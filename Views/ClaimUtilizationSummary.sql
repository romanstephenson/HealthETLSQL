USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_utilization_summary] AS
SELECT 
    YEAR(claimbillablePeriodStart) AS claimYear,
    MONTH(claimbillablePeriodStart) AS claimMonth,
    COUNT(*) AS totalClaims,
    SUM(claimTotal) AS totalClaimAmount
FROM 
    staging.dbo.fact_claim
GROUP BY 
    YEAR(claimbillablePeriodStart), MONTH(claimbillablePeriodStart);
--ORDER BY YEAR(claimbillablePeriodStart), MONTH(claimbillablePeriodStart)
GO
