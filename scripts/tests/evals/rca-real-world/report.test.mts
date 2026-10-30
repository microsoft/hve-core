// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { test } from "node:test";

import { generateEvidenceReport, scanArtifacts } from "../../../evals/rca-real-world/report.mts";
import { parseReportArguments } from "../../../evals/rca-real-world/report-cli.mts";
import { trialDirectory } from "../../../evals/rca-real-world/conditions.mts";
import { EVALUATION_PROTOCOL, readJson, writeJson } from "../../../evals/rca-real-world/contracts.mts";
import type { EvaluationSummary } from "../../../evals/rca-real-world/runner.mts";
import { scoreTrial } from "../../../evals/rca-real-world/scoring.mts";
import type { TrialResult } from "../../../evals/rca-real-world/scoring.mts";
import type { TrialArtifact } from "../../../evals/rca-real-world/orchestrator.mts";
import { parseModelMessages, type DiagnosticReport } from "../../../evals/rca-real-world/communication.mts";

test("report CLI defaults to the current UTC day and preserves explicit date overrides", () => {
  const now = new Date("2026-10-26T23:55:00-07:00");
  assert.deepEqual(parseReportArguments(["--run-id", "fixture"], now), {
    runId: "fixture",
    reviewDate: "2026-10-27",
  });
  assert.deepEqual(parseReportArguments([
    "--run-id", "fixture", "--date", "2026-10-19",
  ], now), { runId: "fixture", reviewDate: "2026-10-19" });
  assert.equal(
    parseReportArguments(["--run-id", "fixture"]).reviewDate,
    new Date().toISOString().slice(0, 10),
  );
  assert.throws(() => parseReportArguments([], now), /Usage:/);
});

