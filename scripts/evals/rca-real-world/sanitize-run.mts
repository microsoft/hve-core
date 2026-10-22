// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { createSchedule, readJson, sha256, stableJson, writeJson } from "./contracts.mts";
import { redactArtifact, type TrialArtifact } from "./orchestrator.mts";
import { scorePersistedTrial, type TrialResult } from "./scoring.mts";

/** Redacts persisted session artifacts and recomputes every dependent hash and score. */
export async function sanitizeRun(repositoryRoot: string, runId: string): Promise<{
  readonly sessions: number;
  readonly replacements: number;
}> {
  const runRoot = join(
    repositoryRoot,
    ".copilot-tracking",
    "evaluations",
    "rcaeval-three-case",
    runId,
  );
  const scorerPath = join(import.meta.dirname, "scoring.mts");
  const results: TrialResult[] = [];
  let sessions = 0;
  let replacements = 0;

  for (const item of createSchedule(3)) {
    const sessionRoot = join(runRoot, "sessions", item.caseId, `trial-${item.trial}`);
    let artifact: TrialArtifact;
    try {
      artifact = await readJson<TrialArtifact>(join(sessionRoot, "session-artifact.json"));
    } catch (error) {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") {
        continue;
      }
      throw error;
    }
    const redacted = redactArtifact(artifact, [
      repositoryRoot,
      process.env.USERPROFILE ?? "",
    ]);
    const sanitized: TrialArtifact = {
      ...redacted.value,
      redactionManifest: {
        applied: ["repository-root", "user-home", "credential-patterns"],
        replacements: artifact.redactionManifest.replacements + redacted.replacements,
      },
    };
    await writeJson(join(sessionRoot, "session-artifact.json"), sanitized);
    const approvalLedger = await readOptional(join(sessionRoot, "fixture-approval-ledger.json"));
    const traces = await readOptional(join(sessionRoot, "mcp-tool-traces.json"));
    await writeJson(join(sessionRoot, "artifact-hashes.json"), {
      sessionArtifactSha256: sha256(stableJson(sanitized)),
      approvalLedgerSha256: approvalLedger
        ? sha256(stableJson(approvalLedger))
        : "Unavailable",
      mcpTraceSha256: traces ? sha256(stableJson(traces)) : "Unavailable",
    });
    results.push(
      await scorePersistedTrial({
        runRoot,
        caseId: item.caseId,
        trial: item.trial,
        scorerPath,
      }),
    );
    sessions += 1;
    replacements += redacted.replacements;
  }

  const summaryPath = join(runRoot, "evaluation-summary.json");
  const summary = await readJson<Record<string, unknown>>(summaryPath);
  await writeJson(summaryPath, { ...summary, trials: results });

  const checkpointPath = join(runRoot, "round-one-checkpoint.json");
  const checkpoint = await readJson<Record<string, unknown>>(checkpointPath);
  await writeJson(checkpointPath, {
    ...checkpoint,
    trialResultHashes: Object.fromEntries(
      results
        .filter((result) => result.trial === 1)
        .map((result) => [result.caseId, result.hashes.resultSha256]),
    ),
  });
  return { sessions, replacements };
}

async function readOptional(path: string): Promise<unknown | undefined> {
  try {
    return JSON.parse(await readFile(path, "utf8")) as unknown;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return undefined;
    }
    throw error;
  }
}

if (import.meta.main) {
  const { values } = parseArgs({
    options: {
      "run-id": { type: "string" },
    },
  });
  if (!values["run-id"]) {
    throw new Error("Usage: node sanitize-run.mts --run-id <run-id>");
  }
  const result = await sanitizeRun(resolve(import.meta.dirname, "..", "..", ".."), values["run-id"]);
  process.stdout.write(`${JSON.stringify(result)}\n`);
}
