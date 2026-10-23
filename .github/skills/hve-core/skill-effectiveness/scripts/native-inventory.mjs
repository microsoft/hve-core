// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

async function bounded(operation, timeoutMs, label) {
  let timer;
  try {
    return await Promise.race([
      Promise.resolve().then(operation),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`${label} timed out; shutdown is unverified`)), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

function persist(file, record) {
  publish(file, Buffer.from(JSON.stringify(record, null, 2) + "\n"));
}

function publish(file, bytes) {
  const directory = path.dirname(file);
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  assert.equal(normalizePath(fs.realpathSync(directory)), normalizePath(path.resolve(directory)),
    "Evidence destination must not traverse symbolic links");
  const temporary = `${file}.tmp-${randomUUID()}`;
  let created = false, handle, failure;
  try {
    handle = fs.openSync(temporary, "wx", 0o600);
    created = true;
    fs.writeFileSync(handle, bytes);
    fs.closeSync(handle);
    handle = undefined;
    // Publish complete bytes without replacing an existing session record.
    fs.linkSync(temporary, file);
  } catch (error) {
    failure = error;
  }
  if (handle !== undefined) {
    try { fs.closeSync(handle); } catch (error) {
      failure = new AggregateError([failure, error], "Inventory persistence and file close failed");
    }
  }
  if (created) {
    try { fs.unlinkSync(temporary); } catch (error) {
      failure = failure ? new AggregateError([failure, error], "Inventory publication and temporary-file cleanup failed") : error;
    }
  }
  if (failure) throw failure;
}

function normalizePath(file) {
  return process.platform === "win32" ? file.toLowerCase() : file;
}

const digest = bytes => createHash("sha256").update(bytes).digest("hex");
const maxEvidenceBytes = 16 * 1024 * 1024;
const sameFile = (a, b) => a.dev === b.dev && a.ino === b.ino
  && a.size === b.size && a.mtimeNs === b.mtimeNs;

function readEvidence(file) {
  assert.ok(path.isAbsolute(file), "Evidence file must be absolute");
  const handle = fs.openSync(file, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW ?? 0) | (fs.constants.O_NONBLOCK ?? 0));
  let bytes, before, failure;
  try {
    before = fs.fstatSync(handle, { bigint: true });
    assert.ok(before.isFile() && before.ino > 0n, "Evidence must be a regular file with supported identity");
    assert.ok(before.size > 0n && before.size <= BigInt(maxEvidenceBytes),
      "Evidence must be nonempty and at most 16 MiB");
    assert.equal(normalizePath(fs.realpathSync(file)), normalizePath(path.resolve(file)),
      "Evidence must not traverse symbolic links");
    assert.ok(sameFile(before, fs.lstatSync(file, { bigint: true })), "Evidence changed before reading");
    bytes = Buffer.alloc(Number(before.size));
    let offset = 0;
    while (offset < bytes.length) {
      const count = fs.readSync(handle, bytes, offset, bytes.length - offset, null);
      assert.ok(count > 0, "Evidence truncated while reading");
      offset += count;
    }
    assert.ok(sameFile(before, fs.fstatSync(handle, { bigint: true })) && sameFile(before, fs.lstatSync(file, { bigint: true })),
      "Evidence changed while reading");
  } catch (error) {
    failure = error;
  }
  try { fs.closeSync(handle); } catch (error) {
    failure = failure ? new AggregateError([failure, error], "Evidence read and file close failed") : error;
  }
  if (failure) throw failure;
  return { bytes, stat: before };
}

export function backupInventory(file) {
  const { bytes } = readEvidence(file);
  const record = JSON.parse(bytes);
  assert.ok(typeof record.sessionId === "string" && record.sessionId.length > 0
    && record.phase === "before-first-prompt"
    && path.basename(file) === `${encodeURIComponent(record.sessionId)}.json`,
  "Startup inventory identity or phase is invalid");
  const backupFile = path.join(path.dirname(file), "startup-backups", path.basename(file));
  publish(backupFile, bytes);
  return Object.freeze({ file, backupFile, sessionId: record.sessionId, sha256: digest(bytes) });
}

export function verifyInventoryBackup(reference) {
  const report = {
    at: new Date().toISOString(), phase: "after-native-execution",
    sessionId: reference.sessionId, expectedSha256: reference.sha256,
    original: path.basename(reference.file),
    backup: path.join("startup-backups", path.basename(reference.backupFile)),
    status: "error",
    limitation: "Supervised consistency only; not an independent host audit or tamper-proof store.",
  };
  let failure;
  try {
    const original = readEvidence(reference.file);
    const backup = readEvidence(reference.backupFile);
    assert.ok(original.stat.dev !== backup.stat.dev || original.stat.ino !== backup.stat.ino,
      "Inventory backup must not share the original inode");
    report.originalSha256 = digest(original.bytes);
    report.backupSha256 = digest(backup.bytes);
    assert.equal(report.originalSha256, reference.sha256, "Startup inventory changed");
    assert.equal(report.backupSha256, reference.sha256, "Startup inventory backup changed");
    report.status = "verified";
  } catch (error) {
    failure = error;
    report.error = errorRecord(error);
  }
  try {
    persist(path.join(path.dirname(reference.file),
      `${encodeURIComponent(reference.sessionId)}.verification.json`), report);
  } catch (error) {
    failure = failure ? new AggregateError([failure, error], "Inventory verification and report publication failed") : error;
  }
  if (failure) throw failure;
  return report;
}

export function backupSessionLog(source, output) {
  assert.ok(path.isAbsolute(output), "Log backup output must be absolute");
  const { bytes } = readEvidence(source);
  const record = {
    at: new Date().toISOString(), phase: "operator-selected-log-snapshot",
    source, bytes: bytes.length, sha256: digest(bytes),
    limitation: "Selected file snapshot only; not complete session history, redacted content or startup attestation.",
  };
  publish(output, bytes);
  persist(`${output}.metadata.json`, record);
  return record;
}

function errorRecord(error) {
  return {
    name: error?.name ?? "Error",
    message: error?.message ?? String(error),
    ...(error instanceof AggregateError ? { errors: error.errors.map(errorRecord) } : {}),
    ...(error?.cause ? { cause: errorRecord(error.cause) } : {}),
  };
}

function validateTimeout(timeoutMs) {
  assert.ok(Number.isFinite(timeoutMs) && timeoutMs > 0 && timeoutMs <= 10000,
    "Inventory timeout must be positive and at most 10000ms");
}

function scrubInventoryEnvironment() {
  for (const key of Object.keys(process.env)) {
    if (key.toUpperCase() === "SKILL_EVAL_INVENTORY_DIR") delete process.env[key];
  }
}

export async function captureInventory(session, config, directory, {
  timeoutMs = 10000, toolNames = null, instructionSources = null, executionProfile = null,
  clientMode = null,
} = {}) {
  validateTimeout(timeoutMs);
  assert.ok(typeof session.sessionId === "string" && session.sessionId.length > 0, "Session ID required for inventory capture");
  await bounded(() => session.rpc.tools.initializeAndValidate(), timeoutMs, "Inventory initialization");
  const inventory = await bounded(() => session.rpc.skills.list(), timeoutMs, "Inventory skill list");
  assert.ok(Array.isArray(inventory.skills) && inventory.skills.every(skill =>
    typeof skill?.name === "string" && typeof skill.enabled === "boolean"),
  "Runtime skill inventory or enabled-state missing");
  const file = path.join(directory, `${encodeURIComponent(session.sessionId)}.json`);
  persist(file, {
    at: new Date().toISOString(), sessionId: session.sessionId, phase: "before-first-prompt",
    workingDirectory: config.workingDirectory ?? null,
    configDirectory: config.configDirectory ?? null,
    requestedSkillDirectories: config.skillDirectories ?? [],
    enableConfigDiscovery: config.enableConfigDiscovery ?? null,
    skipCustomInstructions: config.skipCustomInstructions ?? null,
    enableOnDemandInstructionDiscovery: config.enableOnDemandInstructionDiscovery ?? null,
    enableSessionStore: config.enableSessionStore ?? null,
    requestedTools: config.availableTools ?? null,
    actualTools: toolNames,
    instructionSources,
    clientMode,
    executionProfile,
    skillDetails: inventory,
    limitation: "Diagnostic startup inventory only. Not tamper-proof or isolation enforcement; no later-context guarantee or spending control.",
  });
  return file;
}

// Native persisted history can omit the transient skill inventory.
export async function installInventoryCapture(packageRoot, directory, { preflight = false, timeoutMs = 10000 } = {}) {
  scrubInventoryEnvironment();
  validateTimeout(timeoutMs);
  assert.ok(directory && path.isAbsolute(directory), "Inventory evidence directory must be absolute");
  fs.mkdirSync(directory, { recursive: true });
  const runtime = path.join(packageRoot, "node_modules", "@microsoft", "vally");
  assert.equal(JSON.parse(fs.readFileSync(path.join(runtime, "package.json"), "utf8")).version, "0.19.0");
  const require = createRequire(path.join(runtime, "package.json"));
  const sdkRoot = path.resolve(require.resolve("@github/copilot-sdk"), "..", "..", "..");
  const sdkPackage = JSON.parse(fs.readFileSync(path.join(sdkRoot, "package.json"), "utf8"));
  assert.equal(sdkPackage.name, "@github/copilot-sdk");
  assert.equal(sdkPackage.version, "1.0.15");
  const { CopilotClient } = await import(pathToFileURL(path.resolve(sdkRoot, sdkPackage.exports["."].import.default)));
  const createSession = CopilotClient.prototype.createSession;
  CopilotClient.prototype.createSession = async function (config) {
    const session = await createSession.call(this, config);
    try {
      await captureInventory(session, config, directory, { timeoutMs });
      if (preflight) throw new Error("MODEL_FREE_NATIVE_PREFLIGHT_STOP");
      return session;
    } catch (error) {
      const errors = [error];
      try { await bounded(() => session.disconnect(), timeoutMs, "Inventory failed-session disconnect"); } catch (cleanupError) {
        errors.push(cleanupError);
      }
      try {
        persist(path.join(directory, `${encodeURIComponent(session.sessionId)}.failure.json`), {
          at: new Date().toISOString(), sessionId: session.sessionId, phase: "before-first-prompt",
          status: "error", errors: errors.map(errorRecord),
          limitation: "Diagnostic failure record only; shutdown and evidence protection are unverified.",
        });
      } catch (persistenceError) {
        errors.push(persistenceError);
      }
      throw new AggregateError(errors,
        `Native inventory capture stopped before prompting: ${errors.map(error => error?.message ?? String(error)).join("; ")}`);
    }
  };
  return () => { CopilotClient.prototype.createSession = createSession; };
}

const preloaded = process.execArgv.some((argument, index) => {
  const entry = argument === "--import" ? process.execArgv[index + 1]
    : argument.startsWith("--import=") ? argument.slice("--import=".length) : null;
  return entry && (entry === import.meta.url || pathToFileURL(path.resolve(entry)).href === import.meta.url);
});
if (preloaded) {
  const directory = process.env.SKILL_EVAL_INVENTORY_DIR;
  scrubInventoryEnvironment();
  assert.ok(directory && path.isAbsolute(directory), "SKILL_EVAL_INVENTORY_DIR must be an absolute evidence directory");
  const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  await installInventoryCapture(packageRoot, directory);
} else if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  assert.equal(process.argv[2], "backup-log", "Usage: native-inventory.mjs backup-log --source <absolute-file> --output <new-absolute-file>");
  const { values } = parseArgs({
    args: process.argv.slice(3), strict: true, allowPositionals: false,
    options: { source: { type: "string" }, output: { type: "string" } },
  });
  assert.ok(values.source && values.output, "Log backup requires --source and --output");
  console.log(JSON.stringify(backupSessionLog(values.source, values.output)));
}
