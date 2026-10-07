// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import readline from "node:readline";
import test from "node:test";
import { fileURLToPath } from "node:url";

const SERVER_PATH = fileURLToPath(new URL("./server.mjs", import.meta.url));
const EXPECTED_TOOLS = [
  "get_az_resource_type_schema",
  "get_bicep_best_practices",
  "get_bicep_file_diagnostics",
  "list_az_resource_types_for_provider",
];

function startServer(scenario = "success") {
  const child = spawn(process.execPath, [SERVER_PATH], {
    env: { ...process.env, BICEP_MCP_SCENARIO: scenario },
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
    assert.equal(response.result.serverInfo.name, "synthetic-bicep");
    await send("notifications/initialized", undefined, true);
  }

  async function close() {
    child.stdin.end();
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        child.kill();
        reject(new Error("Synthetic Bicep MCP server did not exit."));
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

function payloadOf(response) {
  return JSON.parse(response.result.content[0].text);
}

test("lists four Bicep tools and returns synthetic Storage data only for Storage types", async () => {
  const server = startServer();
  await server.initialize();

  const listed = await server.send("tools/list", {});
  assert.deepEqual(
    listed.result.tools.map((tool) => tool.name).sort(),
    EXPECTED_TOOLS,
  );

  const types = await server.send("tools/call", {
    name: "list_az_resource_types_for_provider",
    arguments: { providerNamespace: "Microsoft.Storage" },
  });
  const typesPayload = payloadOf(types);
  assert.equal(types.result.isError, undefined);
  assert.equal(typesPayload.synthetic, true);
  assert.deepEqual(typesPayload.resourceTypes[0].apiVersions, ["2025-06-01", "2023-05-01"]);
  assert.equal(typesPayload.resourceTypes[0].latestStableApiVersion, "2025-06-01");

  const schema = await server.send("tools/call", {
    name: "get_az_resource_type_schema",
    arguments: {
      azResourceType: "Microsoft.Storage/storageAccounts",
      apiVersion: "2025-06-01",
    },
  });
  assert.equal(schema.result.isError, undefined);
  assert.equal(payloadOf(schema).schema.type, "object");

  const otherType = await server.send("tools/call", {
    name: "get_az_resource_type_schema",
    arguments: {
      azResourceType: "Microsoft.Resources/deploymentScripts",
      apiVersion: "2023-08-01",
    },
  });
  assert.equal(otherType.result.isError, true);
  assert.equal(payloadOf(otherType).code, "resource_type_not_described");

  const otherProvider = await server.send("tools/call", {
    name: "list_az_resource_types_for_provider",
    arguments: { providerNamespace: "Microsoft.Resources" },
  });
  assert.deepEqual(payloadOf(otherProvider).resourceTypes, []);

  await server.close();
  assert.match(server.stderr(), /network-denied: startup self-probe blocked/);
  assert.equal(server.protocolLines.every((line) => JSON.parse(line)), true);
});

test("returns deterministic schema_unavailable errors for schema tools", async () => {
  const server = startServer("schema-unavailable");
  await server.initialize();

  for (const name of ["list_az_resource_types_for_provider", "get_az_resource_type_schema"]) {
    const response = await server.send("tools/call", {
      name,
      arguments: { providerNamespace: "Microsoft.Storage" },
    });
    assert.equal(response.result.isError, true);
    assert.equal(payloadOf(response).code, "schema_unavailable");
  }

  const practices = await server.send("tools/call", {
    name: "get_bicep_best_practices",
    arguments: {},
  });
  assert.equal(practices.result.isError, undefined);

  await server.close();
  assert.match(server.stderr(), /network-denied: startup self-probe blocked/);
});

test("never provides compile diagnostics in any scenario", async () => {
  for (const scenario of ["success", "schema-unavailable"]) {
    const server = startServer(scenario);
    await server.initialize();

    const response = await server.send("tools/call", {
      name: "get_bicep_file_diagnostics",
      arguments: { filePath: "infra/main.bicep" },
    });
    assert.equal(response.result.isError, true);
    assert.equal(payloadOf(response).code, "diagnostics_not_provided");

    await server.close();
  }
});
