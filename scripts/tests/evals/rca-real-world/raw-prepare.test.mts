// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, readdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";
import { EVALUATION_CASE_IDS, EVALUATION_RUN_DIRECTORY, RAW_EVIDENCE_FORMAT, SKILLED_REPORT_HEADINGS, approvalPolicy, gitBlobObjectId, readJson, sha256, stableJson, writeJson } from "../../../evals/rca-real-world/contracts.mts";
import { convertRawRun, prepareRawCases, selectRawCases, verifyRawRun } from "../../../evals/rca-real-world/raw-prepare.mts";
import { createInputFingerprint, runRound } from "../../../evals/rca-real-world/runner.mts";
import { buildAdHocPrompt } from "../../../evals/rca-real-world/orchestrator.mts";
import { createRawEvidenceTools } from "../../../evals/rca-real-world/raw-evidence-tools.mts";
import { type CliInvoker } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import { RCA_SKILL_NAMES, trialDirectory } from "../../../evals/rca-real-world/conditions.mts";
import { type TrialResult } from "../../../evals/rca-real-world/scoring.mts";

const REVISION = "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e";

async function fixture() {
  const repositoryRoot = await mkdtemp(join(tmpdir(), "hve-raw-preparation-"));
  const excluded = EVALUATION_CASE_IDS.map((_, index) => `old_service_cpu_${index}`);
  const rows = [...excluded, ...EVALUATION_CASE_IDS.map((_, index) => `new_service_delay_${index}`)]
    .map((sourcePath) => ({ case: sourcePath, root_cause_service: "held-out-service", fault: "delay" }));
  const license = Buffer.from("---\nlicense: mit\n---\n");
  const indexBytes = Buffer.from("pinned-index-fixture");
  const payloads = new Map<string, Buffer>();
  const trees = new Map<string, unknown>();
  for (const { case: sourcePath } of rows) {
    const files = [["inject_time.txt", Buffer.from("1700000000")], ["metrics.parquet", Buffer.from(`PAR1-unchanged-${sourcePath}`)],
      ["logs.parquet", Buffer.from(`PAR1-logs-${sourcePath}`)], ["traces.parquet", Buffer.from(`PAR1-traces-${sourcePath}`)]] as const;
    trees.set(sourcePath, files.map(([name, bytes]) => ({
      type: "file", path: `${sourcePath}/${name}`, size: bytes.length, oid: gitBlobObjectId(bytes),
      ...(name === "metrics.parquet" ? { lfs: { oid: sha256(bytes), size: bytes.length } } : {}),
    })));
    for (const [name, bytes] of files) payloads.set(`${sourcePath}/${name}`, bytes);
  }
  await mkdir(join(repositoryRoot, "evals", "rca-real-world"), { recursive: true });
  await writeJson(join(repositoryRoot, "evals", "rca-real-world", "cases.json"), {
    schemaVersion: "1.0.0",
    source: {
      revision: REVISION, dataset: "phamquiluan/RCAEval", license: "MIT",
      licenseCard: { path: "README.md", objectId: gitBlobObjectId(license) },
      caseIndex: { path: "cases.parquet", sha256: sha256(indexBytes), size: indexBytes.length },
    },
    cases: excluded.map((sourcePath, index) => ({ neutralId: EVALUATION_CASE_IDS[index], sourcePath })),
  });
  const fetchImpl: typeof fetch = async (input) => {
    const url = new URL(String(input));
    if (url.pathname.includes(`/tree/${REVISION}/`)) {
      return Response.json(trees.get(url.pathname.split(`/tree/${REVISION}/`)[1]!));
    }
    const path = url.pathname.split(`/resolve/${REVISION}/`)[1];
    if (path === "README.md") return new Response(license);
    if (path === "cases.parquet") return new Response(indexBytes);
    const bytes = payloads.get(path ?? "");
    return bytes ? new Response(new Uint8Array(bytes)) : new Response("Not found", { status: 404 });
  };
  const telemetryRows = [
    { timestamp: 1700000000, "original|metric": 1n, date: new Date("2026-01-01Z"), bytes: new Uint8Array([0, 255]), nested: { flag: true } },
    { timestamp: 1700000001, "original|metric": 3n, date: null, bytes: null, nested: { flag: false } },
  ];
  return { repositoryRoot, excluded, rows, payloads, trees, fetchImpl, indexBytes, telemetryRows,
    parquetReader: async () => telemetryRows };
}

