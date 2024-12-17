USE STAGING;

DECLARE @JSON NVARCHAR(MAX), @filename nvarchar(max)

SELECT @filename = [filename], @JSON = JSONDOCUMENT 
FROM [dbo].[JSONLogs] WHERE CAST(IMPORTDATE AS DATE) = '2024-12-02'

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') encounterID,
	CAST(period.[start] AS DATE) [START],
	CAST(period.[end] AS DATE) [END],
	REPLACE(subject.reference,'urn:uuid:','') as patientID,
	RIGHT(serviceProvider.organizationID, CHARINDEX('|', REVERSE(serviceProvider.organizationID)) - 1) as organizationID,
	RIGHT(practitoner.practitionerID, CHARINDEX('|', REVERSE(practitoner.practitionerID)) - 1) as practitionerID,
	resource.encounter_class,
	coding.code as encounter_code,
	coding.display as encounter_description,
	resource.reasonCodeValue,
	reasonCode.display as encounterReasonName,
	reasonCode.code as encounterReasonCode
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
		status varchar(1000),
		address nvarchar(max) as json,
		type nvarchar(max) as json,
		participant nvarchar(max) as json,
		subject nvarchar(max) as json,
		period nvarchar(max) as json,
		reasonCode nvarchar(max) as json,
		--reasonCodeValue nvarchar(max) '$.reasonCode[0].coding.code',
		serviceProvider nvarchar(max) as json,
		encounter_class nvarchar(max) '$.class.code'
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
OUTER APPLY OPENJSON(resource.subject)
	WITH
	(
		reference varchar(max),
		display nvarchar(max)
	) as subject
OUTER APPLY OPENJSON(resource.period)
	WITH
	(
		[start] varchar(max),
		[end] varchar(max)
	) as period
OUTER APPLY OPENJSON(resource.participant)
	WITH
	(
		individual nvarchar(max) as json
	) as participantDetails
OUTER APPLY OPENJSON(participantDetails.individual)
	WITH
	(
		practitionerID nvarchar(500) '$.reference',
		practionerName nvarchar(500) '$.display'
	) as practitoner
OUTER APPLY OPENJSON(resource.reasonCode)
	WITH
	(
		coding nvarchar(max) as json
	) as reason
OUTER APPLY OPENJSON(reason.coding)
	WITH
	(
		code varchar(500),
		display varchar(500) 
	) as reasonCode
OUTER APPLY OPENJSON(resource.serviceProvider)
	WITH
	(
		organizationID nvarchar(500) '$.reference'
	) as serviceProvider
WHERE entry.resourceType in ('Encounter')