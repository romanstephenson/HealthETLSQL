USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[JsonClaimExtract](@DATE DATETIME, @RESULT INT OUTPUT)
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

	IF OBJECT_ID(N'tempdb..#CLAIM_WORKING_TABLE') IS NOT NULL
	BEGIN
		DROP TABLE #CLAIM_WORKING_TABLE;
	END

	IF OBJECT_ID(N'tempdb..#CLAIM_TO_DELETE') IS NOT NULL
	BEGIN
		DROP TABLE #CLAIM_TO_DELETE;
	END

	IF OBJECT_ID(N'tempdb..#TEMP_JSONLogs') IS NOT NULL
	BEGIN
		DROP TABLE #TEMP_JSONLogs;
	END
	/*END VALIDATIONS*/

	CREATE TABLE #CLAIM_WORKING_TABLE
	(
		claimId NVARCHAR(100) NOT NULL,
        claimStatus VARCHAR(20) NULL,
        claimUse VARCHAR(50) NULL,
        claimPatientId varchar(100) NOT NULL,
        claimbillablePeriodStart DATETIME not NULL,
        claimbillablePeriodEnd DATETIME not NULL,
        claimCreated DATETIME null,
        claimProviderReference NVARCHAR(200) null,
        claimPriorityCode VARCHAR(50) null,
        claimPrescriptionId VARCHAR(100) null,
        claimFocal bit null,
        insuranceSequence int null,
        claimCoverage VARCHAR(100) null,
        itemSequence int null,
        claimCode VARCHAR(100) null,
        encounterId NVARCHAR(100) null,
        claimTotal money null,
        claimCurrency VARCHAR(10)
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
			INSERT INTO #CLAIM_WORKING_TABLE(claimId, claimStatus, claimUse, claimPatientId, claimbillablePeriodStart,claimbillablePeriodEnd, claimCreated, claimProviderReference, claimPriorityCode, claimPrescriptionId, claimFocal,insuranceSequence, claimCoverage, itemSequence, claimCode, encounterId, claimTotal, claimCurrency)		
                SELECT 
                    REPLACE(entry.fullUrl,'urn:uuid:','') claimId,
                    entry.status claimStatus,
                    entry.[use] claimUse,
                    replace(resource.patient, 'urn:uuid:','') claimPatientId,
                    CAST(resource.billablePeriodStart AS DATE) claimbillablePeriodStart,
                    CAST(resource.billablePeriodEnd AS DATE) claimbillablePeriodEnd,
                    CAST(resource.created AS DATE) claimCreated,
                    replace(resource.providerReference, 'urn:uuid:','') claimproviderReference,
                    priorityDetails.priorityCode claimPriorityCode,
                    replace(resource.prescription, 'urn:uuid:','') claimPrescriptionId,
                    insuranceDetails.focal claimFocal,
                    insuranceDetails.insuranceSequence,
                    insuranceDetails.coverage claimCoverage,
                    item.itemSequence,
                    claimCodeDetails.code claimCode,
                    replace(item.itemEncounterId,'urn:uuid:','') encounterId,
                    resource.total claimTotal,
                    resource.currency claimCurrency
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
                        [use] varchar(max) '$.resource.use'
                    ) as entry
                OUTER APPLY OPENJSON(entry.resource)
                    WITH
                    (
                        type nvarchar(max) as json,
                        patient varchar(max) '$.patient.reference',
                        billablePeriodStart varchar(max) '$.billablePeriod.start',
                        billablePeriodEnd varchar(max) '$.billablePeriod.end',
                        created varchar(max), --'$.resource.created',
                        providerReference varchar(max) '$.provider.reference',
                        providerName varchar(max) '$.provider.display',
                        priority nvarchar(max) as json,
                        prescription varchar(max) '$.prescription.reference',
                        insurance nvarchar(max) as json,
                        item nvarchar(max) as json,
                        total money '$.total.value',
                        currency varchar(max) '$.total.currency'
                    ) as resource
                OUTER APPLY OPENJSON(resource.insurance)
                    WITH
                    (
                        insuranceSequence int '$.sequence',
                        focal bit,
                        coverage varchar(max) '$.coverage.display'
                    ) as insuranceDetails
                OUTER APPLY OPENJSON(resource.priority)
                    WITH
                    (
                        coding nvarchar(max) as json
                    ) as priorityCoding
                OUTER APPLY OPENJSON(priorityCoding.coding)
                    WITH
                    (
                        prioritySystem varchar(max) '$.system',
                        priorityCode varchar(max) '$.code'
                    ) as priorityDetails
                OUTER APPLY OPENJSON(resource.type)
                    WITH
                    (
                        coding nvarchar(max) as json
                    ) as claimCoding
                OUTER APPLY OPENJSON(claimCoding.coding)
                    WITH
                    (
                        system nvarchar(max),
                        code nvarchar(max)
                    ) as claimCodeDetails
                OUTER APPLY OPENJSON(resource.item)
                    WITH
                    (
                        itemSequence int '$.sequence',
                        productOrService nvarchar(max) as json,
                        itemEncounterId nvarchar(max) '$.encounter[0].reference'
                    ) as item
                OUTER APPLY OPENJSON(item.productOrService)
                    WITH
                    (
                        coding nvarchar(max) as json,
                        text varchar(max)
                    ) as productOrServiceCoding
                OUTER APPLY OPENJSON(productOrServiceCoding.coding)
                    WITH
                    (
                        system nvarchar(max),
                        code nvarchar(max),
                        display nvarchar(max)
                    ) as itemProductOrderServiceCode
                WHERE entry.resourceType in ('Claim')

				FETCH NEXT FROM CURSOR_FOR_JSON_DOCS INTO @_ID, @filename, @JSONDOC;
		END TRY
		BEGIN CATCH
			INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
			VALUES 
			(
				'FAILED WHILE CREATING #CLAIM_WORKING_TABLE',
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
	SELECT [claimId]
	INTO #CLAIM_TO_DELETE
	FROM #CLAIM_WORKING_TABLE
	WHERE [claimId] IN (SELECT DISTINCT claimId FROM [dbo].[fact_claim])

	SELECT @DUPLICATE_CLAIM = COUNT(*) 
	FROM #CLAIM_TO_DELETE

	IF(@DUPLICATE_CLAIM > 0 )
		BEGIN
			DELETE 
			FROM #CLAIM_WORKING_TABLE
			WHERE [claimId] IN (SELECT DISTINCT [claimId] FROM #CLAIM_TO_DELETE )

				BEGIN TRY

					BEGIN TRANSACTION CREATE_CLAIM;

						--SELECT * FROM #CLAIM_WORKING_TABLE
						INSERT INTO [dbo].[fact_claim](claimId, claimStatus, claimUse, claimPatientId, claimbillablePeriodStart,claimbillablePeriodEnd, claimCreated, claimProviderReference, claimPriorityCode, claimPrescriptionId, claimFocal,insuranceSequence, claimCoverage, itemSequence, claimCode, encounterId, claimTotal, claimCurrency)
						SELECT 	claimId, 
                                claimStatus, 
                                claimUse, 
                                claimPatientId, 
                                claimbillablePeriodStart,
                                claimbillablePeriodEnd, 
                                claimCreated, 
                                claimProviderReference, 
                                claimPriorityCode, 
                                claimPrescriptionId, 
                                claimFocal,
                                insuranceSequence, 
                                claimCoverage, 
                                itemSequence, 
                                claimCode, 
                                encounterId, 
                                claimTotal, 
                                claimCurrency
						FROM #CLAIM_WORKING_TABLE
						GROUP BY claimId, claimStatus, claimUse, claimPatientId, claimbillablePeriodStart,claimbillablePeriodEnd, claimCreated, claimProviderReference, claimPriorityCode, claimPrescriptionId, claimFocal,insuranceSequence, claimCoverage, itemSequence, claimCode, encounterId, claimTotal, claimCurrency
						ORDER BY [claimId] ASC

						COMMIT TRANSACTION CREATE_CLAIM;

				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_CLAIM;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING CLAIM',
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

					BEGIN TRANSACTION CREATE_CLAIM;

						--SELECT * FROM #CLAIM_WORKING_TABLE
						INSERT INTO [dbo].[fact_claim](claimId, claimStatus, claimUse, claimPatientId, claimbillablePeriodStart,claimbillablePeriodEnd, claimCreated, claimProviderReference, claimPriorityCode, claimPrescriptionId, claimFocal,insuranceSequence, claimCoverage, itemSequence, claimCode, encounterId, claimTotal, claimCurrency)
						SELECT 	claimId, 
                                claimStatus, 
                                claimUse, 
                                claimPatientId, 
                                claimbillablePeriodStart,
                                claimbillablePeriodEnd, 
                                claimCreated, 
                                claimProviderReference, 
                                claimPriorityCode, 
                                claimPrescriptionId, 
                                claimFocal,
                                insuranceSequence, 
                                claimCoverage, 
                                itemSequence, 
                                claimCode, 
                                encounterId, 
                                claimTotal, 
                                claimCurrency
						FROM #CLAIM_WORKING_TABLE
						GROUP BY claimId, claimStatus, claimUse, claimPatientId, claimbillablePeriodStart,claimbillablePeriodEnd, claimCreated, claimProviderReference, claimPriorityCode, claimPrescriptionId, claimFocal,insuranceSequence, claimCoverage, itemSequence, claimCode, encounterId, claimTotal, claimCurrency
						ORDER BY [claimId] ASC

						COMMIT TRANSACTION CREATE_CLAIM;
				END TRY
				BEGIN CATCH
					IF( @@TRANCOUNT > 0 )
					BEGIN
						ROLLBACK TRANSACTION CREATE_CLAIM;
					END
						INSERT INTO dbo.import_error_logs(FILENAME,ERRORNUMBER,ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
						VALUES 
						  (
							   'FAILED WHILE CREATING CLAIM',
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
