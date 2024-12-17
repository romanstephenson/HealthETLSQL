USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_with_encounters] AS
SELECT 
    fc.claimId,
    fc.claimStatus,
    fc.claimTotal,
    fc.claimbillablePeriodStart,
    fc.claimbillablePeriodEnd,
    e.encounter_Id,
    e.start as encounterDate,
    e.encounter_class
FROM 
    staging.dbo.fact_claim fc
JOIN 
    staging.dbo.fact_encounters e ON fc.encounterId = e.encounter_Id;
GO
