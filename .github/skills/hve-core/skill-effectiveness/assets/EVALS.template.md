---
description: "Publisher notes template for one supervised baseline-versus-with-skill evaluation"
---

# `<Task>`: Evaluation

Notes adapted from the [Microsoft HVE Core evaluation-notes template](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/skill-effectiveness/assets/EVALS.template.md),
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Retain the accompanying `NOTICE` and record changes to copied template material.
This attribution does not assign a license to independently authored findings
or other evaluation inputs and outputs.

## Task And Skill Fit

<Who needs this work, what is requested, and why might the skill help?
Explain what a capable baseline may already do and which connected capabilities
could add useful value. State the important untested scope.>

<State the publisher's claimed benefit and why it matters to the user.>

## Fair Comparison

<Link the public task, original pinned inputs, focus skill, native eval and
experiment blocks. Both arms have identical conditions except the focus skill.
Disclose any source/task reuse and required output/checker interfaces.>

<For repository intake, record the canonical policy's resolved URL, full commit
revision and activation date before source inspection. Missing activation blocks
intake. For an existing-skill-only route, record Not applicable with a reason.>

## Evidence

Complete this compact decision table for each distinct benefit claim before
inspecting outputs. Keep detailed rubrics in the native eval rather than
duplicating them here. Use `Unknown` for missing evidence, not a pass;
`Not applicable` requires a scope-specific rationale.

| Decision             | Record                                                                                                         |
|----------------------|----------------------------------------------------------------------------------------------------------------|
| Claim                | `<The user benefit this comparison can test>`                                                                  |
| Affected users       | `<Who needs that benefit and in which task context>`                                                           |
| Method               | `<Executable check, source-grounded assessment, image or human review; what it can decide versus only inform>` |
| Sources              | `<Pinned original inputs, skill guidance and exact evidence locations>`                                        |
| Good / poor outcomes | `<A useful result and a materially weaker but plausible result>`                                               |
| Valid alternatives   | `<Other acceptable solutions; allow ties and regressions>`                                                     |
| Unknowns             | `<Missing evidence, untested behavior and limitations>`                                                        |
| Approval             | `<Pending, or the operator's explicit approved scope and limits; link the Run section>`                        |
| Not applicable       | `<Excluded request or method and its rationale, or None>`                                                      |

