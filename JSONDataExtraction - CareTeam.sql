USE JSONDATASTORE;

DECLARE @JSON NVARCHAR(MAX)

SELECT @JSON = JSONDOCUMENT 
FROM DBO.JSONDOCUMENTS

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') UID,
	entry.resourceType,
	entry.id,
	entry.status,
	replace(resource.subject,'urn:uuid:','') subject,
	replace(resource.encounter,'urn:uuid:','') encounter,
	resource.periodStart,
	role.roleCode,
	role.roleSystem,
	role.roleName,
	replace(participant.roleMemberReference, 'urn:uuid:','') roleMemberReference,
	participant.roleMemberDisplay,
	reasonCodeDetails.reasonSystem,
	reasonCodeDetails.code,
	reasonCodeDetails.reasonNameFromCoding,
	replace(managingOrganization.reference, 'urn:uuid:','') managingOrganizationReference,
	managingOrganization.display managingOrganizationName
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
		id varchar(max) '$.resource.id',
		status varchar(max) '$.resource.status'
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		subject varchar(max) '$.subject.reference',
		encounter varchar(max) '$.encounter.reference',
		periodStart varchar(max) '$.period.start',
		participant nvarchar(max) as json,
		reasonCode nvarchar(max) as json,
		managingOrganization nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.participant)
	WITH
	(
		role nvarchar(max) as json,
		roleMemberReference varchar(max) '$.member.reference',
		roleMemberDisplay varchar(max) '$.member.display'
	) as participant
OUTER APPLY OPENJSON(participant.role)
	WITH
	(
		roleSystem varchar(max) '$.coding[0].system',
		roleCode varchar(max) '$.coding[0].code',
		roleName varchar(max) '$.coding[0].display'
	) as role
OUTER APPLY OPENJSON(resource.reasonCode)
	WITH
	(
		coding nvarchar(max) as json,
		reasonName varchar(max) '$.text'
	) as reasonCode
OUTER APPLY OPENJSON(reasonCode.coding)
	WITH
	(
		reasonSystem varchar(max) '$.system',
		code varchar(max) '$.code',
		reasonNameFromCoding varchar(max) '$.display'
	) as reasonCodeDetails
OUTER APPLY OPENJSON(resource.managingOrganization)
	WITH
	(
		reference varchar(max) '$.reference',
		display varchar(max) '$.display'
	) as managingOrganization
WHERE entry.resourceType in ('CareTeam')