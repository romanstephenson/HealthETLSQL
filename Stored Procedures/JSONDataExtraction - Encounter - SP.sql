USE staging;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[JsonEncounterExtract](@DATE DATETIME, @RESULT INT OUTPUT)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@_ID INT,
		@JSONDOC NVARCHAR(MAX), 
		@filename nvarchar(max),
		@DUPLICATE_ENCOUNTERS INT

	SET @RESULT = 0 -- 0 = OK, 1 = NOT OK

	/*BEGIN VALIDATIONS*/
	IF(@DATE IS NULL OR @DATE = '')
	BEGIN
		SET @DATE = CAST(GETDATE() AS DATE)
	END

	IF OBJECT_ID(N'tempdb..#WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#ENCOUNTERS_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #ENCOUNTERS_TO_DELETE;
	END

	IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

	CREATE TABLE #WORKING_TABLE
	(
		JsonLogsID INT,
		encounterID VARCHAR(50),
		[START] DATE,
		[END] DATE,
		patientID VARCHAR(50),
		organizationID VARCHAR(50),
		practitionerID VARCHAR(50),
		encounter_class VARCHAR(50),
		encounter_code VARCHAR(50),
		encounter_description VARCHAR(200),
	    encounterReasonName VARCHAR(500),
		encounterReasonCode VARCHAR(500)
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
			INSERT INTO #WORKING_TABLE(JsonLogsID,encounterID,[START],[END],patientID,organizationID,practitionerID,encounter_class,encounter_code,encounter_description, encounterReasonName ,encounterReasonCode )
			SELECT 
				@_ID AS JsonLogsID,
				REPLACE(entry.fullUrl,'urn:uuid:','') encounterID,
				CAST(period.[start] AS DATE) [START],
				CAST(period.[end] AS DATE) [END],
				REPLACE(subject.reference,'urn:uuid:','') as patientID,
				--REPLACE(serviceProvider.organizationID,'urn:uuid:','') as organizationID,
				CASE 
					WHEN CHARINDEX('|', REVERSE(serviceProvider.organizationID)) = 0 THEN  serviceProvider.organizationID
					ELSE RIGHT(serviceProvider.organizationID, CHARINDEX('|', REVERSE(serviceProvider.organizationID)) - 1) 
				END as organizationID,
				--REPLACE(practitoner.practitionerID,'urn:uuid:','') as practitionerID,
				CASE 
					WHEN CHARINDEX('|', REVERSE(practitoner.practitionerID)) = 0 THEN  practitoner.practitionerID
					ELSE RIGHT(practitoner.practitionerID, CHARINDEX('|', REVERSE(practitoner.practitionerID)) - 1) 
				END as practitionerID,
				resource.encounter_class,
				coding.code as encounter_code,
				coding.display as encounter_description,
				reasonCode.display as encounterReasonName,
				reasonCode.code as encounterReasonCode
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
					status varchar(1000),
					type nvarchar(max) as json,
					participant nvarchar(max) as json,
					subject nvarchar(max) as json,
					period nvarchar(max) as json,
					reasonCode nvarchar(max) as json,
					serviceProvider nvarchar(max) as json,
					encounter_class nvarchar(max) '$.class.code'
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
			OUTER APPLY OPENJSON(resource.subject)
				WITH
				(
					reference varchar(max),
					display nvarchar(max)
				) as subject
			OUTER APPLY OPENJSON(resource.period)
				WITH
				(
					[start] varchar(max),
					[end] varchar(max)

				) as period
			OUTER APPLY OPENJSON(resource.participant)
				WITH
				(
					individual nvarchar(max) as json
				) as participantDetails
			OUTER APPLY OPENJSON(participantDetails.individual)
				WITH
				(
					practitionerID nvarchar(500) '$.reference',
					practionerName nvarchar(500) '$.display'
				) as practitoner
			OUTER APPLY OPENJSON(resource.reasonCode)
				WITH
				(
					coding nvarchar(max) as json
				) as reason
			OUTER APPLY OPENJSON(reason.coding)
				WITH
				(
					system varchar(max),
					code varchar(max),
					display varchar(max)
				) as reasonCode
			OUTER APPLY OPENJSON(resource.serviceProvider)
				WITH
				(
					organizationID nvarchar(500) '$.reference'
				) as serviceProvider
			WHERE 
				entry.resourceType in ('Encounter')

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
	SELECT encounterID
	INTO #ENCOUNTERS_TO_DELETE
	FROM #WORKING_TABLE
	WHERE encounterID IN (SELECT DISTINCT encounter_ID FROM dbo.fact_encounters )

	SELECT @DUPLICATE_ENCOUNTERS = COUNT(*) 
	FROM #ENCOUNTERS_TO_DELETE

	IF(@DUPLICATE_ENCOUNTERS > 0 )
		BEGIN
			DELETE 
			FROM #WORKING_TABLE
			WHERE encounterID IN (SELECT DISTINCT encounterID FROM #ENCOUNTERS_TO_DELETE )

			BEGIN TRY

				BEGIN TRANSACTION CREATE_ENCOUNTERS
				
					/*CREATE ENCOUNTERS FROM JSON FILES*/
					INSERT INTO dbo.fact_encounters(
						encounter_ID,
						[start],
						[end],
						patientID,
						organizationID,
						practitionerID,
						encounter_class,
						encounter_code,
						encounter_description,
						encounterReasonName,
						encounterReasonCode
						)
						SELECT
						encounterID,
						[start],
						[end],
						patientID,
						organizationID,
						practitionerID,
						encounter_class,
						encounter_code,
						encounter_description,
						encounterReasonName,
						encounterReasonCode
					FROM #WORKING_TABLE

					/*IF THE JSONLOGS ID ALREADY IS IN THE IMPORT LOG TABLE, DO NOT INSERT IT AGAIN*/
					DELETE FROM #WORKING_TABLE
					WHERE JSONLOGSID IN ( SELECT DISTINCT JSONLOGSID FROM dbo.JSONImportLog )

					INSERT INTO dbo.JSONImportLog([JSONLogsId],[ResourceType],[ExportDate])
					SELECT DISTINCT JsonLogsId, 'Encounter', CAST(GETDATE() AS DATE) 
					FROM #WORKING_TABLE

				COMMIT TRANSACTION CREATE_ENCOUNTERS;

			END TRY
			BEGIN CATCH
				IF( @@TRANCOUNT > 0 )
				BEGIN
					ROLLBACK TRANSACTION CREATE_ENCOUNTERS;
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

				BEGIN TRANSACTION CREATE_ENCOUNTERS
				/*CREATE ENCOUNTERS FROM JSON FILES*/
					INSERT INTO dbo.fact_encounters(
						encounter_ID,
						[start],
						[end],
						patientID,
						organizationID,
						practitionerID,
						encounter_class,
						encounter_code,
						encounter_description,
						encounterReasonName,
						encounterReasonCode
						)
					SELECT 
						encounterID,
						[start],
						[end],
						patientID,
						organizationID,
						practitionerID,
						encounter_class,
						encounter_code,
						encounter_description,
						encounterReasonName,
						encounterReasonCode
					FROM #WORKING_TABLE

					/*IF THE JSONLOGS ID ALREADY IS IN THE IMPORT LOG TABLE, DO NOT INSERT IT AGAIN*/
					DELETE FROM #WORKING_TABLE
					WHERE JSONLOGSID IN ( SELECT DISTINCT JSONLOGSID FROM dbo.JSONImportLog )

					/*SINCE WE HAVE EXTRACTED THE DATA FROM THE JSON FILES ABOVE, UPDATE LOG*/
					INSERT INTO dbo.JSONImportLog([JSONLogsId],[ResourceType],[ExportDate])
					SELECT DISTINCT JsonLogsId, 'Encounter', CAST(GETDATE() AS DATE) 
					FROM #WORKING_TABLE

				COMMIT TRANSACTION CREATE_ENCOUNTERS;

			END TRY
			BEGIN CATCH
				IF( @@TRANCOUNT > 0 )
				BEGIN
					ROLLBACK TRANSACTION CREATE_ENCOUNTERS;
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
