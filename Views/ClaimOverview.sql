USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_overview] AS
SELECT 
    claimStatus,
    claimUse,
    COUNT(*) AS claimCount,
    SUM(claimTotal) AS totalClaimAmount,
    AVG(claimTotal) AS averageClaimAmount,
    MIN(claimbillablePeriodStart) AS earliestClaimDate,
    MAX(claimbillablePeriodEnd) AS latestClaimDate
FROM 
     STAGING.dbo.fact_claim fc 
GROUP BY 
    claimStatus, claimUse;
GO
