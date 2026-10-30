// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { test } from "node:test";

import { parseRunArguments, selectEvaluationProfile } from "../../../evals/rca-real-world/run-cli.mts";

test("parses explicit profiles without losing the resume inheritance sentinel", () => {
  const args = ["--run-id", "fixture", "--round", "1"];
  assert.equal(parseRunArguments(args).profile, undefined);
  assert.equal(parseRunArguments([...args, "--profile", "debug"]).profile, "debug");
  assert.equal(parseRunArguments([...args, "--profile", "production"]).profile, "production");
  assert.throws(() => parseRunArguments([...args, "--profile", "other"]), /expected debug or production/);
});

test("defaults new noninteractive runs to debug without asking", async () => {
  const result = await selectEvaluationProfile({
    round: 1, interactive: false,
    ask: async () => { throw new Error("Must not prompt"); },
  });
  assert.equal(result, "debug");
});

test("offers the selected CLI models and defaults interactive new runs to debug", async () => {
  for (const [answer, expected] of [["", "debug"], ["a", "debug"], ["b", "production"]] as const) {
    const result = await selectEvaluationProfile({
      round: 1, interactive: true,
      ask: async (question) => {
        assert.match(question, /a\) Debug run with gpt-5\.6-luna \(default\)/);
        assert.match(question, /b\) Production evaluation run with gpt-5\.6-sol/);
        return answer;
      },
    });
    assert.equal(result, expected);
  }
});

test("resumes without prompting or replacing immutable profile selection", async () => {
  const ask = async () => { throw new Error("Must not prompt"); };
  assert.equal(await selectEvaluationProfile({ round: 2, interactive: true, ask }), undefined);
  assert.equal(await selectEvaluationProfile({
    round: 1, continueAfterTechnicalStop: true, interactive: true, ask,
  }), undefined);
  assert.equal(await selectEvaluationProfile({
    round: 1, profile: "production", interactive: true, ask,
  }), "production");
});
