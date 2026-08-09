---
title: Financial Services Industry Overlay
description: Financial data PII types, detection patterns, and control expectations for banking and fintech
---

# Financial Services Industry Overlay

This overlay extends the core PII taxonomy with financial services-specific personal information types. Apply when the codebase processes payment data, banking information, or financial customer records.

## Industry detection triggers

Apply this overlay when the codebase contains:
- Dependencies: `stripe`, `braintree`, `adyen`, `plaid`, `yodlee`, `open-banking`, PCI libraries
- Terminology: account, transaction, KYC, AML, PAN, merchant, settlement, ledger
- API patterns: `/api/accounts`, `/api/transactions`, `/api/payments`, `/api/kyc`
- Domain: `.bank.`, `.finance.`, `.payments.` in package names or configs

## Financial-specific PII types

| ID | PII Type | Description | Tier | Regulatory anchor |
|----|----------|-------------|------|-------------------|
| PII-300 | PAN (Primary Account Number) | Full credit/debit card number | T2 | PCI DSS |
| PII-301 | CVV/CVC | Card verification value | T2 | PCI DSS (never stored) |
| PII-302 | Bank account number | Account, IBAN, BSB + account | T2 | Banking regulations |
| PII-303 | Routing/sort code | Bank routing identifier | T1 | Contextual (sensitive with account) |
| PII-304 | Transaction history | What was bought, when, where, amount | T2 | GDPR, CCPA, APRA |
| PII-305 | Account balance | Current balance, available funds | T2 | Banking secrecy laws |
| PII-306 | Credit score | Bureau score, internal risk rating | T2 | FCRA, GDPR Art. 22 |
| PII-307 | KYC documents | Identity verification documents (passport, utility bill, selfie) | T2 | AML/CTF regulations |
| PII-308 | Tax identifier | TIN, EIN, VAT number linked to individual | T2 | Tax privacy laws |
| PII-309 | Beneficiary details | Transfer recipient name, account, relationship | T2 | AML requirements |
| PII-310 | Loan/mortgage details | Amount, terms, repayment history, arrears | T2 | Consumer credit laws |
| PII-311 | Investment portfolio | Holdings, trades, positions | T2 | Securities regulations |
| PII-312 | Fraud indicators | Fraud scores, suspicious activity flags | T2 | AML/CTF, Tipping-off rules |
| PII-313 | PIN (encrypted) | Personal identification number for authentication | T2 | PCI PIN Security |

## Financial detection patterns

### Naming conventions

| Pattern | Maps to | Confidence |
|---------|---------|------------|
| `*cardNumber*`, `*pan*`, `*primaryAccountNumber*`, `*ccNumber*` | PII-300 PAN | HIGH |
| `*cvv*`, `*cvc*`, `*cardVerification*`, `*securityCode*` | PII-301 CVV | HIGH |
| `*bankAccount*`, `*accountNumber*`, `*iban*`, `*bsb*` | PII-302 Account | HIGH |
| `*routingNumber*`, `*sortCode*`, `*swiftCode*` | PII-303 Routing | HIGH |
| `*transaction*`, `*txn*`, `*payment*`, `*purchase*` | PII-304 Transaction | MEDIUM |
| `*balance*`, `*availableFunds*`, `*accountBalance*` | PII-305 Balance | HIGH |
| `*creditScore*`, `*riskRating*`, `*bureauScore*`, `*fico*` | PII-306 Credit Score | HIGH |
| `*kyc*`, `*identityVerification*`, `*proofOfId*` | PII-307 KYC | HIGH |
| `*tin*`, `*taxId*`, `*einNumber*`, `*vatNumber*` | PII-308 Tax ID | HIGH |
| `*beneficiary*`, `*recipient*`, `*payee*` | PII-309 Beneficiary | MEDIUM |
| `*loan*`, `*mortgage*`, `*repayment*`, `*arrears*` | PII-310 Loan | HIGH |
| `*portfolio*`, `*holdings*`, `*positions*`, `*trades*` | PII-311 Investment | MEDIUM |
| `*fraudScore*`, `*suspiciousActivity*`, `*sar*` | PII-312 Fraud | HIGH |
| `*pin*`, `*pinBlock*`, `*encryptedPin*` | PII-313 PIN | HIGH |

### PCI-specific patterns

```
# PAN detection — look for card number handling
FAIL: Storing full PAN in plaintext columns
FAIL: Logging card numbers
FAIL: CVV stored anywhere (even encrypted)
PASS: Tokenized card reference (tok_xxx)
PASS: Last-4 only storage (card_last_four)
PASS: PCI-compliant vault reference (vault_id)
```

### Open Banking API patterns

```
# Endpoints indicating financial PII
GET  /api/accounts/{id}/balance     → PII-305
GET  /api/accounts/{id}/transactions → PII-304
POST /api/payments                   → PII-300, PII-302
POST /api/kyc/verify                 → PII-307
GET  /api/credit-score              → PII-306
```

## Financial-specific control requirements

Beyond core tier controls:

| Control | Applies to | Rationale |
|---------|-----------|-----------|
| PCI DSS compliance | PII-300, PII-301, PII-313 | Card data requires PCI DSS scope; CVV must never be stored |
| Tokenization | PII-300 | Replace PAN with non-reversible token for non-payment processing |
| PCI-compliant vault | PII-300, PII-313 | Store card data only in certified cardholder data environment (CDE) |
| Transaction monitoring | PII-304, PII-312 | AML/CTF obligation to monitor for suspicious patterns |
| KYC document retention limits | PII-307 | Retain only for regulatory minimum; destroy after obligation expires |
| Tipping-off prevention | PII-312 | Fraud/SAR flags must not be disclosed to the subject |
| Strong Customer Authentication | PII-300, PII-302 | PSD2/SCA requirement for payment initiation |
| Data segregation | All financial PII | Ring-fence financial data from marketing and analytics |
| Audit trail (immutable) | PII-304, PII-305 | Financial transactions require immutable audit for regulatory reporting |
| Cross-border transfer controls | All | SWIFT, SEPA, and correspondent banking data subject to jurisdictional rules |

## Financial regulatory context

| Regulation | Jurisdiction | Key requirement |
|-----------|--------------|-----------------|
| PCI DSS v4.0 | Global | Cardholder data protection, network segmentation, encryption |
| PSD2/SCA | EU | Strong customer authentication, open banking consent |
| FCRA | US | Credit reporting accuracy, consumer dispute rights |
| AML/CTF Act 2006 | Australia | Customer identification, transaction monitoring, reporting |
| Bank Secrecy Act / FinCEN | US | Anti-money laundering, suspicious activity reporting |
| APRA CPS 234 | Australia | Information security for APRA-regulated entities |
| GDPR (financial) | EU | Consent for profiling, automated decision-making transparency |
| Consumer Credit Act | UK/AU | Responsible lending, credit information handling |
| SOX Section 404 | US | Financial data integrity controls for public companies |

---

Financial overlay is original content (CC BY 4.0) synthesized from financial privacy and PCI engineering practices. Regulatory references are paraphrased with attribution, not legal interpretations.
