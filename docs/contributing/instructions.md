---
title: 'Contributing Instructions to HVE Core'
description: 'Requirements and standards for contributing GitHub Copilot instruction files to hve-core'
author: Microsoft
ms.date: 2025-11-26
ms.topic: how-to
---

This guide defines the requirements, standards, and best practices for contributing GitHub Copilot instruction files (`.instructions.md`) to the hve-core library.

**⚙️ Common Standards**: See [AI Artifacts Common Standards](ai-artifacts-common.md) for shared requirements (XML blocks, markdown quality, RFC 2119, validation, testing).

## What is an Instructions File?

An **instructions file** is a technology-specific or pattern-specific guidance document that defines coding standards, conventions, and best practices for GitHub Copilot to follow when working with particular file types, languages, or frameworks.

## Use Cases for Instructions Files

Create an instructions file when you need to:

* Define language-specific coding standards (e.g., Python, C#, Bash)
* Establish framework-specific conventions (e.g., Terraform, Bicep)
* Document file type requirements (e.g., Markdown, YAML)
* Specify workflow patterns (e.g., commit messages, PR creation)
* Codify project-specific style guidelines
* Auto-apply rules based on file patterns (`applyTo` glob matching)

## File Structure Requirements

### Location

All instruction files **MUST** be placed in:

```text
.github/instructions/
├── language-name.instructions.md        # Language-specific
├── framework-name.instructions.md       # Framework-specific
├── workflow-name.instructions.md        # Workflow-specific
└── subfolder/
        └── specialized.instructions.md      # Organized by domain
```

**Examples**:

* `.github/instructions/python-script.instructions.md`
* `.github/instructions/markdown.instructions.md`
* `.github/instructions/csharp/csharp.instructions.md`
* `.github/instructions/bash/bash.instructions.md`

### Naming Convention

* Use lowercase kebab-case: `python-script.instructions.md`
* Be specific about target: `csharp-tests.instructions.md`
* Include domain prefix when needed: `ado-wit-planning.instructions.md`
* Avoid generic names: `code.instructions.md` ❌ → `python-script.instructions.md` ✅

### File Format

Instruction files **MUST**:

1. Use the `.instructions.md` extension
2. Start with valid YAML frontmatter between `---` delimiters
3. End with single newline character

## Frontmatter Requirements

### Required Fields

**`description`** (string, MANDATORY)

* **Purpose**: Concise explanation of instruction scope and target
* **Format**: Single sentence, 10-200 characters
* **Style**: Sentence case with proper punctuation
* **Example**: `'Required instructions for Python script implementation with type hints and docstrings'`

**`applyTo`** (string, MANDATORY for auto-applied instructions)

* **Purpose**: Glob pattern(s) defining when these instructions activate
* **Format**: Valid glob pattern or comma-separated patterns
* **Scope**: Matches from repository root
* **Examples**:
  * Single pattern: `**/*.py`
  * Multiple files: `**/*.py, **/*.ipynb`
  * Directory scope: `**/src/**/*.sh`
  * Specific paths: `**/.copilot-tracking/pr/new/**`

**`maturity`** (string enum, MANDATORY)

* **Purpose**: Controls which extension channel includes this instruction
* **Valid values**:
  * `stable` - Production-ready, included in Stable and Pre-release channels
  * `preview` - Feature-complete, included in Pre-release channel only
  * `experimental` - Early development, included in Pre-release channel only
  * `deprecated` - Scheduled for removal, excluded from all channels
* **Default**: New instructions should use `stable` unless targeting early adopters
* **Example**: `stable`

### Optional Fields

**`version`** (string)

* **Purpose**: Tracks instruction file revisions
* **Format**: Semantic versioning (e.g., `1.0.0`)
* **Pattern**: `^\d+\.\d+(\.\d+)?$` (major.minor or major.minor.patch)

**`author`** (string)

* **Purpose**: Attribution for instruction creator
* **Example**: `microsoft/hve-core`, `your-team-name`

**`lastUpdated`** (string)

* **Purpose**: Timestamp of last modification
* **Format**: ISO 8601 date (YYYY-MM-DD)

### Frontmatter Example

```yaml
---
description: 'Required instructions for Python script implementation with type hints, docstrings, and error handling'
applyTo: '**/*.py, **/*.ipynb'
maturity: 'stable'
version: '1.0.0'
author: 'microsoft/hve-core'
lastUpdated: '2025-11-19'
---
```

## Content Structure Standards

### Required Sections

#### 1. Title (H1)

* Clear heading describing target technology/pattern
* Should align with filename and scope

```markdown
# Python Script Implementation Instructions
```

#### 2. Overview/Scope

* Explains what these instructions cover
* Defines when they apply
* Lists any prerequisites or assumptions

```markdown
## Scope

These instructions apply to all Python scripts in the repository, covering:

* Code structure and organization
* Type hinting and documentation
* Error handling patterns
* Testing requirements
```

#### 3. Core Standards/Conventions

* Defines mandatory coding patterns
* Uses RFC 2119 keywords (MUST, SHOULD, MAY)
* Organizes by category (structure, naming, patterns)
* Provides rationale for key decisions

```markdown
## Code Structure

Scripts MUST follow this organization:

1. Shebang (if executable)
2. Module docstring
3. Imports (standard library → third-party → local)
4. Constants
5. Functions/classes
6. Main execution block
```

#### 4. Naming Conventions

* Specifies naming patterns for identifiers
* Covers files, functions, classes, variables, constants
* Provides examples of correct usage

```markdown
## Naming Conventions

* **Files**: `snake_case.py` (e.g., `data_processor.py`)
* **Functions**: `snake_case()` (e.g., `process_data()`)
* **Classes**: `PascalCase` (e.g., `DataProcessor`)
* **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MAX_RETRIES`)
* **Private**: `_leading_underscore` (e.g., `_internal_helper()`)
```

#### 5. Code Examples

* Demonstrates correct patterns with working code
* Shows both positive (✅) and negative (❌) examples
* Wraps in XML-style blocks for reusability
* Includes inline comments explaining key points

````markdown
<!-- <example-python-function> -->
```python
def calculate_average(numbers: list[float]) -> float:
    """
    Calculate the arithmetic mean of a list of numbers.

    Args:
        numbers: List of numeric values to average

    Returns:
        Arithmetic mean of the input numbers

    Raises:
        ValueError: If the input list is empty
    """
    if not numbers:
        raise ValueError("Cannot calculate average of empty list")

    return sum(numbers) / len(numbers)
