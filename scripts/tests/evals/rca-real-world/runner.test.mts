// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { describe, test } from "node:test";

import { runCliTrial, type CliInvoker } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import type { DiagnosticReport } from "../../../evals/rca-real-world/communication.mts";
import {
  EVALUATION_CASE_IDS,
  EVALUATION_PROTOCOL,
  TRANSFORMATION_VERSION,
  sha256,
  stableJson,
} from "../../../evals/rca-real-world/contracts.mts";
import { createInputFingerprint, runRound } from "../../../evals/rca-real-world/runner.mts";
import { trialDirectory } from "../../../evals/rca-real-world/conditions.mts";
import { fixtureInventory } from "./cli-fixture.mts";

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
  const metadataPaths = EVALUATION_CASE_IDS.flatMap(
    (caseId) => ["incident.json", "source-coverage.json"].map((name) => `inputs/model-visible/${caseId}/${name}`),
  );
  for (const path of [...mappingPaths, ...metadataPaths]) {
    const absolutePath = join(runRoot, ...path.split("/"));
    await mkdir(dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, "{}\n", "utf8");
  }
  const expectedFiles = [
    ...paths.slice(0, 3).map((path) => ({ path, sha256: sha256("fixture") })),
    ...mappingPaths.map((path) => ({ path, sha256: sha256("{}\n") })),
    ...metadataPaths.map((path) => ({ path, sha256: sha256("{}\n") })),
    { path: "package-lock.json", sha256: sha256("fixture") },
    { path: "preparation-manifest.json", sha256: sha256("manifest") },
    { path: paths[4], sha256: sha256("fixture") },
  ];
  expectedFiles.sort((left, right) => left.path < right.path ? -1 : left.path > right.path ? 1 : 0);
  assert.equal(
    await createInputFingerprint(root, runRoot),
    sha256(stableJson(expectedFiles)),
  );
  await writeFile(join(runRoot, ...mappingPaths[0]!.split("/")), '{"changed":true}\n', "utf8");
  assert.notEqual(
    await createInputFingerprint(root, runRoot),
    sha256(stableJson(expectedFiles)),
  );
  const beforeMetadataChange = await createInputFingerprint(root, runRoot);
  await writeFile(join(runRoot, ...metadataPaths[0]!.split("/")), '{"changed":true}\n', "utf8");
  assert.notEqual(await createInputFingerprint(root, runRoot), beforeMetadataChange);
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
  const manifestPath = join(scorerRoot, "preparation-manifest.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  for (const item of manifest.cases) {
    const caseRoot = join(root, "inputs", "model-visible", item.neutralId);
    const coverage = JSON.parse(await readFile(join(caseRoot, "source-coverage.json"), "utf8"));
    item.modalities = await Promise.all(coverage.sources.map(async (source: { modality: string; rowCount: number }) => ({
      ...source, storePath: `${source.modality}.jsonl`,
      sha256: sha256(await readFile(join(caseRoot, `${source.modality}.jsonl`))),
    })));
  }
  await writeFile(manifestPath, stableJson(manifest));
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
  return async (args, options) => {
    const inventory = await fixtureInventory(args, options);
    if (inventory) {
      return inventory;
    }
    if (args.includes("--version")) {
      return result("GitHub Copilot CLI 1.0.101-0\n");
    }
    assert.equal(args.includes("--attachment"), false);
    assert.equal(args.includes("--no-custom-instructions"), true);
    assert.equal(args.includes("--available-tools"), true);
    assert.equal(options.env?.COPILOT_HOME, join(options.cwd, ".isolated-home", ".copilot"));
    const promptIndex = args.indexOf("-p");
    const prompt = promptIndex >= 0 ? args[promptIndex + 1] ?? "" : "";
    if (!(await readdir(options.cwd)).includes(".github")) {
      assert.doesNotMatch(prompt, /root-cause-analysis|causal-evidence-likelihood|statistical-hypothesis-testing|required eight|completion gate|accountable human sign-off/i);
    }
    const caseId = /case-0[1-5]/.exec(prompt)?.[0];
    if (!caseId) {
      throw new Error("Missing case in CLI prompt");
    }
    if (prompt.startsWith("Investigate neutral incident")) {
      assert.match(prompt, /Current host UTC time: 2026-10-19T20:00:00.000Z/);
      assert.match(prompt, /Use exactly "2026-10-19T20:15:00.000Z"/);
      return result(
        `${JSON.stringify({
          type: "assistant.message",
          data: { content: approvalResponse(caseId), phase: "final_answer" },
        })}\n`, prompt, (await readdir(options.cwd)).includes(".github"),
      );
    }
    return result(
      `${JSON.stringify({
        type: "assistant.message",
        data: { phase: "final_answer", content: !(await readdir(options.cwd)).includes(".github")
          ? [
            `- Candidate target: ${serviceByCase[caseId]}`,
            `- Candidate mechanism: ${faultByCase[caseId]}`,
            "- Working confidence: Medium; fixture evidence supports this diagnosis.",
            "Simulated fixture approval; no production authorization.",
          ].join("\n")
          : finalOutput(serviceByCase[caseId]!, faultByCase[caseId]!) },
      })}\n`, prompt, (await readdir(options.cwd)).includes(".github"),
    );
  };
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

