<!-- markdownlint-disable MD013 -->
# Prompt workbench (promptlab) design

## Purpose

The Prompt Builder agent (#55) hardens a prompt through an iterative loop run by three subagents: the Prompt Updater (#62) writes and revises the prompt, the Prompt Tester (#60) executes it literally in a sandbox on scenarios (following the prompt at face value, without interpreting beyond it), and the Prompt Evaluator (#61) scores the results against the Prompt Quality Criteria. Today the cockpit serves this cluster only generically: the Tester and Updater fall to context badges and the Evaluator to the review findings panel, so the most important thing, what the prompt actually DID when followed literally, has no home.

This design adds a dedicated `promptlab` loop view whose centerpiece is a behavior test bench: a table of scenarios, each with the literal output the Tester produced and a pass/warn/fail verdict from the Evaluator. The prompt text and an overall pass-rate summary ride along as secondary context. The user picked behavior (the test bench) as the heart of the surface; the prompt and scores are deliberately secondary.

## A new `promptlab` domain

`promptlab` becomes a new loop-view domain, peer to `rpi`, `review`, `interview`, `backlog`, `team`, `codemap`, `dataprofile`, and `gallery`. Opening it switches the cockpit to the workbench, exactly as `review.start` / `backlog.start` switch to their views.

## State

Four new `SessionState` fields:

* `promptName: string | null` (the prompt being built; null when no workbench is active).
* `promptRound: number` (the current iteration round, default 1; a light "Round N" indicator, not a full history).
* `promptArtifact: string | null` (the prompt text, shown in a secondary panel; null when not provided).
* `promptCases: PromptCase[]`, where `PromptCase = { id: string; scenario: string; output?: string; verdict: PromptVerdict; note?: string }` and `PromptVerdict = "pending" | "running" | "pass" | "warn" | "fail"`.

A case is added scenario-first (verdict `pending`) when the Tester picks it, then the same id is updated in place with the `output` and a `verdict` (and optional `note`) once the Tester runs it and the Evaluator judges it. This upsert-by-id rule matches `item.add` / `column.add`.

## Beats and tools

Two new beats and two new MCP tools, following the `dataset_profile` / `add_column` shape. The MCP tool count goes from 36 to 38.

| Tool | Beat | Effect |
| --- | --- | --- |
| `promptlab_start(name, prompt?, round?)` | `promptlab.start` | Switch the view to `promptlab`, set `promptName`, `promptArtifact` (from `prompt`), and `promptRound` (default 1), and clear `promptCases` (a fresh run). Re-calling with `round + 1` starts the next pass. |
| `add_case(id, scenario, output?, verdict?, note?)` | `case.add` | Append a `PromptCase`, or update the existing one with the same `id` in place (preserves order on update; appends a new id). `verdict` defaults to `"pending"` when omitted. |

`add_case`'s `verdict` is constrained to the `PromptVerdict` enum at the tool boundary (a zod enum), so an unknown value is rejected rather than rendered. The tool descriptions disambiguate "case" as a prompt test scenario (distinct from a kanban item or a dataset column).

## View-model

`toViewModel` projects:

```text
promptlab: {
  name: string | null;
  round: number;
  prompt: string | null;
  summary: { pass: number; warn: number; fail: number; pending: number; running: number; total: number };
  cases: { id: string; scenario: string; output: string | null; verdict: string; note: string | null }[];
}
```

`summary` is derived purely by counting case verdicts (the "score"); `cases` is a pass-through of `promptCases` with `output`/`note` null-coalesced. The projection stays pure.

## The view

A new `#promptlab-view`, a sibling of the other loop views, shown when `v.domain === "promptlab"` and hidden otherwise (the same mutually-exclusive routing the other domains use). It fills `#loop` and renders:

* A header line: `{name}` with a muted `Round {round}` suffix and a derived summary strip of count chips (pass / warn / fail, plus running/pending when nonzero), each colored to its verdict.
* The centerpiece, a case table: one row per `PromptCase` with the scenario, a truncated one-line output preview, and a verdict pill (pass green / warn amber / fail red / running a pulsing blue / pending muted grey). Clicking a row expands it inline to show the full literal output (preformatted) and the evaluator's note. An empty bench (no cases yet) shows the header and an empty-state row.
* A secondary panel showing the prompt text (`promptArtifact`) when present, preformatted; on a wide viewport it sits beside the table, on a narrow one it stacks below.

Every interpolated field goes through the existing `esc()` helper. The expand/collapse is local view state (a delegated click on the row toggling an `open` class), consistent with how the other client interactions are wired.

## Agent contract

`agents/cockpit-instructions.md` gains a prompt-engineering section: the Prompt Builder calls `promptlab_start(name, prompt?)` when it begins hardening a prompt; the Tester calls `add_case(id, scenario)` as it picks each scenario and updates the same id with `output` + `verdict` (`pass`/`warn`/`fail`) once it runs and the Evaluator judges; the Builder re-calls `promptlab_start` with `round + 1` for a fresh pass. A mapping note records that the Prompt Evaluator may still narrate severity findings via `review_start` + `add_finding` when its output is prompt-wide rather than per-case.

## Testing

* state: `promptlab.start` sets name/round/prompt and clears cases; a missing `round` defaults to 1; `case.add` appends, and a second `case.add` with the same id updates in place (order preserved); `verdict` defaults to `pending`.
* view-model: `toViewModel` exposes `promptlab.name`/`round`/`prompt`, the derived `summary` counts, and the `cases` array with every field; null name and empty cases when no workbench started.
* tools: a round trip drives `promptlab_start` + `add_case` over the in-memory transport and asserts `bridge.state.promptName` / `promptCases`; the tool-count assertion goes 36 to 38; `add_case` rejects a `verdict` outside the enum.
* client: the `promptlab` domain shows `#promptlab-view` and hides the others; one row per case; the verdict pill carries the right class; clicking a row expands its full output + note; the summary chips reflect the counts; fields are escaped. The client test follows the existing happy-dom render-harness pattern.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `promptlab` domain, the four state fields and their two beats, the two MCP tools with verdict validation, the view-model projection with the derived summary, the `#promptlab-view` (header summary + case table + secondary prompt panel) and its routing, the agent contract, and the tests above.

Deferred / non-goals:

* A full per-criterion quality scorecard (each Prompt Quality Criterion scored): the derived pass/warn/fail summary is the score for this pass; a criteria scorecard is a clean follow-up.
* Golden-output diffing (an expected output per case with match/mismatch): the verdict is the Evaluator's judgment, not an assertion against a golden output.
* Cross-round history / trend (the score climbing across rounds): the workbench shows the current run plus a round number, not a per-round timeline.
* Re-running cases from the pane: the cockpit narrates the agent's run; it does not execute prompts itself (the charter boundary).
