---
title: 'AI Artifacts Common Standards'
description: 'Common standards and quality gates for all AI artifact contributions to hve-core'
---

This document defines shared standards, conventions, and quality gates that apply to **all** AI artifact contributions to hve-core (chatmodes, prompts, and instructions files).

## XML-Style Block Standards

All AI artifacts use XML-style HTML comment blocks to wrap examples, schemas, templates, and critical instructions. This enables automated extraction, better navigation, and consistency.

### Requirements

* **Tag naming**: Use kebab-case (e.g., `<!-- <example-valid-frontmatter> -->`)
* **Matching pairs**: Opening and closing tags MUST match exactly
* **Unique names**: Each tag name MUST be unique within the file (no duplicates)
* **Code fence placement**: Place code fences **inside** blocks, never outside
* **Nested blocks**: Use 4-backtick outer fence when demonstrating blocks with code fences
* **Single lines**: Opening and closing tags on their own lines

### Valid XML-Style Block Structure

````markdown
<!-- <example-configuration> -->
```json
{
  "enabled": true,
  "timeout": 30
}
```
<!-- </example-configuration> -->
````

### Demonstrating Blocks with Nested Fences

When showing examples that contain XML blocks with code fences, use 4-backtick outer fence:

`````markdown
````markdown
<!-- <example-bash-script> -->
```bash
#!/bin/bash
echo "Hello World"
```
<!-- </example-bash-script> -->
````
`````

### Common Tag Patterns

* `<!-- <example-*> -->` - Code examples
* `<!-- <schema-*> -->` - Schema definitions
* `<!-- <pattern-*> -->` - Coding patterns
* `<!-- <convention-*> -->` - Convention blocks
* `<!-- <anti-pattern-*> -->` - Things to avoid
* `<!-- <reference-sources> -->` - External documentation links
* `<!-- <validation-checklist> -->` - Validation steps
* `<!-- <file-structure> -->` - File organization

### Common XML Block Issues

❌ **Missing closing tag**:

```markdown
<!-- <example-code> -->

```python
def hello(): pass
```

````text

✅ **Proper opening and closing**:

```markdown
<!-- <example-code> -->

```python
def hello(): pass
```

<!-- </example-code> -->
````text

❌ **Duplicate tag names**:

```markdown
<!-- <example-code> -->
Code here...
<!-- </example-code> -->

<!-- <example-code> -->  # ERROR: Duplicate!
More code...
<!-- </example-code> -->
```

✅ **Unique tag names**:

```markdown
<!-- <example-python-function> -->
Code here...
<!-- </example-python-function> -->

<!-- <example-bash-script> -->
More code...
<!-- </example-bash-script> -->
```

## Markdown Quality Standards

All AI artifacts MUST follow these markdown quality requirements:

### Heading Hierarchy

* Start with H1 title
* No skipped levels (H1 → H2 → H3, not H1 → H3)
* Use H1 for document title only
* Use H2 for major sections, H3 for subsections

### Code Blocks

* All code blocks MUST have language tags
* Use proper language identifiers: `bash`, `python`, `json`, `yaml`, `markdown`, `text`, `plaintext`
* No naked code blocks without language specification

❌ **Bad**:

````markdown
```
code without language tag
```
````

✅ **Good**:

````markdown
```python
def example(): pass
```
````

### URL Formatting

* No bare URLs in prose
* Wrap in angle brackets: `<https://example.com>`
* Use markdown links: `[text](https://example.com)`

❌ **Bad**:

```markdown
See https://example.com for details.
```

✅ **Good**:

```markdown
See <https://example.com> for details.
# OR
See [official documentation](https://example.com) for details.
```

### List Formatting

* Use consistent list markers (prefer `*` for bullets)
* Use `-` for nested lists or alternatives
* Numbered lists use `1.`, `2.`, `3.` etc.

### Line Length

* Target ~500 characters per line
* Exceptions: code blocks, tables, URLs, long technical terms
* Not a hard limit, but improves readability

### Whitespace

* No hard tabs (use spaces)
* No trailing whitespace (except 2 spaces for intentional line breaks)
* File ends with single newline character

### File Structure

* Starts with frontmatter (YAML between `---` delimiters)
* Followed by markdown content
* Ends with attribution footer
* Single newline at EOF

## RFC 2119 Directive Language

Use standardized keywords for clarity and enforceability:

### Required Behavior

* **MUST** / **WILL** / **MANDATORY** / **REQUIRED** / **CRITICAL**
* Indicates absolute requirement
* Non-compliance is a defect

**Example**:

```markdown
All functions MUST include type hints for parameters and return values.
You WILL validate frontmatter before proceeding (MANDATORY).
```

### Strong Recommendations

* **SHOULD** / **RECOMMENDED**
* Indicates best practice
* Valid reasons may exist for exceptions
* Non-compliance requires justification

**Example**:

```markdown
Examples SHOULD be wrapped in XML-style blocks for reusability.
Functions SHOULD include docstrings with parameter descriptions.
```

### Optional/Permitted

* **MAY** / **OPTIONAL** / **CAN**
* Indicates permitted but not required
* Implementer choice

**Example**:

```markdown
You MAY include version fields in frontmatter.
Contributors CAN organize examples by complexity level.
```

### Avoid Ambiguous Language

❌ **Ambiguous (Never Use)**:

