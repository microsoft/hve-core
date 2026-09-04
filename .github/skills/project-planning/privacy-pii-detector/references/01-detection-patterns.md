---
title: Detection Patterns
description: Language-agnostic and language-specific code patterns for identifying PII processing in source code
---

# Detection Patterns

This reference defines the patterns agents use to detect PII processing in codebases. Patterns are organized by detection method and map to PII taxonomy IDs.

## Detection methods

| Method | How it works | Confidence |
|--------|--------------|------------|
| Naming convention | Field/variable/column names matching PII patterns | HIGH |
| Data annotation | Decorators, attributes, or comments marking data classification | HIGH |
| Regex/format validation | Validation patterns that match PII formats | HIGH |
| API signature | Parameters or return types indicating PII | MEDIUM |
| Schema definition | Database columns, protobuf fields, GraphQL types | HIGH |
| String literal | Hardcoded PII in tests, seeds, or config | MEDIUM |
| Third-party SDK | Library calls known to process PII | MEDIUM |
| Log/telemetry output | Logging statements containing PII fields | HIGH |

## Naming convention patterns

### Field name indicators (case-insensitive, applies to variables, columns, JSON keys, model fields)

| Pattern (glob/regex) | Maps to PII type | Confidence |
|---------------------|-----------------|------------|
| `*email*`, `*e_mail*`, `*emailAddress*` | PII-002 Email | HIGH |
| `*phone*`, `*mobile*`, `*telephone*`, `*phoneNumber*` | PII-003 Phone | HIGH |
| `*firstName*`, `*lastName*`, `*fullName*`, `*surname*`, `*givenName*` | PII-001 Name | HIGH |
| `*address*`, `*streetAddress*`, `*postalCode*`, `*zipCode*` | PII-004 Address | HIGH |
| `*dateOfBirth*`, `*dob*`, `*birthDate*`, `*birthday*` | PII-005 DOB | HIGH |
| `*ssn*`, `*socialSecurity*`, `*taxFileNumber*`, `*tfn*`, `*nationalId*` | PII-020 National ID | HIGH |
| `*passport*`, `*passportNumber*` | PII-020 National ID | HIGH |
| `*driverLicense*`, `*driversLicence*`, `*licenseNumber*` | PII-021 Driver License | HIGH |
| `*creditCard*`, `*cardNumber*`, `*pan*`, `*ccNumber*` | PII-023 Payment Card | HIGH |
| `*bankAccount*`, `*accountNumber*`, `*iban*`, `*bsb*` | PII-022 Financial Account | HIGH |
| `*password*`, `*passwordHash*`, `*secret*`, `*mfaSecret*` | PII-029 Credential | HIGH |
| `*ipAddress*`, `*clientIp*`, `*remoteAddr*` | PII-006 IP Address | HIGH |
| `*latitude*`, `*longitude*`, `*geoLocation*`, `*gps*` | PII-010 Location | HIGH |
| `*biometric*`, `*fingerprint*`, `*faceId*`, `*voicePrint*` | PII-028 Biometric | HIGH |
| `*diagnosis*`, `*condition*`, `*icdCode*`, `*healthRecord*` | PII-025 Health | HIGH |
| `*medication*`, `*prescription*`, `*drugName*` | PII-026 Medication | HIGH |
| `*salary*`, `*income*`, `*compensation*`, `*wage*` | PII-024 Income | MEDIUM |
| `*username*`, `*userId*`, `*loginId*` | PII-008 Username | MEDIUM |

### Naming exclusions (reduce false positives)

Exclude matches when the context indicates non-PII:

- `*_template*`, `*_placeholder*`, `*_example*`, `*_mock*`
- Inside test fixtures clearly marked as synthetic data
- Generic words in unrelated contexts (e.g., `address` in memory address, `phone` in phone_type enum)

## Format validation patterns (regex)

When code contains regex patterns that match PII formats, this indicates PII processing:

| Regex pattern in code | Indicates | PII Type |
|-----------------------|-----------|----------|
| `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b` | Email validation | PII-002 |
| `\b\d{3}[-.]?\d{3}[-.]?\d{4}\b` | US phone validation | PII-003 |
| `\b\d{3}-\d{2}-\d{4}\b` | SSN validation | PII-020 |
| `\b\d{9}\b` (in TFN context) | Australian TFN | PII-020 |
| `\b4[0-9]{12}(?:[0-9]{3})?\b` | Visa card number | PII-023 |
| `\b[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}\b` | Credit card format | PII-023 |
| `\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b` | IPv4 address | PII-006 |
| `\b[0-9a-fA-F:]{17,39}\b` (MAC-like or IPv6) | Device/IP | PII-006/PII-007 |

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

| Library/Package | Likely PII processing | Industry |
|-----------------|----------------------|----------|
| `stripe`, `braintree`, `adyen` | Payment card data | Financial |
| `twilio`, `sendgrid`, `mailgun` | Phone, email | Universal |
| `auth0`, `okta`, `firebase-auth` | Credentials, email, phone | Universal |
| `segment`, `mixpanel`, `amplitude` | Behavioral profile, device ID | Universal |
| `hl7-fhir`, `pydicom` | Health records | Healthcare |
| `plaid`, `yodlee` | Financial accounts | Financial |
| `google-maps`, `mapbox` | Location data | Universal |

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

| Confidence | Meaning | Action |
|------------|---------|--------|
| HIGH | Strong evidence of PII processing (naming + context match) | Report as confirmed detection |
| MEDIUM | Probable PII (naming match but ambiguous context) | Report with NEEDS_REVIEW flag |
| LOW | Possible PII (indirect inference or weak signal) | Report only in verbose mode |

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
