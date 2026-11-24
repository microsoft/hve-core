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
  contextRef: "refs/heads/main",
  env: {},
  repository: { id: REPOSITORY_ID, default_branch: "main" },
  runs: {
    100: { id: 100, path: ORCHESTRATOR, head_branch: "main", head_sha: SOURCE_SHA, status: "completed", conclusion: "success" },
    200: { id: 200, path: ORCHESTRATOR, head_branch: EXECUTION_TAG, head_sha: SOURCE_SHA, status: "completed", conclusion: "success" },
    900: { id: 900, path: ORCHESTRATOR, head_branch: "main", head_sha: SOURCE_SHA, status: "completed", conclusion: "success" },
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
  "publisher-non-default-ref": () => Object.assign(withFinalArtifact(baseState()), { contextRef: "refs/heads/feature/unreviewed" }),
  "publisher-run-failed": () => {
    const state = withFinalArtifact(baseState());
    state.runs[900].conclusion = "failure";
    return state;
  },
  "publisher-wrong-workflow": () => {
    const state = withFinalArtifact(baseState());
    state.runs[900].path = ".github/workflows/other.yml";
    return state;
  },
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

const continuationState = (ambiguous = false) => {
  const state = scenarios["orchestrator-tag-resume"]();
  const snapshot = state.artifacts[0].content;
  const prior = state.artifacts[1].content;
  const checkpoint = buildCheckpoint(snapshot, { waveNumber: 2, issueIds: [3, 4], runId: "900" });
  checkpoint.prior_checkpoint_digest = prior.checkpoint_digest;
  const { checkpoint_digest: ignored, ...material } = checkpoint;
  checkpoint.checkpoint_digest = digest(material);
  state.artifacts.push({
    id: 9002, name: `backlog-grooming-sweep-v1-${SWEEP_ID}-checkpoint-2-900`, runId: "900",
    file: "checkpoint.json", content: checkpoint,
  });
  if (ambiguous) state.artifacts.push({ ...state.artifacts.at(-1), id: 9003 });
  state.actor = "github-actions[bot]";
  Object.assign(state.env, {
    INPUT_SOURCE_REF: snapshot.source_ref, INPUT_SWEEP_ID: SWEEP_ID, INPUT_WAVE_NUMBER: "2",
    INPUT_SNAPSHOT_RUN_ID: "100", INPUT_SNAPSHOT_ARTIFACT_ID: "1001",
    INPUT_SNAPSHOT_DIGEST: snapshot.snapshot_digest, INPUT_CHECKPOINT_RUN_ID: "200",
    INPUT_CHECKPOINT_ARTIFACT_ID: "2001", INPUT_CHECKPOINT_DIGEST: prior.checkpoint_digest,
  });
  return state;
};
const paginatedState = () => {
  const state = baseState();
  state.allowCapture = true;
  for (let id = 400; id < 498; id += 1) {
    state.runs[id] = { ...state.runs[100], id };
  }
  for (let index = 0; index < 101; index += 1) {
    state.artifacts.push({
      id: 4000 + index, name: index === 0 ? snapshotName(SWEEP_ID) : `unrelated-${index}`,
      runId: "900", expired: index === 0,
    });
  }
  return state;
};
const budgetState = (count, metadataOnly) => {
  const state = withSnapshotArtifact(baseState(), buildSnapshot());
  state.env = { GITHUB_REF: "refs/heads/main", GITHUB_SHA: SOURCE_SHA };
  state.metadataExpired = [];
  for (let index = 1; index < count; index += 1) {
    state.artifacts.push(metadataOnly ? {
      id: 5000 + index, name: `backlog-grooming-sweep-v1-${SWEEP_ID}-checkpoint-1-${index}`,
      runId: 900,
    } : {
      id: 5000 + index, name: snapshotName(index.toString(16).padStart(64, "0")),
      runId: 100, file: "snapshot.json", content: {},
    });
    if (metadataOnly) state.metadataExpired.push(5000 + index);
  }
  return state;
};
Object.assign(scenarios, {
  "discovery-initial-pages": paginatedState,
  "discovery-failed-tag-resume": () => {
    const state = scenarios["orchestrator-tag-resume"]();
    state.runs[100].conclusion = "failure";
    state.runs[200].conclusion = "failure";
    state.artifacts[1].runId = "200";
    return state;
  },
  "discovery-duplicate-continuation": () => continuationState(),
  "discovery-ambiguous-continuation": () => continuationState(true),
  "discovery-run-http500": () => ({ ...baseState(), transportFault: "runs" }),
  "discovery-artifact-http500": () => ({ ...baseState(), transportFault: "artifacts" }),
  "discovery-snapshot-http500": () => ({
    ...withSnapshotArtifact(baseState(), buildSnapshot()), transportFault: 1001,
  }),
  "discovery-checkpoint-http500": () => {
    const state = scenarios["orchestrator-tag-resume"]();
    state.env.GITHUB_REF = "refs/heads/main";
    state.transportFault = 2001;
    return state;
  },
  "discovery-duplicate-run": () => ({ ...paginatedState(), paginationFault: "duplicate-run" }),
  "discovery-duplicate-artifact": () => ({ ...paginatedState(), paginationFault: "duplicate-artifact" }),
  "discovery-missing-page": () => ({ ...paginatedState(), paginationFault: "missing-page" }),
  "discovery-malformed-page": () => ({ ...baseState(), paginationFault: "malformed-page" }),
  "discovery-page-bound": () => ({ ...baseState(), paginationFault: "page-bound" }),
  "discovery-metadata-500": () => budgetState(500, true),
  "discovery-metadata-501": () => budgetState(501, true),
  "discovery-download-50": () => budgetState(50, false),
  "discovery-download-51": () => budgetState(51, false),
  "discovery-calendar-noop": () => ({ ...baseState(), eventName: "schedule" }),
});

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
  workflow_run: { id: Number(artifact.runId) },
});

