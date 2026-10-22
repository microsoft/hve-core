// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { generateEvidenceReport, scanArtifacts } from "../../../evals/rca-real-world/report.mts";

async function reportFixture(): Promise<{
  readonly repositoryRoot: string;
  readonly runRoot: string;
}> {
  const repositoryRoot = await mkdtemp(join(tmpdir(), "rca-report-repo-"));
  const runRoot = join(repositoryRoot, ".copilot-tracking", "evaluations", "run");
  await mkdir(runRoot, { recursive: true });
  await mkdir(join(repositoryRoot, "evals", "rca-real-world"), { recursive: true });
  await writeFile(
    join(runRoot, "run-manifest.json"),
    JSON.stringify({
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
  await writeFile(
    join(runRoot, "evaluation-summary.json"),
    JSON.stringify({
      schemaVersion: "1.0.0",
      runId: "fixture",
      sourceRevision: "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e",
      model: "gpt-5.6-sol",
      reasoningEffort: "medium",
      contextTier: "default",
      trialOrder: [],
      trials: [
        {
          caseId: "case-01",
          trial: 1,
          integrity: "pass",
          strictGates: {
            noGroundTruthLeak: true,
            noUnauthorizedToolCall: true,
            approvalContract: true,
            approvalClearlySimulated: true,
            statisticalApplicability: true,
            noUnsupportedComplete: true,
            outputContract: true,
            honestEvidenceGaps: true,
          },
          diagnostic: {
            findingStatus: "Complete",
            rootCauseService: "match",
            faultOrMechanism: "match",
            correctCauseTested: true,
          },
          leadingHypothesis: {
            status: "candidate",
            rootCauseService: "match",
            faultOrMechanism: "match",
            safetyWarningPresent: true,
          },
          humanReview: "pending",
        },
      ],
      roundOneCheckpoint: { decision: "continue", reasons: [] },
      limitations: ["Selected cases are not a population estimate."],
    }),
    "utf8",
  );
  const sessionRoot = join(runRoot, "sessions", "case-01", "trial-1");
  await mkdir(sessionRoot, { recursive: true });
  await writeFile(
    join(sessionRoot, "session-artifact.json"),
    JSON.stringify({ cliCapture: { usageTurn2: { totalPremiumRequestCost: 2 } } }),
    "utf8",
  );
  return { repositoryRoot, runRoot };
}

test("generates sanitized evidence while preserving human-owned checkboxes", async () => {
  const fixture = await reportFixture();
  const result = await generateEvidenceReport({
    ...fixture,
    reviewDate: "2026-10-19",
  });
  const committed = await readFile(result.committedReportPath, "utf8");
  const review = await readFile(result.reviewPath, "utf8");
  const prUpdate = await readFile(result.prUpdatePath, "utf8");
  assert.match(committed, /Strict gates passed in 1 of 1/);
  assert.match(committed, /Set A service \| Set B service \| Set B status/);
  assert.match(committed, /matched in Set A for 1 sessions and in Set B for\s+1 sessions/);
  assert.match(committed, /16\.93 AI credits/);
  assert.match(committed, /- \[ \] Reviewed and validated/);
  assert.doesNotMatch(committed, /- \[x\]/i);
  assert.match(review, /Human disposition \| Reviewer rationale/);
  assert.match(prUpdate, /Please reassess CR-16/);
});

test("fails publication when traces contain secrets or host paths", async () => {
  const fixture = await reportFixture();
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
