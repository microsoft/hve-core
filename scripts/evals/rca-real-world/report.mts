// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { join, relative } from "node:path";

import { readJson, writeJson } from "./contracts.mts";
import type { EvaluationSummary } from "./runner.mts";

interface RunManifest {
  readonly repositoryCommit: string;
  readonly sourceRevision: string;
  readonly model: string;
  readonly reasoningEffort: string;
  readonly contextTier: string;
  readonly inputFingerprint: string;
  readonly nodeVersion: string;
  readonly readerBundleIdentity: string;
  readonly packageLockSha256: string;
}

interface CommandRecord {
  readonly command: string;
  readonly exitCode: number;
  readonly purpose: string;
}

interface HumanAdjudications {
  readonly criterion: string;
  readonly adjudications: readonly {
    readonly caseId: string;
    readonly trial: number;
    readonly gate: string;
    readonly decision: string;
  }[];
}

interface ExcludedRuns {
  readonly excluded: readonly {
    readonly runId: string;
    readonly modelSessions: number;
    readonly premiumRequestCost: number;
    readonly reason: string;
  }[];
  readonly preflightProbe?: {
    readonly aiCreditsReported?: number;
  };
}

export interface ArtifactScanFinding {
  readonly path: string;
  readonly category: string;
}

/**
 * Scans report and trace text for credentials, absolute home paths, environment capture, and
 * likely personal identifiers.
 */
