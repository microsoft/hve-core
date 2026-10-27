---
title: Control Expectations
description: Required privacy controls per PII sensitivity tier with verification methods
---

# Control Expectations

For each detected PII type, this reference defines the controls that must be present. The agent verifies each control and raises a finding when absent.

## Control matrix by tier

### Tier 1: Identifiers

| Control                | Required    | Verification method                                                    |
|------------------------|-------------|------------------------------------------------------------------------|
| Encryption at rest     | Yes         | Storage config shows AES-256, TDE, or managed encryption               |
| Encryption in transit  | Yes         | TLS 1.2+ enforced; HTTPS-only endpoints                                |
| Access control         | Yes         | Role-based or attribute-based access on PII endpoints/tables           |
| Input validation       | Yes         | Validation present on PII input fields (format, length)                |
| Output masking in logs | Yes         | Logging statements do not contain raw PII values                       |
| Retention policy       | Yes         | TTL, lifecycle rule, or documented retention period                    |
| Purpose documentation  | Recommended | Collection point documents why PII is needed                           |
| Consent mechanism      | Conditional | Required if lawful basis is consent (not contract/legitimate interest) |

### Tier 2: Sensitive

All Tier 1 controls plus:

| Control                | Required    | Verification method                                                            |
|------------------------|-------------|--------------------------------------------------------------------------------|
| Field-level encryption | Yes         | Sensitive fields encrypted independently (not just disk encryption)            |
| Audit logging          | Yes         | Access to sensitive data produces audit trail entries                          |
| Consent gate           | Conditional | Required when the lawful basis is consent; otherwise document the lawful basis |
| Purpose binding        | Yes         | Data tagged with processing purpose; secondary use restricted                  |
| Data minimization      | Yes         | Only minimum necessary fields collected                                        |
| Pseudonymization       | Recommended | Identifiers replaced with tokens in analytics/reporting                        |
| Breach notification    | Yes         | Incident response plan covers this data category                               |

### Tier 3: Special Category

All Tier 1 and Tier 2 controls plus:

| Control                       | Required    | Verification method                                                                                                                                                                                          |
|-------------------------------|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Explicit consent              | Yes         | Granular, specific consent for this data category, or a documented lawful condition other than consent (GDPR Art. 9(2), Art. 10 authorization for criminal data, verifiable parental consent for child data) |
| DPIA conducted                | Yes         | Data Protection Impact Assessment documented                                                                                                                                                                 |
| Access restriction            | Yes         | Need-to-know access beyond standard RBAC                                                                                                                                                                     |
| Processing register           | Yes         | Entry in Records of Processing Activities (ROPA)                                                                                                                                                             |
| DPO notification              | Recommended | Data Protection Officer aware of this processing                                                                                                                                                             |
| Cross-border restriction      | Conditional | Transfer mechanisms if data crosses jurisdictions                                                                                                                                                            |
| Automated decision disclosure | Conditional | If used for profiling or automated decisions                                                                                                                                                                 |

## Control verification patterns

### Encryption at rest

Look for:
- Cloud storage lifecycle rules with encryption enabled
- Database configuration with TDE or column-level encryption
- Application-level encryption before storage (e.g., `encrypt()` calls on PII fields)
- Key management service references (AWS KMS, Azure Key Vault, GCP KMS)

Evidence patterns:
```yaml
# Azure — encryption enabled
encryption:
  services:
    blob:
      enabled: true
      keyType: Account
```

```python
# Application-level encryption
encrypted_ssn = encrypt(ssn, key=get_key("pii-encryption"))
db.store(user_id=id, ssn_encrypted=encrypted_ssn)
```

### Access control

Look for:
- Middleware or decorators restricting PII endpoints (`@authorize`, `@roles_required`)
- Database row-level security or column-level grants
- API gateway policies restricting PII routes

Evidence patterns:
```python
@app.route("/api/users/<id>")
@require_role("user_admin")  # Access control present
def get_user(id): ...
```

### Output masking in logs

Look for:
- Logging utility that masks/redacts PII fields
- Structured logging with PII exclusion rules
- No raw PII in `logger.*()`, `console.log()`, or `print()` calls

Evidence patterns:
```python
# Control present — masked logging
logger.info("User action", extra={"user_id": user.id})  # ID only, no PII

# Control absent — PII in logs
logger.info(f"Login: {user.email} from {request.remote_addr}")  # FAIL
```

### Retention policy

Look for:
- Database TTL or expiration columns
- Cloud storage lifecycle rules with deletion actions
- Scheduled cleanup jobs or retention enforcement code
- Documentation defining retention periods per data category

Evidence patterns:
```yaml
# Storage lifecycle rule
lifecycle_rule:
  condition: { age_days: 365 }
  action: delete
```

```python
# Code-level retention
def purge_expired_users():
    cutoff = datetime.now() - timedelta(days=RETENTION_DAYS)
    User.objects.filter(created_at__lt=cutoff).delete()
```

### Consent mechanism

Look for:
- Consent collection UI or API (consent endpoint, checkbox, modal)
- Consent record storage (consent_given_at, consent_version, purpose)
- Consent check before processing (if not consented, block)

Evidence patterns:
```typescript
// Consent gate before PII processing
if (!user.hasConsent("analytics")) {
  throw new ConsentRequiredError("Analytics consent not given");
}
```

## Control absence findings

When a required control is not found, the finding includes:

| Field             | Value                                             |
|-------------------|---------------------------------------------------|
| `pii_type`        | The detected PII taxonomy ID                      |
| `tier`            | Sensitivity tier (T1/T2/T3)                       |
| `missing_control` | Which control is absent                           |
| `severity`        | Mapped from tier: T1→MEDIUM, T2→HIGH, T3→CRITICAL |
| `remediation`     | Specific action to implement the control          |
| `evidence`        | What was searched and not found                   |

## Control sufficiency rules

Documentation-acceptable controls can be satisfied by a referenced document as well as by code or configuration:

- Retention policy, purpose documentation, and cross-border restriction
- Consent mechanism, consent gate, and explicit consent, through a documented lawful basis or condition
- Breach notification, DPIA conducted, processing register, DPO notification, and automated decision disclosure

All other controls are technical controls and require code or configuration evidence.

A control is considered PRESENT when:
- Code or configuration evidence confirms implementation; for documentation-acceptable controls (such as DPIA, processing register, breach notification, and DPO notification), a referenced document is sufficient
- The control covers the specific PII type detected (not just generic security)
- The control is active (not commented out, behind a disabled feature flag, or in dead code)

A control is PARTIAL when:
- Implementation exists but does not cover all instances of the PII type
- Documentation claims a technical control but code does not implement it
- The control exists in production config but not in all environments

A control is NEEDS_REVIEW when:
- It is documentation-acceptable and neither code nor a referenced document is found in the repository; these documents often live outside the codebase
- It is a consent control and the lawful basis is not evidenced; consent controls are ABSENT only when consent is the evidenced lawful basis and no consent implementation exists

NEEDS_REVIEW controls are listed for confirmation and do not produce control-gap findings.

## Official sources

* [NIST SP 800-122](https://doi.org/10.6028/NIST.SP.800-122)
* [General Data Protection Regulation](https://eur-lex.europa.eu/eli/reg/2016/679/oj)

---

Control framework is original content (CC BY 4.0) synthesized from privacy engineering best practices, NIST SP 800-122, and GDPR Art. 25 technical measures guidance.
