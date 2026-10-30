// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

import { cliStdinInput, runCliTrial } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import { createEvidenceTools } from "../../../evals/rca-real-world/evidence-tools.mts";
import {
  EVALUATION_RUN_DIRECTORY, sha256, stableJson,
} from "../../../evals/rca-real-world/contracts.mts";
import {
  runTrial,
  type ModelClient,
  type SessionCreationConfig,
} from "../../../evals/rca-real-world/orchestrator.mts";
import { sanitizeRun } from "../../../evals/rca-real-world/sanitize-run.mts";
import { trialDirectory } from "../../../evals/rca-real-world/conditions.mts";

const NOW = new Date("2026-10-19T20:00:00.000Z");

test("keeps large scope mappings as complete valid JSON without prescribing query windows", async (context) => {
  const root = await runRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  const metricColumns = Object.fromEntries(Array.from({ length: 200 }, (_, index) => [
    `service-${index}_cpu`, { service: `service-${index}`, metric: "cpu" },
  ]));
  await writeFile(join(root, "inputs", "model-visible", "case-01", "metric-columns.json"), stableJson(metricColumns));
  const evidence = createEvidenceTools({
    caseRoot: join(root, "inputs", "model-visible", "case-01"),
    ledger: { consume: () => "fixture-exact-scope" },
  });
  const text = await evidence.tools.find((tool) => tool.name === "read_incident_scope")!.handler({});
  assert.ok(text.length > 7_000);
  const result = JSON.parse(text);
  assert.deepEqual(result.data.metricColumns, metricColumns);
  assert.equal(result.data.queryGuidance, undefined);
  assert.deepEqual(result.data.timeUnits, { metricsAndLogs: "epoch seconds", traces: "epoch milliseconds" });
});

test("moves large Unicode and quoted prompts to stdin without changing CLI flags", () => {
  const prompt = "Quoted \"text\", CRLF\r\nUnicode \u03bb and backslash \\".repeat(2_000);
  assert.ok(prompt.length > 32_767);
  for (const flag of ["-p", "--prompt"]) {
    const args = ["--model", "fixture", flag, prompt, "--available-tools"];
    const invocation = cliStdinInput(args);
    assert.deepEqual(invocation.args, ["--model", "fixture", "--available-tools"]);
    assert.equal(invocation.input, prompt);
    assert.equal(args[3], prompt);
  }
  assert.deepEqual(cliStdinInput(["--version"]), { args: ["--version"] });
  assert.throws(() => cliStdinInput(["-p"]), /requires text/);
});

test("rejects oversized scope evidence explicitly instead of returning a clipped mapping", async (context) => {
  const root = await runRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  const metricColumns = Object.fromEntries(Array.from({ length: 1500 }, (_, index) => [
    `service-${index}_cpu`, { service: `service-${index}`, metric: "cpu" },
  ]));
  await writeFile(join(root, "inputs", "model-visible", "case-01", "metric-columns.json"), stableJson(metricColumns));
  const evidence = createEvidenceTools({
    caseRoot: join(root, "inputs", "model-visible", "case-01"),
    ledger: { consume: () => "fixture-exact-scope" },
  });
  await assert.rejects(evidence.tools.find((tool) => tool.name === "read_incident_scope")!.handler({}),
    /exceed|too large|limit/i);
  assert.equal(evidence.traces.length, 1);
});

async function runRoot(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "rca-orchestrator-"));
  const caseRoot = join(root, "inputs", "model-visible", "case-01");
  await mkdir(caseRoot, { recursive: true });
  await writeFile(join(caseRoot, "metric-columns.json"), "{}\n", "utf8");
  await writeFile(
    join(caseRoot, "incident.json"),
    '{"caseId":"case-01","incidentOnset":"1700000000"}',
    "utf8",
  );
  await writeFile(
    join(caseRoot, "source-coverage.json"),
    '{"sources":[{"modality":"metrics","rowCount":1}]}',
    "utf8",
  );
  await writeFile(
    join(caseRoot, "metrics.jsonl"),
    '{"timestamp":1700000000,"service":"adservice","metric":"cpu","value":95}\n',
    "utf8",
  );
  return root;
}

