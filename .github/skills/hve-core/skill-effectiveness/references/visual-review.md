---
description: "Rendered-image evidence and explicitly authorized SDK or human review for skill-effectiveness comparisons"
---

# Visual Review

Judge visible usability from actual rendered images, not filenames, source text
or successful rendering. Use human inspection or the bundled one-submission
[SDK image-review command](../assets/review-images.mjs). The pinned native Vally
prompt/panel path supplies text snapshots, not these image attachments.

## Capture The Actual Output

Use the same renderer, readiness conditions, viewport and relevant interaction
states for both submissions. Capture the scope the public task needs, including
below-fold content, labels and additional pages where relevant.

Retain the original output and rendering command/logs with the PNG/JPEG captures.
Check they decode and cover the required scope. Failed capture is missing
evaluator evidence, not automatically poor candidate quality.
Task-specific rendering can use native `run-command`; preserve the images as
artifacts. A later capture is valid if its timing/provenance are recorded.

## Run One Image Review

Copy the image-review asset to `scripts/review-images.mjs` using the
[package copy map](../SKILL.md#assemble-and-validate). The package's
`review:images` command calls the pinned Copilot SDK directly.

Prepare a UTF-8 prompt file containing the public task, relevant source facts,
completed execution results if needed, and a short assessment request. For example:

> Assess whether these diagrams communicate the stated architecture accurately
> and legibly. Identify incorrect relationships, unreadable labels or ambiguous
> boundaries, citing the image number and region. Accept alternative layouts.
> Separate observable defects from preferences and unavailable evidence.

Supply the same source evidence and criteria to each review, but only that
submission's images. The reviewer has no tools, so material absent from the
prompt/images cannot be inspected. Avoid identifying condition labels in the
prompt or pixels. Attachment display names are neutral; keep role mapping outside.

After agreeing model, scope and spending:

```powershell
$review = Join-Path $HOME ("skill-eval-runs\" + [guid]::NewGuid())
npm run review:images -- <judge-model> review-input.md "$review" deliverable/rendered/diagram.png
```

Pass additional image paths as further arguments. The output directory must not
exist; its parent must exist. Each invocation creates a fresh SDK session using
standard `mode: "empty"`, a separate runtime home and no tools. It sends the
actual PNG/JPEG bytes as image blobs, saves the prompt/images, narrative and a
record of hashes, session identity, runtime-reported usage and failures.
The configured model must advertise vision support.

There is one `sendAndWait` call, no scripted retries and a two-minute response
timeout. On failure the command aborts the session and stops its runtime.
This is not a hard credit limit or an OS sandbox. Do not run it when an enforced
credit cap is required but unavailable. Runtime files under the review directory's
`.copilot/` are local session data, not material to publish automatically.

## Validate And Interpret

Model-free tests establish byte attachment, session setup, error handling and
evidence recording, not actual vision or judgment quality. Before relying on a
model/runtime combination, authorize a small check with images containing known
visual facts and a meaningful quality difference. Confirm the response refers
to the pixels rather than merely repeating the prompt. Do not assume capability
metadata alone proves image delivery or calibrates subjective judgment.

For real comparisons follow [source-grounded review](holistic-review.md).
Cite captures/regions and distinguish legibility and user usefulness from optional
palette/spacing conventions. Unseen scope remains unknown. Keep visual assessment
separate from rendering integrity, executed behavior and source fidelity.
Reviewing saved outputs is retrospective assessment, not a new candidate trial.
