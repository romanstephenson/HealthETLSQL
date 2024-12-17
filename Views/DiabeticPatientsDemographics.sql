USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_DiabeticPatient_Demographics] AS
SELECT 
    p.ID as patient_Id,
    [staging].[dbo].[udf_RemoveNumericCharacters](p.firstName) as firstName,
    [staging].[dbo].[udf_RemoveNumericCharacters](p.lastName) as lastName,
    p.gender,
    p.dob,
    DATEDIFF(YEAR, p.dob, GETDATE()) AS age,
    p.race,
    p.ethnicity,
	dc.code,
	dc.description
FROM 
    staging.dbo.dim_patient p
INNER JOIN 
    staging.dbo.fact_encounters e ON p.ID = e.patientId
INNER JOIN 
    staging.dbo.fact_encounter_conditions ec ON e.encounter_Id = ec.encounter_Id
INNER JOIN 
	staging.dbo.dim_condition dc ON ec.condition_code = dc.code
WHERE 
    dc.[description] LIKE '%diabet%'  
GO
