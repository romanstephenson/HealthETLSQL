USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_DiabeticPatient_Medications] AS
SELECT 
    p.ID as patientId,
    staging.[dbo].[udf_RemoveNumericCharacters](p.firstName) + ' ' + staging.[dbo].[udf_RemoveNumericCharacters](p.lastName) AS patientName,
    m.medicationCode,
    m.medicationName,
    m.dosageQuantity As dosage,
    m.frequency,
    e.[start] as encounterDate
FROM 
    staging.dbo.dim_patient p
INNER JOIN 
    staging.dbo.fact_encounters e ON p.Id = e.patientId
INNER JOIN 
    staging.dbo.fact_medication_request m ON e.encounter_Id = replace(m.encounterId,'urn:uuid:','')
WHERE 
    (m.conditionThatCausedMedicationRequest like '%diabet%') ;
GO
