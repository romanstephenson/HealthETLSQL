USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[fact_encounters]; 
GO  
CREATE TABLE [dbo].[fact_encounters](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[encounter_ID] [nvarchar](100) NOT NULL,
	[start] [datetime] NULL,
	[end] [datetime] NULL,
	[patientID] [nvarchar](100) NULL,
	[organizationID] [nvarchar](100) NULL,
	[practitionerID] [nvarchar](100) NULL,
	[encounter_class] [varchar](100) NULL,
	[encounter_code] [varchar](100) NULL,
	[encounter_description] [varchar](100) NULL,
	[encounterReasonName] [varchar](500) NULL,
	[encounterReasonCode] [varchar](500) NULL,
	[CREATE_DT] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_encounters] ADD  CONSTRAINT [PK_fact_encounters] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_encounters_1] ON [dbo].[fact_encounters]
(
	[encounter_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_encounters_2] ON [dbo].[fact_encounters]
(
	[organizationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_encounters_3] ON [dbo].[fact_encounters]
(
	[patientID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [Index_fact_encounters_4] ON [dbo].[fact_encounters]
(
	[practitionerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_encounters] ADD  DEFAULT (getdate()) FOR [CREATE_DT]
GO
