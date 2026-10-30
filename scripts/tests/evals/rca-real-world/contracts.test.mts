// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { join, resolve } from "node:path";
import { test } from "node:test";

import {
  EVALUATION_RUN_DIRECTORY,
  compareStrings,
  createSchedule,
  evaluationModel,
  parseEvaluationProfile,
  resolveInside,
  stableJson,
  validateContract,
  type EvaluationContract,
} from "../../../evals/rca-real-world/contracts.mts";

test("maps exact evaluation profiles to distinct fixed models", () => {
  assert.equal(evaluationModel(parseEvaluationProfile("debug")), "gpt-5.6-luna");
  assert.equal(evaluationModel(parseEvaluationProfile("production")), "gpt-5.6-sol");
  for (const invalid of ["", "Debug", "prod", "gpt-5.6-sol"]) {
    assert.throws(() => parseEvaluationProfile(invalid), /expected debug or production/);
  }
});

test("preserves the existing evaluation directory name", () => {
  assert.equal(EVALUATION_RUN_DIRECTORY, "rcaeval-three-case");
});

function validContract(): EvaluationContract {
  const file = (name: string) => ({
    name,
    objectId: "a".repeat(40),
    sha256: "b".repeat(64),
    size: 1,
  });
  return {
    schemaVersion: "1.0.0",
    source: {
      dataset: "phamquiluan/RCAEval",
      revision: "c".repeat(40),
      license: "MIT",
      sourceUrl: "https://example.invalid",
      licenseCard: { path: "README.md", objectId: "d".repeat(40) },
      caseIndex: { path: "cases.parquet", sha256: "e".repeat(64), size: 1 },
    },
    cases: [
      {
        neutralId: "case-01",
        sourcePath: "source-case-one",
        trialOrder: 1,
        modalities: ["metrics"],
        files: [file("inject_time.txt"), file("metrics.parquet")],
      },
      {
        neutralId: "case-02",
        sourcePath: "source-case-two",
        trialOrder: 2,
        modalities: ["metrics", "logs", "traces"],
        files: [
          file("inject_time.txt"),
          file("metrics.parquet"),
          file("logs.parquet"),
          file("traces.parquet"),
        ],
      },
      {
        neutralId: "case-03",
        sourcePath: "source-case-three",
        trialOrder: 3,
        modalities: ["metrics", "logs", "traces"],
        files: [
          file("inject_time.txt"),
          file("metrics.parquet"),
          file("logs.parquet"),
          file("traces.parquet"),
        ],
      },
      {
        neutralId: "case-04",
        sourcePath: "source-case-four",
        trialOrder: 4,
        modalities: ["metrics", "logs"],
        files: [
          file("inject_time.txt"),
          file("metrics.parquet"),
          file("logs.parquet"),
        ],
      },
      {
        neutralId: "case-05",
        sourcePath: "source-case-five",
        trialOrder: 5,
        modalities: ["metrics", "logs", "traces"],
        files: [
          file("inject_time.txt"),
          file("metrics.parquet"),
          file("logs.parquet"),
          file("traces.parquet"),
        ],
      },
    ],
  };
}

test("validates the exact neutral case order", () => {
  assert.deepEqual(
    validateContract(validContract()).map((item) => item.neutralId),
    ["case-01", "case-02", "case-03", "case-04", "case-05"],
  );

  const invalid = validContract();
  const reversed = { ...invalid, cases: [...invalid.cases].reverse() };
  assert.deepEqual(
    validateContract(reversed).map((item) => item.neutralId),
    ["case-01", "case-02", "case-03", "case-04", "case-05"],
  );
});

test("rejects malformed source identities and modality drift", () => {
  const contract = validContract();
  const first = contract.cases[0];
  assert.ok(first);
  assert.throws(
    () =>
      validateContract({
        ...contract,
        cases: [
          {
            ...first,
            files: [{ ...first.files[0]!, sha256: "weak" }, ...first.files.slice(1)],
          },
          ...contract.cases.slice(1),
        ],
      }),
    /Invalid source identity/,
  );
  assert.throws(
    () =>
      validateContract({
        ...contract,
        cases: [
          { ...first, modalities: ["metrics", "logs"] },
          ...contract.cases.slice(1),
        ],
      }),
    /file set does not match/,
  );
});

test("creates the approved round-robin schedule", () => {
  assert.deepEqual(createSchedule(3), [
    { caseId: "case-01", trial: 1 },
    { caseId: "case-02", trial: 1 },
    { caseId: "case-03", trial: 1 },
    { caseId: "case-04", trial: 1 },
    { caseId: "case-05", trial: 1 },
    { caseId: "case-01", trial: 2 },
    { caseId: "case-02", trial: 2 },
    { caseId: "case-03", trial: 2 },
    { caseId: "case-04", trial: 2 },
    { caseId: "case-05", trial: 2 },
    { caseId: "case-01", trial: 3 },
    { caseId: "case-02", trial: 3 },
    { caseId: "case-03", trial: 3 },
    { caseId: "case-04", trial: 3 },
    { caseId: "case-05", trial: 3 },
  ]);
});

test("rejects output-root escape", () => {
  const root = resolve("safe");
  assert.throws(() => resolveInside(root, join("..", "outside")), /allowed root/);
  assert.throws(() => resolveInside(root, "."), /allowed root/);
});

test("resolves a child below the output root", () => {
  const root = resolve("safe");
  const child = join("sessions", "trial-1");
  assert.equal(resolveInside(root, child), join(root, child));
});

test("serializes equivalent objects deterministically", () => {
  assert.equal(stableJson({ b: 2, a: { d: 4, c: 3 } }), stableJson({ a: { c: 3, d: 4 }, b: 2 }));
});

test("compares strings by code units rather than locale", () => {
  assert.equal(compareStrings("", ""), 0);
  assert.equal(compareStrings("same", "same"), 0);
  for (const [left, right] of [
    ["", "a"],
    ["A", "a"],
    ["Z", "a"],
    ["a", "aa"],
    ["z", "\u00e4"],
    ["e\u0301", "\u00e9"],
    ["\ud83d\ude00", "\ue000"],
  ]) {
    assert.equal(compareStrings(left, right), -1);
    assert.equal(compareStrings(right, left), 1);
  }
});

test("rejects non-string operands without coercion", () => {
  const invalidValues: readonly unknown[] = [
    undefined, null, 0, 1n, false, {}, [], Object("boxed"), Symbol("string"), () => "value",
    { toString: () => { throw new Error("Must not coerce"); } },
  ];
  for (const value of invalidValues) {
    assert.throws(() => compareStrings(value, "a"), TypeError);
    assert.throws(() => compareStrings("a", value), TypeError);
    assert.throws(() => compareStrings(value, value), TypeError);
  }
});

test("serializes nested object keys in code-unit order", () => {
  assert.equal(
    stableJson({ "\u00e4": 4, z: 3, a: { z: 2, Z: 1 }, Z: 0 }),
    '{\n  "Z": 0,\n  "a": {\n    "Z": 1,\n    "z": 2\n  },\n  "z": 3,\n  "\u00e4": 4\n}\n',
  );
});