function approvalResponse(): string {
  return [
    "Generic mode. Requesting exact bounded evidence.",
    "```json",
    JSON.stringify({
      approvalRequests: [
        {
          tool: "read_incident_scope",
          operation: "read",
          parameters: {},
          evidenceSought: "Incident scope and source coverage",
          target: "case-01",
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

function finalResponse(): string {
  return [
    "### 1. Status and Finding",
    "Provisional: adservice CPU saturation is the leading explanation. Human sign-off unavailable.",
    "### 2. Source Coverage",
    "| Source | Coverage | Gaps |",
    "|---|---|---|",
    "| S-001 | Metrics | Logs and traces unavailable |",
    "### 3. Hypotheses Tested",
    "H-001 CPU saturation; N/A - dependent time points.",
    "### 4. Executed Tests and Evidence",
    "T-001 executed through Approval fixture.",
    "### 5. Causal Account and Gate",
    "Completion gate not met because accountable human sign-off is unavailable.",
    "### 6. Actions and Open Decisions",
    "Human review remains open.",
    "### 7. Authorization and Execution Audit",
    "Simulated fixture approval only; no production authorization.",
    "### 8. Resume Checkpoint",
    "Review source metrics and obtain accountable sign-off.",
  ].join("\n\n");
}

test("uses the exact model profile and independently approved tool path", async () => {
  const root = await runRoot();
  let capturedConfig: SessionCreationConfig | undefined;
  let sendCount = 0;
  const clientFactory = async (): Promise<ModelClient> => ({
    start: async () => undefined,
    stop: async () => undefined,
    listModels: async () => [
      { id: "gpt-5.6-sol", supportedReasoningEfforts: ["low", "medium", "high"] },
    ],
    getStatus: async () => ({ version: "fake", path: resolve(".") }),
    createSession: async (config) => {
      capturedConfig = config;
      return {
        onEvent: (handler) => {
          handler({ type: "session.start", credential: "github_pat_abcdefghijklmnopqrstuvwxyz" });
          handler({ type: "workspace", path: config.workingDirectory });
          return () => undefined;
        },
        sendAndWait: async () => {
          sendCount += 1;
          if (sendCount === 1) {
            return { content: approvalResponse() };
          }
          const tool = config.tools.find((candidate) => candidate.name === "read_incident_scope");
          await tool!.handler({});
          return { content: finalResponse() };
        },
        destroy: async () => undefined,
      };
    },
  });

  const artifact = await runTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "fixture-run",
    caseId: "case-01",
    trial: 1,
    clientFactory,
    clock: () => NOW,
  });

  assert.equal(capturedConfig?.model, "gpt-5.6-sol");
  assert.equal(capturedConfig?.reasoningEffort, "medium");
  assert.equal(capturedConfig?.contextTier, "default");
  assert.equal(sendCount, 2);
  assert.equal(artifact.endReason, "complete");
  assert.equal(artifact.evidenceToolTraces.length, 1);
  assert.equal(
    (artifact.approvalLedger as { establishesProductionAuthorization: boolean })
      .establishesProductionAuthorization,
    false,
  );
  assert.doesNotMatch(JSON.stringify(artifact), /github_pat_|HVE-SRE-skill/i);
  assert.ok(capturedConfig);
  assert.equal(JSON.stringify(artifact).includes(capturedConfig.workingDirectory), false);
  const persisted = await readFile(
    join(trialDirectory(root, "case-01", 1, "with-skill"), "session-artifact.json"),
    "utf8",
  );
  assert.equal(persisted.includes(JSON.stringify(capturedConfig.workingDirectory).slice(1, -1)), false);
  assert.ok(artifact.redactionManifest.replacements >= 1);
});

test("redacts CLI workspace paths in persisted errors and keeps hashes consistent", async (context) => {
  const root = await runRoot();
  context.after(() => rm(root, { recursive: true, force: true }));
  let workspace: string | undefined;
  const artifact = await runCliTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "cli-redaction",
    caseId: "case-01",
    trial: 1,
    cliInvoker: async (_args, options) => {
      workspace = options.cwd;
      throw new Error(`CLI failure in ${options.cwd}`);
    },
    clock: () => NOW,
  });
  assert.ok(workspace);
  assert.equal(artifact.endReason, "error");
  assert.equal(artifact.error, "CLI failure in [REDACTED_PATH]");
  const sessionRoot = trialDirectory(root, "case-01", 1, "with-skill");
  const persisted = await readFile(join(sessionRoot, "session-artifact.json"), "utf8");
  assert.equal(persisted.includes(JSON.stringify(workspace).slice(1, -1)), false);
  const hashes = JSON.parse(await readFile(join(sessionRoot, "artifact-hashes.json"), "utf8"));
  assert.equal(hashes.sessionArtifactSha256, sha256(stableJson(artifact)));
  assert.ok(artifact.redactionManifest.applied.includes("temporary-workspace"));
});

test("refuses historical sanitization before changing artifacts, summaries or checkpoint hashes", async (context) => {
  const repositoryRoot = await mkdtemp(join(tmpdir(), "rca-sanitize-"));
  context.after(() => rm(repositoryRoot, { recursive: true, force: true }));
  const runId = "sanitize-fixture";
  const root = join(repositoryRoot, ".copilot-tracking", "evaluations", EVALUATION_RUN_DIRECTORY, runId);
  await mkdir(root, { recursive: true });
  const artifact = await runTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId,
    caseId: "case-01",
    trial: 1,
    clientFactory: async () => { throw new Error("Fixture model unavailable"); },
    clock: () => NOW,
  });
  const sessionRoot = trialDirectory(root, "case-01", 1, "with-skill");
  await writeFile(join(sessionRoot, "session-artifact.json"), stableJson({
    ...artifact,
    events: [{ path: join(homedir(), "private-output") }],
  }));
  const truthRoot = join(root, "inputs", "scorer-only", "truth");
  await mkdir(truthRoot, { recursive: true });
  await writeFile(join(truthRoot, "case-01.json"), stableJson({
    neutralId: "case-01",
    sourcePath: "held-out-case-01",
    rootCauseService: "adservice",
    fault: "cpu",
    compatibleMechanism: "CPU saturation",
  }));
  const baselineRoot = trialDirectory(root, "case-01", 1, "without-skill");
  await mkdir(baselineRoot, { recursive: true });
  await writeFile(join(baselineRoot, "session-artifact.json"), stableJson({
    ...artifact,
    condition: "without-skill",
    events: [{ path: join(homedir(), "baseline-output") }],
  }));
  await writeFile(join(root, "evaluation-summary.json"), stableJson({ mode: "both", trials: [] }));
  await writeFile(join(root, "round-one-checkpoint.json"), stableJson({
    decision: "pause", trialResultHashes: {},
  }));
  const paths = [
    join(sessionRoot, "session-artifact.json"), join(baselineRoot, "session-artifact.json"),
    join(root, "evaluation-summary.json"), join(root, "round-one-checkpoint.json"),
  ];
  const before = await Promise.all(paths.map((path) => readFile(path)));
  await assert.rejects(sanitizeRun(repositoryRoot, runId), /Historical evaluation artifacts are immutable/);
  for (const [index, path] of paths.entries()) assert.deepEqual(await readFile(path), before[index]);
  await assert.rejects(readFile(join(sessionRoot, "trial-result.json")), { code: "ENOENT" });
});

