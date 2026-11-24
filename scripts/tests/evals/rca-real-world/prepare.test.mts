// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import {
  gitBlobObjectId,
  sha256,
  type PreparedCaseManifest,
  type EvaluationContract,
} from "../../../evals/rca-real-world/contracts.mts";
import {
  assertBlindness,
  downloadAndVerify,
  prepareCases,
  verifyPreparedRun,
  type PreparationOptions,
} from "../../../evals/rca-real-world/prepare.mts";

interface Fixture {
  readonly repositoryRoot: string;
  readonly options: Omit<PreparationOptions, "runId">;
  readonly contract: EvaluationContract;
  readonly content: Map<string, Uint8Array>;
}

async function createFixture(): Promise<Fixture> {
  const repositoryRoot = await mkdtemp(join(tmpdir(), "rca-eval-"));
  const contractRoot = join(repositoryRoot, "evals", "rca-real-world");
  await mkdir(contractRoot, { recursive: true });

  const encoder = new TextEncoder();
  const license = encoder.encode("---\nlicense: mit\n---\n");
  const index = encoder.encode("index");
  const content = new Map<string, Uint8Array>();
  const makeFile = (casePath: string, name: string, value: string) => {
    const bytes = encoder.encode(value);
    content.set(`${casePath}/${name}`, bytes);
    return {
      name,
      objectId: sha256(`oid:${casePath}/${name}`).slice(0, 40),
      sha256: sha256(bytes),
      size: bytes.byteLength,
    };
  };
  const cases = [
    {
      neutralId: "case-01",
      sourcePath: "source-case-one",
      trialOrder: 1,
      modalities: ["metrics"] as const,
    },
    {
      neutralId: "case-02",
      sourcePath: "source-case-two",
      trialOrder: 2,
      modalities: ["metrics", "logs", "traces"] as const,
    },
    {
      neutralId: "case-03",
      sourcePath: "source-case-three",
      trialOrder: 3,
      modalities: ["metrics", "logs", "traces"] as const,
    },
    {
      neutralId: "case-04",
      sourcePath: "source-case-four",
      trialOrder: 4,
      modalities: ["metrics", "logs"] as const,
    },
    {
      neutralId: "case-05",
      sourcePath: "source-case-five",
      trialOrder: 5,
      modalities: ["metrics", "logs", "traces"] as const,
    },
  ].map((item) => ({
    ...item,
    files: [
      makeFile(item.sourcePath, "inject_time.txt", "1700000000"),
      ...item.modalities.map((modality) =>
        makeFile(item.sourcePath, `${modality}.parquet`, `${item.neutralId}-${modality}`),
      ),
    ],
  }));

  const contract: EvaluationContract = {
    schemaVersion: "1.0.0",
    source: {
      dataset: "phamquiluan/RCAEval",
      revision: "a".repeat(40),
      license: "MIT",
      sourceUrl: "https://example.invalid",
      licenseCard: { path: "README.md", objectId: gitBlobObjectId(license) },
      caseIndex: { path: "cases.parquet", sha256: sha256(index), size: index.byteLength },
    },
    cases,
  };
  await writeFile(join(contractRoot, "cases.json"), JSON.stringify(contract), "utf8");
  content.set("README.md", license);
  content.set("cases.parquet", index);

  const fetchImpl = async (input: string | URL | Request): Promise<Response> => {
    const url = String(input);
    const treeMatch = /\/tree\/[0-9a-f]{40}\/([^?]+)/.exec(url);
    if (treeMatch) {
      const casePath = decodeURIComponent(treeMatch[1]!);
      const selected = contract.cases.find((item) => item.sourcePath === casePath);
      if (!selected) {
        return new Response("missing", { status: 404 });
      }
      return Response.json(
        selected.files.map((file) => ({
          type: "file",
          oid: file.objectId,
          size: file.size,
          path: `${selected.sourcePath}/${file.name}`,
          ...(file.name.endsWith(".parquet")
            ? { lfs: { oid: file.sha256, size: file.size } }
            : {}),
        })),
      );
    }
    const remotePath = /\/resolve\/[0-9a-f]{40}\/([^?]+)/.exec(url)?.[1];
    const bytes = remotePath ? content.get(decodeURIComponent(remotePath)) : undefined;
    return bytes
      ? new Response(new Uint8Array(bytes).buffer)
      : new Response("missing", { status: 404 });
  };

  const parquetReader = async (path: string): Promise<readonly Record<string, unknown>[]> => {
    if (path.endsWith("cases.parquet")) {
      return contract.cases.map((item) => ({
        case_id: item.sourcePath,
        root_cause_service: `${item.neutralId}-service`,
        fault: item.neutralId === "case-01" ? "cpu" : "delay",
      }));
    }
    return [
      {
        timestamp: 1700000000,
        service: "checkoutservice",
        message: "genuine telemetry service identifier",
      },
    ];
  };

  return {
    repositoryRoot,
    contract,
    content,
    options: {
      repositoryRoot,
      retrievedAt: "2026-10-19T00:00:00.000Z",
      fetchImpl: fetchImpl as typeof fetch,
      parquetReader,
    },
  };
}

