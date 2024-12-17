USE STAGING;

-- Create a new table called '[fact_EplanationOfBenefit]' in schema '[dbo]'
-- Drop the table if it already exists
IF OBJECT_ID('[dbo].[fact_EplanationOfBenefit]', 'U') IS NOT NULL
DROP TABLE [dbo].[fact_EplanationOfBenefit]
GO
-- Create the table in the specified schema
CREATE TABLE [dbo].[fact_EplanationOfBenefit]
(
    [Id] INT IDENTITY(10,1) NOT NULL PRIMARY KEY, -- Primary Key column
    claimId NVARCHAR(100) NOT NULL,
    claimStatus VARCHAR(20) NULL,
    claimUse VARCHAR(50) NULL,
    claimPatientId varchar(100) NOT NULL,
    claimbillablePeriodStart DATETIME not NULL,
    claimbillablePeriodEnd DATETIME not NULL,
    claimCreated DATETIME not null,
    claimProviderReference NVARCHAR(100) not null,
    claimPriorityCode VARCHAR(50) null,
    claimPrescriptionId VARCHAR(100) null,
    claimFocal bit null,
    insuranceSequence int null,
    claimCoverage VARCHAR(100) null,
    itemSequence int null,
    claimCode int null,
    encounterId NVARCHAR(100) null,
    claimTotal money null,
    claimCurrency VARCHAR(10)
);
GO

CREATE INDEX idxClaimId 
ON dbo.fact_claim (claimId)

CREATE INDEX idxPrescription
ON dbo.fact_claim (claimPrescriptionId)

CREATE INDEX idxEncounter 
ON dbo.fact_claim (encounterId)



