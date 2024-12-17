USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_DiabeticPatient_Encounters] AS
SELECT 
    p.ID AS patientId,
    [staging].[dbo].[udf_RemoveNumericCharacters](p.firstName) + ' ' + [staging].[dbo].[udf_RemoveNumericCharacters](p.lastName) AS patientName,
    e.encounter_ID,
    e.[start] As encounterDate,
    e.encounter_class AS encounterType,
    -- e.encounterReason,
    hc.[name] as providerName
FROM 
    staging.dbo.dim_patient p
INNER JOIN 
    staging.dbo.fact_encounters e ON p.ID = e.patientId
INNER JOIN 
    staging.dbo.dim_organization hc ON e.organizationID = hc.ID
INNER JOIN 
    staging.dbo.fact_encounter_conditions d ON e.encounter_Id = d.encounter_ID
INNER JOIN 
	staging.dbo.dim_condition dc ON d.condition_code = dc.code
WHERE 
    dc.[description] LIKE '%diabet%' ;  
GO
