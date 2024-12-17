USE STAGING;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Function [dbo].[udf_RemoveNumericCharacters](@Temp VarChar(MAX))
Returns VarChar(MAX)
AS
Begin

    Declare @NumRange as varchar(50) = '%[0-9]%'
    While PatIndex(@NumRange, @Temp) > 0
        Set @Temp = Stuff(@Temp, PatIndex(@NumRange, @Temp), 1, '')

    Return @Temp
End
GO
