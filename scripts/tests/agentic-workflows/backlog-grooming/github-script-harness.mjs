// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// github-script-harness.mjs
//
// Executes an extracted actions/github-script body against mocked GitHub
// clients for one named scenario and prints the observed outputs or error.
// Usage: node github-script-harness.mjs <script-file> <scenario> <work-dir>

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const [scriptFile, scenarioName, workDir] = process.argv.slice(2);

const ORCHESTRATOR = ".github/workflows/backlog-groom-orchestrator.yml";
const OWNER = "octo";
const REPO = "repo";
const REPOSITORY_ID = 42;
const SOURCE_SHA = "a".repeat(40);
const OTHER_SHA = "d".repeat(40);
const SWEEP_ID = "b".repeat(64);
const OTHER_SWEEP_ID = "c".repeat(64);
const EXECUTION_TAG = `backlog-grooming-sweep/${SWEEP_ID}`;

const canonicalize = (value) => {
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value).sort().map(
      (key) => `${JSON.stringify(key)}:${canonicalize(value[key])}`,
    ).join(",")}}`;
  }
  return JSON.stringify(value);
};
const digest = (value) => crypto.createHash("sha256").update(canonicalize(value)).digest("hex");
const notFound = (what) => Object.assign(new Error(`Not Found: ${what}`), { status: 404 });

const buildSnapshot = ({ sweepId = SWEEP_ID, waves = 1 } = {}) => {
  const shardWidth = waves === 1 ? 5 : 1;
  const material = {
    schema_version: "backlog-grooming-sweep-snapshot/v1",
    sweep_id: sweepId,
    repository_id: String(REPOSITORY_ID),
    repository: `${OWNER}/${REPO}`,
    workflow_ref: `${OWNER}/${REPO}/${ORCHESTRATOR}@refs/heads/main`,
    source_ref: "refs/heads/main",
    source_sha: SOURCE_SHA,
    initiating_run_id: "100",
    initiating_attempt: 1,
    captured_at: "2026-09-07T09:00:00.000Z",
    prior_successful_timestamp: "1970-01-01T00:00:00.000Z",
    prior_cursor: 0,
    prior_published_aggregate_digest: null,
    ordered_issue_ids: [1, 2, 3, 4],
    cursor_candidate_ids: [1, 2, 3, 4],
    priority_issue_ids: [],
    total_snapshot_count: 4,
    eligibility_predicate_version: "open-non-pull-request-excluding-trusted-tracker/v1",
    shard_count: 2,
    shard_width: shardWidth,
    max_parallel: 2,
    wave_capacity: 2 * shardWidth,
    required_waves: waves,
    per_worker_ai_credits: 1000,
    planned_aic_per_wave: 2000,
    planned_sweep_aic: waves * 2000,
  };
  return { ...material, snapshot_digest: digest(material) };
};

const buildCheckpoint = (snapshot, { waveNumber, issueIds, runId }) => {
  const covered = waveNumber * snapshot.wave_capacity > snapshot.total_snapshot_count ?
    snapshot.total_snapshot_count : waveNumber * snapshot.wave_capacity;
  const material = {
    schema_version: "backlog-grooming-sweep-checkpoint/v2",
    sweep_id: snapshot.sweep_id,
    snapshot_digest: snapshot.snapshot_digest,
    wave_number: waveNumber,
    required_waves: snapshot.required_waves,
    source_run_id: runId,
    source_attempt: 1,
    source_manifest_artifact_id: "1",
    source_manifest_digest: "e".repeat(64),
    source_aggregate_run_id: runId,
    source_aggregate_artifact_id: "2",
    source_aggregate_digest: "f".repeat(64),
    prior_checkpoint_run_id: null,
    prior_checkpoint_artifact_id: null,
    prior_checkpoint_digest: null,
    assessed_issue_ids: issueIds,
    deferred_issue_ids: [],
    contract_error_issue_ids: [],
    cumulative_covered_count: covered,
    cumulative_digest: "0".repeat(64),
    remaining_count: snapshot.total_snapshot_count - covered,
    sweep_complete: covered === snapshot.total_snapshot_count,
    completed_at: "2026-09-07T10:00:00.000Z",
  };
  return { ...material, checkpoint_digest: digest(material) };
};

const snapshotName = (sweepId) => `backlog-grooming-sweep-v1-${REPOSITORY_ID}-snapshot-${sweepId}`;

const baseState = () => ({
  eventName: "workflow_dispatch",
  env: {},
  repository: { id: REPOSITORY_ID, default_branch: "main" },
  runs: {
    100: { id: 100, path: ORCHESTRATOR, head_branch: "main", head_sha: SOURCE_SHA, conclusion: "success" },
    200: { id: 200, path: ORCHESTRATOR, head_branch: EXECUTION_TAG, head_sha: SOURCE_SHA, conclusion: "success" },
    900: { id: 900, path: ORCHESTRATOR, head_branch: "main", head_sha: SOURCE_SHA, conclusion: "success" },
  },
  refs: { [`tags/${EXECUTION_TAG}`]: { object: { type: "commit", sha: SOURCE_SHA } } },
  comparisonStatus: "identical",
  artifacts: [],
});

const withFinalArtifact = (state, sweepId = SWEEP_ID) => {
  state.artifacts.push({ id: 9001, name: `backlog-grooming-sweep-v1-${sweepId}-final-900`, runId: 900 });
  return state;
};
const withSnapshotArtifact = (state, snapshot, overrides = {}) => {
  state.artifacts.push({
    id: 1001, name: snapshotName(snapshot.sweep_id), runId: 100,
    file: "snapshot.json", content: snapshot, ...overrides,
  });
  return state;
};
const tagOrchestratorState = () => {
  const state = baseState();
  state.env = { GITHUB_REF: `refs/tags/${EXECUTION_TAG}`, GITHUB_SHA: SOURCE_SHA };
  return state;
};
const publisherTagState = () => {
  const state = withFinalArtifact(baseState());
  state.runs[900].head_branch = EXECUTION_TAG;
  return withSnapshotArtifact(state, buildSnapshot({ waves: 2 }));
};

const scenarios = {
  "publisher-main-current": () => withFinalArtifact(baseState()),
  "publisher-main-ancestor": () => Object.assign(withFinalArtifact(baseState()), { comparisonStatus: "ahead" }),
  "publisher-main-diverged": () => Object.assign(withFinalArtifact(baseState()), { comparisonStatus: "diverged" }),
  "publisher-main-nonterminal": () => baseState(),
  "publisher-unrelated-branch": () => {
    const state = withFinalArtifact(baseState());
    state.runs[900].head_branch = "feature/unrelated";
    return state;
  },
  "publisher-tag-valid": publisherTagState,
  "publisher-tag-sweep-mismatch": () => {
    const state = publisherTagState();
    state.runs[900].head_branch = `backlog-grooming-sweep/${OTHER_SWEEP_ID}`;
    return state;
  },
  "publisher-tag-ref-moved": () => {
    const state = publisherTagState();
    state.refs[`tags/${EXECUTION_TAG}`].object.sha = OTHER_SHA;
    return state;
  },
  "publisher-tag-feature-origin": () => {
    const state = publisherTagState();
    state.runs[100].head_branch = "feature/unreviewed";
    return state;
  },
  "publisher-tag-snapshot-missing": () => {
    const state = publisherTagState();
    state.artifacts = state.artifacts.filter((artifact) => !artifact.name.includes("-snapshot-"));
    return state;
  },
  "publisher-tag-stale": () => Object.assign(publisherTagState(), { comparisonStatus: "behind" }),
  "orchestrator-tag-missing": () => withSnapshotArtifact(tagOrchestratorState(), buildSnapshot({ sweepId: OTHER_SWEEP_ID })),
  "orchestrator-tag-invalid": () => {
    const snapshot = { ...buildSnapshot(), snapshot_digest: "9".repeat(64) };
    return withSnapshotArtifact(tagOrchestratorState(), snapshot);
  },
  "orchestrator-tag-complete": () => {
    const snapshot = buildSnapshot();
    const state = withSnapshotArtifact(tagOrchestratorState(), snapshot);
    state.artifacts.push({
      id: 2001, name: `backlog-grooming-sweep-v1-${SWEEP_ID}-checkpoint-1-200`, runId: 200,
      file: "checkpoint.json", content: buildCheckpoint(snapshot, { waveNumber: 1, issueIds: [1, 2, 3, 4], runId: "200" }),
    });
    return state;
  },
  "orchestrator-tag-resume": () => {
    const snapshot = buildSnapshot({ waves: 2 });
    const state = withSnapshotArtifact(tagOrchestratorState(), snapshot);
    state.artifacts.push({
      id: 2001, name: `backlog-grooming-sweep-v1-${SWEEP_ID}-checkpoint-1-200`, runId: 200,
      file: "checkpoint.json", content: buildCheckpoint(snapshot, { waveNumber: 1, issueIds: [1, 2], runId: "200" }),
    });
    return state;
  },
};

const buildScenario = scenarios[scenarioName];
if (!buildScenario) throw new Error(`Unknown scenario: ${scenarioName}`);
const state = buildScenario();

const findArtifact = (id) => {
  const artifact = state.artifacts.find((item) => item.id === Number(id));
  if (!artifact) throw notFound(`artifact ${id}`);
  return artifact;
};
const describeArtifact = (artifact) => ({
  id: artifact.id, name: artifact.name, expired: Boolean(artifact.expired),
  workflow_run: { id: artifact.runId },
});

const github = {
  paginate: async (method, params) => (await method(params)).data,
  rest: {
    actions: {
      getWorkflowRun: async ({ run_id: runId }) => {
        if (!state.runs[runId]) throw notFound(`run ${runId}`);
        return { data: state.runs[runId] };
      },
      getArtifact: async ({ artifact_id: artifactId }) => ({ data: describeArtifact(findArtifact(artifactId)) }),
      listWorkflowRunArtifacts: async ({ run_id: runId }) => ({
        data: state.artifacts.filter((artifact) => artifact.runId === runId).map(describeArtifact),
      }),
      listArtifactsForRepo: async ({ name }) => ({
        data: state.artifacts.filter((artifact) => !name || artifact.name === name).map(describeArtifact),
      }),
      downloadArtifact: async ({ artifact_id: artifactId }) => {
        const artifact = findArtifact(artifactId);
        return { data: Buffer.from(JSON.stringify({ file: artifact.file, content: artifact.content })) };
      },
    },
    repos: {
      get: async () => ({ data: state.repository }),
      compareCommitsWithBasehead: async () => ({ data: { status: state.comparisonStatus } }),
    },
    git: {
      getRef: async ({ ref }) => {
        if (!state.refs[ref]) throw notFound(`ref ${ref}`);
        return { data: state.refs[ref] };
      },
    },
    issues: {
      listForRepo: async () => {
        throw new Error("Harness forbids fresh snapshot capture");
      },
    },
  },
};

// Stands in for unzip: the mocked archive is a JSON envelope naming one file.
const exec = {
  exec: async (command, args) => {
    if (command !== "unzip") throw new Error(`Unexpected command: ${command}`);
    const [, archivePath, , destination] = args;
    const envelope = JSON.parse(fs.readFileSync(archivePath, "utf8"));
    fs.writeFileSync(path.join(destination, envelope.file), JSON.stringify(envelope.content));
    return 0;
  },
};

const outputs = {};
const messages = [];
const core = {
  setOutput: (name, value) => { outputs[name] = String(value); },
  info: (message) => messages.push({ level: "info", message }),
  warning: (message) => messages.push({ level: "warning", message }),
};
const context = {
  eventName: state.eventName,
  actor: "octocat",
  runId: 300,
  repo: { owner: OWNER, repo: REPO },
  payload: { repository: { id: REPOSITORY_ID }, workflow_run: { id: 900 } },
};

Object.assign(process.env, {
  SWEEP_PROTOCOL_VERSION: "backlog-grooming-sweep/v1",
  INPUT_PROTOCOL_VERSION: "backlog-grooming-sweep/v1",
  INPUT_WAVE_NUMBER: "1",
  SWEEP_DISCOVERY_DOWNLOAD_LIMIT: "50",
  SWEEP_DISCOVERY_METADATA_LIMIT: "500",
  GITHUB_RUN_ATTEMPT: "1",
  ...state.env,
});

fs.mkdirSync(workDir, { recursive: true });
process.chdir(workDir);
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;
const body = fs.readFileSync(scriptFile, "utf8");
let error = null;
try {
  await new AsyncFunction("require", "github", "context", "core", "exec", body)(require, github, context, core, exec);
} catch (caught) {
  error = caught.message;
}
process.stdout.write(`${JSON.stringify({ outputs, error, messages })}\n`);
