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

This skill defines the foundational layer of Python excellence that every piece of code must meet. The calling agent delegates to this skill first during detailed inspection. All specialized skills (security, testing, pydantic, etc.) build on top of these core rules.

This content is a skill rather than an instructions file for three reasons: skills are distributed through the CLI plugin and VS Code extension without requiring consumers to copy files into their repo; new language skills can be added without modifying the review agent itself; and skills are loaded on demand, keeping the context window small when the diff contains no Python.

### Core Checklist

#### 1. Readability & Style

* Clear, descriptive names for variables, functions, and classes.
* Proper spacing, no trailing whitespace, logical grouping of imports.

#### 2. Pythonic Idioms

* Prefer comprehensions and generators over manual loops when clearer.
* Use `with` context managers for files, locks, and DB connections.
* Use `dataclasses` or `NamedTuple` for simple data containers.
* Use `Enum` for fixed sets of values.
* Prefer `pathlib` over `os.path`.
* Use `datetime` with timezone awareness where relevant.

#### 3. Function & Class Design

* Write small, pure functions where possible.
* Apply single responsibility: one function, one job.
* Define clear input/output contracts.
* Document side effects explicitly when they are unavoidable.

#### 4. Type Safety Foundations

* Add type hints on all public functions, methods, module-level variables, and class attributes.
* Use PEP 695 syntax (type statements, generics) on Python 3.12+; use `TypeVar`-based generics for older targets.
* Avoid `Any` except in rare wrapper cases.

#### 5. Error Handling

* Raise specific exceptions; never use bare `except:`. Broad `except Exception:` is acceptable only at application boundaries with logging and re-raise.
* No silent failures.
* Raise meaningful custom exceptions when appropriate.
* Check for uncovered error paths: missing edge cases and unhandled exceptions from callees.

#### 6. Anti-Patterns to Avoid

* No `global` or `nonlocal` unless truly necessary.
* No `eval`, `exec`, or `pickle` on untrusted input.
* No `print` in library or production code; use structured logging.
* No hardcoded secrets or sensitive data.
* No mutable default arguments (`def foo(bar=[])`); use `bar=None` with an internal guard instead.

#### 7. Maintainability

* Write self-documenting code; reserve comments for "why", not "what".
* Follow consistent module-level organization (`__init__.py`, private helpers prefixed `_`).
* Flag technical debt hotspots: functions over 40 LOC, cyclomatic complexity over 10, or logic duplicated across multiple call sites.

#### 8. Architectural Fit

* Confirm the code aligns with existing patterns in the codebase. Red flags: reimplementing functionality already available in shared or common modules, introducing abstractions inconsistent with neighbouring code, or bypassing established service and data layers.
* Confirm the code lives in the right module or package. Red flags: business logic placed in generic utility modules, or domain logic leaking into transport or presentation layers.

## Severity Rubric

* **High:** Causes incorrect behavior, data loss, or security exposure at runtime.
* **Medium:** Degrades maintainability, readability, or violates a project convention with no immediate runtime impact.
* **Low:** Cosmetic, stylistic, or minor improvement opportunity.

## Troubleshooting

| Symptom                      | Check                                                                                                                                                             |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Skill not loaded             | Confirm the diff contains `.py` files. The agent selects skills by matching file types in the changed files against skill descriptions.                           |
| No findings generated        | Verify the `Skills Loaded` footer in the review output lists `python-foundational`. If listed but no findings appear, the diff may already satisfy the checklist. |
| Severity seems miscalibrated | Compare against the Severity Rubric above. High requires runtime impact; medium is maintainability-only.                                                          |

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*