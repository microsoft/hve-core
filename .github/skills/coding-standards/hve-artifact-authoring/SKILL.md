---
name: hve-artifact-authoring
description: >
  Create, validate, and package AI artifacts for HVE Core — GitHub Copilot's prompt engineering
  framework. Covers agents, prompts, instructions, skills, and collections with frontmatter
  contracts, naming conventions, collection packaging, subagent delegation, workspace state
  tracking, and CI validation pipelines. Use when building any markdown-based AI artifact that
  follows the four-tier delegation model (Prompts → Agents → Instructions → Skills) with
  schema-validated frontmatter and collection-based distribution.
version: 1.0.0
---

# HVE Artifact Authoring

## Purpose

Teach the patterns, contracts, and workflows for authoring AI artifacts in the HVE Core
framework — a markdown-based prompt engineering library for GitHub Copilot. Every artifact
type (agent, prompt, instruction, skill, collection) follows strict frontmatter schemas,
naming conventions, and packaging rules that enable automated validation and distribution.

## Core Principles

### 1. Four-Tier Artifact Delegation

Artifacts compose in a strict hierarchy. Each tier has a distinct responsibility:

| Tier | Artifact | Role | Key Property |
|------|----------|------|-------------|
| 1 | **Prompt** (`.prompt.md`) | Captures user intent, routes to agent | `agent:` field delegates |
| 2 | **Agent** (`.agent.md`) | Orchestrates multi-step workflow | `agents:` list, `handoffs:` array |
| 3 | **Instruction** (`.instructions.md`) | Applies coding/style standards passively | `applyTo:` glob auto-matches |
| 4 | **Skill** (`SKILL.md`) | Executes specialized utilities with scripts | Self-contained package |

**Design rule:** Prompts never contain logic — they capture input and delegate. Agents
orchestrate but reference instructions for standards. Instructions are passive guidance.
Skills are active execution with cross-platform scripts.

### 2. Frontmatter Is the Contract

Every artifact's behavior, discoverability, and validation is driven by YAML frontmatter.
VS Code discovers artifacts by frontmatter metadata, not file location alone.

- Frontmatter MUST be the first content in every markdown file
- Required fields vary by artifact type (see procedures below)
- JSON schemas enforce contracts at CI time
- Schema mapping (`schema-mapping.json`) routes file patterns to schemas

### 3. Collection-Based Packaging

Artifacts are never distributed individually. Collections bundle related artifacts with
maturity filtering:

| Channel | Includes | Use |
|---------|----------|-----|
| Stable | `stable` only | Production default |
| Preview | `stable` + `preview` | Early access |
| Experimental | `stable` + `preview` + `experimental` | Full access |

### 4. Subagent Delegation Without Recursion

Only top-level orchestrator agents invoke subagents. Subagents (leaf agents) never
invoke other subagents — they use tools (search, read, terminal) and return findings
to their caller. This prevents unbounded delegation chains.

### 5. Workspace State Tracking

Complex workflows persist state in `.copilot-tracking/` with date-organized subdirectories.
This enables session persistence across agent handoffs and provides human-inspectable
audit trails.

---

## Procedures

### Procedure 1: Create an Agent

1. **Choose location:** `.github/agents/{collection-id}/{name}.agent.md`
   - For subagents: `.github/agents/{collection-id}/subagents/{name}.agent.md`

2. **Write frontmatter** with required and relevant optional fields:
   ```yaml
   ---
   name: My Agent Name
   description: 'One-line purpose statement — Brought to you by microsoft/hve-core'
   argument-hint: 'How users should invoke this agent'
   agents:
     - Subagent Name One
     - Subagent Name Two
   tools:
     - codebase
     - search
   handoffs:
     - label: "📋 Next Action"
       agent: Target Agent
       prompt: /command-name
       send: true
   ---
   ```

3. **Write agent body** with these sections (in order):
   - `# Agent Name` — H1 title matching frontmatter `name:`
   - `## Autonomous Behavior` — decision-making guidelines
   - `## Subagent Invocation Protocol` — when/how to delegate (if orchestrator)
   - `## Tracking Artifacts` — state management rules (if stateful)
   - `## Required Phases` — numbered phase definitions
   - `## Success Criteria` — completion conditions

4. **Key frontmatter decisions:**
   - Set `disable-model-invocation: true` for orchestrator agents (prevents auto-invocation)
   - Set `user-invocable: false` for subagents (hidden from user picker)
   - Use `agents: ["*"]` only when agent needs unrestricted subagent access
   - Use specific `agents:` list to constrain allowed subagents

5. **Register in collection:** Add path + kind to `collections/{id}.collection.yml`

### Procedure 2: Create a Prompt

1. **Choose location:** `.github/prompts/{collection-id}/{name}.prompt.md`

2. **Write frontmatter:**
   ```yaml
   ---
   description: 'Workflow description in 1-200 characters'
   agent: Target Agent Name
   argument-hint: 'arg=... [option={a|b}]'
   ---
   ```

3. **Write prompt body** with these sections:
   - `## Inputs` — list template variables as `${input:varname}`
   - `## Requirements` — numbered conditional routing rules
   - `## Steps` or `## Conversation Summarization` — execution or state rules

4. **Design rules:**
   - Prompts capture intent, they never contain implementation logic
   - Use `agent:` field to delegate to the right orchestrator
   - Template variables use `${input:name}` syntax
   - Keep description under 200 characters

5. **Register in collection**

### Procedure 3: Create an Instruction

1. **Choose location:** `.github/instructions/{collection-id}/{name}.instructions.md`
   - Root-level instructions (no subdirectory) are repo-scoped and never distributed

2. **Write frontmatter:**
   ```yaml
   ---
   description: 'Target file type and standards scope'
   applyTo: '**/*.{ext}'
   ---
   ```

3. **Write instruction body** with these sections:
   - `## Scope` — what files this applies to, what standard it enforces
   - `## [Topic]` sections — one per concern with practical guidance
   - Include XML-delimited example blocks for tool extraction:
     ```
     <!-- <example-topic> -->
     ```code
     [example]
     ```
     <!-- </example-topic> -->
     ```

