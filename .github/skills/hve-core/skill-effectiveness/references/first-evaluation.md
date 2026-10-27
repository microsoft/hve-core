---
description: "First-use authoring walkthrough: a tiny public catalog task, a complete native A/B pair, and model-free validation"
---

# Author Your First A/B Evaluation

Finish with a native evaluation package and a plan showing two comparison arms.
This walkthrough does not run candidates, grade submissions or spend model
credits. It demonstrates authoring, not whether the example skill helps.

## 1. Bring Three Inputs

Install or load skill-effectiveness through your chat host, then provide:

* The complete focus-skill folder. This example uses an existing data-catalog
  skill; the agent must be able to read and copy it, including its support files.
* A small, publishable task input, such as the fictional inventory below.
* The user outcome: help colleagues understand the datasets, relationships and
  missing evidence. A readable, accurate alternative structure is acceptable.

Save this input as `inventory.json`:

```json
{
  "datasets": [
    {"name": "assets", "key": "asset_id", "owner": "Fleet", "access": "confirmed"},
    {"name": "reservations", "key": "reservation_id", "owner": null, "access": "unknown"}
  ],
  "relationships": [
    {"from": "reservations.asset_id", "to": "assets.asset_id", "confidence": "confirmed"}
  ],
  "profiles": []
}
```

The missing owner, access and profiles are intentional evidence gaps, not values
to invent. Both arms receive exactly this same input.

## 2. Ask The Agent To Author, Not Execute

Supply the actual focus-skill folder and inventory file with this request:

```text
Use skill-effectiveness to prepare my first A/B package in a new
catalog-study folder outside the authoring skill.

Focus skill: the complete data-catalog folder I supplied.
Public input: inventory.json.
Task: produce a readable catalog explaining the datasets, their relationship,
and what evidence or access is missing. Choose an appropriate structure.
Required output: deliverable/catalog.md.

Use the same task, model, inputs, tools, limits and checks in both arms.
Give only treatment the complete focus skill. Start with one pair and no
shared skills. Use the shipped native templates and unchanged dependency pins.
Plan human comparison of accuracy, usefulness and honest gaps separately
from the public delivery checks.

Copy the runtime helpers, LICENSE, NOTICE and registry configuration using
the skill's copy map. Prepare evaluation notes and the package's own canonical
public-registry lockfile. Validate native syntax and inspect the dry-run plan.
Keep the no-grants session policy until a runtime is separately qualified.
Do not start candidates, model reviews, runtime-startup probes or containers.
If a required input or dependency-resolution environment is unavailable,
report that gap rather than fetching private sources or changing pins.
```

The agent should clarify any missing input rather than depend on an earlier
conversation. For repository-derived skills, complete
[repository intake](repository-intake.md) first; do not add extraction to this
existing-skill example.

## 3. Inspect The Authored Files

Expect this shape, with the complete skill and all four copied runtime helpers:

```text
catalog-study/
  package.json
  package-lock.json
  .npmrc
  LICENSE
  NOTICE
  EVALS.md
  evals/catalog.eval.yaml
  experiments/catalog.experiment.yaml
  fixtures/catalog/public/inventory.json
  skills/data-catalog/SKILL.md
  skills/data-catalog/...
  scripts/native-inventory.mjs
  scripts/restricted-copilot-executor.mjs
  scripts/native-windows-sandbox.mjs
  scripts/review-images.mjs
```

The candidate eval should stage only the public inventory, use stimulus name
`catalog`, ask for `deliverable/catalog.md`, and check completion and that output
path. Its initial session policy has no grants; it is not ready to execute.
Keep the copied helper code and package pins unchanged.

The complete `experiments/catalog.experiment.yaml` is:

```yaml
name: first-catalog
evals:
  - ../evals/catalog.eval.yaml
vary:
  - /environment/skills
baseline: a-baseline
variants:
  a-baseline:
    environment:
      skills: []
  b-treatment:
    environment:
      skills:
        - ../skills/data-catalog
execution:
  workers: 1
overrides:
  runs: 1
```

Both variants use the same eval. Do not give baseline a less informative prompt
or treatment a different model. If shared skills are added later, list them in
both arrays. The native experiment template explains reversed pair order.

In `EVALS.md`, record the task, input and skill pins, identical conditions, and
planned review questions: are relationships accurate, are unknowns preserved,
and can a colleague use the result? A file-existence pass will not answer them.
Retain the copied notes template's attribution and identify adaptations.

## 4. Validate And Read The Plan

Use Node.js 24+ from `catalog-study`. A canonical lockfile must already exist;
do not substitute the authoring package's manifest or invent integrity hashes.
If a required new lock cannot be resolved, stop and use an approved resolution
environment. For restricted networks, apply the
[approved-registry restore instructions](experiment-method.md#restore-through-an-approved-registry)
before restoring; keep feed values out of files.

```powershell
npm ci --ignore-scripts --include=dev --no-audit --no-fund
npm run vally -- lint --strict --eval-spec evals/catalog.eval.yaml
npm run study:dry-run -- experiments/catalog.experiment.yaml --param AGENT_MODEL=mock --output-dir dry-run-plan --workspace dry-run-workspaces
```

`mock` is only a model parameter for this dry-run. It is not a provider/model
selection for real execution. Use fresh plan/output paths if repeating the check.
These commands do not install the skill into your chat host.

Lint should finish without errors. The plan should name `first-catalog`,
`a-baseline` and `b-treatment`: one task, one run and two variants mean **two
planned candidate sessions**. Baseline has no focus skill; treatment has the
complete data-catalog folder. Neither candidate has run. There is no quality
score, completed comparison or evidence of benefit yet.

## 5. Stop Before Paid Execution

You now have an authored package and an inspected comparison plan. Do not replace
dry-run with a paid command yet. Keep the no-grants policy until the selected
task/runtime, legitimate operations and denied operations are qualified.

Before any real invocation, read and apply the
[restricted execution profile](experiment-method.md#restricted-execution-profile)
and [supervised run policy](experiment-method.md#execute-an-approved-run-plan).
Agree candidate and review counts, disclosure and budget separately. If an
enforced spending ceiling is required but unavailable, stop.

After separately authorized collection, compare both saved outputs against the
same original inventory and review questions. Report ties, regressions,
delivery failures and unavailable evidence as well as improvements. Add protected
executable grading or saved-evidence model review only when the task needs it;
those methods have separate templates and qualification requirements.
