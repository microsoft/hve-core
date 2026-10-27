// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { captureInventory, installInventoryCapture } from "../scripts/native-inventory.mjs";

const pkg = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(path.join(pkg, "package.json"));
const sdkRoot = path.resolve(require.resolve("@github/copilot-sdk"), "..", "..", "..");
const sdkPackage = JSON.parse(readFileSync(path.join(sdkRoot, "package.json"), "utf8"));
const { CopilotClient } = await import(pathToFileURL(path.join(sdkRoot, sdkPackage.exports["."].import.default)));

function temporary(t) {
  const root = mkdtempSync(path.join(tmpdir(), "native-inventory-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  return root;
}

function fixture(skills = []) {
  return { sessionId: "actual-session", rpc: {
    tools: { initializeAndValidate: async () => {} },
    skills: { list: async () => ({ skills }) },
  } };
}

test("capture retains full inventory and actual session identity without judging isolation", async t => {
  const root = temporary(t);
  const skills = [
    { name: "focus", enabled: true, path: path.join(root, "focus", "SKILL.md"), source: "project", description: "Fixture" },
    { name: "ambient", enabled: false, path: path.join(root, "ambient", "SKILL.md"), source: "user" },
    { name: "unknown-path", enabled: true },
  ];
  const config = { workingDirectory: root, configDirectory: root, skillDirectories: [], enableConfigDiscovery: true };
  const file = await captureInventory(fixture(skills), config, root);
  const record = JSON.parse(readFileSync(file, "utf8"));
  assert.equal(path.basename(file), "actual-session.json");
  assert.equal(record.sessionId, "actual-session");
  assert.equal(record.phase, "before-first-prompt");
  assert.deepEqual(record.skillDetails.skills, skills);
  assert.deepEqual(record.requestedSkillDirectories, []);
  assert.equal(record.enableConfigDiscovery, true);
  assert.equal(record.passed, undefined);
  assert.equal(record.isolated, undefined);
  await assert.rejects(captureInventory(fixture([]), config, root), /EEXIST/);
  assert.equal(readFileSync(file, "utf8"), JSON.stringify(record, null, 2) + "\n");
});

test("missing inventory, failed initialization and failed persistence are explicit errors", async t => {
  const root = temporary(t);
  const invalid = fixture();
  invalid.rpc.skills.list = async () => ({});
  await assert.rejects(captureInventory(invalid, {}, root), /inventory or enabled-state missing/);
  await assert.rejects(captureInventory(fixture([{ name: "unknown" }]), {}, root), /enabled-state missing/);
  const failing = fixture();
  failing.rpc.tools.initializeAndValidate = async () => { throw new Error("initialization failed"); };
  await assert.rejects(captureInventory(failing, {}, root), /initialization failed/);
  const destination = path.join(root, "not-a-directory");
  writeFileSync(destination, "occupied");
  await assert.rejects(captureInventory(fixture(), {}, destination), /EEXIST|ENOTDIR/);
  assert.deepEqual(readdirSync(root), ["not-a-directory"]);
});

test("session ids cannot escape the inventory directory, and verified empty inventories stay empty", async t => {
  const root = temporary(t);
  const session = fixture();
  session.sessionId = "../outside";
  const file = await captureInventory(session, {}, root);
  assert.equal(path.dirname(file), root);
  assert.deepEqual(JSON.parse(readFileSync(file, "utf8")).skillDetails.skills, []);
});

test("capture hook leaves configuration, permissions, credits and resume behavior unchanged", async t => {
  const root = temporary(t);
  const originalCreate = CopilotClient.prototype.createSession;
  const originalResume = CopilotClient.prototype.resumeSession;
  const config = Object.freeze({
    workingDirectory: root, skillDirectories: [], enableConfigDiscovery: true,
    sessionLimits: Object.freeze({ maxAiCredits: 30 }),
    onPermissionRequest: () => ({ kind: "approve-once" }),
  });
  const session = fixture([{ name: "unrequested", enabled: true }]);
  let received, restore;
  CopilotClient.prototype.createSession = async function (options) { received = options; return session; };
  try {
    restore = await installInventoryCapture(pkg, root);
    const actual = await CopilotClient.prototype.createSession.call({}, config);
    assert.equal(actual, session);
    assert.equal(received, config);
    assert.equal(CopilotClient.prototype.resumeSession, originalResume);
    assert.equal(received.onPermissionRequest().kind, "approve-once");
    assert.deepEqual(received.sessionLimits, { maxAiCredits: 30 });
  } finally {
    restore?.();
    CopilotClient.prototype.createSession = originalCreate;
  }
});

test("capture failure disconnects before return and does not hide a disconnect error", async t => {
  const root = temporary(t);
  const originalCreate = CopilotClient.prototype.createSession;
  const session = fixture();
  let disconnected = 0, restore;
  session.rpc.skills.list = async () => { throw new Error("inventory RPC failed"); };
  session.disconnect = async () => { disconnected++; throw new Error("disconnect failed"); };
  CopilotClient.prototype.createSession = async () => session;
  try {
    restore = await installInventoryCapture(pkg, root);
    await assert.rejects(CopilotClient.prototype.createSession.call({}, {}), error => {
      assert.ok(error instanceof AggregateError);
      assert.match(error.errors[0].message, /inventory RPC failed/);
      assert.match(error.errors[1].message, /disconnect failed/);
      return true;
    });
    assert.equal(disconnected, 1);
    const record = JSON.parse(readFileSync(path.join(root, "actual-session.failure.json"), "utf8"));
    assert.equal(record.status, "error");
    assert.match(record.errors[0].message, /inventory RPC failed/);
    assert.match(record.errors[1].message, /disconnect failed/);
  } finally {
    restore?.();
    CopilotClient.prototype.createSession = originalCreate;
  }
});

test("inventory RPC deadlines and failed-session disconnect are bounded and clear every timer", { timeout: 3000 }, async t => {
  const timers = new Set();
  const set = globalThis.setTimeout, clear = globalThis.clearTimeout;
  t.mock.method(globalThis, "setTimeout", (...args) => {
    const timer = set(...args);
    timers.add(timer);
    return timer;
  });
  t.mock.method(globalThis, "clearTimeout", timer => {
    timers.delete(timer);
    return clear(timer);
  });
  for (const stage of ["success", "initialization", "list", "disconnect"]) {
    const root = temporary(t);
    const session = fixture();
    let disconnected = 0;
    session.disconnect = async () => {
      disconnected++;
      if (stage === "disconnect") return new Promise(() => {});
    };
    if (stage === "initialization") session.rpc.tools.initializeAndValidate = () => new Promise(() => {});
    if (stage === "list") session.rpc.skills.list = () => new Promise(() => {});
    if (stage === "disconnect") session.rpc.skills.list = async () => { throw new Error("primary inventory failure"); };
    const original = CopilotClient.prototype.createSession;
    let restore;
    CopilotClient.prototype.createSession = async () => session;
    try {
      restore = await installInventoryCapture(pkg, root, { timeoutMs: 15 });
      if (stage === "success") {
        assert.equal(await CopilotClient.prototype.createSession.call({}, {}), session);
        assert.equal(disconnected, 0);
      } else {
        await assert.rejects(CopilotClient.prototype.createSession.call({}, {}), error => {
          assert.ok(error instanceof AggregateError);
          const deadline = stage === "disconnect" ? error.errors[1] : error.errors[0];
          assert.match(deadline.message, /timed out; shutdown is unverified/);
          if (stage === "disconnect") assert.match(error.errors[0].message, /primary inventory failure/);
          return true;
        });
        assert.equal(disconnected, 1);
        assert.equal(JSON.parse(readFileSync(path.join(root, "actual-session.failure.json"), "utf8")).status, "error");
      }
      assert.equal(timers.size, 0);
    } finally {
      restore?.();
      CopilotClient.prototype.createSession = original;
    }
  }
});

test("inventory publication is complete, exclusive and cleans partial writes or publication failures", async t => {
  const root = temporary(t);
  const file = path.join(root, "actual-session.json");
  const link = fs.linkSync;
  const publication = t.mock.method(fs, "linkSync", (source, target) => {
    assert.equal(target, file);
    assert.equal(fs.existsSync(target), false);
    assert.equal(JSON.parse(readFileSync(source, "utf8")).sessionId, "actual-session");
    link(source, target);
  });
  await captureInventory(fixture(), {}, root);
  assert.equal(publication.mock.callCount(), 1);
  publication.mock.restore();
  const original = readFileSync(file, "utf8");
  await assert.rejects(captureInventory(fixture(), {}, root), /EEXIST/);
  assert.equal(readFileSync(file, "utf8"), original);
  assert.deepEqual(readdirSync(root), ["actual-session.json"]);

  const failureRoot = temporary(t);
  const write = fs.writeFileSync;
  const writing = t.mock.method(fs, "writeFileSync", (handle, bytes) => {
    write(handle, bytes.slice(0, 10));
    throw new Error("partial inventory write failed");
  });
  await assert.rejects(captureInventory(fixture(), {}, failureRoot), /partial inventory write failed/);
  writing.mock.restore();
  assert.deepEqual(readdirSync(failureRoot), []);
  t.mock.method(fs, "linkSync", () => { throw new Error("atomic publication failed"); });
  await assert.rejects(captureInventory(fixture(), {}, failureRoot), /atomic publication failed/);
  assert.deepEqual(readdirSync(failureRoot), []);
});

test("a timed-out RPC or disconnect can settle later without resuming capture or erasing failure", { timeout: 3000 }, async t => {
  for (const stage of ["list", "disconnect"]) {
    const root = temporary(t);
    const session = fixture();
    let settle, disconnected = 0;
    const pending = new Promise(resolve => { settle = resolve; });
    session.rpc.skills.list = stage === "list" ? () => pending : async () => { throw new Error("capture failed"); };
    session.disconnect = async () => {
      disconnected++;
      if (stage === "disconnect") await pending;
    };
    const original = CopilotClient.prototype.createSession;
    let restore;
    CopilotClient.prototype.createSession = async () => session;
    try {
      restore = await installInventoryCapture(pkg, root, { timeoutMs: 15 });
      await assert.rejects(CopilotClient.prototype.createSession.call({}, {}), AggregateError);
      const file = path.join(root, "actual-session.failure.json");
      const failure = readFileSync(file, "utf8");
      assert.match(failure, /shutdown is unverified/);
      assert.equal(disconnected, 1);
      settle({ skills: [] });
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(readFileSync(file, "utf8"), failure);
      assert.deepEqual(readdirSync(root), ["actual-session.failure.json"]);
    } finally {
      restore?.();
      CopilotClient.prototype.createSession = original;
    }
  }
});

test("capture, disconnect and failure-record persistence errors are retained together", async t => {
  const root = temporary(t);
  const primary = new Error("inventory RPC failed");
  const cleanup = new Error("disconnect failed");
  const persistence = new Error("failure record could not be published");
  const session = fixture();
  session.rpc.skills.list = async () => { throw primary; };
  session.disconnect = async () => { throw cleanup; };
  t.mock.method(fs, "linkSync", () => { throw persistence; });
  const original = CopilotClient.prototype.createSession;
  let restore;
  CopilotClient.prototype.createSession = async () => session;
  try {
    restore = await installInventoryCapture(pkg, root);
    await assert.rejects(CopilotClient.prototype.createSession.call({}, {}), error => {
      assert.ok(error instanceof AggregateError);
      assert.deepEqual(error.errors, [primary, cleanup, persistence]);
      for (const failure of [primary, cleanup, persistence]) assert.ok(error.message.includes(failure.message));
      return true;
    });
    assert.deepEqual(readdirSync(root), []);
  } finally {
    restore?.();
    CopilotClient.prototype.createSession = original;
  }
});

test("successful capture with failed publication stops and persists the original failure", async t => {
  const root = temporary(t);
  const link = fs.linkSync;
  const session = fixture();
  let disconnected = 0;
  session.disconnect = async () => { disconnected++; };
  t.mock.method(fs, "linkSync", (source, target) => {
    if (!target.endsWith(".failure.json")) throw new Error("snapshot publication failed");
    link(source, target);
  });
  const original = CopilotClient.prototype.createSession;
  let restore;
  CopilotClient.prototype.createSession = async () => session;
  try {
    restore = await installInventoryCapture(pkg, root);
    await assert.rejects(CopilotClient.prototype.createSession.call({}, {}), error => {
      assert.match(error.errors[0].message, /snapshot publication failed/);
      return true;
    });
    assert.equal(disconnected, 1);
    assert.deepEqual(readdirSync(root), ["actual-session.failure.json"]);
    assert.match(JSON.parse(readFileSync(path.join(root, "actual-session.failure.json"), "utf8")).errors[0].message,
      /snapshot publication failed/);
  } finally {
    restore?.();
    CopilotClient.prototype.createSession = original;
  }
});

test("the evidence variable is removed before SDK session creation and no evidence path is logged", async t => {
  const root = temporary(t);
  const previous = process.env.SKILL_EVAL_INVENTORY_DIR;
  const original = CopilotClient.prototype.createSession;
  const logged = [];
  t.mock.method(console, "log", (...args) => { logged.push(args.join(" ")); });
  const session = fixture();
  CopilotClient.prototype.createSession = async () => {
    assert.equal(process.env.SKILL_EVAL_INVENTORY_DIR, undefined);
    return session;
  };
  process.env.SKILL_EVAL_INVENTORY_DIR = root;
  let restore;
  try {
    restore = await installInventoryCapture(pkg, root);
    await CopilotClient.prototype.createSession.call({}, {});
    assert.equal(logged.some(message => message.includes(root)), false);
  } finally {
    restore?.();
    CopilotClient.prototype.createSession = original;
    if (previous === undefined) delete process.env.SKILL_EVAL_INVENTORY_DIR;
    else process.env.SKILL_EVAL_INVENTORY_DIR = previous;
  }
});

test("invalid inventory deadlines reject before RPCs and temporary-file cleanup errors remain visible", async t => {
  const root = temporary(t);
  const session = fixture();
  session.rpc.tools.initializeAndValidate = () => { throw new Error("must not initialize"); };
  for (const timeoutMs of [0, -1, Infinity, NaN, 10001, "15"]) {
    await assert.rejects(captureInventory(session, {}, root, { timeoutMs }), /Inventory timeout/);
  }
  const unlink = fs.unlinkSync;
  const cleanup = t.mock.method(fs, "unlinkSync", () => { throw new Error("temporary-file cleanup failed"); });
  await assert.rejects(captureInventory(fixture(), {}, root), /temporary-file cleanup failed/);
  cleanup.mock.restore();
  for (const name of readdirSync(root).filter(name => name.includes(".tmp-"))) unlink(path.join(root, name));
});

test("actual native executor captures both actual sessions including ambient skills before any prompt", {
  timeout: 90000,
  skip: process.env.SKILL_EFFECTIVENESS_NATIVE_PREFLIGHT !== "1"
    && "Requires explicit native runtime startup authorization and optional Copilot binary",
}, async t => {
  const root = temporary(t);
  const previousCli = process.env.COPILOT_CLI_PATH;
  process.env.COPILOT_CLI_PATH = createRequire(require.resolve("@github/copilot/package.json"))
    .resolve(`@github/copilot-${process.platform}-${process.arch}`);
  const assigned = path.join(root, "assigned");
  const ambient = path.join(root, ".github", "skills", "ambient-fixture");
  for (const [directory, name] of [[assigned, "assigned"], [ambient, "ambient-fixture"]]) {
    mkdirSync(directory, { recursive: true });
    writeFileSync(path.join(directory, "SKILL.md"), `---\nname: ${name}\ndescription: Local test fixture.\n---\nTest fixture.\n`);
  }
  const inventories = path.join(root, "inventories");
  let restore;
  try {
    restore = await installInventoryCapture(pkg, inventories, { preflight: true });
    const { CopilotSdkExecutor } = await import(pathToFileURL(path.join(pkg, "node_modules", "@microsoft", "vally", "dist", "executor", "copilot-sdk-executor.js")));
    for (const role of ["baseline", "treatment"]) {
      const executor = new CopilotSdkExecutor();
      try {
        await assert.rejects(executor.execute({ name: role, prompt: "Never sent" }, {
          workDir: root, skills: role === "baseline" ? [] : [{ path: path.join(assigned, "SKILL.md") }],
          model: "gpt-5.4", timeout: 60000,
          sessionLog: { sessionID: role, rootDir: path.join(root, `${role}-session`) },
        }), /MODEL_FREE_NATIVE_PREFLIGHT_STOP/);
        const record = JSON.parse(readFileSync(path.join(inventories, `${role}.json`), "utf8"));
        assert.equal(record.sessionId, role);
        assert.equal(record.enableConfigDiscovery, true);
        const enabled = record.skillDetails.skills.filter(skill => skill.enabled);
        assert.ok(enabled.some(skill => skill.name === "ambient-fixture"));
        assert.equal(enabled.some(skill => skill.name === "assigned"), role === "treatment");
        assert.ok(enabled.find(skill => skill.name === "ambient-fixture").path);
      } finally { await executor.shutdown(); }
    }
  } finally {
    restore?.();
    if (previousCli === undefined) delete process.env.COPILOT_CLI_PATH;
    else process.env.COPILOT_CLI_PATH = previousCli;
  }
});