function result(stdout: string, prompt?: string, skilled = true) {
  if (prompt) {
    const identity = JSON.parse(/Copy these identity fields exactly: (\{[^\n]+\})\./.exec(prompt)![1]!);
    stdout = stdout.split(/\r?\n/).filter(Boolean).map((line) => {
      const event = JSON.parse(line);
      const content: string = event.data.content;
      const requestText = /```json\s*([\s\S]*?)```/i.exec(content)?.[1];
      const payload = requestText ? {
        messageType: "evidence_request", ...JSON.parse(requestText),
      } : {
        messageType: "final",
        report: {
          candidate: {
            target: /No defensible/i.test(content) ? null : serviceByCase[identity.caseId],
            mechanism: /No defensible/i.test(content) ? null : faultByCase[identity.caseId],
            confidence: "Medium; bounded fixture evidence.",
          },
          ...(skilled ? { finding: { status: "not-established", target: null, mechanism: null } } : {}),
          authority: { simulated: true, productionAuthorization: false },
          limitations: ["Human review pending."], narrative: content,
        },
      };
      return JSON.stringify({ ...event, data: { ...event.data, content: JSON.stringify({ ...identity, ...payload }) } });
    }).join("\n");
  }
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

for (const condition of ["with-skill", "without-skill"] as const) {
  for (const strategy of ["no-tools", "direct-query"] as const) {
    test(`lets ${condition} choose ${strategy} without prescribed scope or comparison steps`, async (context) => {
      const root = await preparedRun();
      context.after(() => rm(root, { recursive: true, force: true }));
      const base = fakeCliInvoker();
      let modelTurns = 0;
      const artifact = await runCliTrial({
        repositoryRoot: resolve("."),
        runRoot: root,
        runId: "ad-hoc-choice",
        caseId: "case-02",
        trial: 1,
        condition,
        clock: () => NOW,
        cliInvoker: async (args, options) => {
          const index = args.indexOf("-p");
          const prompt = index >= 0 ? args[index + 1] ?? "" : "";
          if (index >= 0) modelTurns += 1;
          if (prompt.startsWith("Investigate neutral incident")) {
            assert.match(prompt, /encouraged, but not required/);
            assert.doesNotMatch(prompt, /Map `queryGuidance|first approval cycle permits|request one exact adaptive batch/);
            const request = JSON.parse(focusedApprovalResponse("case-02").split("```json\n")[1]!.split("\n```")[0]!);
            request.approvalRequests[0].parameters.startTime = 1699999877;
            request.approvalRequests[0].parameters.endTime = 1700000987;
            return result(`${JSON.stringify({ type: "assistant.message", data: { phase: "final_answer",
              content: strategy === "no-tools"
                ? "- Candidate target: No defensible candidate\n- Candidate mechanism: Unassessed\n- Working confidence: Low; evidence not collected.\nSimulated fixture; no production authorization."
                : `\`\`\`json\n${JSON.stringify(request)}\n\`\`\``,
            } })}\n`, prompt, condition === "with-skill");
          }
          if (prompt.startsWith("TOOL RESULTS")) {
            assert.match(prompt, /1699999877/);
            assert.match(prompt, /1700000987/);
            assert.doesNotMatch(prompt, /request one.*focused|queryGuidance/);
          }
          return base(args, options);
        },
      });
      assert.equal(artifact.endReason, "complete");
      assert.equal(artifact.error, undefined);
      assert.ok(artifact.finalResponse);
      assert.equal(modelTurns, strategy === "no-tools" ? 1 : 2);
      assert.equal(artifact.evidenceToolTraces.length, strategy === "no-tools" ? 0 : 1);
    });
  }
}

test("still aborts an unexplained empty evidence request without requesting a final report", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const base = fakeCliInvoker();
  const artifact = await runCliTrial({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "invalid-empty-request",
    caseId: "case-02",
    trial: 1,
    clock: () => NOW,
    cliInvoker: async (args, options) => {
      const index = args.indexOf("-p");
      const prompt = index >= 0 ? args[index + 1] ?? "" : "";
      if (prompt.startsWith("Investigate neutral incident")) {
        return result(`${JSON.stringify({
          type: "assistant.message", data: { content: '```json\n{"approvalRequests":[]}\n```' },
        })}\n`, prompt);
      }
      assert.equal(prompt.startsWith("TOOL RESULTS"), false);
      return base(args, options);
    },
  });
  assert.equal(artifact.endReason, "error");
  assert.match(artifact.error ?? "", /1-12 calls/);
  assert.equal(artifact.finalResponse, undefined);
  assert.equal(artifact.evidenceToolTraces.length, 0);
});

test("defaults to ten isolated first-round sessions and records condition-specific hashes", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const summary = await runRound({
    repositoryRoot: resolve("."),
    runRoot: root,
    runId: "round-one-run",
    round: 1,
    cliInvoker: fakeCliInvoker(),
    clock: () => NOW,
  });
  assert.equal(summary.mode, "both");
  assert.equal(summary.trials.length, 10);
  assert.deepEqual(
    summary.trials.map((result) => `${result.caseId}:${result.condition}`),
    [
      "case-01:with-skill",
      "case-02:with-skill",
      "case-03:with-skill",
      "case-04:with-skill",
      "case-05:with-skill",
      "case-01:without-skill",
      "case-02:without-skill",
      "case-03:without-skill",
      "case-04:without-skill",
      "case-05:without-skill",
    ],
  );
  assert.equal(summary.roundOneCheckpoint?.decision, "continue");
  const sessionIds = new Set<string>();
  const toolContracts = new Map<string, string>();
  for (const { caseId, condition } of summary.trials) {
    const artifact = JSON.parse(
      await readFile(join(trialDirectory(root, caseId, 1, condition), "session-artifact.json"), "utf8"),
    ) as {
      cliCapture: { turn1?: unknown; turn2?: unknown };
      evidenceToolTraces: readonly unknown[];
      approvalLedger: { records: readonly { status: string }[] };
      condition: string;
      preflight: { isolation: { enabledSkills: readonly string[] }; clientStatus: { sessionId: string } };
      hashes: { skillBundleSha256: string; toolContractSha256: string };
    };
    assert.ok(artifact.cliCapture.turn1);
    assert.ok(artifact.cliCapture.turn2);
    assert.equal(artifact.evidenceToolTraces.length, 1);
    assert.ok(artifact.approvalLedger.records.every((record) => record.status === "Consumed"));
    assert.equal(artifact.condition, condition);
    assert.equal(artifact.preflight.isolation.enabledSkills.length, condition === "with-skill" ? 3 : 0);
    assert.equal(artifact.hashes.skillBundleSha256 === sha256(""), condition === "without-skill");
    if (condition === "with-skill") toolContracts.set(caseId, artifact.hashes.toolContractSha256);
    else assert.equal(artifact.hashes.toolContractSha256, toolContracts.get(caseId));
    sessionIds.add(artifact.preflight.clientStatus.sessionId);
  }
  assert.equal(sessionIds.size, 10);
  const checkpoint = JSON.parse(await readFile(join(root, "round-one-checkpoint.json"), "utf8"));
  assert.equal(Object.keys(checkpoint.trialResultHashes).length, 10);
  assert.ok(checkpoint.trialResultHashes["with-skill/case-01"]);
  assert.ok(checkpoint.trialResultHashes["without-skill/case-01"]);
});

test("does not continue either condition when a prior paired result is missing", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const base = {
    repositoryRoot: resolve("."), runRoot: root, runId: "missing-pair",
    cliInvoker: fakeCliInvoker(), clock: () => NOW,
  };
  await runRound({ ...base, round: 1 });
  await rm(join(trialDirectory(root, "case-01", 1, "without-skill"), "trial-result.json"));
  let invocations = 0;
  await assert.rejects(runRound({
    ...base, round: 2,
    cliInvoker: async () => { invocations += 1; throw new Error("Must not invoke"); },
  }), { code: "ENOENT" });
  assert.equal(invocations, 0);
});

test("does not start round two when the round-one checkpoint pauses", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
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

test("runs rounds two and three only after unchanged input and prerequisites", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
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
  assert.equal(summary.trials.length, 30);
  assert.deepEqual(
    summary.trials.map((result) => result.trial),
    [...Array<number>(10).fill(1), ...Array<number>(10).fill(2), ...Array<number>(10).fill(3)],
  );
});

for (const mode of ["with-skill", "without-skill"] as const) {
  test(`runs only ${mode} when selected and freezes the selection on resume`, async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const base = {
      repositoryRoot: resolve("."), runRoot: root, runId: `single-${mode}`,
      cliInvoker: fakeCliInvoker(), clock: () => NOW,
    };
    const first = await runRound({ ...base, round: 1, mode });
    assert.equal(first.trials.length, 5);
    assert.ok(first.trials.every((trial) => trial.condition === mode));
    await assert.rejects(
      runRound({ ...base, round: 2, mode: "both" }),
      /conditions cannot change/,
    );
    const second = await runRound({ ...base, round: 2 });
    assert.equal(second.mode, mode);
    assert.equal(second.trials.length, 10);
    assert.ok(second.trials.every((trial) => trial.condition === mode));
  });
}

test("never replaces an existing trial", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
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

for (const profile of ["debug", "production"] as const) {
  test(`uses the ${profile} model for both conditions and freezes it on resume`, async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const model = profile === "debug" ? "gpt-5.6-luna" : "gpt-5.6-sol";
    const fake = fakeCliInvoker();
    const base = {
      repositoryRoot: resolve("."), runRoot: root, runId: `profile-${profile}`,
      profile, clock: () => NOW,
      cliInvoker: async (args: readonly string[], options: Parameters<CliInvoker>[1]) => {
        if (args.includes("-p")) assert.equal(args[args.indexOf("--model") + 1], model);
        return fake(args, options);
      },
    };
    const summary = await runRound({ ...base, round: 1 });
    assert.equal(summary.model, model);
    assert.ok(summary.trials.every((trial) => trial.model === model && trial.integrity === "pass"));
    const manifest = JSON.parse(await readFile(join(root, "run-manifest.json"), "utf8"));
    assert.equal(manifest.protocol, EVALUATION_PROTOCOL);
    assert.equal(manifest.model, model);
    await assert.rejects(runRound({
      ...base, round: 2, profile: profile === "debug" ? "production" : "debug",
    }), /profile/i);
    await writeFile(join(root, "run-manifest.json"), stableJson({ ...manifest, protocol: "host-directed" }));
    await assert.rejects(runRound({ ...base, round: 2 }), /protocol|new.*run/i);
  });
}

for (const condition of ["with-skill", "without-skill"] as const) {
  for (const budget of ["model-turns", "evidence-calls"] as const) {
    test(`enforces the shared ${budget} budget without retries: ${condition}`, async (context) => {
      const root = await preparedRun();
      context.after(() => rm(root, { recursive: true, force: true }));
      const fake = fakeCliInvoker();
      let modelTurns = 0;
      const envelope = JSON.parse(approvalResponse("case-01").split("```json\n")[1]!.split("\n```")[0]!);
      if (budget === "evidence-calls") {
        envelope.approvalRequests = Array.from({ length: 12 }, () => ({ ...envelope.approvalRequests[0] }));
      }
      const artifact = await runCliTrial({
        repositoryRoot: resolve("."), runRoot: root, runId: `budget-${budget}`,
        caseId: "case-01", trial: 1, condition, clock: () => NOW,
        cliInvoker: async (args, options) => {
          if (!args.includes("-p")) return fake(args, options);
          modelTurns += 1;
          return result(`${JSON.stringify({ type: "assistant.message", data: { phase: "final_answer",
            content: `\`\`\`json\n${JSON.stringify(envelope)}\n\`\`\``,
          } })}\n`, args[args.indexOf("-p") + 1], condition === "with-skill");
        },
      });
      assert.equal(artifact.endReason, "error");
      assert.match(artifact.error ?? "", /resource budget exhausted/);
      assert.equal(modelTurns, budget === "model-turns" ? 8 : 3);
      assert.equal(artifact.evidenceToolTraces.length, budget === "model-turns" ? 7 : 24);
      assert.equal(artifact.finalResponse, undefined);
    });
  }
}

test("persists failed arbitrary tool execution rather than discarding its trace", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const fake = fakeCliInvoker();
  const envelope = JSON.parse(focusedApprovalResponse("case-02").split("```json\n")[1]!.split("\n```")[0]!);
  envelope.approvalRequests[0].parameters.startTime = "not-a-time";
  const artifact = await runCliTrial({
    repositoryRoot: resolve("."), runRoot: root, runId: "invalid-window",
    caseId: "case-02", trial: 1, clock: () => NOW,
    cliInvoker: async (args, options) => args.includes("-p")
      ? result(`${JSON.stringify({ type: "assistant.message", data: { phase: "final_answer",
        content: `\`\`\`json\n${JSON.stringify(envelope)}\n\`\`\``,
      } })}\n`, args[args.indexOf("-p") + 1])
      : fake(args, options),
  });
  assert.equal(artifact.endReason, "error");
  assert.match(artifact.error ?? "", /Invalid time value: not-a-time/);
  assert.equal(artifact.evidenceToolTraces.length, 1);
  const traces = JSON.parse(await readFile(join(trialDirectory(root, "case-02", 1, "with-skill"), "mcp-tool-traces.json"), "utf8"));
  assert.equal(traces.traces[0].status, "error");
});

test("pauses after two technical failures and resumes only unattempted sessions with explicit approval", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const base = {
    repositoryRoot: resolve("."), runRoot: root, runId: "technical-pause",
    round: 1 as const, clock: () => NOW,
  };
  let attempts = 0;
  const first = await runRound({
    ...base,
    cliInvoker: async () => {
      attempts += 1;
      throw new Error("Fixture process launch failed");
    },
  });
  assert.equal(attempts, 2);
  assert.equal(first.trials.length, 2);
  assert.equal(first.roundExecution?.status, "paused-technical-failures");
  assert.equal(first.roundExecution.remainingSessions, 8);
  assert.equal(first.roundOneCheckpoint?.decision, "pause");
  const failedPath = join(trialDirectory(root, "case-01", 1, "with-skill"), "session-artifact.json");
  const original = await readFile(failedPath, "utf8");
  await assert.rejects(runRound(base), /Run manifest already exists/);
  let continuedAttempts = 0;
  const fake = fakeCliInvoker();
  const resumed = await runRound({
    ...base, continueAfterTechnicalStop: true,
    cliInvoker: async (args, options) => {
      if (args.includes("--version")) {
        continuedAttempts += 1;
      }
      return fake(args, options);
    },
  });
  assert.equal(continuedAttempts, 8);
  assert.equal(resumed.trials.length, 10);
  assert.equal(resumed.roundExecution?.status, "complete");
  assert.equal(resumed.roundExecution.remainingSessions, 0);
  assert.equal(resumed.roundExecution.continuations.length, 1);
  assert.equal(resumed.roundExecution.pauses.length, 1);
  assert.equal(await readFile(failedPath, "utf8"), original);
  assert.equal(resumed.roundOneCheckpoint?.decision, "pause");
  await assert.rejects(runRound({ ...base, continueAfterTechnicalStop: true }),
    /No remaining sessions/);
});

test("does not continue a technical stop after prior artifacts change", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const base = {
    repositoryRoot: resolve("."), runRoot: root, runId: "technical-tamper",
    round: 1 as const, clock: () => NOW,
    cliInvoker: async () => { throw new Error("Fixture unavailable"); },
  };
  await runRound(base);
  const path = join(trialDirectory(root, "case-01", 1, "with-skill"), "session-artifact.json");
  await writeFile(path, "{}\n");
  await assert.rejects(runRound({ ...base, continueAfterTechnicalStop: true }),
    /artifacts changed before continuation/);
});

for (const failingAttempts of [[1, 3, 4], [5, 6]]) {
  test(`counts consecutive technical failures across condition boundaries: ${failingAttempts}`, async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    let attempts = 0;
    const fake = fakeCliInvoker();
    const summary = await runRound({
      repositoryRoot: resolve("."), runRoot: root, runId: "consecutive-stop",
      round: 1, clock: () => NOW,
      cliInvoker: async (args, options) => {
        if (args.includes("--version") && failingAttempts.includes(++attempts)) {
          throw new Error("Fixture CLI unavailable");
        }
        return fake(args, options);
      },
    });
    const expectedAttempts = failingAttempts[failingAttempts.length - 1];
    assert.equal(attempts, expectedAttempts);
    assert.equal(summary.trials.length, expectedAttempts);
    assert.equal(summary.roundExecution?.consecutiveTechnicalFailures, 2);
    assert.equal(summary.roundExecution?.status, "paused-technical-failures");
  });
}

test("separates valid machine diagnostics from poorly formatted skill narratives", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const fake = fakeCliInvoker();
  const summary = await runRound({
    repositoryRoot: resolve("."), runRoot: root, runId: "diagnostic-failures",
    round: 1, clock: () => NOW,
    cliInvoker: async (args, options) => {
      if (args.some((arg) => arg.startsWith("TOOL RESULTS"))) {
        return result(`${JSON.stringify({
          type: "assistant.message", data: { content: "No defensible diagnosis.", phase: "final_answer" },
        })}\n`, args[args.indexOf("-p") + 1], (await readdir(options.cwd)).includes(".github"));
      }
      return fake(args, options);
    },
  });
  assert.equal(summary.trials.length, 10);
  assert.equal(summary.roundExecution?.status, "complete");
  assert.equal(summary.roundExecution.consecutiveTechnicalFailures, 0);
  assert.equal(summary.roundOneCheckpoint?.decision, "pause");
});

describe("versioned host communication", () => {
  test("stops after two malformed machine responses without repairing or retrying them", async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const fake = fakeCliInvoker();
    let turns = 0;
    const summary = await runRound({
      repositoryRoot: resolve("."), runRoot: root, runId: "malformed-stop", round: 1, clock: () => NOW,
      cliInvoker: async (args, options) => {
        const value = await fake(args, options);
        if (!args.includes("-p")) return value;
        turns++;
        return result(JSON.stringify({ type: "assistant.message", data: { content: "Unstructured final answer." } }));
      },
    });
    assert.equal(turns, 2);
    assert.equal(summary.trials.length, 2);
    assert.equal(summary.roundExecution?.status, "paused-technical-failures");
    assert.ok(summary.trials.every((trial) => trial.outcome === "protocol-error" && trial.errorCode === "missing-envelope"));
  });

  test("rejects stale protocol and inconsistent terminal results before further inference", async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const base = { repositoryRoot: resolve("."), runRoot: root, runId: "result-boundary", clock: () => NOW };
    await runRound({ ...base, round: 1, cliInvoker: fakeCliInvoker() });
    const path = join(trialDirectory(root, "case-01", 1, "with-skill"), "trial-result.json");
    const original = JSON.parse(await readFile(path, "utf8"));
    let invocations = 0;
    for (const change of [{ protocol: "ad-hoc-v1" }, { outcome: "not-reported" }, { outcome: "protocol-error" }]) {
      await writeFile(path, JSON.stringify({ ...original, ...change }));
      await assert.rejects(runRound({
        ...base, round: 2, cliInvoker: async () => { invocations++; throw new Error("Must not infer"); },
      }), /Invalid evaluation result/);
    }
    assert.equal(invocations, 0);
  });

  test("keeps redacted narratives and selected envelope hashes consistent through scoring", async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const fake = fakeCliInvoker();
    const summary = await runRound({
      repositoryRoot: resolve("."), runRoot: root, runId: "redacted-contract", round: 1, clock: () => NOW,
      cliInvoker: async (args, options) => {
        const value = await fake(args, options);
        if (!args.includes("-p")) return value;
        const event = JSON.parse(value.stdout);
        const message = JSON.parse(event.data.content);
        if (message.report) message.report.narrative += `\nSource path: ${join(homedir(), "private-fixture")}`;
        event.data.content = JSON.stringify(message);
        return result(JSON.stringify(event));
      },
    });
    assert.equal(summary.trials.length, 10);
    assert.equal(summary.roundExecution?.status, "complete");
    assert.equal(summary.roundExecution?.consecutiveTechnicalFailures, 0);
    const artifact = JSON.parse(await readFile(join(trialDirectory(root, "case-01", 1, "with-skill"),
      "session-artifact.json"), "utf8"));
    assert.equal(artifact.report.narrative.includes(homedir()), false);
    assert.ok(artifact.report.narrative.includes("[REDACTED_PATH]"));
  });

  for (const condition of ["with-skill", "without-skill"] as const) {
    for (const fenced of [false, true]) {
      test(`executes ${condition} final-answer requests after commentary (${fenced ? "fenced" : "raw"})`, async (context) => {
        const root = await preparedRun();
        context.after(() => rm(root, { recursive: true, force: true }));
        const fake = fakeCliInvoker();
        const artifact = await runCliTrial({
          repositoryRoot: resolve("."), runRoot: root, runId: "multi-message",
          caseId: "case-02", trial: 1, condition, clock: () => NOW,
          cliInvoker: async (args, options) => {
            const value = await fake(args, options);
            if (!args.includes("-p")) return value;
            const event = JSON.parse(value.stdout);
            if (fenced) event.data.content = `\`\`\`json\n${event.data.content}\n\`\`\``;
            return result([
              JSON.stringify({ type: "assistant.message", data: { content: "Opening commentary.", phase: "commentary" } }),
              JSON.stringify(event),
            ].join("\n"));
          },
        });
        assert.equal(artifact.endReason, "complete", artifact.error ?? "Expected a complete session");
        assert.equal(artifact.evidenceToolTraces.length, 1);
        assert.ok(artifact.communication?.turns.every((turn) => turn.messageIndex === 1));
        const directory = trialDirectory(root, "case-02", 1, condition);
        const batch = JSON.parse(await readFile(join(directory, "host-evidence-turn-1.json"), "utf8"));
        const ledger = JSON.parse(await readFile(join(directory, "fixture-approval-ledger.json"), "utf8"));
        const traces = JSON.parse(await readFile(join(directory, "mcp-tool-traces.json"), "utf8"));
        assert.equal(batch.protocol, EVALUATION_PROTOCOL);
        assert.equal(batch.complete, true);
        assert.equal(batch.results[0].requestId, ledger.records[0].requestId);
        assert.equal(batch.results[0].requestId, traces.traces[0].requestId);
        assert.equal(batch.results[0].resultHash, traces.traces[0].resultHash);
        assert.equal(batch.results[0].resultBytes, Buffer.byteLength(stableJson(batch.results[0].result)!, "utf8"));
      });
    }
  }

  for (const condition of ["with-skill", "without-skill"] as const) {
    for (const terminal of ["final", "blocked"] as const) {
      test(`hands off raw final-answer requests and resumes with results: ${condition}/${terminal}`, async (context) => {
        const root = await preparedRun();
        context.after(() => rm(root, { recursive: true, force: true }));
        const fake = fakeCliInvoker();
        let modelTurns = 0;
        const artifact = await runCliTrial({
          repositoryRoot: resolve("."), runRoot: root, runId: "raw-handoff",
          caseId: "case-02", trial: 1, condition, clock: () => NOW,
          cliInvoker: async (args, options) => {
            if (!args.includes("-p")) return fake(args, options);
            modelTurns++;
            const prompt = args[args.indexOf("-p") + 1]!;
            assert.match(prompt, /End the invocation immediately/);
            const identity = {
              protocol: EVALUATION_PROTOCOL, caseId: "case-02",
              messageId: `raw-handoff/${condition}/case-02/trial-1/turn-${modelTurns}`,
            };
            const report: DiagnosticReport = {
              candidate: { target: null, mechanism: null, confidence: "None; no causal attribution established." },
              ...(condition === "with-skill" ? {
                finding: { status: "not-established" as const, target: null, mechanism: null },
              } : {}),
              authority: { simulated: true, productionAuthorization: false },
              limitations: ["The scope read alone does not establish a cause."],
              narrative: "No causal finding established. Human review remains pending.",
            };
            if (modelTurns > 1) {
              assert.equal(modelTurns, 2);
              assert.ok(args.some((arg) => arg.startsWith("--resume=")));
              assert.match(prompt, /^TOOL RESULTS/);
              const batch = JSON.parse(await readFile(join(
                trialDirectory(root, "case-02", 1, condition), "host-evidence-turn-1.json",
              ), "utf8"));
              assert.equal(batch.complete, true);
              assert.equal(batch.results.length, 1);
              assert.equal(batch.results[0].tool, "read_incident_scope");
            }
            const message = modelTurns === 1 ? {
              ...identity, messageType: "evidence_request", approvalRequests: [{
                tool: "read_incident_scope", operation: "read", parameters: {},
                evidenceSought: "Incident scope and coverage", target: "case-02",
                scope: "current neutral case only", maximumCallCount: 1,
                expectedRisk: "read-only bounded fixture evidence", expiresAt: "2026-10-19T20:15:00.000Z",
              }],
            } : {
              ...identity, messageType: terminal, report,
              ...(terminal === "blocked" ? { reason: "Scope alone cannot distinguish causal hypotheses." } : {}),
            };
            return {
              exitCode: 0, timedOut: false, durationMs: 1, stderr: "",
              stdout: [
                { type: "assistant.turn_start", data: {} },
                { type: "assistant.message", data: { phase: "commentary", content: "Processing this investigation step." } },
                { type: "assistant.message", data: { phase: "final_answer", content: JSON.stringify(message) } },
                { type: "assistant.turn_end", data: {} },
                { type: "result", data: {} },
              ].map((event) => JSON.stringify(event)).join("\n"),
            };
          },
        });
        assert.equal(modelTurns, 2);
        assert.equal(artifact.endReason, "complete", artifact.error ?? "Expected a complete session");
        assert.equal(artifact.communication?.outcome, terminal);
        assert.equal(artifact.evidenceToolTraces.length, 1);
        assert.equal(artifact.communication?.turns.length, 2);
        assert.ok(artifact.communication?.turns.every((turn) => turn.messageIndex === 1));
        const ledger = artifact.approvalLedger;
        assert.ok(ledger && typeof ledger === "object" && "records" in ledger && Array.isArray(ledger.records));
        assert.equal(ledger.records.length, 1);
        const approval: unknown = ledger.records[0];
        assert.ok(approval && typeof approval === "object" && "consumedCallCount" in approval);
        assert.equal(approval.consumedCallCount, 1);
      });
    }

    test(`rejects raw commentary request plus blocked final before evidence execution: ${condition}`, async (context) => {
      const root = await preparedRun();
      context.after(() => rm(root, { recursive: true, force: true }));
      const fake = fakeCliInvoker();
      let modelTurns = 0;
      const artifact = await runCliTrial({
        repositoryRoot: resolve("."), runRoot: root, runId: "raw-conflict",
        caseId: "case-02", trial: 1, condition, clock: () => NOW,
        cliInvoker: async (args, options) => {
          if (!args.includes("-p")) return fake(args, options);
          modelTurns++;
          const identity = {
            protocol: EVALUATION_PROTOCOL, caseId: "case-02",
            messageId: `raw-conflict/${condition}/case-02/trial-1/turn-1`,
          };
          return {
            exitCode: 0, timedOut: false, durationMs: 1, stderr: "",
            stdout: [
              { type: "assistant.message", data: { phase: "commentary", content: JSON.stringify({
                ...identity, messageType: "evidence_request", approvalRequests: [{
                  tool: "read_incident_scope", operation: "read", parameters: {},
                  evidenceSought: "Incident scope", target: "case-02",
                  scope: "current neutral case only", maximumCallCount: 1,
                  expectedRisk: "read-only bounded fixture evidence", expiresAt: "2026-10-19T20:15:00.000Z",
                }],
              }) } },
              { type: "assistant.message", data: { phase: "final_answer", content: JSON.stringify({
                ...identity, messageType: "blocked", reason: "Requested evidence has not returned.",
                report: {
                  candidate: { target: null, mechanism: null, confidence: "None; pending evidence." },
                  authority: { simulated: true, productionAuthorization: false },
                  limitations: ["No results received."], narrative: "Blocked pending requested results.",
                },
              }) } },
            ].map((event) => JSON.stringify(event)).join("\n"),
          };
        },
      });
      assert.equal(modelTurns, 1);
      assert.equal(artifact.communication?.errorCode, "ambiguous-envelope");
      assert.equal(artifact.evidenceToolTraces.length, 0);
      const ledger = artifact.approvalLedger;
      assert.ok(ledger && typeof ledger === "object" && "records" in ledger && Array.isArray(ledger.records));
      assert.equal(ledger.records.length, 0);
      assert.equal(artifact.report, undefined);
      assert.equal(artifact.responses?.length, 2);
    });
  }

  for (const failure of [
    "missing-envelope", "ambiguous-envelope", "invalid-tool-parameters",
    "invalid-second-request", "expired-second-request", "wrong-operation",
  ] as const) {
    test(`persists ${failure} as a protocol failure before tool execution`, async (context) => {
      const root = await preparedRun();
      context.after(() => rm(root, { recursive: true, force: true }));
      const fake = fakeCliInvoker();
      let turns = 0;
      const artifact = await runCliTrial({
        repositoryRoot: resolve("."), runRoot: root, runId: "protocol-failure",
        caseId: "case-01", trial: 1, clock: () => NOW,
        cliInvoker: async (args, options) => {
          const value = await fake(args, options);
          if (!args.includes("-p")) return value;
          turns++;
          if (failure === "missing-envelope") return result(JSON.stringify({
            type: "assistant.message", data: { content: "Blocked pending evidence." },
          }));
          if (failure === "ambiguous-envelope") return result(`${value.stdout}\n${value.stdout}`);
          const event = JSON.parse(value.stdout);
          const message = JSON.parse(event.data.content);
          if (failure === "wrong-operation") message.approvalRequests[0].operation = "execute";
          else if (failure === "expired-second-request") message.approvalRequests.push({
            ...message.approvalRequests[0], expiresAt: NOW,
          });
          else if (failure === "invalid-second-request") message.approvalRequests.push({
            ...message.approvalRequests[0], parameters: { unknown: true },
          });
          else message.approvalRequests[0].parameters = { unknown: true };
          event.data.content = JSON.stringify(message);
          return result(JSON.stringify(event));
        },
      });
      assert.equal(turns, 1);
      assert.equal(artifact.endReason, "error");
      assert.equal(artifact.communication?.outcome, "protocol-error");
      assert.equal(artifact.evidenceToolTraces.length, 0);
      assert.equal(artifact.finalResponse, undefined);
    });
  }

  test("rejects changed prepared telemetry before inference", async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    const path = join(root, "inputs", "model-visible", "case-01", "metrics.jsonl");
    await writeFile(path, '{"changed":true}\n');
    await assert.rejects(runRound({
      repositoryRoot: resolve("."), runRoot: root, runId: "changed-telemetry", round: 1,
      cliInvoker: async () => { throw new Error("Inference must not start"); },
    }), /Prepared store integrity mismatch/);
  });

  test("retains oversized complete batches without silently clipping or delivering them", async (context) => {
    const root = await preparedRun();
    context.after(() => rm(root, { recursive: true, force: true }));
    await writeFile(join(root, "inputs", "model-visible", "case-02", "logs.jsonl"),
      JSON.stringify({ timestamp: 1700000001, service: "service-a", message: "x".repeat(60000) }) + "\n");
    const fake = fakeCliInvoker();
    const artifact = await runCliTrial({
      repositoryRoot: resolve("."), runRoot: root, runId: "oversized-batch",
      caseId: "case-02", trial: 1, clock: () => NOW,
      cliInvoker: async (args, options) => {
        const value = await fake(args, options);
        if (!args.includes("-p")) return value;
        const event = JSON.parse(value.stdout);
        const message = JSON.parse(event.data.content);
        const template = message.approvalRequests[0];
        message.approvalRequests = Array.from({ length: 5 }, () => ({
          ...template, tool: "search_logs", operation: "search",
          parameters: { startTime: 1700000000, endTime: 1700000300, limit: 1 },
        }));
        event.data.content = JSON.stringify(message);
        return result(JSON.stringify(event));
      },
    });
    assert.equal(artifact.communication?.errorCode, "batch-too-large");
    assert.equal(artifact.endReason, "error");
    assert.equal(artifact.evidenceToolTraces.length, 5);
    const batch = JSON.parse(await readFile(join(trialDirectory(root, "case-02", 1, "with-skill"),
      "host-evidence-turn-1.json"), "utf8"));
    assert.equal(batch.complete, true);
    assert.equal(batch.delivery.status, "oversized");
    assert.equal(batch.results.length, 5);
    assert.equal(batch.results[0].result.data.rows[0].message.length, 60000);
  });
});

