USE STAGING;

DECLARE @JSON NVARCHAR(MAX)

SELECT top 1 @JSON = JSONDOCUMENT 
FROM [dbo].[JSONLogs]

SELECT REPLACE(entry.fullUrl,'urn:uuid:','') personNumber,
	identifier.type idshortcode,
	identifier.name idtypename,
	identifier.value idnumber
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
		identifier nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.identifier)
	WITH 
	(
		type VARCHAR(50) '$.type.coding[0].code',
		name VARCHAR(50) '$.type.coding[0].display',
		value VARCHAR(50) 
	) as identifier
WHERE entry.resourceType in ('Patient') and identifier.TYPE IS NOT NULL