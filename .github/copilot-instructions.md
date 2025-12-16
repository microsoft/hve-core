# HVE Learning Platform AI Agent Instructions

## Architecture Overview

This is an **AI-assisted learning platform** that provides structured learning through katas (15-45 min exercises), training labs (2+ hours), and learning paths. The platform operates in two modes:

1. **Learning Mode**: AI coaches guide learners through exercises using OpenHack-style discovery methodology
2. **Content Creation Mode**: AI assists developers in creating validated, schema-compliant learning content

**Key Components**:

- `.github/agents/`: Chat agents for coaching (`learning-kata-coach`, `learning-lab-coach`, `learning-content-creator`)
- `.github/instructions/`: Scoped instruction files for different content types (applied via `applyTo` patterns)
- `learning/shared/`: Templates, schemas, and content guidelines
- `docs/_server/schemas/`: Progress tracking and API schemas (JSON Schema format)
- `scripts/learning/`: PowerShell validation and catalog generation scripts

## Critical Content Standards

### YAML Frontmatter Requirements

**ALL kata content MUST have exactly 28 YAML fields** (21 required + 7 optional). Key fields:

```yaml
kata_id: "category-name-100-short-title"  # kebab-case, includes difficulty number
kata_category: ["category-slug"]           # Array with single category matching directory
kata_difficulty: 1-5                       # 1=Foundation, 2=Skill, 3=Advanced, 4=Expert, 5=Legendary
estimated_time_minutes: 45                 # 5-minute increments, must be accurate ±10%
ai_coaching_level: adaptive                # minimal|guided|adaptive
scaffolding_level: medium-heavy            # heavy|medium-heavy|light|minimal
hint_strategy: progressive                 # progressive|direct|minimal
```

**Authoritative schema**: `learning/shared/schema/kata-frontmatter-schema.json` (190 lines)
**Template**: `learning/shared/templates/kata-template.md` - ALWAYS use as starting point

### Content Type Detection by File Path

The `.github/instructions/` files use `applyTo` glob patterns to scope their rules:

- `learning/katas/**/!(README).md` → `kata-content.instructions.md` (28 YAML fields, Quick Context pattern)
- `learning/katas/**/README.md` → `kata-category-readme.instructions.md` (category scaffolding structure)
- `learning/paths/**/*.md` → `learning-path-content.instructions.md` (double checkbox navigation)
- `learning/training-labs/**/*.md` → `training-lab-content.instructions.md` (phase table structure)
- `**/*.md` → `markdown.instructions.md` (markdownlint compliance, ATX headings, YAML frontmatter)

### Mandatory Content Patterns

**Quick Context Section** (all katas):

```markdown
## Quick Context

**You'll Learn**: [specific outcome]
**Real Challenge**: [one paragraph scenario]
**Your Task**: [clear deliverable]
```

**NO COMPANY NAMES** in scenarios - use "role + industry + technical context" (e.g., "You're a platform engineer at a manufacturing company...")

**AI Coaching Comments** - embed hints in HTML for coach agents:

```markdown
<!-- HINT: If learner stuck on X, suggest checking Y -->
```

**Standard Footer** - all content must include AI-generated attribution

## Validation & Quality Gates

### Validation Script

**Primary Tool**: `scripts/learning/kata-validation/Validate-Katas.ps1`

```bash
# Validate specific kata (CORRECT invocation - direct execution)
pwsh ./scripts/learning/kata-validation/Validate-Katas.ps1 -KataPath "learning/katas/category/01-kata.md"

# Validate all katas in directory
pwsh ./scripts/learning/kata-validation/Validate-Katas.ps1 -KataDirectory "learning/katas"

# ❌ NEVER use & operator - causes silent failure without validation
```

**Validation Checks**:

- YAML frontmatter schema compliance (all 28 fields)
- Prerequisite chain integrity (no circular dependencies)
- Category directory alignment
- Checkbox structure (flat, not nested)
- Inclusive language (no "master/mastery")
- Time accuracy validation
- AI coaching integration points

### Checkbox Structure Rules

✅ **CORRECT** - Flat structure:

```markdown
- [ ] Complete step 1
- [ ] Complete step 2
- [ ] Verify result
```

❌ **INCORRECT** - Nested content causes CSS strikethrough issues:

```markdown
- [ ] Setup validation:
  - Nested bullet (breaks rendering)
```

## Developer Workflows

### Creating New Kata Content

1. **Use template**: `learning/shared/templates/kata-template.md`
2. **Follow category structure**: `learning/katas/category-name/###-kata-name.md` (numbering indicates difficulty)
3. **Validate before commit**: Run `Validate-Katas.ps1` on your file
4. **Test instructions**: Verify in clean environment with target scaffolding level

### Working with Chat Agents

When coding in this repository, you may interact with specialized chat agents:

- **@learning-kata-coach**: Use Socratic method, provide progressive hints, avoid direct answers
- **@learning-content-creator**: Collaborative content development with template application
- **@learning-lab-coach**: Multi-phase system coaching