async function reportFixture(): Promise<{
  readonly repositoryRoot: string;
  readonly runRoot: string;
}> {
  const fixtureRoot = join(process.cwd(), ".copilot-tracking", "evaluations", "communication-hardening-20261029");
  await mkdir(fixtureRoot, { recursive: true });
  const repositoryRoot = await mkdtemp(join(fixtureRoot, "rca-report-repo-"));
  const runRoot = join(repositoryRoot, ".copilot-tracking", "evaluations", "run");
  await mkdir(runRoot, { recursive: true });
  await mkdir(join(repositoryRoot, "evals", "rca-real-world"), { recursive: true });
  await writeFile(
    join(runRoot, "run-manifest.json"),
    JSON.stringify({
      protocol: EVALUATION_PROTOCOL,
      profile: "production",
      repositoryCommit: "a".repeat(40),
      sourceRevision: "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e",
      model: "gpt-5.6-sol",
      reasoningEffort: "medium",
      contextTier: "default",
      inputFingerprint: "b".repeat(64),
      nodeVersion: "v24.14.0",
      readerBundleIdentity: "hyparquet@1.31.5:fixture",
      packageLockSha256: "c".repeat(64),
    }),
    "utf8",
  );
  await writeFile(
    join(runRoot, "commands.json"),
    JSON.stringify({
      commands: [
        {
          command: "npm run ci:rca-eval -- --run-id fixture --round 1",
          exitCode: 0,
          purpose: "Execute round one",
        },
      ],
    }),
    "utf8",
  );
  const report: DiagnosticReport = {
    candidate: { target: "adservice", mechanism: "cpu", confidence: "Medium; bounded fixture." },
    finding: { status: "ready-for-human-sign-off", target: "adservice", mechanism: "cpu" },
    authority: { simulated: true, productionAuthorization: false },
    limitations: ["Human review pending."],
    narrative: [
      "1. Status and Finding", "2. Source Coverage", "3. Hypotheses Tested", "4. Executed Tests and Evidence",
      "5. Causal Account and Gate", "6. Actions and Open Decisions", "7. Authorization and Execution Audit",
      "8. Resume Checkpoint", "Dependent observations; statistics N/A. Evidence gaps require human review.",
    ].join("\n"),
  };
  const messageId = "fixture/with-skill/case-01/trial-1/turn-1";
  const response = JSON.stringify({
    protocol: EVALUATION_PROTOCOL, messageId, caseId: "case-01", messageType: "final", report,
  });
  const parsed = parseModelMessages([response], { messageId, caseId: "case-01", condition: "with-skill" });
  const event = { type: "assistant.message", data: { content: response, phase: "final_answer" } };
  const artifact: TrialArtifact & { cliCapture: Record<string, unknown> } = {
    schemaVersion: "2.0.0", protocol: EVALUATION_PROTOCOL, runId: "fixture", caseId: "case-01",
    condition: "with-skill", trial: 1,
    requestedProfile: {
      evaluationProfile: "production", model: "gpt-5.6-sol", reasoningEffort: "medium", contextTier: "default",
    },
    preflight: { modelAvailable: true, reasoningEffortAvailable: true, clientStatus: {} },
    report, firstResponse: response, finalResponse: report.narrative, responses: [response], endReason: "complete",
    communication: { protocol: EVALUATION_PROTOCOL, outcome: "final", turns: [{
      messageId, messageType: "final", messageIndex: 0, messageHash: parsed.messageHash, requestIds: [],
    }] },
    events: [event], evidenceToolTraces: [],
    approvalLedger: { schemaVersion: "1.0.0", authority: "simulated-protocol-fixture", establishesProductionAuthorization: false, records: [] },
    hashes: { promptSha256: "a".repeat(64), skillBundleSha256: "b".repeat(64), toolContractSha256: "c".repeat(64) },
    cliCapture: {
      turn1: { exitCode: 0, timedOut: false, stdout: JSON.stringify(event), stderr: "", durationMs: 1 },
      usageTurn1: { totalPremiumRequestCost: 2 },
    },
    redactionManifest: { applied: [], replacements: 0 },
  };
  const trial = scoreTrial(artifact, {
    neutralId: "case-01", sourcePath: "held-out-source", rootCauseService: "adservice",
    fault: "cpu", compatibleMechanism: "CPU saturation",
  }, "fixture");
  assert.equal(trial.integrity, "pass");
  const summary: EvaluationSummary = {
      schemaVersion: "2.0.0",
      protocol: EVALUATION_PROTOCOL,
      profile: "production",
      mode: "with-skill",
      runId: "fixture",
      sourceRevision: "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e",
      model: "gpt-5.6-sol",
      reasoningEffort: "medium",
      contextTier: "default",
      trialOrder: [],
      trials: [trial],
      roundOneCheckpoint: { decision: "continue", reasons: [] },
      roundExecution: {
        round: 1, status: "paused-technical-failures", attemptedSessions: 2, remainingSessions: 8,
        consecutiveTechnicalFailures: 2, artifactHashes: {}, pauses: [], continuations: [],
      },
      limitations: ["Selected cases are not a population estimate."],
  };
  await writeJson(join(runRoot, "evaluation-summary.json"), summary);
  const sessionRoot = trialDirectory(runRoot, "case-01", 1, "with-skill");
  await mkdir(sessionRoot, { recursive: true });
  await writeJson(join(sessionRoot, "session-artifact.json"), artifact);
  return { repositoryRoot, runRoot };
}

test("generates sanitized evidence while preserving human-owned checkboxes", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const result = await generateEvidenceReport({
    ...fixture,
    reviewDate: "2026-10-19",
  });
  assert.equal(result.committedReportPath, join(fixture.repositoryRoot, "evals", "rca-real-world", "PR-3136-EVIDENCE.md"));
  assert.equal(result.prUpdatePath, join(fixture.runRoot, "PR-3136-UPDATE.md"));
  const committed = await readFile(result.committedReportPath, "utf8");
  const review = await readFile(result.reviewPath, "utf8");
  const prUpdate = await readFile(result.prUpdatePath, "utf8");
  assert.match(committed, /Strict gates passed in 1 of 1 skilled sessions/);
  assert.match(committed, /Set A service \| Set B service \| Set B status/);
  assert.match(committed, /matched in Set A for 1 sessions and in Set B for\s+1 sessions/);
  assert.doesNotMatch(committed, /16\.93 AI credits|all nine/);
  assert.match(committed, /Single-condition run: no paired skill-lift estimate/);
  assert.match(committed, /Latest round execution status \| paused-technical-failures/);
  assert.match(committed, /Remaining sessions in latest round \| 8/);
  assert.match(committed, /Aborted sessions are failures, not completed RCA analyses/);
  assert.match(committed, /- \[ \] Reviewed and validated/);
  assert.doesNotMatch(committed, /- \[x\]/i);
  assert.match(review, /Human disposition \| Reviewer rationale/);
  assert.match(prUpdate, /Please reassess CR-16/);
});

