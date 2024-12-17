USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[fact_claim](
	[Id] [int] IDENTITY(10,1) NOT NULL,
	[claimId] [nvarchar](100) NOT NULL,
	[claimStatus] [varchar](20) NULL,
	[claimUse] [varchar](50) NULL,
	[claimPatientId] [varchar](100) NOT NULL,
	[claimbillablePeriodStart] [datetime] NOT NULL,
	[claimbillablePeriodEnd] [datetime] NOT NULL,
	[claimCreated] [datetime] NULL,
	[claimProviderReference] [nvarchar](500) NULL,
	[claimPriorityCode] [varchar](50) NULL,
	[claimPrescriptionId] [varchar](100) NULL,
	[claimFocal] [bit] NULL,
	[insuranceSequence] [int] NULL,
	[claimCoverage] [varchar](100) NULL,
	[itemSequence] [int] NULL,
	[claimCode] [varchar](100) NULL,
	[encounterId] [nvarchar](100) NULL,
	[claimTotal] [money] NULL,
	[claimCurrency] [varchar](10) NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_claim] ADD PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_claim_1] ON [dbo].[fact_claim]
(
	[claimId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX [CSIndex_fact_claim_1] ON [dbo].[fact_claim]
(
	[claimPatientId]
)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]
GO