const calls = { runs: [], artifacts: [], broad: 0, metadata: [], downloads: [], issues: 0 };
const exhausted = (stage) => Object.assign(new Error(`${stage}: exhausted HTTP 500`), { status: 500 });
const pageResponse = (items, key, page, stage) => {
  const response = {
    data: { total_count: items.length, [key]: items.slice((page - 1) * 100, page * 100) },
    headers: page * 100 < items.length ? {
      link: `<https://api.github.com/collection?per_page=100&page=${page + 1}>; rel="next"`,
    } : {},
  };
  const fault = state.paginationFault;
  if (page === 2 && ((fault === "duplicate-run" && stage === "runs") ||
      (fault === "duplicate-artifact" && stage === "artifacts"))) {
    response.data[key][0] = items[0];
  }
  if (fault === "missing-page" && stage === "runs" && page === 1) response.headers = {};
  if (fault === "malformed-page") response.data.total_count = "3";
  if (fault === "page-bound") {
    response.headers.link = `<https://api.github.com/collection?page=${page + 1}>; rel="next"`;
  }
  return response;
};
const github = {
  paginate: async (method, params) => {
    const items = [];
    for (let page = 1; ; page += 1) {
      const response = await method({ ...params, page });
      items.push(...(response.data.artifacts ?? response.data.workflow_runs ?? response.data));
      if (!response.headers?.link) return items;
    }
  },
  rest: {
    actions: {
      getWorkflowRun: async ({ run_id: runId }) => {
        if (!state.runs[runId]) throw notFound(`run ${runId}`);
        return { data: state.runs[runId] };
      },
      getArtifact: async ({ artifact_id: artifactId }) => {
        calls.metadata.push(Number(artifactId));
        if (state.transportFault === Number(artifactId)) throw exhausted(`Artifact metadata ${artifactId}`);
        const artifact = describeArtifact(findArtifact(artifactId));
        if (state.metadataExpired?.includes(Number(artifactId))) artifact.expired = true;
        return { data: artifact };
      },
      listWorkflowRuns: async (params) => {
        calls.runs.push(params);
        if (state.transportFault === "runs") throw exhausted("workflow runs");
        return pageResponse(Object.values(state.runs), "workflow_runs", params.page, "runs");
      },
      listWorkflowRunArtifacts: async ({ run_id: runId, page = 1, ...params }) => {
        calls.artifacts.push({ ...params, run_id: runId, page });
        if (state.transportFault === "artifacts") throw exhausted("run artifacts");
        const artifacts = state.artifacts.filter((artifact) => Number(artifact.runId) === Number(runId))
          .map((artifact) => {
            const { workflow_run: ignored, ...record } = describeArtifact(artifact);
            return record;
          });
        return pageResponse(artifacts, "artifacts", page, "artifacts");
      },
      listArtifactsForRepo: async ({ name, page = 1 }) => {
        calls.broad += 1;
        if (!name) throw new Error("Harness forbids broad artifact discovery");
        return pageResponse(
          state.artifacts.filter((artifact) => artifact.name === name).map(describeArtifact),
          "artifacts", page, "artifacts",
        );
      },
      downloadArtifact: async ({ artifact_id: artifactId }) => {
        calls.downloads.push(Number(artifactId));
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
        calls.issues += 1;
        if (!state.allowCapture) throw new Error("Harness forbids fresh snapshot capture");
        return { data: [1, 2, 3, 4].map((number) => ({
          number, state: "open", updated_at: "2026-09-01T00:00:00Z",
        })) };
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
  ref: state.contextRef,
  actor: state.actor ?? "octocat",
  runId: 300,
  repo: { owner: OWNER, repo: REPO },
  payload: { repository: { id: REPOSITORY_ID } },
};

Object.assign(process.env, {
  SWEEP_PROTOCOL_VERSION: "backlog-grooming-sweep/v1",
  INPUT_PROTOCOL_VERSION: "backlog-grooming-sweep/v1",
  INPUT_WAVE_NUMBER: "1",
  INPUT_SOURCE_REF: "",
  INPUT_SWEEP_ID: "",
  INPUT_SNAPSHOT_RUN_ID: "",
  INPUT_SNAPSHOT_ARTIFACT_ID: "",
  INPUT_SNAPSHOT_DIGEST: "",
  INPUT_CHECKPOINT_RUN_ID: "",
  INPUT_CHECKPOINT_ARTIFACT_ID: "",
  INPUT_CHECKPOINT_DIGEST: "",
  SWEEP_DISCOVERY_DOWNLOAD_LIMIT: "50",
  SWEEP_DISCOVERY_METADATA_LIMIT: "500",
  SWEEP_SHARD_COUNT: "2",
  SWEEP_SHARD_WIDTH: "5",
  SWEEP_MAX_PARALLEL: "2",
  SWEEP_PER_WORKER_AIC: "1000",
  GITHUB_WORKFLOW_REF: `${OWNER}/${REPO}/${ORCHESTRATOR}@refs/heads/main`,
  GITHUB_REF: "refs/heads/main",
  GITHUB_SHA: SOURCE_SHA,
  GITHUB_RUN_ATTEMPT: "1",
  SWEEP_RUN_ID: "900",
  ...state.env,
});

fs.mkdirSync(workDir, { recursive: true });
process.chdir(workDir);
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;
const body = fs.readFileSync(scriptFile, "utf8");
let error = null;
try {
  const clock = class extends Date {
    constructor(...args) {
      super(...(args.length ? args : ["2026-10-21T12:00:00.000Z"]));
    }
  };
  await new AsyncFunction("require", "github", "context", "core", "exec", "Date", body)(
    require, github, context, core, exec, clock,
  );
} catch (caught) {
  error = caught.message;
}
const readOutput = (name) => {
  const file = path.join("sweep-output", `${name}.json`);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
};
process.stdout.write(`${JSON.stringify({
  outputs, error, messages, calls,
  snapshot: readOutput("snapshot") ?? readOutput("snapshot-reference"), manifest: readOutput("manifest"),
})}\n`);
