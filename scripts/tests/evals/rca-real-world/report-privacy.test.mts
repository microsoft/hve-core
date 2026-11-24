// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { test } from "node:test";

import {
  reportSensitiveCategories, writeLocalReports,
} from "../../../evals/rca-real-world/report-privacy.mts";

/** Creates an ignored local report workspace; the caller owns cleanup. */
async function fixture(): Promise<string> {
  const root = join(process.cwd(), ".copilot-tracking", "evaluations", "report-privacy-tests");
  await mkdir(root, { recursive: true });
  return mkdtemp(join(root, "run-"));
}

test("masks supported categories without losing surrounding causal information", async (context) => {
  const root = await fixture();
  context.after(() => rm(root, { recursive: true, force: true }));
  const path = join(root, "report.md");
  const source = [
    "# Finding", "", "Latency increased for first@example.test, not second@example.test.",
    "Repeated: first@example.test.",
    "github_pat_abcdefghijklmnopqrstuvwxyz",
    "Bearer abcdefghijklmnopqrstuvwxyz",
    'password="private-value"',
    'Environment: {"HOME":"/home/private", "PATH":"private-search-path"}',
    "C:\\Users\\private\\data", "/home/private/data",
    "C:\\\\Users\\\\private\\\\data", "",
    "The queue saturated before the timeout.",
  ].join("\n");
  await writeLocalReports(root, [{ path, text: source }]);
  const text = await readFile(path, "utf8");
  for (const value of [
    "first@example.test", "second@example.test", "github_pat_", "Bearer ",
    "private-value", "private-search-path", "Users\\private", "/home/private",
  ]) {
    assert.ok(!text.includes(value));
  }
  assert.match(text, /Latency increased for EMAIL_[a-f0-9]{64}, not EMAIL_[a-f0-9]{64}/);
  const tokens = [...text.matchAll(/EMAIL_[a-f0-9]{64}/g)].map((match) => match[0]);
  assert.equal(tokens[0], tokens[2]);
  assert.notEqual(tokens[0], tokens[1]);
  assert.ok(text.includes("The queue saturated before the timeout."));
  assert.deepEqual(reportSensitiveCategories(text), []);
  const manifest = JSON.parse(await readFile(join(root, "report-privacy.json"), "utf8"));
  assert.equal(manifest.reports[0].originalSha256, createHash("sha256").update(source).digest("hex"));
  assert.equal(manifest.reports[0].presentationSha256, createHash("sha256").update(text).digest("hex"));
  assert.equal(await readFile(join(root, manifest.reports[0].original), "utf8"), source);
});

test("pseudonyms persist across copies and reruns but are scoped to one run", async (context) => {
  const first = await fixture();
  const second = await fixture();
  context.after(() => rm(first, { recursive: true, force: true }));
  context.after(() => rm(second, { recursive: true, force: true }));
  const reports = [
    { path: join(first, "one.md"), text: "same@example.test" },
    { path: join(first, "two.md"), text: "same@example.test" },
  ];
  await writeLocalReports(first, reports);
  const text = await readFile(reports[0]!.path, "utf8");
  const token = text.match(/EMAIL_[a-f0-9]{64}/)![0];
  assert.ok((await readFile(reports[1]!.path, "utf8")).includes(token));
  await writeLocalReports(first, reports);
  assert.equal(await readFile(reports[0]!.path, "utf8"), text);
  await writeLocalReports(second, [{ path: join(second, "one.md"), text: "same@example.test" }]);
  assert.ok(!(await readFile(join(second, "one.md"), "utf8")).includes(token));
  const changed = [{ ...reports[0]!, text: "same@example.test\nNew finding." }];
  await writeLocalReports(first, changed);
  const originalLink = text.match(/\[Full original report\]\(([^)]+)\)/)![1]!;
  assert.equal(await readFile(join(first, originalLink), "utf8"), "same@example.test");
});

test("withholds encoded sensitive lines, retaining the rest and linked original content", async (context) => {
  const root = await fixture();
  context.after(() => rm(root, { recursive: true, force: true }));
  const lines = [
    "mail=user%40example.test",
    "mail=user%2540example.test",
    "mail=user&#64;example.test",
    "mail=user&commat;example&period;test",
    "mail=user\\u0040example.test",
  ];
  const path = join(root, "report.md");
  await writeLocalReports(root, [{ path, text: [...lines, "Unaffected causal account."].join("\n") }]);
  const text = await readFile(path, "utf8");
  for (const line of lines) {
    assert.ok(!text.includes(line));
  }
  assert.match(text, /5 encoded-content lines withheld/);
  assert.ok(text.includes("Unaffected causal account."));
  assert.deepEqual(reportSensitiveCategories(text), []);
  const token = text.match(/WITHHELD_LINE_[a-f0-9]{64}/)![0];
  const value = JSON.parse(await readFile(join(root, "restricted-reports", "values", `${token}.txt`), "utf8"));
  assert.equal(value.value, lines[0]);
});

test("fails closed without overwriting existing presentations when the key is invalid", async (context) => {
  const root = await fixture();
  context.after(() => rm(root, { recursive: true, force: true }));
  const path = join(root, "report.md");
  await writeLocalReports(root, [{ path, text: "Safe previous report." }]);
  const before = await readFile(path, "utf8");
  await writeFile(join(root, "restricted-reports", "pseudonym-key"), "invalid");
  await assert.rejects(writeLocalReports(root, [{ path, text: "private@example.test" }]), /Invalid local report pseudonym key/);
  assert.equal(await readFile(path, "utf8"), before);
});

test("refuses outputs outside the local run directory", async (context) => {
  const root = await fixture();
  context.after(() => rm(root, { recursive: true, force: true }));
  await assert.rejects(
    writeLocalReports(root, [{ path: join(root, "..", "outside.md"), text: "private@example.test" }]),
    /direct children/,
  );
});

test("checks reveal targets and all copies before replacing any presentation", async (context) => {
  const root = await fixture();
  context.after(() => rm(root, { recursive: true, force: true }));
  const safePath = join(root, "report.md");
  await writeLocalReports(root, [{ path: safePath, text: "Safe previous report." }]);
  const before = await readFile(safePath, "utf8");
  const unsafePath = join(root, "private@example.test.md");
  await assert.rejects(writeLocalReports(root, [
    { path: safePath, text: "Replacement report." },
    { path: unsafePath, text: "Otherwise safe content." },
  ]), /presentation withheld: remaining categories EMAIL/);
  assert.equal(await readFile(safePath, "utf8"), before);
  await assert.rejects(readFile(unsafePath, "utf8"), { code: "ENOENT" });
});
