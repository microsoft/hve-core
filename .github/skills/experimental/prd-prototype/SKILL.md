---
name: prd-prototype
description: "Prototype PRD template bundle for validating the document-section item kind and variable-resolution lint - Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: "HVE Core contributors"
  spec_version: "1.0"
  last_updated: "2026-04-21"
---

# PRD Prototype — Skill Entry

Throwaway prototype validating the `document-section` item kind and variable-resolution pipeline. Not intended for production use; lives under `experimental/` until the content-generation extensions reach Phase 2+.

## Purpose

Exercises the following validation paths:

- `document-section.schema.json` per-item schema validation
- `Test-FsiVariableResolution` lint for `{{var}}` token coverage
- Globals-to-item resolution across the manifest

## Items

| ID                | Title             | Phase   |
|-------------------|-------------------|---------|
| executive-summary | Executive Summary | outline |
| objectives        | Objectives        | outline |
| stakeholders      | Stakeholders      | detail  |
