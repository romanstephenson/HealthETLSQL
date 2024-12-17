USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dim_organization](
	[ID] [varchar](100) NOT NULL,
	[name] [varchar](100) NULL,
	[address] [varchar](100) NULL,
	[city] [varchar](50) NULL,
	[state] [varchar](50) NULL,
	[zip] [varchar](50) NULL,
	[phone] [varchar](30) NULL,
	[type] [nvarchar](100) NULL,
	[created_dt] [datetime] NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
ALTER TABLE [dbo].[dim_organization] ADD  CONSTRAINT [PK_dim_organization] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dim_organization] ADD  CONSTRAINT [DF_dim_organization_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO
