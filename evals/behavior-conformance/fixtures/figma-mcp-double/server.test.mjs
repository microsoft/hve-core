// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import readline from "node:readline";
import test from "node:test";
import { fileURLToPath } from "node:url";

const SERVER_PATH = fileURLToPath(new URL("./server.mjs", import.meta.url));
const EXPECTED_TOOLS = [
  "create_new_file",
  "generate_diagram",
  "get_figjam",
  "get_metadata",
  "use_figma",
  "whoami",
];

function startServer(scenario = "success") {
  const child = spawn(process.execPath, [SERVER_PATH], {
    env: { ...process.env, FIGMA_MCP_SCENARIO: scenario },
    stdio: ["pipe", "pipe", "pipe"],
  });
  const lines = readline.createInterface({ input: child.stdout });
  const pending = new Map();
  const protocolLines = [];
  let stderr = "";

  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });
  lines.on("line", (line) => {
    protocolLines.push(line);
    const message = JSON.parse(line);
    if (message.id !== undefined && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    }
  });

  let requestId = 0;
  function send(method, params, notification = false) {
    const message = { jsonrpc: "2.0", method };
    if (params !== undefined) {
      message.params = params;
    }
    if (notification) {
      child.stdin.write(`${JSON.stringify(message)}\n`);
      return Promise.resolve();
    }

    requestId += 1;
    message.id = requestId;
    const response = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        pending.delete(requestId);
        reject(new Error(`Timed out waiting for ${method}. stderr: ${stderr}`));
      }, 15000);
      pending.set(requestId, (value) => {
        clearTimeout(timeout);
        resolve(value);
      });
    });
    child.stdin.write(`${JSON.stringify(message)}\n`);
    return response;
  }

  async function initialize() {
    const response = await send("initialize", {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "synthetic-protocol-test", version: "1.0.0" },
    });
    assert.equal(response.result.serverInfo.name, "synthetic-figma");
    await send("notifications/initialized", undefined, true);
  }

  async function close() {
    child.stdin.end();
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        child.kill();
        reject(new Error("Synthetic Figma MCP server did not exit."));
      }, 15000);
      child.once("exit", (code) => {
        clearTimeout(timeout);
        assert.equal(code, 0);
        resolve();
      });
    });
    lines.close();
  }

  return {
    close,
    initialize,
    protocolLines,
    send,
    stderr: () => stderr,
  };
}

test("lists exactly six Figma protocol tools and returns a synthetic success", async () => {
  const server = startServer();
  await server.initialize();

  const listed = await server.send("tools/list", {});
  assert.deepEqual(
    listed.result.tools.map((tool) => tool.name).sort(),
    EXPECTED_TOOLS,
  );

  const called = await server.send("tools/call", {
    name: "create_new_file",
    arguments: { title: "Synthetic Renewal Board" },
  });
  const payload = JSON.parse(called.result.content[0].text);
  assert.equal(payload.synthetic, true);
  assert.equal(payload.url, "https://example.invalid/figma/synthetic-file-001");

  await server.close();
  assert.match(server.stderr(), /network-denied: startup self-probe blocked/);
  assert.equal(server.protocolLines.every((line) => JSON.parse(line)), true);
});

test("returns a deterministic MCP tool error for placement failure", async () => {
  const server = startServer("placement-failure");
  await server.initialize();

  const first = await server.send("tools/call", {
    name: "use_figma",
    arguments: { fileId: "synthetic-file-001" },
  });
  const second = await server.send("tools/call", {
    name: "use_figma",
    arguments: { fileId: "synthetic-file-002" },
  });
  const payload = JSON.parse(second.result.content[0].text);
  assert.equal(first.result.isError, undefined);
  assert.equal(second.result.isError, true);
  assert.equal(payload.code, "placement_failed");

  await server.close();
  assert.match(server.stderr(), /network-denied: startup self-probe blocked/);
});