---
description: 'Invoke doc-ops agent for comprehensive documentation updates'
agent: 'doc-ops'
argument-hint: '[scope=all|docs|agents|root|...] [validate-only={true|false}]'
maturity: stable
---

# Documentation Update

## Inputs

* ${input:scope:all}: (Optional, defaults to all) Document scope to process, e.g.:
  * all - Process all documentation categories
  * docs - Process only docs/**/*.md files
  * instructions - Process only .github/instructions/**/*.instructions.md files
  * prompts - Process only .github/prompts/**/*.prompt.md files
  * agents - Process only .github/agents/**/*.agent.md files
  * skills - Process only .github/skills/**/SKILL.md files
  * root - Process only root community files (README.md, CONTRIBUTING.md, etc.)
  * scripts - Process only scripts/**/*.md files
* ${input:validateOnly:false}: (Optional, defaults to false) When true, run validation and report issues without making changes

---

Process documentation within the specified ${input:scope} following doc-ops agent protocols. When ${input:validateOnly} is true, report validation findings without making changes to files.
