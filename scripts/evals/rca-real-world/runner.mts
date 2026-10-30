// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { execFile } from "node:child_process";
import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join, relative } from "node:path";
import { promisify } from "node:util";

import {
  EXPECTED_CONTEXT_TIER,
  EVALUATION_CASE_IDS,
  EVALUATION_RUN_DIRECTORY,
  EVALUATION_PROTOCOL,
  evaluationModel,
  parseEvaluationProfile,
  type EvaluationProfile,
  EXPECTED_REASONING_EFFORT,
  TRANSFORMATION_VERSION,
  type PreparedCaseManifest,
  compareStrings,
  readJson,
  sha256,
  stableJson,
  writeJson,
} from "./contracts.mts";
import { runCliTrial, type CliInvoker } from "./cli-orchestrator.mts";
import {
  evaluateRoundOne,
  scorePersistedTrial,
  type TrialResult,
} from "./scoring.mts";
import {
  createConditionSchedule,
  parseEvaluationMode,
  selectedConditions,
  trialDirectory,
  type EvaluationMode,
} from "./conditions.mts";

const execFileAsync = promisify(execFile);
const SOURCE_REVISION = "afeacb11bcc94dadfd1c8f483ee4377b2b8b614e";

export interface RunRoundOptions {
  readonly repositoryRoot: string;
  readonly runRoot?: string;
  readonly runId: string;
  readonly round: 1 | 2 | 3;
  /** Defaults to both on a new run; continuation reuses the immutable manifest selection. */
  readonly mode?: EvaluationMode;
  /** Defaults to debug for a new run; continuation inherits the immutable manifest profile. */
  readonly profile?: EvaluationProfile;
  /** Requires an explicit coordinator-approved continuation of a technical-failure stop. */
  readonly continueAfterTechnicalStop?: boolean;
  readonly cliInvoker?: CliInvoker;
  readonly clock?: () => Date;
}

/** Persists partial-round progress without granting authority to retry failed sessions. */
export interface RoundExecutionCheckpoint {
  readonly round: number;
  readonly status: "complete" | "paused-technical-failures";
  readonly attemptedSessions: number;
  readonly remainingSessions: number;
  readonly consecutiveTechnicalFailures: number;
  readonly artifactHashes: Readonly<Record<string, { readonly session: string; readonly result: string }>>;
  readonly pauses: readonly { readonly at: string; readonly afterSession: number }[];
  readonly continuations: readonly { readonly at: string; readonly afterSession: number }[];
}

export interface EvaluationSummary {
  readonly schemaVersion: "2.0.0";
  readonly protocol: typeof EVALUATION_PROTOCOL;
  readonly profile: EvaluationProfile;
  readonly mode: EvaluationMode;
  readonly runId: string;
  readonly sourceRevision: string;
  readonly model: string;
  readonly reasoningEffort: string;
  readonly contextTier: string;
  readonly trialOrder: ReturnType<typeof createConditionSchedule>;
  readonly trials: readonly TrialResult[];
  readonly roundExecution?: RoundExecutionCheckpoint;
  readonly roundOneCheckpoint?: {
    readonly decision: "continue" | "pause";
    readonly reasons: readonly string[];
  };
  readonly limitations: readonly string[];
}

/**
 * Executes one approved trial round and updates aggregate machine-readable evidence.
 *
 * Round two requires a continuing round-one checkpoint. Round three additionally requires all
 * round-two results. Two consecutive aborted sessions pause execution. Explicit continuation
 * resumes only unattempted sessions with unchanged inputs; existing sessions are never retried.
 */
