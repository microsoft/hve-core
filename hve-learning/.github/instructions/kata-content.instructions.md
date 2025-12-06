---
applyTo: '../../learning/katas/**/!(README).md'
description: 'Required instructions for individual kata content including YAML requirements (28 fields: 21 required + 7 optional), Quick Context pattern, phase structure, and validation standards'
---

# Kata Content Standards

This file provides comprehensive instructions for creating and maintaining individual kata content files.

**Template File**: When creating new katas, use `../../learning/shared/templates/kata-template.md` as your starting point. The template includes complete YAML structure and content sections.

For category README files, see `kata-category-readme.instructions.md`.
For learning path content, see `learning-path-content.instructions.md`.
For training lab content, see `training-lab-content.instructions.md`.

## Content Type and ms.topic Mapping

Use the following `ms.topic` value in YAML frontmatter for individual katas:

| Content Type         | ms.topic Value  | Description                                                        |
|----------------------|-----------------|--------------------------------------------------------------------|
| Individual Kata      | `how-to-guide`  | Step-by-step technical exercises with specific learning objectives |
| Kata Category README | `kata-category` | Overview page organizing related katas by category                 |
| Learning Path        | `learning-path` | Curated sequence of katas with progressive difficulty              |
| Training Lab Hub     | `tutorial`      | Multi-phase learning experience with comprehensive objectives      |

## **HIGHEST PRIORITY**

1. **NO COMPANY NAMES**: MUST NOT use any company names (real, fictitious, example, or sample) in scenarios. Use role + industry + technical context only (e.g., "You're a platform engineer at a manufacturing company...").
2. **AI Coaching Integration**: MUST include HTML comments in each phase for AI coaching hints.
3. **Quick Context Pattern**: MUST include Quick Context section with 3 subsections: You'll Learn, Prerequisites, Real Challenge.
4. **Standard Footer**: MUST include AI-generated attribution footer at end of all content.
5. **YAML Completeness**: MUST include ALL 28 YAML fields (21 required + 7 optional) with correct types and values.

## Kata Structure and YAML Frontmatter

**Authoritative Sources**:

- **Complete field definitions**: `../../learning/shared/schema/kata-frontmatter-schema.json` (21 required + 7 optional fields)
- **Template structure**: `../../learning/shared/templates/kata-template.md` (use as starting point)

**Schema Overview**: Each kata requires 28 YAML fields (21 required + 7 optional) covering metadata, learning objectives, AI coaching, environment requirements, and search optimization.

### Complexity Rating Scale

<!-- <kata-complexity-scale> -->
Use these ratings for the `kata_difficulty` YAML field (integer 1-5):

| Rating | Label      | Description            | Characteristics                                                                |
|--------|------------|------------------------|--------------------------------------------------------------------------------|
| 1      | Foundation | Starting point         | Minimal prerequisites, single technology, foundational skills                  |
| 2      | Skill      | Building competency    | 1-2 prerequisites, limited integration, some decision-making                   |
| 3      | Advanced   | Integration challenges | Moderate problem-solving, 2-3 technologies, integration patterns               |
| 4      | Expert     | Complex scenarios      | Deep expertise required, 3+ technologies, architectural decisions              |
| 5      | Legendary  | Mastery-level          | Extensive prerequisites, multi-system orchestration, production considerations |
<!-- </kata-complexity-scale> -->

### Field Structure Reference

**Complete YAML structure with all 28 fields and inline documentation**: See `../../learning/shared/templates/kata-template.md`

**Key Points**:

- 21 required fields, 7 optional fields
- Strict typing enforced by JSON schema
- All arrays can be empty `[]` when no items apply
- Date format: `MM/DD/YYYY` (US format)

### AI Coaching Configuration Fields

Three YAML fields control coaching behavior:

**`ai_coaching_level`** (required enum):

