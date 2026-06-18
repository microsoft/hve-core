---
title: Contributing Hooks
description: How to implement, register, and validate hook artifacts in hve-core
sidebar_position: 7
author: Microsoft
ms.date: 2026-06-17
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

Hooks are collection-scoped, like every other distributable artifact type. Use this structure for hook contributions:

| Path | Purpose |
|---|---|
| `.github/hooks/<collection>/<name>.json` | Hook manifest that maps lifecycle events to executable commands |
| `.github/hooks/<collection>/<name>/` | Hook implementation scripts and support files |
| `collections/*.collection.yml` | Collection registration with `kind: hook` |
| `collections/*.collection.md` | Human-readable hook entry in the collection documentation table |

Manifests live one collection level down (`.github/hooks/<collection>/`) so the installer can activate each collection's hooks independently by adding only that collection's folder to `chat.hookFilesLocations`. A flat `.github/hooks/<name>.json` is treated as a repo-specific artifact and is excluded from distribution.

The telemetry hook is the current reference implementation:

* `.github/hooks/shared/telemetry.json`
* `.github/hooks/shared/telemetry/`

## Implementing a New Hook

1. Add a manifest at `.github/hooks/<collection>/<name>.json`.
2. Add executable scripts under `.github/hooks/<collection>/<name>/`.
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
        "bash": ".github/hooks/shared/my-hook/my-hook.sh",
        "powershell": ".github/hooks/shared/my-hook/Invoke-MyHook.ps1",
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

## Handling Sensitive Payloads

Hook payloads can contain sensitive data. `PreToolUse` inputs include full file
contents being written and shell command strings, and `UserPromptSubmit`
includes the full prompt, any of which may carry secrets. Follow these rules
when a hook persists payloads to disk:

* Store only the minimum needed for the hook's purpose. Prefer derived signals
  (keys, lengths, counts, truncated previews) over verbatim values.
* Gate any verbatim payload capture behind its own explicit opt-in, separate
  from the hook's main enable gate, and default it off.
* Write to local, gitignored locations and never to committed paths.
* Document exactly what is captured, where it is written, and how to remove it.

The telemetry hook applies this pattern: its processed `sessions-*.jsonl` stream
stores only tool-input key names and a truncated prompt preview, while the
verbatim `raw-input.jsonl` dump is a separate opt-in (`HVE_TELEMETRY_RAW=1`,
off by default). See [Local Telemetry](../customization/local-telemetry#sensitive-data-and-privacy).

## Event Compatibility Guidance

Write a single CLI-format block per event: lowercase event keys with `bash` and `powershell` command properties. VS Code automatically converts the lowercase CLI event names to its PascalCase form and maps `bash` to `osx`/`linux` and `powershell` to `windows`, so one block covers both surfaces. Do not also declare a PascalCase copy of the same event; VS Code would register and fire both, duplicating every invocation.

Choose CLI event names that convert to valid VS Code events:

* `sessionStart` -> `SessionStart`
* `preToolUse` -> `PreToolUse`
* `userPromptSubmit` -> `UserPromptSubmit` (not `userPromptSubmitted`)
* `stop` -> `Stop` (VS Code has no `sessionEnd` or `agentStop` event)

## Registering a Hook in Collections

Add a collection item with `kind: hook`:

```yaml
items:
  - path: .github/hooks/<collection>/my-hook.json
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