test("shared downloader preserves bytes with SHA-256 and Git blob verification", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "rca-download-"));
  context.after(() => rm(root, { recursive: true, force: true }));
  const bytes = new TextEncoder().encode("unchanged-source-bytes");
  const revision = "a".repeat(40);
  const requests: string[] = [];
  const fetchImpl: typeof fetch = async (input) => {
    requests.push(String(input));
    return new Response(bytes);
  };
  const shaIdentity = { name: "metrics.parquet", size: bytes.length, sha256: sha256(bytes) };
  assert.deepEqual(await downloadAndVerify(fetchImpl, revision, "source-case", shaIdentity, root), bytes);
  assert.deepEqual(await readFile(join(root, shaIdentity.name)), Buffer.from(bytes));
  const blobIdentity = { name: "inject_time.txt", size: bytes.length, objectId: gitBlobObjectId(bytes) };
  assert.deepEqual(await downloadAndVerify(fetchImpl, revision, "source-case", blobIdentity, root), bytes);
  assert.deepEqual(await readFile(join(root, blobIdentity.name)), Buffer.from(bytes));
  const licenseIdentity = { name: "README.md", objectId: gitBlobObjectId(bytes) };
  assert.deepEqual(await downloadAndVerify(fetchImpl, revision, "", licenseIdentity, undefined, false), bytes);
  await assert.rejects(readFile(join(root, licenseIdentity.name)), /ENOENT/);
  assert.equal(requests.length, 3);
  assert.ok(requests.every((url) => url.startsWith(`https://huggingface.co/datasets/phamquiluan/RCAEval/resolve/${revision}/`)));
});

test("shared downloader rejects hash and size drift before writing", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "rca-download-drift-"));
  context.after(() => rm(root, { recursive: true, force: true }));
  const bytes = new TextEncoder().encode("source-bytes");
  const fetchImpl: typeof fetch = async () => new Response(bytes);
  for (const identity of [
    { sha256: "0".repeat(64), size: bytes.length },
    { objectId: "0".repeat(40), size: bytes.length },
    { sha256: sha256(bytes), size: bytes.length + 1 },
    { objectId: gitBlobObjectId(bytes), size: bytes.length + 1 },
  ]) {
    await assert.rejects(downloadAndVerify(fetchImpl, "a".repeat(40), "source-case", {
      name: "metrics.parquet", ...identity,
    }, root), /Downloaded content mismatch/);
    await assert.rejects(readFile(join(root, "metrics.parquet")), /ENOENT/);
  }
});

test("shared downloader rejects invalid paths, revisions and identities before fetching", async () => {
  let requests = 0;
  const fetchImpl: typeof fetch = async () => {
    requests++;
    throw new Error("Unexpected download");
  };
  for (const [revision, sourcePath, name] of [
    ["a".repeat(40), "../escape", "metrics.parquet"],
    ["a".repeat(40), "source-case", "script.mjs"],
    ["main", "source-case", "metrics.parquet"],
  ]) {
    await assert.rejects(downloadAndVerify(fetchImpl, revision!, sourcePath!, {
      name: name!, sha256: "a".repeat(64),
    }), /Invalid RCAEval source download/);
  }
  for (const identity of [
    { sha256: "invalid" }, { objectId: "invalid" }, { sha256: "a".repeat(64), size: -1 },
  ]) {
    await assert.rejects(downloadAndVerify(fetchImpl, "a".repeat(40), "source-case", {
      name: "metrics.parquet", ...identity,
    }), /Invalid expected source identity/);
  }
  assert.equal(requests, 0);
});

test("shared downloader surfaces HTTP failures without writing", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "rca-download-http-"));
  context.after(() => rm(root, { recursive: true, force: true }));
  const fetchImpl: typeof fetch = async () => new Response("missing", { status: 404 });
  await assert.rejects(downloadAndVerify(fetchImpl, "a".repeat(40), "source-case", {
    name: "metrics.parquet", sha256: "a".repeat(64),
  }, root), /Unable to download source-case\/metrics.parquet: HTTP 404/);
  await assert.rejects(readFile(join(root, "metrics.parquet")), /ENOENT/);
});

