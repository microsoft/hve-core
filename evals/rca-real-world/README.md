---
title: RCAEval real-world RCA evaluation
description: Compare skilled and skill-free RCA on separate prepared and raw blinded RCAEval cohorts
author: HVE Core Team
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - root cause analysis
  - rcaeval
  - evaluation
  - copilot sdk
  - blinded testing
---

<!-- cspell:ignore diskio -->

This evaluation compares the root-cause-analysis skill with a skill-free baseline on separate
five-case prepared and raw RCAEval fault-injection cohorts. Both conditions run by default,
using the same selected
model profile, cases, evidence-tool contracts, turn limits, timeouts, and credit limits. Workflow
conformance is measured separately from held-out diagnostic results. The selected cases do not
represent organic production incidents or a statistically representative benchmark.

## Recorded evaluation snapshots

* [2026-11-06 paired raw-data debug evaluation](PR-3136-RAW-DEBUG-2026-11-06.md) records
  three completed `ad-hoc-v12` rounds: 30 attempted sessions, 29 integrity-valid reports,
  one execution failure, and 5/15 skilled versus 1/15 baseline leading-candidate service
  matches per scheduled condition session. One format rejection and four query rejections
  were recorded. Consumption was 116.387373 AI credits. Its
  [machine-readable snapshot](PR-3136-RAW-DEBUG-2026-11-06.json) preserves all 30 trial
  records without telemetry or private captures. Human causal review remains pending,
  including six skilled sign-off-readiness claims that missed the held-out service and
  one logical output-contract gate failure on an integrity-valid report.
  Keep this raw cohort separate from the prepared and production-model snapshots below.
* [2026-11-04 paired production-model evaluation](PR-3136-PRODUCTION-2026-11-04.md) records
  the completed `ad-hoc-v10` run using `gpt-5.6-sol`: 30 integrity-valid reports, zero format
  or query rejections, and 15/15 leading-candidate service matches in each condition.
  Consumption was 3,360.57570 AI credits, approximately USD 33.61, within the pooled
  6,000-credit allowance. Its [machine-readable snapshot](PR-3136-PRODUCTION-2026-11-04.json)
  preserves all 30 trial records. Production denotes the benchmark model profile, not
  readiness certification; human causal review remains pending. Earlier snapshots stay
  separate because model, protocol, and budget policies differ.
* [2026-11-04 paired schema-mode evaluation](PR-3136-DEBUG-2026-11-04.md) records the
  completed `ad-hoc-v9` real-data run: 30 integrity-valid reports, zero format rejections,
  and 15/15 skilled versus 11/15 baseline leading-candidate service matches. The
  [machine-readable snapshot](PR-3136-DEBUG-2026-11-04.json) preserves all 30 trial records.
  This is an official repository evaluation record using the debug profile, not a
  production-readiness or general efficacy claim; human causal review remains pending.
* [2026-11-02 paired debug snapshot](PR-3136-DEBUG-2026-11-02.md) captures the completed
  `ad-hoc-v7` run, both conditions, case mappings, provenance, failures, and unresolved review.
  Its [machine-readable results](PR-3136-DEBUG-2026-11-02.json) contain all 30 trial records.
* [Earlier evidence](PR-3136-EVIDENCE.md) describes a different, skilled-only evaluation.
  Preserve it as historical evidence; do not combine its results with the paired debug snapshot.

## Run ID naming

For each new evaluation, choose an unused `--run-id` without calendar dates or timestamps,
for example `rcaeval-raw-debug-example-id`. Replace `example-id` with a fresh alphabetic
suffix. The complete ID must contain 3-64 lower-case letters, digits, or hyphens and start
with a letter or digit.

The run ID becomes the prefix of model-visible message and evidence-request identities.
Non-date names mitigate observed date-suffix copying failures; they do not guarantee exact
model output. This is a naming convention, not a new CLI restriction. Exact identity
validation, approval binding, and final-envelope schema checks remain unchanged.

Use the same ID for preparation, every round, technical-stop continuation, and report
generation. Keep existing run IDs unchanged, including date-bearing IDs; do not rename
their directories or rewrite historical artifacts. Apply the convention only to new runs.
Use the run manifest's `startedAt` timestamp for chronology instead of embedding a date
in the ID.

## Prepared and raw evidence tracks

The default `prepared` track retains the existing five cases, JSONL conversion, metric mapping,
and specialized evidence queries. Historical evaluation snapshots remain unchanged.

Both tracks use the same dataset downloader during explicit input preparation, not during
skill invocation or evaluation rounds. It restricts source paths, verifies sizes when supplied,
and checks SHA-256 identities from the contract or pinned LFS metadata, or Git blob identities
for other source objects, before writing local files. These checks establish source identity,
not parser safety. Subsequent rounds verify and reuse the local inputs without downloading
the dataset again.

The `raw` track downloads five additional cases from the same pinned revision, excludes the
existing five, and separates scorer-only truth from model-visible evidence. Every telemetry
Parquet is converted to JSONL using the pinned reader. Original fields and row order are
preserved; BigInt values, dates, bytes and nonfinite numbers use the existing deterministic
JSON-compatible encoding. Original Parquet bytes remain unchanged in scorer-only downloads.
No metric mappings, renamed fields, added telemetry fields, resampling, or preparation-time
aggregates are produced. This track is conversion-only `jsonl-unmapped-v1`, not an assessment
of access to original or unfamiliar binary formats. The case-index Parquet remains scorer-only.

