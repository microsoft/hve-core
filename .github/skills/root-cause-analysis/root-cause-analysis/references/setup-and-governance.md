---
description: Installation, connector governance, verification, update, withdrawal, and use limits for the RCA skill package
---

# RCA Setup and Governance

Use this reference before deploying the RCA skills or attaching them to production evidence.
Install all three skills so the root workflow can invoke its statistical and causal companions.
Expose only `root-cause-analysis` as a user entry point. Preserve `user-invocable: false` on
`statistical-hypothesis-testing` and `causal-evidence-likelihood`; do not publish direct commands
or other user-facing entry points for either companion.

## Intended use

The package assists engineers with evidence-based investigation of operational incidents,
software defects, data failures, and process failures. Use it when the cause is not established,
competing hypotheses need testing, and evidence can be gathered or supplied.

Results, including a `Complete` status, are AI-assessed and require validation by a qualified human
reviewer before adoption in a postmortem, incident record, or corrective-action plan.

Do not use the output as the sole basis for regulatory incident reports, safety determinations,
legal conclusions, or evaluating an individual's performance or conduct. Those contexts require
accountable domain review of the underlying technical evidence.

## Runtime prerequisite

Statistical tests require a host-provided, approved code-execution or statistics tool with an
existing runtime that supports Barnard's exact test and Welch's independent-samples t-test. The
package does not ship or install a runtime and must not install or upgrade packages during an
investigation. Without the required runtime, the statistical companion records the test as
`Blocked` and returns no statistic, confidence interval, degrees of freedom, or p-value.

## Azure SRE Agent installation

Install from a released, reviewed source rather than from a working tree with uncommitted or
unreviewed changes.

1. Download the HVE Core VSIX from the intended GitHub release and verify its attestation with
   `gh attestation verify <vsix-path> --repo microsoft/hve-core`.
2. Record the release tag, commit SHA, and SHA-256 digest of every skill and reference file that
   will be uploaded.
3. Open Azure SRE Agent and go to **Builder > Skills**.
4. Create skills named `root-cause-analysis`, `statistical-hypothesis-testing`, and
   `causal-evidence-likelihood`, then add each corresponding `SKILL.md`. Configure only
   `root-cause-analysis` as user-invocable.
5. Add `references/azure-sre-tools.md` and this setup reference to the RCA skill.
6. Confirm with the data owner or privacy team that a privacy impact assessment, including a DPIA
   where applicable, covers LLM-agent processing for every connected production source. The
   assessment must address end-user identifiers, employee activity data, inference location,
   regional residency, and thread and memory retention.
7. Attach only the read-only tools and connectors required for the declared investigation scope.
   Run them under a least-privilege identity with only the necessary read roles. Do not grant Key
   Vault data-plane access or permissions to list keys, connection strings, or app settings.
8. Do not attach write-capable tools. Attach a secret-returning tool only when it is required, and
   configure per-call approval for every invocation. Configure actions outside the reviewed
   read-only catalog to require human approval.
9. Verify the approved statistical runtime separately. The cataloged Azure SRE tools do not
   provide one.

Connectors determine which logs, telemetry, repositories, and work-item content the skill can
read. Configure each connector for the smallest required resources, fields, identities, and
absolute time window. Confirm that the service region and thread and memory retention satisfy the
organization's requirements for incident evidence before attaching production telemetry.

### Verify the installation

Run these checks in a new thread:

1. Ask which RCA host mode was detected. The response must be Azure SRE mode. If it reports generic
   mode, confirm that the platform explicitly identifies itself as Azure SRE Agent; tool names
   alone do not establish host identity.
2. Request a harmless read-only query against one approved source. Confirm that the result stays
   inside the declared resource and time window and records a source and result locator.
3. Request a write or an out-of-scope read without approving it. Confirm that no call runs and the
   action is reported as approval-gated or blocked.
4. Request a secret-returning call. Confirm that the host requires exact per-call approval and
   that stored output is redacted.
5. If no approved statistical runtime is attached, request a grouped statistical comparison.
   Confirm that the test is `Blocked` and contains no computed numeric result.

## Generic installation

Install the three skill directories in a host that supports on-demand skills. Use a reviewed
release rather than a working tree, and record the release tag, commit SHA, and SHA-256 digest of
every installed skill and reference file. Expose only `root-cause-analysis` as a user entry point
and preserve the companions as internal, fail-closed capabilities. Expose only tools appropriate
for the investigation. Generic mode requires exact, enumerated approval before any tool call that
expands the evidence set. Apply the same privacy, connector-scope, retention, least-privilege, and
human-review controls described above.

## Updates and withdrawal

Deployed copies do not update automatically. Watch HVE Core releases and security advisories.
For each update:

1. Verify the new release and record its tag, commit SHA, and file digests.
2. Compare deployed digests with the recorded source before replacement.
3. Re-upload all changed skill and reference files as one versioned set.
4. Repeat the installation checks in a new thread.

When a release or advisory withdraws a skill version, disable its tools, delete the deployed skill
files from **Builder > Skills**, and retain the version and removal record under the organization's
change-management policy.

## Model and evaluation limits

The agent can misread telemetry, code, or lineage and can produce a plausible but incorrect causal
account. Verify cited evidence, executed-test records, source coverage, and every completion-gate
criterion rather than relying on the narrative alone. Model-elicited causal-likelihood bands are
uncalibrated judgments of evidence relevance, can vary across runs or models, and are not
probabilities that a cause is real.

Advisory behavior-conformance stimuli exercise selected routing, disposition-authority,
authorization, completion, checkpoint, and regression-corpus contracts. They do not prove runtime
behavior and do not block builds while tagged advisory.

## Product documentation

* [Skills: creation, tool attachment, and lifecycle](https://learn.microsoft.com/azure/sre-agent/skills)
* [Connectors and data access](https://learn.microsoft.com/azure/sre-agent/connectors)
