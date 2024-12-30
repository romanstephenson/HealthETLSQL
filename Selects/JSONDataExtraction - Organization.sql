USE STAGING;

DECLARE @JSON NVARCHAR(MAX)

SELECT @JSON = JSONDOCUMENT 
FROM [dbo].[JSONLogs]

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') UID,
	resource.name,
	address.line + ',' + address.country AS ADDRESS,
	address.city,
	address.state,
	address.postalCode AS ZIP,
	telecom.value as phone,
	type.text as TYPE
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
		name nvarchar(max),
		telecom nvarchar(max) as json,
		gender nvarchar(500),
		birthDate datetime,
		active bit, --nvarchar(max),
		address nvarchar(max) as json,
		type nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.type)
	WITH
	(
		text varchar(max),
		coding nvarchar(max) as json
	) as type
OUTER APPLY OPENJSON(type.coding)
	WITH
	(
		system varchar(max),
		code nvarchar(max),
		display nvarchar(max)
	) as coding
OUTER APPLY OPENJSON(resource.telecom)
	WITH
	(
		system varchar(max),
		value nvarchar(max)
	) as telecom
OUTER APPLY OPENJSON(resource.address)
	WITH
	(
		line nvarchar(max) '$.line[0]',
		city nvarchar(max),
		state nvarchar(max),
		postalCode nvarchar(max),
		country nvarchar(max)
	) as address
WHERE entry.resourceType in ('Organization')