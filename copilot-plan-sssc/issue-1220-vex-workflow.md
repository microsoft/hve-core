# feat: Add VEX (Vulnerability Exploitability eXchange) Workflow #1220

- **URL**: https://github.com/microsoft/hve-core/issues/1220
- **Author**: @dasiths
- **Labels**: enhancement, security, needs-triage
- **Milestone**: v3.10.0

## Description

### Overview

To complement our existing supply chain security practices (SBOM and build provenance attestations), introduce a VEX (Vulnerability Exploitability eXchange) document and process. VEX provides a machine-readable status for vulnerabilities in dependencies, dramatically improving signal-to-noise for downstream consumers and aligning HVE Core with modern supply chain standards.

### Motivation

- Consumers and auditors currently receive only an SBOM: All dependencies and transitive packages are listed, but every potential CVE is flagged whether or not it's exploitable in this project.
- VEX augments SBOMs: Maintainers/auditors can communicate actual risk (`Affected`, `Not Affected`, `Fixed`, `Under Investigation`) for CVEs, helping consumers prioritize real vulnerabilities, not theoretical ones.
- Noise reduction: With 123 forks and growing adoption, a VEX document prevents a flood of "are you affected by CVE-X?" issues every time a high-profile vulnerability is disclosed in a common dependency.
- Best practices alignment: Complements our existing Sigstore, SLSA, and OpenSSF posture for supply chain security maturity.

### Current State

The release pipeline already produces and attests the following artifacts per release:

| Suffix          | Format                    | Purpose                              |
|-----------------|---------------------------|--------------------------------------|
| .spdx.json      | SPDX 2.3 JSON             | Software Bill of Materials           |
| .sigstore.json   | Sigstore bundle (JSON)    | Cryptographic attestation envelope   |
| .intoto.jsonl    | in-toto DSSE envelope     | Provenance statement                 |

VEX would add a new row to this table as a natural extension.

### VEX Workflow

VEX is not auto-generated — it requires human triage. The workflow is:

1. A CVE is disclosed in a dependency (flagged by Dependabot, Grype, Trivy, etc.)
2. A maintainer investigates whether the vulnerable code path is reachable in HVE Core
3. The maintainer updates the VEX document in `security/vex/hve-core.openvex.json` with a status entry
4. The VEX file ships with the next release, attested and uploaded alongside existing artifacts

### Implementation Plan

#### Phase 1: Foundation

- Choose VEX format — recommend OpenVEX for simplicity and ecosystem compatibility
- Create initial VEX document at `security/vex/hve-core.openvex.json`
- Triage any currently known CVEs in production dependencies and populate initial statements
- Add `openvex` to `.cspell/general-technical.txt`

#### Phase 2: CI Integration

- Add VEX schema validation step to PR validation pipeline (lint/check well-formedness)
- Optional: Add a "VEX gap" CI job that cross-references SBOM scan results against VEX entries and warns on unaddressed CVEs

#### Phase 3: Release Pipeline

- Add a step in the `attest-and-upload` job (in both `release-stable.yml` and `release-prerelease.yml`) to:
  - Copy VEX document into release artifacts
  - Attest with Sigstore (same as SBOM)
  - Upload alongside existing `.spdx.json`, `.sigstore.json`, and `.intoto.jsonl` files
- Update the Release Artifact Formats table in `SECURITY.md` to include the new `.openvex.json` suffix
- Update `append-verification-notes` job to reference VEX in release notes

#### Phase 4: Documentation

- Create `docs/security/vex-verification.md` (parallel to `sbom-verification.md`) covering:
  - What VEX is and how it complements the SBOM
  - How to download and verify the VEX document
  - How to interpret status values (`not_affected`, `affected`, `fixed`, `under_investigation`)
  - How to consume VEX alongside the SBOM in tooling (Grype, Trivy, etc.)
- Update `docs/security/security-model.md` control table with a new VEX control entry
- Update `docs/agents/sssc-planning/phase-reference.md` capability table

### Proposed Repo Structure

```text
security/
  vex/
    hve-core.openvex.json    ← VEX document, maintained manually, committed to git
docs/security/
    vex-verification.md       ← consumer-facing verification and interpretation guide
```

