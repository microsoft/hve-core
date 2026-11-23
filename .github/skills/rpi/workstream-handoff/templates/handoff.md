<!-- markdownlint-disable-file -->
# Workstream handoff: {{logical contract}}

## Local record

* Handoff ID: {{handoff-N}}
* Revision: {{positive integer}}
* Supersedes: {{previous revision or none}}
* Status: {{current, stale or obsolete}}
* As of: {{date/time of this revision}}
* Producer task / role: {{stable local task identity and owning role}}
* Receiver workstream / role: {{stable workstream identity and owning role}}
* Contract: {{logical interface, schedule or assumption independent of changing refs}}
* Revision delta: {{what changed since the previous revision}}

## Evidence and consequence

* Producer before and after: {{branch and full commit IDs, observed target tip and separate in-flight head, or dated decision references}}
* Receiver reliance: {{pinned receiver source, task goal and marker or exact call/criterion}}
* Integration points: {{landed, in-flight or proposed; exact paths and symbols, inputs by reference, outputs and job/run/environment boundary}}
* Coverage and contrary evidence: {{sources checked, unavailable evidence, already-adapted or unaffected work}}
* Receiver action now: {{specific task or test that can proceed}}
* Wait or keep disabled: {{gated action, owning role, clearing evidence and recheck trigger}}
* Validation: {{observed checks and their scope; distinguish unrun or unavailable checks}}

## Issue delivery (local only)

* Receiving issue: {{verified host/repository, number, link and title for the affected receiver task, or not established}}
* Delivery history: {{initially unsent; retain attempts by revision, destination and body digest, approval scope, pending/unsent/unconfirmed/posted outcome and verified comment URL or ID when available}}
* Receiver disposition: {{not inferred from posting}}

## Copy-ready message

{{For a current confirmed impact only: state the change at a receiver-readable revision, the exact integration point, what to do now and what must wait for whom. Omit local record metadata. For stale, obsolete or unsafe-to-share records omit this section entirely.}}
