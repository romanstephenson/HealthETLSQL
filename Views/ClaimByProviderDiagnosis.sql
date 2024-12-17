USE claimdatamart;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_claims_by_provider_diagnosis] AS
SELECT 
    fc.claimProviderReference,
    fc.claimCode AS diagnosisCode,
    COUNT(*) AS claimCount,
    SUM(fc.claimTotal) AS totalClaimAmount
FROM 
    staging.dbo.fact_claim fc
GROUP BY 
    fc.claimProviderReference, fc.claimCode;
GO
