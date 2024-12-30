USE JSONDATASTORE;

DECLARE @JSON NVARCHAR(MAX)

SELECT @JSON = JSONDOCUMENT 
FROM DBO.JSONDOCUMENTS

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') UID,
	entry.resourceType,
	resource.id,
	resource.status,
	replace(resource.subject,'urn:uuid:','') subject,
	replace(resource.encounter,'urn:uuid:','') encounter,
	resource.periodStart,
	resource.intent,
	categoryCodingDetails.system,
	categoryCodingDetails.code categoryCodingCode,
	categoryCodingDetails.display categoryCodingName,
	replace(resource.careteamID,'urn:uuid:','') careTeamID,
	activityDetail.status activityDetailStatus,
	activityDetail.location activityDetailLocation,
	activityCode.text activityDetailText,
	activityCoding.system activityCodingSystem,
	activityCoding.code activityCodingCode,
	activityCoding.display activityCodingName
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
		subject varchar(max) '$.subject.reference',
		encounter varchar(max) '$.encounter.reference',
		periodStart varchar(max) '$.period.start',
		id varchar(max) '$.id',
		status varchar(max) '$.status',
		intent varchar(max) '$.intent',
		category nvarchar(max) as json,
		careteamID varchar(max) '$.careTeam[0].reference',
		activity nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.category)
	WITH
	(
		coding nvarchar(max) as json,
		text varchar(max) '$.text'
	) as category
OUTER APPLY OPENJSON(category.coding)
	WITH
	(
		system nvarchar(max) '$.system',
		code varchar(max) '$.code',
		display varchar(max) '$.display'
	) as categoryCodingDetails
OUTER APPLY OPENJSON(resource.activity)
	WITH
	(
		detail nvarchar(max) as json
	) as activity
OUTER APPLY OPENJSON(activity.detail)
	WITH
	(
		code nvarchar(max) as json,
		status varchar(max) '$.status',
		location varchar(max) '$.location.display'
	) as activityDetail
OUTER APPLY OPENJSON(activityDetail.code)
	WITH
	(
		coding nvarchar(max) as json,
		text varchar(max) '$.text'
	) as activityCode
OUTER APPLY OPENJSON(activityCode.coding)
	WITH
	(
		system varchar(max) '$.system',
		code varchar(max) '$.code',
		display varchar(max) '$.display'
	) as activityCoding
WHERE entry.resourceType in ('CarePlan')