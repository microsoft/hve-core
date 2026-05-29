---
description: 'Frontmatter field reference for agents, prompts, instructions, skills, and collection manifests'
---

# Frontmatter Schema Reference

## Agent Frontmatter (`agent-frontmatter.schema.json`)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `description` | string (minLength 1) | **Yes** | Shown as placeholder in chat input |
| `name` | string | No | Defaults to filename |
| `argument-hint` | string | No | Guidance text in chat input |
| `agents` | array of strings OR `"*"` | No | Allowed subagents; `"*"` = all |
| `tools` | array of strings | No | Available tools (builtin, MCP, extensions) |
| `model` | string OR array of strings | No | Model override |
| `target` | `"vscode"` or `"github-copilot"` | No | Execution target |
| `handoffs` | array of handoff objects | No | Agent delegation buttons |
| `user-invocable` | boolean | No | Default: true |
| `disable-model-invocation` | boolean | No | Default: false |
| `mcp-servers` | array of MCP server configs | No | MCP server declarations |

### Handoff Object

```yaml
handoffs:
  - label: "Button Label"        # Required: UI button text
    agent: Target Agent Name     # Required: agent to hand off to
    prompt: "/command args"      # Optional: prompt to send
    send: true                   # Optional: auto-send (default: false)
```

## Prompt Frontmatter (`prompt-frontmatter.schema.json`)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `description` | string (1-200 chars) | **Yes** | Workflow description |
| `name` | string | No | Used after "/" in chat |
| `agent` | string | No | Named custom agent to delegate to |
| `argument-hint` | string | No | Argument guidance |
| `model` | string | No | Model override |
| `tools` | array of strings | No | Available tools |

## Instruction Frontmatter (`instruction-frontmatter.schema.json`)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `description` | string (minLength 1) | **Yes** | Target and scope |
| `name` | string | No | Defaults to filename |
| `applyTo` | string (glob pattern) | No | Auto-application file matching |

## Skill Frontmatter (`skill-frontmatter.schema.json`)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string (kebab-case) | **Yes** | Lowercase with hyphens |
| `description` | string (1-1024 chars) | **Yes** | Brief description |
| `user-invocable` | boolean | No | Default: true |
| `disable-model-invocation` | boolean | No | Default: false |
| `argument-hint` | string | No | Argument hints |
| `license` | string | No | SPDX license identifier |
| `compatibility` | string | No | Runtime requirements |
| `metadata` | object | No | Authors, spec_version, etc. |

## Collection Manifest (`collection-manifest.schema.json`)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string (pattern `^[a-z0-9-]+$`) | **Yes** | Unique ID |
| `name` | string (minLength 1) | **Yes** | Display name |
| `description` | string (minLength 1) | **Yes** | Brief description |
| `items` | array (minItems 1) | **Yes** | Artifact references |
| `maturity` | enum | No | stable, preview, experimental, deprecated, removed |
| `tags` | array of strings | No | Discovery tags |
| `display.ordering` | `"alpha"` or `"manual"` | No | Default: alpha |

### Item Object

```yaml
items:
  - path: .github/agents/collection-id/name.agent.md   # Required
    kind: agent                                          # Required: agent|prompt|instruction|skill|hook
    usage: "Usage guidance text"                         # Optional
    maturity: stable                                     # Optional: overrides collection maturity
```

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
