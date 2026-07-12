---
title: Local Telemetry
description: Enable local Copilot session telemetry, understand capture mechanics, and generate local reports
sidebar_position: 10
author: Microsoft
ms.date: 2026-07-12
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

At stop time, telemetry also appends a session summary with model and token usage when available.

When a token budget is configured, the hook also emits best-effort, non-blocking budget advisories as sessions grow. See [Token Budget Advisories](#token-budget-advisories).

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

Processed telemetry never stores full prompt text or full tool inputs (see
[Sensitive Data and Privacy](#sensitive-data-and-privacy)). A separate,
explicit opt-in records the first few hook payloads **verbatim** to
`raw-input.jsonl` for deep diagnostics. It is off by default, even when
telemetry is enabled, and is honored only by the Bash collector:

```bash
export HVE_TELEMETRY_RAW=1
```

Leave this unset unless you are actively debugging the hook payload shape, and
remove the captured file afterward. Because it stores prompts and tool inputs in
the clear, treat any session run with it enabled as potentially sensitive.

## Token Budget Advisories

When you set a positive integer token budget, the telemetry hook tracks observed
session token usage and emits a concise, non-blocking advisory as usage crosses
fixed thresholds. Advisories are best-effort context: they always allow
execution to continue and never block, cancel, or compact a session.

Budget advisories build on the same session usage totals as the session summary,
so local telemetry must be enabled for them to appear.

### Enable a Budget

Set `HVE_TOKEN_BUDGET` to the number of session tokens to treat as the full
budget. Only positive integers are honored; any other value disables advisories.

```bash
export HVE_TOKEN_BUDGET=200000
```

```powershell
$env:HVE_TOKEN_BUDGET = "200000"
```

### What You See

When usage crosses a threshold, the hook returns a `systemMessage` alongside its
normal `{"continue": true}` response. A message reads like:

```text
Token budget advisory: 60% used (60,000 of 200,000 session tokens). Source: session fallback; approximate as of 2026-07-12T12:00:00Z. Consider completing the current phase before starting additional work. Execution will continue.
```

Each message reports the usage percentage, observed and budgeted tokens, the
measurement source and accuracy, the snapshot time, and a suggested action.

### Thresholds and Guidance

Advisories fire at three fixed thresholds, each with escalating guidance:

| Threshold | Suggested action                                                       |
|-----------|------------------------------------------------------------------------|
| 30%       | No action is required.                                                 |
| 50%       | Consider completing the current phase before starting additional work. |
| 70%       | Consider saving progress and starting a new session.                   |

### Behavior

* **Evaluated at** `UserPromptSubmit`, `PreCompact`, and `Stop`.
* **One message per event.** When a single snapshot crosses more than one new
  threshold, only the highest newly crossed threshold is reported.
* **Once per session.** Each threshold notifies at most once; crossings are
  deduplicated using per-session state under `.budget-state/`.
* **`Stop` is silent.** The stop event refreshes budget state as a final record
  but never emits a new advisory.
* **Source and accuracy.** Usage sourced from the live process log is labeled
  `process log` and `exact`; usage reconstructed from session-state fallback is
  labeled `session fallback` and `approximate`. When usage cannot be determined,
  status is `unavailable` and no percentage is shown.
* **Non-blocking.** The response always keeps `continue` true and every message
  ends with "Execution will continue."

### Disable Budget Advisories

Unset `HVE_TOKEN_BUDGET` (or set it to a non-positive value). Telemetry
collection continues unaffected.

```bash
unset HVE_TOKEN_BUDGET
```

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

| Path                        | Purpose                                                                                                  |
|-----------------------------|----------------------------------------------------------------------------------------------------------|
| `sessions-YYYY-MM-DD.jsonl` | Daily event stream with hook events and session summaries                                                |
| `raw-input.jsonl`           | First few hook payloads stored verbatim; written only when `HVE_TELEMETRY_RAW=1` is set (Bash collector) |
| `.stacks/`                  | Per-session agent stack tracking used for attribution                                                    |
| `.budget-state/`            | Per-session token budget advisory state; written only when `HVE_TOKEN_BUDGET` is set                     |
| `report.generated.html`     | Optional self-contained report output                                                                    |

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

| Data Category                                 | Source                                                                    |
|-----------------------------------------------|---------------------------------------------------------------------------|
| Hook lifecycle events                         | Copilot hook payloads routed through collector scripts                    |
| Session summaries                             | `.copilot/session-state/<sid>/events.jsonl` (CLI session state)           |
| Additional model/token enrichment for reports | VS Code debug logs and session-state aggregation during report generation |

### Event Naming Normalization

The pipeline normalizes different casing variants of event names to canonical names used in stored telemetry records. This keeps mixed-client event surfaces queryable from one schema.

### Storage and Retention Behavior

* Data is stored locally under `.copilot-tracking/telemetry` by default.
* Records append to date-partitioned files (`sessions-YYYY-MM-DD.jsonl`).
* A small verbatim raw payload sample is stored in `raw-input.jsonl` only when `HVE_TELEMETRY_RAW=1` is explicitly set; see [Sensitive Data and Privacy](#sensitive-data-and-privacy).
* Per-session agent stack files are maintained under `.stacks/` for attribution and cleaned up on session stop.

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
at `~/.hve/telemetry-dirs.txt` (honoring `HVE_HOME`).

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

> [!NOTE]
> **Registry-driven cleanup is name-constrained.** `clean-telemetry.sh
> --all-dirs` iterates every path in `~/.hve/telemetry-dirs.txt` and, in each
> directory, removes only a fixed allow-list of artifact names
> (`raw-input.jsonl`, `report.generated.html`, `sessions-*.jsonl`, and the
> `.stacks/` directory). It never deletes a directory wholesale. A tampered
> registry can therefore, at most, delete those specific names in an
> attacker-chosen directory, not arbitrary files. The `.stacks/` entry is
> removed recursively, but symlinked artifacts are unlinked rather than
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
* No enrichment data: model and token enrichment depends on available debug logs and session-state data.
* Report generation fails: ensure `python3` is available for enrichment. The bash generator also needs `jq`; the PowerShell generator (`Invoke-TelemetryReport.ps1`) does not.

## Related Guides

* [Contributing Hooks](../contributing/hooks)
* [Environment Customization](environment)
* [Managing Collections](collections)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
