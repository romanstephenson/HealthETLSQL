USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[JsonPractitionerExtract](@DATE DATETIME, @RESULT INT OUTPUT)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@_ID INT,
		@JSONDOC NVARCHAR(MAX), 
		@filename nvarchar(max),
		@DUPLICATE_ORGANIZATION INT

	SET @RESULT = 0 -- 0 = OK, 1 = NOT OK

	/*BEGIN VALIDATIONS*/
	IF(@DATE IS NULL OR @DATE = '')
	BEGIN
		SET @DATE = CAST(GETDATE() AS DATE)
	END

	IF OBJECT_ID(N'tempdb..#PRACTIONER_WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #PRACTIONER_WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#PRAC_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #PRAC_TO_DELETE;
	END

	IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

	CREATE TABLE #PRACTIONER_WORKING_TABLE
	(
		[ID] [varchar](100) NOT NULL,
		[prefix] [varchar](10) NULL,
		[firstname] [varchar](50) NULL,
		[lastname] [varchar](50) NULL,
		[gender] [varchar](20) NULL,
		[address] [varchar](100) NULL,
		[city] [varchar](50) NULL,
		[state] [varchar](50) NULL,
		[zip] [varchar](50) NULL,
		[contactvalue] [varchar](100) NULL,
		contacttype [varchar](100) NULL,
		contactmethod [varchar](100) NULL,
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

	/*NOW THAT WE HAVE ALL DOCS FOR A DATE, LOOP THROUGH EACH DOC AND COLLECT THE ENCOUNTERS*/
	FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*ASSUMING THE ABOVE IS SUCCESSFUL, EXTRACT THE BELOW FIELDS AND PLACE IN A TEMP TABLE*/
		BEGIN TRY
			INSERT INTO #PRACTIONER_WORKING_TABLE([ID], prefix, firstname, lastname, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod)		
				SELECT 
					REPLACE(entry.fullUrl,'urn:uuid:','') practitionerID,
					nameDetails.prefix,
					nameDetails.Given, 
					nameDetails.Family,
					resource.gender,
					address.line + ',' + address.country AS ADDRESS,
					address.city,
					address.state,
					address.postalCode AS ZIP,
					telecom.[value] as contactvalue,
					telecom.[use] as contacttype,
					telecom.[system] as contactmethod
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
						name nvarchar(max) as json,
						telecom nvarchar(max) as json,
						gender nvarchar(500),
						active bit, --nvarchar(max),
						address nvarchar(max) as json
					) as resource
				OUTER APPLY OPENJSON(resource.name)
					WITH
					(
						family varchar(max),
						given nvarchar(max) '$.given[0]',
						prefix nvarchar(max) '$.prefix[0]'
					) as nameDetails
				OUTER APPLY OPENJSON(resource.telecom)
					WITH
					(
						system nvarchar(max), --'$.resource.telecom.system',
						value nvarchar(max), --'$.resource.telecom.value',
						[use] nvarchar(max) --'$.resource.telecom.use'
					) as telecom
				OUTER APPLY OPENJSON(resource.address)
					WITH
					(
						line nvarchar(max) '$.line[0]',
						city nvarchar(max),
						state nvarchar(max),
						postalCode nvarchar(max),
						country nvarchar(max)
					) as address
				WHERE entry.resourceType in ('Practitioner') 

				FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;
		END TRY
		BEGIN CATCH
			INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
			VALUES 
			(
				'FAILED WHILE CREATING #PRACTIONER_WORKING_TABLE',
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
	SELECT [ID]
	INTO #PRAC_TO_DELETE
	FROM #PRACTIONER_WORKING_TABLE
	WHERE [ID] IN (SELECT DISTINCT ID FROM [dbo].[dim_practitioner])

	SELECT @DUPLICATE_ORGANIZATION = COUNT(*) 
	FROM #PRAC_TO_DELETE

	IF(@DUPLICATE_ORGANIZATION > 0 )
		BEGIN
			DELETE 
			FROM #PRACTIONER_WORKING_TABLE
			WHERE [ID] IN (SELECT DISTINCT [ID] FROM #PRAC_TO_DELETE )

				BEGIN TRY

					BEGIN TRANSACTION CREATE_PRACTITIONER;

						--SELECT * FROM #PRACTIONER_WORKING_TABLE
						INSERT INTO [dbo].[dim_practitioner]([ID], prefix, firstname, lastname, [gender], [address], [city], [state], [zip], contactvalue, contacttype, contactmethod)
						SELECT 	[ID], prefix, given, family, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod
						FROM #PRACTIONER_WORKING_TABLE
						GROUP BY [ID], prefix, given, family, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod
						ORDER BY [ID] ASC

						COMMIT TRANSACTION CREATE_PRACTITIONER;

				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_PRACTITIONER;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING practition',
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

					BEGIN TRANSACTION CREATE_PRACTITIONER

						--SELECT * FROM #PRACTIONER_WORKING_TABLE

						INSERT INTO [dbo].[dim_practitioner]([ID], prefix, firstname, lastname, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod)
						SELECT 	[ID], prefix, firstname, lastname, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod
						FROM #PRACTIONER_WORKING_TABLE
						GROUP BY [ID], prefix, firstname, lastname, [gender], [address], [city], [state], [zip], [contactvalue], contacttype,contactmethod
						ORDER BY [ID] ASC

						COMMIT TRANSACTION CREATE_PRACTITIONER;
				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_PRACTITIONER;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING practition',
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
