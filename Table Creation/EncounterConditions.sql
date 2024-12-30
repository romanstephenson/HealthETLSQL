USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[fact_encounter_conditions]; 
GO  
CREATE TABLE [dbo].[fact_encounter_conditions](
	[patientID] [varchar](100) NOT NULL,
	[encounter_ID] [varchar](100) NOT NULL,
	[condition_code] [varchar](50) NOT NULL,
	[start] [date] NULL,
	[end] [date] NULL,
	[created_dt] [datetime] NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
ALTER TABLE [dbo].[fact_encounter_conditions] ADD  CONSTRAINT [PK_encounter_conditions] PRIMARY KEY CLUSTERED 
(
	[patientID] ASC,
	[encounter_ID] ASC,
	[condition_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[fact_encounter_conditions] ADD  CONSTRAINT [DF_dim_fact_encounter_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO

