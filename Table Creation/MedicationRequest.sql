USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[fact_medication_request](
	[ID] [int] IDENTITY(100,1) NOT NULL,
	[medicationRequestID] [nvarchar](100) NULL,
	[medicationRequestStatus] [nvarchar](100) NULL,
	[medicationRequestIntent] [nvarchar](100) NULL,
	[medicationName] [nvarchar](500) NULL,
	[medicationCode] [nvarchar](100) NULL,
	[medicationCategoryAdministration] [nvarchar](200) NULL,
	[patientId] [nvarchar](100) NULL,
	[encounterID] [nvarchar](100) NULL,
	[medicationRequestCreated] [datetime] NULL,
	[doctorID] [nvarchar](100) NULL,
	[medicationRequestReasonID] [nvarchar](100) NULL,
	[conditionThatCausedMedicationRequest] [nvarchar](100) NULL,
	[asNeededBoolean] [bit] NULL,
	[sequence] [int] NULL,
	[frequency] [int] NULL,
	[period] [float] NULL,
	[periodUnit] [char](10) NULL,
	[dosageQuantity] [float] NULL,
	[created_dt] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_medication_request] ADD  CONSTRAINT [PK_fact_medication_request] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_medication_request_1] ON [dbo].[fact_medication_request]
(
	[doctorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_medication_request_2] ON [dbo].[fact_medication_request]
(
	[medicationRequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_medication_request_3] ON [dbo].[fact_medication_request]
(
	[patientId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX [CSIndex_fact_medication_request_3] ON [dbo].[fact_medication_request]
(
	[encounterID]
)WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_medication_request] ADD  CONSTRAINT [DEFAULT_fact_medication_request_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO
