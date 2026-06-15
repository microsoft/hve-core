---
title: Contributing Hooks
description: How to implement, register, and validate hook artifacts in hve-core
sidebar_position: 7
author: Microsoft
ms.date: 2026-06-08
ms.topic: how-to
keywords:
  - hooks
  - contributing
  - telemetry
  - sidecar automation
estimated_reading_time: 6
---

## Why Hooks Exist

Hooks let you run lightweight automation during Copilot lifecycle events without modifying agents, prompts, or skills. In hve-core, hooks are packaged as collection artifacts and can be distributed with other AI customization files.

Use a hook when you need event-driven behavior such as:

* collecting local diagnostics or telemetry
* enforcing lightweight local policy checks
* triggering sidecar automation before or after tool calls

## Hook Layout in This Repository

Use this structure for hook contributions:

| Path | Purpose |
|---|---|
| `.github/hooks/<name>.json` | Hook manifest that maps lifecycle events to executable commands |
| `.github/hooks/<name>/` | Hook implementation scripts and support files |
| `collections/*.collection.yml` | Collection registration with `kind: hook` |
| `collections/*.collection.md` | Human-readable hook entry in the collection documentation table |

The telemetry hook is the current reference implementation:

* `.github/hooks/telemetry.json`
* `.github/hooks/telemetry/`

## Implementing a New Hook

1. Add a manifest at `.github/hooks/<name>.json`.
2. Add executable scripts under `.github/hooks/<name>/`.
3. Register the hook in one or more `collections/*.collection.yml` files.
4. Document the hook in the matching `collections/*.collection.md` files.
5. Add or update docs under `docs/` for setup and usage.

Minimal manifest pattern:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": ".github/hooks/my-hook/my-hook.sh",
        "powershell": ".github/hooks/my-hook/Invoke-MyHook.ps1",
        "timeoutSec": 10
      }
    ]
  }
}
```

## Script Contract and Runtime Behavior

For reliability and portability, hook scripts should follow these rules:

* Read event payload JSON from stdin.
* Return quickly on the disabled path.
* Write `{"continue":true}` to stdout on normal completion.
* Avoid interactive prompts.
* Keep runtime short and respect `timeoutSec` values in the manifest.
* Support both bash and PowerShell paths when practical.

Telemetry follows this model with a no-op gate and structured JSONL append behavior.

## Event Compatibility Guidance

The telemetry manifest includes both lowercase and PascalCase event names to support multiple invocation surfaces. If you need broad compatibility across environments, mirror that pattern in your hook manifest.

Examples from telemetry:

* `sessionStart` and `SessionStart`
* `preToolUse` and `PreToolUse`
* `agentStop` and `Stop`

## Registering a Hook in Collections

Add a collection item with `kind: hook`:

```yaml
items:
  - path: .github/hooks/my-hook.json
    kind: hook
```

Then update the corresponding collection markdown (`collections/*.collection.md`) in the Hooks section so users can discover what the hook does.

## Validation Checklist

Before opening a PR:

1. Run `npm run plugin:validate`
2. Run `npm run plugin:generate`
3. Run `npm run lint:md`

When your hook includes scripts, also run the relevant script linters and tests for those languages.

## Related Guides

* [Custom Agents](custom-agents)
* [Instructions](instructions)
* [Common Standards](ai-artifacts-common)
* [Local Telemetry](../customization/local-telemetry)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