- `minimal`: Basic hints only, maximum learner discovery
- `guided`: Balanced guidance with strategic hints
- `adaptive`: Dynamic coaching based on learner progress

**`scaffolding_level`** (required enum):

- `heavy`: Step-by-step instructions with code samples
- `medium-heavy`: Detailed guidance with some code provided
- `light`: High-level objectives, minimal code examples
- `minimal`: Problem statement only with reference links

**`hint_frequency`** (required enum):

- `none`: No hints in HTML comments
- `strategic`: Key decision points only
- `frequent`: Multiple hints throughout
- `on-demand`: Learner-initiated only (future feature)

## Kata Content Structure Pattern

All kata content follows a standardized structure with specific header hierarchy and section requirements.

### Header Hierarchy Rules

- **H2 (`##`) for major sections**: Quick Context, phases, Validation, What's Next, Resources
- **H3 (`###`) for subsections**: Phase subsections, prerequisite details, troubleshooting items
- **No H4+ headers**: Keep hierarchy flat for readability and accessibility

**Rationale**: Deep nesting (H4, H5, H6) creates cognitive overhead and accessibility issues. If you need H4+, split content into multiple katas or simplify structure.

❌ **Anti-pattern**:

```markdown
## Phase 1
### Step 1
#### Substep A
##### Detail 1
```

✅ **Preferred**:

```markdown
## Phase 1: Step 1

**Substep A**: Detail 1
```

### Phase Flexibility

- **Allowed phase counts**: 2, 3, 4, or 5 phases
- **Standard**: 3 phases (most common, recommended for balance)
- **Minimum**: 2 phases (simple concepts only)
- **Maximum**: 5 phases (complex multi-step scenarios only)
- **Numbering**: Sequential (Phase 1, Phase 2, Phase 3, etc.)
- **YAML alignment**: `phases` field and `phase_structure` array must match actual content
- **Rationale**: More than 5 phases indicates content should be split into multiple katas

### Checkbox Pattern for Steps Sections

Within **Steps** sections under tasks/phases, use this specific checkbox pattern for progress tracking:

**Core Rules**:

- Numbered items (1., 2., 3., etc.) do NOT have checkboxes
- Sub-items under numbered steps CAN have checkboxes `- [ ]` for actionable steps
- Not all sub-items require checkboxes

**Items that GET checkboxes**:

- Actionable steps learners should complete: `- [ ] Do this specific action`
- **Expected result** statements: `- [ ] **Expected result**: Outcome achieved`
- **Success check** when it describes an actionable validation: `- [ ] **Success check**: Run validation command`

**Items that do NOT get checkboxes**:

- **Pro tip**: Helpful context and guidance
- **Validation checkpoint**: Questions to check understanding (not actionable)
- **Success check**: Non-actionable verification criteria (descriptive only)
- **Success criteria**: Overall proficiency indicators

**Example Pattern**:

```markdown
**Steps**:

1. **Create** research document
   - [ ] In Task Researcher chatmode, say: *"Help me research..."*
   - [ ] Ask for output as a comparison table
   - **Pro tip**: Task Researcher auto-saves to `.copilot-tracking/research/`
   - [ ] **Expected result**: Research document framework created

2. **Analyze** findings
   - [ ] Review comparison table for patterns
   - [ ] Identify clear winners and losers for each criterion
   - **Validation checkpoint**: Can you explain the key trade-offs?
   - [ ] **Expected result**: Clear understanding of technology differences

3. **Document** conclusions
   - [ ] Create summary with justified recommendation
   - **Success check**: Summary includes evidence from research
   - [ ] **Expected result**: Professional documentation ready for review
```

**Rationale**: Checkboxes provide progress tracking for actionable steps while keeping contextual guidance (tips, validation questions) visually distinct without checkbox clutter.

### Standard Section Template

