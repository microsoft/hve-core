// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";

import type { CliInvoker } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import {
  EVALUATION_CASE_IDS,
  TRANSFORMATION_VERSION,
  sha256,
  stableJson,
} from "../../../evals/rca-real-world/contracts.mts";
import { createInputFingerprint, runRound } from "../../../evals/rca-real-world/runner.mts";

test("fingerprints input paths in code-unit order", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "rca-fingerprint-"));
  context.after(() => rm(root, { recursive: true, force: true }));
  const runRoot = join(root, "run");
  const paths = [
    ".github/skills/root-cause-analysis/skill.txt",
    "evals/rca-real-world/Z.txt",
    "evals/rca-real-world/a.txt",
    "package-lock.json",
    "scripts/evals/rca-real-world/source.mts",
  ];
  for (const path of paths) {
    const absolutePath = join(root, ...path.split("/"));
    await mkdir(dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, "fixture", "utf8");
  }
  const manifestPath = join(runRoot, "inputs", "scorer-only", "preparation-manifest.json");
  await mkdir(dirname(manifestPath), { recursive: true });
  await writeFile(manifestPath, "manifest", "utf8");
  const mappingPaths = EVALUATION_CASE_IDS.map(
    (caseId) => `inputs/model-visible/${caseId}/metric-columns.json`,
  );
  for (const path of mappingPaths) {
    const absolutePath = join(runRoot, ...path.split("/"));
    await mkdir(dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, "{}\n", "utf8");
  }
  const expectedFiles = [
    ...paths.slice(0, 3).map((path) => ({ path, sha256: sha256("fixture") })),
    ...mappingPaths.map((path) => ({ path, sha256: sha256("{}\n") })),
    { path: "package-lock.json", sha256: sha256("fixture") },
    { path: "preparation-manifest.json", sha256: sha256("manifest") },
    { path: paths[4], sha256: sha256("fixture") },
  ];
  assert.equal(
    await createInputFingerprint(root, runRoot),
    sha256(stableJson(expectedFiles)),
  );
  await writeFile(join(runRoot, ...mappingPaths[0]!.split("/")), '{"changed":true}\n', "utf8");
  assert.notEqual(
    await createInputFingerprint(root, runRoot),
    sha256(stableJson(expectedFiles)),
  );
});

const NOW = new Date("2026-10-19T20:00:00.000Z");
const serviceByCase: Readonly<Record<string, string>> = {
  "case-01": "adservice",
  "case-02": "checkoutservice",
  "case-03": "cartservice",
  "case-04": "user",
  "case-05": "ts-auth-service",
};
const faultByCase: Readonly<Record<string, string>> = {
  "case-01": "cpu",
  "case-02": "delay",
  "case-03": "f1",
  "case-04": "loss",
  "case-05": "f2",
};

async function preparedRun(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "rca-runner-"));
  const scorerRoot = join(root, "inputs", "scorer-only");
  await mkdir(join(scorerRoot, "truth"), { recursive: true });
  await writeFile(
    join(scorerRoot, "preparation-manifest.json"),
    JSON.stringify({
      sourceRevision: "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e",
      transformationVersion: TRANSFORMATION_VERSION,
      cases: EVALUATION_CASE_IDS.map((neutralId) => ({
        neutralId, metricColumnsSha256: sha256("{}\n"),
      })),
    }),
    "utf8",
  );
  for (const caseId of Object.keys(serviceByCase)) {
    const caseRoot = join(root, "inputs", "model-visible", caseId);
    await mkdir(caseRoot, { recursive: true });
    await writeFile(join(caseRoot, "metric-columns.json"), "{}\n", "utf8");
    await writeFile(
      join(caseRoot, "incident.json"),
      JSON.stringify({ caseId, incidentOnset: "1700000000" }),
      "utf8",
    );
    const hasLogs = caseId !== "case-01";
    const hasTraces = !["case-01", "case-04"].includes(caseId);
    const sources = [
      { modality: "metrics", rowCount: 1 },
      ...(hasLogs ? [{ modality: "logs", rowCount: 1 }] : []),
      ...(hasTraces ? [{ modality: "traces", rowCount: 1 }] : []),
    ];
    await writeFile(
      join(caseRoot, "source-coverage.json"),
      JSON.stringify({ sources }),
      "utf8",
    );
    await writeFile(
      join(caseRoot, "metrics.jsonl"),
      `{"timestamp":1700000000,"service":"${serviceByCase[caseId]}","metric":"cpu","value":95}\n`,
      "utf8",
    );
    if (hasLogs) {
      await writeFile(
        join(caseRoot, "logs.jsonl"),
        `{"timestamp":1700000001,"service":"${serviceByCase[caseId]}","message":"incident log"}\n`,
        "utf8",
      );
    }
    if (hasTraces) {
      await writeFile(
        join(caseRoot, "traces.jsonl"),
        `{"startTimeMillis":"1700000001000","serviceName":"${serviceByCase[caseId]}","statusCode":"0","duration":"100"}\n`,
        "utf8",
      );
    }
    await writeFile(
      join(scorerRoot, "truth", `${caseId}.json`),
      JSON.stringify({
        neutralId: caseId,
        sourcePath: `held-out-${caseId}`,
        rootCauseService: serviceByCase[caseId],
        fault: faultByCase[caseId],
        compatibleMechanism: `compatible ${faultByCase[caseId]} mechanism`,
      }),
      "utf8",
    );
  }
  return root;
}

