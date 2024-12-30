USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[dim_patient]; 
GO  
CREATE TABLE [dbo].[dim_patient](
	[ID] [varchar](100) NOT NULL,
	[DOB] [date] NOT NULL,
	[DOD] [date] NULL,
	[SSN] [varchar](10) NULL,
	[prefix] [varchar](10) NULL,
	[firstname] [varchar](50) NOT NULL,
	[lastname] [varchar](50) NOT NULL,
	[suffix] [nvarchar](10) NULL,
	[maiden] [varchar](50) NULL,
	[marital] [varchar](5) NULL,
	[race] [varchar](15) NULL,
	[ethnicity] [varchar](50) NULL,
	[gender] [varchar](5) NULL,
	[address] [varchar](50) NULL,
	[city] [varchar](50) NULL,
	[state] [varchar](50) NULL,
	[zip] [varchar](50) NULL,
	[created_dt] [datetime] NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
ALTER TABLE [dbo].[dim_patient] ADD  CONSTRAINT [PK_dim_patient] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dim_patient] ADD  CONSTRAINT [DF_dim_patient_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO