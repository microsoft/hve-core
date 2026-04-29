---
description: "Unified canonical deck workflow for opt-in offer, snapshot generation/refresh, and optional customer-card PowerPoint build - Brought to you by microsoft/hve-core"
agent: "DT Coach"
argument-hint: "[project-slug=...] [action=offer|build|run] [method-context=...] [trigger-context=...]"
---

# DT Canonical Deck

Single prompt that handles both canonical deck and customer-card build flows.

## Inputs

- `${input:project-slug}`: Optional DT project slug under `.copilot-tracking/dt/`.
- `${input:action}`: One of `offer`, `build`, or `run`.
  - `offer`: offer canonical snapshot creation or refresh.
  - `build`: build customer-card PPTX from canonical artifacts.
  - `run`: execute offer flow, and if accepted, execute optional build flow.
- `${input:method-context}`: Optional method number.
- `${input:trigger-context:explicit-request}`: Optional offer context (`explicit-request`, `method-exit`, `session-start-check`).

## Workflow Rules

1. Canonical workflow is opt-in. If the team has not opted in, ask first.
2. Decline is valid and non-blocking. Do not gate method transitions.
3. Apply canonical workflow rules from `.github/instructions/design-thinking/dt-canonical-deck.instructions.md` when active.

## Step 1: Resolve Project Slug

If no project slug was provided in inputs:

1. List all projects in `.copilot-tracking/dt/` by reading the `coaching-state.md` files
2. Ask the user to select which project: *"Which DT project? (Found: [list projects]. Choose one or enter a new slug.)"
3. Record the chosen slug and resolve paths using the selected project

Once slug is resolved, establish these paths:

1. Project root: `.copilot-tracking/dt/{project-slug}`
2. Canonical dir: `{project-root}/canonical`
3. Render dir: `{project-root}/render`
4. Customer-card skill root: `.github/skills/experimental/customer-card-render`
5. PowerPoint skill root: `.github/skills/experimental/powerpoint`

## Step 2: Offer Branch (`action=offer` or `action=run`)

If canonical workflow is not active for this session, ask:

> I can keep a canonical deck snapshot as we progress and optionally build customer-card slides from it. Want to enable that workflow?

If declined, stop and continue normal coaching.

When active, offer snapshot creation or refresh at natural checkpoints (especially Method 1, 2, 3, and 5 exits):

> We can snapshot the canonical deck now so your current artifacts stay traceable. Generate or refresh now?

If declined, record the decline and stop.

If accepted:

1. Detect create vs refresh mode from canonical directory state.
2. Generate or refresh canonical entries from DT artifacts.
3. Update snapshot metadata in coaching state.

## Step 2.5: Verify Skill Interfaces (Before Build)

Before executing build commands, verify the actual command parameters by reading the skill documentation:

1. Check `.github/skills/experimental/customer-card-render/README.md` for the exact flags and parameters for `generate_cards.py`
2. Check `.github/skills/experimental/powerpoint/SKILL.md` for the exact parameters for `Invoke-PptxPipeline.ps1` (PowerShell) or `invoke-pptx-pipeline.sh` (bash)
3. Confirm parameter names match the commands shown in Step 3 below. If skill interfaces have changed, update commands accordingly and inform the user of any parameter differences

## Step 3: Build Branch (`action=build` or accepted `action=run`)

Ask before PPTX build unless the user explicitly requested build in this turn:

> Want me to build the customer-card PowerPoint from the canonical deck now?

If accepted:

1. **Determine the active shell runtime** by observing the current terminal type (PowerShell vs bash/Git Bash/WSL)
2. **Execute the appropriate build path** based on the active runtime:

**If PowerShell terminal is active:**

Run the two-command flow using the confirmed parameters from Step 2.5:

1. Generate slide YAML:

```bash
python .github/skills/experimental/customer-card-render/scripts/generate_cards.py \
  --canonical-dir .copilot-tracking/dt/{project-slug}/canonical \
  --output-dir .copilot-tracking/dt/{project-slug}/render/content
```

2. Build PPTX using existing PowerPoint pipeline:

```powershell
./.github/skills/experimental/powerpoint/scripts/Invoke-PptxPipeline.ps1 -Action Build \
  -ContentDir .copilot-tracking/dt/{project-slug}/render/content \
  -StylePath .copilot-tracking/dt/{project-slug}/render/content/global/style.yaml \
  -OutputPath .copilot-tracking/dt/{project-slug}/render/output/customer-cards.pptx
```

**If bash terminal is active (Git Bash, WSL, or similar):**

Use the bash script instead. Verify the bash script flags by sending `invoke-pptx-pipeline.sh --help` first, then run the build command with the confirmed flags.

**Execution Rules:**

- Use `send_to_terminal` to send commands to the active terminal
- Use `get_terminal_output` to poll for completion
- Do not run `pip install` or manual dependency installation
- Rely on PowerPoint skill environment setup (`uv sync`) and documented prerequisites
- Keep output under the project slug render directory

## Step 4: Response Template

Success:

> Canonical workflow updated successfully.
> Canonical: `<project canonical path>`
> PPTX: `<project render/output/customer-cards.pptx>`

Offer declined:

> Skipped for now. We can enable canonical deck workflow any time.

Build failure:

> YAML generation completed, but PPTX build failed due to `<friendly cause>`.
> Next:
> 1. Verify PowerShell and Python prerequisites.
> 2. Re-run the PowerPoint build command from the same render content.
