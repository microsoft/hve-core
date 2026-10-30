// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { join, relative } from "node:path";

import {
  EVALUATION_PROTOCOL, EVALUATION_RUN_DIRECTORY, evaluationModel, parseEvaluationProfile,
  readJson, writeJson, type EvaluationProfile,
} from "./contracts.mts";
import type { EvaluationSummary } from "./runner.mts";
import { selectedConditions, trialDirectory, type EvaluationCondition } from "./conditions.mts";
import { gateSatisfied } from "./scoring.mts";

interface RunManifest {
  readonly protocol: string;
  readonly profile: EvaluationProfile;
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
    readonly condition: EvaluationCondition;
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
 * Produces machine-grounded review, evidence, and update drafts.
 *
 * Debug outputs stay under the run root and never replace production-facing evidence or drafts.
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
  if (summary.schemaVersion !== "2.0.0") {
    throw new Error("Report generation requires condition-aware schema 2.0.0; start a new evaluation run");
  }
  const manifest = await readJson<RunManifest>(join(options.runRoot, "run-manifest.json"));
  const profile = parseEvaluationProfile(summary.profile);
  if (
    summary.protocol !== EVALUATION_PROTOCOL || manifest.protocol !== summary.protocol ||
    manifest.profile !== profile || summary.model !== evaluationModel(profile) ||
    manifest.model !== summary.model || manifest.reasoningEffort !== summary.reasoningEffort ||
    manifest.contextTier !== summary.contextTier ||
    summary.trials.some((trial) =>
      trial.protocol !== summary.protocol || trial.profile !== profile ||
      trial.model !== summary.model || trial.reasoningEffort !== summary.reasoningEffort ||
      trial.contextTier !== summary.contextTier
    )
  ) {
    throw new Error(`Cannot report mixed or historical profiles, models, or protocols; ${EVALUATION_PROTOCOL} provenance must match`);
  }
  if (summary.trials.some((trial) =>
    !["candidate", "abstained", "blocked", "protocol-error", "execution-error"].includes(trial.outcome) ||
    (trial.integrity === "pass"
      ? ["protocol-error", "execution-error"].includes(trial.outcome) || trial.leadingHypothesis?.status === "unusable"
      : !["protocol-error", "execution-error"].includes(trial.outcome)) ||
    !trial.leadingHypothesis || !trial.diagnostic ||
    (trial.outcome === "candidate" && trial.leadingHypothesis.status !== "candidate") ||
    (["abstained", "blocked"].includes(trial.outcome) && trial.leadingHypothesis.status !== "abstained") ||
    (["protocol-error", "execution-error"].includes(trial.outcome) &&
      (!trial.errorCode || trial.leadingHypothesis.status !== "unusable"))
  )) {
    throw new Error("Cannot report missing or inconsistent structured trial outcomes; do not rescore historical results");
  }
  const commands = await readJson<{ commands: readonly CommandRecord[] }>(
    join(options.runRoot, "commands.json"),
  );
  const adjudications = await readOptionalJson<HumanAdjudications>(
    join(options.runRoot, "human-adjudications.json"),
  );
  const excludedRuns = await readOptionalJson<ExcludedRuns>(
    join(options.runRoot, "excluded-runs.json"),
  );
  const costs = await readPremiumRequestCosts(options.runRoot, summary);
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

  const debug = summary.profile === "debug";
  const reviewRoot = debug ? options.runRoot : join(
    options.repositoryRoot,
    ".copilot-tracking",
    "reviews",
    "rca-evaluations",
    options.reviewDate,
  );
  await mkdir(reviewRoot, { recursive: true });
  const reviewPath = join(reviewRoot, debug ? "DEBUG-REVIEW.md" : `${EVALUATION_RUN_DIRECTORY}-review.md`);
  await writeFile(
    reviewPath,
    renderReview(summary, manifest, commands.commands, adjudications),
    "utf8",
  );

  const committedReportPath = debug ? join(options.runRoot, "DEBUG-EVIDENCE.md") : join(
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
      costs,
      options.reviewDate,
    ),
    "utf8",
  );

  const prUpdatePath = join(options.runRoot, debug ? "DEBUG-UPDATE.md" : "PR-3136-UPDATE.md");
  await writeFile(prUpdatePath, renderPrUpdate(summary, commands.commands), "utf8");
  return { committedReportPath, reviewPath, prUpdatePath };
}