test("rejects changed metric identities before invoking the model", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "inputs", "model-visible", "case-01", "metric-columns.json"),
    '{"changed":true}\n', "utf8");
  await assert.rejects(runRound({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "mapping-drift",
    round: 1,
    cliInvoker: async () => { throw new Error("Model must not run"); },
  }), /Metric column mapping integrity mismatch/);
});

function fakeCliInvoker(): CliInvoker {
  return async (args) => {
    if (args.includes("--version")) {
      return result("GitHub Copilot CLI 1.0.101-0\n");
    }
    assert.equal(args.includes("--attachment"), false);
    assert.equal(args.includes("--no-custom-instructions"), false);
    assert.equal(args.includes("--available-tools"), true);
    const promptIndex = args.indexOf("-p");
    const prompt = promptIndex >= 0 ? args[promptIndex + 1] ?? "" : "";
    const caseId = /case-0[1-5]/.exec(prompt)?.[0];
    if (!caseId) {
      throw new Error("Missing case in CLI prompt");
    }
    if (prompt.startsWith("Investigate neutral incident")) {
      return result(
        `${JSON.stringify({
          type: "assistant.message",
          data: { content: approvalResponse(caseId) },
        })}\n`,
      );
    }
    if (prompt.startsWith("HOST-EXECUTED SCOPE EVIDENCE")) {
      return result(
        `${JSON.stringify({
          type: "assistant.message",
          data: { content: adaptiveApprovalResponse(caseId) },
        })}\n`,
      );
    }
    if (prompt.startsWith("HOST-EXECUTED ALIGNED EVIDENCE")) {
      return result(
        `${JSON.stringify({
          type: "assistant.message",
          data: { content: focusedApprovalResponse(caseId) },
        })}\n`,
      );
    }
    return result(
      `${JSON.stringify({
        type: "assistant.message",
        data: { content: finalOutput(serviceByCase[caseId]!, faultByCase[caseId]!) },
      })}\n`,
    );
  };
}

function adaptiveApprovalResponse(caseId: string): string {
  const hasLogs = caseId !== "case-01";
  const hasTraces = !["case-01", "case-04"].includes(caseId);
  return [
    "```json",
    JSON.stringify({
      approvalRequests: [
        {
          tool: "compare_metrics",
          operation: "compare",
          parameters: {
            baselineStartTime: 1699999700,
            baselineEndTime: 1700000000,
            postStartTime: 1700000000,
            postEndTime: 1700000300,
            limit: 20,
          },
          evidenceSought: "Baseline to post-onset metric changes",
          target: caseId,
          scope: "current neutral case only",
          maximumCallCount: 1,
          expectedRisk: "read-only bounded fixture evidence",
          expiresAt: "2026-10-19T20:10:00.000Z",
        },
        ...(hasLogs
          ? [
              {
                tool: "search_logs",
                operation: "search",
                parameters: { startTime: 1700000000, endTime: 1700000300, limit: 20 },
                evidenceSought: "Post-onset logs",
                target: caseId,
                scope: "current neutral case only",
                maximumCallCount: 1,
                expectedRisk: "read-only bounded fixture evidence",
                expiresAt: "2026-10-19T20:10:00.000Z",
              },
            ]
          : []),
        ...(hasTraces
          ? [
              {
                tool: "summarize_traces",
                operation: "summarize",
                parameters: {
                  startTime: 1700000000000,
                  endTime: 1700000300000,
                  limit: 20,
                },
                evidenceSought: "Post-onset traces",
                target: caseId,
                scope: "current neutral case only",
                maximumCallCount: 1,
                expectedRisk: "read-only bounded fixture evidence",
                expiresAt: "2026-10-19T20:10:00.000Z",
              },
            ]
          : []),
      ],
    }),
    "```",
  ].join("\n");
}

function focusedApprovalResponse(caseId: string): string {
  const useComparison = ["case-01", "case-03", "case-05"].includes(caseId);
  return [
    "```json",
    JSON.stringify({
      approvalRequests: [
        {
          tool: useComparison ? "compare_metrics" : "aggregate_metrics",
          operation: useComparison ? "compare" : "aggregate",
          parameters: useComparison
            ? {
                baselineStartTime: 1699999700,
                baselineEndTime: 1700000000,
                postStartTime: 1700000000,
                postEndTime: 1700000300,
                service: serviceByCase[caseId],
                limit: 10,
              }
            : {
                startTime: 1700000000,
                endTime: 1700000300,
                service: serviceByCase[caseId],
              },
          evidenceSought: "Focused post-onset service metrics",
          target: caseId,
          scope: "current neutral case only",
          maximumCallCount: 1,
          expectedRisk: "read-only bounded fixture evidence",
          expiresAt: "2026-10-19T20:10:00.000Z",
        },
      ],
    }),
    "```",
  ].join("\n");
}

