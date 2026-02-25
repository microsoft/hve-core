---
description: M365 Copilot image prompt generation techniques for Design Thinking Method 5 concept visualization with lo-fi enforcement
applyTo: "**/.copilot-tracking/dt/**/method-05**/concepts.yml"
---

# DT Image Prompt Generation

## Purpose and Scope

During **Method 5b (Concept Articulation)**, write visualization prompts that transform user concepts into lo-fi sketches for stakeholder evaluation.

Prompts are authored as part of YAML concept cards and optionally processed by `generate-dalle-images.ps1` or M365 Copilot between Method 5b and 5c.

**When to Offer Image Generation:**

* After drafting concept title and description during Method 5b
* Before Method 5c Silent Review when visual concepts support stakeholder comprehension
* Only if lo-fi prompt structure is clearly explained and enforced

**When Not to Offer:**

* During Method 5a planning (concepts not yet articulated)
* If user prefers text-only concept evaluation
* If prompt violates lo-fi standards (redirect to structure before generating)

## Prompt Generation Approach

Transform concept into visualization prompt using this sequence:

1. **Identify Core Interaction**: What single action or outcome does this concept test?
2. **Extract Visual Elements**: Who (stakeholder archetype), what (tool/object), where (environmental context from Methods 3-4)
3. **Apply Lo-Fi Enforcement**: Add all 5 required style directive layers
4. **Validate 15-Second Test**: Could this be sketched on a napkin in 15 seconds?

**Concept → Prompt Workflow:**

```text
Concept: "Workers scan QR codes to access equipment manuals"
  ↓
Core Interaction: Worker scans code, sees instructions
  ↓
Visual Elements: Stick figure + phone + QR code + simple list
  ↓
Lo-Fi Layers: stick figures, minimal lines, plain background, b&w, no shading
  ↓
Prompt: "Create a simple stick-figure scene of a factory worker pointing
        a phone at a big QR code on a machine; on the phone screen, show
        a plain card with three bullet lines labelled 'Step 1, Step 2, Step 3'.
        Black-and-white line art, stick figures, minimal lines, no shading,
        plain white background."
```

## Image Prompt Structure

**Required Template:**

```text
Create a simple stick-figure sketch showing [ONE CORE INTERACTION].
[Optional: Environmental context if constraint-relevant].
Minimal lines, plain white background, black-and-white line art, no shading.
```

**Components:**

* **Opening**: Action verb + "stick-figure" + subject (e.g., "Create a simple stick-figure sketch showing...")
* **Single Scenario**: One interaction per concept, not multiple use cases
* **Optional Context**: Environmental details only when relevant to constraints from Methods 3-4
* **Terminal Reinforcement**: Combine 3-5 lo-fi descriptors in closing sentence

**Subject, Context, Style, Focus, Exclusions:**

* **Subject**: Stakeholder archetype (worker, nurse, manager) + tool/object
* **Context**: Environmental constraints (factory floor, hospital bed, office desk) only when relevant
* **Style**: Always "stick-figure" or "simple line drawing" with "black-and-white line art"
* **Focus**: Single core interaction validating one key assumption
* **Exclusions**: "no shading", "no detail", "minimal lines" to block implementation detail

## Lo-Fi Visual Requirements

**5-Layer Required Directive Stack (all prompts must include all layers):**

1. **Human Representation**: "stick figures" OR "simple line drawing"
2. **Complexity Reduction**: "minimal lines" (required)
3. **Environmental Simplification**: "plain white background"
4. **Visual Treatment**: "black-and-white line art"
5. **Detail Blocking**: "no shading" OR "no detail"

**Effective Descriptor Vocabulary:**

* Core: "stick figures", "minimal lines", "plain white background", "black-and-white line art", "no shading"
* Supplementary: "simple sketch", "napkin sketch", "whiteboard drawing", "basic shapes"

**Anti-Pattern Vocabulary (never use):**

* "detailed", "interface mockup", "buttons and menus", "production-ready", "polished", "realistic", "high-fidelity"

**Scrappy Principle Alignment:**

* Rough concepts invite structural feedback: "Does this solve the right problem?"
* Polished concepts invite cosmetic feedback: "I'd change the wording here"
* Maintain roughness to preserve validation quality

## Method 5 Workflow Integration

**Method 5b (Concept Articulation)** — Prompts Written Here:

* Draft 2-4 word concept title
* Write 1-2 sentence description covering what and how
* **Create visualization prompt** with mandatory lo-fi structure
* Generate `concepts.yml` artifact with name/description/file/prompt fields
* Validate against 15-second napkin sketch test

**Between Methods 5 and 6** — Images Generated (Optional):

* Batch processing: Run `generate-dalle-images.ps1` with `concepts.yml`
* Interactive: Use M365 Copilot to generate images one-at-a-time
* Review generated PNGs and regenerate if DALL-E violates lo-fi standards

**Method 5c (Concept Evaluation)** — Images Used for Alignment:

* Silent Review sequence with stakeholder representatives
* Visual concepts support 30-second comprehension test
* Three-lens D/F/V evaluation uses text + optional visuals
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

**YAML Concept Card Schema:**

```yaml
concepts:
  - name: Concept Title              # 2-4 words
    description: >-                   # 1-2 sentences, what + how
      Brief explanation of solution.
    file: concept-title.png           # kebab-case
    prompt: >-                        # Stick figures, minimal lo-fi
      Create a simple stick-figure sketch showing [core interaction].
      Minimal lines, plain white background, black-and-white line art, no shading.
```

## Example Prompt Patterns

### Example 1: Manufacturing Safety Concept

**Concept**: QR Snap Manuals — Workers scan machine QR codes to access step-by-step safety procedures.

**Prompt**:

```text
Create a simple stick-figure scene of a factory worker pointing a phone at a big
QR code on a machine; on the phone screen, show a plain card with three bullet
lines labelled 'Step 1, Step 2, Step 3'. Black-and-white line art, stick figures,
minimal lines, no shading, plain white background.
```

**Rationale**: Single scenario (scanning QR code), environmental context (factory machine), all 5 lo-fi layers, passes 15-second sketch test.

### Example 2: Healthcare Alert Concept

**Concept**: Vital Sign Pulse — Nurses receive automatic alerts when patient vitals exceed thresholds.

**Prompt**:

```text
Create a simple stick-figure sketch showing a nurse holding a tablet with an upward
arrow and exclamation mark, standing next to a patient in a bed. Minimal lines,
plain white background, black-and-white line art, no shading.
```

**Rationale**: Healthcare environment (patient bed), single interaction (alert notification), simple symbols (arrow, exclamation), no UI mockup detail.

### Example 3: Office Efficiency Concept

**Concept**: Dashboard Glance — Managers view team metrics on a single dashboard page.

**Prompt**:

```text
Create a simple stick-figure sketch showing a person at a desk looking at a screen
with three simple bar charts. Minimal lines, plain white background, black-and-white
line art, no shading.
```

**Rationale**: Office context (desk), single interaction (viewing metrics), basic shapes (bar charts), avoids "detailed interface mockup" trap.
