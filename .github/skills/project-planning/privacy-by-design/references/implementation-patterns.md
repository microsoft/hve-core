---
title: Implementation Patterns
description: Pragmatic code-level and architecture-level patterns agents can verify when assessing PbD principle adherence
---

# Implementation Patterns

This reference provides pragmatic, verifiable implementation patterns that an agent can look for in code, configuration, and architecture when assessing PbD principle adherence. Each pattern maps to one or more principles and provides concrete indicators.

## PbD-01: Proactive indicators in code

### Privacy Impact Assessment integration

Look for:

- Pre-commit hooks or CI checks that flag new personal data collection points
- Architecture Decision Records (ADRs) with privacy as a decision driver
- Issue templates or PR templates that include privacy impact questions
- Privacy-tagged user stories or acceptance criteria in backlog items

### Privacy threat modeling artifacts

Look for:

- STRIDE analysis files that include privacy-specific threats (information disclosure, elevation of privilege for data access)
- Data flow diagrams annotating personal data boundaries
- Privacy risk registers in project documentation

## PbD-02: Default setting patterns

### Configuration-level checks

```yaml
# PASS indicators — privacy-protective defaults
analytics:
  tracking_enabled: false        # Disabled by default
  anonymize_ip: true            # Anonymized by default
  consent_required: true        # Opt-in required

cookies:
  third_party: disabled         # No third-party by default
  session_only: true            # Minimal persistence

user_profile:
  visibility: private           # Private by default
  search_indexing: false        # Not indexed by default
```

```yaml
# FAIL indicators — privacy-invasive defaults
analytics:
  tracking_enabled: true        # Tracking without consent
  anonymize_ip: false           # Full IP collection
  consent_required: false       # No consent gate

user_profile:
  visibility: public            # Public by default
  search_indexing: true         # Indexed without consent
```

### Consent mechanism patterns

```
PASS: Consent flows use opt-in (unchecked checkboxes, explicit "I agree" action)
FAIL: Pre-checked consent boxes, bundled consent, consent buried in terms
PASS: Consent withdrawal is a single-action operation accessible from the same location
FAIL: Withdrawal requires contacting support or navigating obscure settings
```

### API default patterns

```
PASS: API endpoints return minimal fields by default; expand via explicit ?fields= parameter
FAIL: API endpoints return all user data by default including sensitive fields
PASS: Pagination defaults to smallest reasonable page size
FAIL: Endpoints return unbounded result sets with full user records
```

## PbD-03: Embedded design indicators

### Architecture patterns

| Pattern | PbD alignment | What to look for |
|---------|---------------|------------------|
| Data classification in schema | PbD-03 | Column/field annotations marking PII, sensitive, public |
| Purpose-binding at collection | PbD-03 | Data tagged with processing purpose at ingestion point |
| Privacy boundaries in microservices | PbD-03 | Separate services for identity vs. analytics vs. business logic |
| Tokenization/pseudonymization | PbD-03 | User identifiers replaced with tokens in analytics pipelines |
| Field-level encryption | PbD-03 | Sensitive fields encrypted independently of storage encryption |

### Code-level indicators

Look for:

- Data classification decorators or annotations on model classes
- Purpose-binding metadata attached to data collection endpoints
- Separate data access layers for PII vs. non-PII queries
- Privacy-aware logging that redacts or masks personal data
- Input validation that rejects unnecessary personal data fields

```python
# PASS indicator — data classification in code
@data_classification(category="sensitive", purpose="billing")
class PaymentInfo:
    card_last_four: str  # Only last 4 stored
    billing_zip: str

# PASS indicator — privacy-aware logging
logger.info("Payment processed", extra={"user_id": mask(user_id), "amount": amount})

# FAIL indicator — logging PII
logger.info(f"Payment for {user.email} with card {card_number}")
```

## PbD-04: Positive-sum indicators

### Non-discrimination patterns

Look for:

- Feature flags or configuration that ensures opted-out users retain full core functionality
- A/B test configurations that do not degrade experience for privacy-conscious cohorts
- Terms of service that do not condition service access on optional data collection
- No differential pricing or feature gating based on consent choices

### Code indicators