test("reports condition costs and matched correctness differences without mixing workflow gates", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  const skilled = summary.trials[0]!;
  const baseline = {
    ...skilled,
    condition: "without-skill" as const,
    diagnostic: { ...skilled.diagnostic, rootCauseService: "unassessed" as const },
    strictGates: {
      ...skilled.strictGates,
      statisticalApplicability: "not-applicable" as const,
      noUnsupportedComplete: "not-applicable" as const,
      honestEvidenceGaps: "not-applicable" as const,
    },
  };
  await writeJson(summaryPath, { ...summary, mode: "both", trials: [skilled, baseline] });
  const baselineRoot = trialDirectory(fixture.runRoot, "case-01", 1, "without-skill");
  await mkdir(baselineRoot, { recursive: true });
  await writeJson(join(baselineRoot, "session-artifact.json"), {
    protocol: EVALUATION_PROTOCOL,
    requestedProfile: { evaluationProfile: "production", model: "gpt-5.6-sol" },
    cliCapture: { usageTurn4: { totalPremiumRequestCost: 3 } },
  });
  const result = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-26" });
  const report = await readFile(result.committedReportPath, "utf8");
  assert.match(report, /\| with-skill \| 1 \| 0 \| 1 \| 1 \| 2 \|/);
  assert.match(report, /\| without-skill \| 1 \| 0 \| N\/A \(not requested\) \| 1 \| 3 \|/);
  assert.doesNotMatch(report, /\| Set A service \| 1 \|/);
  assert.match(report, /\| Set B service \| 1 \| 0 \| 0 \| 0\.0 \|/);
  assert.match(report, /\| Case \| Trial \| Unskilled best guess \| Skilled Set A \| Skilled Set B \|/);
  assert.match(report, /\| case-01 \| 1 \| adservice \(match\) \| adservice \(match\) \| adservice \(match\) \|/);
  assert.match(report, /\| without-skill \| case-01 \| 1 \| pass \| pass; skill workflow N\/A \| N\/A \(not requested\) \| adservice \(match\) \| candidate \|/);
  assert.match(await readFile(result.reviewPath, "utf8"), /N\/A \(not requested\)/);
  assert.match(report, /Authoritative run premium requests \| 5/);
  assert.match(report, /pass; skill workflow N\/A/);

  await writeJson(summaryPath, {
    ...summary, mode: "both", trials: [skilled, {
      ...baseline, integrity: "fail", outcome: "protocol-error", errorCode: "invalid-report",
      leadingHypothesis: { ...baseline.leadingHypothesis, status: "unusable" },
    }],
  });
  await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-26" });
  const invalid = await readFile(result.committedReportPath, "utf8");
  assert.match(invalid, /Excluded incomplete or invalid pairs: 1/);
  assert.match(invalid, /\| Set B service \| 0 \| 0 \| 0 \| Unavailable \|/);
  assert.match(invalid, /\| case-01 \| 1 \| Unavailable \(protocol-error: invalid-report\) \| adservice \(match\) \| adservice \(match\) \|/);
});

