---
description: "Validation selection matrix for prompt-refactor runs"
---

# Prompt Refactor Validation Matrix

Use this matrix after applying refactor edits and before the final response. Select validations based on the changed artifact types and the repository capabilities available in the current workspace. When a validation is not available, skip it explicitly and record the reason.

## Operator Prerequisites

Use this matrix only when you have repository checkout access, permission to run the relevant validation commands, and enough prompt-artifact familiarity to interpret Markdown, frontmatter, schema, and eval output. Escalate instead of guessing when permissions are missing, tools are unavailable, validation output is ambiguous, or the available check would be broader or more destructive than the requested refactor scope.

## Selection Rules

* Validate every changed file with the narrowest relevant checks available.
* Prefer repository-provided commands when they exist, but treat command names as examples rather than universal requirements.
* Include at least one changed-file scope check so the run proves it stayed within the requested edit boundary.
* Record skipped validations when tools, dependencies, or repository commands are unavailable.
* Do not run broad or destructive checks when a narrower read-only check can validate the same requirement.

## Matrix

| Changed artifact                          | Recommended validation                                                                                        | Example checks                                                                        |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Prompt, agent, instruction, or skill text | Markdown structure, link syntax, whitespace, and changed-file scope                                           | Markdown linting, whitespace checks, `git diff --check`, changed-file review          |
| Prompt or agent frontmatter               | Frontmatter schema, required fields, model/tool/handoff fields, and protocol shape                            | Frontmatter/schema validation, editor diagnostics, artifact-specific validation       |
| Instruction frontmatter                   | `applyTo` glob validity, schema fields, and artifact-specific constraints                                     | Frontmatter/schema validation, editor diagnostics, instruction artifact validation    |
| Skill package                             | Skill directory structure, skill frontmatter, bundled reference links, optional scripts, and package metadata | Package-specific skill validation, Markdown link checks, artifact-specific validators |
| Cross-artifact references                 | Semantic references to skills, prompts, agents, instructions, and bundled skill resources                     | Reference review against local artifact metadata, link checks, portability review     |
| Final response contract                   | Required summary fields, validation status, skipped validations, and remaining issue reporting                | Checklist review against the skill or prompt's response contract                      |

## Reporting

The final response includes:

* Changed files
* Refactor rationale
* Evaluation or validation status
* Skipped validations with reasons
* Remaining issues
