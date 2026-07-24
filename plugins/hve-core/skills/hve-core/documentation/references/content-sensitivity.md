---
title: Content sensitivity checks
description: Pre-publish checks for PII, confidentiality, secrets, and AI disclosure in documentation.
---

# Content sensitivity checks

Use these checks before publishing or committing documentation, especially when content
is derived from source code, logs, sample output, or screenshots.

## Pre-publish checklist

- No real PII in examples. Use placeholders (`user@example.com`, `Jane Doe`,
  `00000000-0000-0000-0000-000000000000`) instead of real names, emails, or IDs.
- No secrets or credentials. Redact tokens, keys, passwords, and connection strings;
  use obviously fake values in samples.
- Confidentiality check. Flag internal-only URLs, customer names, and unreleased
  feature names before they reach a public-facing surface (for example `docs/`).
- AI disclosure. Preserve the repository attribution or disclosure footer when content is
  materially shaped by AI assistance.

## Handoff trigger

If documentation would expose regulated PII or NDA-bound material, halt and route the
work to the RAI Planner (data handling) or Security Planner (secrets or credentials)
rather than resolving it inline.
