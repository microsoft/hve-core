---
description: "Drafts OpenVEX status updates as a pull request after the VEX Detection workflow finds untriaged vulnerabilities"
tracker-id: vex-draft
on:
  workflow_run:
    workflows: ["VEX Detection"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]
  reaction: eyes
  skip-if-match: 'is:open "gh-aw-tracker-id: vex-draft" in:body'
  permissions:
    contents: read
    issues: read
  steps:
    - id: vex_gate
      name: Gate B - skip when all findings already have terminal VEX statuses
      env:
        GH_TOKEN: ${{ github.token }}
        REPO_SLUG: ${{ github.repository }}
        ISSUE_TITLE: 'VEX detection: untriaged vulnerabilities found'
      run: |
        set -euo pipefail

        issue_number="$(gh issue list --repo "$REPO_SLUG" --state open --label automated --limit 100 --json number,title --jq ".[] | select(.title == \"$ISSUE_TITLE\") | .number" | head -n 1)"
        if [ -z "$issue_number" ]; then
          echo "No open automated VEX detection issue found; skipping."
          exit 1
        fi

        issue_body="$(gh issue view --repo "$REPO_SLUG" "$issue_number" --json body --jq '.body')"
        finding_ids=()
        while IFS= read -r line; do
          if [[ "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\| ]]; then
            finding_id="${BASH_REMATCH[1]}"
            finding_id="${finding_id// /}"
            if [[ "$finding_id" != "Finding" && "$finding_id" != "ID" && "$finding_id" != "FindingID" ]]; then
              finding_ids+=("$finding_id")
            fi
          fi
        done <<< "$issue_body"

        if [ ${#finding_ids[@]} -eq 0 ]; then
          echo "No findings found in detection issue; skipping."
          exit 1
        fi

        python3 - "$PWD/security/vex/hve-core.openvex.json" "${finding_ids[@]}" <<'PY'
        import json
        import sys
        from pathlib import Path

        path = Path(sys.argv[1])
        finding_ids = sys.argv[2:]
        if not path.exists():
            print("OpenVEX document not found; proceeding.")
            sys.exit(0)

        with path.open(encoding="utf-8") as handle:
            document = json.load(handle)

        terminal_statuses = {"not_affected", "fixed"}

        def check_terminal(node, target):
            if isinstance(node, dict):
                status = node.get("status")
                if isinstance(status, str) and status in terminal_statuses:
                    for value in node.values():
                        if isinstance(value, str) and target.lower() in value.lower():
                            return True
                        if isinstance(value, list) and any(isinstance(item, str) and target.lower() in item.lower() for item in value):
                            return True
                    return False
                for value in node.values():
                    if isinstance(value, (dict, list)) and check_terminal(value, target):
                        return True
            elif isinstance(node, list):
                for item in node:
                    if check_terminal(item, target):
                        return True
            return False

        for finding_id in finding_ids:
            if not check_terminal(document, finding_id):
                print(f"Finding {finding_id} is not terminal; proceeding.")
                sys.exit(0)

        print("All findings already have terminal VEX status; skipping.")
        sys.exit(1)
        PY

engine: copilot
timeout-minutes: 20

# Deterministic gate: skip the agent entirely when the upstream VEX Detection
# run did not succeed. workflow_dispatch carries no workflow_run payload, so it
# always passes this guard.
if: >-
  (github.event_name != 'workflow_run' || github.event.workflow_run.conclusion == 'success') && needs.pre_activation.outputs.vex_gate_result == 'success'

imports:
  - ../agents/security/vex-generator.agent.md

checkout:
  sparse-checkout: |
    .github/copilot-instructions.md
    .github/agents/security/
    .github/instructions/security/
    .github/instructions/shared/
    .github/skills/security/openvex-spec/
    .github/PULL_REQUEST_TEMPLATE/vex-triage.md
    security/vex/
    scripts/
    extension/
    collections/
    package.json
    package-lock.json
    pyproject.toml
    justfile

permissions:
  contents: read
  issues: read
  actions: read

# Reach the public advisory databases for CVE enrichment. api.github.com (GitHub
# Advisory Database) is already in the gh-aw network defaults; OSV.dev and NVD
# are added here so the agent can resolve advisories by native id and CVE.
network:
  allowed:
    - defaults
    - api.osv.dev
    - osv.dev
    - services.nvd.nist.gov

safe-outputs:
  concurrency-group: "vex-draft-${{ github.repository }}"
  report-failure-as-issue: ["!max_ai_credits_exceeded", "!ai_credits_rate_limit_error"]
  create-pull-request:
    max: 1
    labels: [security, automated, needs-triage]
    # Pin the PR target (and the safe_outputs checkout ref) to the trusted
    # default branch. This workflow runs under the privileged workflow_run
    # trigger, so the checkout ref must never derive from agent output
    # (Scorecard Dangerous-Workflow / untrusted code checkout).
    base-branch: main
  noop:
    max: 1
    report-as-issue: false
---

# VEX Drafting

Draft OpenVEX status updates for untriaged vulnerabilities surfaced by the
`VEX Detection` workflow, and open a single pull request for human review.
The agent drafts; a CODEOWNERS-required human reviews and merges. The merge
commit author is the accountable author of record, never the agent.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The event is `workflow_run` and `github.event.workflow_run.conclusion` is not `success`. Call `noop` with message "Skipping: upstream VEX Detection run did not succeed."
* No open issue exists with the title `VEX detection: untriaged vulnerabilities found` and the `automated` label. Call `noop` with message "Skipping: no open VEX detection issue with untriaged findings."
* The detection issue lists no vulnerabilities in its findings table. Call `noop` with message "Skipping: detection issue has no untriaged findings."

**Failure to call `noop` when no drafting action is taken will cause workflow failure.**

## Instruction Priority

Follow the Workflow section below as the sole drafting procedure. The imported
`VEX Generator` agent and its referenced skill and instructions provide domain
knowledge only: OpenVEX schema, status logic, evidence thresholds, confidence
routing, and licensing posture. Ignore any phase-, mode-, or tracking-file-based
orchestration from the imported files; this workflow runs Mode 2 (triage from an
existing finding set) non-interactively.

## Workflow

1. **Read the work list.** Locate the open issue titled `VEX detection:
   untriaged vulnerabilities found` carrying the `automated` label. Parse its
   findings table to obtain the list of vulnerability IDs, aliases, affected
   packages, and current VEX status.

2. **Load the canonical rules.** Read the OpenVEX skill and the VEX generation
   and standards instructions referenced by the imported agent. Honor the
   document mutation contract for `security/vex/hve-core.openvex.json` and the
   forbidden-transition rules.

3. **Drop already-triaged findings.** Read
   `security/vex/hve-core.openvex.json`. For each finding from the issue, look
   up an existing statement by vulnerability ID or alias and discard any
   finding already at a terminal status (`not_affected` or `fixed`). If no
   non-terminal findings remain, call `noop` with message "Skipping: all
   detected findings already carry a terminal VEX status." and stop. The
   detection issue is not closed by this workflow; it is the human reviewer's
   to resolve.

4. **Enrich each vulnerability.** For every remaining finding, gather advisory
   data from license-clean public sources (OSV.dev, NVD API 2.0): affected
   version ranges, CVSS vector, CWE, advisory URLs, and the vulnerable symbol
   when available. Do not quote GHSA prose. Do not fabricate data when a source
   is unavailable; record the gap.

5. **Analyze reachability.** For each finding, determine whether the vulnerable
   symbol is reachable in this codebase. Delegate per-CVE exploitability
   analysis to the `CVE Analyzer` subagent. If subagent delegation is
   unavailable in this environment, perform the same analysis inline. Either
   way, trace the import path, confirm dead code, or identify a mitigation, and
   cite file paths and line ranges as evidence.

6. **Route by confidence.** Classify each finding into a confidence band and
   draft the status the band permits:

   | Confidence band                 | Criteria                                 | Status the agent may draft                                              |
   |---------------------------------|------------------------------------------|-------------------------------------------------------------------------|
   | High, not_affected              | Vulnerable symbol provably unreachable   | `not_affected` with the matching justification code plus code citations |
   | High, affected                  | Vulnerable symbol on a reachable path    | `affected`, with a note on the remediation need                         |
   | Medium, Low, or Vendor-disputed | Reachability ambiguous or undeterminable | `under_investigation` only                                              |

   The non-negotiable guard: when reachability or exploitability cannot be
   determined, the only valid status is `under_investigation`. You are
   forbidden from drafting `not_affected` at low confidence.

7. **Update the VEX document.** Apply the drafted statements to
   `security/vex/hve-core.openvex.json` per the mutation contract (bump the
   document version, set timestamps, never rewrite unrelated statements).

8. **Open one pull request.** Emit a single `create-pull-request` safe output.
   Populate the PR body from `.github/PULL_REQUEST_TEMPLATE/vex-triage.md`: a
   summary, the evidence checklist, and one CVE assessment block per finding
   recording the drafted status, confidence band, code-citation evidence, and
   impact statement. Title the PR `VEX: draft status for untriaged findings`.

## Constraints

* Draft only; never merge, approve, or publish. Humans remain the merge gate.
* Emit at most one pull request per run.
* Never draft `not_affected` or `affected` without code-citation evidence.
* Never assert `not_affected` when reachability is undetermined; use
  `under_investigation`.
* Do not modify any file outside `security/vex/hve-core.openvex.json`. If the
  drafted patch would touch any other path, call `noop` instead of opening a
  pull request.
* Do not close or relabel the detection issue; the PR links back to it for the
  human reviewer to resolve.
