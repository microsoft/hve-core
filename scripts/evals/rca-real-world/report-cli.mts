// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { generateEvidenceReport } from "./report.mts";

const { values } = parseArgs({
  options: {
    "run-id": { type: "string" },
    date: { type: "string", default: "2026-10-19" },
  },
});

if (!values["run-id"]) {
  throw new Error("Usage: npm run rca-eval:report -- --run-id <run-id> [--date YYYY-MM-DD]");
}

const repositoryRoot = resolve(import.meta.dirname, "..", "..", "..");
const result = await generateEvidenceReport({
  repositoryRoot,
  runRoot: join(
    repositoryRoot,
    ".copilot-tracking",
    "evaluations",
    "rcaeval-three-case",
    values["run-id"],
  ),
  reviewDate: values.date,
});
process.stdout.write(`${JSON.stringify(result)}\n`);