```markdown
You might want to validate the input...
It could be helpful to add docstrings...
Perhaps consider wrapping examples...
Try to follow the pattern...
Maybe include tests...
```

✅ **Clear (Always Use)**:

```markdown
You MUST validate all input before processing.
Functions SHOULD include docstrings.
Examples SHOULD be wrapped in XML-style blocks.
You MAY include additional examples.
```

## Common Validation Standards

All AI artifacts are validated using these automated tools:

### Validation Commands

Run these commands before submitting:

```bash
# Validate frontmatter against schemas
npm run lint:frontmatter

# Check markdown quality
npm run lint:md

# Spell check
npm run spell-check

# Validate all links
npm run lint:md-links

# PowerShell analysis (if applicable)
npm run lint:ps
```

### Quality Gates

All submissions MUST pass:

* **Frontmatter Schema**: Valid YAML with required fields
* **Markdown Linting**: No markdown rule violations
* **Spell Check**: No spelling errors (or added to dictionary)
* **Link Validation**: All links accessible and valid
* **File Format**: Correct fences and structure

### Validation Checklist Template

Use this checklist structure in type-specific guides:

```markdown
### Validation Checklist

#### Frontmatter
- [ ] Valid YAML between `---` delimiters
- [ ] All required fields present and valid
- [ ] No trailing whitespace
- [ ] Single newline at EOF

#### Markdown Quality
- [ ] Heading hierarchy correct
- [ ] Code blocks have language tags
- [ ] No bare URLs
- [ ] Consistent list markers

#### XML-Style Blocks
- [ ] All blocks closed properly
- [ ] Unique tag names
- [ ] Code fences inside blocks

#### Technical
- [ ] File references valid
- [ ] External links accessible
- [ ] No conflicts with existing files
```

## Common Testing Practices

Before submitting any AI artifact:

### 1. Manual Testing

* Execute the artifact manually with realistic scenarios
* Verify outputs match expectations
* Check edge cases (missing data, invalid inputs, errors)

### 2. Example Verification

* All code examples are syntactically correct
* Examples run without errors
* Examples demonstrate intended patterns

### 3. Tool Validation

* Specified tools/commands exist and work
* Tool outputs match documentation
* Error messages are clear

### 4. Documentation Review

* All sections complete and coherent
* Cross-references valid
* No contradictory guidance

## Common Issues and Fixes

### Issue: Ambiguous Directives

❌ **Bad**:

```markdown
You might want to consider adding validation...
It would be good to include examples...
```

✅ **Good**:

```markdown
You MUST validate all inputs before processing (MANDATORY).
You SHOULD include at least one working example.
```

### Issue: Missing XML Block Closures

❌ **Bad**:

```markdown
<!-- <example-config> -->

```json
{"enabled": true}
```

````text

✅ **Good**:

```markdown
<!-- <example-config> -->

```json
{"enabled": true}
```

<!-- </example-config> -->
````text

### Issue: Code Blocks Without Language Tags

❌ **Bad**:

````markdown

```text
def example():
    pass
```

````text

✅ **Good**:

````markdown

```python
def example():
    pass
```

````text

### Issue: Bare URLs

❌ **Bad**:

````markdown
See https://github.com/microsoft/hve-core for details.
````

✅ **Good**:

````markdown
See <https://github.com/microsoft/hve-core> for details.
# OR
See [hve-core repository](https://github.com/microsoft/hve-core) for details.
```

### Issue: Inconsistent List Markers

❌ **Bad**:

```markdown
* Item 1
- Item 2
* Item 3
```

✅ **Good**:

```markdown
* Item 1
* Item 2
* Item 3
```

### Issue: Trailing Whitespace

❌ **Bad** (spaces after text):

```markdown
Some text here   
More text   
```

✅ **Good**:

```markdown
Some text here
More text
```

### Issue: Skipped Heading Levels

❌ **Bad**:

```markdown
# Title

### Subsection (skipped H2!)
```

✅ **Good**:

```markdown
# Title

## Section

### Subsection
```

## Attribution Requirements

All AI artifacts MUST include attribution footer at the end:

```markdown
---

Brought to you by microsoft/hve-core
```

**Placement**: After all content, before final closing fence.

**Format**:

* Horizontal rule (`---`)
* Blank line
* Exact text: "Brought to you by microsoft/hve-core"
* Or team-specific: "Brought to you by microsoft/edge-ai"

## Getting Help

When contributing AI artifacts:

### Review Examples

* **Chatmodes**: Examine files in `.github/chatmodes/`
* **Prompts**: Examine files in `.github/prompts/`
* **Instructions**: Examine files in `.github/instructions/`

### Check Repository Standards

* Read `.github/copilot-instructions.md` for repository-wide conventions
* Review existing files in same category for patterns
* Use `prompt-builder.chatmode.md` agent for guided assistance

### Ask Questions

* Open draft PR and ask in comments
* Reference specific validation errors
* Provide context about your use case

### Common Resources

* [Contributing Chatmodes](./contributing-chatmodes.md) - Agent configurations
* [Contributing Prompts](./contributing-prompts.md) - Workflow guidance
* [Contributing Instructions](./contributing-instructions.md) - Technology standards
* [Pull Request Template](../.github/PULL_REQUEST_TEMPLATE.md) - Submission checklist

---

Brought to you by microsoft/hve-core
