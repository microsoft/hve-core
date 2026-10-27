// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { backupInventory, backupSessionLog, captureInventory, verifyInventoryBackup } from "../scripts/native-inventory.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function temporary(t) {
  const directory = fs.mkdtempSync(path.join(tmpdir(), "skill-evidence-test-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function savedBytes(file) {
  let handle;
  try { handle = fs.openSync(file, "r"); } catch (error) {
    if (error.code !== "ENOENT") throw error;
    return null;
  }
  try { return fs.readFileSync(handle); } finally { fs.closeSync(handle); }
}

async function startup(t) {
  const directory = temporary(t);
  const session = { sessionId: "actual-session", rpc: {
    tools: { initializeAndValidate: async () => {} },
    skills: { list: async () => ({ skills: [{ name: "fixture", enabled: true }] }) },
  } };
  const file = await captureInventory(session, { workingDirectory: directory }, directory);
  const bytes = fs.readFileSync(file);
  return { directory, file, bytes, reference: backupInventory(file) };
}

test("startup backup preserves complete bytes on an independent inode and verifies against the captured digest", async t => {
  const { file, bytes, reference } = await startup(t);
  assert.ok(Object.isFrozen(reference));
  assert.deepEqual(fs.readFileSync(reference.backupFile), bytes);
  assert.notEqual(fs.statSync(file, { bigint: true }).ino, fs.statSync(reference.backupFile, { bigint: true }).ino);
  const report = verifyInventoryBackup(reference);
  assert.equal(report.status, "verified");
  assert.equal(report.originalSha256, reference.sha256);
  assert.equal(report.backupSha256, reference.sha256);
  assert.equal(report.sessionId, "actual-session");
  assert.throws(() => backupInventory(file), /EEXIST/);
  assert.throws(() => verifyInventoryBackup(reference), /EEXIST/);
  assert.deepEqual(savedBytes(file), bytes);
});

test("startup verification detects mutation or loss without overwriting either copy", async t => {
  for (const scenario of ["original-changed", "backup-changed", "both-changed", "original-deleted", "backup-deleted", "hard-linked-backup"]) {
    await t.test(scenario, async t => {
      const { directory, file, reference } = await startup(t);
      if (scenario === "original-changed" || scenario === "both-changed") fs.writeFileSync(file, "changed original");
      if (scenario === "backup-changed" || scenario === "both-changed") fs.writeFileSync(reference.backupFile, "changed original");
      if (scenario === "original-deleted") fs.unlinkSync(file);
      if (scenario === "backup-deleted") fs.unlinkSync(reference.backupFile);
      if (scenario === "hard-linked-backup") {
        fs.unlinkSync(reference.backupFile);
        fs.linkSync(file, reference.backupFile);
      }
      const before = [file, reference.backupFile].map(savedBytes);
      assert.throws(() => verifyInventoryBackup(reference), /changed|ENOENT|share the original inode/);
      const report = JSON.parse(fs.readFileSync(path.join(directory, "actual-session.verification.json")));
      assert.equal(report.status, "error");
      assert.equal(report.expectedSha256, reference.sha256);
      assert.ok(report.error.message);
      assert.deepEqual([file, reference.backupFile].map(savedBytes), before);
    });
  }
});

test("startup verification rejects a backup directory redirected through a link", async t => {
  const { directory, reference } = await startup(t);
  const external = temporary(t);
  fs.copyFileSync(reference.backupFile, path.join(external, path.basename(reference.file)));
  fs.unlinkSync(reference.backupFile);
  fs.rmdirSync(path.dirname(reference.backupFile));
  fs.symlinkSync(external, path.dirname(reference.backupFile), process.platform === "win32" ? "junction" : "dir");
  assert.throws(() => verifyInventoryBackup(reference), /symbolic links/);
  assert.equal(JSON.parse(fs.readFileSync(path.join(directory, "actual-session.verification.json"))).status, "error");
});

test("backup publication failure retains the original and removes only its own temporary file", async t => {
  const { directory, file, bytes, reference } = await startup(t);
  fs.unlinkSync(reference.backupFile);
  t.mock.method(fs, "linkSync", () => { throw new Error("backup publication denied"); });
  assert.throws(() => backupInventory(file), /backup publication denied/);
  assert.deepEqual(fs.readFileSync(file), bytes);
  assert.deepEqual(fs.readdirSync(path.join(directory, "startup-backups")), []);
});

test("verification failure and report-publication failure are both retained", async t => {
  const { file, reference } = await startup(t);
  fs.writeFileSync(file, "altered");
  t.mock.method(fs, "linkSync", () => { throw new Error("verification report denied"); });
  assert.throws(() => verifyInventoryBackup(reference), error => {
    assert.ok(error instanceof AggregateError);
    assert.match(error.errors[0].message, /Startup inventory changed/);
    assert.match(error.errors[1].message, /verification report denied/);
    return true;
  });
});

test("selected log backup is exclusive, bounded and independent of later log growth", t => {
  const directory = temporary(t);
  const source = path.join(directory, "events.jsonl"), output = path.join(directory, "backup", "events.jsonl");
  const bytes = Buffer.from('{"event":"synthetic completed session"}\n');
  fs.writeFileSync(source, bytes);
  const record = backupSessionLog(source, output);
  assert.deepEqual(fs.readFileSync(output), bytes);
  assert.equal(record.bytes, bytes.length);
  assert.equal(record.phase, "operator-selected-log-snapshot");
  assert.deepEqual(JSON.parse(fs.readFileSync(`${output}.metadata.json`)), record);
  fs.appendFileSync(source, '{"event":"later"}\n');
  assert.deepEqual(fs.readFileSync(output), bytes);
  assert.throws(() => backupSessionLog(source, output), /EEXIST/);
  fs.writeFileSync(source, "");
  assert.throws(() => backupSessionLog(source, path.join(directory, "empty-backup")), /nonempty/);
  fs.truncateSync(source, 16 * 1024 * 1024);
  const boundaryOutput = path.join(directory, "boundary-backup");
  assert.equal(backupSessionLog(source, boundaryOutput).bytes, 16 * 1024 * 1024);
  assert.deepEqual(fs.readFileSync(boundaryOutput), fs.readFileSync(source));
  fs.truncateSync(source, 16 * 1024 * 1024 + 1);
  assert.throws(() => backupSessionLog(source, path.join(directory, "oversized-backup")), /16 MiB/);
  assert.throws(() => backupSessionLog(directory, path.join(directory, "directory-backup")), /regular file|EISDIR/);
  assert.throws(() => backupSessionLog(source, "relative-output"), /absolute/);
  assert.equal(fs.existsSync(path.join(directory, "oversized-backup")), false);
  if (process.platform !== "win32") assert.equal(fs.statSync(output).mode & 0o777, 0o600);
});

test("a log that changes while reading is not published", t => {
  const directory = temporary(t);
  const source = path.join(directory, "events.jsonl"), output = path.join(directory, "snapshot");
  fs.writeFileSync(source, "synthetic log\n");
  const read = fs.readSync;
  t.mock.method(fs, "readSync", (...args) => {
    const count = read(...args);
    fs.appendFileSync(source, "changed\n");
    return count;
  });
  assert.throws(() => backupSessionLog(source, output), /changed while reading/);
  assert.equal(fs.existsSync(output), false);
});

test("evidence reads validate the opened descriptor and reject a replaced path before reading bytes", t => {
  const directory = temporary(t);
  const source = path.join(directory, "events.jsonl"), output = path.join(directory, "snapshot");
  fs.writeFileSync(source, "original bytes\n");
  const replacement = path.join(directory, "replacement.jsonl");
  fs.writeFileSync(replacement, "replacement bytes\n");
  const open = fs.openSync, read = fs.readSync;
  let descriptor, reads = 0;
  t.mock.method(fs, "openSync", (file, ...args) => {
    const handle = open(file, ...args);
    if (file === source && descriptor === undefined) {
      descriptor = handle;
      fs.renameSync(source, path.join(directory, "original.jsonl"));
      fs.copyFileSync(replacement, source, fs.constants.COPYFILE_EXCL);
    }
    return handle;
  });
  t.mock.method(fs, "readSync", (...args) => {
    if (args[0] === descriptor) reads++;
    return read(...args);
  });
  assert.throws(() => backupSessionLog(source, output), /changed before reading/);
  assert.equal(reads, 0);
  assert.throws(() => fs.fstatSync(descriptor), /EBADF/);
  assert.equal(fs.existsSync(output), false);
});

test("log CLI copies only the selected file and emits metadata, not session contents", t => {
  const directory = temporary(t);
  const source = path.join(directory, "events.jsonl"), output = path.join(directory, "saved.jsonl");
  fs.writeFileSync(source, '{"prompt":"SYNTHETIC_PRIVATE_PROMPT"}\n');
  const run = args => spawnSync(process.execPath, [path.join(root, "scripts", "native-inventory.mjs"), "backup-log", ...args], {
    encoding: "utf8", timeout: 10000,
  });
  const result = run(["--source", source, "--output", output]);
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).phase, "operator-selected-log-snapshot");
  assert.doesNotMatch(result.stdout, /SYNTHETIC_PRIVATE_PROMPT/);
  assert.deepEqual(fs.readFileSync(source), fs.readFileSync(output));
  assert.notEqual(run(["--source", source]).status, 0);
  assert.notEqual(run(["--source", source, "--output", output]).status, 0);
});

