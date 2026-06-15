---
title: Local Telemetry
description: Enable local Copilot session telemetry, understand capture mechanics, and generate local reports
sidebar_position: 10
author: Microsoft
ms.date: 2026-06-08
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

The telemetry manifest is at `.github/hooks/telemetry.json`.

Events currently captured include:

* session start
* user prompt submission
* pre-tool and post-tool use
* subagent start and stop
* agent stop and session end
* pre-compact events

At stop time, telemetry also appends a session summary with model and token usage when available.

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

| Path | Purpose |
|---|---|
| `sessions-YYYY-MM-DD.jsonl` | Daily event stream with hook events and session summaries |
| `raw-input.jsonl` | First few raw hook payloads for diagnostics |
| `.stacks/` | Per-session agent stack tracking used for attribution |
| `report.generated.html` | Optional self-contained report output |

## Data Captured and Storage Schema

This section describes the mechanics of what local telemetry collects and where each class of data comes from.

### Collection Pipeline

1. Copilot lifecycle events invoke the telemetry hook from `.github/hooks/telemetry.json`.
2. Shell entry points (`telemetry-collector.sh` and `Invoke-TelemetryCollector.ps1`) enforce opt-in gates.
3. Event payloads are normalized and appended to daily JSONL files.
4. On stop events, a `SessionSummary` record is appended with model and token aggregates when available.

### Core Record Types

The daily JSONL stream contains two primary record types:

| Record Type | Trigger | Purpose |
|---|---|---|
| Hook event records | Session/tool/subagent lifecycle events | Timeline of what happened during a session |
| `SessionSummary` | Stop event (`Stop`) | Aggregated usage totals and model-level summary |

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

### Session Summary Fields

When available at stop time, `SessionSummary` includes:

* `models`: Model usage map observed during the session
* `model_usage`: Per-model aggregate usage counters
* `input_tokens`, `output_tokens`
* `cache_read_tokens`, `cache_write_tokens`
* `total_nano_aiu`
* `turns`, `messages`
* Optional `reasoning_effort`, `subagent_map`, and `client`

### Data Sources by Layer

| Data Category | Source |
|---|---|
| Hook lifecycle events | Copilot hook payloads routed through collector scripts |
| Session summaries | `.copilot/session-state/<sid>/events.jsonl` (CLI session state) |
| Additional model/token enrichment for reports | VS Code debug logs and session-state aggregation during report generation |

### Event Naming Normalization

The pipeline normalizes different casing variants of event names to canonical names used in stored telemetry records. This keeps mixed-client event surfaces queryable from one schema.

### Storage and Retention Behavior

* Data is stored locally under `.copilot-tracking/telemetry` by default.
* Records append to date-partitioned files (`sessions-YYYY-MM-DD.jsonl`).
* A small raw payload diagnostic sample is stored in `raw-input.jsonl`.
* Per-session agent stack files are maintained under `.stacks/` for attribution and cleaned up on session stop.

## Generate a Report

Use the repository script:

```bash
npm run telemetry:report
```

The script wraps `.github/hooks/telemetry/generate-telemetry-report.sh` and creates a self-contained report HTML file.

Useful options:

```bash
bash .github/hooks/telemetry/generate-telemetry-report.sh --help
bash .github/hooks/telemetry/generate-telemetry-report.sh --date all
bash .github/hooks/telemetry/generate-telemetry-report.sh --open
```

## Cross-Project Reports

Telemetry is captured per project, so each repository keeps its own store under
`<repo>/.copilot-tracking/telemetry`. To view sessions across every project in a
single report, each store is recorded once per session in a user-level registry
at `~/.hve/telemetry-dirs.txt` (honoring `HVE_HOME`).

Generate a combined, cross-project report with `--all-dirs`:

```bash
bash .github/hooks/telemetry/generate-telemetry-report.sh --all-dirs --date all
```

The registry self-populates as you work across repositories, so no manual setup
is required. Stale directories (deleted or moved repositories) are pruned
automatically when the report runs. Each session is labeled with its originating
project in the report, so combined output still reads per project.

## Reports Without the Repository (Extension Users)

When telemetry runs from the VS Code extension rather than this repository, the
`npm run telemetry:report` script is not present and the report generator lives
at a version-pinned extension path that is awkward to locate. To bridge this, a
cross-project launcher is written into the HVE home directory (`~/.hve`, honoring
`HVE_HOME`) at session start, next to the registry it reads:

* `~/.hve/generate-report.sh`: for unix shells and Git Bash on Windows
* `~/.hve/generate-report.ps1`: for PowerShell (requires `bash`, for example Git Bash)

Run the launcher from the HVE home directory without knowing the extension path.
It defaults to a combined, cross-project report written to
`~/.hve/report.generated.html`:

```bash
bash ~/.hve/generate-report.sh
bash ~/.hve/generate-report.sh --date all
```

The launchers are regenerated every session, so they self-heal after an
extension upgrade. They forward any extra arguments to the report generator.

## Troubleshooting

Common issues:

* No events captured: verify one enablement gate is set and your hook manifest is active.
* No enrichment data: model and token enrichment depends on available debug logs and session-state data.
* Report generation fails: install `jq` and ensure `python3` is available.

## Related Guides

* [Contributing Hooks](../contributing/hooks)
* [Environment Customization](environment)
* [Managing Collections](collections)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
