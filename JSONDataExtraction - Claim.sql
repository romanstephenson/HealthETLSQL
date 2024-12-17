USE STAGING;

DECLARE @JSON NVARCHAR(MAX), @filename nvarchar(max)

SELECT @JSON = JSONDOCUMENT, @filename = FILENAME
FROM [dbo].[JSONLogs]

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') claimId,
	entry.status claimStatus,
	entry.[use] claimUse,
	replace(resource.patient, 'urn:uuid:','') claimPatientId,
	resource.billablePeriodStart claimbillablePeriodStart,
	resource.billablePeriodEnd claimbillablePeriodEnd,
	resource.created claimCreated,
	replace(resource.providerReference, 'urn:uuid:','') claimproviderReference,
	priorityDetails.priorityCode claimPriorityCode,
	replace(resource.prescription, 'urn:uuid:','') claimPrescriptionId,
	insuranceDetails.focal claimFocal,
	insuranceDetails.insuranceSequence,
	insuranceDetails.coverage claimCoverage,
	item.itemSequence,
	claimCodeDetails.code claimCode,
	replace(item.itemEncounterId,'urn:uuid:','') encounterId,
	resource.total claimTotal,
	resource.currency claimCurrency
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
		[use] varchar(max) '$.resource.use'
	) as entry
OUTER APPLY OPENJSON(entry.resource)
	WITH
	(
		type nvarchar(max) as json,
		patient varchar(max) '$.patient.reference',
		billablePeriodStart varchar(max) '$.billablePeriod.start',
		billablePeriodEnd varchar(max) '$.billablePeriod.end',
		created varchar(max), --'$.resource.created',
		providerReference varchar(max) '$.provider.reference',
		providerName varchar(max) '$.provider.display',
		priority nvarchar(max) as json,
		prescription varchar(max) '$.prescription.reference',
		insurance nvarchar(max) as json,
		item nvarchar(max) as json,
		total money '$.total.value',
		currency varchar(max) '$.total.currency'
	) as resource
OUTER APPLY OPENJSON(resource.insurance)
	WITH
	(
		insuranceSequence int '$.sequence',
		focal bit,
		coverage varchar(max) '$.coverage.display'
	) as insuranceDetails
OUTER APPLY OPENJSON(resource.priority)
	WITH
	(
		coding nvarchar(max) as json
	) as priorityCoding
OUTER APPLY OPENJSON(priorityCoding.coding)
	WITH
	(
		prioritySystem varchar(max) '$.system',
		priorityCode varchar(max) '$.code'
	) as priorityDetails
OUTER APPLY OPENJSON(resource.type)
	WITH
	(
		coding nvarchar(max) as json
	) as claimCoding
OUTER APPLY OPENJSON(claimCoding.coding)
	WITH
	(
		system nvarchar(max),
		code nvarchar(max)
	) as claimCodeDetails
OUTER APPLY OPENJSON(resource.item)
	WITH
	(
		itemSequence int '$.sequence',
		productOrService nvarchar(max) as json,
		itemEncounterId nvarchar(max) '$.encounter[0].reference'
	) as item
OUTER APPLY OPENJSON(item.productOrService)
	WITH
	(
		coding nvarchar(max) as json,
		text varchar(max)
	) as productOrServiceCoding
OUTER APPLY OPENJSON(productOrServiceCoding.coding)
	WITH
	(
		system nvarchar(max),
		code nvarchar(max),
		display nvarchar(max)
	) as itemProductOrderServiceCode
WHERE entry.resourceType in ('Claim')