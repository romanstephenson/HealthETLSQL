USE STAGING;

DECLARE @JSON NVARCHAR(MAX)

SELECT top 1 @JSON = JSONDOCUMENT 
FROM [dbo].[JSONLogs] where cast([IMPORTDATE] as date ) = '2024-11-30' order by IMPORTDATE desc

SELECT REPLACE(entry.fullUrl,'urn:uuid:','') patientID,
	entry.resourceType,
	personname.prefix, 
	personname.family, 
	personname.given, 
	resource.gender, 
	resource.birthDate, 
	ind_address.line address,
	ind_address.city,
	ind_address.state,
	ind_address.country,
	extension.race,
	contact.value as contactvalue, 
	contact.system as contactmethod, 
	contact.[use] contacttype,
	language.languagespoken,
	maritalStatus.maritalValue
	-- identifier.type idshortcode,
	-- identifier.name idtypename,
	-- identifier.value idnumber
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
		resource nvarchar(max) as json
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		name nvarchar(max) as json,
		telecom nvarchar(max) as json,
		gender nvarchar(500),
		birthDate datetime,
		address nvarchar(max) as json,
		communication nvarchar(max) as json,
		maritalStatus nvarchar(max) as json,
		identifier nvarchar(max) as json,
		extension nvarchar(max) as json
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
OUTER APPLY OPENJSON(resource.communication)
	WITH 
	(
		languageSpoken VARCHAR(50) '$.language.coding[0].display'
	) as language
OUTER APPLY OPENJSON(resource.maritalStatus)
	WITH 
	(
		maritalValue VARCHAR(50) '$.coding[0].code'
	) as maritalStatus
OUTER APPLY OPENJSON(resource.identifier)
	WITH 
	(
		type VARCHAR(50) '$.type.coding[0].code',
		name VARCHAR(50) '$.type.coding[0].display',
		value VARCHAR(50) 
	) as identifier
OUTER APPLY OPENJSON(resource.extension)
	WITH 
	(
		race NVARCHAR(max) '$.extension[0].valueCoding.display'
	) as extension
WHERE entry.resourceType in ('Patient')