function renderCommittedReport(
  summary: EvaluationSummary,
  manifest: RunManifest,
  commands: readonly CommandRecord[],
  adjudications: HumanAdjudications | undefined,
  excludedRuns: ExcludedRuns | undefined,
  costs: Readonly<Record<EvaluationCondition, number | null>>,
  reportDate: string,
): string {
  const caseCount = new Set(summary.trials.map((trial) => trial.caseId)).size;
  const skilled = summary.trials.filter((trial) => trial.condition === "with-skill");
  const strictPasses = skilled.filter((trial) =>
    effectiveStrictPass(trial, adjudications),
  ).length;
  const serviceMatches = summary.trials.filter(
    (trial) => trial.integrity === "pass" && trial.diagnostic.rootCauseService === "match",
  ).length;
  const leadingMatches = summary.trials.filter(
    (trial) => trial.integrity === "pass" && trial.leadingHypothesis?.rootCauseService === "match",
  ).length;
  const leadingAbstentions = summary.trials.filter(
    (trial) => trial.integrity === "pass" && trial.leadingHypothesis?.status === "abstained",
  ).length;
  const selectedCosts = selectedConditions(summary.mode).map((condition) => costs[condition]);
  const authoritativeCost = selectedCosts.some((cost) => cost === null)
    ? "Unavailable"
    : selectedCosts.reduce<number>((total, cost) => total + (cost ?? 0), 0);
  return `---
title: PR 3136 RCAEval evaluation evidence
description: Sanitized evidence from blinded RCAEval skill and skill-free conditions
author: HVE Core Team
ms.date: ${reportDate}
---

# PR 3136 RCAEval evaluation evidence

${profileNotice(summary)}

## Scope

This run evaluated ${caseCount} selected RCAEval fault-injection cases with scheduled trials per
case in the \`${summary.mode}\` condition selection. It used \`${summary.model}\` with medium reasoning
effort and the default context tier. Strict RCA workflow gates apply only to the skilled
condition; both conditions use the same held-out correctness extraction and safety checks.

The cases are controlled faults on microservice testbeds, not organic production incidents.
${summary.trials.length} recorded session results cannot establish a general RCA accuracy rate.
Aborted sessions are failures, not completed RCA analyses.

## Provenance

| Item | Value |
|------|-------|
| Repository commit | \`${manifest.repositoryCommit}\` |
| RCAEval revision | \`${manifest.sourceRevision}\` |
| Dataset source and license | [phamquiluan/RCAEval](https://huggingface.co/datasets/phamquiluan/RCAEval), MIT |
| Protocol | \`${summary.protocol}\` |
| Evaluation profile | \`${summary.profile}\` |
| Model | \`${manifest.model}\` |
| Reasoning effort | \`${manifest.reasoningEffort}\` |
| Context tier | \`${manifest.contextTier}\` |
| Node.js | \`${manifest.nodeVersion}\` |
| Copilot CLI | \`${cliVersions(summary).join(", ") || "Unavailable"}\` |
| Parquet reader | \`${manifest.readerBundleIdentity}\` |
| Package lock SHA-256 | \`${manifest.packageLockSha256}\` |
| Input fingerprint | \`${manifest.inputFingerprint}\` |
| Authoritative run premium requests | ${authoritativeCost} |
| Latest round execution status | ${summary.roundExecution?.status ?? "Unavailable - not recorded"} |
| Remaining sessions in latest round | ${summary.roundExecution?.remainingSessions ?? "Unavailable - not recorded"} |

## Commands

| Command | Exit code | Purpose |
|---------|----------:|---------|
${commands.map((item) => `| \`${escapeTable(item.command)}\` | ${item.exitCode} | ${escapeTable(item.purpose)} |`).join("\n")}

## Results

${renderConditionComparison(summary, costs)}

| Condition | Case | Trial | Integrity | Strict gates | Set A service | Set B service | Set B status | Outcome and error | Correct cause tested | Human review |
|-----------|------|------:|-----------|--------------|---------------|---------------|--------------|-------------------|----------------------|--------------|
${summary.trials.map((trial) => renderTrialRow(trial, adjudications)).join("\n")}

Strict gates passed in ${strictPasses} of ${skilled.length} skilled sessions. The held-out
root-cause service matched in Set A for ${serviceMatches} sessions and in Set B for
${leadingMatches} sessions. Set B abstained in ${leadingAbstentions} sessions. These are exact run
counts, not population accuracy estimates.
Technical protocol and execution failures have no usable diagnosis and are not abstentions.
Blocked outcomes are valid evidence blockers, distinct from technical failures.
Whether the correct cause was tested requires human review; the machine report does not establish test execution.

