#!/usr/bin/env node
// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from "node:fs";
import http from "node:http";
import https from "node:https";
import net from "node:net";

import { fromJsonSchema, McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";

const TOOL_NAMES = [
  "whoami",
  "create_new_file",
  "get_figjam",
  "get_metadata",
  "generate_diagram",
  "use_figma",
];

const inputSchema = fromJsonSchema({
  type: "object",
  additionalProperties: true,
});

function denyNetwork() {
  const blocked = () => {
    throw new Error("Network access is disabled for the synthetic Figma MCP double.");
  };

  globalThis.fetch = blocked;
  net.connect = blocked;
  net.createConnection = blocked;
  net.Socket.prototype.connect = blocked;
  http.get = blocked;
  http.request = blocked;
  https.get = blocked;
  https.request = blocked;

  try {
    net.connect({ host: "example.invalid", port: 443 });
    throw new Error("Network denial self-probe unexpectedly succeeded.");
  } catch (error) {
    if (!String(error.message).startsWith("Network access is disabled")) {
      throw error;
    }
    process.stderr.write("network-denied: startup self-probe blocked\n");
  }
}

function loadScenario() {
  const scenarios = JSON.parse(
    fs.readFileSync(new URL("./scenarios.json", import.meta.url), "utf8"),
  );
  const scenarioName = process.env.FIGMA_MCP_SCENARIO ?? "success";
  const scenario = scenarios[scenarioName];
  if (!scenario) {
    throw new Error(`Unknown FIGMA_MCP_SCENARIO: ${scenarioName}`);
  }
  return { scenarioName, scenario };
}

function successResult(toolName, args, scenarioName, configuredResult) {
  const result = {
    synthetic: true,
    scenario: scenarioName,
    tool: toolName,
    request: args,
    fileId: "synthetic-file-001",
    url: "https://example.invalid/figma/synthetic-file-001",
    ...configuredResult,
  };
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
  };
}

function errorResult(toolName, configuredError, scenarioName) {
  const result = {
    synthetic: true,
    scenario: scenarioName,
    tool: toolName,
    code: configuredError.code,
    message: configuredError.message,
  };
  return {
    content: [{ type: "text", text: JSON.stringify(result) }],
    isError: true,
  };
}

function createServer() {
  const { scenarioName, scenario } = loadScenario();
  const callCounts = new Map();
  const server = new McpServer({
    name: "synthetic-figma",
    version: "1.0.0",
  });

  for (const toolName of TOOL_NAMES) {
    server.registerTool(
      toolName,
      {
        description: `Synthetic protocol response for ${toolName}.`,
        inputSchema,
      },
      async (args) => {
        const configured = scenario[toolName];
        const callCount = (callCounts.get(toolName) ?? 0) + 1;
        callCounts.set(toolName, callCount);
        const shouldFail = configured?.isError &&
          (!configured.failOnCall || configured.failOnCall === callCount);
        return shouldFail
          ? errorResult(toolName, configured, scenarioName)
          : successResult(toolName, args, scenarioName, configured?.result);
      },
    );
  }

  return server;
}

denyNetwork();
serveStdio(createServer, {
  onerror(error) {
    process.stderr.write(`mcp-error: ${error.message}\n`);
  },
});