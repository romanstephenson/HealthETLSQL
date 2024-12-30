USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[dim_organization]; 
GO  
CREATE TABLE [dbo].[dim_organization](
	[ID] [varchar](100) NOT NULL,
	[name] [varchar](500) NULL,
	[address] [varchar](200) NULL,
	[city] [varchar](200) NULL,
	[state] [varchar](200) NULL,
	[zip] [varchar](100) NULL,
	[lat] [float] NULL,
	[lon] [float] NULL,
	[phone] [varchar](100) NULL,
	[revenue] [float] NULL,
	[utilization] [int] NULL,
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
