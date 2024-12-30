USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDUREDURE [dbo].[JsonIdentificationExtract](@DATE DATETIME, @RESULT INT OUTPUT)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@_ID INT,
		@JSONDOC NVARCHAR(MAX), 
		@filename nvarchar(max),
		@DUPLICATE_CLAIM INT

	SET @RESULT = 0 -- 0 = OK, 1 = NOT OK

	/*BEGIN VALIDATIONS*/
	IF(@DATE IS NULL OR @DATE = '')
	BEGIN
		SET @DATE = CAST(GETDATE() AS DATE)
	END

	IF OBJECT_ID(N'tempdb..#ID_WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #ID_WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#ID_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #ID_TO_DELETE;
	END

	IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

	CREATE TABLE #ID_WORKING_TABLE
	(
		[personNumber] NVARCHAR(50) NOT NULL,
        [idNumber] NVARCHAR(50) NULL,
        [idTypeName] NVARCHAR(50) NULL,
        [idShortCode] NVARCHAR(50) NULL
	); 

	/* GET ALL JSON FILES FOR CURRENT DATE OR WHATEVER DATE IS PASSED TO STORED PROCEDURE*/
	BEGIN TRY
		
		DECLARE CURSOR_FOR_JSON_DOCS CURSOR LOCAL FOR
			SELECT _ID, [filename], JSONDOCUMENT 
			FROM [dbo].[JSONLogs]
			WHERE CAST(IMPORTDATE AS DATE) = CAST(@DATE AS DATE)

	END TRY
	BEGIN CATCH
		INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
		VALUES 
		(
		   'FAILED WHILE GETTING JSON DATA FOR CURRENT DAY',
		   ERROR_NUMBER(),
		   ERROR_LINE(),
		   ERROR_MESSAGE(),
		   GETDATE()
		   );
		   GOTO ERROR
	END CATCH		

	OPEN CURSOR_FOR_JSON_DOCS;

	FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*ASSUMING THE ABOVE IS SUCCESSFUL, EXTRACT THE BELOW FIELDS AND PLACE IN A TEMP TABLE*/
		BEGIN TRY
			INSERT INTO #ID_WORKING_TABLE([personNumber],[idNumber], [idTypeName] ,[idShortCode])		
                
            SELECT REPLACE(entry.fullUrl,'urn:uuid:','') personNumber,
                identifier.type idshortcode,
                identifier.name idtypename,
                identifier.value idnumber
            FROM OPENJSON( @JSONDOC )
                WITH 
                (
                    resourceType varchar(max),
                    entry nvarchar(max) as json
                ) as jsonfile
            OUTER APPLY OPENJSON(jsonfile.entry)
                WITH
                (
                    fullUrl varchar(max),
                    resourceType varchar(250) '$.resource.resourceType',
                    resource nvarchar(max) as json
                ) as entry
            OUTER APPLY OPENJSON(entry.resource)
                WITH
                (
                    identifier nvarchar(max) as json
                ) as resource
            OUTER APPLY OPENJSON(resource.identifier)
                WITH 
                (
                    type VARCHAR(50) '$.type.coding[0].code',
                    name VARCHAR(50) '$.type.coding[0].display',
                    value VARCHAR(50) 
                ) as identifier
            WHERE entry.resourceType in ('Patient') and identifier.TYPE IS NOT NULL

				FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;
		END TRY
		BEGIN CATCH
			INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
			VALUES 
			(
				'FAILED WHILE CREATING #ID_WORKING_TABLE',
				ERROR_NUMBER(),
				ERROR_LINE(),
				ERROR_MESSAGE(),
				GETDATE()
				);

				GOTO ERROR
		END CATCH
	END;

	/*DEALLOCATE RESOURCES WE NO LONGER NEED.*/
	CLOSE CURSOR_FOR_JSON_DOCS;
	DEALLOCATE CURSOR_FOR_JSON_DOCS;

	/*CHECK IF THE ENCOUNTER ID EXISTS ALREADY IN THE TABLE, IF THEY DO, DELETE THEM FROM TEMP TABLE AND INSERT ONLY THOSE THAT DO NOT EXIST*/
	SELECT [personNumber]
	INTO #ID_TO_DELETE
	FROM #ID_WORKING_TABLE
	WHERE [personNumber] IN (SELECT DISTINCT personNumber FROM [dbo].[fact_Identification])

	SELECT @DUPLICATE_CLAIM = COUNT(*) 
	FROM #ID_TO_DELETE

	IF(@DUPLICATE_CLAIM > 0 )
		BEGIN
			DELETE 
			FROM #ID_WORKING_TABLE
			WHERE [personNumber] IN (SELECT DISTINCT [personNumber] FROM #ID_TO_DELETE )

				BEGIN TRY

					BEGIN TRANSACTION CREATE_ID;

						--SELECT * FROM #ID_WORKING_TABLE
						INSERT INTO [dbo].[fact_Identification]([personNumber],[idNumber], [idTypeName] ,[idShortCode])
						SELECT 	[personNumber],[idNumber], [idTypeName] ,[idShortCode]
						FROM #ID_WORKING_TABLE
						GROUP BY [personNumber],[idNumber], [idTypeName] ,[idShortCode]
						ORDER BY [personNumber] ASC

					COMMIT TRANSACTION CREATE_ID;

				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_ID;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING ID',
							   ERROR_NUMBER(),
							   ERROR_LINE(),
							   ERROR_MESSAGE(),
							   GETDATE()
						   );

						   GOTO ERROR
				END CATCH
			END
		ELSE
			BEGIN
				BEGIN TRY

					BEGIN TRANSACTION CREATE_ID;

						INSERT INTO [dbo].[fact_Identification]([personNumber],[idNumber], [idTypeName] ,[idShortCode])
						SELECT 	[personNumber],[idNumber], [idTypeName] ,[idShortCode]
						FROM #ID_WORKING_TABLE
						GROUP BY [personNumber],[idNumber], [idTypeName] ,[idShortCode]
						ORDER BY [personNumber] ASC

					COMMIT TRANSACTION CREATE_ID;
				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_ID;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING ID',
							   ERROR_NUMBER(),
							   ERROR_LINE(),
							   ERROR_MESSAGE(),
							   GETDATE()
						   );

						   GOTO ERROR
				END CATCH
			END

	IF @RESULT <> 0
	BEGIN
		ERROR:
			SET @RESULT = 1
	END
END;

GO