export async function scanArtifacts(root: string): Promise<readonly ArtifactScanFinding[]> {
  const findings: ArtifactScanFinding[] = [];
  for (const path of await listTextFiles(root)) {
    const text = await readFile(path, "utf8");
    const patterns: readonly [string, RegExp][] = [
      ["credential", /(?:ghp|github_pat|gho|ghu|ghs)_[A-Za-z0-9_]{20,}/g],
      ["authorization", /Bearer\s+[A-Za-z0-9._~+/=-]{16,}/gi],
      ["windows-home-path", /[A-Za-z]:\\Users\\[^\\\s"']+/g],
      ["windows-home-path", /[A-Za-z]:\\\\Users\\\\[^"\s]+/g],
      ["posix-home-path", /\/(?:home|Users)\/[^/\s"']+/g],
      ["environment-value", /"(?:PATH|HOME|USERPROFILE|GITHUB_TOKEN|COPILOT_GITHUB_TOKEN)"\s*:/g],
      ["email-address", /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi],
    ];
    for (const [category, pattern] of patterns) {
      if (pattern.test(text)) {
        findings.push({ path: relative(root, path).replaceAll("\\", "/"), category });
      }
    }
  }
  return findings;
}

/**
 * Produces machine-grounded review, committed evidence, and PR-update drafts.
 *
 * Human judgments remain pending and all human review checkboxes remain unchecked.
 */
export async function generateEvidenceReport(options: {
  readonly repositoryRoot: string;
  readonly runRoot: string;
  readonly reviewDate: string;
}): Promise<{
  readonly committedReportPath: string;
  readonly reviewPath: string;
  readonly prUpdatePath: string;
}> {
  const summary = await readJson<EvaluationSummary>(join(options.runRoot, "evaluation-summary.json"));
  const manifest = await readJson<RunManifest>(join(options.runRoot, "run-manifest.json"));
  const commands = await readJson<{ commands: readonly CommandRecord[] }>(
    join(options.runRoot, "commands.json"),
  );
  const adjudications = await readOptionalJson<HumanAdjudications>(
    join(options.runRoot, "human-adjudications.json"),
  );
  const excludedRuns = await readOptionalJson<ExcludedRuns>(
    join(options.runRoot, "excluded-runs.json"),
  );
  const authoritativeCost = await readPremiumRequestCost(options.runRoot, summary);
  const scanFindings = await scanArtifacts(options.runRoot);
  await writeJson(join(options.runRoot, "artifact-scan.json"), {
    schemaVersion: "1.0.0",
    scannedAt: new Date().toISOString(),
    status: scanFindings.length === 0 ? "pass" : "fail",
    findings: scanFindings,
  });
  if (scanFindings.length > 0) {
    throw new Error(
      `Artifact scan failed: ${scanFindings.map((item) => `${item.path}:${item.category}`).join(", ")}`,
    );
  }

  const reviewRoot = join(
    options.repositoryRoot,
    ".copilot-tracking",
    "reviews",
    "rca-evaluations",
    options.reviewDate,
  );
  await mkdir(reviewRoot, { recursive: true });
  const reviewPath = join(reviewRoot, "rcaeval-three-case-review.md");
  await writeFile(
    reviewPath,
    renderReview(summary, manifest, commands.commands, adjudications),
    "utf8",
  );

  const committedReportPath = join(
    options.repositoryRoot,
    "evals",
    "rca-real-world",
    "PR-3136-EVIDENCE.md",
  );
  await writeFile(
    committedReportPath,
    renderCommittedReport(
      summary,
      manifest,
      commands.commands,
      adjudications,
      excludedRuns,
      authoritativeCost,
      options.reviewDate,
    ),
    "utf8",
  );

  const prUpdatePath = join(options.runRoot, "PR-3136-UPDATE.md");
  await writeFile(prUpdatePath, renderPrUpdate(summary, commands.commands), "utf8");
  return { committedReportPath, reviewPath, prUpdatePath };
}

function renderCommittedReport(
  summary: EvaluationSummary,
  manifest: RunManifest,
  commands: readonly CommandRecord[],
  adjudications: HumanAdjudications | undefined,
  excludedRuns: ExcludedRuns | undefined,
  authoritativeCost: number,
  reportDate: string,
): string {
  const caseCount = new Set(summary.trials.map((trial) => trial.caseId)).size;
  const strictPasses = summary.trials.filter((trial) =>
    effectiveStrictPass(trial, adjudications),
  ).length;
  const serviceMatches = summary.trials.filter(
    (trial) => trial.diagnostic.rootCauseService === "match",
  ).length;
  const leadingMatches = summary.trials.filter(
    (trial) => trial.leadingHypothesis?.rootCauseService === "match",
  ).length;
  const leadingAbstentions = summary.trials.filter(
    (trial) => trial.leadingHypothesis?.status === "abstained",
  ).length;
  return `---
title: PR 3136 RCAEval evaluation evidence
description: Sanitized evidence from blinded RCAEval runs of the root-cause-analysis skill
author: HVE Core Team
ms.date: ${reportDate}
---

# PR 3136 RCAEval evaluation evidence

## Scope

This run evaluated ${caseCount} selected RCAEval fault-injection cases with scheduled trials per
case. It used GPT-5.6 Sol with medium reasoning effort and the default context tier. Strict RCA
workflow gates are reported separately from held-out diagnostic results.

The cases are controlled faults on microservice testbeds, not organic production incidents.
${summary.trials.length} completed sessions cannot establish a general RCA accuracy rate.

## Provenance

| Item | Value |
|------|-------|
| Repository commit | \`${manifest.repositoryCommit}\` |
| RCAEval revision | \`${manifest.sourceRevision}\` |
| Dataset source and license | [phamquiluan/RCAEval](https://huggingface.co/datasets/phamquiluan/RCAEval), MIT |
| Model | \`${manifest.model}\` |
| Reasoning effort | \`${manifest.reasoningEffort}\` |
| Context tier | \`${manifest.contextTier}\` |
| Node.js | \`${manifest.nodeVersion}\` |
| Copilot CLI | \`${cliVersions(summary).join(", ") || "Unavailable"}\` |
| Parquet reader | \`${manifest.readerBundleIdentity}\` |
| Package lock SHA-256 | \`${manifest.packageLockSha256}\` |
| Input fingerprint | \`${manifest.inputFingerprint}\` |
| Authoritative run premium requests | ${authoritativeCost} |

## Commands

| Command | Exit code | Purpose |
|---------|----------:|---------|
${commands.map((item) => `| \`${escapeTable(item.command)}\` | ${item.exitCode} | ${escapeTable(item.purpose)} |`).join("\n")}

## Results

| Case | Trial | Integrity | Strict gates | Set A service | Set B service | Set B status | Correct cause tested | Human review |
|------|------:|-----------|--------------|---------------|---------------|--------------|----------------------|--------------|
${summary.trials.map((trial) => renderTrialRow(trial, adjudications)).join("\n")}

Strict gates passed in ${strictPasses} of ${summary.trials.length} completed sessions. The held-out
root-cause service matched in Set A for ${serviceMatches} sessions and in Set B for
${leadingMatches} sessions. Set B abstained in ${leadingAbstentions} sessions. These are exact run
counts, not population accuracy estimates.

Round-one checkpoint: **${summary.roundOneCheckpoint?.decision ?? "Unavailable"}**.
${
  adjudications
    ? "The machine wording gate paused round one; the repository user reviewed the exact authorization statements and recorded an effective continue decision."
    : (summary.roundOneCheckpoint?.reasons ?? []).map((reason) => `* ${reason}`).join("\n") ||
      "* No machine gate required a pause."
}

## Approval and statistical boundaries

Every approval is labelled as a simulated evaluation fixture and persisted in a separate ledger.
The run tests approval-protocol conformance only. It does not establish live authorization,
authenticated human approval, or production access.

The case rows are dependent time-series observations from one injected incident. They do not meet
the independent affected-versus-unaffected observational-unit contract. A conforming run reports
the statistical companion as not applicable or blocked and does not invent a p-value.

## Limitations and review status

${summary.limitations.map((limitation) => `* ${limitation}`).join("\n")}
* The preflight configuration probe made before the evaluation consumed 16.93 AI credits and is
  disclosed separately from the scheduled trials.
* Raw telemetry, prompts, transcripts, tool payloads, credentials, and host paths are excluded
  from this committed report.
* Human diagnostic compatibility, unsupported-claim review, and CR-16 disposition are pending.
* Machine scoring initially rejected the simulated-authority wording. The repository user
  adjudicated all nine semantically equivalent fixture-boundary statements as passing under this
  criterion: ${adjudications?.criterion ?? "Unavailable"}

### Excluded harness-development runs

| Run | Model sessions | Premium requests | Exclusion reason |
|-----|---------------:|-----------------:|------------------|
${(excludedRuns?.excluded ?? []).map((item) => `| \`${item.runId}\` | ${item.modelSessions} | ${item.premiumRequestCost} | ${escapeTable(item.reason)} |`).join("\n")}

The separate preflight probe reported ${excludedRuns?.preflightProbe?.aiCreditsReported ?? "Unavailable"}
AI credits and is excluded because it was not an evaluation session.

- [ ] Reviewed and validated by a qualified human reviewer

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
`;
}

function renderReview(
  summary: EvaluationSummary,
  manifest: RunManifest,
  commands: readonly CommandRecord[],
  adjudications: HumanAdjudications | undefined,
): string {
  return `<!-- markdownlint-disable-file -->
# RCAEval Three-Case Human Review

## Run Identity

* Run ID: \`${summary.runId}\`
* Repository commit: \`${manifest.repositoryCommit}\`
* Input fingerprint: \`${manifest.inputFingerprint}\`
* Trial count: ${summary.trials.length}
* Round-one decision: ${summary.roundOneCheckpoint?.decision ?? "Unavailable"}

## Commands

${commands.map((item) => `* \`${item.command}\`: exit ${item.exitCode}, ${item.purpose}`).join("\n")}

## Trial Review

| Case | Trial | Machine integrity | Machine strict gates | Set A service | Set B service | Set B status | Human disposition | Reviewer rationale |
|------|------:|-------------------|----------------------|---------------|---------------|--------------|-------------------|--------------------|
${summary.trials
  .map(
    (trial) =>
      `| ${trial.caseId} | ${trial.trial} | ${trial.integrity} | ${formatStrict(trial, adjudications)} | ${trial.diagnostic.rootCauseService} | ${trial.leadingHypothesis?.rootCauseService ?? "not-reported"} | ${trial.leadingHypothesis?.status ?? "not-reported"} | Pending | Pending |`,
  )
  .join("\n")}

## Required Human Decisions

* Confirm or revise every compatible-mechanism judgment with cited trace evidence.
* Review unsupported causal, authorization, statistical, and completion claims.
* Record disagreements without rewriting model output.
* Decide whether the bounded evidence satisfies CR-16.
* Decide separately whether any issue closure condition is met.

- [ ] Reviewed and validated by a qualified human reviewer
`;
}

function renderPrUpdate(
  summary: EvaluationSummary,
  commands: readonly CommandRecord[],
): string {
  const caseCount = new Set(summary.trials.map((trial) => trial.caseId)).size;
  return `## CR-16 model-backed RCA evaluation

Executed ${summary.trials.length} blinded sessions across ${caseCount} selected RCAEval fault-injection
cases using GPT-5.6 Sol, medium reasoning effort, and the default context tier.

### Validation

${commands.map((item) => `* \`${item.command}\`: ${item.exitCode === 0 ? "passed" : `failed (${item.exitCode})`}`).join("\n")}

Round-one gate: **${summary.roundOneCheckpoint?.decision ?? "Unavailable"}**.

The committed sanitized evidence report is
\`evals/rca-real-world/PR-3136-EVIDENCE.md\`. It separates strict workflow conformance from
descriptive held-out diagnostics and discloses fixture approvals, statistical inapplicability,
the preflight model probe, and benchmark limitations.

Human review and CR-16 disposition remain pending. Please reassess CR-16 against the committed
evidence. This update does not claim a general RCA accuracy rate, resolve review threads, or close
issue #3134.
`;
}

function renderTrialRow(
  trial: EvaluationSummary["trials"][number],
  adjudications: HumanAdjudications | undefined,
): string {
  return `| ${trial.caseId} | ${trial.trial} | ${trial.integrity} | ${formatStrict(trial, adjudications)} | ${trial.diagnostic.rootCauseService} | ${trial.leadingHypothesis?.rootCauseService ?? "not-reported"} | ${trial.leadingHypothesis?.status ?? "not-reported"} | ${trial.diagnostic.correctCauseTested} | ${trial.humanReview} |`;
}

function formatStrict(
  trial: EvaluationSummary["trials"][number],
  adjudications: HumanAdjudications | undefined,
): string {
  const values = Object.values(trial.strictGates);
  return effectiveStrictPass(trial, adjudications)
    ? values.every((value) => value === true)
      ? "pass"
      : "pass (human-adjudicated wording)"
    : `${values.filter((value) => value !== true).length} not passed`;
}

function effectiveStrictPass(
  trial: EvaluationSummary["trials"][number],
  adjudications: HumanAdjudications | undefined,
): boolean {
  const failed = Object.entries(trial.strictGates)
    .filter(([, value]) => value !== true)
    .map(([gate]) => gate);
  if (failed.length === 0) {
    return true;
  }
  return (
    failed.length === 1 &&
    failed[0] === "approvalClearlySimulated" &&
    adjudications?.adjudications.some(
      (item) =>
        item.caseId === trial.caseId &&
        item.trial === trial.trial &&
        item.gate === "approvalClearlySimulated" &&
        item.decision === "pass",
    ) === true
  );
}

async function readPremiumRequestCost(
  runRoot: string,
  summary: EvaluationSummary,
): Promise<number> {
  let cost = 0;
  for (const trial of summary.trials) {
    const artifact = await readJson<{
      cliCapture?: {
        usageTurn2?: { totalPremiumRequestCost?: number };
        usageTurn3?: { totalPremiumRequestCost?: number };
        usageTurn4?: { totalPremiumRequestCost?: number };
      };
    }>(
      join(runRoot, "sessions", trial.caseId, `trial-${trial.trial}`, "session-artifact.json"),
    );
    cost +=
      artifact.cliCapture?.usageTurn4?.totalPremiumRequestCost ??
      artifact.cliCapture?.usageTurn3?.totalPremiumRequestCost ??
      artifact.cliCapture?.usageTurn2?.totalPremiumRequestCost ??
      0;
  }
  return cost;
}

async function readOptionalJson<T>(path: string): Promise<T | undefined> {
  try {
    return await readJson<T>(path);
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return undefined;
    }
    throw error;
  }
}

function escapeTable(value: string): string {
  return value.replaceAll("|", "\\|");
}

function cliVersions(summary: EvaluationSummary): string[] {
  return [
    ...new Set(
      summary.trials
        .map((trial) => {
          const status = trial.runtime?.clientStatus as { cliVersion?: unknown } | undefined;
          return typeof status?.cliVersion === "string" ? status.cliVersion : undefined;
        })
        .filter((value): value is string => typeof value === "string"),
    ),
  ];
}

async function listTextFiles(root: string): Promise<readonly string[]> {
  const result: string[] = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "inputs") {
        continue;
      }
      result.push(...(await listTextFiles(path)));
    } else if (entry.isFile() && /\.(?:json|jsonl|md|txt)$/i.test(entry.name)) {
      result.push(path);
    }
  }
  return result;
}
