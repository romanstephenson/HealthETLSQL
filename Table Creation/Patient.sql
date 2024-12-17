USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dim_patient](
	[ID] [varchar](100) NULL,
	[DOB] [date] NULL,
	[DOD] [date] NULL,
	[SSN] [varchar](10) NULL,
	[prefix] [varchar](10) NULL,
	[firstname] [varchar](50) NULL,
	[lastname] [varchar](50) NULL,
	[suffix] [nvarchar](10) NULL,
	[maiden] [varchar](50) NULL,
	[marital] [varchar](5) NULL,
	[race] [varchar](15) NULL,
	[ethnicity] [varchar](50) NULL,
	[gender] [varchar](5) NULL,
	[address] [varchar](50) NULL,
	[city] [varchar](50) NULL,
	[state] [varchar](50) NULL,
	[zip] [varchar](50) NULL
) ON [PRIMARY]
GO