test("keeps all three case results distinct when Set A is unassessed or a session is missing", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  const skilled = summary.trials[0]!;
  const baseline = {
    ...skilled,
    condition: "without-skill" as const,
    leadingHypothesis: {
      ...skilled.leadingHypothesis,
      rootCauseService: "miss" as const,
      extractedService: "other-service",
    },
  };
  await writeJson(summaryPath, {
    ...summary,
    mode: "both",
    trials: [{
      ...skilled,
      diagnostic: { ...skilled.diagnostic, rootCauseService: "unassessed" },
      leadingHypothesis: { ...skilled.leadingHypothesis, extractedService: "expected|service" },
    }, baseline, {
      ...skilled, caseId: "case-02", integrity: "fail", outcome: "execution-error", errorCode: "execution-failed",
      leadingHypothesis: { ...skilled.leadingHypothesis, status: "unusable" },
    }],
  });
  for (const [condition, caseId] of [
    ["without-skill", "case-01"], ["with-skill", "case-02"],
  ] as const) {
    const sessionRoot = trialDirectory(fixture.runRoot, caseId, 1, condition);
    await mkdir(sessionRoot, { recursive: true });
    await writeJson(join(sessionRoot, "session-artifact.json"), {
      protocol: EVALUATION_PROTOCOL,
      requestedProfile: { evaluationProfile: "production", model: "gpt-5.6-sol" },
      cliCapture: { usageTurn4: { totalPremiumRequestCost: 1 } },
    });
  }
  const result = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-28" });
  const report = await readFile(result.committedReportPath, "utf8");
  assert.match(report, /\| case-01 \| 1 \| other-service \(miss\) \| Unassessed \| expected\\\|service \(match\) \|/);
  assert.match(report, /\| case-02 \| 1 \| Not run \| Unavailable \(execution-error: execution-failed\) \| Unavailable \(execution-error: execution-failed\) \|/);
  assert.doesNotMatch(report, /\| Set A service \| 1 \|/);
});

test("reports missing usage as unavailable rather than a zero-cost run", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  await writeJson(
    join(trialDirectory(fixture.runRoot, "case-01", 1, "with-skill"), "session-artifact.json"),
    {
      protocol: EVALUATION_PROTOCOL,
      requestedProfile: { evaluationProfile: "production", model: "gpt-5.6-sol" },
      cliCapture: {},
    },
  );
  const result = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-26" });
  assert.match(await readFile(result.committedReportPath, "utf8"), /Authoritative run premium requests \| Unavailable/);
});

test("displays evidence blockers and abstentions separately from explicit technical errors", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  const original = summary.trials[0]!;
  const outcomes = ["blocked", "abstained", "protocol-error", "execution-error", "candidate"] as const;
  const trials: TrialResult[] = outcomes.map((outcome, index) => {
    const technical = outcome === "protocol-error" || outcome === "execution-error";
    return {
      ...original, caseId: `case-0${index + 1}`, outcome,
      integrity: technical ? "fail" : "pass",
      errorCode: technical ? outcome === "protocol-error" ? "invalid-report" : "execution-failed" : undefined,
      reason: technical ? "Fixture error | requires\noperator review" : outcome === "blocked" ? "Evidence unavailable" : undefined,
      diagnostic: {
        ...original.diagnostic, findingStatus: technical ? "Unusable" : "not-established",
        rootCauseService: "unassessed", extractedService: undefined,
      },
      leadingHypothesis: {
        ...original.leadingHypothesis,
        status: technical ? "unusable" : outcome === "candidate" ? "candidate" : "abstained",
        rootCauseService: outcome === "candidate" ? "match" : "unassessed", extractedService: undefined,
      },
    };
  });
  const source = await readJson<TrialArtifact & { cliCapture: Record<string, unknown> }>(
    join(trialDirectory(fixture.runRoot, "case-01", 1, "with-skill"), "session-artifact.json"),
  );
  for (const trial of trials.slice(1)) {
    const root = trialDirectory(fixture.runRoot, trial.caseId, 1, "with-skill");
    await mkdir(root, { recursive: true });
    await writeJson(join(root, "session-artifact.json"), { ...source, caseId: trial.caseId });
  }
  await writeJson(summaryPath, { ...summary, trials } satisfies EvaluationSummary);
  const paths = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-29" });
  for (const path of [paths.committedReportPath, paths.reviewPath]) {
    const text = await readFile(path, "utf8");
    assert.ok(text.includes("Blocked (evidence unavailable; abstained)"), "blocker is explicitly labelled");
    assert.ok(text.includes("No defensible candidate (abstained)"), "valid abstention is explicitly labelled");
    assert.ok(text.includes("Unavailable (protocol-error: invalid-report)"), "protocol failure is unusable");
    assert.ok(text.includes("Unavailable (execution-error: execution-failed)"), "execution failure is unusable");
    assert.ok(text.includes("protocol-error: invalid-report: Fixture error \\| requires operator review"));
    assert.ok(text.includes("execution-error: execution-failed: Fixture error \\| requires operator review"));
  }
  const update = await readFile(paths.prUpdatePath, "utf8");
  assert.match(update, /1 candidates,\s+1 abstentions,\s+1 evidence blockers,\s+1 protocol failures,\s+1 execution failures/);
});

