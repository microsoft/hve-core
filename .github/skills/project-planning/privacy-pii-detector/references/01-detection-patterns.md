---
title: Detection Patterns
description: Language-agnostic and language-specific code patterns for identifying PII processing in source code
---

# Detection Patterns

This reference defines the patterns agents use to detect PII processing in codebases. Patterns are organized by detection method and map to PII taxonomy IDs.

## Matching rules

Name patterns in this file, in every industry overlay, and in `.pii-config.yml` custom types match identifier tokens, not raw substrings.

1. Split each identifier into lowercase tokens on camelCase and PascalCase boundaries, `_`, `-`, `.`, and letter-digit boundaries. `icd10Code` becomes `icd`, `10`, `code`; `EMAIL_ADDRESS` becomes `email`, `address`.
2. Split each pattern the same way after removing `*`. A pattern matches when its tokens equal a contiguous run of identifier tokens, or when its joined tokens equal the joined tokens of a contiguous run. `*firstName*` matches `user_first_name`; `*username*` matches `userName` and `user_name`.
3. A pattern never matches part of a token. `*pan*` does not match `company` or `expand`, `*pin*` does not match `mapping`, `*tin*` does not match `setting`, `*sar*` does not match `necessary`, `*lac*` does not match `replace`, and `*condition*` does not match `conditional`.
4. When several patterns match one identifier, report only the most specific match: the pattern with the most tokens, then the longest. `emailAddress` reports PII-002 only, not PII-004; `ipAddress` reports PII-006 only.
5. Short or ambiguous tokens are capped at MEDIUM confidence unless surrounding context confirms the PII type (for example, a card-number format check next to `pan`, or a health resource next to `condition`): `pan`, `pin`, `tin`, `sar`, `lac`, `cgi`, `dna`, `mri`, `npi`, `ndc`, `snp`, `condition`.

