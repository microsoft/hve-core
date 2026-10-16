// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";

const assets = dirname(fileURLToPath(import.meta.url));
const runtime = resolve(assets, "..");
const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=", "base64");

function fixture(t) {
  const root = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  symlinkSync(join(runtime, "node_modules"), join(root, "node_modules"), process.platform === "win32" ? "junction" : "dir");
  copyFileSync(join(assets, "review-images.mjs"), join(root, "review-images.mjs"));
  writeFileSync(join(root, "request.md"), "Assess visible labels; do not infer unseen sources.");
  writeFileSync(join(root, "source.png"), png);
  const prime = join(root, "prime.mjs");
  writeFileSync(prime, `
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { registerHooks } from "node:module";
import { pathToFileURL } from "node:url";
import { CopilotClient } from "@github/copilot-sdk";
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "@github/copilot-" + process.platform + "-" + process.arch) {
      return { url: pathToFileURL(process.execPath).href, shortCircuit: true };
    }
    return nextResolve(specifier, context);
  },
});
CopilotClient.prototype.start = async () => { writeFileSync("started", "yes"); };
CopilotClient.prototype.listModels = async function() {
  assert.equal(this.options.mode, "empty");
  assert.equal(readFileSync("started", "utf8"), "yes");
  return [{ id: "mock", capabilities: { supports: { vision: process.env.CASE !== "no-vision" } } }];
};
CopilotClient.prototype.createSession = async config => {
  assert.deepEqual(config.availableTools, []);
  assert.equal(config.onPermissionRequest().kind, "reject");
  writeFileSync("session-called", "yes");
  const handlers = {};
  return {
    sessionId: "observed-session",
    on: (name, handler) => { handlers[name] = handler; },
    abort: async () => { writeFileSync("aborted", "yes"); },
    sendAndWait: async (message, timeout) => {
      assert.equal(timeout, 120000);
      assert.equal(message.prompt, readFileSync("request.md", "utf8"));
      assert.equal(message.attachments.length, 1);
      const image = message.attachments[0];
      assert.equal(image.type, "blob");
      assert.equal(image.mimeType, "image/png");
      assert.equal(image.displayName, "image-1.png");
      assert.deepEqual(Buffer.from(image.data, "base64"), readFileSync("source.png"));
      handlers["assistant.usage"]({data: {model: "observed-model", inputTokens: 12, outputTokens: 6}});
      if (process.env.CASE === "timeout") throw new Error("timeout fixture");
      if (process.env.CASE === "session-error") handlers["session.error"]({data: {message: "runtime error fixture"}});
      return {data: {content: process.env.CASE === "empty" ? "" : "Image 1: synthetic review."}};
    },
  };
};
CopilotClient.prototype.stop = async () => {
  writeFileSync("stopped", "yes");
  return process.env.CASE === "cleanup-error" ? [new Error("cleanup fixture")] : [];
};
`);
  const run = (scenario = "", image = "source.png", destination = "review") => {
    const env = { ...process.env, CASE: scenario };
    delete env.NODE_OPTIONS;
    delete env.NODE_TEST_CONTEXT;
    const result = spawnSync(process.execPath, ["--import", pathToFileURL(prime).href, "review-images.mjs",
      "mock", "request.md", destination, image], { cwd: root, env, encoding: "utf8", timeout: 15000 });
    assert.ifError(result.error);
    return result;
  };
  return { root, run, record: () => JSON.parse(readFileSync(join(root, "review", "record.json"), "utf8")) };
}

test("copied SDK reviewer attaches actual bytes and records runtime identity and evidence", t => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const record = f.record();
  assert.equal(record.status, "completed");
  assert.equal(record.sessionId, "observed-session");
  assert.equal(record.requestedModel, "mock");
  assert.equal(record.usage[0].model, "observed-model");
  assert.equal(record.usage[0].inputTokens, 12);
  assert.equal(record.hardCreditLimit, null);
  assert.equal(record.images[0].sha256, createHash("sha256").update(png).digest("hex"));
  assert.deepEqual(readFileSync(join(f.root, "review", "image-1.png")), png);
  assert.equal(existsSync(join(f.root, "stopped")), true);
});

for (const scenario of ["timeout", "empty", "session-error", "cleanup-error", "no-vision"]) {
  test(`SDK reviewer preserves ${scenario} as an explicit failure without retry`, t => {
    const f = fixture(t);
    const result = f.run(scenario);
    assert.notEqual(result.status, 0);
    assert.equal(f.record().status, "error");
    assert.ok(f.record().errors.length > 0);
    assert.equal(existsSync(join(f.root, "stopped")), true);
    if (scenario === "no-vision") assert.equal(existsSync(join(f.root, "session-called")), false);
    if (["timeout", "empty", "session-error"].includes(scenario)) {
      assert.equal(existsSync(join(f.root, "aborted")), true);
    }
  });
}

test("missing/unsupported images and existing output directories fail before a session", t => {
  const f = fixture(t);
  for (const image of ["missing.png", "request.md"]) assert.notEqual(f.run("", image).status, 0);
  mkdirSync(join(f.root, "review"));
  writeFileSync(join(f.root, "review", "keep.txt"), "preserve");
  assert.notEqual(f.run().status, 0);
  assert.equal(readFileSync(join(f.root, "review", "keep.txt"), "utf8"), "preserve");
  assert.equal(existsSync(join(f.root, "session-called")), false);
});