test("rejects absent structured outcomes and historical v1 protocols without rewriting evidence", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  const evidencePath = join(fixture.repositoryRoot, "evals", "rca-real-world", "PR-3136-EVIDENCE.md");
  await writeFile(evidencePath, "Untouched historical evidence.", "utf8");
  await writeJson(summaryPath, {
    ...summary, trials: summary.trials.map((trial) => ({ ...trial, outcome: undefined })),
  });
  await assert.rejects(generateEvidenceReport({ ...fixture, reviewDate: "2026-10-29" }), /structured trial outcomes/);
  await writeJson(summaryPath, { ...summary, protocol: "ad-hoc-v1" });
  await assert.rejects(generateEvidenceReport({ ...fixture, reviewDate: "2026-10-29" }), /historical/);
  assert.equal(await readFile(evidencePath, "utf8"), "Untouched historical evidence.");
});

test("human wording adjudication cannot substitute for v2 machine authority or artifact integrity", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  await writeJson(summaryPath, {
    ...summary, trials: summary.trials.map((trial) => ({
      ...trial, strictGates: { ...trial.strictGates, approvalClearlySimulated: false },
    })),
  } satisfies EvaluationSummary);
  await writeJson(join(fixture.runRoot, "human-adjudications.json"), {
    criterion: "Human review of wording only.",
    adjudications: [{
      caseId: "case-01", trial: 1, condition: "with-skill", gate: "approvalClearlySimulated", decision: "pass",
    }],
  });
  const paths = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-29" });
  const report = await readFile(paths.committedReportPath, "utf8");
  assert.match(report, /Strict gates passed in 0 of 1 skilled sessions/);
  assert.doesNotMatch(report, /pass \(human-adjudicated wording\)/);
});

test("reads latest numeric cumulative usage across arbitrarily numbered turns", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  await writeJson(
    join(trialDirectory(fixture.runRoot, "case-01", 1, "with-skill"), "session-artifact.json"),
    {
      protocol: EVALUATION_PROTOCOL,
      requestedProfile: { evaluationProfile: "production", model: "gpt-5.6-sol" },
      cliCapture: {
        usageTurn4: { totalPremiumRequestCost: 4 },
        usageTurn12: { totalPremiumRequestCost: 12 },
        usageTurn13: {},
        usageTurn8: { totalPremiumRequestCost: 8 },
      },
    },
  );
  const result = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-28" });
  assert.match(await readFile(result.committedReportPath, "utf8"), /Authoritative run premium requests \| 12/);
});