**Agent Constraints**:

- Keep responses concise for chat pane (no walls of text)
- Never use HTML `<input>` elements in responses
- Reference instruction files when making content edits

### Progress Tracking Integration

The platform uses structured JSON schemas for AI coach state management:

- `docs/_server/schemas/kata-progress-schema.json` - Learner checkpoint tracking
- `docs/_server/schemas/learning-path-progress-schema.json` - Multi-kata journey state
- `docs/_server/schemas/self-assessment-schema.json` - Skill evaluation data

Coaches read/write these during sessions to maintain context across interactions.

## Project-Specific Conventions

### Kata Difficulty Numbering

File names encode difficulty: `100-foundation.md`, `200-skill.md`, `300-advanced.md`, `400-expert.md`, `500-legendary.md`

This is separate from `kata_difficulty` YAML field (1-5 integer) but should align.

### Scaffolding Levels Define Content Depth

- **Heavy**: Step-by-step with expected outputs and code samples
- **Medium-heavy**: Framework with reference links and partial guidance
- **Light**: High-level objectives with minimal examples
- **Minimal**: Problem statement only, reference links for context

Match content detail to declared `scaffolding_level` in YAML.

### OpenHack Coaching Methodology

Content is designed for **discovery-based learning**:

- Challenges drive motivation (not lectures)
- Learners explore and experiment
- Failure is expected and positive
- AI coaches guide but don't prescribe solutions

When writing kata content, phrase instructions as challenges/objectives rather than step-by-step procedures (unless scaffolding is heavy).

## Integration Points

### VS Code Extension

`extension/package.json` registers 3 chat agents and 6 instruction files. The extension embeds all `.github/agents/` and `.github/instructions/` content, making them available in any workspace where the extension is installed.

### GitHub MCP Server

Required for AI coaches to:

- Track progress across sessions
- Access kata content from multiple repositories (CAIRA, edge-ai, etc.)
- Create personalized learning paths
- Interact with learner's GitHub context

Configure in VS Code before using learning modes.

## Common Pitfalls

- **Forgetting kata_id format**: Must be `category-difficulty-short-name` (kebab-case)
- **Nested checkboxes**: Causes CSS strikethrough on parent content
- **Missing YAML fields**: Schema requires all 28 fields, check with validation script
- **Incorrect validation invocation**: Using `&` operator causes silent failure
- **Time estimates**: Must be realistic (±10%) and 5-minute increments
- **Mixing content types**: Different `ms.topic` values for katas vs category READMEs vs paths

## Commit Message Guidelines

This document provides instructions for generating standardized commit messages.

### Format Requirements

- Use Conventional Commit Messages
- All changes MUST be in imperative mood

### Types

Types MUST be one of the following:

- `feat` - A new feature
- `fix` - A bug fix
- `refactor` - A code change that neither fixes a bug nor adds a feature
- `perf` - A code change that improves performance
- `style` - Changes that do not affect the meaning of the code
- `test` - Adding missing tests or correcting existing tests
- `docs` - Documentation only changes (excluding: `*.instructions.md`, `*.prompt.md`, `*.chatmode.md`, as these are prompts and instructions likely meaning the changes are `feat`, `chore`, etc)
- `build` - Changes that affect the build system or external dependencies
- `ops` - Changes to operational components
- `chore` - Other changes that don't modify src or test files

### Scopes

Scopes MUST be one of the following:

- `(prompts)`
- `(instructions)`
- `(settings)`
- `(cloud)`
- `(edge)`
- `(application)`
- `(tools)`
- `(resource-group)`
- `(security-identity)`
- `(observability)`
- `(data)`
- `(fabric)`
- `(messaging)`
- `(vm-host)`
- `(cncf-cluster)`
- `(iot-ops)`
- `(blueprints)`
- `(terraform)`
- `(bicep)`
- `(scripts)`
- `(adrs)`
- `(build)`
- `(azureml)`

### Description

- Description MUST be short and LESS THAN 100 bytes
- Examples:

```txt
feat: update logic with new feature
chore: cleaned up and moved code from A to B
feat(iot-ops): add parameters to take name instead of id
```

### Body (Optional)

For larger changes only:

- Body starts with a blank line
- Contains a summarized bulleted list (0-5 items AT MOST)
- MUST be LESS THAN 300 bytes

### Footer

- Footer MUST start with a blank line
- Must include an emoji that represents the change
- Must end with `- Generated by Copilot`

### Example Complete Commit Message - Large

```txt
feat(cloud): add new authentication flow

- add commit message, markdown, C# along with C# test instructions
- introduce task planner and researcher, prompt builder, and adr creation chatmodes
- configure markdownlint and VS Code workspace settings
- add ADO work items prompts for getting and preparing my work items
- add .gitignore and cleanup README newlines

🔐
- Generated by Copilot
```