test("native factory captures before prompting and verifies after native cleanup without starting an SDK", t => {
  const directory = temporary(t);
  // Load the actual adapter with only its SDK/native dependencies replaced by inert public-contract stubs.
  const script = String.raw`
    import assert from "node:assert/strict";
    import fs from "node:fs";
    import path from "node:path";
    import { pathToFileURL } from "node:url";
    import vm from "node:vm";
    const [root, directory] = process.argv.slice(1);
    const returned = Object.freeze({ output: "unchanged native result" });
    let prompts = 0, disconnected = 0;
    class Client {
      constructor(options) { this.mode = options.connection.env.MODE; }
      async createSession(config) {
        assert.deepEqual(config.availableTools, []);
        assert.equal(config.managedSettings.permissions.disableBypassPermissionsMode, "disable");
        assert.equal(config.onPermissionRequest({ kind: "shell" }).kind, "reject");
        const mode = this.mode;
        return {
          sessionId: "actual-" + mode,
          rpc: {
            instructions: { getSources: async () => ({ sources: [] }) },
            tools: { initializeAndValidate: async () => {}, getCurrentMetadata: async () => ({ tools: [] }) },
            skills: { list: async () => {
              if (mode === "capture-error") throw new Error("startup inventory unavailable");
              if (mode === "backup-error") {
                const auditRoot = path.join(directory, mode + "-audit");
                const audit = fs.readdirSync(auditRoot).find(name => name.startsWith("skill-evidence-"));
                fs.writeFileSync(path.join(auditRoot, audit, "startup-backups"), "not a directory");
              }
              return { skills: [] };
            } },
          },
          disconnect: async () => { disconnected++; },
        };
      }
    }
    class Native {
      constructor(factories) { this.createEnvClient = factories.createEnvClient; }
      validateConfig() {}
      async execute(stimulus, options) {
        try {
          const session = await this.createEnvClient(options.env).createSession({ workingDirectory: options.workDir, skillDirectories: [] });
          assert.deepEqual(fs.readdirSync(options.workDir), []);
          const audit = fs.readdirSync(options.sessionLog.rootDir).find(name => name.startsWith("skill-evidence-"));
          const file = path.join(options.sessionLog.rootDir, audit, session.sessionId + ".json");
          const backup = path.join(options.sessionLog.rootDir, audit, "startup-backups", session.sessionId + ".json");
          assert.deepEqual(fs.readFileSync(file), fs.readFileSync(backup));
          assert.equal(JSON.parse(fs.readFileSync(file)).sessionId, session.sessionId);
          prompts++;
          if (options.env.MODE === "both-changed" || options.env.MODE === "both-errors") {
            fs.writeFileSync(file, "altered"); fs.writeFileSync(backup, "altered");
          }
          if (options.env.MODE === "native-error" || options.env.MODE === "both-errors") throw new Error("original native failure");
          return returned;
        } finally {
          fs.writeFileSync(path.join(options.workDir, "native-cleanup-finished"), "yes");
        }
      }
    }
    const module = new vm.SourceTextModule(fs.readFileSync(path.join(root, "scripts", "restricted-copilot-executor.mjs"), "utf8"), {
      initializeImportMeta(meta) { meta.url = pathToFileURL(path.join(root, "scripts", "restricted-copilot-executor.mjs")).href; },
    });
    await module.link(async specifier => {
      const exports = specifier === "@github/copilot-sdk" ? {
        CopilotClient: Client, RuntimeConnection: { forStdio: options => ({ kind: "stdio", ...options }) },
      }
        : specifier === "@microsoft/vally/executor" ? { CopilotSdkExecutor: Native }
        : await import(specifier.startsWith("./")
          ? pathToFileURL(path.join(root, "scripts", specifier.slice(2))).href : specifier);
      return new vm.SyntheticModule(Object.keys(exports), function () {
        for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
      });
    });
    await module.evaluate();
    const executor = new module.namespace.RestrictedCopilotExecutor();
    const options = mode => {
      const workDir = path.join(directory, mode); fs.mkdirSync(workDir);
      return { workDir, env: { MODE: mode }, timeout: 1000,
        sessionLog: { rootDir: path.join(directory, mode + "-audit") },
        executorConfig: { auditDirectory: path.join(directory, mode + "-audit"),
          sessionPolicy: { availableTools: [], permissions: { allow: [], deny: [] } } } };
    };
    await Promise.all(["healthy-a", "healthy-b", "native-error", "both-changed", "both-errors", "capture-error", "backup-error"].map(async mode => {
      const input = options(mode);
      if (mode.startsWith("healthy")) assert.equal(await executor.execute({}, input), returned);
      else await assert.rejects(executor.execute({}, input), error => {
        if (mode === "both-errors") {
          assert.ok(error instanceof AggregateError);
          assert.match(error.errors[0].message, /original native failure/);
          assert.match(error.errors[1].message, /Startup inventory changed/);
        } else assert.match(error.message, /original native failure|Startup inventory changed|startup inventory unavailable|EEXIST/);
        return true;
      });
      assert.ok(fs.existsSync(path.join(input.workDir, "native-cleanup-finished")));
      const audit = fs.readdirSync(input.sessionLog.rootDir).find(name => name.startsWith("skill-evidence-"));
      const reportFile = path.join(input.sessionLog.rootDir, audit, "actual-" + mode + ".verification.json");
      if (mode === "capture-error" || mode === "backup-error") assert.equal(fs.existsSync(reportFile), false);
      else {
        const report = JSON.parse(fs.readFileSync(reportFile));
        assert.equal(report.sessionId, "actual-" + mode);
        assert.equal(report.status, mode.startsWith("both-") ? "error" : "verified");
        assert.equal(fs.readdirSync(path.join(input.sessionLog.rootDir, audit)).filter(name => name.endsWith(".verification.json")).length, 1);
      }
    }));
    assert.equal(prompts, 5);
    assert.equal(disconnected, 2);
    console.log("Native factory ordering, concurrent isolation, backup/capture failures and aggregated completion failures passed.");
  `;
  const result = spawnSync(process.execPath, ["--experimental-vm-modules", "--input-type=module", "-e", script, root, directory], {
    encoding: "utf8", timeout: 15000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
