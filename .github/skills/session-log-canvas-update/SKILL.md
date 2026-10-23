---
name: session-log-canvas-update
description: 'Update the Session Log canvas after a Copilot release changes session events, session storage, system prompt structure, or the canvas SDK. Diffs the installed session-events schema against the canvas baseline, then guides the fixes, fixtures, docs, and baseline refresh. Use after updating Copilot or when the canvas shows unknown events or missing data.'
argument-hint: '[mode=check|update] [schema=<path|version|latest>]'
license: MIT
user-invocable: true
disable-model-invocation: true
---

# Session Log Canvas Update

## Goal

Keep the Session Log canvas accurate when a new Copilot version changes what a session records. Find what changed between the schema the canvas was built against and the current one, then update the canvas so new and changed data renders correctly while sessions recorded by earlier versions stay readable.

This skill belongs to the HVE Core repository. Keep it directly under `.github/skills/session-log-canvas-update/`, outside package directories and plugin or VSIX membership. The canvas it maintains lives at `.github/extensions/hve-core/session-log/`.

## Inputs

* `mode` (optional): `check` reports what changed and the work it implies without editing. `update` (default) also applies the changes and refreshes the baseline.
* `schema` (optional): which schema to compare. Accepts a path to a `session-events.schema.json`, an installed Copilot version, or `latest` (default, the newest installed Copilot CLI package).

## Success Criteria

* Every change to an event type the canvas handles is classified (needs code, already tolerated, or not used by the canvas) with the diff line that supports it.
* New persisted event types either render through a deliberate log kind or are recorded as intentionally generic; none is silently dropped.
* Sessions recorded by both the baseline version and the new version render without regressions: the canvas tests cover the old and new shapes with synthetic fixtures.
* Storage, `workspace.yaml`, system prompt structure, and canvas SDK changes are checked even when the event schema diff is empty.
* The baseline (`assets/event-shapes.json`) describes the schema the updated canvas was verified against, and the style guide revision log names the change.
* No session content appears in fixtures, tests, docs, reports, or responses.

## Flow

1. Find the versions in play. Run `node scripts/event-schema.mjs list` from the skill root (or `node .github/skills/session-log-canvas-update/scripts/event-schema.mjs list` from the repository root) to see installed Copilot CLI schemas. Read the baseline's `source` in [assets/event-shapes.json](assets/event-shapes.json). For a VS Code session, also locate the schema bundled with VS Code at `<VS Code app resources>/app/node_modules.asar.unpacked/@github/copilot-sdk-<platform>/schemas/session-events.schema.json`, because the VS Code harness can run a newer runtime than the installed CLI. The `copilotVersion` a session recorded comes from its `session.start` event; the canvas `get_session_summary` action returns it.
2. Diff the schema. Run `node scripts/event-schema.mjs diff --schema <path|version|latest>` for each relevant schema. The report lists handled types that changed (field by field), new event types with whether they persist, removed types, other changed types, and handled types the schema no longer defines. A field that union alternatives share lists every signature it can take, and a signature cut short by the script's size limits ends in `…`. Use `--json` when you need to process the result.
3. Check real sessions without reading content. Open the canvas on a session from the new version and call its `get_session_summary` action: `eventHealth.unknownTypes` lists persisted types the canvas does not handle, and `unreadableLines` counts lines it could not parse. The Details tab shows the same counts. Compare a few entries of each changed kind in the log against the expected rendering.
4. Read the release notes. The CLI package's `changelog.json` (beside its `schemas/` folder) lists changes per version; scan the versions between the baseline and the new version for session events, compaction, hooks, subagents, system prompt, storage, and extension or canvas changes.
5. Map each change to canvas code with [references/coupling-map.md](references/coupling-map.md), and classify it:
   * Changed field that the indexer reads: read the new location first and fall back to the old one so earlier sessions still render.
   * New persisted type: decide whether it becomes a log entry, enriches an existing entry, updates counts or metadata, or stays generic. Add it to the indexer switch and `HANDLED_EVENT_TYPES` together; a test enforces that they match.
   * Removed type or field: keep reading it while sessions recorded by earlier versions can still contain it.
   * Ephemeral type: ignore unless it becomes persisted.
   In `check` mode, stop here and report.
6. Apply the changes. Add synthetic events for each new or changed shape to the canvas test fixtures (never copy real session text), extend the indexer, server, and UI as needed, and keep the log grammar consistent with the style guide. Update the style guide's Log Grammar table and revision log, and the README when user-visible behavior or actions change.
7. Validate:
   * `npm run test:extensions` and `node --test ".github/skills/session-log-canvas-update/tests/*.test.mjs"`. PR validation runs both suites in its Node test lane.
   * `node --check` on changed modules, and `npm run plugin:validate`.
   * Markdown lint, spelling, table format, and frontmatter checks on changed Markdown.
   * A browser check on synthetic fixtures only: confirm the page URL before each screenshot, and never capture the live canvas because it shows real session content.
   * A host reload (`extensions_reload`, then reopen the canvas) with the served `ui/` files matching disk.
8. Refresh the baseline. Run `node scripts/event-schema.mjs snapshot --schema <the schema you verified against> --write`, rerun `diff` against it to confirm a clean report, and commit the baseline with the canvas changes. Both commands exit non-zero without writing anything when the file defines no session event types.

## Constraints

* Read session logs only through the canvas or for event type names, field names, counts, and sizes. Do not print, paste, or persist message, prompt, tool, or summary text from real sessions.
* The script reads schema files, their `package.json`, and the baseline, and imports the canvas indexer, or the module passed with `--indexer`, to read its exported type lists. That module runs in the script's process, so pass `--indexer` only a module you trust. The script writes only to stdout or, with `snapshot --write`, to `assets/event-shapes.json`. [SECURITY.md](SECURITY.md) records its threat model.
* The baseline keeps event and field identifiers and type signatures only, never schema descriptions.
* Prefer a schema from a package whose license permits redistribution of derived identifiers for the committed baseline, such as the MIT-licensed `@github/copilot-sdk-<platform>` package bundled with VS Code.
* Keep changes inside the canvas, its tests and docs, and this skill. Do not commit, push, or publish without the user's request.

## Stop Rules

* Stop and ask for a schema path when no installed schema is found and none was given.
* Stop in `check` mode after the classified report.
* Stop as Blocked when a change cannot be mapped to canvas behavior from the diff, release notes, and synthetic reproduction; report the type and fields and what evidence would settle it.
* Stop as Revise when validation fails; report the failing check and do not refresh the baseline.

## Final Response Contract

Report the versions compared, a classified table of changes (type or surface, change, canvas impact, action taken or proposed), files changed, validation results with exact commands, whether the baseline was refreshed and from which schema, and any blocked items with the evidence needed.