Round-one checkpoint: **${summary.roundOneCheckpoint?.decision ?? "Unavailable"}**.
${
  adjudications
    ? "Human adjudications are recorded separately; the original machine checkpoint is preserved."
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
* Raw telemetry, prompts, transcripts, tool payloads, credentials, and host paths are excluded
  from this committed report.
* Human diagnostic compatibility, unsupported-claim review, and CR-16 disposition are pending.
${adjudications ? `* Human adjudication criterion: ${adjudications.criterion}` : "* No human gate adjudications were supplied."}

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
# RCAEval Human Review

${profileNotice(summary)}

## Run Identity

* Run ID: \`${summary.runId}\`
* Protocol: \`${summary.protocol}\`
* Evaluation profile: \`${summary.profile}\`
* Model: \`${summary.model}\`
* Repository commit: \`${manifest.repositoryCommit}\`
* Input fingerprint: \`${manifest.inputFingerprint}\`
* Trial count: ${summary.trials.length}
* Conditions: ${summary.mode}
* Round-one decision: ${summary.roundOneCheckpoint?.decision ?? "Unavailable"}

## Commands

${commands.map((item) => `* \`${item.command}\`: exit ${item.exitCode}, ${item.purpose}`).join("\n")}

## Trial Review

| Condition | Case | Trial | Machine integrity | Machine strict gates | Set A service | Set B service | Set B status | Outcome and error | Human disposition | Reviewer rationale |
|-----------|------|------:|-------------------|----------------------|---------------|---------------|--------------|-------------------|-------------------|--------------------|
${summary.trials
  .map(
    (trial) =>
      `| ${trial.condition} | ${trial.caseId} | ${trial.trial} | ${trial.integrity} | ${formatStrict(trial, adjudications)} | ${formatSetAService(trial)} | ${formatComparisonService(trial, "leadingHypothesis")} | ${trial.leadingHypothesis.status} | ${formatOutcome(trial)} | Pending | Pending |`,
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
  return `## ${summary.profile === "debug" ? "RCA harness debug run" : "CR-16 model-backed RCA evaluation"}

${profileNotice(summary)}

Executed ${summary.trials.length} blinded sessions across ${caseCount} selected RCAEval fault-injection
cases using \`${summary.model}\`, medium reasoning effort, and the default context tier.
Profile: \`${summary.profile}\`. Protocol: \`${summary.protocol}\`.
Condition selection: \`${summary.mode}\`. See the evidence report for condition-separated
outcomes and matched-pair differences; no general skill-effectiveness claim is implied.
Outcomes: ${summary.trials.filter((trial) => trial.outcome === "candidate").length} candidates,
${summary.trials.filter((trial) => trial.outcome === "abstained").length} abstentions,
${summary.trials.filter((trial) => trial.outcome === "blocked").length} evidence blockers,
${summary.trials.filter((trial) => trial.outcome === "protocol-error").length} protocol failures,
${summary.trials.filter((trial) => trial.outcome === "execution-error").length} execution failures.

### Validation

${commands.map((item) => `* \`${item.command}\`: ${item.exitCode === 0 ? "passed" : `failed (${item.exitCode})`}`).join("\n")}

Round-one gate: **${summary.roundOneCheckpoint?.decision ?? "Unavailable"}**.

The ${summary.profile === "debug" ? "run-local debug evidence report is `DEBUG-EVIDENCE.md`" : "committed sanitized evidence report is\n`evals/rca-real-world/PR-3136-EVIDENCE.md`"}. It separates strict workflow conformance from
descriptive held-out diagnostics and discloses fixture approvals, statistical inapplicability,
the preflight model probe, and benchmark limitations.