test("fails closed before sending when the exact model profile is unavailable", async () => {
  const root = await runRoot();
  let sendCount = 0;
  const artifact = await runTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "unavailable-profile",
    caseId: "case-01",
    trial: 1,
    clientFactory: async () => ({
      start: async () => undefined,
      stop: async () => undefined,
      listModels: async () => [{ id: "different-model", supportedReasoningEfforts: ["medium"] }],
      getStatus: async () => ({ version: "fake" }),
      createSession: async () => {
        sendCount += 1;
        throw new Error("must not create");
      },
    }),
    clock: () => NOW,
  });
  assert.equal(sendCount, 0);
  assert.equal(artifact.endReason, "error");
  assert.match(artifact.error ?? "", /Exact model profile unavailable/);
});

test("does not retry a failed approved turn", async () => {
  const root = await runRoot();
  let sendCount = 0;
  const artifact = await runTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "failed-turn",
    caseId: "case-01",
    trial: 1,
    clientFactory: async () => ({
      start: async () => undefined,
      stop: async () => undefined,
      listModels: async () => [
        { id: "gpt-5.6-sol", supportedReasoningEfforts: ["medium"] },
      ],
      getStatus: async () => ({ version: "fake" }),
      createSession: async () => ({
        onEvent: () => () => undefined,
        sendAndWait: async () => {
          sendCount += 1;
          if (sendCount === 1) {
            return { content: approvalResponse() };
          }
          throw new Error("synthetic model failure");
        },
        destroy: async () => undefined,
      }),
    }),
    clock: () => NOW,
  });
  assert.equal(sendCount, 2);
  assert.equal(artifact.endReason, "error");
  assert.match(artifact.error ?? "", /synthetic model failure/);
});

test("persists trace and hash artifacts", async () => {
  const root = await runRoot();
  await runTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "artifact-run",
    caseId: "case-01",
    trial: 1,
    clientFactory: async () => ({
      start: async () => undefined,
      stop: async () => undefined,
      listModels: async () => [
        { id: "gpt-5.6-sol", supportedReasoningEfforts: ["medium"] },
      ],
      getStatus: async () => ({ version: "fake" }),
      createSession: async (config) => {
        let turn = 0;
        return {
          onEvent: () => () => undefined,
          sendAndWait: async () => {
            turn += 1;
            if (turn === 1) {
              return { content: approvalResponse() };
            }
            await config.tools.find((tool) => tool.name === "read_incident_scope")!.handler({});
            return { content: finalResponse() };
          },
          destroy: async () => undefined,
        };
      },
    }),
    clock: () => NOW,
  });
  const sessionRoot = trialDirectory(root, "case-01", 1, "with-skill");
  assert.doesNotReject(() => readFile(join(sessionRoot, "session-artifact.json"), "utf8"));
  assert.doesNotReject(() => readFile(join(sessionRoot, "fixture-approval-ledger.json"), "utf8"));
  assert.doesNotReject(() => readFile(join(sessionRoot, "artifact-hashes.json"), "utf8"));
});
