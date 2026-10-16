---
description: "Publisher notes template for one supervised baseline-versus-with-skill evaluation"
---

# <Task>: Evaluation

## Task And Skill Fit

<Who needs this work, what is requested, and why might the skill help?
Explain what a capable baseline may already do and which connected capabilities
could add useful value. State the important untested scope.>

<State the publisher's claimed benefit and why it matters to the user.>

## Fair Comparison

<Link the public task, original pinned inputs, focus skill, native eval and
experiment blocks. Both arms have identical conditions except the focus skill.
Disclose any source/task reuse and required output/checker interfaces.>

## Evidence

<Implement the evidence appropriate to the claim: executable checks, native
prompt grading, rendered-image review, or a combination. Identify what each
method establishes and what remains unmeasured. If using human review, give its
actual inputs and questions; do not substitute delivery checks for that review.
Explain good/poor outcomes and valid alternatives.
Detailed criteria are optional. State requests that remain unmeasured.
Do not duplicate complete rubrics or infer quality from formatting alone.>

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

<For native prompt grading, define task-specific rubric/score anchors and inspect
the selected evidence. A repo snapshot is bounded text, may omit needed sources
and can reveal condition clues. It does not automatically include other graders'
logs or original unmodified input files. For image review, name the capture and
SDK command or human procedure, and retain the actual pixels. Keep executable
results, model judgments and guideline adherence separately interpretable.>

## Run

<Candidate and judge models, pair count, order, timeouts, spending limits and exact commands.
Count native prompt-grader invocations and additional image reviews separately
from candidate sessions; native judge retries/reminders can add calls.
Record native overrides.runs and total candidate sessions across tasks, variants
and experiment files. Repetitions do not automatically alternate variant order.
Document local install/lint/dry-run/tests and any unexercised paths.
Record how the chosen execution/review path supplies required spending controls;
if it cannot, paid execution remains blocked. Authoring does not authorize calls.>

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

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