### Example VEX Statement

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://github.com/microsoft/hve-core/security/vex/2026-03-27",
  "author": "Microsoft HVE Core Maintainers",
  "timestamp": "2026-03-27T00:00:00Z",
  "statements": [
    {
      "vulnerability": { "@id": "https://nvd.nist.gov/vuln/detail/CVE-2026-XXXXX" },
      "products": [
        { "@id": "pkg:npm/@microsoft/hve-core" }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "The affected parsing function is never invoked by HVE Core"
    }
  ]
}
```

### References

- [OpenVEX Specification](https://openvex.dev/)
- [CycloneDX VEX](https://cyclonedx.org/capabilities/vex/)
- [CISA VEX Overview](https://www.cisa.gov/resources-tools/resources/minimum-requirements-vulnerability-exploitability-exchange-vex)
- [Current SBOM verification guide](https://github.com/microsoft/hve-core/tree/main/docs/security/sbom-verification.md)
- [Security model controls](https://github.com/microsoft/hve-core/tree/main/docs/security/security-model.md)
- [attest-and-upload job in release-stable.yml](https://github.com/microsoft/hve-core/tree/main/.github/workflows/release-stable.yml)
- [attest-and-upload job in release-prerelease.yml](https://github.com/microsoft/hve-core/tree/main/.github/workflows/release-prerelease.yml)

---

## WilliamBerryiii's Comment: Deep technical review

> After auditing the existing CI/CD, security, release, and agentic surfaces, hve-core is not greenfield for VEX — roughly 80% of the plumbing already exists. What's missing is a VEX document, a VEX-aware scanner trigger, and a routing layer. This comment proposes an architecture that pushes everything except the merge click onto agents and machines.
>
> Note: this is complementary to #1221 (the `vex-generator` agent). #1221 builds the tool; this issue builds the workflow that consumes it. Phase C below is exactly where #1221 lands.

### 1. What hve-core already has (the leverage)

| Capability                              | Where                                                                                                       | Why it matters for VEX                                                                                                             |
|-----------------------------------------|-------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| SPDX-JSON SBOMs per artifact + dependency-wide | release-stable.yml (anchore/sbom-action@v0.24.0)                                                          | Authoritative input for any vulnerability scanner                                                                                  |
| Sigstore keyless attestation pipeline   | release-stable.yml attest-and-upload job (actions/attest@v4.1.0, actions/attest-build-provenance@v4.1.0) with id-token: write + attestations: write | One additional actions/attest step + one extra gh release upload argument adds VEX with zero new infrastructure                    |
| gh-aw agentic workflow framework        | .github/workflows/*.md + .lock.yml pairs, engine: copilot, safe-outputs capability gating, noop activation guards | Drop-in pattern for vex-draft.md and vex-triage.md workflows                                                                       |
| Issue-triage agent precedent            | issue-triage.md, issue-implement.md                                                                         | Canonical safe-outputs template for AI-drafted PRs with max: caps                                                                  |
| Scheduled + post-release scanning cadence | scorecard.yml (cron + workflow_run)                                                                        | Direct precedent for VEX rescan triggers                                                                                           |
| Dependency change firehose              | dependabot.yml (weekly Mon, npm/github-actions/uv)                                                         | Natural trigger source for "rescan VEX on dependency change"                                                                       |
| GitHub App auth                         | RELEASE_APP_ID / RELEASE_APP_PRIVATE_KEY                                                                    | Already-trusted identity for autonomous PR creation                                                                                |

Practical implication: adding VEX to the existing `attest-and-upload` job is a ~10-line YAML change — one extra `actions/attest@v4.1.0` step on the VEX file, one extra `gh release upload --clobber` argument. The `.sigstore.json` + `.intoto.jsonl` pair drops out automatically.

### 2. The trust constraint, and why it doesn't block automation

CISA VEX requires an identifiable accountable author. OpenVEX's trust anchor is the Sigstore signing identity. Neither requires that a human drafted the document — only that a human (or accountable identity) attested it.

In the GitHub-native model:

- **Drafter** = AI agent (no trust requirement)
- **Reviewer** = CODEOWNERS-required human approver
- **Author of record** = merge commit author (the approver)
- **Trust anchor** = Sigstore identity of the release workflow

This means an agent can perform every step except clicking "Merge". That's the human-touch budget.

### 3. Proposed end-to-end flow

```text
Trigger (3 sources, all autonomous):
  ├─ release-please tagging        →  vex-detect.yml runs against new SBOM
  ├─ Dependabot PR merged          →  vex-detect.yml runs against changed deps only
  └─ Weekly cron (Mon, post-Dependabot)  →  vex-detect.yml runs full scan
         │
         ▼
