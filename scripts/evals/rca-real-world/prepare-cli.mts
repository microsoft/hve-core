// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { prepareCases, verifyPreparedRun } from "./prepare.mts";
import { writeJson } from "./contracts.mts";

const { values } = parseArgs({
  options: {
    "run-id": { type: "string" },
    check: { type: "boolean", default: false },
  },
});

if (!values["run-id"]) {
  throw new Error("Usage: node prepare-cli.mts --run-id <run-id> [--check]");
}

if (values.check) {
  const result = await verifyPreparedRun(
    resolve(import.meta.dirname, "..", "..", ".."),
    values["run-id"],
  );
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(0);
}

const result = await prepareCases({
  repositoryRoot: resolve(import.meta.dirname, "..", "..", ".."),
  runId: values["run-id"],
});

const commandPath = join(result.runRoot, "commands.json");
await writeJson(commandPath, {
  schemaVersion: "1.0.0",
  commands: [
    {
      command: `node scripts/evals/rca-real-world/prepare-cli.mts --run-id ${values["run-id"]}`,
      exitCode: 0,
      purpose: "Prepare and validate blinded inputs",
    },
  ],
});

process.stdout.write(`${JSON.stringify(result)}\n`);
