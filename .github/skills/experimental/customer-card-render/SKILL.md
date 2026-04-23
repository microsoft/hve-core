---
name: customer-card-render
description: 'Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires Python 3.11+, uv, and the experimental powerpoint skill'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-21"
---

# Customer Card Render Skill

Converts canonical Design Thinking markdown artifacts into PowerPoint skill `content.yaml` slide definitions and builds the final deck through the shared PowerPoint build pipeline.

## Overview

This skill is a sibling to the experimental powerpoint skill. It handles the Design Thinking-specific mapping layer: extracting sections from canonical markdown artifacts and filling template-driven `content.yaml` files. The PowerPoint skill then owns layout rendering, theming, export, and validation.

Keeping these concerns separate means:

* Customer-card mapping logic stays independent from general PowerPoint capabilities.
* The skill can be included in collections independently.
* Layout primitives, `Invoke-PptxPipeline.ps1`, theming, and validation behavior are not reimplemented here.

For full PowerPoint pipeline documentation, see [powerpoint/SKILL.md](../powerpoint/SKILL.md).

## Prerequisites

* Python 3.11+
* `uv` package manager — install with one of:

  ```bash
  # macOS / Linux
  curl -LsSf https://astral.sh/uv/install.sh | sh

  # Windows
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

  # Via pip (fallback)
  pip install uv
  ```

* The experimental `powerpoint` skill at `.github/skills/experimental/powerpoint/` for the `Invoke-PptxPipeline.ps1` build step

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

### Use Case 3-Slide Layout

Each Use Case expands into 3 consecutive slides with distinct sections:

| Slide       | Content                                                                                |
|-------------|----------------------------------------------------------------------------------------|
| **Slide 1** | Use Case Description, Use Case Overview, Business Value, Primary User                  |
| **Slide 2** | Secondary User, Preconditions, Steps, Data Requirements                                |
| **Slide 3** | Equipment Requirements, Operating Environment, Success Criteria, Pain Points, Evidence |

Cards are ordered by artifact type (Vision → Problem → Scenario → Use Case → Persona), then alphabetically by title within each type. Use Cases appear with all 4 slides consecutive (Slide N, N+1, N+2, N+3).

## Two-Command Flow

### Step 1: Generate slide YAML from canonical markdown

```bash
python .github/skills/experimental/customer-card-render/scripts/generate_cards.py \
  --canonical-dir .copilot-tracking/dt/<project-slug>/canonical \
  --output-dir .copilot-tracking/dt/<project-slug>/render/content
```

#### generate_cards.py CLI Reference

| Flag              | Required | Default                        | Description                                       |
|-------------------|----------|--------------------------------|---------------------------------------------------|
| `--canonical-dir` | No       | `<skill-root>/canonical`       | Directory containing canonical DT markdown files  |
| `--output-dir`    | No       | `<skill-root>/scripts/content` | Directory to write generated `content.yaml` files |
| `-v`, `--verbose` | No       | —                              | Enable debug-level logging                        |

The script reads each markdown file in `--canonical-dir`, detects the artifact type from frontmatter, extracts required sections, and generates `content.yaml` files. Vision, Problem, Scenario, and Persona artifacts produce one slide each. Use Case artifacts produce 3 consecutive slides per use case.

For the section-to-field mapping contract and Use Case 3-slide layout details, see [references/mapping-spec.md](references/mapping-spec.md).

### Step 2: Build PPTX using the PowerPoint skill pipeline

```powershell
./.github/skills/experimental/powerpoint/scripts/Invoke-PptxPipeline.ps1 -Action Build `
  -ContentDir .copilot-tracking/dt/<project-slug>/render/content `
  -StylePath .copilot-tracking/dt/<project-slug>/render/content/global/style.yaml `
  -OutputPath .copilot-tracking/dt/<project-slug>/render/output/customer-cards.pptx
```

The PowerShell orchestrator manages virtual environment setup and dependency installation automatically via `uv sync`. See [powerpoint/SKILL.md](../powerpoint/SKILL.md) for the full `Invoke-PptxPipeline.ps1` parameter reference, template usage, validation, and export options.

## DT Coach Integration

The `dt-canonical-deck` prompt and `dt-canonical-deck.instructions.md` provide opt-in workflow integration for the Design Thinking coaching agent. When a user opts in, the coaching agent offers to build customer cards at method exit points. The two-command flow above runs as part of that workflow with `--canonical-dir` and `--output-dir` resolved from the active DT project slug in `.copilot-tracking/dt/`.

Canonical artifacts are produced by the DT coach and live under `.copilot-tracking/dt/<project-slug>/canonical/`.

## Running Tests

```bash
cd .github/skills/experimental/customer-card-render
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

| Issue                           | Cause                                      | Solution                                                                                 |
|---------------------------------|--------------------------------------------|------------------------------------------------------------------------------------------|
| `uv` not found                  | uv not installed                           | Run `curl -LsSf https://astral.sh/uv/install.sh \| sh` (macOS/Linux) or `pip install uv` |
| Python not found by uv          | No Python 3.11+ on PATH                    | Run `uv python install 3.11`                                                             |
| Template not found              | `--canonical-dir` contains unknown type    | Check frontmatter `type:` field against supported artifact types                         |
| Empty output directory          | No canonical markdown files found          | Confirm `--canonical-dir` path and that files have `---` frontmatter                     |
| PPTX build fails after generate | PowerPoint skill missing or path incorrect | Confirm `powerpoint/` skill exists at `.github/skills/experimental/powerpoint/`          |

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
