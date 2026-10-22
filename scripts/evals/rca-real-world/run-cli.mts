// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { runRound } from "./runner.mts";
import { readJson, writeJson } from "./contracts.mts";

const { values } = parseArgs({
  options: {
    "run-id": { type: "string" },
    round: { type: "string" },
  },
});

if (!values["run-id"] || !values.round || !["1", "2", "3"].includes(values.round)) {
  throw new Error("Usage: npm run ci:rca-eval -- --run-id <run-id> --round <1|2|3>");
}

const summary = await runRound({
  repositoryRoot: resolve(import.meta.dirname, "..", "..", ".."),
  runId: values["run-id"],
  round: Number(values.round) as 1 | 2 | 3,
});

const runRoot = join(
  resolve(import.meta.dirname, "..", "..", ".."),
  ".copilot-tracking",
  "evaluations",
  "rcaeval-three-case",
  values["run-id"],
);
const commandPath = join(runRoot, "commands.json");
const existing = await readJson<{
  schemaVersion: string;
  commands: readonly unknown[];
}>(commandPath);
await writeJson(commandPath, {
  schemaVersion: existing.schemaVersion,
  commands: [
    ...existing.commands,
    {
      command: `node scripts/evals/rca-real-world/run-cli.mts --run-id ${values["run-id"]} --round ${values.round}`,
      exitCode: 0,
      purpose: `Execute and score trial round ${values.round}`,
    },
  ],
});

process.stdout.write(
  `${JSON.stringify({
    runId: summary.runId,
    completedTrials: summary.trials.length,
    roundOneDecision: summary.roundOneCheckpoint?.decision,
  })}\n`,
);
