--CREATE DATABASE JSONDATASTORE;
--GO
--USE JSONDATASTORE;

--ALTER DATABASE JSONDATASTORE
--SET COMPATIBILITY_LEVEL = 160;
--GO

--CREATE TABLE DBO.JSONDOCUMENTS
--(
--	ID INT IDENTITY(10,1) PRIMARY KEY,
--	JSONDOCUMENT NVARCHAR(MAX) NOT NULL
--);

---- Load file contents into a table
--INSERT INTO JSONDOCUMENTS(JSONDOCUMENT)
--SELECT BULKCOLUMN
--FROM OPENROWSET(BULK 'C:\Users\steph\Downloads\fhir\Alesha810_Marks830_1e0a8bd3-3b82-4f17-b1d6-19043aa0db6b.json', SINGLE_CLOB) as j
USE JSONDATASTORE;

DECLARE @JSON NVARCHAR(MAX)

SELECT @JSON = JSONDOCUMENT 
FROM DBO.JSONDOCUMENTS

SELECT REPLACE(entry.fullUrl,'urn:uuid:','') UID,
	--entry.fullUrl,
	entry.resourceType,
	personname.prefix, 
	personname.family, 
	personname.given, 
	resource.gender, 
	resource.birthDate, 
	ind_address.line,
	ind_address.city,
	ind_address.state,
	ind_address.country,
	contact.value as phoneoremail, 
	contact.system as method, 
	contact.[use]
FROM OPENJSON( @JSON )
	WITH 
	(
		resourceType varchar(max),
		type varchar(400),
		entry nvarchar(max) as json
	) as jsonfile
OUTER APPLY OPENJSON(jsonfile.entry)
	WITH
	(
		fullUrl varchar(max),
		resourceType varchar(250) '$.resource.resourceType',
		resource nvarchar(max) as json,
		extension nvarchar(max) as json
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		name nvarchar(max) as json,
		telecom nvarchar(max) as json,
		gender nvarchar(500),
		birthDate datetime,
		address nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.name)
	WITH
	(
		family nvarchar(max),
		given nvarchar(max) '$.given[0]',
		prefix nvarchar(max) '$.prefix[0]'
	) as personname
OUTER APPLY OPENJSON(resource.telecom)
	WITH
	(
		[use] nvarchar(max),
		value nvarchar(max),
		system nvarchar(max)
	) as contact
OUTER APPLY OPENJSON(resource.address)
	WITH
	(
		line nvarchar(max) '$.line[0]',
		city nvarchar(max),
		state nvarchar(max),
		country nvarchar(max)
	) as ind_address
WHERE entry.resourceType in ('Practitioner','Patient')