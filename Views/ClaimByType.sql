USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_by_ClaimType] AS
SELECT 
    fc.claimId,
    fc.claimCode AS ClaimType,
    COUNT(*) AS procedureCount,
    SUM(fc.claimTotal) AS totalClaimAmount
FROM 
    staging.dbo.fact_claim fc
GROUP BY 
    fc.claimId, fc.claimCode;
GO