4. **Design rules:**
   - `applyTo` glob patterns auto-match files — instructions are applied passively
   - One instruction per concern (don't mix Python + TypeScript)
   - Reference `.github/copilot-instructions.md` for repo-wide conventions
   - Keep focused and actionable — these are standards, not tutorials

5. **Register in collection**

### Procedure 4: Create a Skill

1. **Create directory:** `.github/skills/{collection-id}/{skill-name}/`

2. **Required structure:**
   ```
   {skill-name}/
   ├── SKILL.md          # Required
   ├── scripts/          # Optional
   │   ├── action.ps1    # PowerShell required if scripts/ exists
   │   └── action.sh     # Bash recommended
   ├── references/       # Optional
   ├── assets/           # Optional
   ├── examples/         # Optional
   └── tests/            # Optional (excluded from distribution)
       └── action.Tests.ps1
   ```

3. **Write SKILL.md frontmatter:**
   ```yaml
   ---
   name: skill-name
   description: 'Brief description, 1-1024 characters'
   user-invocable: true
   argument-hint: '[input=...] [quality=high|medium|low]'
   ---
   ```

4. **Write SKILL.md body** with sections: What is This Skill?, Use Cases,
   Requirements, Installation, Usage, Examples, Troubleshooting

5. **Implement scripts** — PowerShell (.ps1) is required for cross-platform;
   Bash (.sh) recommended as companion

6. **Register in collection**

### Procedure 5: Create a Collection

1. **Create YAML manifest:** `collections/{id}.collection.yml`
   ```yaml
   id: my-collection
   name: Human-Readable Name
   description: Purpose and scope
   tags:
     - tag1
     - tag2
   items:
     - path: .github/agents/my-collection/agent.agent.md
       kind: agent
       maturity: stable
     - path: .github/prompts/my-collection/prompt.prompt.md
       kind: prompt
   ```

2. **Create companion markdown:** `collections/{id}.collection.md`

3. **Organize artifacts** in `{collection-id}` subdirectories under
   `.github/agents/`, `.github/prompts/`, `.github/instructions/`, `.github/skills/`

4. **Collection YAML rules:**
   - `id`: lowercase with hyphens only (pattern: `^[a-z0-9-]+$`)
   - `items`: minimum 1 item, each with `path` and `kind`
   - `kind` values: `agent`, `prompt`, `instruction`, `skill`, `hook`
   - Item-level `maturity` overrides collection-level maturity
   - `maturity: removed` excludes from all channels

### Procedure 6: Design an Orchestrator Agent with Subagent Delegation

1. **Identify the orchestration need:** Multi-phase workflow requiring research,
   planning, implementation, or review steps

2. **Create orchestrator agent** with:
   - `agents:` listing specific allowed subagents
   - `handoffs:` array with labeled UI buttons for common next actions
   - `disable-model-invocation: true` (user explicitly invokes orchestrators)

3. **Create leaf subagents** at `subagents/{name}.agent.md` with:
   - `user-invocable: false` (hidden from user picker)
   - No `agents:` field (leaf agents never invoke subagents)
   - Focused scope — one responsibility per subagent

4. **Delegation rules:**
   - Orchestrators classify task difficulty before delegating
   - Simple tasks: handle directly, no subagents
   - Complex tasks: delegate to specialized subagents
   - Each subagent returns findings; orchestrator synthesizes

5. **State handoff** via `.copilot-tracking/`:
   ```
   .copilot-tracking/
   ├── research/{YYYY-MM-DD}/     # Investigation findings
   ├── plans/{YYYY-MM-DD}/        # Implementation plans
   ├── details/{YYYY-MM-DD}/      # Phase-by-phase details
   ├── changes/{YYYY-MM-DD}/      # Executed changes
   ├── review/{YYYY-MM-DD}/       # Review findings
   └── pr/{YYYY-MM-DD}/           # PR descriptions
   ```

### Procedure 7: Validate Artifacts

1. **Run full validation:**
   ```bash
   npm run lint:all
   ```

2. **Individual checks:**
   | Command | What it validates |
   |---------|------------------|
   | `npm run lint:frontmatter` | Frontmatter against JSON schemas |
   | `npm run lint:md` | Markdown style (markdownlint) |
   | `npm run lint:yaml` | YAML syntax |
   | `npm run lint:ps` | PowerShell static analysis |
   | `npm run validate:skills` | Skill directory structure |
   | `npm run lint:collections-metadata` | Collection manifests |
   | `npm run test:ps` | PowerShell Pester tests |

3. **Schema validation details:**
   - Schemas live in `scripts/linting/schemas/`
   - `schema-mapping.json` maps glob patterns to schema files
   - Most specific pattern match wins when multiple patterns apply

---

## Markdown Standards

All artifact files must follow these markdown rules (enforced by markdownlint):

- ATX-style headings only (`#`, `##`, `###`)
- Single H1 per file (unless frontmatter has `title:` field — then start at H2)
- Increase heading levels by one (no skipping)
- Blank lines above and below headings
- No trailing punctuation on headings
- Frontmatter MUST be at file start, before all content
- UTF-8 encoding, plain ASCII punctuation

---

## Reference Links

- Frontmatter schemas: [references/frontmatter-schemas.md](references/frontmatter-schemas.md)
- Collection manifest schema: [references/collection-schema.md](references/collection-schema.md)
- Agent template: [assets/agent-template.md](assets/agent-template.md)
- Prompt template: [assets/prompt-template.md](assets/prompt-template.md)
- Instruction template: [assets/instruction-template.md](assets/instruction-template.md)
- Skill template: [assets/skill-template.md](assets/skill-template.md)
- Collection template: [assets/collection-template.yml](assets/collection-template.yml)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
