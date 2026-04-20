---
description: "Offer or execute customer-card PowerPoint generation from the canonical deck, track per-snapshot cooldown in coaching state, run build-cards.ps1 with project-scoped paths, and report success or failure with clear diagnostics - Brought to you by microsoft/hve-core"
agent: "DT Coach"
argument-hint: "[project-slug=...] [canonical-dir=...] [render-dir=...] [trigger-context=...]"
---

# Build Customer Cards PPTX

Confirm with the user before building PowerPoint output from canonical deck artifacts.

## Inputs

* ${input:project-slug}: (Optional) DT project slug under `.copilot-tracking/dt/`.
* ${input:canonical-dir}: (Optional) Absolute or relative canonical directory path.
* ${input:render-dir}: (Optional) Absolute or relative render directory path.
* ${input:trigger-context:explicit-request}: (Optional) One of `explicit-request`, `post-deck-refresh`, or `session-start-check`.

## Required Steps

### Step 1: Resolve Paths and Snapshot Context

Resolve paths in this order:

1. If `render-dir` is provided, use it.
2. Else if `project-slug` is provided, use `.copilot-tracking/dt/{project-slug}/render`.
3. Else infer by scanning `.copilot-tracking/dt/**/canonical` and use the sibling `render` directory for the best match.

Resolve `canonical-dir`:

1. If `canonical-dir` is provided, use it.
2. Else use `{render-dir}/../canonical`.

Script path:

1. `.github/skills/experimental/powerpoint/customer-card-render/scripts/build-cards.ps1`
2. `.github/skills/experimental/powerpoint/scripts/invoke-pptx-pipeline.sh`

If required scripts are missing, respond with a friendly error and include expected locations.

If `project-slug` is provided, read `.copilot-tracking/dt/{project-slug}/coaching-state.md` and determine the latest generated canonical snapshot key using the most recent generated entry in `canonical_deck.snapshots`. Use the format `{snapshot-name}:{timestamp}`.

If no generated canonical snapshot exists and the canonical directory is missing or empty, respond with a friendly error explaining that the canonical deck must exist before the PowerPoint can be built.

### Step 2: Decide Whether to Offer

If `trigger-context` is `explicit-request`, skip cooldown checks and continue to Step 3.

Otherwise, stop without offering if any of the following are true:

1. `customer_card_render.session_declined` is `true`.
2. `customer_card_render.last_offered_snapshot_key` matches the latest generated canonical snapshot key.
3. `customer_card_render.last_generated_snapshot_key` matches the latest generated canonical snapshot key.

Select the confirmation question based on `trigger-context`:

* `post-deck-refresh`: `Canonical deck is updated. Want me to generate the customer-card PowerPoint from it now?`
* `session-start-check`: `The canonical deck moved since the last PowerPoint build. Want me to generate a fresh visual from it now?`
* `explicit-request`: `I can generate the customer-card PowerPoint from the canonical deck now. Do you want me to run the build?`

### Step 3: Ask For Confirmation

Ask a direct confirmation question before execution:

Use the question selected in Step 2.

Proceed only on confirmation.

Map the response:

* Accept (`yes`, `sure`, `go for it`, `do it`) → continue to Step 4.
* Decline (`no`, `not now`, `later`, `skip it`) → update `customer_card_render.last_offered_snapshot_key` to the latest generated canonical snapshot key and stop.
* Session opt-out (`stop asking`, `never mind`) → update `customer_card_render.last_offered_snapshot_key`, set `customer_card_render.session_declined: true`, and stop.

### Step 4: Execute Build

**Dependency management rule (non-negotiable)**: Never run `pip install`, `pip3 install`, or any manual dependency installation command. The PowerPoint skill manages its own dependencies via `uv sync` and `pyproject.toml`.

**Environment setup is silent.** Do not ask users to confirm dependency checks, uv installation, venv creation, or `uv sync`. Run all prerequisite steps automatically and only surface errors if they fail. The user should see at most one terminal command sequence that produces the PPTX.

