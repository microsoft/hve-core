# VEX Test Plan (pre-documentation gate)

Validate the six merged VEX phases (#1-#6) behaviorally, not just statically, before the documentation phase (#7). Each layer states what it proves, how to run it, prerequisites, the expected result, and whether it is runnable in the current local environment.

## Environment inventory (verified 2026-06-18)

| Tool | Status | Used by |
|------|--------|---------|
| Trivy | 0.63.0 installed | VEX Generator Mode 1 (`/vex-scan`) |
| osv-scanner | NOT installed locally | detection workflow (#5) |
| python3 | 3.10.12 | detection diff, schema checks |
| node | 24.16.0 | linters, postprocess |
| gh | 2.92.0 | issue/PR/`gh aw` |
| gh aw | v0.79.6 (pinned) | drafting workflow trial (#6) |

## Layers

### Layer 0 — Holistic static re-validation (all phases combined)

- **Proves**: combining all six phases on the base branch introduced no lint/compile regressions; the lock is in sync with its source.
- **Run**:
  - `npm run lint:yaml`, `npm run lint:md`, `npm run spell-check`, `npm run lint:dependency-pinning`, `npm run lint:permissions`
  - `gh aw compile vex-draft` (expect 0/0; restore `dependabot.yml` + `actions-lock.json` afterward), then `gh aw lint`
- **Expected**: all pass; `gh aw compile` reports no drift.
- **Runnable now**: yes.

### Layer 1 — VEX document schema conformance (#1, #2)

- **Proves**: `security/vex/hve-core.openvex.json` is a valid OpenVEX v0.2.0 document, and the same validator can gate agent-drafted updates later.
- **Run**: structural validation of the envelope (`@context`, `@id`, `author`, `timestamp`, `version`, `statements`) plus, when statements exist, per-statement required fields and allowed `status`/`justification` values per `.github/skills/security/openvex-spec/references/openvex-schema.md`.
  - `uvx check-jsonschema --schemafile <openvex-v0.2.0 schema> security/vex/hve-core.openvex.json` (or an embedded python `jsonschema` check if offline).
- **Expected**: envelope valid; empty `statements` accepted.
- **Runnable now**: yes.

### Layer 2 — Detection workflow local execution (#5)

- **Proves**: `vex-detect.yml`'s scan + diff + issue-body logic works against the real dependency set, including the reviewed exit-code and status-suppression behavior.
- **Prereq**: install `osv-scanner` v2.3.8 via the workflow's verified-download (same per-arch SHA256).
- **Run** (replicate the job steps by hand):
  1. `osv-scanner scan source --recursive --format json --output /tmp/osv-results.json .`
  2. Execute the workflow's inline Python diff against `security/vex/hve-core.openvex.json`; capture `count` and `/tmp/vex-issue-body.md`.
  3. **Findings path**: confirm real repo CVEs (if any) appear in the issue table with severity/aliases/status columns.
  4. **No-findings path**: temporarily add a matching statement to a copy of the VEX doc; confirm the CVE is suppressed (terminal status) and `count` drops.
  5. **Error path (M1)**: simulate `osv-scanner` exit > 1; confirm the step would fail rather than emit `{"results":[]}`.
- **Expected**: count matches the untriaged set; issue body renders; suppression and error handling behave as reviewed.
- **Runnable now**: yes (after installing osv-scanner).

### Layer 3 — VEX Generator agent pipeline (#2, #3, #4)

- **Proves**: the agent + `CVE Analyzer` subagent + skill + instructions produce a schema-valid, evidence-backed OpenVEX draft that honors confidence routing and the forbidden-transition guard.
- **Run**:
  - **Mode 1** (`/vex-scan scope=scripts/` to bound it): Trivy scan -> CVE enrichment (OSV.dev/NVD) -> reachability via subagent -> draft OpenVEX + triage report.
  - **Mode 2** (`/vex-triage report=/tmp/osv-results.json`): triage from the Layer 2 scan output (no Trivy dependency).
- **Checks on output**:
  - Draft validates against Layer 1 schema.
  - No `not_affected` without code-citation evidence; `under_investigation` used where reachability is undetermined.
  - Report matches the templates in `vex-generation.instructions.md`; no GHSA prose quoted (licensing posture).
  - Mutation contract respected (version bump, timestamps, unrelated statements untouched).
- **Optional**: grade the run with the `Prompt Evaluator` / `Prompt Tester` subagent.
- **Runnable now**: yes (Trivy present). Output is a throwaway draft, not committed.

### Layer 4 — Drafting workflow behavioral test (#6)

- **Proves**: `vex-draft.md` activates correctly (success gate + noop guards), reads a detection issue, and emits exactly one PR with the vex-triage body.
- **Run** (escalating cost):
  1. `gh aw trial ./.github/workflows/vex-draft.md --dry-run` — preview without execution.
  2. Seed a throwaway detection issue (title/label matching the contract), then `gh aw trial ./.github/workflows/vex-draft.md --logical-repo dasiths/hve-core --clone-repo dasiths/hve-core --trigger-context <issue-url> --delete-host-repo-after` — full behavioral run in an ephemeral repo.
  3. Inspect the captured safe-output PR + `gh aw logs` / `gh aw audit`.
- **Prereq**: Copilot engine token configured for `gh aw`; consumes AI credits; creates a temporary private repo.
- **Expected**: noop on no-issue / failed-upstream; one PR drafted when the seeded issue lists untriaged findings; PR touches only `security/vex/hve-core.openvex.json`.
- **Runnable now**: dry-run yes; full trial pending engine-credit confirmation.

### Layer 5 — Release attestation (#1) — deferred

- **Proves**: the release pipeline attests and uploads the VEX document alongside the SBOM.
- **Run**: static review of the `attest` + `gh release upload` additions; full verification (`gh attestation verify --predicate-type ...`) requires an actual stable release.
- **Runnable now**: static review only; behavioral test deferred to the next release (or an `act` dry-run if desired).

### Layer 6 — Integration seam check

- **Proves**: the contracts line up across phases: detection issue title/label == drafting guard; drafted file path == release attest path == skill mutation target; statuses/justifications consistent across skill, instructions, prompts, and the PR template.
- **Run**: checklist cross-reference (mostly covered by prior reviews; this consolidates it).
- **Runnable now**: yes.

## Recommended order

0 -> 1 -> 2 -> 3 -> 6 locally (no external cost), then 4 (engine credits) on demand, with 5 deferred to a real release.

## Out of scope

- Cutting an actual release to verify attestation end-to-end (Layer 5 behavioral).
- Proving false-positive rates across three codebases (the `experimental` maturity exit criterion) — that is longitudinal, not a single test pass.
