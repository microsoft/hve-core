---
description: 'Invoke doc-ops agent for documentation quality assurance and updates'
agent: 'doc-ops'
argument-hint: '[scope=all|docs|root|scripts] [validate-only={true|false}]'
maturity: stable
---

# Documentation Update

Invoke the doc-ops agent for pattern compliance, accuracy verification, and gap detection across documentation files.

## Inputs

* ${input:scope:all}: (Optional, defaults to all) Documentation scope to process:
  * all - Process all documentation files (docs/, root markdown, scripts/*.md)
  * docs - Process only docs/**/*.md files
  * root - Process only root community files (README.md, CONTRIBUTING.md, etc.)
  * scripts - Process only scripts/**/*.md files
* ${input:validateOnly:false}: (Optional, defaults to false) When true, run validation and report issues without making changes
* ${input:focus}: (Optional) Focus area for discovery:
  * patterns - Prioritize style and markdown convention divergences
  * accuracy - Prioritize documentation vs implementation discrepancies
  * missing - Prioritize undocumented functionality detection

## Scope Definition

This prompt processes **documentation files only**. Prompt engineering artifacts (.github/instructions/, prompts/, agents/, skills/) are out of scope. Use prompt-build.prompt.md for those file types.

---

Process documentation within the specified ${input:scope} following doc-ops agent protocols. Focus discovery on ${input:focus} when specified. When ${input:validateOnly} is true, report validation findings without making changes to files.