export async function runRound(options: RunRoundOptions): Promise<EvaluationSummary> {
  const runRoot =
    options.runRoot ??
    join(
      options.repositoryRoot,
      ".copilot-tracking",
      "evaluations",
      EVALUATION_RUN_DIRECTORY,
      options.runId,
    );
  const prepared = await assertPrepared(runRoot);
  const currentFingerprint = await createInputFingerprint(options.repositoryRoot, runRoot);
  const manifestPath = join(runRoot, "run-manifest.json");
  const resuming = options.continueAfterTechnicalStop === true;
  const priorManifest = options.round === 1 && !resuming ? undefined : await readJson<{
    schemaVersion: string;
    mode: string;
    runId: string;
    inputFingerprint: string;
    protocol?: string;
    profile?: string;
    model?: string;
    reasoningEffort?: string;
    contextTier?: string;
  }>(manifestPath);
  if (priorManifest && (priorManifest.schemaVersion !== "2.0.0" || priorManifest.runId !== options.runId)) {
    throw new Error("A new paired-evaluation run is required for this manifest");
  }
  if (priorManifest && priorManifest.protocol !== EVALUATION_PROTOCOL) {
    throw new Error(`Cannot continue a historical protocol; start a new ${EVALUATION_PROTOCOL} run`);
  }
  if (priorManifest && priorManifest.profile === undefined) {
    throw new Error("Cannot continue a run without an immutable evaluation profile");
  }
  const profile = parseEvaluationProfile(options.profile ?? priorManifest?.profile ?? "debug");
  const model = evaluationModel(profile);
  if (priorManifest && (
    priorManifest.profile !== profile || priorManifest.model !== model ||
    priorManifest.reasoningEffort !== EXPECTED_REASONING_EFFORT ||
    priorManifest.contextTier !== EXPECTED_CONTEXT_TIER
  )) {
    throw new Error("Evaluation profile and model cannot change after round one");
  }
  const mode = parseEvaluationMode(options.mode ?? priorManifest?.mode ?? "both");
  if (priorManifest && priorManifest.mode !== mode) {
    throw new Error("Evaluation conditions cannot change after round one");
  }
  const expectedResultIdentity = { runId: options.runId, profile, model };
  const existingResults = await readAllResults(runRoot, mode, expectedResultIdentity);
  if (options.round === 1 && !resuming) {
    try {
      await stat(manifestPath);
      throw new Error(`Run manifest already exists for ${options.runId}; retries are not allowed`);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
    await writeJson(manifestPath, {
      schemaVersion: "2.0.0",
      protocol: EVALUATION_PROTOCOL,
      profile,
      mode,
      runId: options.runId,
      sourceRevision: SOURCE_REVISION,
      model,
      reasoningEffort: EXPECTED_REASONING_EFFORT,
      contextTier: EXPECTED_CONTEXT_TIER,
      inputFingerprint: currentFingerprint,
      repositoryCommit: await gitCommit(options.repositoryRoot),
      nodeVersion: process.version,
      readerBundleIdentity: prepared.parquetReader ?? "Unavailable",
      packageLockSha256: sha256(await readFile(join(options.repositoryRoot, "package-lock.json"))),
      startedAt: (options.clock ?? (() => new Date()))().toISOString(),
      retries: "none",
    });
  } else {
    if (priorManifest?.inputFingerprint !== currentFingerprint) {
      throw new Error("Evaluation inputs changed after round one");
    }
    if (options.round > 1) {
      const checkpoint = await readJson<{ decision: string }>(
        join(runRoot, "round-one-checkpoint.json"),
      );
      if (checkpoint.decision !== "continue") {
        throw new Error("Round-one checkpoint does not authorize continuation");
      }
      await requireResults(runRoot, options.round - 1, mode);
    }
  }

  const scorerPath = join(import.meta.dirname, "scoring.mts");
  const roundItems = createConditionSchedule(options.round, mode).filter((item) => item.trial === options.round);
  const checkpointPath = join(runRoot, `round-${options.round}-execution.json`);
  const previous = resuming ? await readJson<RoundExecutionCheckpoint>(checkpointPath) : undefined;
  let attemptedSessions = previous?.attemptedSessions ?? 0;
  if (previous) {
    if (
      previous.round !== options.round || previous.status !== "paused-technical-failures" ||
      !Number.isSafeInteger(attemptedSessions) || attemptedSessions < 1 ||
      attemptedSessions > roundItems.length
    ) {
      throw new Error("No remaining sessions in an eligible technical-failure checkpoint");
    }
    for (const item of roundItems.slice(0, attemptedSessions)) {
      const key = `${item.condition}/${item.caseId}`;
      const directory = trialDirectory(runRoot, item.caseId, item.trial, item.condition);
      const expected = previous.artifactHashes[key];
      if (
        !expected ||
        sha256(await readFile(join(directory, "session-artifact.json"))) !== expected.session ||
        sha256(await readFile(join(directory, "trial-result.json"))) !== expected.result
      ) {
        throw new Error(`Attempted session artifacts changed before continuation: ${key}`);
      }
    }
  }
  const now = () => (options.clock ?? (() => new Date()))().toISOString();
  const pauses = [...(previous?.pauses ?? [])];
  const continuations = [
    ...(previous?.continuations ?? []),
    ...(resuming ? [{ at: now(), afterSession: attemptedSessions }] : []),
  ];
  const priorRound = options.round > 1 && !resuming
    ? await readJson<RoundExecutionCheckpoint>(join(runRoot, `round-${options.round - 1}-execution.json`))
    : undefined;
  if (priorRound?.status === "paused-technical-failures") {
    throw new Error("The previous round has an unresolved technical-failure stop");
  }
  let consecutiveTechnicalFailures = priorRound?.consecutiveTechnicalFailures ?? 0;
  let status: RoundExecutionCheckpoint["status"] = "complete";
  for (const item of roundItems.slice(attemptedSessions)) {
    const sessionPath = join(
      trialDirectory(runRoot, item.caseId, item.trial, item.condition),
      "session-artifact.json",
    );
    try {
      await stat(sessionPath);
      throw new Error(`Session already exists and will not be retried: ${item.caseId} trial ${item.trial}`);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
    const artifact = await runCliTrial({
      repositoryRoot: options.repositoryRoot,
      runRoot,
      runId: options.runId,
      caseId: item.caseId,
      trial: item.trial,
      condition: item.condition,
      profile,
      cliInvoker: options.cliInvoker,
      clock: options.clock,
    });
    await scorePersistedTrial({
      runRoot,
      caseId: item.caseId,
      trial: item.trial,
      condition: item.condition,
      scorerPath,
    });
    attemptedSessions += 1;
    consecutiveTechnicalFailures = artifact.endReason === "error" ? consecutiveTechnicalFailures + 1 : 0;
    if (consecutiveTechnicalFailures >= 2) {
      status = "paused-technical-failures";
      pauses.push({ at: now(), afterSession: attemptedSessions });
      break;
    }
  }

  const artifactHashes: Record<string, { session: string; result: string }> = {};
  for (const item of roundItems.slice(0, attemptedSessions)) {
    const directory = trialDirectory(runRoot, item.caseId, item.trial, item.condition);
    artifactHashes[`${item.condition}/${item.caseId}`] = {
      session: sha256(await readFile(join(directory, "session-artifact.json"))),
      result: sha256(await readFile(join(directory, "trial-result.json"))),
    };
  }
  const roundExecution: RoundExecutionCheckpoint = {
    round: options.round,
    status,
    attemptedSessions,
    remainingSessions: roundItems.length - attemptedSessions,
    consecutiveTechnicalFailures,
    artifactHashes,
    pauses,
    continuations,
  };
  await writeJson(checkpointPath, roundExecution);
  const results = await readAllResults(runRoot, mode, expectedResultIdentity);
  let roundOneCheckpoint: EvaluationSummary["roundOneCheckpoint"];
  if (options.round === 1) {
    const firstRound = results.filter((result) => result.trial === 1);
    roundOneCheckpoint = evaluateRoundOne(firstRound, selectedConditions(mode));
    await writeJson(join(runRoot, "round-one-checkpoint.json"), {
      schemaVersion: "2.0.0",
      evaluatedAt: (options.clock ?? (() => new Date()))().toISOString(),
      ...roundOneCheckpoint,
      trialResultHashes: Object.fromEntries(
        firstRound.map((result) => [
          `${result.condition}/${result.caseId}`,
          result.hashes.resultSha256,
        ]),
      ),
    });
  } else {
    roundOneCheckpoint = await readJson<EvaluationSummary["roundOneCheckpoint"]>(
      join(runRoot, "round-one-checkpoint.json"),
    );
  }

  const summary: EvaluationSummary = {
    schemaVersion: "2.0.0",
    protocol: EVALUATION_PROTOCOL,
    profile,
    mode,
    runId: options.runId,
    sourceRevision: SOURCE_REVISION,
    model,
    reasoningEffort: EXPECTED_REASONING_EFFORT,
    contextTier: EXPECTED_CONTEXT_TIER,
    trialOrder: createConditionSchedule(3, mode),
    trials: results,
    roundExecution,
    roundOneCheckpoint,
    limitations: [
      "The cases are controlled fault injections, not organic production incidents.",
      `${EVALUATION_CASE_IDS.length} selected cases and the scheduled sessions do not establish a general RCA accuracy rate.`,
      "Approvals are simulated evaluation fixtures and do not establish production authority.",
      `Both conditions use the ${EVALUATION_PROTOCOL} autonomous host-mediated evidence protocol with bounded, simulated per-call approvals.`,
      ...(profile === "debug" ? ["Debug run only: these results are harness diagnostics, not skill efficacy evidence."] : []),
      "The baseline receives a minimal diagnostic output schema, not the skill workflow; skill-only gates are not applicable.",
      "Set B service match is the shared primary diagnostic endpoint; Set A diagnosis claims can differ because skill claim-authority gates do not apply to the baseline.",
      "Diagnostic compatibility, unsupported claims, CR-16 satisfaction, and issue closure require human review.",
    ],
  };
  await writeJson(join(runRoot, "evaluation-summary.json"), summary);
  return summary;
}

async function assertPrepared(runRoot: string): Promise<{
  readonly parquetReader?: string;
}> {
  const manifest = await readJson<{
    sourceRevision?: string;
    transformationVersion?: string;
    cases?: readonly PreparedCaseManifest[];
    parquetReader?: string;
  }>(join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"));
  if (
    manifest.sourceRevision !== SOURCE_REVISION ||
    manifest.transformationVersion !== TRANSFORMATION_VERSION ||
    manifest.cases?.length !== EVALUATION_CASE_IDS.length
  ) {
    throw new Error("Prepared input manifest is missing or does not match the pinned source");
  }
  for (const caseId of EVALUATION_CASE_IDS) {
    const preparedCase = manifest.cases.find((item) => item.neutralId === caseId);
    const mapping = await readFile(join(runRoot, "inputs", "model-visible", caseId, "metric-columns.json"));
    if (!preparedCase || sha256(mapping) !== preparedCase.metricColumnsSha256) {
      throw new Error(`Metric column mapping integrity mismatch: ${caseId}`);
    }
    if (!Array.isArray(preparedCase.modalities) || preparedCase.modalities.length === 0) {
      throw new Error(`Prepared source identities are missing: ${caseId}`);
    }
    for (const modality of preparedCase.modalities) {
      if (!["metrics", "logs", "traces"].includes(modality.modality) ||
          modality.storePath !== `${modality.modality}.jsonl`) {
        throw new Error(`Invalid prepared evidence identity: ${caseId}`);
      }
      const store = await readFile(join(runRoot, "inputs", "model-visible", caseId, modality.storePath));
      if (sha256(store) !== modality.sha256) {
        throw new Error(`Prepared store integrity mismatch: ${caseId}/${modality.modality}`);
      }
    }
  }
  return { parquetReader: manifest.parquetReader };
}

async function requireResults(runRoot: string, trial: number, mode: EvaluationMode): Promise<void> {
  for (const item of createConditionSchedule(trial, mode).filter((item) => item.trial === trial)) {
    await stat(join(trialDirectory(runRoot, item.caseId, trial, item.condition), "trial-result.json"));
  }
}

async function readAllResults(
  runRoot: string, mode: EvaluationMode,
  expected: Pick<EvaluationSummary, "runId" | "profile" | "model">,
): Promise<readonly TrialResult[]> {
  const results: TrialResult[] = [];
  for (const item of createConditionSchedule(3, mode)) {
    const path = join(trialDirectory(runRoot, item.caseId, item.trial, item.condition), "trial-result.json");
    try {
      const result = await readJson<TrialResult>(path);
      if (!result || typeof result !== "object") throw new Error(`Invalid evaluation result: ${path}`);
      const technical = result.outcome === "protocol-error" || result.outcome === "execution-error";
      const expectedStatus = technical ? "unusable" : result.outcome === "candidate" ? "candidate" : "abstained";
      if (!result || result.schemaVersion !== "2.0.0" || result.protocol !== EVALUATION_PROTOCOL ||
          result.runId !== expected.runId || result.profile !== expected.profile || result.model !== expected.model ||
          result.reasoningEffort !== EXPECTED_REASONING_EFFORT || result.contextTier !== EXPECTED_CONTEXT_TIER ||
          result.condition !== item.condition || result.caseId !== item.caseId || result.trial !== item.trial ||
          !["candidate", "abstained", "blocked", "protocol-error", "execution-error"].includes(result.outcome) ||
          result.integrity !== (technical ? "fail" : "pass") || result.leadingHypothesis?.status !== expectedStatus ||
          (technical && (typeof result.errorCode !== "string" || !result.errorCode.trim())) ||
          (result.outcome === "blocked" && (typeof result.reason !== "string" || !result.reason.trim()))) {
        throw new Error(`Invalid evaluation result identity, provenance or outcome: ${item.condition}/${item.caseId}/trial-${item.trial}`);
      }
      results.push(result);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }
  }
  return results;
}

/** Computes the immutable evaluation input fingerprint for run continuation checks. */
export async function createInputFingerprint(
  repositoryRoot: string,
  runRoot: string,
): Promise<string> {
  const roots = [
    join(repositoryRoot, "evals", "rca-real-world"),
    join(repositoryRoot, "scripts", "evals", "rca-real-world"),
    join(repositoryRoot, ".github", "skills", "root-cause-analysis"),
  ];
  const files: { path: string; sha256: string }[] = [];
  for (const root of roots) {
    for (const path of await listFiles(root)) {
      files.push({
        path: relative(repositoryRoot, path).replaceAll("\\", "/"),
        sha256: sha256(await readFile(path)),
      });
    }
  }
  for (const path of [
    join(repositoryRoot, "package-lock.json"),
    join(runRoot, "inputs", "scorer-only", "preparation-manifest.json"),
  ]) {
    files.push({
      path: basename(path),
      sha256: sha256(await readFile(path)),
    });
  }
  for (const caseId of EVALUATION_CASE_IDS) {
    for (const name of ["metric-columns.json", "incident.json", "source-coverage.json"]) {
      const path = `inputs/model-visible/${caseId}/${name}`;
      files.push({ path, sha256: sha256(await readFile(join(runRoot, ...path.split("/")))) });
    }
  }
  files.sort((left, right) => compareStrings(left.path, right.path));
  return sha256(stableJson(files));
}

async function listFiles(root: string): Promise<readonly string[]> {
  const entries = await readdir(root, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listFiles(path)));
    } else if (entry.isFile()) {
      files.push(path);
    }
  }
  return files;
}

async function gitCommit(repositoryRoot: string): Promise<string> {
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: repositoryRoot });
  return stdout.trim();
}
