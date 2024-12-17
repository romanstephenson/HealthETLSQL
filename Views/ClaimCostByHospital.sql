USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_CostByHospital] AS
SELECT 
	YEAR(fc.claimbillablePeriodStart) AS claimYear,
    MONTH(fc.claimbillablePeriodStart) AS claimMonth,
    hc.[Name] AS HospitalName,
    COUNT(fc.claimId) AS TotalClaims,
    SUM(fc.claimTotal) AS TotalClaimCost,
    AVG(fc.claimTotal) AS AverageClaimCost
FROM 
    staging.dbo.fact_claim fc
INNER JOIN 
    staging.dbo.fact_encounters e ON fc.encounterId = e.encounter_Id
INNER JOIN 
    staging.dbo.dim_organization hc ON e.organizationID = hc.ID
GROUP BY 
	YEAR(claimbillablePeriodStart), MONTH(claimbillablePeriodStart), hc.Name;
GO
