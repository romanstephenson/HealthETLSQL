USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_DiabeticPatient_HospitalizationSummary] AS
SELECT 
    p.ID as patientId,
    [staging].[dbo].[udf_RemoveNumericCharacters](p.firstName) + ' ' + [staging].[dbo].[udf_RemoveNumericCharacters](p.lastName) AS patientName,
    hc.[name] as hospitalName,
    e.[start] as encounterDate,
    e.encounter_class encounterType,
    --e.encounterReason,
    SUM(fc.claimTotal) AS hospitalizationCost
FROM 
    [staging].[dbo].dim_patient p
INNER JOIN 
    [staging].[dbo].fact_encounters e ON p.ID = e.patientId
INNER JOIN 
    [staging].[dbo].dim_organization hc ON e.organizationID = hc.ID
INNER JOIN 
    [staging].[dbo].fact_claim fc ON e.encounter_Id = fc.encounterId
INNER JOIN 
    [staging].[dbo].fact_encounter_conditions d ON e.encounter_Id = d.encounter_ID
INNER JOIN 
	[staging].[dbo].dim_condition dc ON d.condition_code = dc.code
WHERE 
    dc.[description] LIKE '%diabet%'  

GROUP BY 
    p.ID, p.firstName, p.lastName, hc.[name], e.[start], e.encounter_class --, e.encounterReason;
GO
