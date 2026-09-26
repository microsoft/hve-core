---
title: Dangerous Workflow Detection
description: How the hybrid dangerous-workflow control combines a homegrown template-injection gate with the Poutine supply-chain scanner for GitHub Actions workflows
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-22
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

<!-- cspell:ignore githubactions -->

## Overview

This page documents the defensive CI control that guards against risky GitHub Actions
workflow patterns before merge. The control is a hybrid of two complementary parts:

* A **homegrown template-injection gate** that runs in PR validation as a fast, deterministic,
  offline **blocking** check and surfaces findings in the Security tab as SARIF.
* The **Poutine** supply-chain scanner, which runs as a broad **advisory** scanner in CI and
  uploads its findings to the Security tab as SARIF without blocking merge.

## The homegrown gate (blocking)

The homegrown check enforces one rule with two detection sources, both reported under the
same rule identifier:

* `dangerous-workflow/template-injection`
  * **Untrusted event values.** Triggered when attacker-controllable GitHub event values are
    interpolated directly into `run:` or `github-script` code execution contexts.
    The narrowed scope covers free-text and ref fields such as `github.event.pull_request.title`,
    `github.event.pull_request.body`, `github.event.pull_request.head.ref`,
    `github.event.pull_request.head.label`, `github.event.issue.title`, `github.event.issue.body`,
    `github.event.comment.body`, `github.event.review.body`, `github.event.review_comment.body`,
    `github.event.discussion.title`, `github.event.discussion.body`, `github.event.head_commit.message`,
    `github.event.head_commit.author.*`, `github.event.commits[*].message`,
    `github.event.commits[*].author.*`, `github.event.workflow_run.head_branch`,
    `github.event.workflow_run.display_title`, `github.event.pages[*].page_name`, and `github.head_ref`.
  * **Workflow inputs.** Triggered when a workflow input is interpolated directly into the same
    execution contexts. Input declarations are resolved from every trigger that declares them, so a
    `workflow_dispatch` input is treated exactly like a `workflow_call` input. Inputs declared
    `boolean` or `number` are validated by GitHub before the runner receives them and are never
    reported; a name declared by more than one trigger is exempt only when every one of its
    declarations is typed `boolean` or `number`. Compound expressions such as
    `${{ inputs.max-age-days || 30 }}` are classified on every input they reference, so
    `${{ inputs.a || inputs.b }}` is reported when either `a` or `b` is unsafe.
  * Indirect derivations through `steps.*`, `needs.*`, `matrix.*`, and `env.*` are intentionally out
    of scope to keep the rule deterministic and low-noise.

The input rule detects deviation from the safe pattern rather than attempting to prove a value is
tainted. The safe pattern is a step-level `env:` mapping read through native shell syntax:

```yaml
- name: Run validation
  env:
    INPUT_WORKING_DIRECTORY: ${{ inputs.working-directory }}
  run: |
    echo "$INPUT_WORKING_DIRECTORY"
```

The value then reaches the shell as data and is never parsed as command structure, so the control
holds without filtering the value first.

This gate is PowerShell-native, has no runtime dependencies, and runs offline as part of
`npm run validate:local`.

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

### Standing default-branch coverage

`weekly-security-maintenance.yml` calls the same reusable `dangerous-workflow-scan.yml`
every Sunday at 02:00 UTC on the default branch. Manual dispatch scans the selected ref;
select `main` when collecting a merged-state baseline. Both scanners are advisory in this
maintenance caller. The homegrown check remains blocking in PR validation.

The caller grants only `contents: read` and `security-events: write`, enabling SARIF uploads
without repository-content write access. Poutine retains its pinned action revision, the
`poutine` SARIF category, and the `poutine-results` artifact with 90-day retention.
The maintenance summary reports job execution, not a finding-free scan. Because analysis
and upload steps tolerate failures, inspect step logs and confirm that a current SARIF
artifact exists even when the job succeeds.

## Scope and limitations

The split is deliberate:

* The homegrown gate stays narrow, deterministic, and offline so it can block with near-zero
  false positives.
* Poutine provides breadth and is maintained upstream, but runs advisory to avoid a noisy hard gate.
* Reviewed Poutine exceptions are configured in `.poutine.yml` by exact rule and package URL,
  or workflow path and job where available. They do not
  affect the homegrown template-injection gate.
* Taint-based expansion of the injection rule (indirect derivations) remains tracked as follow-on work.
  CodeQL's `actions/code-injection` query models untrusted sources as `github.event.*` values, so it
  does not report workflow-input interpolation either; the homegrown input rule covers that case.
* A repository-derived value that reaches a `run:` block through a dynamic job matrix is an indirect
  derivation and is not reported here. Project discovery paths are validated separately by
  `scripts/security/Assert-WorkflowProjectDirectory.ps1` before they enter a matrix.

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

Use acknowledgments only for evidence-backed false positives or explicitly reviewed
compensating controls. For a trusted checkout, constrain the rule by path and job:

```yaml
skip:
  - rule: untrusted_checkout_exec
    path:
      - .github/workflows/example.yml
    job:
      - prepare
```

Poutine also supports skip entries by job, level, OSV ID, or package URL. Prefer the narrowest
combination that matches the reviewed finding.

