USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[JsonOrganizationExtract](@DATE DATETIME, @RESULT INT OUTPUT)
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

	IF OBJECT_ID(N'tempdb..#ORG_WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #ORG_WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#ORG_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #ORG_TO_DELETE;
	END

	IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

	CREATE TABLE #ORG_WORKING_TABLE
	(
		organizationID varchar(100),
        name varchar(100),
        address varchar(100),
        city varchar(50),
        state varchar(50),
        zip varchar(50),
        phone varchar(30),
		type varchar(100)
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
			INSERT INTO #ORG_WORKING_TABLE(organizationID,NAME,address,CITY,state,ZIP,PHONE,TYPE)
				SELECT 
				REPLACE(entry.fullUrl,'urn:uuid:','') organizationID,
				resource.name,
				address.line + ',' + address.country AS ADDRESS,
				address.city,
				address.state,
				address.postalCode AS ZIP,
				telecom.value as phone,
				type.text as TYPE
			FROM OPENJSON( @JSONDOC )
				WITH 
				(
					resourceType varchar(max),
					type varchar(400),
					entry nvarchar(max) as json
				) as jsonfile
			OUTER APPLY OPENJSON(jsonfile.entry)
				WITH
				(
					fullUrl varchar(max),
					resourceType varchar(250) '$.resource.resourceType',
					resource nvarchar(max) as json,
					extension nvarchar(max) as json
				) as entry
			OUTER APPLY OPENJSON(entry.resource)
				WITH
				(
					name nvarchar(max),
					telecom nvarchar(max) as json,
					gender nvarchar(500),
					birthDate datetime,
					active bit, --nvarchar(max),
					address nvarchar(max) as json,
					type nvarchar(max) as json
				) as resource
			OUTER APPLY OPENJSON(resource.type)
				WITH
				(
					text varchar(max),
					coding nvarchar(max) as json
				) as type
			OUTER APPLY OPENJSON(type.coding)
				WITH
				(
					system varchar(max),
					code nvarchar(max),
					display nvarchar(max)
				) as coding
			OUTER APPLY OPENJSON(resource.telecom)
				WITH
				(
					system varchar(max),
					value nvarchar(max)
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
			WHERE entry.resourceType in ('Organization')

				FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;
		END TRY
		BEGIN CATCH
			INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
			VALUES 
			(
				'FAILED WHILE CREATING #WORKING_TABLE',
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
	SELECT organizationID
	INTO #ORG_TO_DELETE
	FROM #ORG_WORKING_TABLE
	WHERE organizationID IN (SELECT DISTINCT ID FROM [dbo].[dim_organization])

	SELECT @DUPLICATE_ORGANIZATION = COUNT(*) 
	FROM #ORG_TO_DELETE

	IF(@DUPLICATE_ORGANIZATION > 0 )
		BEGIN
			DELETE 
			FROM #ORG_WORKING_TABLE
			WHERE organizationID IN (SELECT DISTINCT organizationID FROM #ORG_TO_DELETE )

				BEGIN TRY

					BEGIN TRANSACTION CREATE_ORGANIZATION

						--SELECT * FROM #ORG_WORKING_TABLE
						INSERT INTO dbo.dim_organization(
									ID,
									name,
									address,
									city,
									state,
									zip,
									phone,
									[type])
						SELECT DISTINCT
							organizationID,
							name,
							address,
							city,
							state,
							zip,
							phone,
							[type]
						FROM #ORG_WORKING_TABLE
						GROUP BY organizationID,
							name,
							address,
							city,
							state,
							zip,
							phone,
							[type]
						ORDER BY organizationID ASC

						COMMIT TRANSACTION CREATE_ORGANIZATION;

				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_ORGANIZATION;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING ENCOUNTERS',
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

					BEGIN TRANSACTION CREATE_ORGANIZATION

						--SELECT * FROM #ORG_WORKING_TABLE

						INSERT INTO dbo.dim_organization(
									ID,
									name,
									address,
									city,
									state,
									zip,
									phone,
									[type])
						SELECT
							organizationID,
							name,
							address,
							city,
							state,
							zip,
							phone,
							[type]
						FROM #ORG_WORKING_TABLE
						GROUP BY organizationID,
							name,
							address,
							city,
							state,
							zip,
							phone,
							[type]
						ORDER BY organizationID ASC

						COMMIT TRANSACTION CREATE_ORGANIZATION;

						
				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_ORGANIZATION;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING ENCOUNTERS',
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