<!-- <kata-content-structure> -->
```markdown
# Kata: [Title]

Brief introduction paragraph explaining the kata's purpose and what learners will achieve.

## Quick Context

[See Quick Context section below for 3 required subsections]

## Phase 1: [Phase Title]

[AI coaching HTML comment with hints]

### [Subsection if needed]

Instructional content with clear steps.

**Example:**
\```bash
# Sample command
kubectl get pods
\```

## Phase 2: [Phase Title]

[AI coaching HTML comment with hints]

### [Subsection if needed]

Continued learning content.

## Phase 3: [Phase Title]

[AI coaching HTML comment with hints]

### [Subsection if needed]

Final phase content.

## Validation

Steps to verify successful completion of the kata.

1. Check step 1
2. Check step 2
3. Check step 3

## What's Next

- Link to related katas
- Suggested learning paths
- Additional resources

## Resources

- [Official Documentation](https://learn.microsoft.com)
- [GitHub Repository](https://github.com)

[Standard Footer - see footer section below]
```
<!-- </kata-content-structure> -->

## Quick Context Section

MUST include exactly 3 subsections in this order:

<!-- <kata-quick-context> -->
```markdown
## Quick Context

### You'll Learn

- Specific skill 1
- Specific skill 2
- Specific skill 3

### Prerequisites

- Prerequisite 1 (link to kata if applicable)
- Prerequisite 2
- Azure subscription with sufficient credits

### Real Challenge

You're a [role] at a [industry type] company working on [technical context without company name]. Your team needs to [specific challenge]. This kata walks you through [solution approach] using [technologies].

**Note**: This kata uses role-based scenarios without company names to maintain focus on technical learning objectives.

**Additional Examples**:
- "You're a DevOps engineer at a healthcare provider implementing HIPAA-compliant edge computing. Your infrastructure requires..."
- "As a solutions architect for an energy company, you're tasked with deploying real-time monitoring across distributed wind farms..."
- "Your role as a platform engineer at a financial services firm involves securing container workloads for PCI-DSS compliance..."
```
<!-- </kata-quick-context> -->

### Quick Context Rules

1. **You'll Learn**: 3-5 bullet points, action-oriented, specific
2. **Prerequisites**: Include technical prerequisites, link to prerequisite katas
3. **Real Challenge**: Describe role + industry + technical context (NO company names)
4. **Scenario Focus**: Technical challenge and solution approach

## No Company Names Policy

### **CRITICAL REQUIREMENT**

**MUST NOT use any company names** in kata scenarios, examples, or learning content:

- ❌ Real company names (Microsoft, Amazon, Google, etc.)
- ❌ Fictitious company names (Contoso, Fabrikam, Northwind, etc.)
- ❌ Example company names (Acme, Example Corp, Sample Industries, etc.)
- ❌ Sample company names (Demo Company, Test Corp, etc.)

### Approved Scenario Format

Instead, use **role + industry + technical context**:

✅ **Good Examples:**

- "You're a platform engineer at a manufacturing company implementing AI..."
- "Your team at a retail organization needs to deploy IoT sensors..."
- "As a DevOps engineer for a logistics provider, you must configure..."

❌ **Bad Examples:**

- "Contoso Manufacturing needs to deploy..."
- "Fabrikam Retail is implementing..."
- "Northwind Logistics wants to configure..."

### Rationale

- **Focus on Learning**: Company names distract from technical content
- **Universal Applicability**: Role-based scenarios apply to any organization
- **Reduces Maintenance**: No need to track approved/deprecated company names
- **Improves Clarity**: Direct technical context without fictional narrative overhead

### Content Review

When reviewing or creating content:

1. Search for any company name references
2. Replace with role + industry + technical context
3. Verify scenario still provides necessary context
4. Ensure learning objectives remain clear

## AI Coaching Integration

Each phase MUST include an HTML comment with AI coaching hints for adaptive learning assistance.

### Coaching Format

