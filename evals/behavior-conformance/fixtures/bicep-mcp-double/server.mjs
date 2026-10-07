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
  "get_az_resource_type_schema",
  "list_az_resource_types_for_provider",
  "get_bicep_best_practices",
  "get_bicep_file_diagnostics",
];

// The double never compiles; compile evidence comes only from the real Bicep CLI.
const DIAGNOSTICS_NOT_PROVIDED = {
  isError: true,
  code: "diagnostics_not_provided",
  message: "The synthetic Bicep double does not compile files. Run bicep build for diagnostics.",
};

// Only this resource type has synthetic schema data; other types get a deterministic error.
const DESCRIBED_RESOURCE_TYPE = "Microsoft.Storage/storageAccounts";

const TYPE_NOT_DESCRIBED = {
  isError: true,
  code: "resource_type_not_described",
  message: "The synthetic Bicep double has no schema data for this resource type.",
};

const inputSchema = fromJsonSchema({
  type: "object",
  additionalProperties: true,
});

function denyNetwork() {
  const blocked = () => {
    throw new Error("Network access is disabled for the synthetic Bicep MCP double.");
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
  const scenarioName = process.env.BICEP_MCP_SCENARIO ?? "success";
  const scenario = scenarios[scenarioName];
  if (!scenario) {
    throw new Error(`Unknown BICEP_MCP_SCENARIO: ${scenarioName}`);
  }
  return { scenarioName, scenario };
}

function successResult(toolName, args, scenarioName, configuredResult) {
  const result = {
    synthetic: true,
    scenario: scenarioName,
    tool: toolName,
    request: args,
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

function resolveResult(toolName, args, scenarioName, scenario) {
  if (toolName === "get_bicep_file_diagnostics") {
    return errorResult(toolName, DIAGNOSTICS_NOT_PROVIDED, scenarioName);
  }

  const configured = scenario[toolName];
  if (configured?.isError) {
    return errorResult(toolName, configured, scenarioName);
  }

  if (
    toolName === "get_az_resource_type_schema" &&
    String(args?.azResourceType ?? "").toLowerCase() !== DESCRIBED_RESOURCE_TYPE.toLowerCase()
  ) {
    return errorResult(toolName, TYPE_NOT_DESCRIBED, scenarioName);
  }

  if (
    toolName === "list_az_resource_types_for_provider" &&
    args?.providerNamespace !== undefined &&
    String(args.providerNamespace).toLowerCase() !== "microsoft.storage"
  ) {
    return successResult(toolName, args, scenarioName, {
      providerNamespace: args.providerNamespace,
      resourceTypes: [],
    });
  }

  return successResult(toolName, args, scenarioName, configured?.result);
}

function createServer() {
  const { scenarioName, scenario } = loadScenario();
  const server = new McpServer({
    name: "synthetic-bicep",
    version: "1.0.0",
  });

  for (const toolName of TOOL_NAMES) {
    server.registerTool(
      toolName,
      {
        description: `Synthetic protocol response for ${toolName}.`,
        inputSchema,
      },
      async (args) => resolveResult(toolName, args, scenarioName, scenario),
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