For accessibility claims, use the canonical method selection in
[visual review](../references/visual-review.md#match-the-method-to-the-claim).
Screenshots decide visible properties only; untested nonvisual behavior stays
unknown. Human visual review is an alternative, not nonvisual conformance evidence.

<If both candidates deliver valid outputs, what evidence would let the publisher
decide whether the skill helped? Could a materially worse but valid output pass
every automated check? If so, specify the concrete output review needed.
Separate delivery checks from benefit assessment, unless delivery is the benefit.
A reasoned publisher preference is valid when explained; allow ties and valid
alternatives. Do not require an automatic quality score.>

<For holistic review, select a short set of observable skill-derived guidelines
and record their source before inspecting outputs. Apply them equally to both
independent reviews, separately from task quality. Do not provide them to the
baseline candidate. Record practices it already demonstrates without the skill.>

<Record the public fixtures path and identical disclosed output contract for both
arms; the separate reviewed-original grading tree, digests, checker entry point,
interpreter and grader-only locked dependencies; and the approved one-submission
saved-review inputs. Keep these notes, private checks, review machinery and role
maps out of candidate staging. Preserve complete focus skills and their public
tools. Record protected executed bytes and immediate pre-use authentication
separately from before/after hashes. Missing runtime
verification blocks execution rather than being inferred from staging YAML.>

<Record candidate and offline-grader toolchains separately. If candidates use
Node/Python but Jupyter execution or browser rendering happens only in protected
offline grading, record approval for that capability change and disclose the
same self-test limitation to both arms before collection. Pin the original
prompts and the changed tool disclosures separately. Retain the full executable
and visual evidence; do not label file-only collection as executed results.>

<Record the selected platform runtime path, child-environment handling,
clientMode (omitted default or explicit empty), private runtime-state location,
the controlled actual workspace/OS context when empty mode is selected,
and actual
executionProfile (absent or windows-native), absolute readonly/denied path lists,
normal-login status and observed sandbox support/enforcement. Do not include
credentials. The optional Windows profile does not qualify the offline grader
or arbitrary Python/browser tasks.
For repository tasks, qualify the complete staged checkout in both arms.
Retain raw instruction-source responses from startup diagnostics; an empty
synthetic fixture does not cover nested repository instruction discovery.
For Linux rendering, record the image identity, browser version, seccomp source
revision/hash and approved syscall delta; retain observed renderer namespace/
seccomp status and decoded actual Mermaid images. Do not infer native export
or immutable submission binding from a standalone browser smoke test.
Record the actual
custom-instruction inventory and requested versus offered tools. Both arms
request the same tool list, including native skill when used. Disclose the
runtime's conditional omission of skill in an arm without skills. Verify actual
model-facing treatment availability and activation, not just registration.
Test legitimate directory listing, reads and delivery writes as well as denied
operations. Use canonical paths, keep private content outside listing scope and
avoid recursive workspace grants. Synthetic native lifecycle results establish
mechanics only; identify the tested source revision and retained evidence.>

For each separate offline grade, retain this linkage in these existing notes:

* Original native results file and SHA-256; exact selected original record and
  its digest; native run/item/variant/stimulus/trial/shard and trajectory/session
  identities, original eval/config hashes. Keep all failed/skipped/retried attempts.
* Completed host-owned submission snapshot origin, digest and explicit binding
  to that original record. Record export completeness and unavailable facts;
  directory existence, path names and order do not establish provenance.
* Trusted checker/dependency origin and locked closure, entry point and reviewed
  expected SHA-256; separate grade-spec/config hashes and interpreter/image
  identity. Never derive the expected digest from candidate-writable bytes.
* Exact native command, fresh scratch directory and separate new grade-output
  location/digest. Explicitly link it back to the original record and snapshot;
  new grade output does not preserve all outer variant/trial/experiment fields.

Use one original record and one snapshot per invocation, never a shared artifact
override for both arms. Do not overwrite originals or manufacture an ungraded
trajectory. A previous public pass does not suppress fresh quality grading for
successful nonnull trajectories. Error/skip/null-trajectory inputs are not proof
of fresh grading. Missing required output under an intact bound snapshot is task
failure; unavailable trusted roots/checker, integrity or startup failures are
operational errors, not measured task zero. No invented checker-body verdict,
positive subprocess exit or raw stdout/stderr when native output omits them.

<For native prompt grading, define task-specific rubric/score anchors and inspect
the selected evidence. A repo snapshot is bounded text, may omit needed sources
and can reveal condition clues. It does not automatically include other graders'
logs or original unmodified input files. For image review, name the capture and
SDK command or human procedure, and retain the actual pixels. Keep executable
results, model judgments and guideline adherence separately interpretable.>

## Run

<Candidate and judge models, pair count, order, timeouts and exact commands.
Record native experiment collection, separate per-record protected offline
grading, then optional saved-evidence online review. Verify fresh candidate homes,
sessions/workspaces and native pair identities; use native --variant selection
only if separate arm invocations are needed. Do not duplicate evals per arm or
add a collection engine. Keep execution and grading lifecycle ownership in Vally.
Verify readonly authoritative checker/submission inputs, fresh writable scratch,
denied grading egress and absence of model credentials. YAML/authentication alone
does not establish those controls or automatically validate arm binding.
Count native prompt-grader invocations and additional image reviews separately
from candidate sessions; native judge retries/reminders can add calls.
Record native overrides.runs and total candidate sessions across tasks, variants
and experiment files. Repetitions do not automatically alternate variant order.
Document local install/lint/dry-run/tests and any unexercised paths.
Record operator approval of the exact paid scope, budget and native retry/reminder
behavior, available execution/provider limits, and the risk of overspend.
Distinguish a supervised target from a required enforced maximum. Record candidate,
grader, credential and evidence-security verification separately; financial
approval cannot waive those prerequisites.
Authoring does not authorize calls. Manual reruns and expanded scope need fresh
approval. Inspect usage before the next invocation and do not start it after the
approved scope or reported-usage target is reached. This does not promise to
cancel an in-flight call or native retry. Missing or incomparable usage remains
unknown; pause for explicit continuation unless prior approval already covers
that specific bounded unknown-usage scope. These controls do not guarantee a
monetary ceiling. If the operator requires an enforced ceiling, identify its
provider/runtime control or keep paid execution blocked.>

## Publisher Iteration
<!-- cspell:ignore unblinded -->

<Use an initial pair to examine task/evidence usefulness when appropriate.
Record changes to the skill, task or assessment and link earlier outcomes.
Label tuned examples as development demonstrations and publisher inspection as
unblinded, not independent review. Before an agreed repeat batch, fix the skill,
task and assessment; run fresh candidates through native Vally.
Rejudging existing outputs is not another candidate trial.>

## Results

<Link native results and the review. Report failures, paired observations,
variation, measured usage and limitations. A narrative review is not a numeric
score. Small experiments do not establish general skill value or equivalence.>
<Address the claimed benefit directly, separately from the native aggregate.
Report all agreed trials and whether the observed difference recurred.
Distinguish a curated example from evidence on fresh tasks.>

Link Vally's actual run directory, report, raw trial records, workspaces and
session inventories. Match task/variant/trial/session identities, not file order.
Keep independent reviews alongside the native evidence. Record unavailable
evidence and exclusions explicitly; preserve all failed and incomplete attempts.

<For each native session, retain its durable operator-owned `skill-evidence-*`
directory, outside the candidate workspace: original startup JSON, independent
`startup-backups` copy and completion
verification report. Record the expected SHA-256 and the link to the original
native trial. Missing/failed verification is an operational error, not a task
score. This is supervised consistency evidence, not candidate-resistant host
attestation. Set executor.config.auditDirectory (AUDIT_DIR in the candidate
template) to an absolute, durable path disjoint from --workspace, and retain it
alongside --output-dir. Native sessionLog.rootDir is temporary; the CLI does not
export extra audit files from it.
Keep operator policy receipts and audit files out of candidate directory listings,
deliverable-only grading snapshots and
blinded review inputs. Grader/checker readonly protection, dependency provenance
and arm binding remain separate prerequisites.>

<If useful, back up only explicitly selected completed native session logs with
the recorder's `backup-log` command. Link their metadata/digests to the trial and
review for secrets before sharing. Do not copy entire session homes, assume
automatic redaction, or treat evolving log contents as immutable startup data.>

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
