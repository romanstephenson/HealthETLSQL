USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[dim_practitioner]; 
GO  
CREATE TABLE [dbo].[dim_practitioner](
	[ID] [varchar](100) NOT NULL,
	[prefix] [varchar](10) NULL,
	[firstname] [varchar](50) NULL,
	[lastname] [varchar](50) NULL,
	[gender] [varchar](20) NULL,
	[address] [varchar](100) NULL,
	[city] [varchar](50) NULL,
	[state] [varchar](50) NULL,
	[zip] [varchar](50) NULL,
	[contactvalue] [varchar](100) NULL,
	[contacttype] [varchar](100) NULL,
	[contactmethod] [varchar](100) NULL,
	[created_dt] datetime NOT NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
ALTER TABLE [dbo].[dim_practitioner] ADD  CONSTRAINT [PK_dim_practitioner] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dim_practitioner] ADD  CONSTRAINT [DF_dim_practitioner_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO