---
title: Dangerous Workflow Detection
description: How the hybrid dangerous-workflow control combines a homegrown template-injection gate with the Poutine supply-chain scanner for GitHub Actions workflows
sidebar_position: 6
author: Microsoft
ms.date: 2026-07-01
ms.topic: reference
keywords:
  - security
  - github actions
  - workflow
  - pull_request_target
  - workflow_run
  - poutine
estimated_reading_time: 4
---

## Overview

This page documents the defensive CI control that guards against risky GitHub Actions
workflow patterns before merge. The control is a hybrid of two complementary parts:

* A **homegrown template-injection gate** that runs in PR validation as a fast, deterministic,
  offline **blocking** check and surfaces findings in the Security tab as SARIF.
* The **Poutine** supply-chain scanner, which runs as a broad **advisory** scanner in CI and
  uploads its findings to the Security tab as SARIF without blocking merge.

## The homegrown gate (blocking)

The homegrown check enforces a single, high-signal rule:

* `dangerous-workflow/template-injection`
  * Triggered when attacker-controllable GitHub event values are interpolated directly into
    `run:` or `github-script` code execution contexts.
    The narrowed scope covers free-text and ref fields such as `github.event.pull_request.title`,
    `github.event.pull_request.body`, `github.event.pull_request.head.ref`,
    `github.event.pull_request.head.label`, `github.event.issue.title`, `github.event.issue.body`,
    `github.event.comment.body`, `github.event.review.body`, `github.event.review_comment.body`,
    `github.event.discussion.title`, `github.event.discussion.body`, `github.event.head_commit.message`,
    `github.event.head_commit.author.*`, `github.event.commits[*].message`,
    `github.event.commits[*].author.*`, `github.event.workflow_run.head_branch`,
    `github.event.workflow_run.display_title`, `github.event.pages[*].page_name`, and `github.head_ref`.
  * Indirect derivations through `steps.*`, `needs.*`, and `env.*` are intentionally out of scope
    to keep the rule deterministic and low-noise.

This gate is PowerShell-native, has no runtime dependencies, and runs offline as part of
`npm run lint:all`.

## Broad coverage via Poutine (advisory)

Broader dangerous-workflow coverage is delegated to [Poutine](https://github.com/boostsecurityio/poutine),
an Apache-2.0 supply-chain scanner maintained by BoostSecurity. Poutine runs in CI and reports a
wider class of issues as advisory SARIF, including:

* Untrusted checkout / arbitrary code execution from untrusted code changes (`untrusted_checkout_exec`).
* Template injection across a broader surface than the homegrown gate.
* Unpinned or unverified third-party actions.
* Pull-request jobs running on self-hosted runners.
* Known vulnerabilities in build-platform components.

Poutine findings appear in the Security tab under the `poutine` category. They are **advisory**
and do not block merge; the homegrown template-injection gate is the only required check.

## Scope and limitations

The split is deliberate:

* The homegrown gate stays narrow, deterministic, and offline so it can block with near-zero
  false positives.
* Poutine provides breadth and is maintained upstream, but runs advisory to avoid a noisy hard gate.
* The `# poutine:ignore untrusted_checkout_exec` marker is honored by Poutine to acknowledge
  reviewed checkout exceptions. It does not affect the homegrown template-injection gate.
* Taint-based expansion of the injection rule (indirect derivations) remains tracked as follow-on work.

## Why this exists

This control closes a pre-merge gap. OpenSSF Scorecard can report dangerous workflow findings, but
it only runs on the default branch, so a risky workflow can reach the PR branch and merge before the
repository sees the issue. The homegrown gate brings a deterministic blocking signal into PR
validation, and Poutine adds broad supply-chain coverage on top.

## Run it locally

Run the homegrown gate:

```bash
npm run lint:dangerous-workflow
```

The command scans `.github/workflows` and writes results to the local logs directory. Poutine is a
CI-only scanner and is not part of the offline lint pipeline.

## Suppression

Use the suppression marker only when a checkout is genuinely trusted and the exception has been
reviewed. The marker is recognized by Poutine on the checkout step line itself or on the immediately
preceding line:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4 # poutine:ignore untrusted_checkout_exec
        with:
          ref: ${{ github.ref }}
```

Advisory Poutine findings can also be acknowledged in `.poutine.yml` by rule, path, or level once
triaged.

Use this only for a legitimate trusted checkout. Review expectations:

* The checkout target must be a trusted constant or otherwise intentionally approved.
* The comment should be added only after a human review confirms that the workflow truly needs the exception.
* Suppressions should be temporary and removed when the workflow is refactored to a safer pattern.

## Triage flow

When the workflow fails, review the finding in the Security tab and resolve it in the workflow file:

1. Open the failing check and read the SARIF finding for the affected workflow and line. Findings use the stable rule IDs `dangerous-workflow/untrusted-checkout` and `dangerous-workflow/template-injection`, both emitted at `level: error`.
2. Confirm whether the workflow is running in a privileged context such as `pull_request_target` or `workflow_run`.
3. If the checkout is unsafe, move to a trusted ref or remove the privileged trigger.
4. If a `run:` or script block interpolates an untrusted event value, replace the interpolation with a trusted value or restructure the workflow so the untrusted payload is never executed as code.
5. Use the file path, job/step, and line information in the finding to navigate directly to the offending workflow block, then re-run `npm run lint:dangerous-workflow` and re-check the PR validation status.

## Related documentation

* [Security Documentation](README)
* [Branch Protection](branch-protection)
* [Dependency Pinning](dependency-pinning)

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
