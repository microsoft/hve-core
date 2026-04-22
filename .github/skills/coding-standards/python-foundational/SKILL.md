---
name: python-foundational
description: "Foundational Python best practices, idioms, and code quality fundamentals - Brought to you by microsoft/hve-core"
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-03-23"
---

# Python Foundational Coding Standards Skill

## Overview

Foundational Python excellence that every diff must satisfy. This skill is loaded first for any .py change. All higher-order skills build on it.

This content is a skill rather than an instructions file for three reasons: skills are distributed through the CLI plugin and VS Code extension without requiring consumers to copy files into their repo; new language skills can be added without modifying the review agent itself; and skills are loaded on demand, keeping the context window small when the diff contains no Python.

## Core Checklist

#### 1. Readability & Style

* Use Python naming: `PascalCase` classes, `snake_case` functions/variables, `UPPER_SNAKE_CASE` constants, `_` private members.
* Group imports: stdlib → third-party → local (blank line between groups, no trailing whitespace).

#### 2. Pythonic Idioms

* Prefer comprehensions for simple transforms; use explicit loops for complex logic/side-effects.
* Always use `with` for files, locks, DB connections.
* Prefer `dataclass` / `NamedTuple` / `Enum` for data holders.
* Use `pathlib` over `os.path`; timezone-aware `datetime` when relevant.
* Use `*` keyword-only arguments for multi-optional functions.
* Never use mutable defaults or `global`/`nonlocal` unless strictly required.

#### 3. Function & Class Design

* Keep functions small and single-responsibility.
* Add docstrings to all public APIs (follow repo style).
* Document unavoidable side-effects.
* Follow codebase’s class-member ordering (if defined).

#### 4. Type Safety Foundations

* Add type hints to all public APIs, module vars, and class attributes.
* Use PEP 695 (3.12+) or `TypeVar` for generics.
* Avoid `Any` except in thin wrappers.

#### 5. Error Handling

* Raise specific exceptions; never bare `except:` (broad `except Exception:` only at app boundaries with logging).
* No silent failures or generic error messages.
* Provide context, expected state, and guidance in every exception.

#### 6. Anti-Patterns to Avoid

* Never use `eval`, `exec`, or `pickle` on untrusted data.
* Never hard-code secrets.

#### 7. Maintainability

* Prefer self-documenting code; comments only for "why".
* Use structured logging instead of `print`.
* Flag overly long/complex functions that resist testing.

#### 8. Architectural Fit

* Align with existing patterns; do not re-implement shared functionality or bypass established layers.
* Place code in the correct module/package.

#### 9. Design Principles

* Eliminate duplication: extract repeated logic into a shared helper so fixes propagate automatically.
* Prefer the simplest implementation that satisfies current requirements. Introduce abstractions only when a second concrete use case appears.
* Limit change breadth: every modified line should trace to the stated purpose of the change.
* Before flagging seemingly unused code, verify it is not a protocol implementation, framework hook, public API, or entry point invoked externally.
* Match solution complexity to problem complexity. A duplicated function warrants a shared helper, not an event-driven architecture.

## References

| File                                                        | Covers       | Purpose                                                                                 |
|-------------------------------------------------------------|--------------|-----------------------------------------------------------------------------------------|
| [design-principles.md](references/design-principles.md)     | Section 9    | Rationale and examples for the design principles                                        |
| [code-style-patterns.md](references/code-style-patterns.md) | Sections 1–5 | Concrete code examples for style, idioms, type safety, class design, and error handling |

## Severity Rubric

| Severity | Definition                                                                                               |
|----------|----------------------------------------------------------------------------------------------------------|
| High     | Causes incorrect behavior, data loss, or security exposure at runtime                                    |
| Medium   | Degrades maintainability, readability, or violates a project convention with no immediate runtime impact |
| Low      | Cosmetic, stylistic, or minor improvement opportunity                                                    |

## Troubleshooting

| Symptom                      | Check                                                                                                                                                             |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Skill not loaded             | Confirm the diff contains `.py` files. The agent selects skills by matching file types in the changed files against skill descriptions.                           |
| No findings generated        | Verify the `Skills Loaded` footer in the review output lists `python-foundational`. If listed but no findings appear, the diff may already satisfy the checklist. |
| Severity seems miscalibrated | Compare against the Severity Rubric above. High requires runtime impact; medium is maintainability-only.                                                          |

## Contributing

Follow these conventions when extending this skill:

* Checklist items belong in SKILL.md. Each bullet is a single, actionable check an agent or reviewer can apply to a diff. Keep bullets concise: one sentence, no code.
* Reference files live in `references/` and provide examples or rationale for the covered checklist items. Each reference file covers a contiguous range of sections. Update the References table when adding a new file.
* Before adding a new checklist item, confirm it does not duplicate an existing bullet in any section. Place it in the section that matches its primary concern. If it spans concerns, prefer the more specific section.
* Name new reference files after the topic they cover (e.g., `async-patterns.md`). Include a frontmatter `description` that states which sections the file supports. Add a row to the References table in SKILL.md.
* Checklist items and examples must be portable across codebases. Use generic module names and describe anti-patterns by their behavior, not by specific directory or file names.

---
