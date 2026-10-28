---
name: customer-card-render
description: 'Generate customer-card slide content YAML from Design Thinking canonical artifacts'
license: MIT
compatibility: 'Requires Python 3.11+ and uv'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-10-27"
---

# Customer Card Render Skill

Converts canonical Design Thinking markdown artifacts into template-driven `content.yaml` slide definitions.

## Overview

This skill handles the Design Thinking-specific mapping layer: extracting sections from canonical markdown artifacts and filling template-driven `content.yaml` files. It does not build, theme, export, or validate a presentation file. The separate `hve-slides` skill owns HTML presentation authoring and rendering.

Keeping this layer separate means:

* Customer-card mapping logic stays independent from any presentation tooling.
* The skill can be included in packages independently.
* The generated YAML stays a reviewable, renderer-neutral artifact.

## Prerequisites

* Python 3.11+
* `uv` package manager, installed with a package manager that verifies the download against a published hash:

  ```bash
  # Windows
  winget install --id astral-sh.uv -e

  # macOS / Linux (Homebrew)
  brew install uv
  ```

  To install from a release archive instead, download it from the [uv releases page](https://github.com/astral-sh/uv/releases) and check it against its `.sha256` file before extracting.

## Directory Structure

```text
.github/skills/experimental/customer-card-render/
├── SKILL.md
├── pyproject.toml
├── references/
│   └── mapping-spec.md
├── scripts/
│   └── generate_cards.py
├── templates/
│   ├── global-style.yaml
│   ├── persona.content.yaml
│   ├── problem.content.yaml
│   ├── scenario.content.yaml
│   ├── use-case-slide1.content.yaml
│   ├── use-case-slide2.content.yaml
│   ├── use-case-slide3.content.yaml
│   └── vision.content.yaml
└── tests/
    ├── fuzz_harness.py
    └── test_generate_cards.py
```

## Supported Artifact Types

| Artifact Type     | Slide Layout             |
|-------------------|--------------------------|
| Vision Statement  | Single slide             |
| Problem Statement | Single slide             |
| Scenario          | Single slide             |
| Use Case          | **4 slides** (see below) |
| Persona           | Single slide             |

### Use Case 4-Slide Layout

Each Use Case expands into 4 consecutive slides with distinct sections:

| Slide       | Content                                                                      |
|-------------|------------------------------------------------------------------------------|
| **Slide 1** | Use Case Description, Use Case Overview, Business Value, Primary User        |
| **Slide 2** | Secondary User, Preconditions, Steps, Data Requirements                      |
| **Slide 3** | Equipment Requirements, Operating Environment, Success Criteria, Pain Points |
| **Slide 4** | Extensions, Evidence                                                         |

Cards are ordered by artifact type (Vision → Problem → Scenario → Use Case → Persona), then alphabetically by title within each type. Use Cases appear with all 4 slides consecutive (Slide N, N+1, N+2, N+3).

## Generate Slide YAML

### Generate slide YAML from canonical markdown

```bash
python "<customer-card-render-skill-root>/scripts/generate_cards.py" \
  --canonical-dir .copilot-tracking/dt/<project-slug>/canonical \
  --output-dir .copilot-tracking/dt/<project-slug>/render/content
```

Resolve `<customer-card-render-skill-root>` from the loaded skill location before running the command.

#### generate_cards.py CLI Reference

| Flag              | Required | Default                        | Description                                       |
|-------------------|----------|--------------------------------|---------------------------------------------------|
| `--canonical-dir` | No       | `<skill-root>/canonical`       | Directory containing canonical DT markdown files  |
| `--output-dir`    | No       | `<skill-root>/scripts/content` | Directory to write generated `content.yaml` files |
| `-v`, `--verbose` | No       | —                              | Enable debug-level logging                        |

The script reads each markdown file in `--canonical-dir`, detects the artifact type from frontmatter, extracts required sections, and generates `content.yaml` files. Vision, Problem, Scenario, and Persona artifacts produce one slide each. Use Case artifacts produce 4 consecutive slides per use case.

For the section-to-field mapping contract and Use Case 4-slide layout details, see [references/mapping-spec.md](references/mapping-spec.md).

The generated `content.yaml` files are this skill's final output. For an explicitly requested HTML presentation, hand reviewed YAML to `hve-slides` authoring. For a levelled demo, use `hve-demo-material` and its `references/slide-content.md` adapter contract. Resolve skills by name, preserve canonical order, source labels and unknown-knowledge markers, and never claim a presentation exists until rendered and validated. This mapping skill does not synthesize narration or dispatch a deck subagent.

## DT Coach Integration

The `dt-coaching-foundation` skill's `canonical-deck` reference provides opt-in workflow integration for the Design Thinking coaching agent. When a user opts in, the coaching agent offers to generate customer-card YAML at method exit points. The generation command above runs as part of that workflow with `--canonical-dir` and `--output-dir` resolved from the active DT project slug in `.copilot-tracking/dt/`.

Canonical artifacts are produced by the DT coach and live under `.copilot-tracking/dt/<project-slug>/canonical/`.

## Running Tests

```bash
cd "<customer-card-render-skill-root>"
uv sync --group dev
uv run pytest tests/
```

Tests cover parsing, template selection, YAML emission, and regressions. The `tests/fuzz_harness.py` file is an Atheris polyglot fuzz harness for OSSF Scorecard compliance.

## Content Fidelity Note: Use Case Cards

Use Case cards are split across 3 opinionated slides, each with dedicated sections:

- **Slide 1**: Introduces the use case with Description, Overview, Business Value, and Primary User
- **Slide 2**: Details execution with Secondary User, Preconditions, Steps, and Data Requirements
- **Slide 3**: Captures quality criteria with Equipment Requirements, Operating Environment, Success Criteria, Pain Points, and Evidence

This structure ensures all 16 Use Case sections fit legibly across 4 slides without compression. Each section appears in its own textbox with appropriate styling and heading.

For complete mapping details, see [references/mapping-spec.md](references/mapping-spec.md).

## Troubleshooting

| Issue                  | Cause                                   | Solution                                                                               |
|------------------------|-----------------------------------------|----------------------------------------------------------------------------------------|
| `uv` not found         | uv not installed                        | Run `winget install --id astral-sh.uv -e` (Windows) or `brew install uv` (macOS/Linux) |
| Python not found by uv | No Python 3.11+ on PATH                 | Run `uv python install 3.11`                                                           |
| Template not found     | `--canonical-dir` contains unknown type | Check frontmatter `type:` field against supported artifact types                       |
| Empty output directory | No canonical markdown files found       | Confirm `--canonical-dir` path and that files have `---` frontmatter                   |