function result(stdout: string) {
  return { exitCode: 0, stdout, stderr: "", durationMs: 1, timedOut: false };
}

function approvalResponse(caseId: string): string {
  return [
    "```json",
    JSON.stringify({
      approvalRequests: [
        {
          tool: "read_incident_scope",
          operation: "read",
          parameters: {},
          evidenceSought: "Incident scope",
          target: caseId,
          scope: "current neutral case only",
          maximumCallCount: 1,
          expectedRisk: "read-only bounded fixture evidence",
          expiresAt: "2026-10-19T20:10:00.000Z",
        },
      ],
    }),
    "```",
  ].join("\n");
}

function finalOutput(service: string, fault: string): string {
  return [
    "### 1. Status and Finding",
    `Provisional: root-cause service is ${service}; ${fault} is the leading mechanism. Human sign-off unavailable.`,
    "### 2. Source Coverage",
    "| Source | Coverage | Gaps |",
    "|---|---|---|",
    "| S-001 | Metrics | Other sources unavailable |",
    "### 3. Hypotheses Tested",
    `H-001: ${service} ${fault}. Repeated time points are dependent; independent statistics are N/A - not applicable.`,
    "### 4. Executed Tests and Evidence",
    "T-001 executed.",
    "### 5. Causal Account and Gate",
    "Completion gate not met because accountable human sign-off is unavailable.",
    "### 6. Actions and Open Decisions",
    "Human review remains open.",
    "### 7. Authorization and Execution Audit",
    "Simulated fixture approval only; no production authorization.",
    "### 8. Resume Checkpoint",
    "Review the evidence gaps.",
  ].join("\n\n");
}

test("runs exactly five first-round sessions and records a continue checkpoint", async () => {
  const root = await preparedRun();
  const summary = await runRound({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "round-one-run",
    round: 1,
    cliInvoker: fakeCliInvoker(),
    clock: () => NOW,
  });
  assert.equal(summary.trials.length, 5);
  assert.deepEqual(
    summary.trials.map((result) => `${result.caseId}:${result.trial}`),
    ["case-01:1", "case-02:1", "case-03:1", "case-04:1", "case-05:1"],
  );
  assert.equal(summary.roundOneCheckpoint?.decision, "continue");
  for (const caseId of Object.keys(serviceByCase)) {
    const artifact = JSON.parse(
      await readFile(join(root, "sessions", caseId, "trial-1", "session-artifact.json"), "utf8"),
    ) as {
      cliCapture: { third?: unknown; fourth?: unknown };
      evidenceToolTraces: readonly unknown[];
      approvalLedger: { records: readonly { status: string }[] };
    };
    const expectedCalls = caseId === "case-01" ? 3 : caseId === "case-04" ? 4 : 5;
    assert.ok(artifact.cliCapture.third);
    assert.ok(artifact.cliCapture.fourth);
    assert.equal(artifact.evidenceToolTraces.length, expectedCalls);
    assert.ok(artifact.approvalLedger.records.every((record) => record.status === "Consumed"));
  }
  assert.doesNotReject(() => readFile(join(root, "round-one-checkpoint.json"), "utf8"));
});

test("does not start round two when the round-one checkpoint pauses", async () => {
  const root = await preparedRun();
  await runRound({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "paused-run",
    round: 1,
    cliInvoker: fakeCliInvoker(),
    clock: () => NOW,
  });
  await writeFile(
    join(root, "round-one-checkpoint.json"),
    '{"decision":"pause","reasons":["review required"]}',
    "utf8",
  );
  await assert.rejects(
    runRound({
      repositoryRoot: resolve("."),
      runRoot: root,
      runId: "paused-run",
      round: 2,
      cliInvoker: fakeCliInvoker(),
      clock: () => NOW,
    }),
    /does not authorize continuation/,
  );
});

test("runs rounds two and three only after unchanged input and prerequisites", async () => {
  const root = await preparedRun();
  const base = {
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "complete-run",
    cliInvoker: fakeCliInvoker(),
    clock: () => NOW,
  };
  await runRound({ ...base, round: 1 });
  await runRound({ ...base, round: 2 });
  const summary = await runRound({ ...base, round: 3 });
  assert.equal(summary.trials.length, 15);
  assert.deepEqual(
    summary.trials.map((result) => result.trial),
    [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3],
  );
});

test("never replaces an existing trial", async () => {
  const root = await preparedRun();
  const options = {
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "no-retry-run",
    round: 1 as const,
    cliInvoker: fakeCliInvoker(),
    clock: () => NOW,
  };
  await runRound(options);
  await assert.rejects(runRound(options), /Run manifest already exists/);
});