For creator-list false positives, use the exact package URL with
`github_action_from_unverified_creator_used`, not an organization-wide or rule-only skip.
A Marketplace verified-creator badge establishes publisher verification, not action safety;
SHA pinning and least privilege remain necessary.

Review expectations:

* The checkout target must be a trusted constant or otherwise intentionally approved.
* The configuration entry should be added only after review confirms that the workflow needs the exception.
* Suppressions should be temporary and removed when the workflow is refactored to a safer pattern.

### Baseline dispositions

The baseline used for [issue 2983](https://github.com/microsoft/hve-core/issues/2983)
contains 12 Poutine v1.1.4 findings across three rules. Analysis `1822021547` scanned
the synthetic merge commit `8ef91813` for PR 2906. Its Git tree
`20025492a0cfb71be4dfbdd08ef52336455c7553` matches `main` commit `5e21810e` exactly.
This proves content equivalence, not execution on `refs/heads/main`; no main-ref Poutine
analysis was present in the retrieved inventory. Weekly coverage closes that scheduling
gap once deployed, but the first hosted result must still be confirmed.

* Alerts 788, 789, 601, 593, 719, and 595 identify `astral-sh/setup-uv`.
  Marketplace verifies the creator, but Poutine's static list omits it, as tracked in
  [upstream issue 452](https://github.com/boostsecurityio/poutine/issues/452).
  The exact package acknowledgment is handled by the separate setup-uv change; this
  baseline-triage change does not add it.
* Alerts 742 and 743 identify `googleapis/release-please-action` in the two release
  workflows. Its [Marketplace listing](https://github.com/marketplace/actions/release-please-action)
  verifies the creator. The acknowledgment uses only the exact rule and
  `pkg:githubactions/googleapis/release-please-action` package identity.
* Alerts 755 and 756 identify dependency execution in `prepare-publisher` within
  `extension-marketplace-publish.yml`. Preparation checks out an API-resolved `main`
  commit, verifies `HEAD` before installation, and has only `contents: read`, with no
  protected environment or marketplace credential. Publication happens in a separate
  protected job. The exception relies on the repository's protected-main trust assumption
  and is restricted to this rule, workflow, and preparation job.
* Alert 348 uses `default_permissions_on_risky_events` for `pr-review.lock.yml`.
  The generated workflow declares `permissions: {}`, which grants no scopes to jobs
  without overrides. Poutine treats the empty map as absent. The exact rule-and-path
  acknowledgment does not change job grants or the separate permissions hard gate.
* Alert 340 identifies `EndBug/label-sync`, which lacks a Marketplace verified-creator
  badge. Retain this advisory finding as accepted provenance risk, not a false positive.
  The action remains full-SHA-pinned, with job-scoped permissions and normal staleness
  monitoring. Reassess on action updates or a change in publisher verification.

These three acknowledgments target five baseline occurrences. Six setup-uv occurrences
remain the responsibility of the separate fix, and EndBug remains visible. These are
dispositions and expected filter effects, not evidence that remote alerts are resolved.

The job-level permissions opportunity from issue 2527 is already implemented by
`Test-WorkflowPermissions.ps1`: absent workflow permissions fail, jobs under populated
workflow grants need explicit permissions, and an empty workflow map grants nothing to
jobs without overrides. No further validator or generated-workflow edit is needed here.

Remove creator acknowledgments when a pinned scanner upgrade recognizes the verified
publisher without them. Remove the PR-review acknowledgment when the scanner distinguishes
empty permissions from missing permissions. Re-review or remove the marketplace exception
if the checkout source, digest checks, permissions, or credential separation changes.
Maintainers should verify each removal against hosted SARIF, not job success alone.

## Triage flow

When the required homegrown check fails, resolve the blocking `dangerous-workflow/template-injection` finding:

1. Open the failing check and read the SARIF finding for the affected workflow and line. The homegrown gate emits the stable rule ID `dangerous-workflow/template-injection` at `level: error`.
2. Locate the `run:` or `github-script` block that interpolates an untrusted event value.
3. Replace the interpolation with a trusted value, route the untrusted value through an intermediate `env:` variable, or restructure the workflow so the untrusted payload is never executed as code.
4. Re-run `npm run lint:dangerous-workflow` and re-check the PR validation status.

Advisory Poutine findings appear separately under the `poutine` category and do not block merge:

1. Record the scanner revision, scanned commit/ref, complete SARIF, rule, path, job, and package identity where available.
2. Classify each finding as actionable, a verified false positive, or an accepted residual risk. Cite source controls or upstream evidence; advisory status alone is not a disposition.
3. Harden actionable findings. Acknowledge proven false positives with the narrowest supported selector and a removal condition. Keep accepted-risk signal visible unless maintainers explicitly decide otherwise.
4. After publication, inspect hosted SARIF and step logs for the actual change. Confirm scheduled default-branch coverage after merge.
5. Reconcile remote alerts and review threads only with current hosted evidence and separate authorization. A local contract test does not prove remote resolution.

## Related documentation

* [Branch Protection](branch-protection)
* [Dependency Pinning](dependency-pinning)

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
