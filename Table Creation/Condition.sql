USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[dim_condition]; 
GO  
CREATE TABLE [dbo].[dim_condition](
	[ID] INT IDENTITY(1,1) NOT NULL,
	[code] [varchar](100) NOT NULL,
	[description] [nvarchar](250) NULL,
	[START] DATE NULL,
	[END] DATE NULL,
	[patient] [nvarchar](250) NULL,
	[encounter] [nvarchar](100) NULL,
	[system] [nvarchar](100) NULL,
	[created_dt] datetime NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
-- GO
-- ALTER TABLE [dbo].[dim_condition] ADD  CONSTRAINT [PK_dim_condition] PRIMARY KEY CLUSTERED 
-- (
-- 	[code] ASC
-- )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dim_condition] ADD  CONSTRAINT [DF_dim_condition_created_dt]  DEFAULT (getdate()) FOR [created_dt]
GO