// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export async function captureInventory(session, config, directory) {
  assert.ok(typeof session.sessionId === "string" && session.sessionId.length > 0, "Session ID required for inventory capture");
  await session.rpc.tools.initializeAndValidate();
  const inventory = await session.rpc.skills.list();
  assert.ok(Array.isArray(inventory.skills) && inventory.skills.every(skill =>
    typeof skill?.name === "string" && typeof skill.enabled === "boolean"),
  "Runtime skill inventory or enabled-state missing");
  mkdirSync(directory, { recursive: true });
  const file = path.join(directory, `${encodeURIComponent(session.sessionId)}.json`);
  writeFileSync(file, JSON.stringify({
    at: new Date().toISOString(), sessionId: session.sessionId, phase: "before-first-prompt",
    workingDirectory: config.workingDirectory ?? null,
    configDirectory: config.configDirectory ?? null,
    requestedSkillDirectories: config.skillDirectories ?? [],
    enableConfigDiscovery: config.enableConfigDiscovery ?? null,
    skillDetails: inventory,
    limitation: "Startup inventory only. No isolation enforcement, later-context guarantee, or spending control.",
  }, null, 2) + "\n", { flag: "wx" });
  return file;
}

// Native persisted history can omit the transient skill inventory.
export async function installInventoryCapture(packageRoot, directory, { preflight = false } = {}) {
  mkdirSync(directory, { recursive: true });
  const runtime = path.join(packageRoot, "node_modules", "@microsoft", "vally");
  assert.equal(JSON.parse(readFileSync(path.join(runtime, "package.json"), "utf8")).version, "0.17.0");
  const require = createRequire(path.join(runtime, "package.json"));
  const sdkRoot = path.resolve(require.resolve("@github/copilot-sdk"), "..", "..", "..");
  const sdkPackage = JSON.parse(readFileSync(path.join(sdkRoot, "package.json"), "utf8"));
  assert.equal(sdkPackage.name, "@github/copilot-sdk");
  assert.equal(sdkPackage.version, "1.0.14");
  const { CopilotClient } = await import(pathToFileURL(path.resolve(sdkRoot, sdkPackage.exports["."].import.default)));
  const createSession = CopilotClient.prototype.createSession;
  CopilotClient.prototype.createSession = async function (config) {
    const session = await createSession.call(this, config);
    try {
      const file = await captureInventory(session, config, directory);
      console.log("NATIVE_SESSION_INVENTORY", session.sessionId, file);
      if (preflight) throw new Error("MODEL_FREE_NATIVE_PREFLIGHT_STOP");
      return session;
    } catch (error) {
      const failure = new Error(`Native session inventory capture stopped session ${session.sessionId}: ${error.message}`, { cause: error });
      try { await session.disconnect(); } catch (cleanupError) {
        throw new AggregateError([failure, cleanupError], `${failure.message}; disconnect failed: ${cleanupError.message}`);
      }
      throw failure;
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
  assert.ok(directory && path.isAbsolute(directory), "SKILL_EVAL_INVENTORY_DIR must be an absolute evidence directory");
  const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  await installInventoryCapture(packageRoot, directory);
}