Industry and custom types then resolve against core types using the classification order in [00 PII Taxonomy](00-pii-taxonomy.md#classification-rules).

## Detection methods

| Method                  | How it works                                                    | Confidence |
|-------------------------|-----------------------------------------------------------------|------------|
| Naming convention       | Field/variable/column names matching PII patterns               | HIGH       |
| Data annotation         | Decorators, attributes, or comments marking data classification | HIGH       |
| Regex/format validation | Validation patterns that match PII formats                      | HIGH       |
| API signature           | Parameters or return types indicating PII                       | MEDIUM     |
| Schema definition       | Database columns, protobuf fields, GraphQL types                | HIGH       |
| String literal          | Hardcoded PII in tests, seeds, or config                        | MEDIUM     |
| Third-party SDK         | Library calls known to process PII                              | MEDIUM     |
| Log/telemetry output    | Logging statements containing PII fields                        | HIGH       |

## Naming convention patterns

### Field name indicators (case-insensitive, token-matched per [Matching rules](#matching-rules); applies to variables, columns, JSON keys, model fields)

| Pattern (glob/regex)                                                    | Maps to PII type          | Confidence |
|-------------------------------------------------------------------------|---------------------------|------------|
| `*email*`, `*e_mail*`, `*emailAddress*`                                 | PII-002 Email             | HIGH       |
| `*phone*`, `*mobile*`, `*telephone*`, `*phoneNumber*`                   | PII-003 Phone             | HIGH       |
| `*firstName*`, `*lastName*`, `*fullName*`, `*surname*`, `*givenName*`   | PII-001 Name              | HIGH       |
| `*address*`, `*streetAddress*`, `*postalCode*`, `*zipCode*`             | PII-004 Address           | HIGH       |
| `*dateOfBirth*`, `*dob*`, `*birthDate*`, `*birthday*`                   | PII-005 DOB               | HIGH       |
| `*ssn*`, `*socialSecurity*`, `*taxFileNumber*`, `*tfn*`, `*nationalId*` | PII-020 National ID       | HIGH       |
| `*passport*`, `*passportNumber*`                                        | PII-020 National ID       | HIGH       |
| `*driverLicense*`, `*driversLicence*`, `*licenseNumber*`                | PII-021 Driver License    | HIGH       |
| `*creditCard*`, `*cardNumber*`, `*pan*`, `*ccNumber*`                   | PII-023 Payment Card      | HIGH       |
| `*bankAccount*`, `*accountNumber*`, `*iban*`, `*bsb*`                   | PII-022 Financial Account | HIGH       |
| `*password*`, `*passwordHash*`, `*secret*`, `*mfaSecret*`               | PII-029 Credential        | HIGH       |
| `*ipAddress*`, `*clientIp*`, `*remoteAddr*`                             | PII-006 IP Address        | HIGH       |
| `*latitude*`, `*longitude*`, `*geoLocation*`, `*gps*`                   | PII-010 Location          | HIGH       |
| `*biometric*`, `*fingerprint*`, `*faceId*`, `*voicePrint*`              | PII-028 Biometric         | HIGH       |
| `*diagnosis*`, `*condition*`, `*icdCode*`, `*healthRecord*`             | PII-025 Health            | HIGH       |
| `*medication*`, `*prescription*`, `*drugName*`                          | PII-026 Medication        | HIGH       |
| `*salary*`, `*income*`, `*compensation*`, `*wage*`                      | PII-024 Income            | MEDIUM     |
| `*username*`, `*userId*`, `*loginId*`                                   | PII-008 Username          | MEDIUM     |

### Naming exclusions (reduce false positives)

Exclude matches when the context indicates non-PII:

- `*_template*`, `*_placeholder*`, `*_example*`, `*_mock*`
- Inside test fixtures clearly marked as synthetic data
- Generic words in unrelated contexts (e.g., `address` in memory address, `phone` in phone_type enum)

## Format validation patterns (regex)

When code contains regex patterns that match PII formats, this indicates PII processing:

| Regex pattern in code                                    | Indicates           | PII Type        |
|----------------------------------------------------------|---------------------|-----------------|
| `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b`        | Email validation    | PII-002         |
| `\b\d{3}[-.]?\d{3}[-.]?\d{4}\b`                          | US phone validation | PII-003         |
| `\b\d{3}-\d{2}-\d{4}\b`                                  | SSN validation      | PII-020         |
| `\b\d{9}\b` (in TFN context)                             | Australian TFN      | PII-020         |
| `\b4[0-9]{12}(?:[0-9]{3})?\b`                            | Visa card number    | PII-023         |
| `\b[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}\b` | Credit card format  | PII-023         |
| `\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b`                 | IPv4 address        | PII-006         |
| `\b[0-9a-fA-F:]{17,39}\b` (MAC-like or IPv6)             | Device/IP           | PII-006/PII-007 |

## Schema definition patterns

### Database migrations and models

Look for column definitions containing PII field names:

```python
# SQLAlchemy example — detected PII fields
email = Column(String(255))          # PII-002
phone_number = Column(String(20))    # PII-003
date_of_birth = Column(Date)         # PII-005
ssn_encrypted = Column(LargeBinary)  # PII-020 (note: encryption control present)
```

```typescript
// TypeORM / Prisma example
model User {
  email       String   @unique     // PII-002
  phone       String?              // PII-003
  dateOfBirth DateTime?            // PII-005
  address     String?              // PII-004
}
```

### API endpoint patterns

Parameters or request/response bodies indicating PII:

```
POST /api/users          → likely creates user with PII
GET  /api/users/:id      → returns user PII
PUT  /api/profile        → updates PII
POST /api/payments       → processes financial PII
GET  /api/health-records → health PII
```

## Third-party SDK indicators

| Library/Package                    | Likely PII processing         | Industry   |
|------------------------------------|-------------------------------|------------|
| `stripe`, `braintree`, `adyen`     | Payment card data             | Financial  |
| `twilio`, `sendgrid`, `mailgun`    | Phone, email                  | Universal  |
| `auth0`, `okta`, `firebase-auth`   | Credentials, email, phone     | Universal  |
| `segment`, `mixpanel`, `amplitude` | Behavioral profile, device ID | Universal  |
| `hl7-fhir`, `pydicom`              | Health records                | Healthcare |
| `plaid`, `yodlee`                  | Financial accounts            | Financial  |
| `google-maps`, `mapbox`            | Location data                 | Universal  |

## Log and telemetry detection

Detect PII leaking into logs:

```python
# FAIL indicators — PII in logs
logger.info(f"User registered: {user.email}")     # PII-002 in logs
logger.debug(f"Payment from card {card_number}")   # PII-023 in logs
print(f"Processing {patient.ssn}")                 # PII-020 in stdout

# PASS indicators — PII properly masked
logger.info(f"User registered: {mask(user.email)}")
logger.info(f"Payment processed for user_id={user.id}")
```

## Detection confidence levels

| Confidence | Meaning                                                    | Action                                                         |
|------------|------------------------------------------------------------|----------------------------------------------------------------|
| HIGH       | Strong evidence of PII processing (naming + context match) | Report as confirmed detection; proceed to control verification |
| MEDIUM     | Probable PII (naming match but ambiguous context)          | Report as NEEDS_REVIEW                                         |
| LOW        | Possible PII (indirect inference or weak signal)           | Report as NEEDS_REVIEW                                         |

The method and naming tables give initial confidence, not a permanent ceiling. Before control verification, reassess each MEDIUM detection against evidence for the same field and data flow.

Promote MEDIUM to HIGH when independent evidence confirms both the resolved PII type and its link to an individual. Examples include:

- A payroll schema linking `salary` to an employee record confirms PII-024; a numeric column named `salary` alone does not.
- An authentication model linking `username` to an individual account confirms PII-008; a generic display label alone does not.
- A classification annotation or type-specific validator corroborates an API parameter or SDK argument, and its call site shows that the value belongs to an individual.

Explicit reviewer confirmation may also promote a detection when it identifies the field, its PII type, and its use for an individual. Record the initial signal and the corroborating code location or reviewer confirmation in the detection's `evidence`, then set `confidence` to HIGH and verify controls for its resolved type and effective tier.

Repeated naming matches, a generic string/number schema, or an installed SDK without a traced personal-data argument do not independently confirm PII. Keep uncorroborated MEDIUM and LOW detections as NEEDS_REVIEW; they do not produce control-gap findings.

## Language-specific hints

### Python
- Look in: models.py, serializers.py, schemas.py, forms.py, views.py, tasks.py
- Decorators: `@validator`, `@field_validator`, `@sensitive_data`

### TypeScript/JavaScript
- Look in: *.model.ts, *.entity.ts, *.dto.ts, *.schema.ts, *.controller.ts
- Decorators: `@Column`, `@IsEmail()`, `@IsPhoneNumber()`

### C#
- Look in: *Model.cs, *Entity.cs, *Dto.cs, *Controller.cs
- Attributes: `[PersonalData]`, `[EmailAddress]`, `[Phone]`, `[ProtectedPersonalData]`

### Java
- Look in: *Entity.java, *Model.java, *Dto.java, *Repository.java
- Annotations: `@Email`, `@Column`, `@Sensitive`

### Go
- Look in: *_model.go, *_handler.go, *_repository.go
- Struct tags: `json:"email"`, `db:"phone_number"`

---

Detection patterns are original content (CC BY 4.0) synthesized from common software engineering practices for PII handling. Regex patterns are factual format descriptions, not reproductions of any licensed material.
