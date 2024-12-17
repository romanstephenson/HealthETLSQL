USE STAGING;
GO
CREATE PROCEDURE dbo.JsonEncounterTreatmentsExtract(@DATE DATETIME, @RESULT INT OUTPUT)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@JSON NVARCHAR(MAX), 
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
	/*END VALIDATIONS*/


	/* GET ALL JSON FILES FOR CURRENT DATE OR WHATEVER DATE IS PASSED TO STORED PROCEDURE*/
	BEGIN TRY
		SELECT @filename = [filename], @JSON = JSONDOCUMENT 
		FROM [dbo].[JSONLogs]
		WHERE CAST(IMPORTDATE AS DATE) = CAST(@DATE AS DATE)
	END TRY
	BEGIN CATCH
		INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
		VALUES 
		(
		   NULL,
		   ERROR_NUMBER(),
		   ERROR_LINE(),
		   ERROR_MESSAGE(),
		   GETDATE()
		   );
		   GOTO ERROR
	END CATCH
		
	/*ASSUMING THE ABOVE IS SUCCESSFUL, EXTRACT THE BELOW FIELDS AND PLACE IN A TEMP TABLE*/
	BEGIN TRY
		SELECT 
			REPLACE(entry.fullUrl,'urn:uuid:','') encounterID,
			period.[start],
			period.[end],
			REPLACE(subject.reference,'urn:uuid:','') as patientID,
			REPLACE(serviceProvider.organizationID,'urn:uuid:','') as organizationID,
			REPLACE(practitoner.practitionerID,'urn:uuid:','') as practitionerID,
			resource.encounter_class,
			coding.code as encounter_code,
			coding.display as encounter_description
			INTO #WORKING_TABLE
		FROM OPENJSON( @JSON )
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
				status varchar(1000),
				address nvarchar(max) as json,
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
				[end] nvarchar(max)
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
	END TRY
	BEGIN CATCH
		INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
		VALUES 
		(
		   NULL,
		   ERROR_NUMBER(),
		   ERROR_LINE(),
		   ERROR_MESSAGE(),
		   GETDATE()
		   );

		   GOTO ERROR
	END CATCH

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
		END
	ELSE
		BEGIN
			BEGIN TRY
				/*"OUTPUT INSERTED" - ENSURES RECORD THAT IS CREATED ON ENCOUNTER TABLE IS ALSO LOGGED TO JSONLOGS TABLE AS EXPORTED*/
				INSERT INTO dbo.fact_encounters(
					encounter_ID,
					[start],
					[end],
					patientID,
					organizationID,
					practitionerID,
					encounter_class,
					encounter_code,
					encounter_description)
				OUTPUT INSERTED.ID, 'Encounter', CAST(GETDATE() AS DATE)
				SELECT 
					encounterID,
					[start],
					[end],
					patientID,
					organizationID,
					practitionerID,
					encounter_class,
					encounter_code,
					encounter_description
				FROM #WORKING_TABLE
			END TRY
			BEGIN CATCH
				INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
				VALUES 
				  (
					   NULL,
					   ERROR_NUMBER(),
					   ERROR_LINE(),
					   ERROR_MESSAGE(),
					   GETDATE()
				   );

				   GOTO ERROR
			END CATCH
		END

	ERROR:
		SET @RESULT = 1
END;

GO