```
<!-- </example-python-function> -->
````

#### 6. Anti-Patterns

* Documents what to avoid
* Explains why patterns are problematic
* Shows correct alternatives

```markdown
## Anti-Patterns

❌ **Bare except clauses**:
```python
try:
    risky_operation()
except:  # DON'T DO THIS
    pass
```

✅ **Specific exception handling**:

```python
try:
    risky_operation()
except FileNotFoundError as e:
    logger.error(f"File not found: {e}")
    raise
```

#### 7. Validation/Testing

* Specifies validation tools and commands
* Defines testing requirements
* Lists quality gates

```markdown
## Validation

All Python code MUST pass:

* **Linting**: `ruff check .`
* **Type checking**: `mypy --strict .`
* **Testing**: `pytest tests/ --cov=src`
* **Coverage**: Minimum 80% line coverage
```

#### 8. Attribution Footer

* **MANDATORY**: Include at end of file

```markdown
---

Brought to you by microsoft/hve-core
```

### XML-Style Block Requirements

See [AI Artifacts Common Standards - XML-Style Block Standards](ai-artifacts-common.md#xml-style-block-standards) for complete rules. Common tags for instructions:

* `<!-- <example-{pattern-name}> -->` - Code examples
* `<!-- <convention-{category}> -->` - Convention blocks
* `<!-- <anti-pattern-{issue}> -->` - Things to avoid
* `<!-- <validation-checklist> -->` - Validation steps
* `<!-- <file-structure> -->` - File organization

### Directive Language Standards

Use RFC 2119 compliant keywords (MUST/SHOULD/MAY). See [AI Artifacts Common Standards - RFC 2119 Directive Language](ai-artifacts-common.md#rfc-2119-directive-language) for complete guidance.

## Pattern Definition Standards

Instructions should clearly define:

### File Organization

Structure for target files:

````markdown
<!-- <file-structure-python-script> -->
```python
#!/usr/bin/env python3
"""
Module-level docstring describing purpose and usage.
"""

# Standard library imports
import os
import sys
from pathlib import Path

# Third-party imports
import requests
import pandas as pd

# Local imports
from .utils import helper_function

# Constants
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30

# Functions and classes
def main() -> int:
    """Main entry point."""
    return 0

# Main execution
if __name__ == "__main__":
    sys.exit(main())
```
<!-- </file-structure-python-script> -->
````

### Code Patterns

Approved implementation patterns:

````markdown
## Error Handling Pattern

<!-- <pattern-error-handling> -->
```python
def process_file(file_path: Path) -> dict[str, Any]:
    """
    Process a configuration file with proper error handling.

    Args:
        file_path: Path to configuration file

    Returns:
        Parsed configuration dictionary

    Raises:
        FileNotFoundError: If configuration file doesn't exist
        ValueError: If configuration is invalid
    """
    if not file_path.exists():
        raise FileNotFoundError(f"Configuration not found: {file_path}")

    try:
        with file_path.open() as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {file_path}: {e}")

    # Validate required keys
    required = {"version", "settings"}
    if not required.issubset(config.keys()):
        missing = required - config.keys()
        raise ValueError(f"Missing required keys: {missing}")

    return config
```
<!-- </pattern-error-handling> -->
````

### Style Conventions

Formatting and style rules:

```markdown
## Style Conventions

* **Indentation**: 4 spaces (no tabs)
* **Line length**: 88 characters (Black formatter default)
* **Quotes**: Double quotes for strings, single for dict keys
* **Imports**: Organized by isort with Black-compatible settings
* **Trailing commas**: Use in multi-line collections
* **Type hints**: Use modern syntax (`list[str]` not `List[str]`)
```

## Validation and Tooling

### Linting Configuration

Specify tools and configurations:

````markdown
## Linting

All Python code MUST pass Ruff checks:

<!-- <config-ruff> -->
```toml
[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]
ignore = ["E501"]  # Line too long (handled by formatter)
```
<!-- </config-ruff> -->

Run: `ruff check . --fix`
````

### Testing Requirements

Define test expectations:

```markdown
## Testing Requirements

* **Coverage**: Minimum 80% line coverage
* **Test location**: `tests/` directory mirroring `src/` structure
* **Test naming**: `test_*.py` files, `test_*` functions
* **Fixtures**: Use pytest fixtures for shared test data
* **Mocking**: Mock external dependencies (file I/O, network calls)

<!-- <example-pytest-test> -->
```python
import pytest
from pathlib import Path
from mymodule import process_file

def test_process_file_valid(tmp_path: Path) -> None:
    """Test processing valid configuration file."""
    config_file = tmp_path / "config.json"
    config_file.write_text('{"version": "1.0", "settings": {}}')

    result = process_file(config_file)

    assert result["version"] == "1.0"
    assert "settings" in result

def test_process_file_missing(tmp_path: Path) -> None:
    """Test handling of missing configuration file."""
    config_file = tmp_path / "missing.json"

    with pytest.raises(FileNotFoundError):
        process_file(config_file)
```
<!-- </example-pytest-test> -->

## Glob Pattern Guidelines

The `applyTo` field uses glob patterns to match files:

### Pattern Syntax

* `*` - Matches any characters except `/`
* `**` - Matches any characters including `/` (recursive)
* `?` - Matches single character
* `[abc]` - Matches any character in brackets
* `{a,b}` - Matches either `a` or `b`

### Common Patterns

```yaml
# Single file extension
applyTo: '**/*.py'

# Multiple extensions
applyTo: '**/*.py, **/*.ipynb'

# Specific directory
applyTo: '**/src/**/*.ts'

# Specific path pattern
applyTo: '**/.copilot-tracking/plans/*.md'

# Exclude pattern (handled by negative patterns in schema-mapping.json)
# Not directly in applyTo, but can be configured
```

### Testing Patterns

Verify your glob pattern matches intended files:

```bash
# PowerShell
Get-ChildItem -Path . -Recurse -Include *.py

# Bash
find . -name "*.py"
```

## Validation Checklist

Before submitting your instructions file, verify:

### File Format Structure

* [ ] File uses `.instructions.md` extension
* [ ] File starts with YAML frontmatter between `---` delimiters
* [ ] File ends with single newline character (EOF)
* [ ] No trailing whitespace on any lines
* [ ] Uses UTF-8 encoding

### Frontmatter

* [ ] Valid YAML between `---` delimiters
* [ ] `description` field present and descriptive (10-200 chars)
* [ ] `applyTo` field with valid glob pattern (if auto-applied)
* [ ] `version` follows semantic versioning format (if present)
* [ ] No trailing whitespace in values

### Content Structure

* [ ] Clear H1 title describing target
* [ ] Overview/scope section
* [ ] Core standards with RFC 2119 keywords
* [ ] Naming conventions documented
* [ ] Code examples wrapped in XML-style blocks
* [ ] Anti-patterns section with alternatives
* [ ] Validation/testing requirements
* [ ] Attribution footer present

### Code Examples

* [ ] All examples are syntactically correct
* [ ] Examples include necessary imports/context
* [ ] Both positive and negative examples provided
* [ ] Examples wrapped in XML-style blocks with unique names
* [ ] Code blocks have language tags
* [ ] Inline comments explain key points

### Common Standards

* [ ] Markdown quality (see [Common Standards - Markdown Quality](ai-artifacts-common.md#markdown-quality-standards))
* [ ] XML-style blocks properly formatted (see [Common Standards - XML-Style Blocks](ai-artifacts-common.md#xml-style-block-standards))
* [ ] RFC 2119 keywords used consistently (see [Common Standards - RFC 2119](ai-artifacts-common.md#rfc-2119-directive-language))

### Technical Validation

* [ ] Glob pattern in `applyTo` is valid and tested
* [ ] All file references point to existing files
* [ ] External links are valid and accessible
* [ ] Tool/command references are correct
* [ ] No conflicts with existing instructions files

### Integration

* [ ] Aligns with `.github/copilot-instructions.md`
* [ ] Follows repository conventions
* [ ] Compatible with existing instructions
* [ ] Does not duplicate existing instruction functionality
* [ ] Glob pattern doesn't conflict with other instructions

## Testing Your Instructions

See [AI Artifacts Common Standards - Common Testing Practices](ai-artifacts-common.md#common-testing-practices) for testing guidelines. For instructions specifically:

1. Verify `applyTo` glob pattern matches intended files
2. Test all code examples execute correctly
3. Have Copilot generate code following your instructions
4. Validate specified linting/validation commands work

## Common Issues and Fixes

### Instructions-Specific Issues

### Invalid Glob Pattern

* **Problem**: Glob patterns that only match root directory or contain syntax errors
* **Solution**: Use `**/` prefix for recursive matching (e.g., `**/*.py` for all Python files recursively)

### Conflicting Patterns

* **Problem**: Multiple instruction files with overlapping glob patterns causing ambiguity
* **Solution**: Make patterns more specific (e.g., `**/tests/**/*.py` vs `**/*.py`) or ensure they target distinct file sets

For additional common issues (XML blocks, markdown, directives), see [AI Artifacts Common Standards - Common Issues and Fixes](ai-artifacts-common.md#common-issues-and-fixes).

## Automated Validation

Run these commands before submission (see [Common Standards - Common Validation](ai-artifacts-common.md#common-validation-standards)):

* `npm run lint:frontmatter`
* `npm run lint:md`
* `npm run spell-check`
* `npm run lint:md-links`

All checks **MUST** pass before merge.

## Related Documentation

* [AI Artifacts Common Standards](ai-artifacts-common.md) - Shared standards for all contributions
* [Contributing Custom Agents](custom-agents.md) - AI agent configuration files
* [Contributing Prompts](prompts.md) - Workflow-specific guidance
* [Pull Request Template](../../.github/PULL_REQUEST_TEMPLATE.md) - Submission requirements

## Getting Help

See [AI Artifacts Common Standards - Getting Help](ai-artifacts-common.md#getting-help) for support resources. For instructions-specific assistance:

* Review existing examples in `.github/instructions/`
* Test glob patterns using file search commands
* Use `prompt-builder.agent.md` agent for assistance

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
