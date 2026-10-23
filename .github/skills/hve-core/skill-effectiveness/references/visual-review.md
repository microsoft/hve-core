---
description: "Rendered-image evidence and explicitly authorized SDK or human review for skill-effectiveness comparisons"
---

# Visual Review

Judge visible usability from actual rendered images, not filenames, source text
or successful rendering. Use human inspection or the bundled one-submission
[SDK image-review command](../scripts/review-images.mjs). The helper uses the
published SDK's blob attachment interface. Native `repo` evidence is a text
snapshot; it must not be treated as proof that a model received image pixels.
Use an automatic visual-review path only when actual image delivery is verified.

## Match The Method To The Claim

Screenshot review decides visible properties only. It cannot establish keyboard
operation, screen-reader announcements, programmatic semantics or behavior in
uncaptured states. A favorable image review does not close those claims.

For accessibility evidence selection, activate the `accessibility` skill and
read its canonical
[method-adequacy guidance](https://github.com/microsoft/hve-core/blob/main/.github/skills/accessibility/accessibility/SKILL.md#method-adequacy-decide-vs-inform).
If the skill is not installed, read that public canonical reference instead of
recreating its criteria here. Record which method can decide each scoped claim
and which evidence only informs it in `EVALS.md`. If no adequate method or
canonical guidance is available, mark the claim unmeasured or unknown; do not
promote visual evidence into a conformance verdict.

Human visual inspection remains supported for visible claims. Nonvisual claims
need separately scoped adequate evidence, such as interaction or assistive-
technology testing selected through the canonical skill. For optional coverage
workflow orchestration, ask the user to run `/accessibility-coverage-matrix`;
it is manual-only. Selecting a method does not authorize browser, screen-reader,
service or paid model startup. Do not copy WCAG or COGA requirements here.

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

Copy the image-review helper to `scripts/review-images.mjs` using the
[package copy map](../SKILL.md#assemble-and-validate). The generated package
omits the `review:images` paid convenience script. The helper remains available
for separately authorized manual use and calls the pinned Copilot SDK directly;
removing the alias does not disable it or enforce a spending ceiling.

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

Before a paid image review, read and apply the security, spending and operational
prerequisites in the
[supervised run policy](experiment-method.md#execute-an-approved-run-plan)
and obtain approval for that invocation. Human visual inspection remains
available without a model call.
For separately authorized manual use, the helper takes the judge model,
approved-copy root, relative prompt path, fresh output directory and relative
image paths as positional arguments. It does not supply financial enforcement.

Prompt/image paths resolve beneath `approved-copy`, an explicitly approved,
evaluator-owned copy made after candidates have stopped. Do not use a live
candidate-writable directory. Detected links, junctions, redirects, directories
and outside-root inputs reject. Reads require stable nonzero opened-file
identities and unchanged size/modification timestamps before and after reading;
unsupported identities stop automation. These are not hostile same-user
filesystem-race guarantees.

Preflight limits the prompt to 64 KiB, eight images, 8 MiB per image, 24 MiB
aggregate raw media and 32 MiB aggregate base64 attachments. Each image is
limited to 8192 pixels per dimension and 16,777,216 pixels; aggregate pixels
are limited to 33,554,432. Signature checks precede strict local PNG/JPEG
decoding with pinned Sharp, with a ten-second decode deadline before SDK
contact. Model-free Ubuntu checks passed actual Sharp decoding and standalone
installation on the pinned stack. Decoder doubles alone do not establish real
codec behavior, and neither result verifies model vision or Windows compatibility.

Pass additional image paths as further arguments. The output directory must not
exist; its parent must exist. Initially it contains only an atomic status record;
invalid inputs retain a minimal failure record without prompt/media copies.
Exactly the bytes read and decoded are subsequently copied and attached.
Each invocation creates a fresh SDK session using
standard `mode: "empty"`, a separate runtime home and no tools. It sends the
actual PNG/JPEG bytes as image blobs, saves the prompt/images, narrative and a
record of hashes, session identity, runtime-reported usage and failures.
The configured model must advertise vision support.

There is one `sendAndWait` call, no scripted retries and a two-minute response
timeout. Runtime startup has a separate thirty-second deadline to allow normal
authenticated process initialization. Client creation, model inventory, session
creation, abort and stop each retain a ten-second deadline with cleared timers.
Records distinguish startup, other lifecycle and response deadlines. Failure attempts
abort/stop and retains request, cleanup and terminal-persistence errors together.
Terminal status atomically replaces the helper-owned record. Failed persistence
can leave the last status `started`; the command still fails explicitly.
Deadlines do not cancel underlying operations or prove a late-created runtime
stopped. Inspect unconfirmed shutdown before another invocation.
This is not a hard credit limit or an OS sandbox. Review recorded usage before
authorizing another invocation; a failed review needs fresh approval to rerun.
Stop at approved scope/usage limits or when a required enforced cap is unavailable.
Apply the run policy's unknown-usage continuation rule; approval never waives the
requirement that this reviewer cannot execute submissions or expose protected
credentials.
Runtime files under the review directory's
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