Human review and CR-16 disposition remain pending. ${summary.profile === "debug" ? "Do not use this debug run to establish CR-16 efficacy." : "Please reassess CR-16 against the committed evidence."}
This update does not claim a general RCA accuracy rate, resolve review threads, or close
issue #3134.
`;
}

function profileNotice(summary: EvaluationSummary): string {
  return summary.profile === "debug"
    ? "**DEBUG RUN: harness diagnostics only; not skill efficacy evidence. Do not pool with production evaluations or historical protocols.**"
    : `**Production evaluation run: ${EVALUATION_PROTOCOL} only; do not pool with debug runs or historical protocols.**`;
}

function renderTrialRow(
  trial: EvaluationSummary["trials"][number],
  adjudications: HumanAdjudications | undefined,
): string {
  return `| ${trial.condition} | ${trial.caseId} | ${trial.trial} | ${trial.integrity} | ${formatStrict(trial, adjudications)} | ${formatSetAService(trial)} | ${formatComparisonService(trial, "leadingHypothesis")} | ${trial.leadingHypothesis.status} | ${formatOutcome(trial)} | ${trial.condition === "without-skill" ? "N/A (workflow)" : trial.diagnostic.correctCauseTested} | ${trial.humanReview} |`;
}

function formatSetAService(trial: EvaluationSummary["trials"][number]): string {
  return trial.condition === "without-skill" ? "N/A (not requested)" : formatComparisonService(trial, "diagnostic");
}

function formatOutcome(trial: EvaluationSummary["trials"][number]): string {
  return escapeTable([trial.outcome, trial.errorCode, trial.reason].filter(Boolean).join(": "));
}

function formatStrict(
  trial: EvaluationSummary["trials"][number],
  adjudications: HumanAdjudications | undefined,
): string {
  const failed = Object.entries(trial.strictGates)
    .filter(([gate, value]) => !gateSatisfied(trial.condition, gate, value));
  return effectiveStrictPass(trial, adjudications)
    ? trial.condition === "without-skill" ? "pass; skill workflow N/A" : "pass"
    : trial.integrity !== "pass" ? "unusable (integrity failure)" : `${failed.length} not passed`;
}

function effectiveStrictPass(
  trial: EvaluationSummary["trials"][number],
  _adjudications: HumanAdjudications | undefined,
): boolean {
  const failed = Object.entries(trial.strictGates)
    .filter(([gate, value]) => !gateSatisfied(trial.condition, gate, value))
    .map(([gate]) => gate);
  return trial.integrity === "pass" &&
    !["protocol-error", "execution-error"].includes(trial.outcome) && failed.length === 0;
}

async function readPremiumRequestCosts(
  runRoot: string,
  summary: EvaluationSummary,
): Promise<Record<EvaluationCondition, number | null>> {
  const costs: Record<EvaluationCondition, number | null> = { "with-skill": 0, "without-skill": 0 };
  for (const trial of summary.trials) {
    const artifact = await readJson<{
      protocol?: string;
      requestedProfile?: { evaluationProfile?: EvaluationProfile; model?: string };
      cliCapture?: Readonly<Record<string, unknown>>;
    }>(
      join(trialDirectory(runRoot, trial.caseId, trial.trial, trial.condition), "session-artifact.json"),
    );
    if (
      artifact.protocol !== summary.protocol ||
      artifact.requestedProfile?.evaluationProfile !== summary.profile ||
      artifact.requestedProfile?.model !== summary.model
    ) {
      throw new Error("Cannot report mixed session profiles, models, or protocols");
    }
    const usages = Object.entries(artifact.cliCapture ?? {})
      .filter(([key]) => /^usageTurn\d+$/.test(key))
      .sort(([left], [right]) => Number(right.slice(9)) - Number(left.slice(9)));
    const cost = usages.map(([, usage]) =>
      usage && typeof usage === "object" && "totalPremiumRequestCost" in usage
        ? usage.totalPremiumRequestCost : undefined
    ).find((value) => typeof value === "number" && Number.isFinite(value) && value >= 0);
    const previous = costs[trial.condition];
    costs[trial.condition] = previous === null ||
      typeof cost !== "number" || !Number.isFinite(cost) || cost < 0
      ? null
      : previous + cost;
  }
  return costs;
}

function renderConditionComparison(
  summary: EvaluationSummary,
  costs: Readonly<Record<EvaluationCondition, number | null>>,
): string {
  const rows = selectedConditions(summary.mode).map((condition) => {
    const trials = summary.trials.filter((trial) => trial.condition === condition);
    const setAMatches = condition === "without-skill"
      ? "N/A (not requested)"
      : trials.filter((trial) => trial.integrity === "pass" && trial.diagnostic.rootCauseService === "match").length;
    return `| ${condition} | ${trials.length} | ${trials.filter((trial) => trial.integrity !== "pass").length} | ${setAMatches} | ${trials.filter((trial) => trial.integrity === "pass" && trial.leadingHypothesis.rootCauseService === "match").length} | ${costs[condition] ?? "Unavailable"} |`;
  });
  const table = [
    "| Condition | Sessions | Integrity failures | Set A service matches | Set B service matches | Premium requests |",
    "|-----------|---------:|-------------------:|----------------------:|----------------------:|-----------------:|",
    ...rows,
  ].join("\n");
  if (summary.mode !== "both") {
    return `${table}\n\nSingle-condition run: no paired skill-lift estimate is available.\n`;
  }
  const pairKeys = new Set(summary.trials.map((trial) => `${trial.caseId}/${trial.trial}`));
  const comparisonRows: string[] = [];
  const pairs = [...pairKeys].flatMap((key) => {
    const trials = summary.trials.filter((trial) => `${trial.caseId}/${trial.trial}` === key);
    const skilled = trials.find((trial) => trial.condition === "with-skill");
    const baseline = trials.find((trial) => trial.condition === "without-skill");
    const [caseId, trialNumber] = key.split("/");
    comparisonRows.push(
      `| ${caseId} | ${trialNumber} | ${formatComparisonService(baseline, "leadingHypothesis")} | ${formatComparisonService(skilled, "diagnostic")} | ${formatComparisonService(skilled, "leadingHypothesis")} |`,
    );
    return skilled?.integrity === "pass" && baseline?.integrity === "pass"
      ? [{ skilled, baseline }]
      : [];
  });
  const skillOnly = pairs.filter(({ skilled, baseline }) =>
    skilled.leadingHypothesis.rootCauseService === "match" && baseline.leadingHypothesis.rootCauseService !== "match",
  ).length;
  const baselineOnly = pairs.filter(({ skilled, baseline }) =>
    baseline.leadingHypothesis.rootCauseService === "match" && skilled.leadingHypothesis.rootCauseService !== "match",
  ).length;
  const difference = pairs.length === 0 ? "Unavailable" : (100 * (skillOnly - baselineOnly) / pairs.length).toFixed(1);
  return `${table}