<!-- <ai-coaching-pattern> -->
```html
<!-- AI_COACH: [Guidance for AI to provide contextual help] -->
```
<!-- </ai-coaching-pattern> -->

### Coaching Tone Guidelines

- **Socratic questioning preferred**: "Consider what happens when...", "Think about how...", "What if you tried..."
- **Encouraging and constructive**: Focus on learning, not just answers
- **Avoid direct commands**: Guide learners to discover solutions

**Good Examples:**

- "Consider checking the pod status to understand what might be causing the issue."
- "Think about how the namespace affects resource visibility. What command could help verify this?"
- "If the service isn't accessible, what networking components should you investigate first?"

**Poor Examples**:

- "Run kubectl get pods to check status." (Too directive)
- "You need to fix the namespace issue." (Not guiding discovery)
- "This is wrong because..." (Discouraging)

**Configuration Examples**:

- Good: "Consider how environment variables affect service discovery. What happens if the endpoint changes?"
- Poor: "Set ENDPOINT_URL to the correct value." (Too directive)

**Debugging Examples**:

- Good: "When logs show connection timeouts, what network components could be involved?"
- Poor: "Check your firewall rules." (Not guiding discovery)

### Placement

- **One coaching hint per phase**: Place immediately after the phase H2 header, before any content
- **Format**: HTML comment on its own line
- **Contextual guidance**: Reference specific learning objectives for that phase
- **Progressive difficulty**: Earlier phases have more detailed hints, later phases have minimal guidance

**Example Placement**:

```markdown
## Phase 1: Environment Setup

<!-- AI_COACH: This phase introduces basic cluster concepts... -->

Content starts here...
```

### Example Coaching Comments by Phase

```markdown
## Phase 1: Environment Setup

<!-- AI_COACH: This phase introduces basic cluster concepts. If learners struggle with kubectl commands, guide them to check their kubeconfig context and namespace. Encourage exploration of 'kubectl explain' for resource understanding. -->

## Phase 2: Resource Configuration

<!-- AI_COACH: Configuration errors are common here. Rather than providing direct fixes, ask learners to review their YAML syntax and consider what each field controls. Suggest comparing their config to the example structure. -->

## Phase 3: Validation and Testing

<!-- AI_COACH: Validation requires understanding component interactions. If issues arise, prompt learners to trace the data flow between resources. Encourage systematic troubleshooting: check logs, verify connectivity, confirm configurations match requirements. -->
```

## Kata Template and Validation

### Using the Template

1. **Copy template file**: Copy `../../learning/shared/templates/kata-template.md` to your new kata location
2. **Replace all placeholders**: Update YAML frontmatter with your kata's values
3. **Verify YAML completeness**: Ensure all 28 fields (21 required + 7 optional) are present
4. **Follow structure**: Maintain the standard section order
5. **Add AI coaching**: Include HTML comments in each phase

### Template Location

- Path: `../../learning/shared/templates/kata-template.md`
- Contains: Complete YAML structure + content sections
- Updated: Reflects latest standards and requirements

### Validation Script

**Location**: `scripts/kata-validation/Validate-Katas.ps1`

**Usage**:

```powershell
# From repository root
.\scripts\kata-validation\Validate-Katas.ps1

# Validate including individual kata files
.\scripts\kata-validation\Validate-Katas.ps1 -IncludeIndividualKatas

# Run specific validation types
.\scripts\kata-validation\Validate-Katas.ps1 -ValidationTypes Fields,Quality
```

**Validation Checks**:

- Template field compliance (28 YAML fields: 21 required + 7 optional)
- Category organization and structure
- Prerequisite chain validation
- Required field completeness
- Content quality standards
- AI coaching schema compliance

**Architecture Note**: Path alignment validation has been removed. Learning paths now own kata membership through unidirectional mapping - paths reference katas, not vice versa. This aligns with the dashboard architecture where `learning-path-manifest.js` serves as the single source of truth.

### Common Validation Failures