Define `<skill-root>` as `.github/skills/experimental/powerpoint`.
Define `<card-scripts>` as `<skill-root>/customer-card-render/scripts`.

#### 4a. Ensure uv is available

Locate `uv` silently using this resolution order:

1. `uv` on PATH.
2. `~/.local/bin/uv` (macOS/Linux) or `~/.local/bin/uv.exe` (Windows).
3. `~/.cargo/bin/uv` (macOS/Linux) or `~/.cargo/bin/uv.exe` (Windows).

If not found at any location, install it automatically:

* Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
* macOS/Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`

After installation, resolve the installed path (typically `~/.local/bin/uv` or `~/.local/bin/uv.exe`). Use the resolved absolute path for all subsequent `uv` commands if it is not on PATH.

#### 4b. Sync Python environment

Run `uv sync` once to ensure the virtual environment exists with all required dependencies:

`<uv-path> sync --directory <skill-root>`

This creates `<skill-root>/.venv/` and installs packages from `<skill-root>/pyproject.toml`. If the venv already exists and dependencies are current, this completes in under a second.

#### 4c. Resolve venv Python path

The venv Python interpreter location varies by OS:

* Windows: `<skill-root>/.venv/Scripts/python.exe`
* macOS/Linux: `<skill-root>/.venv/bin/python`

Store this as `<venv-python>` for the build step.

#### 4d. Generate card content YAML

Run `generate_cards.py` using any available Python (it uses only stdlib modules):

`python <card-scripts>/generate_cards.py --canonical-dir <resolved-canonical-dir> --output-dir <render-dir>/content`

#### 4e. Build PPTX deck

Run `build_deck.py` using the venv Python:

`<venv-python> <skill-root>/scripts/build_deck.py --content-dir <render-dir>/content --style <render-dir>/content/global/style.yaml --output <render-dir>/output/customer-cards.pptx`

#### Execution strategy

Combine steps 4a through 4e into the minimum number of terminal commands. Prefer chaining prerequisite steps (uv install, uv sync) with the build steps in a single terminal interaction when possible. Do not ask users to approve each step individually.

If `uv sync` or `build_deck.py` fails, report the error clearly. Do not fall through to shell wrapper scripts unless the direct Python path encounters a fundamental issue unrelated to dependencies (for example, Python not installed at all).

All path arguments must resolve under `.copilot-tracking/dt/{project-slug}/` when `project-slug` is provided.

Render fidelity requirements:

* Vision slides must render both the canonical vision summary and the `### Why This Matters` section.
* Scenario slides must render `### Description`, `### Scenario Narrative`, and `### How Might We` as explicit sections.

### Step 5: Update State and Report Outcome

On success, update `customer_card_render` in the coaching state:

* `enabled: true`
* `session_declined: false`
* `last_offered_snapshot_key`: latest generated canonical snapshot key
* `last_generated_snapshot_key`: latest generated canonical snapshot key
* `last_generated`: current ISO 8601 date
* `last_output_path`: relative project path to `render/output/customer-cards.pptx`

On failure, leave `last_generated_snapshot_key` unchanged.

On success:

* Confirm build succeeded.
* Provide the PPTX location explicitly.

On partial success (for example, YAML generated but direct PPTX build failed):

* Confirm what completed successfully.
* Provide the generated content directory explicitly.
* Explain which build step failed and why.
* Include a specific retry path using the runtime matrix above.

On failure:

* Clearly state build failed.
* Provide a user-friendly summary of the most likely failure cause from stderr/stdout.
* Include a short "Try next" checklist (for example: missing canonical dir, missing PowerShell, missing Python/uv, invalid YAML).

## Response Format

Use one of these concise templates.

Success:

> Build completed successfully.
> PPTX: `<absolute-path-to-customer-cards.pptx>`

Partial success:

> YAML generation completed successfully.
> Content: `<absolute-path-to-render-content>`
> I couldn't build the PPTX because `<friendly-cause>`.
> Next: `<specific retry step>`

Failure:

> I couldn't generate the PowerPoint because `<friendly-cause>`.
> Suggested next steps:
> 1. `<step>`
> 2. `<step>`
