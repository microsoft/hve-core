---
title: Local Telemetry
description: Enable local Copilot session telemetry, understand capture mechanics, and generate local reports
sidebar_position: 10
author: Microsoft
ms.date: 2026-08-02
ms.topic: how-to
keywords:
  - telemetry
  - hooks
  - local reporting
  - copilot
estimated_reading_time: 7
---

## What This Captures

The local telemetry hook captures Copilot lifecycle events into local JSONL files. It is intended for local analysis and troubleshooting of your own sessions.

The telemetry manifest is at `.github/hooks/shared/telemetry.json`.

Events currently captured include:

* session start
* user prompt submission
* pre-tool and post-tool use
* subagent start and stop
* agent stop and session end
* pre-compact events

At stop time, telemetry also appends a session summary with model and token usage, but only when the surface you are running on writes a usage log it can read. See [Enrichment Coverage by Surface](#enrichment-coverage-by-surface) for what each surface provides.

## Prerequisites

All telemetry processing runs in Python. The shell entry points are thin wrappers that gate on opt-in and hand stdin to `_telemetry_core.py`.

| Requirement     | Needed for                                                | Notes                                                                                    |
|-----------------|-----------------------------------------------------------|------------------------------------------------------------------------------------------|
| Python 3.11+    | Event collection, reports, cleanup                        | Collectors try `python3` then `python`; the report and cleanup scripts require `python3` |
| Bash 3.2+       | Bash entry points                                         | macOS system Bash works; no Bash 4 features used                                         |
| PowerShell 5.1+ | `Invoke-TelemetryCollector.ps1`                           | Written for Windows PowerShell; no `#Requires` floor                                     |
| PowerShell 7.4+ | `Invoke-TelemetryReport.ps1`, `Invoke-TelemetryClean.ps1` | Enforced by `#Requires -Version 7.4`                                                     |
| `jq`            | `generate-telemetry-report.sh`                            | Not needed by `Invoke-TelemetryReport.ps1`                                               |

You only need one shell family. Copilot selects the Bash or PowerShell entry point based on the host.

Only `telemetry-collector.sh` checks the interpreter version, skipping a `python3` older than 3.11 and falling back to `python`. Where Python is missing or too old, the collector warns and continues without recording events, so collection never blocks a session. The report and cleanup scripts are run by hand and fail loudly instead.

## Enable Local Telemetry

Telemetry is opt-in. Enable it with either an environment variable or a repository marker file.

### Option 1: Environment Variable

```bash
export HVE_TELEMETRY=1
```

```powershell
$env:HVE_TELEMETRY = "1"
```

### Option 2: Repository Marker File

Create `.hve-telemetry` at the repository root:

```bash
touch .hve-telemetry
```

Either option enables collection. If both are absent, the hook exits in no-op mode.

### Optional: Verbatim Raw Payload Capture

Processed telemetry never stores full prompt text or full tool inputs (see
[Sensitive Data and Privacy](#sensitive-data-and-privacy)). A separate,
explicit opt-in records the first few hook payloads **verbatim** to
`raw-input.jsonl` for deep diagnostics. It is off by default, even when
telemetry is enabled, and both the Bash and PowerShell collectors honor it:

```bash
export HVE_TELEMETRY_RAW=1
```

Leave this unset unless you are actively debugging the hook payload shape, and
remove the captured file afterward. Because it stores prompts and tool inputs in
the clear, treat any session run with it enabled as potentially sensitive.

## View Reports

Generate a report with the script in ~/.hve (created at session start):

```bash
bash ~/.hve/generate-report.sh
```

Which will generate a `report.generated.html` for viewing.

The generated report path is printed when report generation completes.

The report is self-contained: it embeds every selected JSONL file (session
events plus model and token enrichment) inline. Combined cross-project reports
over a long history (`--all-dirs --date all`) can therefore grow to several
megabytes. Narrow the scope with a specific `--date`, or report a single project
without `--all-dirs`, when a smaller file is preferred.

## Disable Local Telemetry

Disable collection by removing both enablement gates:

1. Unset `HVE_TELEMETRY`
2. Remove `.hve-telemetry` from repository root

## Where Data Is Written

Default output directory:

`<repo>/.copilot-tracking/telemetry`

Override with `HVE_TELEMETRY_DIR` when needed.

Key files and folders:

| Path                                            | Purpose                                                                                                   |
|-------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| `sessions-YYYY-MM-DD.jsonl`                     | Daily event stream with hook events and session summaries                                                 |
| `sessions-YYYY-MM-DD.<stamp>-<pid>-<hex>.jsonl` | Fallback shard written when a collector could not take the day log's lock; read alongside it              |
| `raw-input.jsonl`                               | First few hook payloads stored verbatim; written only when `HVE_TELEMETRY_RAW=1` is set                   |
| `.stacks/<session-id>/ops.log`                  | Append-only agent push and pop records for one session, replayed to attribute events to the calling agent |
| `report.generated.html`                         | Optional self-contained report output                                                                     |

## Data Captured and Storage Schema

This section describes the mechanics of what local telemetry collects and where each class of data comes from.

### Collection Pipeline

1. Copilot lifecycle events invoke the telemetry hook from `.github/hooks/shared/telemetry.json`.
2. Shell entry points (`telemetry-collector.sh` and `Invoke-TelemetryCollector.ps1`) enforce opt-in gates.
3. Event payloads are normalized and appended to daily JSONL files.
4. On stop events, a `SessionSummary` record is appended with model and token aggregates when available.

### Core Record Types

The daily JSONL stream contains two primary record types:

| Record Type        | Trigger                                | Purpose                                         |
|--------------------|----------------------------------------|-------------------------------------------------|
| Hook event records | Session/tool/subagent lifecycle events | Timeline of what happened during a session      |
| `SessionSummary`   | Stop event (`Stop`)                    | Aggregated usage totals and model-level summary |

### Common Fields

Most hook event records include:

* `ts`: Event timestamp (ISO 8601)
* `sid`: Session identifier
* `event`: Canonical event name (for example, `PreToolUse`, `PostToolUse`, `SessionStart`)
* `cwd`: Working directory at capture time

Additional fields are event-specific. Examples:

* Prompt events: truncated prompt preview
* Tool events: tool name, selected input keys, response length, inferred agent attribution
* Subagent events: agent name and display name
* Stop events: stop reason

Tool events also carry two fields the bundled report does not render, kept for
offline analysis of a full session timeline. A tool payload names no agent, and a
turn's tool calls run in parallel, so an active subagent is not evidence that it
issued any particular call:

* `agent`: Present only when no subagent was in flight, holding `root`. This is
  the one case where the caller is certain.
* `agents`: The candidate list (`root` plus every started-but-not-stopped
  subagent) when one or more subagents were running. The two fields are mutually
  exclusive; neither resolves the caller once work overlaps.
* `tool_use_id`: The client's identifier for one tool invocation, pairing a
  `PreToolUse` record with its `PostToolUse` record exactly, where the report's
  by-name correlation can only approximate the pairing under concurrency.

Token attribution does not have this problem and the report does render it; see
[Session Summary Fields](#session-summary-fields).

### Session Summary Fields

When available at stop time, `SessionSummary` includes:

* `models`: Model usage map observed during the session
* `model_usage`: Per-model aggregate usage counters
* `input_tokens`, `output_tokens`
* `cache_read_tokens`, `cache_write_tokens`
* `total_nano_aiu`
* `turns`, `messages`
* `token_source`: provenance of the token numbers (`process_log` or `state_fallback`)
* Optional `reasoning_effort`, `subagent_map`, and `client`
* `agent_usage`: Per-agent token counters, present only under `process_log`

Unlike tool attribution, the token split is exact. Every process-log request
records the agent that issued it, so the collector partitions requests by agent
and resolves each id to a display name through `subagent_map`. The report shows
the split under Token Usage, as a share of AIU (or of output tokens where the
host reports no AIU), and rolls it up to a Subagent Share card.

Where a host emits no process log, the report reconstructs the same split by
crediting each merged subagent session its own totals and treating the balance
as the root agent's.

### Data Sources by Layer

| Data Category             | Source                                          | Availability                   |
|---------------------------|-------------------------------------------------|--------------------------------|
| Hook lifecycle events     | Copilot hook payloads via the collector scripts | Any surface that runs hooks    |
| Session summaries         | `~/.copilot/session-state/<sid>/events.jsonl`   | Copilot CLI only               |
| Precise per-request usage | `~/.copilot/logs/process-*.log`                 | Copilot CLI only               |
| Report-time enrichment    | VS Code `debug-logs/**/*.jsonl` (`llm_request`) | VS Code builds that write them |

### Enrichment Coverage by Surface

Event capture and usage enrichment are separate concerns. Hook events are recorded on any surface that runs hooks. Model and token data comes from surface-specific logs that telemetry reads but does not create, and the two sources are not interchangeable.

#### Copilot CLI

The CLI maintains its own session state under `~/.copilot/session-state/<sid>/` (honoring `COPILOT_HOME`).
When that directory contains an `events.jsonl`, the collector appends a `SessionSummary` inline at `Stop`, `SessionEnd`, and `PreCompact`, and the report re-derives summaries through the `aggregate-session` pass.
Precise per-request usage comes from `~/.copilot/logs/process-*.log`, located through the session lock PID and, once the lock is gone, by scanning for logs that reference the session's interaction ids.
Not every state directory has an `events.jsonl`; sessions that never reached a recorded turn produce no summary.

#### VS Code

VS Code sessions do not appear under `~/.copilot/session-state`, so the CLI path contributes nothing for them. Their only enrichment source is the Copilot Chat debug log, discovered by globbing `debug-logs/**/*.jsonl` beneath the workspace storage roots for `.vscode-server-insiders`, `.vscode-server`, `.vscode`, and the platform user-data directories for Code - Insiders, Code, and VSCodium.

> [!IMPORTANT]
> Debug logs are not written by every VS Code build. Public (stable) VS Code on macOS has been confirmed to produce none. On such a host, telemetry still records the full event timeline, but the report shows no model, token, or cost data for those sessions, and no `SessionSummary` record is written. This is a source-availability gap, not a telemetry failure.

Missing enrichment is never fatal. Both aggregation passes return a non-zero status when they find nothing, the generator silently skips the corresponding layer, and the report renders from the hook event stream alone.

### Summary Provenance

Each `SessionSummary` carries a `token_source` field recording where its numbers came from:

| `token_source`   | Meaning                                                        |
|------------------|----------------------------------------------------------------|
| `process_log`    | Per-request `assistant_usage` metrics from the CLI process log |
| `state_fallback` | Summed `session.shutdown` model metrics from `events.jsonl`    |

Under `state_fallback`, shutdown metrics are summed across every run segment because a resumed session resets its counters on each resume. A live session that has not yet ended a segment knows only per-message output tokens, so input, cache, and AIU totals are reported as unknown rather than zero, keeping an in-progress session distinguishable from a free one.

### Event Naming Normalization

The pipeline normalizes different casing variants of event names to canonical names used in stored telemetry records. This keeps mixed-client event surfaces queryable from one schema.

### Storage and Retention Behavior

* Data is stored locally under `.copilot-tracking/telemetry` by default.
* Records append to date-partitioned files (`sessions-YYYY-MM-DD.jsonl`).
  Concurrent hook events append to that one file: POSIX resolves `O_APPEND` in the kernel, and on Windows the collector takes a byte-range lock first, because the C runtime emulates append as seek-then-write and would otherwise let one writer overwrite another.
  A collector that cannot take the lock writes a sibling shard named `sessions-YYYY-MM-DD.<stamp>-<pid>-<hex>.jsonl`, which the report generators pick up alongside the day log.
* A small verbatim raw payload sample is stored in `raw-input.jsonl` only when `HVE_TELEMETRY_RAW=1` is explicitly set; see [Sensitive Data and Privacy](#sensitive-data-and-privacy).
* Per-session agent stacks are maintained under `.stacks/<session-id>/ops.log`, an append-only record of agent pushes and pops that is replayed to attribute each event, and removed on session stop.

### Sensitive Data and Privacy

Local telemetry writes plaintext JSONL to local disk only. It makes no network
calls and the default output directory (`.copilot-tracking/telemetry`) is
gitignored, so data is not committed. The risk is local-disk exposure, not a
committed leak. Be aware of what each layer records:

* **Processed stream (`sessions-*.jsonl`)** stores a truncated prompt preview
  (first 200 characters of each submitted prompt) and, for tool events, only
  the tool input *key names* plus selected fields such as file paths and
  subagent names. It does not store full tool input *values* (file contents or
  shell command strings). A secret pasted into the start of a prompt can still
  appear in the 200-character preview.
* **Verbatim raw dump (`raw-input.jsonl`)** stores the first few hook payloads
  exactly as received, including the full prompt and the full tool input (file
  contents being written, shell command strings). It is off by default and only
  written when `HVE_TELEMETRY_RAW=1` is set.
* **User-level locations** under `~/.hve` and `~/.copilot` (honoring `HVE_HOME`)
  hold the report generator and directory registry. Generated reports embed the
  captured JSONL inline.

To reduce exposure: keep `HVE_TELEMETRY_RAW` unset, avoid pasting secrets into
prompts while telemetry is enabled, and remove captured files when you are done
(`bash ~/.hve/clean-telemetry.sh` or delete the telemetry directory).

## Generate a Report

Run the report generator directly:

```bash
bash .github/hooks/shared/telemetry/generate-telemetry-report.sh --help
bash .github/hooks/shared/telemetry/generate-telemetry-report.sh --date all
bash .github/hooks/shared/telemetry/generate-telemetry-report.sh --open
```

On Windows (or any PowerShell host) the native equivalent needs no `bash`:

```powershell
pwsh .github/hooks/shared/telemetry/Invoke-TelemetryReport.ps1 -Date all
pwsh .github/hooks/shared/telemetry/Invoke-TelemetryReport.ps1 -Open
```

## Cross-Project Reports

Telemetry is captured per project, so each repository keeps its own store under
`<repo>/.copilot-tracking/telemetry`. To view sessions across every project in a
single report, each store is recorded once per session in a user-level registry
at `~/.hve/telemetry-dirs` (honoring `HVE_HOME`).

Generate a combined, cross-project report with `--all-dirs`:

```bash
bash .github/hooks/shared/telemetry/generate-telemetry-report.sh --all-dirs --date all
```

The PowerShell generator takes `-AllDirs` for the same cross-project report:

```powershell
pwsh .github/hooks/shared/telemetry/Invoke-TelemetryReport.ps1 -AllDirs -Date all
```

The registry self-populates as you work across repositories, so no manual setup
is required. Stale directories (deleted or moved repositories) are pruned
automatically when the report runs. Each session is labeled with its originating
project in the report, so combined output still reads per project.

To report on a single store, pass `--path` (`-Path`). An explicit path overrides
`--all-dirs`, so the generated cross-project launcher can also be scoped down:

```bash
bash ~/.hve/generate-report.sh --path /path/to/repo/.copilot-tracking/telemetry --date all
```

Cleanup follows the same precedence: `clean-telemetry.sh --path DIR` restricts
removal to that one store and leaves the registry, launchers, and every other
project untouched, even when `--all-dirs` is also present. Both entry points
report the override on stderr, so a narrowed destructive scope is never silent.

> [!NOTE]
> **Registry-driven cleanup is name-constrained.** `clean-telemetry.sh
> --all-dirs` iterates every path in `~/.hve/telemetry-dirs` and, in each
> directory, removes only a fixed allow-list of artifact names:
> `raw-input.jsonl`, `report.generated.html`, date-shaped
> `sessions-YYYY-MM-DD*.jsonl` logs and their fallback shards, and the
> `.stacks/` directory. It never deletes a directory
> wholesale. A tampered registry can therefore, at most, delete those specific
> names in an attacker-chosen directory, not arbitrary files. The `.stacks/`
> entry is removed recursively, but symlinked artifacts are unlinked rather than
> followed, so the target of a symlink is never deleted. The registry lives in
> the user-owned HVE home (`~/.hve`, honoring `HVE_HOME`), so an attacker able
> to tamper with it already holds the user's filesystem privileges; the risk is
> low and the blast radius is bounded.

## Reports Without the Repository (Extension Users)

When telemetry runs from the VS Code extension rather than this repository, the
report generator lives at a version-pinned extension path that is awkward to
locate. To bridge this, a cross-project launcher is written into the HVE home
directory (`~/.hve`, honoring `HVE_HOME`) at session start, next to the registry
it reads:

* `~/.hve/generate-report.sh`: for unix shells and Git Bash on Windows
* `~/.hve/generate-report.ps1`: for PowerShell, runs natively (no `bash` required)

Run the launcher from the HVE home directory without knowing the extension path.
It defaults to a combined, cross-project report written to
`~/.hve/report.generated.html`:

```bash
bash ~/.hve/generate-report.sh
bash ~/.hve/generate-report.sh --date all
```

From PowerShell, run the native launcher:

```powershell
~/.hve/generate-report.ps1
~/.hve/generate-report.ps1 -Date all
```

The launchers are regenerated every session, so they self-heal after an
extension upgrade. They forward any extra arguments to the report generator.

## Troubleshooting

Common issues:

* No events captured: verify one enablement gate is set and your hook manifest is active.
* Events captured but no model, token, or cost data: the surface produced no usable usage log. On the CLI, confirm `~/.copilot/session-state/<sid>/events.jsonl` exists for the session. In VS Code, confirm a `debug-logs` directory exists under your workspace storage; stable builds may not write one. See [Enrichment Coverage by Surface](#enrichment-coverage-by-surface).
* Token totals look approximate: check `token_source` on the `SessionSummary` record. `state_fallback` means the CLI process log was unavailable and totals were summed from shutdown metrics.
* Report generation fails: ensure `python3` is available for enrichment. The bash generator also needs `jq`; the PowerShell generator (`Invoke-TelemetryReport.ps1`) does not.

## Related Guides

* [Contributing Hooks](../contributing/hooks)
* [Environment Customization](environment)
* [Managing Packages](packages)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