[Raw cohort provenance](raw-cases.json) records the seed `rcaeval-raw-2026-11-05`, all five source
identities and file hashes, the excluded cases, and the 730-case eligible population digest.
Selection ranks eligible source paths by SHA-256 of `seed + NUL + sourcePath`, with a code-unit
tie-break, then takes the first five without replacement. Source availability, sensitive content,
and diagnostic success do not influence selection. A missing, oversized, or invalid source file
stops preparation rather than substituting another case.

Prepare a fresh raw run using the [run ID naming convention](#run-id-naming), without
invoking a model:

```powershell
node scripts\evals\rca-real-world\prepare-cli.mts --run-id <new-run-id> --track raw --seed rcaeval-raw-2026-11-05
node scripts\evals\rca-real-world\prepare-cli.mts --run-id <new-run-id> --track raw --check
```

Both conditions receive the same trusted general-purpose tools: `list_files`, bounded UTF-8
`read_file`, and `query_jsonl`. Queries support AND predicates over exact original field names,
projection, pagination, and optional on-demand numeric min/max/mean/count summaries and groups.
They do not infer service or metric identities. Numeric strings are summarized only within
safe integer precision; other values are counted as nonnumeric. Summary field counts distinguish
numeric and nonnumeric values. A query scans the full selected file, has a 30-second deadline,
and returns at most 100 rows and 64 KiB with explicit continuation or oversized-row information.
Results separately identify scanned rows, matching source rows, and returned rows or summaries.
Summaries allow at most 1,000 groups, 1,000 original fields per group and 32,000 field/group cells; select columns or
narrow filters when needed. Individual file reads return at most 8 KiB.

No Docker, Python environment, shell, generated-code execution, or additional reader is needed
for an investigation. Existing cumulative session/run limits and exact approvals still apply.
The approval risk is `read-only bounded JSONL evidence`. Parameter mistakes are recoverable
query errors; corrupt evidence, cursor binding violations and scan deadlines are technical failures.

To convert a previously downloaded raw cohort that has never started an evaluation, without
downloading its source again:

```powershell
node scripts\evals\rca-real-world\prepare-cli.mts --run-id <unused-raw-run-id> --track raw --convert-only
```

Conversion verifies original source hashes and records JSONL hashes, sizes and row counts.
An existing evaluation manifest prevents conversion from changing previously evaluated inputs.

Only after separate approval of the model, cost allowance, and round cadence, execute:

```powershell
node scripts\evals\rca-real-world\run-cli.mts --run-id <new-run-id> --round 1 --track raw --conditions both --profile debug --report-output schema
```

Track and conversion-format identities are immutable across conditions and rounds. New runs use
`ad-hoc-v12`; historical protocols cannot resume or pool with it. Reports label the track and
format, and distinguish executed file reads, JSONL queries, and reported access blockers from
diagnostic outcomes, technical failures, and costs. Query counts are not proof of causal
evidence coverage; that judgment remains pending human review.

Raw and prepared cases differ. Their results describe two cohorts, not a controlled estimate of
the causal effect of preparation. Source identities belong only in preparation/scoring records
and published provenance, never in the model's incident metadata.

## Field investigations versus evaluation trials

In field use, the [root-cause-analysis skill](../../.github/skills/root-cause-analysis/root-cause-analysis/SKILL.md)
conducts one investigation, not three benchmark rounds. Continue hypothesis testing and evidence
collection automatically whenever the skill's host-mode rules, security policy, authorization,
declared scope, and execution budget permit it without another approval. Ask only when an
applicable approval gate or missing user decision requires it. This does not remove the skill's
generic-mode approval requirements or expand Azure SRE automatic collection authority.

An investigation may contain multiple test cycles and may resume from a checkpoint. These are
progress within an investigation, not repeated evaluation trials.

The three-round schedule below is for baseline measurement and regression evaluation before
publication or after a substantial skill update. It does not prescribe field investigation
cadence. Choosing to run all three evaluation rounds never overrides security or tool approvals.

## Source and license

The preparation command retrieves selected files from
[`phamquiluan/RCAEval`](https://huggingface.co/datasets/phamquiluan/RCAEval) at revision
`afeacb11bcc94dadfd1c8f483ee4377b2b8b614e`. That dataset revision is published under the MIT
license.

No RCAEval telemetry or transformed telemetry is committed to this repository. The committed
case contract records source paths only for preparation and provenance. Generated data remains
under the gitignored evaluation evidence root.

### Current case selection

For newly prepared runs, `case-04` uses `re1tt_ts-travel-service_mem_3` in the pinned
dataset revision. It replaces `re2ss_user_loss_1`, whose logs contained email-shaped strings.
The replacement was the first email-free draw among three cases randomly sampled without
replacement from the 730 cases outside the existing five-case selection. All source files
were downloaded, identity-verified, and scanned; Parquet text was scanned after decoding,
using the report scanner's email-address expression. The replacement's 961 metric rows and
injection-time file contained no matches. No telemetry values were rewritten, and the report
safety scan remains unchanged.

This is a metrics-only Train Ticket memory-fault case, not a modality-equivalent replacement
for the previous Sock Shop network-loss case. The current selection therefore has two
metrics-only cases and three metrics/logs/traces cases, with no Sock Shop case. Comparisons
across the old and new selections must disclose this case-mix change.

Use a fresh run ID after this contract change. Historical prepared inputs, scores, and evidence
remain associated with their original case selection and must not be overwritten or rescored
as the replacement. Replacing `case-04` does not certify the other cases as email-free; in
particular, earlier runs also encountered email-shaped strings in `case-03`.

## Metric identities

Preparation preserves source column names and writes a per-case `metric-columns.json` mapping
each wide numeric column to its service and metric identities. The pinned RCAEval schema uses
terminal metric suffixes: `cpu`, `mem`, `latency`, `latency-50`, `latency-90`, `load`, `error`,
`diskio`, `socket`, and `workload`. Preparation extracts only these declared suffixes, preserving
underscores inside service names, and rejects unknown numeric columns instead of guessing a
boundary. The mapping uses telemetry schema only, never held-out root-cause labels.

`read_incident_scope` exposes the mapping. Both metric tools compare requested identities using
trimmed, case-insensitive equality, not substring matching. For example, `latency` does not match
`latency-90`, and `user` does not match `user-db`. Narrow rows use their explicit identity fields;
rows missing a requested identity are excluded. Mixed narrow and wide rows are handled per row.
Matched-row counts include only rows contributing selected finite numeric values.

The preparation manifest hashes each mapping, and continuation fingerprints include the mapping
files. Transformation version `2.0.0` requires freshly prepared inputs; old runs must not be resumed
with the new filtering semantics. Unknown, missing, or malformed mappings fail explicitly.

## Blindness boundary

The preparation command creates two separate roots:

* `model-visible/` contains neutral incident metadata and either prepared evidence stores or
  unchanged raw files, according to the selected track.
* `scorer-only/` contains source provenance, hashes, and held-out service and fault labels.

The `ad-hoc-v12` protocol compares two ad hoc investigations using one selected Copilot host mode.
Each condition runs in a fresh temporary workspace and independent model session. Only the
`with-skill` condition receives the three packaged RCA skills. The `without-skill` condition
receives no skill bundle, no custom agent, and no RCA reasoning procedure. Both receive the
same neutral incident metadata, task, optional-tool invitation, and complete tool schemas.
They cannot access the repository, the case contract, source paths,
other cases, prior model output, or scorer-only files. Genuine service names remain in telemetry
because they are evidence; packaging metadata never identifies one as the expected answer.

The CLI uses a private home and configuration for every session. The host disables hooks and IDE
autoconnection, suppresses custom instruction loading, disables built-in MCP servers, and exposes
no model-callable evidence tools. Native skill activation remains available for the staged skilled
package. Evidence calls are instead validated and executed by the host. Inherited
skills can still be discovered from a temporary directory's ancestors: the harness enumerates
them, disables all except the exact staged RCA package in private settings, then verifies the
enabled skill and plugin inventories. The baseline must have zero enabled skills and plugins.
Unsupported inventory commands, malformed responses, or unexpected enabled capabilities fail
closed before inference. No user configuration is changed or copied into the workspace.

For the baseline, this establishes no enabled runtime skills, not absence of skill-related material in model training.
The skilled bundle is supplied explicitly in the initial prompt; inherited custom instructions
are suppressed for both conditions. CLI prompts are sent through stdin rather than command-line
arguments, avoiding platform command-line length limits without changing prompt content.

Neither condition is told to discover scope first, compare pre/post observations, use particular
windows, collect particular modalities, or perform a focused-query stage. The scope tool returns
timestamp units, source coverage, incident metadata, and metric identities, not recommended
five-minute windows. In the prepared track, tools such as `compare_metrics` advertise capabilities equally to both
conditions; they do not have to be used. Actual retrieved evidence can differ because choosing
what to retrieve is part of the measured behavior.

The shared interface is host-mediated JSON, not native model-callable MCP tools. Each invocation
returns exactly one versioned envelope: `evidence_request`, `final`, or `blocked`. The envelope must
be the invocation's sole CLI `final_answer` message and its last public assistant message.
Optional `commentary` messages may precede it but must not contain envelopes. The host supplies
the exact case and invocation identity. Raw JSON and JSON code fences are equivalent; the host
checks all public assistant messages, not only the last. Missing or unknown phases, envelopes in
commentary, multiple authoritative envelopes, missing identities, malformed fields, and conflicting
request/final messages are explicit protocol failures, never implicit final answers.

An `evidence_request` ends the current CLI invocation, not the investigation. The host cannot
execute the requested calls until that process returns. After validating and executing the batch,
it resumes the same session with results. The model must not emit a second envelope or declare
evidence unavailable merely because results have not arrived before the request handoff.
Execution, redaction validation, and scoring use the same phase-aware decoder.

Both conditions receive complete `evidence_request`, `final`, and `blocked` JSON envelope
examples serialized from objects with `JSON.stringify`. The examples carry the current case and
invocation identity; only skilled report examples include `finding`. Tool, operation, parameters,
expiry, and narrative placeholders must be replaced with actual values. The examples demonstrate
transport shape without prescribing a retrieval sequence or diagnostic outcome. Regression tests
extract the published examples and validate each through the production message and CLI decoders,
including rejection of an extra trailing closing brace. Populated evidence-request examples also
pass through the host's approval validation, simulated ledger, and deterministic fixture execution.
This is prompt guidance, not generation-time JSON-schema enforcement. JSONL CLI output does not
constrain the model's JSON. A sole `final_answer` envelope with malformed JSON or invalid field
placement (`invalid-json` or `invalid-fields`) can receive one explicit format-correction turn
in the same session. Its message type must be unambiguous: `evidence_request`, `final`, or `blocked`.
The host retains the rejected text and capture, records a `format_error` audit turn and its hash,
and asks for the same intended message with corrected syntax or field placement and the next
invocation identity. It does not append braces, move fields, or accept a malformed message.
The replacement must preserve the message type. A report correction cannot request evidence;
an evidence-request correction requires fresh exact approval, current expiry, and all normal
target, scope, parameter, and budget checks before any call executes. After a corrected request,
the investigation continues normally. The single correction allowance is shared across syntax
and field errors; a second rejection or an exhausted turn budget fails the session.
Identity, authority, phase, size, approval, and execution violations remain fatal.
The scorer replays both the rejection and replacement from stored captures. Trial results retain
`recovery.formatErrors` and `recovery.queryErrors`; report tables expose both rejection counts,
including on failed sessions. A valid corrected message is not evidence that the first answer was
valid or that the correction preserved every diagnostic claim or requested parameter; human review
can compare both texts.

An evidence request contains exact `approvalRequests`; the host validates the complete batch's
tool names, operations, scope, call counts, and expiries before any call executes.
Each approved call then validates its parameters against the same schema advertised to the model,
plus shared cross-field rules, before accessing any evidence source. Direct tool execution and
MCP calls enforce that same request contract.
Each request must copy `scope: "current neutral case only"`, `maximumCallCount: 1`, and
`expectedRisk: "read-only bounded fixture evidence"` for prepared queries, or
`expectedRisk: "bounded isolated raw-file analysis"` for raw tools, exactly. Scope and risk are fixed policy
values, not free-form descriptions; time windows, service filters, row limits, and other query
bounds belong in `parameters` according to the chosen tool schema. The prompt, examples,
execution validator, and scorer share these policy values. Scope and risk mismatches identify
the failing field explicitly without relaxing the boundary or retrying the model.
Every call receives a host-generated request ID linking the accepted message, approval ledger,
execution trace, and result. The host simulates approval and returns complete result envelopes
without suggesting the next diagnostic step. Results retain byte counts, hashes, row counts,
coverage, truncation, and partial-execution metadata. This interface and safety policy are shared
scaffolding, not an unrestricted chat baseline.

Modalities absent from the source-coverage inventory return `availability: "unavailable"` and
an `availabilityReason`, with `empty: true` and `sourceComplete: false`. This is a delivered
evidence result, not a technical session failure. Malformed coverage, unreadable stores, and
missing stores for advertised modalities remain explicit execution errors.

Every query window is limited to 3,600 seconds (3,600,000 milliseconds). Metrics and logs use
epoch seconds; traces use epoch milliseconds. Baseline and post-onset windows are bounded
separately and must use matching units. Timestamp inputs are finite epoch numbers or numeric
strings, not date strings or blank text. Optional filters must contain a non-whitespace character.
Tool descriptions and parameter schemas advertise the constraints used at runtime.
Approved schema violations return an explicit `error` with `code: "invalid-tool-parameters"`;
invalid window ordering, non-finite numeric strings, or mixed units return
`code: "invalid-time-window"`. An overlong window returns `code: "time-window-too-large"`.
Every request rejection includes `evidenceReturned: false`. Its trace has
`status: "query-error"` and its approval is consumed;
the failed query counts against the evidence-call budget but is not successful evidence.
Other independently approved calls in the batch still run. The model may request a corrected,
newly approved query within the existing budgets or report the gap; the host never narrows or
reissues a query itself. Scoring recomputes the rejection using the same request contract and
exact approved parameters before accepting its audit. Unknown tools, operation or scope
mismatches, authorization failures, cursor case/query checksum mismatches, malformed stores,
I/O errors, and unknown runtime exceptions still terminate the session.

`search_logs` and `summarize_traces` return complete rows in deterministic store order, bounded
by both the requested row limit and the serialized UTF-8 byte limit. `pageComplete` describes
completion of the matching query, independently of source coverage in `sourceComplete`.
When more rows remain, `nextCursor` permits a new, separately approved call using the same tool
and exact query parameters plus `cursor`. Cursors are bound to their query and case; they are
not authorization. Each page consumes the same shared evidence-call and model-turn budgets.
The model chooses whether to request additional pages; the host never retrieves them automatically.
Trace `groups` have `summaryScope: "page"` and summarize only that page's representative rows.
An individual row that cannot fit returns explicit `nonProgress` and `oversizedRow` metadata
rather than a clipped row, a silently skipped match, or a cursor that repeats without progress.
Raw JSONL pages are bounded against the complete serialized UTF-8 result, including nested
indentation and continuation metadata. Page boundaries may fall below the requested row limit.
If even one complete row cannot fit, `oversizedRow.requiredResultBytes` measures its complete
result envelope. The host delivers this bounded non-progress result without aborting the
investigation; fewer columns or a narrower query require a new exact approval and consume
the existing budgets. Authorization failures, corrupt data, and unexpected tool errors remain fatal.

A final or blocked envelope contains structured candidate fields, explicit simulated-authority
flags, limitations, and the complete human-readable narrative. A null candidate target explicitly
abstains. Skilled reports additionally retain a separate structured finding (Set A) and the
skill's narrative sections. Machine diagnosis does not depend on Markdown headings or exact
disclaimer wording; narrative workflow conformance remains a separate check. Missing diagnostic
fields are protocol failures, not abstentions. A blocked outcome requires a reason and abstention.
Both skilled `final` and `blocked` reports require `report.finding`; a blocked report must use
`{"status":"not-established","target":null,"mechanism":null}`. A finding described only in the
narrative does not satisfy this field. Baseline reports must omit `finding`.
Skilled `final` and `blocked` examples also provide the eight canonical numbered narrative
headings. Set A and Set B belong under `1. Status and Finding`, followed by the skill's warning.
The scorer and scaffold share the same heading list; a failed heading check identifies the
missing titles. This does not relax the gate or replace the required section content with
headings alone. The baseline receives no skilled narrative scaffold.
A model can finish without tools or after any evidence batch. The single format-correction
opportunity consumes a model turn, usage, and wall time within the existing limits. No failed
session is retried automatically, and historical responses or scores are never repaired.

Each session allows at most eight model turns and 24 evidence calls, with a 240-second per-turn
timeout and a 15-minute investigation wall-time budget. Debug sessions retain a 100-AI-credit
cutoff. Production sessions share a 6,000-AI-credit allowance across all rounds and both
conditions, rather than dividing it into equal per-session caps. Each session receives at most
the remaining whole-credit allowance. Accounting includes failed sessions and finalization, using each session's latest
cumulative usage once. Missing accounting prevents further production execution.

These are monitored cutoffs, not hard billing caps: usage arrives after a response, which can
cross a cutoff before the host detects it. A depleted run stops before another session starts.
At the [published Copilot rate](https://github.com/features/copilot/plans) of $0.01 per AI credit,
6,000 credits represent $60 of consumption, not necessarily $60 of additional billing.
Production budget changes require a fresh run; historical results remain frozen.
The `ad-hoc-v12` protocol retains the selected session cutoff and replays its enforcement.
Each tool result is bounded to 64 KiB, a complete delivered evidence batch to 256 KiB, and each
public assistant message to 256 KiB of UTF-8. Complete prompts are bounded to 512 KiB, CLI stdout
to 10 MiB, and CLI stderr to 64 KiB. The larger stdout allowance covers JSONL event wrappers,
streaming deltas, and echoed inputs; it is not a larger assistant-message or model-context budget.
The host parses events incrementally and checks public-message bytes independently, including
accumulated deltas per message. It retains the bounded raw audit and still requires a complete
final-answer event; deltas cannot substitute for an authoritative envelope.
An exceeded stream or message limit stops the producer and marks the capture incomplete.
Execution and scoring reject stopped captures even if they contain an otherwise valid envelope.
Retained evidence is never silently clipped or presented as complete delivery. Requests must
also fit the shared batch and prompt budgets; individual result limits do not reserve space for
an arbitrarily large batch. Batch `complete` records that every requested call has an outcome
(including explicit query rejections), not that every call returned evidence, while
`delivery.status` distinguishes ready, partial, and oversized payloads.
Selected-message hashes are computed against redacted stored payloads. Continuation validates
persisted result identities, profiles, and terminal outcomes before starting another model call.
Raw results, hashes, per-turn responses, cumulative usage captures, and exact approvals are
retained. A completed model session does not mean a causally complete RCA.

## Prerequisites

* Node.js 24 and dependencies restored with `npm ci`
* Network access to the pinned Hugging Face revision for preparation
* Copilot CLI supporting `skill list --json`, `plugin list --json`, and the enforced isolation flags
* GitHub Copilot authentication available through an environment token or credential provider
  that works with a fresh CLI home; the harness does not copy stored login files
* The selected model: `gpt-5.6-luna` for debug or `gpt-5.6-sol` for production evaluation,
  both with `medium` reasoning effort and the `default` context tier
* A human reviewer for diagnostic compatibility and final CR-16 assessment

The harness fails closed before model execution if the exact model profile is unavailable,
source provenance changes, an input is malformed, or a blindness check fails.

## Commands

Use a new ID following the [run ID naming convention](#run-id-naming) for preparation,
then reuse that exact ID for execution:

```powershell
npm run rca-eval:prepare -- --run-id <run-id>
npm run test:rca-eval
npm run ci:rca-eval -- --run-id <run-id> --round 1
```

### Report generation mode

The default `--report-output prompt` retains prompt-only report formatting. To constrain only
final report generation, start a fresh run with:

```powershell
node scripts\evals\rca-real-world\run-cli.mts --run-id <new-run-id> --round 1 --profile debug --report-output schema
```

Schema mode uses one installed headless-runtime session per investigation. Evidence-request
messages and host-delivered tool results are not schema-constrained. When ready, the model
returns a small `report_ready` envelope with outcome `final` or `blocked`, not the report.
The next send in the same session constrains the complete final envelope, including invocation
identity and the condition-specific report shape. Existing validation and exact approvals remain
mandatory. No evidence collection is allowed after readiness, and there is no prompt-only fallback.

Readiness and finalization both count toward the existing eight-turn limit. The host stops
evidence requests that would consume the reserved finalization turn. Runtime cumulative usage
includes finalization, and audit replay checks the session identity, outbound schema fingerprint,
selected message, usage snapshots, and terminal outcome. Missing or incomplete usage is a failure.

Output mode is immutable in the manifest and inherited on continuation. Both conditions use
the same mode. To disable schema generation, start a different run with `--report-output prompt`;
do not switch modes in an existing run. Models without advertised schema support fail explicitly.
See [schema finalization checks](SCHEMA-FINALIZATION.md) for the synthetic test and its limits.

### Debug and production profiles

On a new interactive run, choose:

* `a) Debug run with gpt-5.6-luna (default)`
* `b) Production evaluation run with gpt-5.6-sol`

Noninteractive runs default to debug. To choose explicitly:

```powershell
npm run ci:rca-eval -- --run-id <debug-run-id> --round 1 --profile debug
npm run ci:rca-eval -- --run-id <production-run-id> --round 1 --profile production
```

Production means benchmark evaluation, not access to a production incident or production
authorization. Both profiles use the same host, tools, safety policy, and model settings other
than model identity. Debug output is for harness development, not skill-efficacy evidence.
Profile, model, and protocol are persisted and cannot change within a run; continuation inherits
the recorded profile without prompting. Reports reject mixed profiles, models, or protocols.
Switching from debug to production requires a new run ID and separately authorized execution.

PR validation runs `npm run test:rca-eval` in the required `RCA Harness Tests` job on every
workflow run, without path filtering. These deterministic tests use fixtures and simulated
responses with Node's built-in test runner; they require no dependency installation, model
credentials, external dataset download, or inference budget.

The model-backed command is CI-owned because it uses external data, credentials, and model budget.
It is not invoked by PR validation or another workflow. Run it separately only after confirming
the evaluation scope, budget, and trial cadence.
The report command defaults to today's UTC date; use `--date YYYY-MM-DD` to specify another date.

## Condition selection and scoring

Noninteractive execution defaults to both conditions. In a terminal, a new run asks whether to
run both (the default), only `with-skill`, or only `without-skill`. Use `--interactive` to require
terminal selection, or specify `--conditions` to choose explicitly without prompting:

```powershell
npm run ci:rca-eval -- --run-id <run-id> --round 1 --conditions both
npm run ci:rca-eval -- --run-id <run-id> --round 1 --conditions with-skill
npm run ci:rca-eval -- --run-id <run-id> --round 1 --conditions without-skill
```

The selection is recorded in the immutable run manifest. Later rounds reuse it without asking;
an explicit conflicting selection is rejected before any session starts. Each round runs all five
cases with skills first, then all five without skills, in case-number order within each condition.
Single-condition runs retain the same round and case order. Schema version `2.0.0` requires a new run ID; do not resume
or rescore historical single-condition artifacts with the new session layout.

The shared task requests comparable diagnostic fields without prescribing a diagnostic method:
candidate service, candidate mechanism, and working confidence with a brief reason.
The baseline reports one best diagnostic guess: candidate service, candidate mechanism, working
confidence with a brief reason, and free-form evidence, uncertainty, alternatives, and limitations.
The candidate is its strongest overall diagnosis, not a weaker alternative to a separate finding.
It may report `No defensible candidate` when the evidence cannot identify one. Both conditions use
the same held-out service and mechanism extraction for this shared endpoint (Set B). The baseline is not required to
produce the skill's eight sections, hypothesis ledger, completion gate, statistical-companion
phrasing, or human-sign-off workflow. Skill-only gates are recorded as `not-applicable`, not
failed or passed; safety, fixture-approval, integrity, and the condition's output-format checks
still apply.

The skill-free baseline is not an unprompted raw-model response. It receives the shared minimal
answer schema, tool interface, resource limits, and safety policy, but no RCA skills or Set A/Set B instructions.
The scorer maps its single best guess to Set B. Set A is not requested or scored for the baseline;
reports mark its Set A cells `N/A (not requested)` and do not compute paired Set A differences.

Set B service match is the declared primary shared diagnostic endpoint: it compares the skill's
leading hypothesis with the baseline's best guess without requiring skill completion.
Set A remains a skilled-only finding-authority endpoint, not a shared accuracy metric. Mechanism scores
remain in each trial result; compatibility and unsupported claims require human adjudication.

Earlier runs used prescribed scope, pre/post-comparison, and focused-query stages; some also
requested a two-category baseline. Those saved outputs do not establish ad hoc performance.
Start a new run ID for `ad-hoc-v12`; continuation of older protocols, including `ad-hoc-v10`, is rejected. The immutable
input fingerprint also rejects changed prompts or scoring. Preserve prior evidence and do not
pool old and new protocols, or debug and production results, as one experiment.

The simulated-authority gate checks the validated authority fields against the separate fixture
ledger and correlated execution traces. Self-reported flags do not replace exact approval
enforcement, and human-readable text cannot grant production authority.

Reports separate sessions, failures, outcomes, and costs by condition. Matched comparisons use
one row per case and trial with three results side by side: the unskilled best guess, skilled
Set A, and skilled Set B. The skilled output retains both sets; only the unskilled output has
a single guess. An unassessed Set A finding is shown explicitly, not hidden or relabeled as an
incorrect guess. Aborted or invalid sessions show unavailable results, and missing sessions
show `Not run`.

Matched service-difference calculations use
the same case and trial, exclude pairs with an incomplete or integrity-failed session, and show
the exclusion count. They report skill-only and baseline-only matches and the observed
percentage-point difference. Unassessed diagnoses and abstentions are not matches. A
single-condition run cannot produce a skill-lift estimate.

The experiment measures incremental value of the skill within an otherwise shared, bounded
ad hoc tool interface, not unrestricted production autonomy. Both conditions have equal access
to the underlying evidence, not necessarily identical retrieved observations. No additional
evaluation or significance claim follows from five selected cases.
The historical committed evidence predates this paired protocol and is not a baseline comparison.

## Trial cadence and checkpoint

Before starting an evaluation, the coordinating person or agent must ask:

> Would you like to pause after round 1 to review the results and approve continuation, or run
> all three rounds without that review pause?

Record the user's choice in the evaluation run notes before execution. Do not infer permission
to run all three rounds from a missing response.

* If the user chooses a pause, run the selected trial-1 sessions, present their results, and wait for
  explicit approval before starting any trial-2 or trial-3 session.
* If the user chooses all three rounds, run rounds 1, 2, and 3 in order without asking again at
  the round-one review checkpoint, provided the automated continuation checks pass.

Each round contains one isolated trial per case and selected condition. The default paired run
has 10 sessions per round and 30 across all three rounds; selecting one condition gives 5 and 15,
respectively. Pairing therefore doubles the scheduled model sessions and budget exposure.

```text
round 1: with-skill cases 01-05, then without-skill cases 01-05, all trial 1
automated checkpoint; human review and approval only if the user chose a pause
round 2: with-skill cases 01-05, then without-skill cases 01-05, all trial 2
round 3: with-skill cases 01-05, then without-skill cases 01-05, all trial 3
```

The CLI executes one round per invocation using `--round 1`, `--round 2`, or `--round 3`.
The coordinating person or agent owns the upfront question, choice recording, and any requested
review pause; the CLI does not prompt for or enforce that human approval. Invoke the later
rounds only when the selected cadence permits them.

The checkpoint's automatically computed `decision` reports whether machine checks permit
continuation, not whether a human reviewed or approved the results. A `pause` decision blocks
later rounds for both conditions in either cadence. A `continue` decision does not replace human approval when the
user requested the review pause. A failed session remains a result and is never retried
automatically. Diagnostic compatibility, unsupported claims, and final CR-16 assessment still
require human review even when all three rounds were authorized upfront.

### Consecutive technical failures

After two consecutive sessions abort on a technical or execution-protocol error, the CLI stops
before the next session, persists partial scores and a `round-<n>-execution.json` checkpoint,
and exits with code 2. Process-launch, authentication, timeout, isolation, and invalid approval
errors count. A completed session resets the consecutive-failure count. The count carries across
condition and round boundaries until a completed session or an approved technical-stop continuation.
Wrong diagnoses, abstentions, and final-output scoring failures do not count as
technical aborts; they remain evaluation outcomes.

The coordinator must present the errors and ask whether to continue. Only after explicit user
approval may the same round resume its unattempted sessions:

```powershell
npm run ci:rca-eval -- --run-id <run-id> --round 1 --continue-after-technical-stop
```

Continuation verifies unchanged inputs and hashes of attempted session artifacts and scores,
records the continuation time, and starts a new consecutive-failure count. It never retries or
replaces attempted sessions. It does not override the round-one machine gate or the user's
round-one review pause. After a source repair, use a fresh run ID instead of resuming changed
inputs. A failed session remains in its original run.

Each approval-request turn supplies current host UTC time and an exact deadline 15 minutes ahead.
Expired or malformed model requests, and deadlines more than 30 minutes ahead, still fail closed.
The host never silently extends a model-requested approval.

## Evidence

Raw inputs, transcripts, tool traces, approvals, scores, and manifests are written below:

```text
.copilot-tracking/evaluations/rcaeval-three-case/<run-id>/
  sessions/with-skill/<case-id>/trial-<n>/
  sessions/without-skill/<case-id>/trial-<n>/
```

Generate local reports without starting another model session:

```powershell
npm run rca-eval:report -- --run-id <run-id>
```

Reporting renders full drafts first, then pseudonymizes supported sensitive patterns in the
assembled reports. Matches in internal traces do not block reporting and source evidence,
integrity hashes, and scores are not rewritten. Debug reports retain their `DEBUG-EVIDENCE.md`,
`DEBUG-REVIEW.md`, and `DEBUG-UPDATE.md` names. Production-profile reports now use
`LOCAL-EVIDENCE.md`, `LOCAL-REVIEW.md`, and `LOCAL-UPDATE.md` under the run directory.
The report command no longer writes tracked evidence or a publication-ready PR update.
The returned `committedReportPath` field now identifies the run-local evidence report.

Emails, supported credential forms, captured environment values, and home-path patterns receive
run-scoped HMAC-SHA-256 pseudonyms. Repeated exact values retain the same pseudonym across the
three reports and subsequent regeneration. Different runs use independently generated keys.
Case and encoding differences are not silently merged. Common percent, HTML-entity, and Unicode
escape encodings are inspected; a line with a remaining encoded match is withheld as a whole,
while the rest of the report remains available. Detection is pattern-based and does not
guarantee anonymity or cover every sensitive fact, identifier, or encoding.

Every report includes links to its full original and to the original values indexed by its
pseudonyms. Originals are retained as content-addressed text files under `restricted-reports/`;
the same folder holds the persistent `pseudonym-key` and `values/`. The `report-privacy.json`
manifest records transformation version, replacement counts, withheld lines, and separate
original/presentation hashes, without copying original values. All presentation copies are
checked before writing; masking or validation errors never fall back to presenting raw drafts.

> [!WARNING]
> These reports and reveal links are local-only, not safe to commit, publish, or redistribute.
> Access relies on existing OS file permissions, not an authenticated evidence viewer.
> Restrict the run directory to authorized investigators before generating reports.
> POSIX creation modes restrict new private files where supported; Windows access depends on
> existing ACLs. Gitignore and the `restricted-reports` name are not access controls.

Raw drafts are not printed to the terminal. Do not copy the raw folder, its key, or linked values
into chat, shared logs, or a publication bundle. Retention and disposal follow the investigation's
approved policy; no automatic deletion is performed. Retain the key while stable pseudonyms
are needed. A public report requires a separately reviewed copy without local reveal links.
Existing historical evidence files are not retroactively sanitized or removed.

The CLI runner and the retrospective sanitizer use the shared
[`redaction.mts`](../../scripts/evals/rca-real-world/redaction.mts) helper for session artifacts.
It collects the OS home directory, `HOME`, and `USERPROFILE`; the runners also supply the repository
root and exact temporary workspace. Redaction handles slash variants and JSON-escaped paths,
replaces longer paths before their parents, and retains home-pattern and credential fallbacks.
It traverses JSON values rather than editing serialized JSON syntax. Structural keys, arrays,
unaffected values, and types are preserved. Valid embedded JSON, whole JSON fences, and JSONL
captures are decoded recursively and re-encoded only when changed; malformed content is not
silently repaired. Sensitive structural keys require a separate approved schema transformation.
The sanitizer cannot infer a past temporary workspace or a different host's custom home directory;
those historical artifacts still need review before sharing.

Session artifacts record value-free `redactionManifest.notices` with category, replacement count,
and zero-based member/index location; `/json` marks decoded string content. Locations omit
data-derived keys. Both runners and the sanitizer retain notices, scoring projects them into the
result, and all three local reports disclose affected sessions and locations. Impact on downstream
verification is `unassessed`, and original-source retrieval is `unverified`; a detector match does
not prove the value was a credential. Reports with missing metadata disclose that gap.

> [!IMPORTANT]
> The current security-review policy, informed by OWASP LLM02:2025, may remove critical context
> even from the authorized RCA operator. This is not an OWASP mandate to hide data from that
> operator. No unredacted session-artifact copy is retained by this stage. Report-presentation
> reveal links restore only what reached the report, not earlier artifact redactions.
> Incomplete reports state that redaction's contribution is unassessed rather than attributing
> unrelated failures to masking. Human reviewers must assess material evidence loss and permitted
> source retrieval; masking alone does not invalidate a diagnosis.

The format-preserving redaction and disclosure contract was introduced in `ad-hoc-v7` and is
retained in `ad-hoc-v9`, which adds optional report-only schema enforcement to the bounded
envelope correction introduced in `ad-hoc-v8`. Use fresh run IDs; do not
pool or rewrite earlier protocol runs.

## Interpretation limits

* Five selected cases and their model sessions do not establish a general RCA accuracy rate.
* The prepared cases have informed harness development. Keep the newly sampled raw cohort's
  results separate and use fresh held-out cases for a stronger
  efficacy claim; debug runs on these cases establish harness behavior, not generalization.
* Fixed condition ordering can introduce temporal or order effects; conditions are not counterbalanced.
* RCAEval uses controlled fault injection on microservice testbeds.
* Fixture approvals test generic-mode approval-protocol behavior. They do not establish live
  production authorization or authenticated human approval.
* Repeated time points from one injected incident are dependent observations. In the skilled
  condition, the statistical companion must report the independent-unit test as not applicable
  or blocked rather than inventing a p-value. Baseline unsupported statistical claims remain
  subject to human review, not a skill-specific wording test.
* Diagnostic compatibility, unsupported claims, CR-16 satisfaction, and issue closure remain
  human decisions.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