vex-detect.yml (no AI)
  └─ OSV-Scanner (or Grype) against latest SBOM, emit JSON
  └─ Diff against current security/vex/hve-core.openvex.json
  └─ If new findings or status drift detected: dispatch vex-draft.md
         │
         ▼
vex-draft.md (gh-aw, engine: copilot, agent: vex-triage)
  └─ For each new CVE:
     ├─ Fetch OSV.dev advisory (CC0 — license-clean, see §6)
     ├─ Reachability analysis on the codebase (codebase + search tools)
     ├─ Compute confidence score
     └─ Route per §4 confidence table
  └─ safe-outputs: create-pull-request (max: 1) with updated VEX + assessment report
  └─ PR template auto-populated with evidence, confidence, suggested status
         │
         ▼
Human (only required step)
  └─ CODEOWNERS-required review on security/vex/**
  └─ Approve → squash-merge → merge commit author = accountable author
         │
         ▼
release-stable.yml attest-and-upload (extended)
  └─ actions/attest@v4.1.0 on security/vex/hve-core.openvex.json
  └─ gh release upload hve-core.openvex.json + .sigstore.json + .intoto.jsonl
```

Steady-state human touch: review and merge a small VEX PR. Estimated ~20 min/month at typical Dependabot volume.

### 4. Confidence-banded routing (the autonomy lever)

The agent must classify each finding into one of three confidence bands, with hard rules on what it's allowed to draft autonomously:

| Band                   | Criteria                                                                                                  | Agent Action                                                                                           | Human Action                            |
|------------------------|-----------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-----------------------------------------|
| High — not_affected    | Vulnerable symbol provably unreachable (no import path, dead code, or guarded by mitigation)              | Draft not_affected with vulnerable_code_not_in_execute_path justification + code citations              | Approve PR (skim evidence)              |
| High — affected        | Vulnerable symbol on a reachable execution path                                                           | Draft affected + link to remediation issue                                                              | Approve PR + triage remediation         |
| Medium                 | Symbol reachable in some configurations but ambiguous (feature flags, optional codepaths, runtime conditional) | Draft under_investigation + structured questions for human reviewer                                     | Decide final status, edit PR            |
| Low                    | Cannot determine reachability (closed-source dep, dynamic dispatch, native code)                          | Draft under_investigation only — forbidden from drafting not_affected                                   | Manual analysis, may downgrade          |
| Vendor-disputed        | OSV/NVD shows dispute or CVSS < 4.0 with no known exploit                                                | Draft not_affected with inline_mitigations_already_exist only when accompanied by code citation         | Approve PR                              |

**Hard rule**: the agent is forbidden from drafting `not_affected` at low confidence. Uncertain cases default to `under_investigation`, which is safe and fully retractable in OpenVEX.

> [!NOTE]
> **Editorial audit note (added 2026-06-17, not part of the original issue text).** The
> **Vendor-disputed** row above proposes drafting `not_affected` with
> `inline_mitigations_already_exist`. This was determined to be **incorrect**: it lets the agent
> assert non-exploitability for a disputed CVE without reachability evidence, which violates the
> project's core guard. The implemented standard (see the `openvex-spec` skill reference
> [`vex-status-logic.md`](../.github/skills/security/openvex-spec/references/vex-status-logic.md)
> and [`vex-standards.instructions.md`](../.github/instructions/security/vex-standards.instructions.md))
> **corrects this**: vendor-disputed findings are drafted as `under_investigation`, recording the
> dispute in `status_notes` until evidence is gathered. The verbatim table is retained above for
> historical traceability. The `codepaths` spelling in the Medium row is likewise a verbatim
> artifact of the source issue; the shipped files use `code paths`.

### 5. Mandatory human-touch surface (the non-negotiables)

| Touch Point                  | Why                                                                   | Frequency                            |
|------------------------------|-----------------------------------------------------------------------|--------------------------------------|
| Approve VEX PR               | Author-of-record requirement; Sigstore identity needs accountable approver | Per Dependabot wave / per release    |
| Decide ambiguous reachability | Agent forbidden from low-confidence not_affected                      | Edge cases only                      |
| Override agent draft         | Human judgment on operational context the agent cannot infer          | Rare                                 |
| Initial CODEOWNERS + workflow PRs | Bootstrap trust                                                   | One-time                             |

Everything else — scanning, drafting, evidence collection, PR creation, attestation, upload, release-asset publication — is automated.

### 6. Licensing: use OSV.dev as the evidence source

Sidesteps the GHSA prose attribution problem entirely:

| Source                   | License                       | Use in VEX                                              |
|--------------------------|-------------------------------|---------------------------------------------------------|
| OSV.dev advisory data    | CC0 (public domain)           | Drafted summaries, references, affected ranges, severity |
| NVD API 2.0              | US Gov public domain          | CVSS vectors, CWE classification                        |
| GitHub Advisory DB prose  | CC-BY-4.0 (attribution required) | Avoid quoting; use only as a pointer                   |

OpenVEX `references[]` URLs are facts, not copyrighted expression — safe to include from any source. Drafted prose should paraphrase OSV/NVD only.

This pairs cleanly with #1221's "no MCP dependencies, fetch via REST" approach — same data sources, same licensing posture.

### 7. Revised rollout (3 phases, each independently shippable)

**Phase A — Plumbing only, no AI (estimated half-day)**

- `security/vex/hve-core.openvex.json` (empty document with product identity)
- CODEOWNERS entry: `/security/vex/ @microsoft/hve-core-security-leads`
- `.github/PULL_REQUEST_TEMPLATE/vex-triage.md`
- Extend `release-stable.yml attest-and-upload` to attest + upload the VEX file
- `.github/instructions/security/vex-standards.instructions.md`

Ship as a normal PR with no agentic dependencies. Closes the "we have no VEX document at all" gap immediately.

**Phase B — Detection only, no AI drafting (estimated 1 day)**

- `.github/workflows/vex-detect.yml` (cron + `workflow_run` on release-stable + Dependabot merge)
- OSV-Scanner against latest release SBOM
- On new findings, file a regular GitHub issue (no PR yet) with structured triage prompt
- Manual VEX edits during this phase, but with automated detection cadence

This proves the detection cadence and surfaces real-world signal volume before adding AI drafting.

**Phase C — AI drafting via #1221 (estimated 2 days, depends on #1221 shipping)**

- `.github/workflows/vex-draft.md` (gh-aw wrapper that invokes `vex-generator` from #1221)
- Confidence-routing rules from §4 enforced via `vex-triage.agent.md` instructions
- `safe-outputs: create-pull-request` with `max: 1` cap
- PR template auto-populated with evidence + confidence + suggested status
- Forbidden-transitions list enforced in agent instructions

Phase C cannot ship until #1221 lands. Phase A and B can ship now and provide value independently.

### 8. Recommendation

1. Treat #1220 (this issue) as the workflow track and #1221 as the tooling track. They are complementary, not redundant.
2. Ship Phase A as a single PR this week — it's pure plumbing, no agent dependencies, and closes the immediate gap.
3. Begin Phase B in parallel with #1221's Phase 1 (core agent + skill).
4. Phase C lights up automatically once #1221 reaches `experimental` maturity.

Open question for maintainers: confirm `microsoft/hve-core-security-leads` (or equivalent) as the CODEOWNERS group for `security/vex/`, and confirm the autonomy posture in §4 is acceptable for the `not_affected` forbidden-transition rule.

Cross-references: #1221 (VEX Generation Agent — provides the AI drafting capability for Phase C above).
