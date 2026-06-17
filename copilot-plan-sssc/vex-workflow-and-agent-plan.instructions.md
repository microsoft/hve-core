<!-- markdownlint-disable-file -->

---
description: "Implementation plan for VEX Workflow (#1220) and VEX Generation Agent (#1221)"
---

# VEX Workflow and VEX Generation Agent — Implementation Plan

## User Requests

1. Implement GitHub issue #1220: Add VEX (Vulnerability Exploitability eXchange) Workflow
2. Implement GitHub issue #1221: VEX Generation Agent — AI-Assisted Vulnerability Triage for Any Codebase
3. Create distinct phases distributable to individual developers/agents
4. Create a spec that can be validated against

## Overview and Objectives

Add VEX capability to hve-core across two complementary tracks:

- **Workflow track (#1220)**: VEX document, CI detection, release pipeline attestation, consumer documentation
- **Tooling track (#1221)**: Copilot agent for AI-assisted vulnerability triage producing OpenVEX documents

The two tracks converge at Phase 6 (AI Drafting) where the agent from #1221 powers the automated VEX drafting workflow from #1220.

### Design Decisions (from WilliamBerryiii's review)

- **Trust model**: AI drafts, human merges. Merge commit author = accountable author. Sigstore = trust anchor.
- **Confidence routing**: 5-band system (High not_affected, High affected, Medium, Low, Vendor-disputed). Agent FORBIDDEN from drafting `not_affected` at low confidence.
- **Licensing**: OSV.dev is a mixed-license aggregator — paraphrase only CC0/public-domain records (route by record `id` prefix: `GHSA-`=CC-BY-4.0, `RUSTSEC-`=CC0, `CVE-`=public domain). NVD (public domain) for CVSS/CWE. Reference GHSA by URL only.
- **Output locations**: Ephemeral in `.copilot-tracking/security/vex/`, persistent reports in `docs/security/reports/`, canonical VEX at `security/vex/`.
- **SBOM input precedence**: Trivy JSON > OSV-Scanner JSON > SPDX-JSON SBOM.
- **Maturity**: Ship all new artifacts at `experimental`. Promote to `stable` after ≥3 codebases and ≤5% false-positive rate on `not_affected`.
- **OWASP integration**: Deferred to a follow-up issue.

## Context Summary

### Discovered Instructions Files

- `.github/instructions/security/identity.instructions.md` — Security Planner identity pattern
- `.github/instructions/security/standards-mapping.instructions.md` — Standards mapping reference
- `.github/instructions/security/sssc-identity.instructions.md` — SSSC Planner identity pattern
- `.github/instructions/shared/disclaimer-language.instructions.md` — Shared disclaimer blocks
- `.github/instructions/hve-core/markdown.instructions.md` — Markdown conventions
- `.github/instructions/hve-core/prompt-builder.instructions.md` — Prompt/agent authoring standards
- `.github/instructions/hve-core/writing-style.instructions.md` — Writing style conventions
- `.github/instructions/workflows.instructions.md` — GitHub Actions workflow conventions

### Existing Infrastructure Leveraged

- `release-stable.yml` `attest-and-upload` job (Sigstore + SPDX attestation pipeline)
- `scorecard.yml` (cron + workflow_run trigger pattern)
- `dependabot.yml` (weekly Monday cadence for npm + github-actions)
- `issue-triage.md` / `issue-triage.lock.yml` (gh-aw agentic workflow pattern)
- `.github/CODEOWNERS` (current owner: `@microsoft/edge-ai-core-dev`)
- `.cspell/general-technical.txt` (`trivy` already present; `openvex` and `osv` need adding)
- `collections/security.collection.yml` (existing security collection with agents, skills, prompts, instructions)

## Implementation Phases

### Phase 1: VEX Foundation (Plumbing) <!-- parallelizable: false -->

**Issue**: #1220 Phase A
**Assignee scope**: 1 developer/agent
**Dependencies**: None
**Estimated effort**: Small

Create the foundational VEX document, CODEOWNERS entry, PR template, spelling dictionary updates, and VEX standards instructions file. No AI, no workflows.

- [x] 1.1 Create `security/vex/hve-core.openvex.json` — Empty OpenVEX document with product identity (`pkg:npm/@microsoft/hve-core`), `@context`, `@id`, `author`, `timestamp`, and empty `statements` array
- [x] 1.2 Add CODEOWNERS entry: `/security/vex/ @microsoft/edge-ai-core-dev`
- [x] 1.3 Create `.github/PULL_REQUEST_TEMPLATE/vex-triage.md` — PR template for VEX triage changes with evidence checklist and confidence-band fields
- [x] 1.4 Add `openvex` and `osv` to `.cspell/general-technical.txt` (alphabetical order)
- [x] 1.5 Create `.github/instructions/security/vex-standards.instructions.md` — OpenVEX format reference, confidence-routing rules (5-band table from #1220 §4), forbidden transitions, licensing posture (OSV preferred), author-of-record contract
- [x] 1.6 Extend `release-stable.yml` `attest-and-upload` job to attest and upload VEX file alongside existing SBOM artifacts
- [x] 1.7 Extend `release-stable.yml` `upload-plugin-packages` job similarly for plugin releases
- [x] 1.8 Update `release-stable.yml` `append-verification-notes` job to reference VEX in release notes

**Deliverables**: VEX document, CODEOWNERS update, PR template, cspell update, instructions file, release pipeline VEX attestation

### Phase 2: OpenVEX Skill + VEX Generation Instructions <!-- parallelizable: true -->

**Issue**: #1221 Phase 1 (partial)
**Assignee scope**: 1 developer/agent
**Dependencies**: None (parallelizable with Phase 1)
**Estimated effort**: Medium

Create the OpenVEX specification skill and the VEX generation instructions file that encodes the evidence requirements, status logic, confidence routing, and report templates.

- [x] 2.1 Create `.github/skills/security/openvex-spec/SKILL.md` — Skill entrypoint with OpenVEX schema reference, status definitions (`not_affected`, `affected`, `fixed`, `under_investigation`), justification codes, product identifier conventions (PURL), and document structure
- [x] 2.2 Create `.github/skills/security/openvex-spec/references/openvex-schema.md` — Detailed OpenVEX v0.2.0 JSON schema reference with field definitions, required vs optional fields, and example documents
- [x] 2.3 Create `.github/skills/security/openvex-spec/references/vex-status-logic.md` — Status determination decision tree, justification code reference, and evidence requirements per status
- [x] 2.4 Create `.github/skills/security/openvex-spec/references/cve-data-sources.md` — Data source reference covering OSV.dev API, NVD API 2.0, and GitHub Advisory DB with licensing posture, API endpoints, and response schemas
- [x] 2.5 Create `.github/instructions/security/vex-generation.instructions.md` — Evidence requirements, confidence-routing rules (5-band table), forbidden transitions (`unknown reachability → not_affected` ❌, `unknown reachability → affected` ❌), licensing posture, author-of-record contract, report templates

**Deliverables**: OpenVEX skill (SKILL.md + 3 reference files), VEX generation instructions file

### Phase 3: VEX Agent + Subagent <!-- parallelizable: true -->

**Issue**: #1221 Phase 1 (partial)
**Assignee scope**: 1 developer/agent
**Dependencies**: Phase 2 (references skill and instructions by path)
**Estimated effort**: Medium

Create the VEX generator orchestrator agent and the CVE analyzer subagent.

- [x] 3.1 Create `.github/agents/security/subagents/cve-analyzer.agent.md` — Per-CVE deep exploitability analysis subagent. Tools (repo-canonical): `search/codebase`, `search/fileSearch`, `search/textSearch`, `read/readFile`, `web`. No model invocation (`disable-model-invocation: true`). Receives enriched CVE profile, traces code reachability, determines VEX status with evidence. Enforces forbidden transitions.
- [x] 3.2 Create `.github/agents/security/vex-generator.agent.md` — Orchestrator agent. Tools (repo-canonical): `agent`, `todos`, `search/codebase`, `search/fileSearch`, `search/textSearch`, `read/readFile`, `edit/editFiles`, `edit/createFile`, `execute/runInTerminal`, `execute/getTerminalOutput`, `web`. References `cve-analyzer` subagent. Runs Trivy CLI scans, fetches CVE details from OSV.dev and NVD, delegates per-CVE analysis, assembles OpenVEX JSON output. References `#file:../../instructions/security/vex-generation.instructions.md` and `#file:../../skills/security/openvex-spec/SKILL.md`.

**Deliverables**: `vex-generator.agent.md`, `cve-analyzer.agent.md`

### Phase 4: Prompts + Collection Integration <!-- parallelizable: true -->

**Issue**: #1221 Phase 2
**Assignee scope**: 1 developer/agent
**Dependencies**: Phase 3 (prompts reference agent)
**Estimated effort**: Small

Create the `/vex-scan` and `/vex-triage` prompts and register all new artifacts in the security collection.

- [x] 4.1 Create `.github/prompts/security/vex-scan.prompt.md` — Mode 1: full pipeline. Agent: `vex-generator`. Inputs: scope (optional), product name (optional). Runs scan → enrich → analyze → generate.
- [x] 4.2 Create `.github/prompts/security/vex-triage.prompt.md` — Mode 2: triage from existing report. Agent: `vex-generator`. Inputs: report path or SBOM path (Trivy JSON, OSV-Scanner JSON, or SPDX-JSON). Skips scan phase.
- [x] 4.3 Update `collections/security.collection.yml` — Add all new artifacts:
  - Agent: `.github/agents/security/vex-generator.agent.md` (maturity: experimental)
  - Subagent: `.github/agents/security/subagents/cve-analyzer.agent.md` (maturity: experimental)
  - Skill: `.github/skills/security/openvex-spec` (maturity: experimental)
  - Prompt: `.github/prompts/security/vex-scan.prompt.md` (maturity: experimental)
  - Prompt: `.github/prompts/security/vex-triage.prompt.md` (maturity: experimental)
  - Instruction: `.github/instructions/security/vex-generation.instructions.md` (maturity: experimental)
  - Instruction: `.github/instructions/security/vex-standards.instructions.md` (maturity: experimental)
- [x] 4.4 Update `collections/security.collection.md` to document the new VEX capabilities
- [x] 4.5 Run `npm run plugin:generate` to regenerate plugin outputs
- [x] 4.6 Run `npm run plugin:validate` to confirm collection metadata

**Deliverables**: 2 prompt files, updated collection YAML + MD, regenerated plugins

### Phase 5: VEX Detection Workflow <!-- parallelizable: false -->

**Issue**: #1220 Phase B
**Assignee scope**: 1 developer/agent
**Dependencies**: Phase 1 (VEX document must exist)
**Estimated effort**: Medium

Create the `vex-detect.yml` workflow that scans for new vulnerabilities and files issues when unaddressed CVEs are found. No AI drafting yet.

- [ ] 5.1 Create `.github/workflows/vex-detect.yml` — Triggered by: (a) `workflow_run` on `release-stable.yml` success, (b) weekly cron (Monday, after Dependabot), (c) `workflow_dispatch`. Runs OSV-Scanner or Grype against latest SBOM. Diffs findings against current `security/vex/hve-core.openvex.json`. Files a structured GitHub issue when new CVEs or status drift are detected.
- [ ] 5.2 Add `osv-scanner` to `copilot-setup-steps.yml` and `.devcontainer/scripts/on-create.sh` if not already present

**Deliverables**: `vex-detect.yml` workflow, environment updates

### Phase 6: AI-Assisted VEX Drafting Workflow <!-- parallelizable: false -->

**Issue**: #1220 Phase C + #1221 convergence
**Assignee scope**: 1 developer/agent
**Dependencies**: Phase 3 (agent must exist), Phase 5 (detection workflow triggers drafting)
**Estimated effort**: Medium

Create the gh-aw agentic workflow that uses the VEX generator agent to draft VEX updates as PRs.

- [x] 6.1 Create `.github/workflows/vex-draft.md` — gh-aw workflow definition. Engine: `copilot`. Imports: `vex-generator.agent.md`. Triggered by `vex-detect.yml` dispatch when new findings exist. Safe-outputs: `create-pull-request` with `max: 1`. PR template uses `vex-triage.md` with evidence, confidence band, and suggested status.
- [x] 6.2 Create `.github/workflows/vex-draft.lock.yml` — Compiled gh-aw lock file (generated by `gh aw compile`)

**Deliverables**: `vex-draft.md`, `vex-draft.lock.yml`

### Phase 7: Documentation <!-- parallelizable: true -->

**Issue**: #1220 Phase 4 + #1221 Phase 4
**Assignee scope**: 1 developer/agent
**Dependencies**: Phase 1-4 (documents what was built)
**Estimated effort**: Medium

Create consumer-facing documentation for VEX verification and agent usage.

- [x] 7.1 Create `docs/security/vex-verification.md` — What VEX is, how it complements the SBOM, how to download and verify, how to interpret status values, how to consume VEX with Trivy/Grype
- [x] 7.2 Update `docs/security/security-model.md` — Add VEX control entry to the Security Controls table
- [x] 7.3 Update `docs/security/README.md` — Add VEX verification link to the security documentation index
- [x] 7.4 Update `SECURITY.md` — Add `.openvex.json` to the Release Artifact Formats table
- [x] 7.5 Create `docs/agents/security/vex-generator.md` — Agent documentation with usage examples, prerequisites (Trivy), output format, confidence routing explanation
- [ ] 7.6 Update `docs/agents/sssc-planning/phase-reference.md` — Add VEX capability to the capability table (if this file exists) — N/A: VEX is not an SSSC planning phase, so it does not belong in that capability table

**Deliverables**: 2 new doc files, 3-4 doc updates

## Dependencies

### Skills

- `.github/skills/security/openvex-spec/` (new, created in Phase 2)

### Instructions

- `.github/instructions/security/vex-standards.instructions.md` (new, Phase 1)
- `.github/instructions/security/vex-generation.instructions.md` (new, Phase 2)
- `.github/instructions/shared/disclaimer-language.instructions.md` (existing)
- `.github/instructions/hve-core/prompt-builder.instructions.md` (existing, authoring standards)

### External Tools

- Trivy CLI v0.63.0+ (prerequisite for consumers running `/vex-scan`)
- OSV-Scanner (prerequisite for `vex-detect.yml`)
- OSV.dev REST API (CC0 license, no auth required)
- NVD API 2.0 (public domain, no auth required)

## Success Criteria

See the companion validation spec at `vex-validation-spec.md`.

## Phase Dependency Graph

```text
Phase 1 (Foundation)  ──────────────────────────────────┐
                                                         │
Phase 2 (Skill + Instructions) ─── Phase 3 (Agent) ─── Phase 4 (Prompts + Collection) ──┐
                                                         │                                │
                                                         ├── Phase 5 (Detection) ──── Phase 6 (AI Drafting)
                                                         │
                                                         └── Phase 7 (Documentation)
```

Phases 1 and 2 can run in parallel. Phases 2→3→4 are sequential. Phase 5 depends on Phase 1. Phase 6 depends on Phases 3 and 5. Phase 7 can start after Phase 4 completes.