test("carries a consecutive technical failure across round boundaries", async (context) => {
  const root = await preparedRun();
  context.after(() => rm(root, { recursive: true, force: true }));
  const base = {
    repositoryRoot: resolve("."), runRoot: root, runId: "cross-round-stop",
    clock: () => NOW, cliInvoker: fakeCliInvoker(),
  };
  await runRound({ ...base, round: 1 });
  let attempts = 0;
  const fake = fakeCliInvoker();
  await runRound({
    ...base, round: 2,
    cliInvoker: async (args, options) => {
      if (args.includes("--version") && ++attempts === 10) {
        throw new Error("Last round-two session failed");
      }
      return fake(args, options);
    },
  });
  let thirdRoundAttempts = 0;
  const third = await runRound({
    ...base, round: 3,
    cliInvoker: async () => {
      thirdRoundAttempts += 1;
      throw new Error("First round-three session failed");
    },
  });
  assert.equal(thirdRoundAttempts, 1);
  assert.equal(third.roundExecution?.attemptedSessions, 1);
  assert.equal(third.roundExecution.remainingSessions, 9);
  assert.equal(third.roundExecution.consecutiveTechnicalFailures, 2);
  assert.equal(third.roundExecution.status, "paused-technical-failures");
  const resumed = await runRound({ ...base, round: 3, continueAfterTechnicalStop: true });
  assert.equal(resumed.roundExecution?.status, "complete");
  assert.equal(resumed.trials.length, 30);
});
