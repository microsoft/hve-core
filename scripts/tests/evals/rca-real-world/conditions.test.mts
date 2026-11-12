// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";

import { baselineOutputContract, createConditionSchedule, parseEvaluationMode } from "../../../evals/rca-real-world/conditions.mts";
import { parseRunArguments, selectEvaluationMode } from "../../../evals/rca-real-world/run-cli.mts";

test("schedules thirty unique sessions by round, condition, then case", () => {
  const schedule = createConditionSchedule(3, "both");
  assert.equal(schedule.length, 30);
  assert.equal(new Set(schedule.map((item) => `${item.condition}/${item.caseId}/${item.trial}`)).size, 30);
  const caseIds = ["case-01", "case-02", "case-03", "case-04", "case-05"];
  for (const mode of ["both", "with-skill", "without-skill"] as const) {
    const conditions = mode === "both" ? ["with-skill", "without-skill"] : [mode];
    for (const rounds of [1, 2, 3]) {
      const expected = [];
      for (let trial = 1; trial <= rounds; trial += 1) {
        for (const condition of conditions) {
          for (const caseId of caseIds) {
            expected.push({ caseId, trial, condition });
          }
        }
      }
      assert.deepEqual(createConditionSchedule(rounds, mode), expected);
    }
  }
  assert.throws(() => createConditionSchedule(0, "both"), RangeError);
  assert.throws(() => createConditionSchedule(4, "both"), RangeError);
});

test("validates explicit CLI condition selection without side effects", () => {
  assert.equal(parseRunArguments(["--run-id", "fixture", "--round", "1"]).mode, undefined);
  assert.equal(parseRunArguments([
    "--run-id", "fixture", "--round", "1", "--continue-after-technical-stop",
  ]).continueAfterTechnicalStop, true);
  assert.equal(parseRunArguments([
    "--run-id", "fixture", "--round", "1", "--conditions", "without-skill", "--interactive",
  ]).mode, "without-skill");
  assert.throws(() => parseEvaluationMode("invalid"), /Conditions must be/);
  assert.throws(() => parseRunArguments(["--run-id", "fixture", "--round", "4"]), /Usage:/);
  assert.throws(() => parseRunArguments(["--run-id", "fixture", "--round", "01"]), /Usage:/);
  assert.throws(() => parseRunArguments([
    "--run-id", "fixture", "--round", "1", "--conditions", "invalid",
  ]), /Conditions must be/);
});

test("defaults to both noninteractively and prompts only at interactive initialization", async () => {
  const noPrompt = async (): Promise<string> => { throw new Error("Must not prompt"); };
  assert.equal(await selectEvaluationMode({
    round: 1, interactive: false, ask: noPrompt,
  }), "both");
  assert.equal(await selectEvaluationMode({
    round: 2, interactive: true, ask: noPrompt,
  }), undefined);
  assert.equal(await selectEvaluationMode({
    round: 1, interactive: true, mode: "with-skill", ask: noPrompt,
  }), "with-skill");
  for (const answer of ["", "both", "with-skill", "without-skill"]) {
    let prompts = 0;
    assert.equal(await selectEvaluationMode({
      round: 1, interactive: true,
      ask: async (question) => {
        prompts += 1;
        assert.match(question, /both.*with-skill only.*without-skill only/);
        return answer;
      },
    }), answer || "both");
    assert.equal(prompts, 1);
  }
  await assert.rejects(selectEvaluationMode({
    round: 1, interactive: true, ask: async () => "invalid",
  }), /Conditions must be/);
});

test("baseline requests one best guess without a supported-finding split or skill workflow", () => {
  const prompt = baselineOutputContract();
  assert.match(prompt, /best overall service diagnosis/);
  assert.match(prompt, /Candidate target/);
  assert.match(prompt, /Candidate mechanism/);
  assert.match(prompt, /Working confidence/);
  assert.match(prompt, /No defensible candidate/);
  assert.doesNotMatch(prompt, /Finding status|Root-cause target|Fault or mechanism|Set A|Set B|###|root-cause-analysis|causal-evidence-likelihood|statistical-hypothesis-testing|eight|completion gate|H-001|T-001/i);
});
