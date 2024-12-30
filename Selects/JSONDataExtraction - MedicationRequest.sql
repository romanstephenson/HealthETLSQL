USE STAGING;

DECLARE @JSON NVARCHAR(MAX)

SELECT @JSON = JSONDOCUMENT 
FROM DBO.JSONLogs

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') medicationRequestID,
	entry.status medicationRequestStatus,
	entry.intent medicationRequestIntent,
	medCodeDetails.display medicationName,
	medCodeDetails.code medicationCode,
	medicationCoding.[text] medicationCategoryAdministration,
	resource.subject patientId,
	resource.encounter encounterID,
	resource.authoredOn medicationRequestCreated,
	resource.requester doctorID,
	resource.medicationRequestReasonID,
	resource.condition conditionThatCausedMedicationRequest,
	dosageInstruct.asNeededBoolean,
	dosageInstruct.sequence, 
	dosageInstruct.frequency,
	dosageInstruct.period,
	dosageInstruct.periodUnit,
	dosageInstruct.dosageQuantity
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
		extension nvarchar(max) as json,
		id varchar(max) '$.resource.id',
		status varchar(max) '$.resource.status',
		intent varchar(max) '$.resource.intent',
		medicationCodeableConcept nvarchar(max) as json
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		medicationCodeableConcept nvarchar(max) as json,
		subject varchar(max) '$.subject.reference',
		encounter varchar(max) '$.encounter.reference',
		authoredOn varchar(max) '$.authoredOn',
		requester varchar(max) '$.requester.reference',
		display varchar(max) '$.requester.display',
		medicationRequestReasonID varchar(max) '$.reasonReference.reference',
		condition varchar(max) '$.reasonReference.display',
		dosageInstruction nvarchar(max) as json
	) as resource
OUTER APPLY OPENJSON(resource.medicationCodeableConcept)
	WITH
	(
		coding nvarchar(max) as json,
		[text] nvarchar(max)
	) as medicationCoding
OUTER APPLY OPENJSON(medicationCoding.coding)
	with
	(
		system nvarchar(max),
		code nvarchar(max),
		display nvarchar(max)
	) as medCodeDetails
OUTER APPLY OPENJSON(resource.dosageInstruction)
	with
	(
		sequence nvarchar(max),
		asNeededBoolean bit,
		frequency NVARCHAR(max) '$.timing.repeat.frequency',
		period NVARCHAR(max) '$.timing.repeat.period',
		periodUnit NVARCHAR(max) '$.timing.repeat.periodUnit',
		dosageQuantity NVARCHAR(200)
	) as dosageInstruct
WHERE entry.resourceType in ('MedicationRequest')