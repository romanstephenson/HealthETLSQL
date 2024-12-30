USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[IMPORT_JSON_FILES] 
	
	@FullFilePathName NVARCHAR(max),
	@FileNameOnly NVARCHAR(500)
	
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @sqlUpdate varchar(max)

	SET @FullFilePathName = REPLACE(@FullFilePathName, '''', '''''');
	SET @FileNameOnly = REPLACE(@FileNameOnly, '''', '''''');

	IF not exists ( Select * from dbo.JSONlogs where [filename] = @FullFilePathName)
	
		BEGIN

			SET @sqlUpdate = 
							'Declare @JSONFileData varchar(max)
							SELECT @JSONFileData = BulkColumn FROM OPENROWSET (BULK N''' + @FullFilePathName + ''', 
							SINGLE_CLOB) as JSON

							INSERT INTO JSONlogs(JSONDOCUMENT, Filename,importDate)
							SELECT  BulkColumn, N''' + @FileNameOnly + ''', GETDATE() FROM OPENROWSET (BULK N''' + @FullFilePathName + ''', 
							SINGLE_CLOB) as JSON'
			BEGIN TRY	
				EXEC (@sqlupdate)

				RETURN 1
			END TRY

			BEGIN CATCH
				
				INSERT INTO dbo.import_error_logs([FILENAME], ERRORNUMBER, ERRORLINE,ERRORMESSAGE,IMPORTDATETIME)
				SELECT @FullFilePathName
					, ERROR_NUMBER()
					, ERROR_LINE()
					,  ERROR_MESSAGE()
					, GETDATE() 

				RETURN 2
			END CATCH
		END
	ELSE
		BEGIN
			RETURN 3
		END

END
GO
