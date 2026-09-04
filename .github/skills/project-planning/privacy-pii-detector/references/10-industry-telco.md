---
title: Telco Industry Overlay
description: Telecommunications-specific PII types, detection patterns, and control expectations
---

# Telco Industry Overlay

This overlay extends the core PII taxonomy with telecommunications-specific personal information types. Apply when the codebase processes subscriber data, network identifiers, or communication metadata.

## Industry detection triggers

Apply this overlay when the codebase contains:
- Dependencies: `diameter`, `ss7`, `camel`, `radius`, `sip`, telecom SDKs
- Terminology: subscriber, MSISDN, CDR, provisioning, roaming, handset
- API patterns: `/api/subscribers`, `/api/cdr`, `/api/network/`
- Domain: `.telco.`, `.telecom.`, `.mobile.` in package names or configs

## Telco-specific PII types

| ID | PII Type | Description | Tier | Regulatory anchor |
|----|----------|-------------|------|-------------------|
| PII-100 | IMEI | International Mobile Equipment Identity (15-digit device ID) | T2 | GDPR Art. 4(1), ePrivacy |
| PII-101 | IMSI | International Mobile Subscriber Identity (SIM identity) | T2 | GDPR Art. 4(1), ePrivacy |
| PII-102 | MSISDN | Mobile subscriber number (phone number in E.164 format) | T1 | GDPR Art. 4(1) |
| PII-103 | SIM serial (ICCID) | Integrated Circuit Card ID | T2 | ePrivacy Directive |
| PII-104 | MAC address | Device network hardware identifier | T1 | GDPR Recital 30 |
| PII-105 | Cell tower ID (CGI) | Cell Global Identity — user location via network | T2 | ePrivacy Art. 9, GDPR Art. 9 (if continuous) |
| PII-106 | CDR (Call Detail Record) | Who called whom, when, duration, cell tower | T2 | Metadata Retention laws, ePrivacy |
| PII-107 | SMS/MMS content | Message body content | T3 | Interception laws, ePrivacy Art. 5 |
| PII-108 | Voicemail content | Recorded voice messages | T3 | ePrivacy Art. 5 |
| PII-109 | Network location history | Sequence of cell attachments over time | T2 | GDPR Art. 9 (movement patterns) |
| PII-110 | Subscriber profile | Plan type, usage patterns, credit status | T1 | Contextual |
| PII-111 | Device fingerprint | Handset model, OS version, IMEI + behavioral signals | T2 | ePrivacy, GDPR Recital 30 |
| PII-112 | Roaming data | Visited networks, international movement | T2 | Cross-border transfer triggers |

## Telco detection patterns

### Naming conventions

| Pattern | Maps to | Confidence |
|---------|---------|------------|
| `*imei*`, `*device_imei*`, `*handsetId*` | PII-100 IMEI | HIGH |
| `*imsi*`, `*subscriberIdentity*` | PII-101 IMSI | HIGH |
| `*msisdn*`, `*subscriberNumber*`, `*mobileNumber*` | PII-102 MSISDN | HIGH |
| `*iccid*`, `*simSerial*`, `*simId*` | PII-103 SIM Serial | HIGH |
| `*macAddress*`, `*hwAddress*`, `*mac_addr*` | PII-104 MAC | HIGH |
| `*cellId*`, `*cgi*`, `*cellTower*`, `*lac*` | PII-105 Cell Tower | HIGH |
| `*cdr*`, `*callRecord*`, `*callDetail*` | PII-106 CDR | HIGH |
| `*smsBody*`, `*messageContent*`, `*mmsPayload*` | PII-107 SMS/MMS | HIGH |
| `*voicemail*`, `*vmContent*` | PII-108 Voicemail | HIGH |
| `*locationHistory*`, `*cellHistory*`, `*networkTrace*` | PII-109 Location History | HIGH |

### Format patterns

| Format in code | Indicates | Confidence |
|----------------|-----------|------------|
| `\b\d{15}\b` (15-digit, Luhn check) | IMEI | MEDIUM |
| `\b\d{15,16}\b` (in IMSI context) | IMSI | MEDIUM |
| `\+?\d{10,15}` (E.164 format) | MSISDN | MEDIUM |
| `\b\d{19,20}\b` (in SIM context) | ICCID | MEDIUM |
| `([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}` | MAC address | HIGH |

### Schema patterns

```protobuf
// Telco protobuf — multiple PII fields
message CallDetailRecord {
  string calling_msisdn = 1;    // PII-102
  string called_msisdn = 2;     // PII-102
  int64 start_time = 3;
  int32 duration_seconds = 4;
  string cell_id_start = 5;     // PII-105
  string cell_id_end = 6;       // PII-105
  string imei = 7;              // PII-100
  string imsi = 8;              // PII-101
}
```

## Telco-specific control requirements

Beyond core tier controls, telco PII requires:

| Control | Applies to | Rationale |
|---------|-----------|-----------|
| Lawful interception isolation | PII-107, PII-108 | Content must be accessible only via warranted legal process |
| Metadata retention compliance | PII-106, PII-109 | Retention periods mandated by national data retention laws (varies: 6mo–2yr) |
| Network-level encryption | PII-100–PII-112 | Data in transit between network elements must use IPsec or TLS |
| Subscriber consent for location | PII-105, PII-109 | Explicit opt-in for location-based services beyond network operation |
| CDR anonymization for analytics | PII-106 | Aggregated CDR for business analytics must strip subscriber identifiers |
| Cross-border roaming controls | PII-112 | Roaming partner data sharing requires transfer agreements |
| Device correlation prevention | PII-100, PII-111 | IMEI must not be correlated across services without purpose limitation |

## Telco regulatory context

| Regulation | Jurisdiction | Key requirement |
|-----------|--------------|-----------------|
| ePrivacy Directive (2002/58/EC) | EU | Consent for location data; confidentiality of communications |
| Telecommunications Act 1997 | Australia | Metadata retention (2 years); interception warrant requirements |
| CPNI rules (47 CFR § 64.2001) | US | Customer Proprietary Network Information protection |
| Telecommunications (Interception) Act | Australia | Lawful interception obligations |
| EU Data Retention Directive (invalidated) | EU | Historical context; replaced by national implementations |

---

Telco overlay is original content (CC BY 4.0) synthesized from telecommunications privacy engineering practices. Regulatory references are paraphrased with attribution, not legal interpretations.
