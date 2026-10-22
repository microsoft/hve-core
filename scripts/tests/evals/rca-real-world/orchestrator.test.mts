// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

import {
  redactArtifact,
  runTrial,
  type ModelClient,
  type SessionCreationConfig,
} from "../../../evals/rca-real-world/orchestrator.mts";

const NOW = new Date("2026-10-19T20:00:00.000Z");

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

test("redacts Windows and Unix home paths", () => {
  const result = redactArtifact(
    {
      windowsPath: "C:\\Users\\person\\secret",
      unixPath: "/home/person/secret",
    },
    [],
  );

  assert.deepEqual(result.value, {
    windowsPath: "[REDACTED_HOME]\\secret",
    unixPath: "[REDACTED_HOME]/secret",
  });
  assert.equal(result.replacements, 2);
});

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
  assert.ok(artifact.redactionManifest.replacements >= 1);
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
  const sessionRoot = join(root, "sessions", "case-01", "trial-1");
  assert.doesNotReject(() => readFile(join(sessionRoot, "session-artifact.json"), "utf8"));
  assert.doesNotReject(() => readFile(join(sessionRoot, "fixture-approval-ledger.json"), "utf8"));
  assert.doesNotReject(() => readFile(join(sessionRoot, "artifact-hashes.json"), "utf8"));
});
