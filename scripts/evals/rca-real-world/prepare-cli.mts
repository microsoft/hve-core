// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { prepareCases, verifyPreparedRun } from "./prepare.mts";
import { EVALUATION_RUN_DIRECTORY, parseEvidenceTrack, writeJson } from "./contracts.mts";
import { convertRawRun, prepareRawCases, verifyRawRun } from "./raw-prepare.mts";

const { values } = parseArgs({
  options: {
    "run-id": { type: "string" },
    check: { type: "boolean", default: false },
    track: { type: "string", default: "prepared" },
    seed: { type: "string" },
    "convert-only": { type: "boolean", default: false },
  },
});

if (!values["run-id"]) {
  throw new Error("Usage: node prepare-cli.mts --run-id <run-id> [--track prepared|raw] [--seed <seed>] [--check | --convert-only]");
}
if (!/^[a-z0-9][a-z0-9-]{2,63}$/.test(values["run-id"])) throw new Error("Invalid preparation run ID");
const track = parseEvidenceTrack(values.track);
if (values.seed !== undefined && track !== "raw") throw new Error("--seed applies only to the raw track");
if (values["convert-only"]) {
  if (track !== "raw" || values.check || values.seed !== undefined) throw new Error("--convert-only requires --track raw and cannot combine with --check or --seed");
  await convertRawRun(resolve(import.meta.dirname, "..", "..", "..", ".copilot-tracking", "evaluations", EVALUATION_RUN_DIRECTORY, values["run-id"]));
  process.stdout.write("Unused raw originals converted and verified as unmapped JSONL\n");
  process.exit(0);
}

if (values.check) {
  if (track === "raw") {
    await verifyRawRun(resolve(import.meta.dirname, "..", "..", "..", ".copilot-tracking", "evaluations", EVALUATION_RUN_DIRECTORY, values["run-id"]));
    process.stdout.write("Raw input integrity verified\n");
    process.exit(0);
  }
  const result = await verifyPreparedRun(
    resolve(import.meta.dirname, "..", "..", ".."),
    values["run-id"],
  );
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(0);
}

const result = await (track === "raw" ? prepareRawCases : prepareCases)({
  repositoryRoot: resolve(import.meta.dirname, "..", "..", ".."),
  runId: values["run-id"],
  seed: values.seed,
});

const commandPath = join(result.runRoot, "commands.json");
await writeJson(commandPath, {
  schemaVersion: "1.0.0",
  commands: [
    {
      command: `node scripts/evals/rca-real-world/prepare-cli.mts --run-id ${values["run-id"]} --track ${track}${values.seed === undefined ? "" : ` --seed ${JSON.stringify(values.seed)}`}`,
      exitCode: 0,
      purpose: "Prepare and validate blinded inputs",
    },
  ],
});

process.stdout.write(`${JSON.stringify(result)}\n`);
