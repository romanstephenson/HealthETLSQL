USE STAGING;

DECLARE @JSON NVARCHAR(MAX), @filename nvarchar(max)

SELECT @JSON = JSONDOCUMENT, @filename = FILENAME
FROM [dbo].[JSONLogs]

SELECT 
	REPLACE(entry.fullUrl,'urn:uuid:','') ExplanationOfBenefitId,
	entry.status,
	entry.[use] ExplanationOfBenefitUse,
	ExplanationOfBenefitCodingDetails.code ExplanationOfBenefitCodingDetailsCode,
	replace(resource.patient, 'urn:uuid:','') patientID,
	resource.billablePeriodStart,
	resource.billablePeriodEnd,
	resource.created,
	replace(resource.providerReference, 'urn:uuid:','') providerReference,
	insuranceDetails.coverage,
	item.itemSequence,
	itemProductOrderServiceCode.code itemProductOrderServiceCode,
	--productOrServiceCoding.text,
	contained.containedResourceType,
	contained.id containedId,
	contained.containedStatus,
	contained.containedIntent,
	replace(contained.containedSubject,'urn:uuid:','') containedSubject,
	replace(contained.containedReference,'urn:uuid:','') containedReference,
	replace(contained.containedPerformer,'urn:uuid:','') containedPerformer,
	containedType,
	replace(containedBeneficiary,'urn:uuid:','') containedBeneficiary,
	containedPayor,
	replace(item.itemEncounterId,'urn:uuid:','') itemEncounterId,
	resource.outcome,
	careTeamRoleData.roleCode,
	careTeamRoleData.roleName careTeamRoleName,
	careTeam.careTeamSequence,
	replace(careTeam.careTeamProvider,'urn:uuid:','') careTeamProvider,
	item.itemcategoryCode,
	item.itemcategoryName,
	item.servicePeriodStart,
	item.servicePeriodEnd,
	itemLocationCodeableConceptCodingDetails.code as locationCodeableConceptCode,
	itemLocationCodeableConceptCodingDetails.display as locationCodeableConceptName,
	total.currency ExplanationOfBenefitCurrency,
	total.amount ExplanationOfBenefitTotalAmount,
	totalCategoryCoding.code,
	totalCategoryCoding.display,
	resource.paymentAmountValue,
	resource.paymentAmountCurrency
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
		created varchar(max),
		providerReference varchar(max) '$.provider.reference',
		priority nvarchar(max) as json,
		prescription varchar(max) '$.prescription.reference',
		insurance nvarchar(max) as json,
		item nvarchar(max) as json,
		contained nvarchar(max) as json,
		outcome varchar(max) '$.outcome',
		careTeam nvarchar(max) as json,
		total nvarchar(max) as json,
		paymentAmountValue money '$.payment.amount.value',
		paymentAmountCurrency varchar(max) '$.payment.amount.currency'
	) as resource
OUTER APPLY OPENJSON(resource.contained)
	WITH
	(
		containedResourceType varchar(max) '$.resourceType',
		id varchar(max),
		containedStatus varchar(max) '$.status',
		containedIntent varchar(max) '$.intent',
		containedSubject varchar(max) '$.subject.reference',
		containedReference varchar(max) '$.requester.reference',
		containedPerformer varchar(max) '$.performer[0].reference',
		containedType varchar(max) '$.type.text',
		containedBeneficiary varchar(max) '$.beneficiary.reference',
		containedPayor varchar(max) '$.payor[0].display'
	) as contained
OUTER APPLY OPENJSON(resource.careTeam)
	WITH
	(
		careTeamSequence varchar(max) '$.sequence',
		careTeamProvider varchar(max) '$.provider.reference',
		role nvarchar(max) as json
	) as careTeam
OUTER APPLY OPENJSON(careTeam.role)
	WITH
	(
		
		roleSystem varchar(max) '$.coding[0].system',
		roleCode varchar(max) '$.coding[0].code',
		roleName varchar(max) '$.coding[0].display'
	) as careTeamRoleData
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
	) as ExplanationOfBenefitCoding
OUTER APPLY OPENJSON(ExplanationOfBenefitCoding.coding)
	WITH
	(
		system nvarchar(max),
		code nvarchar(max)
	) as ExplanationOfBenefitCodingDetails
OUTER APPLY OPENJSON(resource.item)
	WITH
	(
		itemSequence int '$.sequence',
		itemcategorySystem varchar(max) '$.category.coding[0].system',
		itemcategoryCode varchar(max) '$.category.coding[0].code',
		itemcategoryName varchar(max) '$.category.coding[0].display',
		productOrService nvarchar(max) as json,
		itemEncounterId nvarchar(max) '$.encounter[0].reference',
		servicePeriodStart nvarchar(max) '$.servicedPeriod.start',
		servicePeriodEnd nvarchar(max) '$.servicedPeriod.end',
		locationCodeableConcept nvarchar(max) as json
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
OUTER APPLY OPENJSON(item.locationCodeableConcept)
	WITH
	(
		coding nvarchar(max) as json
	) as itemLocationCodeableConcept
OUTER APPLY OPENJSON(itemLocationCodeableConcept.coding)
	WITH
	(
		code nvarchar(max),
		display varchar(max)
	) as itemLocationCodeableConceptCodingDetails
OUTER APPLY OPENJSON(resource.total)
	WITH
	(
		category nvarchar(max) as json,
		amount varchar(max) '$.amount.value',
		currency varchar(max) '$.amount.currency'
	) as total
OUTER APPLY OPENJSON(total.category)
	WITH
	(
		coding nvarchar(max) as json
	) as totalCategory
OUTER APPLY OPENJSON(totalCategory.coding)
	WITH
	(
		code varchar(max),
		display varchar(max)
	) as totalCategoryCoding
WHERE entry.resourceType in ('ExplanationOfBenefit')