test("labels debug outputs as harness diagnostics rather than efficacy evidence", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  const manifestPath = join(fixture.runRoot, "run-manifest.json");
  const manifest = await readJson<Record<string, unknown>>(manifestPath);
  const committedEvidencePath = join(fixture.repositoryRoot, "evals", "rca-real-world", "PR-3136-EVIDENCE.md");
  const productionDraftPath = join(fixture.runRoot, "PR-3136-UPDATE.md");
  const sentinel = "Historical production evidence must remain unchanged.\n";
  await writeFile(committedEvidencePath, sentinel, "utf8");
  await writeFile(productionDraftPath, sentinel, "utf8");
  await writeJson(manifestPath, { ...manifest, profile: "debug", model: "gpt-5.6-luna" });
  await writeJson(summaryPath, {
    ...summary, profile: "debug", model: "gpt-5.6-luna",
    trials: summary.trials.map((trial) => ({ ...trial, profile: "debug", model: "gpt-5.6-luna" })),
  });
  await writeJson(
    join(trialDirectory(fixture.runRoot, "case-01", 1, "with-skill"), "session-artifact.json"),
    {
      protocol: EVALUATION_PROTOCOL,
      requestedProfile: { evaluationProfile: "debug", model: "gpt-5.6-luna" },
      cliCapture: {},
    },
  );
  const result = await generateEvidenceReport({ ...fixture, reviewDate: "2026-10-28" });
  assert.equal(await readFile(committedEvidencePath, "utf8"), sentinel);
  assert.equal(await readFile(productionDraftPath, "utf8"), sentinel);
  assert.equal(result.committedReportPath, join(fixture.runRoot, "DEBUG-EVIDENCE.md"));
  assert.equal(result.reviewPath, join(fixture.runRoot, "DEBUG-REVIEW.md"));
  assert.equal(result.prUpdatePath, join(fixture.runRoot, "DEBUG-UPDATE.md"));
  for (const path of [result.committedReportPath, result.reviewPath, result.prUpdatePath]) {
    const text = await readFile(path, "utf8");
    assert.match(text, /DEBUG RUN.*not skill efficacy evidence/);
    assert.match(text, /gpt-5\.6-luna/);
    assert.ok(text.includes(EVALUATION_PROTOCOL));
    assert.doesNotMatch(text, /GPT-5\.6 Sol/);
  }
});

test("rejects mixed profiles, models, and protocols before publishing reports", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const summaryPath = join(fixture.runRoot, "evaluation-summary.json");
  const summary = await readJson<EvaluationSummary>(summaryPath);
  for (const change of [
    { profile: "debug" }, { model: "gpt-5.6-luna" }, { protocol: "host-directed-v1" },
  ]) {
    await writeJson(summaryPath, {
      ...summary, trials: summary.trials.map((trial) => ({ ...trial, ...change })),
    });
    await assert.rejects(
      generateEvidenceReport({ ...fixture, reviewDate: "2026-10-28" }),
      /Cannot report mixed or historical profiles, models, or protocols/,
    );
  }
  await writeJson(summaryPath, { ...summary, protocol: undefined });
  await assert.rejects(
    generateEvidenceReport({ ...fixture, reviewDate: "2026-10-28" }),
    /Cannot report mixed or historical profiles, models, or protocols/,
  );
});

test("rejects historical summaries explicitly instead of treating them as paired evidence", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  await writeJson(join(fixture.runRoot, "evaluation-summary.json"), { schemaVersion: "1.0.0" });
  await assert.rejects(
    generateEvidenceReport({ ...fixture, reviewDate: "2026-10-26" }),
    /requires condition-aware schema 2\.0\.0/,
  );
});

test("fails publication when traces contain secrets or host paths", async (context) => {
  const fixture = await reportFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  await writeFile(
    join(fixture.runRoot, "unsafe.json"),
    '{"token":"github_pat_abcdefghijklmnopqrstuvwxyz","path":"C:\\\\Users\\\\person\\\\secret"}',
    "utf8",
  );
  const findings = await scanArtifacts(fixture.runRoot);
  assert.ok(findings.some((item) => item.category === "credential"));
  assert.ok(findings.some((item) => item.category === "windows-home-path"));
  await assert.rejects(
    generateEvidenceReport({ ...fixture, reviewDate: "2026-10-19" }),
    /Artifact scan failed/,
  );
});