test("seeded raw selection is repeatable, order independent, and excludes all prepared cases", () => {
  const rows = Array.from({ length: 25 }, (_, index) => ({ case: `source_${index}` }));
  const a = selectRawCases(rows, ["source_0", "source_1"], "fixed-seed");
  assert.deepEqual(a, selectRawCases([...rows].reverse(), ["source_1", "source_0"], "fixed-seed"));
  assert.equal(a.eligibleCases, 23);
  assert.equal(new Set(a.selectedSourcePaths).size, 5);
  assert.ok(a.selectedSourcePaths.every((name) => name !== "source_0" && name !== "source_1"));
  assert.notDeepEqual(a.selectedSourcePaths, selectRawCases(rows, [], "another-seed").selectedSourcePaths);
  assert.throws(() => selectRawCases(rows, [], ""), /seed/);
  assert.throws(() => selectRawCases([...rows, rows[0]!], [], "seed"), /duplicate/);
  assert.throws(() => selectRawCases([{ case: "../escape" }], [], "seed"), /invalid/);
  assert.throws(() => selectRawCases(rows.slice(0, 4), [], "seed"), /Fewer/);
});

test("raw preparation rejects unapproved pinned metadata paths before downloading", async (context) => {
  const source = await fixture();
  context.after(() => rm(source.repositoryRoot, { recursive: true, force: true }));
  const path = join(source.repositoryRoot, "evals", "rca-real-world", "cases.json");
  const contract = JSON.parse(await readFile(path, "utf8"));
  for (const field of ["licenseCard", "caseIndex"]) {
    const changed = structuredClone(contract);
    changed.source[field].path = "../unapproved";
    await writeJson(path, changed);
    let downloads = 0;
    await assert.rejects(prepareRawCases({
      ...source, runId: "invalid-source-path", indexRows: source.rows,
      fetchImpl: async () => { downloads++; throw new Error("Unexpected download"); },
    }), /pinned MIT RCAEval source/);
    assert.equal(downloads, 0);
  }
});

test("raw preparation downloads the verified index through the shared downloader", async (context) => {
  const source = await fixture();
  context.after(() => rm(source.repositoryRoot, { recursive: true, force: true }));
  const { indexBytes, ...options } = source;
  const result = await prepareRawCases({ ...options, runId: "raw-downloaded-index", indexRows: source.rows });
  assert.deepEqual(await readFile(join(result.scorerOnlyRoot, "cases.parquet")), indexBytes);
  await verifyRawRun(result.runRoot);
});

test("raw preparation rejects incorrect LFS metadata before preserving evidence", async (context) => {
  const source = await fixture();
  context.after(() => rm(source.repositoryRoot, { recursive: true, force: true }));
  const selected = selectRawCases(source.rows, source.excluded, "seed").selectedSourcePaths[0]!;
  const bytes = source.payloads.get(`${selected}/metrics.parquet`)!;
  source.trees.set(selected, [
    { type: "file", path: `${selected}/inject_time.txt`, size: 10, oid: gitBlobObjectId(Buffer.from("1700000000")) },
    { type: "file", path: `${selected}/metrics.parquet`, size: bytes.length, oid: gitBlobObjectId(bytes),
      lfs: { oid: "0".repeat(64) } },
  ]);
  await assert.rejects(prepareRawCases({
    ...source, runId: "raw-lfs-drift", seed: "seed", indexRows: source.rows,
  }), /Downloaded content mismatch/);
  const root = join(source.repositoryRoot, ".copilot-tracking", "evaluations", EVALUATION_RUN_DIRECTORY, "raw-lfs-drift", "inputs");
  assert.equal(await readFile(join(root, "scorer-only", "downloads", "case-01", "inject_time.txt"), "utf8"), "1700000000");
  await assert.rejects(readFile(join(root, "scorer-only", "downloads", "case-01", "metrics.parquet")), /ENOENT/);
  await assert.rejects(readFile(join(root, "model-visible", "case-01", "metrics.parquet")), /ENOENT/);
});

