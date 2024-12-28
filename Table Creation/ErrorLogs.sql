USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP TABLE IF EXISTS [dbo].[import_error_logs]; 
GO  
CREATE TABLE [dbo].[import_error_logs](
	[_ID] [int] IDENTITY(1,1) NOT NULL,
	[FILENAME] [nvarchar](250) NULL,
	[ERRORNUMBER] [int] NULL,
	[ERRORLINE] [int] NULL,
	[ERRORMESSAGE] [nvarchar](MAX) NULL,
	[IMPORTDATETIME] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[import_error_logs] ADD  CONSTRAINT [PK_import_error_logs] PRIMARY KEY CLUSTERED 
(
	[_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