```
PASS: Service works fully with analytics disabled
FAIL: Features break or degrade when tracking is blocked
PASS: Rate limits and quotas are identical regardless of consent status
FAIL: Higher quotas or premium features require accepting additional data collection
```

## PbD-05: Lifecycle security patterns

### Encryption verification

| Check | Evidence |
|-------|----------|
| Encryption at rest | Storage configuration shows AES-256, managed keys, or customer-managed keys |
| Encryption in transit | TLS 1.2+ enforced; HTTP redirected to HTTPS; HSTS headers present |
| Key rotation | Key management policy shows rotation schedule (e.g., 90 days) |
| Cryptographic erasure capability | Key management supports key deletion as a disposal method |

### Retention enforcement patterns

```yaml
# PASS — automated retention enforcement
storage:
  lifecycle_rules:
    - condition:
        age_days: 365
        matches_prefix: "user-analytics/"
      action: delete

  backup_retention:
    max_days: 90
    auto_purge: true

# FAIL — no lifecycle management
storage:
  lifecycle_rules: []  # No rules defined
  backup_retention:
    max_days: unlimited
```

### Deletion verification

Look for:

- Cascading delete logic that removes data from all stores (primary, cache, backup, CDN)
- Deletion confirmation logs or audit trail entries
- Soft-delete to hard-delete pipeline with defined timelines
- Data subject access request (DSAR) handling workflows

## PbD-06: Transparency indicators

### Privacy notice patterns

Look for:

- Privacy policy accessible from every page (footer link, modal, or dedicated route)
- Plain-language summaries alongside legal text
- Version history of privacy notices (git history or CMS versioning)
- Automated notification to users when privacy policy changes materially

### Data access patterns

```
PASS: Self-service DSAR portal or API endpoint for data export
FAIL: Users must email support to request their data
PASS: Data export includes all categories with clear labeling
FAIL: Data export is partial or requires multiple requests
PASS: Response within defined SLA (e.g., 30 days per GDPR)
FAIL: No defined timeline for data access requests
```

### Records of processing

Look for:

- Processing activity register (spreadsheet, database, or documentation)
- Each entry lists: purpose, legal basis, categories, recipients, retention, safeguards
- Register is maintained and updated when processing changes

## PbD-07: User-centric indicators

### Privacy control accessibility

Look for:

- Privacy settings reachable within 2 clicks/taps from main navigation
- Granular consent management (per-purpose, not all-or-nothing)
- Account deletion available as self-service (not "contact support to delete")
- Data portability export in standard formats (JSON, CSV)
- WCAG 2.2 AA compliance for privacy-related UI elements

### Consent granularity patterns

```
PASS: Separate consent for analytics, marketing, third-party sharing, profiling
FAIL: Single "I agree to everything" consent covering all purposes
PASS: Per-partner consent for data sharing (can consent to Partner A but not B)
FAIL: Blanket "share with partners" consent
```

### Automated decision-making

Look for:

- Disclosure of automated profiling or algorithmic decisions affecting users
- Mechanism to request human review of automated decisions
- Explanation capability for algorithmic outcomes (even if simplified)

## Cross-cutting indicators

### CI/CD privacy checks

| Check | Principle | What to verify |
|-------|-----------|----------------|
| PII scanner in pipeline | PbD-01, PbD-03 | Automated detection of new PII collection points |
| Privacy test suite | PbD-02, PbD-05 | Tests verifying privacy defaults and data lifecycle |
| Consent flow tests | PbD-02, PbD-07 | Automated verification of opt-in behavior |
| Data classification linter | PbD-03 | Schema changes require classification annotation |
| Retention policy validator | PbD-05 | New data stores require retention configuration |

### Infrastructure-as-code indicators

```
PASS: Terraform/Bicep includes lifecycle rules on storage resources
PASS: Network policies restrict data egress to approved destinations
PASS: Logging configuration excludes PII fields from log sinks
FAIL: Storage resources created without lifecycle management
FAIL: No network-level data exfiltration controls
FAIL: Application logs contain unmasked personal data
```

---

Patterns synthesized from privacy engineering best practices, GDPR technical guidance (Article 29 Working Party), and architecture patterns observed in privacy-mature systems. Provided as planning reference material with attribution.
