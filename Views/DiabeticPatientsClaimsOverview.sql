USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_DiabeticPatients_ClaimsOverview] AS
SELECT 
    fc.claimId,
    fc.claimStatus,
    fc.claimCreated,
    fc.claimTotal,
    staging.[dbo].[udf_RemoveNumericCharacters](p.firstName) + ' ' + staging.[dbo].[udf_RemoveNumericCharacters](p.lastName) AS patientName,
    hc.[name] as hospitalName,
    m.medicationCode as medicationCode,
	m.MedicationName as MedicationName,
    d.condition_code AS diagnosisCode,
    dc.[description] AS diagnosisDescription

FROM 
    staging.dbo.fact_claim fc
INNER JOIN 
    staging.dbo.fact_encounters e ON fc.encounterId = e.encounter_Id
INNER JOIN 
    staging.dbo.dim_patient p ON fc.claimPatientId = p.ID
INNER JOIN 
    staging.dbo.dim_organization hc ON e.organizationID = hc.ID
INNER JOIN 
    staging.dbo.fact_encounter_conditions d ON e.encounter_ID = d.encounter_ID
INNER JOIN 
   staging.dbo.fact_medication_request m ON e.encounter_Id = replace(m.encounterId,'urn:uuid:','')

INNER JOIN 
	staging.dbo.dim_condition dc ON d.condition_code = dc.code
WHERE 
    dc.[description] LIKE '%diabet%'  ;
GO
