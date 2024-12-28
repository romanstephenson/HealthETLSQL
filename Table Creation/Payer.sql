USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[dim_payer]; 
GO  
CREATE TABLE [dbo].[dim_payer](
	[ID] [varchar](100) NOT NULL,
	[name] [varchar](100) NULL,
	[address] [varchar](300) NULL,
	[city] [varchar](100) NULL,
	[state] [varchar](100) NULL,
	[zip] [varchar](100) NULL,
	[phone] [varchar](100) NULL,
	[created_dt] [datetime] NOT NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
ALTER TABLE [dbo].[dim_payer] ADD  CONSTRAINT [PK_dim_payer] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dim_payer] ADD  CONSTRAINT [DF_dim_payer_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO

