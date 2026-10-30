// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import {
  EVALUATION_PROTOCOL, EVALUATION_RUN_DIRECTORY, readJson, sha256, stableJson, writeJson,
} from "./contracts.mts";
import type { TrialArtifact } from "./orchestrator.mts";
import { redactArtifact } from "./redaction.mts";
import { scorePersistedTrial, type TrialResult } from "./scoring.mts";
import { createConditionSchedule, parseEvaluationMode, trialDirectory } from "./conditions.mts";
import { rebindRedactedCommunication } from "./cli-orchestrator.mts";

/** Redacts persisted session artifacts and recomputes every dependent hash and score. */
export async function sanitizeRun(repositoryRoot: string, runId: string): Promise<{
  readonly sessions: number;
  readonly replacements: number;
}> {
  const runRoot = join(
    repositoryRoot,
    ".copilot-tracking",
    "evaluations",
    EVALUATION_RUN_DIRECTORY,
    runId,
  );
  const scorerPath = join(import.meta.dirname, "scoring.mts");
  const results: TrialResult[] = [];
  let sessions = 0;
  let replacements = 0;
  const summaryPath = join(runRoot, "evaluation-summary.json");
  const summary = await readJson<Record<string, unknown>>(summaryPath);
  if (summary.protocol !== EVALUATION_PROTOCOL) {
    throw new Error("Historical evaluation artifacts are immutable; start a new evaluation run instead of sanitizing in place");
  }
  if (typeof summary.mode !== "string") {
    throw new Error("Sanitization requires a condition-aware evaluation summary");
  }
  const mode = parseEvaluationMode(summary.mode);
  const pending: {
    sessionRoot: string; artifact: TrialArtifact;
    item: ReturnType<typeof createConditionSchedule>[number];
  }[] = [];
  for (const item of createConditionSchedule(3, mode)) {
    const sessionRoot = trialDirectory(runRoot, item.caseId, item.trial, item.condition);
    let artifact: TrialArtifact;
    try {
      artifact = await readJson<TrialArtifact>(join(sessionRoot, "session-artifact.json"));
    } catch (error) {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") {
        continue;
      }
      throw error;
    }
    if (artifact.protocol !== EVALUATION_PROTOCOL) {
      throw new Error("Historical evaluation artifacts are immutable; no sessions were changed");
    }
    pending.push({ sessionRoot, artifact, item });
  }
  for (const { sessionRoot, artifact, item } of pending) {
    const redacted = redactArtifact(artifact, [repositoryRoot]);
    const sanitized: TrialArtifact = rebindRedactedCommunication({
      ...redacted.value,
      redactionManifest: {
        applied: [...new Set([
          ...artifact.redactionManifest.applied,
          "repository-root", "user-home", "credential-patterns",
        ])],
        replacements: artifact.redactionManifest.replacements + redacted.replacements,
      },
    });
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
        condition: item.condition,
        scorerPath,
      }),
    );
    sessions += 1;
    replacements += redacted.replacements;
  }

  await writeJson(summaryPath, { ...summary, trials: results });

  const checkpointPath = join(runRoot, "round-one-checkpoint.json");
  const checkpoint = await readJson<Record<string, unknown>>(checkpointPath);
  await writeJson(checkpointPath, {
    ...checkpoint,
    trialResultHashes: Object.fromEntries(
      results
        .filter((result) => result.trial === 1)
        .map((result) => [`${result.condition}/${result.caseId}`, result.hashes.resultSha256]),
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
