---
title: Demo Material v2 Migration Runbook
description: Maintainer procedure for publishing the first demo-material-site/v2 bundle while GitHub Pages still serves v1 demo material
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - demo material
  - migration
  - runbook
  - github pages
sidebar_position: 2
sidebar_label: v2 Migration Runbook
estimated_reading_time: 6
---

This runbook moves the published demo material from `demo-material-site/v1`
to `demo-material-site/v2`. It applies once, to the first v2 publication.
Repository maintainers own every step. Each step is a separate, explicit
action. Nothing here runs automatically, and no step deletes published media.

## Why a Migration Step Exists

The v2 pipeline refuses old bundles rather than resetting or emptying the site.
Until a v2 bundle exists:

* The render workflow's full recovery stops on a v1 index, so ordinary
  scheduled runs cannot produce the first v2 bundle.
* The documentation deployment cannot restage v1 material, so docs deployments
  fail with a request to complete this migration.

The `migrate-from-v1` input of the
[Demo Material Render](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-render.yml)
workflow is the only path across that boundary. The workflow accepts it only
when all of these conditions hold:

* The run is a manual dispatch that names an `author-run-id`.
* The published index is v1.
* No v2 bundle artifact exists.

It starts from an empty v2 site and publishes only when all four levels pass
every check. Dispatching it is the publication authorization: once the bundle
passes, the documentation deployment publishes it and replaces the v1 site.

## 1. Inventory the Current Publication

Fetch `https://microsoft.github.io/hve-core/demo-material/index.json` and record
its `schema_version`, levels, and file list in the migration issue or PR.

| Published schema        | Action                                                                                                                                        |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `demo-material-site/v1` | Continue with this runbook.                                                                                                                   |
| `demo-material-site/v2` | Stop. The migration already happened; use the normal pipeline.                                                                                |
| No index (HTTP 404)     | Stop. Nothing is published, so the normal pipeline starts an empty v2 site; dispatch a render with an `author-run-id` and no migration input. |

## 2. Archive the v1 Bundle

Keep a complete copy of the v1 material outside GitHub Pages before anything
replaces it. Use the v1 recovery tool from the last commit before the v2 change
merged. It downloads every file the v1 index lists and verifies its hash:

```bash
V1_COMMIT="<parent commit of the v2 merge on main>"
git show "${V1_COMMIT}:.github/skills/experimental/hve-demo-material/scripts/artifact_lookup.py" \
  > /tmp/artifact_lookup_v1.py
python3 /tmp/artifact_lookup_v1.py recover \
  --site-url https://microsoft.github.io/hve-core/ --target demo-material-v1-archive
```

Store `demo-material-v1-archive` where maintainers can retrieve it later, for
example as an asset on a draft release. Record its location and file count in
the migration issue. Do not continue until the archive is complete.

## 3. Choose the Author Run

Pick a successful default-branch
[Demo Material Author](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-author.md)
run whose `demo-material-content-v2-<run id>` artifact has not expired and
covers L100, L200, L300 and L400. Review its authored slide content. If no
such run exists, dispatch the author workflow for all four levels and wait for
it to succeed.

## 4. Dispatch the Migration Render

Run the render workflow manually with `author-run-id` set to the chosen run and
`migrate-from-v1` checked. The run:

* Fails immediately if the conditions above do not hold.
* Renders each level and skips v1 recovery.
* Assembles with `--require-levels L100 L200 L300 L400`, so a missing or
  failing level stops the run before any bundle is uploaded.
* Uploads `demo-material-site-v2-<run id>` and dispatches the documentation
  deployment.

## 5. Verify Provenance and Publication

1. Confirm that the render run ran on the default branch, its `Assemble the
   bundle` step logged no `WARNING` lines, and the uploaded artifact name
   matches the run ID.
2. Download the artifact and run
   `python3 .github/skills/experimental/hve-demo-material/scripts/artifact_lookup.py validate-site --target <download>`.
3. Confirm that the deployment run's `source-run-id` is the render run, and
   that the published `index.json` reports `demo-material-site/v2` with all
   four levels.
4. Open the [Demo Material](./) page and play one video, open one deck, and
   read one transcript per level.

## Rollback Criteria

* **Failure before upload:** a failed guard, render, or required-level check
  uploads nothing, and Pages keeps serving v1. Fix the cause and repeat from
  step 3.
* **Defect after publication:** prefer a forward fix. Dispatch a new render
  with a corrected author run; v2 recovery keeps passing levels while the fix
  lands.
* **Restore v1:** this is a manual maintainer action and the pipeline does not
  automate it. Revert the v2 change on `main`, then deploy the site with the
  archived v1 bundle staged under `demo-material/`. Record who approved the
  restore and why.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
