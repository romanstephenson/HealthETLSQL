USE STAGING;

GO

-- Create a new table called '[patientID]' in schema '[dbo]'
-- Drop the table if it already exists
IF OBJECT_ID('[dbo].[fact_Identification]', 'U') IS NOT NULL
DROP TABLE [dbo].[fact_Identification]
GO
-- Create the table in the specified schema
CREATE TABLE [dbo].[fact_Identification]
(
    [Id] INT IDENTITY(10,1) NOT NULL PRIMARY KEY, -- Primary Key column
    [personNumber] NVARCHAR(50) NOT NULL,
    [idNumber] NVARCHAR(50) NULL,
    [idTypeName] NVARCHAR(50) NULL,
    [idShortCode] NVARCHAR(50) NULL
);
GO

CREATE INDEX idxIdentifiation
ON [dbo].[fact_Identification] (idNumber)

CREATE INDEX idxPerson
ON [dbo].[fact_Identification] (personNumber)