| Case | Trial | Unskilled best guess | Skilled Set A | Skilled Set B |
|------|------:|----------------------|---------------|---------------|
${comparisonRows.join("\n")}

Each case and trial shows all three results. Unskilled best guesses correspond to skilled
Set B, not Set A's finding authority. Unassessed means no diagnostic attribution was established
or reported, not an incorrect service guess. Incomplete or invalid sessions have no usable result;
they are distinct from an unassessed finding or a wrong diagnosis. Not-run sessions remain visible.

| Correctness metric | Valid pairs | Skill-only matches | Baseline-only matches | Skill minus baseline (percentage points) |
|--------------------|------------:|-------------------:|----------------------:|----------------------------------------:|
| Set B service | ${pairs.length} | ${skillOnly} | ${baselineOnly} | ${difference} |

Pairs match the same case and trial; both sessions must pass integrity.
Excluded incomplete or invalid pairs: ${pairKeys.size - pairs.length}.
Unassessed diagnoses and abstentions are not matches. These are descriptive differences on
selected dependent cases, not statistical significance or a general effectiveness estimate.
The ${EVALUATION_PROTOCOL} autonomous host-mediated evidence protocol and output-schema instructions apply to both
conditions. Skill workflow conformance is not a baseline correctness criterion.
Set B service match compares the skill's leading hypothesis with the baseline's single best
diagnostic guess. The baseline is not asked for Set A; its Set A cells are not applicable,
not diagnostic failures. Set A is reported only for the skilled condition and is not a paired metric.
`;
}

function formatComparisonService(
  trial: EvaluationSummary["trials"][number] | undefined,
  endpoint: "diagnostic" | "leadingHypothesis",
): string {
  if (trial === undefined) {
    return "Not run";
  }
  if (trial.integrity !== "pass") {
    return `Unavailable (${escapeTable(trial.outcome)}${trial.errorCode ? `: ${escapeTable(trial.errorCode)}` : ""})`;
  }
  if (trial.outcome === "blocked") {
    return "Blocked (evidence unavailable; abstained)";
  }
  if (endpoint === "leadingHypothesis") {
    if (trial.leadingHypothesis.status === "abstained") {
      return "No defensible candidate (abstained)";
    }
    if (trial.leadingHypothesis.status === "unusable") {
      return "Unavailable (unusable diagnostic)";
    }
  }
  const result = trial[endpoint];
  if (result.rootCauseService === "unassessed") {
    return "Unassessed";
  }
  return result.extractedService === undefined
    ? result.rootCauseService
    : `${escapeTable(result.extractedService)} (${result.rootCauseService})`;
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
  return value.replaceAll("|", "\\|").replace(/\r?\n/g, " ");
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
