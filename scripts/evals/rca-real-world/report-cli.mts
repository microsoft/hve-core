// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { generateEvidenceReport } from "./report.mts";
import { EVALUATION_RUN_DIRECTORY } from "./contracts.mts";

/** Parses report options, requiring a run ID and defaulting the review date to the current UTC day. */
export function parseReportArguments(args: readonly string[], now: Date = new Date()): {
  readonly runId: string;
  readonly reviewDate: string;
} {
  const { values } = parseArgs({
    args: [...args],
    options: {
      "run-id": { type: "string" },
      date: { type: "string", default: now.toISOString().slice(0, 10) },
    },
  });
  if (!values["run-id"]) {
    throw new Error("Usage: npm run rca-eval:report -- --run-id <run-id> [--date YYYY-MM-DD]");
  }
  return { runId: values["run-id"], reviewDate: values.date };
}

if (import.meta.main) {
  const options = parseReportArguments(process.argv.slice(2));
  const repositoryRoot = resolve(import.meta.dirname, "..", "..", "..");
  const result = await generateEvidenceReport({
    repositoryRoot,
    runRoot: join(
      repositoryRoot,
      ".copilot-tracking",
      "evaluations",
      EVALUATION_RUN_DIRECTORY,
      options.runId,
    ),
    reviewDate: options.reviewDate,
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
}