| Failure Type              | Description                                       | Fix                                                             |
|---------------------------|---------------------------------------------------|-----------------------------------------------------------------|
| Missing YAML field        | One of the 28 required fields is absent           | Add the field with appropriate value                            |
| Invalid difficulty value  | `kata_difficulty` not in range 1-5                | Set to integer between 1 and 5                                  |
| Broken prerequisite chain | `prerequisite_katas` references non-existent kata | Remove invalid reference or create prerequisite kata            |
| Category mismatch         | `kata_category` doesn't match category README     | Update to match existing category or create new category README |
| Date format error         | Dates not in US format `MM/DD/YYYY`               | Fix to `01/15/2025` format (month/day/year)                     |

### Exit Codes

- **0**: All validations passed
- **1**: One or more failures detected (see output for details)

## Standard Footer

ALL individual kata content files MUST include this footer:

<!-- <learning-content-footer> -->
```markdown
---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
```
<!-- </learning-content-footer> -->

### Footer Placement

- **Position**: After all content sections, before any metadata blocks
- **Separator**: Horizontal rule (`---`) above footer text
- **Format**: Italicized paragraph with markdownlint disable/enable comments
- **Required**: No exceptions, all individual kata files must include this footer

## Validation Checklist

**Priority Guide**: Focus on 🔴 CRITICAL items first, then 🟠 HIGH, then 🟡 MEDIUM. LOW items can be deferred but should not be ignored.

### Kata Content (Individual Katas)

- [ ] 🔴 **CRITICAL**: All 28 YAML fields (21 required + 7 optional) present with correct types
- [ ] 🔴 **CRITICAL**: NO company names used (real, fictitious, example, sample)
- [ ] 🔴 **CRITICAL**: Quick Context section with 3 subsections (You'll Learn, Prerequisites, Real Challenge)
- [ ] 🔴 **CRITICAL**: Standard Copilot footer present
- [ ] 🟠 **HIGH**: AI coaching HTML comments in each phase
- [ ] 🟠 **HIGH**: Phase count matches YAML `phases` field
- [ ] 🟠 **HIGH**: Header hierarchy correct (H2 for major sections, H3 for subsections, no H4+)
- [ ] 🟠 **HIGH**: Complexity rating (1-5) reflects actual difficulty
- [ ] 🟡 **MEDIUM**: Prerequisite katas referenced correctly (array of kata_id values or empty array)
- [ ] 🟡 **MEDIUM**: Scaffolding level appropriate for target audience
- [ ] 🟡 **MEDIUM**: Real-world scenario provides sufficient context without company names
- [ ] 🟡 **MEDIUM**: All code examples are complete and tested
- [ ] **LOW**: Links to external resources are valid
- [ ] **LOW**: Estimated time is realistic

## References

### Project Files

1. **Kata Template**: `../../learning/shared/templates/kata-template.md` - Complete structure with all required fields
2. **Validation Script**: `scripts/kata-validation/Validate-Katas.ps1` - Automated YAML and structure validation
3. **Example Kata**: `../../learning/katas/prompt-engineering/01-prompt-creation-and-refactoring-workflow.md` - Real kata implementation
4. **Category README Instructions**: `kata-category-readme.instructions.md` - Category README structure and requirements
5. **Root Katas README**: `../../learning/katas/README.md` - Overview of all kata categories

### External Documentation

1. **Microsoft Learn Metadata**: [Metadata documentation](https://learn.microsoft.com/contribute/metadata) - Official field definitions

### Related Instruction Files

1. **Learning Path Integration**: `learning-path-content.instructions.md` - Path-specific requirements
2. **Training Lab Integration**: `training-lab-content.instructions.md` - Lab-specific requirements
3. **Markdown Standards**: `markdown.instructions.md` - General markdown formatting rules
4. **Commit Messages**: `commit-message.instructions.md` - Conventional commit format for kata changes
