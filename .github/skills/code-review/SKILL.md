---
name: code-review
description: "Shared knowledge base for code reviews, including output formats, severity taxonomy, lens checklists, context-bootstrap, and depth tiers."
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-21"
---

# Code Review — Skill Entry

This skill is the canonical code review reference contract for HVE Core. Agents and instructions invoke this skill by name and rely on it to own review depth, perspective lenses, output formatting, and severity classification.

---

## Context-Bootstrap Procedure (Tier 0)

Before initiating a review, the following context must be established to scope the analysis:

1. **Identify Scope**: Determine the current branch and the comparison base branch (e.g., `origin/main`).
2. **Compute Diff**: Generate the diff between the base and the current branch, including working-tree supplements for untracked or unstaged files.
3. **Filter Artifacts**: Exclude non-source artifacts from the file list.
4. **Extract Metadata**: Collect the list of changed files, untracked files, and their unique file extensions.
5. **Classify Size**: Determine the T-Shirt size (XS, S, M, L, XL) based on the file count and diff line count to dictate the review strategy.
6. **Generate State**: Output a structured state object (e.g., `diff-state.json`) containing the branch, base, file lists, extensions, size classification, and paths to the diff patch and findings folder.

---

## Depth Tier Definitions

Reviews are conducted at one of three depth levels, mapped from the T-Shirt size classification:

* **Tier 1 (Basic)**: XS / S ( <20 files, <400 lines )
  *Strategy*: Single-pass, surface-level validation.

* **Tier 2 (Standard)**: M (20–49 files, 400–999 lines)
  *Strategy*: Focused analysis with grouping or scoped passes.

* **Tier 3 (Comprehensive)**: L / XL (50+ files, 1000+ lines)
  *Strategy*: Batched deep analysis prioritizing high-risk areas.

---

## Severity Taxonomy

* **Critical** → System-breaking issue, security vulnerability, or data loss risk
* **High** → Major functional bug or incorrect behavior
* **Medium** → Maintainability, edge-case, or performance issue
* **Low** → Minor improvement or stylistic issue

---

## Verdict Determination

* Any **Critical** or **High** findings →  Request changes
* Only **Medium** or **Low** findings →  Approve with comments
* No findings →  Approve

---

## Output Format

All reviews must consolidate into a unified report structure:

1. **Executive Summary**: Total files changed, issue counts by severity
2. **Changed Files Overview**: File, Lines Changed, Risk Level, Issues Found
3. **Issues by Severity**: Critical → High → Medium → Low
4. **Positive Changes**
5. **Testing Recommendations**
6. **Professional Review Disclaimer**

---

## Issue Template

Each finding must follow this structure:

````markdown
#### Issue {number}: [Brief descriptive title] [Lens Tag]

**Severity**: Critical/High/Medium/Low  
**Category**: [e.g., Logic, Security, Accessibility]  
**File**: `path/to/file`  
**Lines**: 45-52  

### Problem
[Describe the issue and impact]

### Current Code
```language
[Code snippet]
```

### Recommendation
Provide a clear fix or improvement suggestion.
````

---

## Perspective Lens Checklists

### Functional
Focuses on correctness and behavior.
- Logic errors (conditions, state transitions)
- Edge cases (nulls, boundaries, empty inputs)
- Error handling (exceptions, retries, cleanup)
- Concurrency issues (race conditions, shared state)
- API contract correctness

### Standards
Focuses on code quality and maintainability.
- Naming conventions
- Code structure and modularity
- Duplication and complexity
- Proper use of design patterns

### Accessibility
Focuses on usability for assistive technologies.
- Perceivable (contrast, alternatives)
- Operable (keyboard, focus)
- Understandable (labels, clarity)
- Robust (valid markup, ARIA)

### PR (Pull Request Quality)
Focuses on contribution quality.
- Clear PR description
- Clean commit structure
- No unnecessary changes
- Tests and documentation updated

### Security
Focuses on identifying vulnerabilities.
- Input validation
- Authentication/authorization
- Sensitive data exposure
- Injection risks
- Dependency safety

---

## Usage Notes

- Treat this skill as the default entrypoint for all code review workflows.  
- Do not duplicate review logic in agents or prompts.  
- Always select the appropriate depth tier before review.  
- Apply perspectives based on scope and context.
```
