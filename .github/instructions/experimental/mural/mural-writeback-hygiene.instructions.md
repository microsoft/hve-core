---
description: 'Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.'
applyTo: '**/.copilot-tracking/mural/**, **/.github/skills/experimental/mural/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md'
---

## Mural Writeback Hygiene

Writeback is the act of attaching structure to widgets after the workshop. The Mural API exposes only three stable channels for that structure. This file defines the rules for using them and the invariants that protect the human-authored content beneath.

## Allowed writeback channels

| Channel     | Purpose                                                 | API field   |
|-------------|---------------------------------------------------------|-------------|
| `tags[]`    | Classification (intent, destination, lineage, status)   | `tags`      |
| `hyperlink` | External reference (work item URL, ADR path, doc link)  | `hyperlink` |
| `parentId`  | Spatial / semantic placement under an area or container | `parentId`  |

Writeback *must* limit itself to these three fields. Composite tools that scaffold AI-authored widgets may set `text` *at create time*, but writeback against an existing widget never sets `text`.

## Forbidden writes

* `text` on any widget the writeback step did not just create in the same call.
* Removing the reserved `authored-by-ai` tag without `--force-reserved`.
* Updating or deleting any widget that does not carry the reserved `authored-by-ai` tag unless `--require-author-tag` is satisfied or `--force-human` is set; the skill raises `MuralHumanAuthoredProtected` (exit 77) otherwise.

## Tag merge semantics

* Tag mutations route through `_merge_tags` (read-modify-write with up to 3 attempts and jittered 50–200ms backoff). Never PATCH the full `tags[]` array directly.
* On verification failure after retries, `_merge_tags` raises `MuralTagMergeConflict` (exit 75) with `{intended, observed, missing, extra, attempts}`. Surface that envelope to the user; do not retry blindly.
* Tag IDs are workspace-scoped. Look up or create tags via `mural tag list` and `mural tag create`; do not hardcode IDs across workspaces.

## Reserved tag invariant

The skill reserves a fixed set of tag prefixes for machine semantics:

* `authored-by-ai`: set on every widget AI authors.
* `dt:method=<n>`, `dt:section=<name>`: DT lineage on composite outputs.
* `destination:<adapter-id>`: set during retro / extractor writeback (see [mural-destinations.instructions.md](mural-destinations.instructions.md)).
* `intent:<create|mutate|append|no-op>`: set during retro / extractor writeback.

Reserved tags are recognized by `_is_reserved_tag_id`. Removal requires `--force-reserved`. Manual creation of tags using these prefixes for non-skill purposes is forbidden.

## Defensive tag manifest re-application

Every writeback that closes a workshop must re-apply the tag manifest before exiting:

1. Resolve the manifest from `_read_tag_manifest` (per-mural manifest of expected tags).
2. Call `_ensure_tag_manifest` to verify tags are present and apply missing ones via `_merge_tags`.
3. If `_ensure_tag_manifest` returns `tag_cap_reached`, surface the warning and stop further tag mutations on the affected widgets.
4. Use `mural repair-tag-drift` to reconcile a widget whose tag set has drifted from the manifest. The repair is additive only (does not strip tags the user added in the workshop).

## Mode-aware writeback

* `extractor` writeback runs after the workshop is closed. It enriches widgets without their authors present, so it must be conservative: tag, link, parent — never text.
* `facilitator` writeback may run during the workshop. It still touches only the three writeback channels on widgets it did not just create. AI-authored stickies from the same session are mutable by the same authoring agent within that session.

## Sandbox versus production

* Treat any mural id outside the configured production workspace as sandbox.
* Sandbox writebacks may set arbitrary tags and hyperlinks; they still respect reserved-tag protection.
* Production writebacks additionally require the destination registry (see [mural-destinations.instructions.md](mural-destinations.instructions.md)) to declare the tag they will apply.

## Failure handling

* Bulk operations report a `{succeeded, failed, warnings}` envelope. Treat any non-empty `failed` array as a writeback to retry or escalate; never silently drop entries.
* `--atomic` on `mural widget update-bulk` aborts on first failure with `MuralBulkAtomicAbort` (exit 75). Use it only when downstream consumers cannot tolerate partial state.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
