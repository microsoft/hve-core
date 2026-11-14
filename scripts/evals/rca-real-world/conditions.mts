// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { join } from "node:path";

import { createSchedule } from "./contracts.mts";

export type EvaluationCondition = "with-skill" | "without-skill";
export type EvaluationMode = "both" | EvaluationCondition;

export const RCA_SKILL_NAMES = [
  "root-cause-analysis",
  "causal-evidence-likelihood",
  "statistical-hypothesis-testing",
] as const;

/** Rejects unknown selections rather than silently substituting a different experiment. */
export function parseEvaluationMode(value: string): EvaluationMode {
  if (value !== "both" && value !== "with-skill" && value !== "without-skill") {
    throw new Error("Conditions must be both, with-skill, or without-skill");
  }
  return value;
}

/** Expands a validated selection into independently isolated experimental conditions. */
export function selectedConditions(mode: EvaluationMode): readonly EvaluationCondition[] {
  parseEvaluationMode(mode);
  return mode === "both" ? ["with-skill", "without-skill"] : [mode];
}

/** Orders sessions by round, then selected condition (with skills first), then case. */
export function createConditionSchedule(rounds: number, mode: EvaluationMode): readonly {
  readonly caseId: string;
  readonly trial: number;
  readonly condition: EvaluationCondition;
}[] {
  const caseSchedule = createSchedule(rounds);
  const conditions = selectedConditions(mode);
  const schedule: { caseId: string; trial: number; condition: EvaluationCondition }[] = [];
  for (let trial = 1; trial <= rounds; trial += 1) {
    for (const condition of conditions) {
      for (const item of caseSchedule.filter((item) => item.trial === trial)) {
        schedule.push({ ...item, condition });
      }
    }
  }
  return schedule;
}

/** Keeps condition identities separate for artifacts, scores, usage, and checkpoint hashes. */
export function trialDirectory(
  runRoot: string,
  caseId: string,
  trial: number,
  condition: EvaluationCondition,
): string {
  return join(runRoot, "sessions", condition, caseId, `trial-${trial}`);
}

/** Requests one best diagnostic guess for the shared Set B scorer, without a Set A finding. */
export function baselineOutputContract(): string {
  return [
    "Solve the incident using your own analysis, without skills or custom agents.",
    "Report one best diagnostic guess using these opening bullet fields:",
    "* Candidate target: your best overall service diagnosis, or No defensible candidate if the evidence cannot identify one",
    "* Candidate mechanism: your best explanation of how that service caused the incident, or Unassessed",
    "* Working confidence: your confidence in this diagnosis, with a brief reason",
    "After these fields, explain your evidence, uncertainty, alternatives, and limitations in your own format.",
    "Give your strongest diagnosis, not a weaker alternative. Do not fabricate evidence or present an unverified guess as a verified root cause.",
    "State that fixture approval is simulated and is not production authorization.",
  ].join("\n");
}
