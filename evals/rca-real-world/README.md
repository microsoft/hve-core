---
title: RCAEval real-world RCA evaluation
description: Compare skilled and skill-free RCA on five blinded RCAEval cases with bounded evidence tools
author: HVE Core Team
ms.date: 2026-10-29
ms.topic: reference
keywords:
  - root cause analysis
  - rcaeval
  - evaluation
  - copilot sdk
  - blinded testing
---

<!-- cspell:ignore diskio -->

This evaluation compares the root-cause-analysis skill with a skill-free baseline on five
controlled RCAEval fault-injection cases. Both conditions run by default, using the same selected
model profile, cases, evidence-tool contracts, turn limits, timeouts, and credit limits. Workflow
conformance is measured separately from held-out diagnostic results. The selected cases do not
represent organic production incidents or a statistically representative benchmark.

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

* `model-visible/` contains neutrally named incident metadata and deterministic evidence stores.
* `scorer-only/` contains source provenance, hashes, and held-out service and fault labels.

The `ad-hoc-v3` protocol compares two ad hoc investigations in the same Copilot CLI host.
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
five-minute windows. Tools such as `compare_metrics` advertise capabilities equally to both
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

An evidence request contains exact `approvalRequests`; the host validates the complete batch's
tool names, operations, parameter schemas, scope, call counts, and expiries before execution.
Every call receives a host-generated request ID linking the accepted message, approval ledger,
execution trace, and result. The host simulates approval and returns complete result envelopes
without suggesting the next diagnostic step. Results retain byte counts, hashes, row counts,
coverage, truncation, and partial-execution metadata. This interface and safety policy are shared
scaffolding, not an unrestricted chat baseline.

A final or blocked envelope contains structured candidate fields, explicit simulated-authority
flags, limitations, and the complete human-readable narrative. A null candidate target explicitly
abstains. Skilled reports additionally retain a separate structured finding (Set A) and the
skill's narrative sections. Machine diagnosis does not depend on Markdown headings or exact
disclaimer wording; narrative workflow conformance remains a separate check. Missing diagnostic
fields are protocol failures, not abstentions. A blocked outcome requires a reason and abstention.
Both skilled `final` and `blocked` reports require `report.finding`; a blocked report must use
`{"status":"not-established","target":null,"mechanism":null}`. A finding described only in the
narrative does not satisfy this field. Baseline reports must omit `finding`.
A model can finish without tools or after any evidence batch. No protocol repair makes a model
call or retries a failed session automatically.

Each session allows at most eight model turns and 24 evidence calls, with a 240-second per-turn
timeout, a 15-minute investigation wall-time budget, and the CLI's 100-credit session limit.
Each tool result is bounded to 64 KiB, a complete delivered evidence batch to 256 KiB, and each
public assistant message to 256 KiB of UTF-8. Complete prompts are bounded to 512 KiB, CLI stdout
to 1 MiB, and CLI stderr to 64 KiB. Oversized content fails explicitly; a stopped CLI capture is
marked incomplete, and retained evidence is never silently clipped or presented as complete
delivery. Batch `complete` records execution completeness, while `delivery.status` distinguishes
ready, partial, and oversized payloads.
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

```powershell
npm run rca-eval:prepare -- --run-id <run-id>
npm run test:rca-eval
npm run ci:rca-eval -- --run-id <run-id> --round 1
```

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
Start a new run ID for `ad-hoc-v3`; continuation of older protocols, including `ad-hoc-v2`, is rejected. The immutable
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

The committed `PR-3136-EVIDENCE.md` report contains only sanitized outcomes, immutable input and
artifact hashes, commands, limitations, and human-review status. It excludes raw telemetry,
credentials, host paths, personal data, and unredacted tool payloads.

The CLI runner and the retrospective sanitizer use the shared
[`redaction.mts`](../../scripts/evals/rca-real-world/redaction.mts) helper for session artifacts.
It collects the OS home directory, `HOME`, and `USERPROFILE`; the runners also supply the repository
root and exact temporary workspace. Redaction handles slash variants and JSON-escaped paths,
replaces longer paths before their parents, and retains home-pattern and credential fallbacks.
The sanitizer cannot infer a past temporary workspace or a different host's custom home directory;
those historical artifacts still need review before sharing.

## Interpretation limits

* Five selected cases and their model sessions do not establish a general RCA accuracy rate.
* These five cases have informed harness development. Use fresh held-out cases for a stronger
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