test("raw verification rejects linked incident metadata", async (context) => {
  const source = await fixture();
  context.after(() => rm(source.repositoryRoot, { recursive: true, force: true }));
  const result = await prepareRawCases({ ...source, runId: "linked-incident", indexRows: source.rows });
  const incident = join(result.modelVisibleRoot, "case-01", "incident.json");
  const external = join(source.repositoryRoot, "external-incident.json");
  await writeFile(external, await readFile(incident));
  await rm(incident);
  try {
    await symlink(external, incident, "file");
  } catch (error) {
    if (error instanceof Error && "code" in error && ["EPERM", "EACCES", "ENOTSUP"].includes(String(error.code))) {
      context.skip("Creating symlinks is unavailable on this host");
      return;
    }
    throw error;
  }
  await assert.rejects(verifyRawRun(result.runRoot), /contained regular file|ELOOP/);
});

test("raw preparation converts rows without metric mappings and preserves originals and truth separation", async () => {
  const source = await fixture();
  try {
    const result = await prepareRawCases({ ...source, runId: "raw-fixture", indexRows: source.rows });
    const manifest = await readJson<{ evidenceTrack: string; selection: { selectedSourcePaths: string[] } }>(result.manifestPath);
    assert.equal(manifest.evidenceTrack, "raw");
    for (const [position, caseId] of EVALUATION_CASE_IDS.entries()) {
      const directory = join(result.modelVisibleRoot, caseId);
      assert.deepEqual((await readdir(directory)).sort(), ["incident.json", "logs.jsonl", "metrics.jsonl", "traces.jsonl"]);
      for (const modality of ["metrics", "logs", "traces"]) {
        assert.equal(await readFile(join(directory, `${modality}.jsonl`), "utf8"), source.telemetryRows.map((row) => JSON.stringify(JSON.parse(stableJson(row)))).join("\n") + "\n");
      }
      assert.equal(await readFile(join(directory, "metrics.jsonl"), "utf8"), source.telemetryRows.map((row) => JSON.stringify(JSON.parse(stableJson(row)))).join("\n") + "\n");
      assert.deepEqual(await readFile(join(result.scorerOnlyRoot, "downloads", caseId, "metrics.parquet")), source.payloads.get(`${manifest.selection.selectedSourcePaths[position]}/metrics.parquet`));
      const incident = await readFile(join(directory, "incident.json"), "utf8");
      for (const name of ["sourcePath", "held-out-service", ...manifest.selection.selectedSourcePaths]) assert.ok(!incident.includes(name));
      const truth = await readJson<{ rootCauseService: string }>(join(result.scorerOnlyRoot, "truth", `${caseId}.json`));
      assert.equal(truth.rootCauseService, "held-out-service");
    }
    await verifyRawRun(result.runRoot);
    const originalManifest = await readFile(result.manifestPath, "utf8");
    const changedManifest = JSON.parse(originalManifest);
    changedManifest.cases[0].files[0].rowCount++;
    await writeJson(result.manifestPath, changedManifest);
    await assert.rejects(verifyRawRun(result.runRoot), /integrity/);
    await writeFile(result.manifestPath, originalManifest);
    const incidentPath = join(result.modelVisibleRoot, "case-01", "incident.json");
    const originalIncident = await readFile(incidentPath);
    await writeJson(incidentPath, { ...JSON.parse(originalIncident.toString("utf8")), incidentOnset: "1700000001" });
    await assert.rejects(verifyRawRun(result.runRoot), /metadata integrity/);
    await writeFile(incidentPath, originalIncident);
    await assert.rejects(prepareRawCases({ ...source, runId: "raw-fixture", indexRows: source.rows }), /EEXIST/);
    await writeFile(join(result.modelVisibleRoot, "case-01", "metric-columns.json"), "{}");
    await assert.rejects(verifyRawRun(result.runRoot), /inventory/);
    await rm(join(result.modelVisibleRoot, "case-01", "metric-columns.json"));
    await writeFile(join(result.modelVisibleRoot, "case-01", "metrics.jsonl"), "changed");
    await assert.rejects(verifyRawRun(result.runRoot), /integrity/);
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("raw preparation rejects source identity mismatches rather than selecting another case", async () => {
  const source = await fixture();
  try {
    const selected = selectRawCases(source.rows, source.excluded, "seed").selectedSourcePaths[0]!;
    source.payloads.set(`${selected}/metrics.parquet`, Buffer.from("tampered-source"));
    await assert.rejects(prepareRawCases({ ...source, runId: "raw-tampered", seed: "seed", indexRows: source.rows }), /Downloaded content mismatch/);
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("raw run rejects an incorrect track before invoking a model; converted inputs need no runtime configuration", async () => {
  const source = await fixture();
  try {
    const result = await prepareRawCases({ ...source, runId: "raw-no-runtime", indexRows: source.rows });
    let invocations = 0;
    const options = {
      repositoryRoot: source.repositoryRoot, runRoot: result.runRoot, runId: "raw-no-runtime", round: 1 as const,
      cliInvoker: async () => { invocations++; throw new Error("Model must not start"); },
    };
    await assert.rejects(runRound({ ...options, evidenceTrack: "prepared" }), /does not match/);
    assert.equal(invocations, 0);
    await assert.rejects(readFile(join(result.runRoot, "run-manifest.json")), /ENOENT/);
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("both raw conditions receive the same generic unmapped JSONL interface and read-only risk", () => {
  const tools = createRawEvidenceTools({ caseRoot: ".", ledger: { consume: () => { throw new Error("Contract only"); } } }).tools;
  assert.deepEqual(tools.map((tool) => tool.name).sort(), ["list_files", "query_jsonl", "read_file"]);
  const prompt = buildAdHocPrompt("case-01", {}, tools, new Date("2026-11-05T00:00:00Z"), "raw");
  assert.match(prompt, /read-only bounded JSONL evidence/);
  assert.match(prompt, /both conditions have exactly the same host capabilities/);
  assert.doesNotMatch(prompt, /read-only bounded fixture evidence/);
  assert.ok(!prompt.includes("held-out-service"));
});

test("raw input fingerprints include every converted file, not just metadata", async () => {
  const source = await fixture();
  try {
    const result = await prepareRawCases({ ...source, runId: "raw-fingerprint", indexRows: source.rows });
    await mkdir(join(source.repositoryRoot, "scripts", "evals", "rca-real-world"), { recursive: true });
    await mkdir(join(source.repositoryRoot, ".github", "skills", "root-cause-analysis"), { recursive: true });
    await writeFile(join(source.repositoryRoot, "package-lock.json"), "{}");
    const before = await createInputFingerprint(source.repositoryRoot, result.runRoot, "raw");
    await writeFile(join(result.modelVisibleRoot, "case-01", "metrics.jsonl"), "changed row");
    assert.notEqual(await createInputFingerprint(source.repositoryRoot, result.runRoot, "raw"), before);
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

function rawCliFixture(invalidRead = false, correctRequestFormat = false): CliInvoker {
  return async (args, options) => {
    const skilled = (await readdir(options.cwd)).includes(".github");
    const inventory = args.includes("skill")
      ? JSON.stringify(skilled ? RCA_SKILL_NAMES.map((name) => ({ name, enabled: true, path: join(options.cwd, ".github", "skills", name) })) : [])
      : args.includes("plugin") ? "[]" : undefined;
    if (inventory !== undefined || args.includes("--version")) {
      return { exitCode: 0, stdout: inventory ?? "synthetic-cli", stderr: "", timedOut: false, durationMs: 1 };
    }
    const prompt = args[args.indexOf("-p") + 1]!;
    const identity = JSON.parse(/Copy these identity fields exactly: (\{[^\n]+\})\./.exec(prompt)![1]!);
    const policy = approvalPolicy("raw");
    assert.ok(!prompt.includes(approvalPolicy("prepared").expectedRisk));
    assert.ok(prompt.includes(`expectedRisk ${JSON.stringify(policy.expectedRisk)} exactly`));
    const example = [...prompt.matchAll(/```json\n([\s\S]*?)\n```/g)]
      .map((match) => JSON.parse(match[1]!))
      .find((message) => message.messageType === "evidence_request");
    assert.ok(example);
    for (const [key, value] of Object.entries(policy)) assert.equal(example.approvalRequests[0][key], value);
    const payload = prompt.startsWith("Investigate neutral incident") || prompt.startsWith("FORMAT CORRECTION") ? {
      messageType: "evidence_request",
      approvalRequests: (invalidRead
        ? [{ tool: "read_file", operation: "read", parameters: { path: "metrics.jsonl", offset: -1 } }]
        : [
          { tool: "list_files", operation: "list", parameters: {} },
          { tool: "query_jsonl", operation: "query", parameters: { path: "metrics.jsonl", mode: "summary", columns: '["original|metric"]' } },
        ]).map((request) => ({
          ...request, ...policy, target: identity.caseId, evidenceSought: "Inspect original JSONL fields",
          expiresAt: "2026-11-05T00:15:00.000Z",
        })),
    } : {
      messageType: invalidRead ? "blocked" : "final",
      ...(invalidRead ? { reason: "Raw evidence was not decoded after the invalid bounded read." } : {}),
      report: {
        candidate: { target: invalidRead ? null : "held-out-service", mechanism: invalidRead ? null : "delay", confidence: "Synthetic evidence only" },
        ...(skilled ? { finding: { status: "not-established", target: null, mechanism: null } } : {}),
        authority: { simulated: true, productionAuthorization: false },
        limitations: ["Synthetic deterministic harness test; human review pending."],
        narrative: [
          ...(skilled ? SKILLED_REPORT_HEADINGS : []),
          "Evidence-informed working hypothesis, not a verified root cause.",
          "Do not use it by itself for incident closure. Simulated fixture approval, not production authorization.",
          ...(invalidRead ? ["Blocked: raw evidence was not decoded."] : ["Candidate: held-out-service, delay; synthetic analysis output."]),
        ].join("\n\n"),
      },
    };
    const content = JSON.stringify({ ...identity, ...payload });
    return {
      exitCode: 0, stderr: "", timedOut: false, durationMs: 1,
      stdout: `${JSON.stringify({ type: "assistant.message", data: { phase: "final_answer",
        content: correctRequestFormat && prompt.startsWith("Investigate neutral incident") ? `${content}]}` : content } })}\n`,
    };
  };
}

test("paired raw sessions replay exact approvals without Docker and lock track and format identities", async () => {
  const source = await fixture();
  try {
    const prepared = await prepareRawCases({ ...source, runId: "raw-paired", indexRows: source.rows });
    const options = {
      repositoryRoot: resolve(import.meta.dirname, "..", "..", "..", ".."),
      runRoot: prepared.runRoot, runId: "raw-paired", cliInvoker: rawCliFixture(),
      clock: () => new Date("2026-11-05T00:00:00Z"),
    };
    const summary = await runRound({ ...options, round: 1 });
    assert.equal(summary.evidenceTrack, "raw");
    assert.equal(summary.trials.length, 10, JSON.stringify(summary.trials.map((trial) => ({ outcome: trial.outcome, reason: trial.reason }))));
    for (const result of summary.trials) {
      assert.equal(result.integrity, "pass", JSON.stringify(result.integrityFailures));
      assert.equal(result.strictGates.approvalContract, true);
      assert.equal(result.evidenceTrack, "raw");
      assert.equal(result.evidenceAccess?.jsonlQueries, 1);
      assert.equal(result.rawEvidenceFormat, RAW_EVIDENCE_FORMAT);
      assert.equal(result.evidenceAccess?.evidenceCoverageReview, "pending-human-review");
      assert.equal(result.leadingHypothesis.rootCauseService, "match");
    }
    const contracts = await Promise.all(["with-skill", "without-skill"].map(async (condition) => {
      const artifact = await readJson<{ hashes: { toolContractSha256: string } }>(
        join(prepared.runRoot, "sessions", condition, "case-01", "trial-1", "session-artifact.json"));
      return artifact.hashes.toolContractSha256;
    }));
    assert.equal(contracts[0], contracts[1]);
    await assert.rejects(convertRawRun(prepared.runRoot, source.parquetReader), /already started/);
    const manifestPath = join(prepared.runRoot, "run-manifest.json");
    const manifest = await readJson<Record<string, unknown>>(manifestPath);
    await writeJson(manifestPath, { ...manifest, rawEvidenceFormat: "different-format" });
    await assert.rejects(runRound({ ...options, round: 2 }), /cannot change/);
    await writeJson(manifestPath, manifest);
    const path = join(trialDirectory(prepared.runRoot, "case-01", 1, "with-skill"), "trial-result.json");
    const result = await readJson<TrialResult>(path);
    await writeJson(path, { ...result, evidenceTrack: "prepared" });
    await assert.rejects(runRound({ ...options, round: 2 }), /Invalid evaluation result identity/);
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("raw initial, format-correction and subsequent invocation prompts agree with strict approvals in both conditions", async () => {
  const source = await fixture();
  try {
    const prepared = await prepareRawCases({ ...source, runId: "raw-policy-correction", indexRows: source.rows });
    const summary = await runRound({
      repositoryRoot: resolve(import.meta.dirname, "..", "..", "..", ".."),
      runRoot: prepared.runRoot, runId: "raw-policy-correction", round: 1,
      cliInvoker: rawCliFixture(false, true), clock: () => new Date("2026-11-05T00:00:00Z"),
    });
    assert.equal(summary.trials.length, 10);
    for (const result of summary.trials) {
      assert.equal(result.integrity, "pass", JSON.stringify(result.integrityFailures));
      assert.equal(result.strictGates.approvalContract, true);
      assert.deepEqual(result.recovery, { formatErrors: 1, queryErrors: 0 });
      assert.equal(result.evidenceAccess?.jsonlQueries, 1);
    }
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("raw parameter errors consume exact approvals but a reported access blocker is not a technical failure", async () => {
  const source = await fixture();
  try {
    const prepared = await prepareRawCases({ ...source, runId: "raw-blocked", indexRows: source.rows });
    const summary = await runRound({
      repositoryRoot: resolve(import.meta.dirname, "..", "..", "..", ".."),
      runRoot: prepared.runRoot, runId: "raw-blocked", round: 1, mode: "without-skill",
      cliInvoker: rawCliFixture(true), clock: () => new Date("2026-11-05T00:00:00Z"),
    });
    assert.equal(summary.trials.length, 5);
    for (const result of summary.trials) {
      assert.equal(result.integrity, "pass", JSON.stringify(result.integrityFailures));
      assert.equal(result.outcome, "blocked");
      assert.equal(result.recovery?.queryErrors, 1);
      assert.equal(result.evidenceAccess?.reportedBlocked, true);
      assert.match(result.evidenceAccess?.blocker ?? "", /not decoded/);
      assert.equal(result.evidenceAccess?.jsonlQueries, 0);
    }
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});

test("two consecutive raw technical failures persist and pause without spending model credits", async () => {
  const source = await fixture();
  try {
    const prepared = await prepareRawCases({ ...source, runId: "raw-runtime-lost", indexRows: source.rows });
    let modelInvocations = 0;
    const summary = await runRound({
      repositoryRoot: resolve(import.meta.dirname, "..", "..", "..", ".."),
      runRoot: prepared.runRoot, runId: "raw-runtime-lost", round: 1, profile: "production",
      cliInvoker: async () => { modelInvocations++; throw new Error("Model must not start"); },
      clock: () => new Date("2026-11-05T00:00:00Z"),
    });
    assert.equal(modelInvocations, 2);
    assert.equal(summary.roundExecution?.status, "paused-technical-failures");
    assert.equal(summary.trials.length, 2);
    assert.equal(summary.aiCreditsUsed, 0);
    for (const result of summary.trials) {
      assert.equal(result.outcome, "execution-error");
      assert.equal(result.evidenceAccess?.reportedBlocked, false);
      assert.equal(result.leadingHypothesis.status, "unusable");
    }
  } finally { await rm(source.repositoryRoot, { recursive: true, force: true }); }
});