test("prepares deterministic separated workspaces while preserving telemetry services", async () => {
  const fixture = await createFixture();
  const first = await prepareCases({ ...fixture.options, runId: "fixture-run-one" });
  const second = await prepareCases({ ...fixture.options, runId: "fixture-run-two" });

  const firstMetric = await readFile(
    join(first.modelVisibleRoot, "case-01", "metrics.jsonl"),
    "utf8",
  );
  const secondMetric = await readFile(
    join(second.modelVisibleRoot, "case-01", "metrics.jsonl"),
    "utf8",
  );
  assert.equal(firstMetric, secondMetric);
  assert.match(firstMetric, /checkoutservice/);
  assert.doesNotMatch(
    await readFile(join(first.modelVisibleRoot, "case-01", "incident.json"), "utf8"),
    /source-case-one|root_cause/i,
  );
  assert.match(
    await readFile(join(first.scorerOnlyRoot, "truth", "case-01.json"), "utf8"),
    /source-case-one|case-01-service/,
  );
});

test("persists and verifies deterministic metric identities without renaming telemetry columns", async (context) => {
  const fixture = await createFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const originalReader = fixture.options.parquetReader;
  assert.ok(originalReader);
  const options = {
    ...fixture.options,
    parquetReader: async (path: string) => path.endsWith("metrics.parquet")
      ? [{ time: 1, user_db_cpu: 10, "user_latency-90": 0.2 }]
      : originalReader(path),
  };
  const first = await prepareCases({ ...options, runId: "mapping-one" });
  const second = await prepareCases({ ...options, runId: "mapping-two" });
  const mapPath = join(first.modelVisibleRoot, "case-01", "metric-columns.json");
  const mapping = await readFile(mapPath, "utf8");
  assert.deepEqual(JSON.parse(mapping), {
    user_db_cpu: { service: "user_db", metric: "cpu" },
    "user_latency-90": { service: "user", metric: "latency-90" },
  });
  assert.equal(mapping, await readFile(
    join(second.modelVisibleRoot, "case-01", "metric-columns.json"), "utf8",
  ));
  assert.deepEqual(JSON.parse((await readFile(
    join(first.modelVisibleRoot, "case-01", "metrics.jsonl"), "utf8",
  )).trim()), { time: 1, user_db_cpu: 10, "user_latency-90": 0.2 });
  const manifest: {
    sourceRevision: string;
    transformationVersion: string;
    cases: readonly PreparedCaseManifest[];
  } = JSON.parse(await readFile(first.manifestPath, "utf8"));
  assert.equal(manifest.transformationVersion, "2.0.0");
  assert.equal(manifest.cases[0]?.metricColumnsSha256, sha256(mapping));
  await writeFile(first.manifestPath, JSON.stringify({
    ...manifest, sourceRevision: "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e",
  }), "utf8");
  await verifyPreparedRun(fixture.repositoryRoot, "mapping-one");
  await writeFile(mapPath, mapping.replace('"user_db"', '"other"'), "utf8");
  await assert.rejects(
    verifyPreparedRun(fixture.repositoryRoot, "mapping-one"),
    /Metric column mapping integrity mismatch/,
  );
});

test("rejects unsupported wide metric schemas during preparation", async (context) => {
  const fixture = await createFixture();
  context.after(() => rm(fixture.repositoryRoot, { recursive: true, force: true }));
  const originalReader = fixture.options.parquetReader;
  assert.ok(originalReader);
  await assert.rejects(prepareCases({
    ...fixture.options,
    runId: "unknown-metric",
    parquetReader: async (path) => path.endsWith("metrics.parquet")
      ? [{ time: 1, user_cpu_percent: 10 }]
      : originalReader(path),
  }), /Unsupported RCAEval metric column/);
});

test("fails closed on source hash drift and removes partial output", async () => {
  const fixture = await createFixture();
  fixture.content.set("source-case-one/metrics.parquet", new TextEncoder().encode("changed"));
  await assert.rejects(
    prepareCases({ ...fixture.options, runId: "hash-drift-run" }),
    /Downloaded content mismatch/,
  );
});

test("fails closed on missing modalities and path traversal", async () => {
  const fixture = await createFixture();
  fixture.content.delete("source-case-two/logs.parquet");
  await assert.rejects(
    prepareCases({ ...fixture.options, runId: "missing-file-run" }),
    /Unable to download/,
  );
  await assert.rejects(
    prepareCases({ ...fixture.options, runId: "../escape" }),
    /runId must be/,
  );
});

test("detects answer-bearing metadata but permits telemetry content", async () => {
  const fixture = await createFixture();
  const result = await prepareCases({ ...fixture.options, runId: "leakage-scan-run" });
  await writeFile(
    join(result.modelVisibleRoot, "case-01", "incident.json"),
    '{"root_cause_service":"answer"}',
    "utf8",
  );
  await assert.rejects(
    assertBlindness(result.modelVisibleRoot, fixture.contract.cases),
    /Ground-truth leakage/,
  );
});
