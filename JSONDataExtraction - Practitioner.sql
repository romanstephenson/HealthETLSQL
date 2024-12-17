USE STAGING;

DECLARE @JSON NVARCHAR(MAX), @filename nvarchar(max)

SELECT @filename = filename, @JSON = JSONDOCUMENT 
FROM [dbo].[JSONLogs]

SELECT --@filename,
	REPLACE(entry.fullUrl,'urn:uuid:','') practitionerID,
	nameDetails.prefix,
	nameDetails.Given,
	nameDetails.Family,
	resource.gender,
	address.line + ',' + address.country AS ADDRESS,
	address.city,
	address.state,
	address.postalCode AS ZIP,
	telecom.[value] as contactvalue,
	telecom.[use] as contacttype,
	telecom.[system] as contactmethod
FROM OPENJSON( @JSON )
	WITH 
	(
		resourceType varchar(max),
		entry nvarchar(max) as json
	) as jsonfile
OUTER APPLY OPENJSON(jsonfile.entry)
	WITH
	(
		fullUrl varchar(max),
		resourceType varchar(250) '$.resource.resourceType',
		resource nvarchar(max) as json
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		name nvarchar(max) as json,
		telecom nvarchar(max) as json,
		gender nvarchar(500),
		active bit, --nvarchar(max),
		address nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.name)
	WITH
	(
		family varchar(max),
		given nvarchar(max) '$.given[0]',
		prefix nvarchar(max) '$.prefix[0]'
	) as nameDetails
OUTER APPLY OPENJSON(resource.telecom)
	WITH
	(
		system nvarchar(max),-- '$.system',
		value nvarchar(max), --'$.resource.telecom.value',
		[use] nvarchar(max) --'$.resource.telecom.use'
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
WHERE entry.resourceType in ('Practitioner') 
--and REPLACE(entry.fullUrl,'urn:uuid:','') = 'c7bb0ef6-2097-4d12-8306-f170f5c3953a'