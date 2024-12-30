USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[JsonMedicationRequestExtract](@DATE DATETIME, @RESULT INT OUTPUT)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@_ID INT,
		@JSONDOC NVARCHAR(MAX), 
		@filename nvarchar(max),
		@DUPLICATE_MEDICATIONREQUEST INT

	SET @RESULT = 0 -- 0 = OK, 1 = NOT OK

	/*BEGIN VALIDATIONS*/
	IF(@DATE IS NULL OR @DATE = '')
	BEGIN
		SET @DATE = CAST(GETDATE() AS DATE)
	END

	IF OBJECT_ID(N'tempdb..#MEDICATIONREQUEST_WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #MEDICATIONREQUEST_WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#MEDICATIONREQUEST_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #MEDICATIONREQUEST_TO_DELETE;
	END

    IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

    CREATE TABLE #MEDICATIONREQUEST_WORKING_TABLE
    (
        JsonLogsID INT,
        [medicationRequestID] [nvarchar](100) ,
        [medicationRequestStatus] [nvarchar](100) ,
        [medicationRequestIntent] [nvarchar](100) ,
        [medicationName] [nvarchar](400) ,
        [medicationCode] [nvarchar](100) ,
        [medicationCategoryAdministration] [nvarchar](200) ,
        [patientId]  [nvarchar](100) ,
        encounterID [nvarchar](100),
        [medicationRequestCreated] [datetime] ,
        [doctorID] [nvarchar](100) ,
        [medicationRequestReasonID] [nvarchar](100) ,
        [conditionThatCausedMedicationRequest] [nvarchar](100) ,
        [asNeededBoolean] [bit] ,
        [sequence] [int] ,
        [frequency] [int] ,
        [period] [float] ,
        [periodUnit] [char](10) ,
        [dosageQuantity] [float] 
    ) 


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
			INSERT INTO #MEDICATIONREQUEST_WORKING_TABLE
            (
                    JsonLogsID,
                    [medicationRequestID],
                            [medicationRequestStatus] ,
                            [medicationRequestIntent] ,
                            [medicationName] ,
                            [medicationCode]  ,
                            [medicationCategoryAdministration] ,
                            [patientId] ,
                            encounterID,
                            [medicationRequestCreated] ,
                            [doctorID]  ,
                            [medicationRequestReasonID] ,
                            [conditionThatCausedMedicationRequest] ,
                            [asNeededBoolean] ,
                            [sequence] ,
                            [frequency] ,
                            [period]  ,
                            [periodUnit],
                            [dosageQuantity] 
            )
			SELECT 
                @_ID AS JsonLogsID ,
                REPLACE(entry.fullUrl,'urn:uuid:','') medicationRequestID,
                entry.status medicationRequestStatus,
                entry.intent medicationRequestIntent,
                medCodeDetails.display medicationName,
                medCodeDetails.code medicationCode,
                medicationCoding.[text] medicationCategoryAdministration,
                resource.subject patientId,
                CASE 
                    WHEN CHARINDEX('|', REVERSE( resource.encounter)  ) = 0 THEN  resource.encounter
                    ELSE  RIGHT(resource.encounter, CHARINDEX('|', REVERSE(resource.encounter) ) - 1) 
                END AS encounterID,
                CAST(resource.authoredOn AS DATE) medicationRequestCreated,
                CASE 
                    WHEN CHARINDEX('|', REVERSE(resource.requester) ) = 0 THEN  resource.requester
                    ELSE RIGHT(resource.requester, CHARINDEX('|', REVERSE(resource.requester) ) - 1)
                END AS doctorID,
                CASE
                    WHEN CHARINDEX('|', REVERSE(resource.medicationRequestReasonID) ) = 0 THEN  resource.medicationRequestReasonID
                    ELSE RIGHT(resource.medicationRequestReasonID, CHARINDEX('|', REVERSE(resource.medicationRequestReasonID) ) - 1 ) 
                END AS medicationRequestReasonID,
                resource.condition conditionThatCausedMedicationRequest,
                dosageInstruct.asNeededBoolean,
                dosageInstruct.sequence, 
                dosageInstruct.frequency,
                dosageInstruct.period,
                dosageInstruct.periodUnit,
                resource.doseAndRate
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
                    extension nvarchar(max) as json,
                    id varchar(max) '$.resource.id',
                    status varchar(max) '$.resource.status',
                    intent varchar(max) '$.resource.intent',
                    medicationCodeableConcept nvarchar(max) as json
                ) as entry
            OUTER APPLY OPENJSON(entry.resource)
                WITH
                (
                    medicationCodeableConcept nvarchar(max) as json,
                    subject varchar(max) '$.subject.reference',
                    encounter varchar(max) '$.encounter.reference',
                    authoredOn varchar(max) '$.authoredOn',
                    requester varchar(max) '$.requester.reference',
                    display varchar(max) '$.requester.display',
                    medicationRequestReasonID varchar(max) '$.reasonReference[0].reference',
                    condition varchar(max) '$.reasonReference[0].display',
                    dosageInstruction nvarchar(max) as json,
                    doseAndRate FLOAT '$.doseAndRate[0].doseQuantity.value' --as json
                ) as resource
            OUTER APPLY OPENJSON(resource.medicationCodeableConcept)
                WITH
                (
                    coding nvarchar(max) as json,
                    [text] nvarchar(max)
                ) as medicationCoding
            OUTER APPLY OPENJSON(medicationCoding.coding)
                with
                (
                    system nvarchar(max),
                    code nvarchar(max),
                    display nvarchar(max)
                ) as medCodeDetails
            OUTER APPLY OPENJSON(resource.dosageInstruction)
                with
                (
                    sequence nvarchar(max),
                    asNeededBoolean bit,
                    frequency NVARCHAR(max) '$.timing.repeat.frequency',
                    period NVARCHAR(max) '$.timing.repeat.period',
                    periodUnit NVARCHAR(max) '$.timing.repeat.periodUnit'
                ) as dosageInstruct
            WHERE entry.resourceType in ('MedicationRequest')

				FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;
		END TRY
		BEGIN CATCH
			INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
			VALUES 
			(
				'FAILED WHILE CREATING #MEDICATIONREQUEST_WORKING_TABLE',
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
	SELECT medicationRequestID
	INTO #MEDICATIONREQUEST_TO_DELETE
	FROM #MEDICATIONREQUEST_WORKING_TABLE
	WHERE medicationRequestID IN (SELECT DISTINCT medicationRequestID FROM [dbo].[fact_medication_request] )

	SELECT @DUPLICATE_MEDICATIONREQUEST = COUNT(*) 
	FROM #MEDICATIONREQUEST_TO_DELETE

	IF(@DUPLICATE_MEDICATIONREQUEST > 0 )
		BEGIN
			DELETE 
			FROM #MEDICATIONREQUEST_WORKING_TABLE
			WHERE medicationRequestID IN (SELECT DISTINCT medicationRequestID FROM #MEDICATIONREQUEST_TO_DELETE )

			BEGIN TRY

				BEGIN TRANSACTION CREATE_MEDICATION_REQUEST
				
					INSERT INTO dbo.fact_medication_request(
                            [medicationRequestID],
                            [medicationRequestStatus] ,
                            [medicationRequestIntent] ,
                            [medicationName] ,
                            [medicationCode]  ,
                            [medicationCategoryAdministration] ,
                            [patientId] ,
                            encounterID,
                            [medicationRequestCreated] ,
                            [doctorID]  ,
                            [medicationRequestReasonID] ,
                            [conditionThatCausedMedicationRequest] ,
                            [asNeededBoolean] ,
                            [sequence] ,
                            [frequency] ,
                            [period]  ,
                            [periodUnit],
                            [dosageQuantity]
                            )
					SELECT 
                            [medicationRequestID],
                            [medicationRequestStatus] ,
                            [medicationRequestIntent] ,
                            [medicationName] ,
                            [medicationCode]  ,
                            [medicationCategoryAdministration] ,
                            [patientId] ,
                            encounterID,
                            [medicationRequestCreated] ,
                            [doctorID]  ,
                            [medicationRequestReasonID] ,
                            [conditionThatCausedMedicationRequest] ,
                            [asNeededBoolean] ,
                            [sequence] ,
                            [frequency] ,
                            [period]  ,
                            [periodUnit],
                            [dosageQuantity] 
					FROM #MEDICATIONREQUEST_WORKING_TABLE

					/*IF THE JSONLOGS ID ALREADY IS IN THE IMPORT LOG TABLE, DO NOT INSERT IT AGAIN*/
					DELETE FROM #MEDICATIONREQUEST_WORKING_TABLE
					WHERE JSONLOGSID IN ( SELECT DISTINCT JSONLOGSID FROM dbo.JSONImportLog )

					INSERT INTO dbo.JSONImportLog([JSONLogsId],[ResourceType],[ExportDate])
					SELECT DISTINCT JsonLogsId, 'MedicationRequest', CAST(GETDATE() AS DATE) 
					FROM #MEDICATIONREQUEST_WORKING_TABLE

				COMMIT TRANSACTION CREATE_MEDICATION_REQUEST;

			END TRY
			BEGIN CATCH
				IF( @@TRANCOUNT > 0 )
				BEGIN
					ROLLBACK TRANSACTION CREATE_MEDICATION_REQUEST;
				END
					INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
					VALUES 
					  (
						   'FAILED WHILE CREATING MEDICATION REQUEST',
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

				BEGIN TRANSACTION CREATE_MEDICATION_REQUEST
				    
                    INSERT INTO dbo.fact_medication_request
                    (
                            [medicationRequestID],
                            [medicationRequestStatus] ,
                            [medicationRequestIntent] ,
                            [medicationName] ,
                            [medicationCode]  ,
                            [medicationCategoryAdministration] ,
                            [patientId] ,
                            encounterID,
                            [medicationRequestCreated] ,
                            [doctorID]  ,
                            [medicationRequestReasonID] ,
                            [conditionThatCausedMedicationRequest] ,
                            [asNeededBoolean] ,
                            [sequence] ,
                            [frequency] ,
                            [period]  ,
                            [periodUnit],
                            [dosageQuantity] 
                    )
					SELECT 
                            [medicationRequestID],
                            [medicationRequestStatus] ,
                            [medicationRequestIntent] ,
                            [medicationName] ,
                            [medicationCode]  ,
                            [medicationCategoryAdministration] ,
                            [patientId] ,
                            encounterID,
                            [medicationRequestCreated] ,
                            [doctorID]  ,
                            [medicationRequestReasonID] ,
                            [conditionThatCausedMedicationRequest] ,
                            [asNeededBoolean] ,
                            [sequence] ,
                            [frequency] ,
                            [period]  ,
                            [periodUnit],
                            [dosageQuantity] 
					FROM #MEDICATIONREQUEST_WORKING_TABLE

					/*IF THE JSONLOGS ID ALREADY IS IN THE IMPORT LOG TABLE, DO NOT INSERT IT AGAIN*/
					DELETE FROM #MEDICATIONREQUEST_WORKING_TABLE
					WHERE JSONLOGSID IN ( SELECT DISTINCT JSONLOGSID FROM dbo.JSONImportLog )

					/*SINCE WE HAVE EXTRACTED THE DATA FROM THE JSON FILES ABOVE, UPDATE LOG*/
					INSERT INTO dbo.JSONImportLog([JSONLogsId],[ResourceType],[ExportDate])
					SELECT DISTINCT JsonLogsId, 'MedicationRequest', CAST(GETDATE() AS DATE) 
					FROM #MEDICATIONREQUEST_WORKING_TABLE

				COMMIT TRANSACTION CREATE_MEDICATION_REQUEST;

			END TRY
			BEGIN CATCH
				IF( @@TRANCOUNT > 0 )
				BEGIN
					ROLLBACK TRANSACTION CREATE_MEDICATION_REQUEST;
				END
					INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
					VALUES 
					  (
						   'FAILED WHILE CREATING MEDICATION REQUEST',
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
