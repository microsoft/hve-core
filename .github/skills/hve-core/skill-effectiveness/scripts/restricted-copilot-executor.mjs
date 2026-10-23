// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { AsyncLocalStorage } from "node:async_hooks";
import { mkdirSync, mkdtempSync, readFileSync, realpathSync } from "node:fs";
import { createRequire, findPackageJSON } from "node:module";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import { CopilotClient, RuntimeConnection } from "@github/copilot-sdk";
import { CopilotSdkExecutor } from "@microsoft/vally/executor";
import { backupInventory, captureInventory, verifyInventoryBackup } from "./native-inventory.mjs";
import { applyWindowsSandbox, validateWindowsProfile, windowsClientOptions } from "./native-windows-sandbox.mjs";

function object(value, keys, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || ![Object.prototype, null].includes(Object.getPrototypeOf(value))
    || Object.keys(value).some(key => !keys.includes(key))) {
    throw new Error(`${label} must be an object containing only ${keys.join(", ")}`);
  }
}

function list(value, label, tools = false) {
  if (!Array.isArray(value) || Array.from(value).some(entry => typeof entry !== "string"
    || !entry.trim() || entry !== entry.trim() || (tools && /[*?]/.test(entry)))
    || new Set(value).size !== value.length) {
    throw new Error(`${label} requires distinct nonempty strings${tools ? " without wildcard tool names" : ""}`);
  }
  return Object.freeze([...value]);
}

export function validateSessionPolicy(config) {
  object(config, ["provider", "sessionPolicy", "auditDirectory", "executionProfile", "clientMode"], "executor.config");
  if (config.clientMode !== undefined && config.clientMode !== "empty") {
    throw new Error('executor.config.clientMode must be "empty" when supplied');
  }
  const policy = config.sessionPolicy;
  object(policy, ["availableTools", "permissions"], "sessionPolicy");
  object(policy.permissions, ["allow", "deny"], "sessionPolicy.permissions");
  return Object.freeze({
    availableTools: list(policy.availableTools, "sessionPolicy.availableTools", true),
    permissions: Object.freeze({
      allow: list(policy.permissions.allow, "sessionPolicy.permissions.allow"),
      deny: list(policy.permissions.deny, "sessionPolicy.permissions.deny"),
    }),
  });
}

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

export function runtimeClientOptions(env, telemetry, onGetTraceContext) {
  const childEnv = { ...env };
  for (const key of Object.keys(childEnv)) {
    if (/^(COPILOT_AGENT_SESSION_ID|COPILOT_CLI|COPILOT_CLI_RUN_AS_NODE|COPILOT_EXP_COPILOT_CLI_EXECUTION_SUBAGENT(?:_MODEL)?|NODE_OPTIONS|NODE_TEST_CONTEXT)$/i.test(key)) {
      delete childEnv[key];
    }
  }
  const require = createRequire(import.meta.url);
  const runtime = createRequire(require.resolve("@github/copilot/package.json"))
    .resolve(`@github/copilot-${process.platform}-${process.arch}`);
  return {
    connection: RuntimeConnection.forStdio({ path: runtime, env: childEnv }),
    telemetry, onGetTraceContext,
  };
}

export function verifySkillInventory(skills, directories) {
  const canonical = file => {
    const absolute = resolve(file);
    return process.platform === "win32" ? absolute.toLowerCase() : absolute;
  };
  const expected = new Set(directories.map(directory => canonical(join(directory, "SKILL.md"))));
  const enabled = skills.filter(skill => skill.enabled);
  if (enabled.length !== expected.size || enabled.some(skill =>
    typeof skill.path !== "string" || !expected.delete(canonical(skill.path))) || expected.size !== 0) {
    throw new Error("Enabled skill inventory does not match the explicitly requested skill directories");
  }
}

export function prepareAuditRoot(workDir, rootDir) {
  if (typeof workDir !== "string" || !isAbsolute(workDir)
    || typeof rootDir !== "string" || !isAbsolute(rootDir)) {
    throw new Error("Restricted execution requires an absolute workspace and executor.config.auditDirectory outside it");
  }
  const overlaps = (a, b) => {
    const within = (parent, child) => {
      const part = relative(parent, child);
      return part === "" || (!isAbsolute(part) && part !== ".." && !part.startsWith(".." + sep));
    };
    return within(a, b) || within(b, a);
  };
  if (overlaps(resolve(workDir), resolve(rootDir))) {
    throw new Error("Audit root and candidate workspace must not overlap");
  }
  mkdirSync(rootDir, { recursive: true });
  const canonicalRoot = realpathSync.native(rootDir);
  if (overlaps(realpathSync.native(workDir), canonicalRoot)) {
    throw new Error("Canonical audit root and candidate workspace must not overlap");
  }
  return canonicalRoot;
}

export function restrictedFactories(context, createClient = options => new CopilotClient(options)) {
  return {
    createClient() {
      throw new Error("restricted-copilot-sdk requires fresh environment-scoped sessions; default clients are unsupported");
    },
    createEnvClient(env, telemetry, onGetTraceContext) {
      const run = context.getStore();
      if (!run) throw new Error("restricted-copilot-sdk client creation requires an active validated execution");
      const { policy, timeoutMs } = run;
      const options = runtimeClientOptions(env, telemetry, onGetTraceContext);
      const clientOptions = run.profile ? windowsClientOptions(options) : options;
      if (run.clientMode === "empty") {
        run.runtimeStateDirectory ??= mkdtempSync(join(run.auditRoot, "runtime-state-"));
      }
      const client = createClient(run.clientMode === "empty"
        ? { ...clientOptions, mode: "empty", baseDirectory: run.runtimeStateDirectory }
        : clientOptions);
      const createSession = client.createSession.bind(client);
      client.resumeSession = async () => {
        throw new Error("restricted-copilot-sdk does not support session resume");
      };
      client.createSession = async config => {
        if (config.managedSettings !== undefined || config.availableTools !== undefined) {
          throw new Error("restricted-copilot-sdk rejects conflicting injected session restrictions");
        }
        let systemMessage = config.systemMessage;
        if (run.clientMode === "empty") {
          if (!config.workingDirectory || !isAbsolute(config.workingDirectory)) {
            throw new Error("Empty client mode requires the actual absolute working directory");
          }
          if (systemMessage?.mode === "replace" || systemMessage?.sections?.environment_context !== undefined) {
            throw new Error("Empty client mode rejects conflicting system-message environment context");
          }
          systemMessage = {
            ...systemMessage, mode: "customize",
            sections: { ...systemMessage?.sections, environment_context: { action: "replace",
              content: `Operating system: ${process.platform}\nActual working directory: ${JSON.stringify(config.workingDirectory)}\nResolve relative file paths against this directory. Do not assume /workspace or inspect enclosing directories.` } },
          };
        }
        let session;
        try {
          const appliedConfig = {
            ...config,
            ...(run.clientMode === "empty" ? { systemMessage } : {}),
            enableConfigDiscovery: false, skipCustomInstructions: true,
            enableOnDemandInstructionDiscovery: false, requestExtensions: false,
            enableFileHooks: false, enableHostGitOperations: false, enableSessionStore: false,
            enableSkills: true, includedBuiltinSkills: [],
            availableTools: [...policy.availableTools],
            managedSettings: {
              permissions: {
                allow: [...policy.permissions.allow],
                deny: [...policy.permissions.deny],
                disableBypassPermissionsMode: "disable",
              },
            },
            onPermissionRequest: () => ({ kind: "reject" }),
          };
          session = await bounded(() => createSession(appliedConfig),
            run.startupTimeoutMs ?? timeoutMs, "Restricted session creation");
          const executionProfile = run.profile
            ? await bounded(() => applyWindowsSandbox(client, session, appliedConfig, run.profile, run.auditRoot),
              timeoutMs, "Native Windows sandbox preflight")
            : null;
          await bounded(() => session.rpc.tools.initializeAndValidate(), timeoutMs, "Restricted tool initialization");
          const metadata = await bounded(() => session.rpc.tools.getCurrentMetadata(), timeoutMs, "Restricted tool inventory");
          if (!Array.isArray(metadata?.tools) || metadata.tools.some(tool => typeof tool?.name !== "string")) {
            throw new Error("Restricted tool inventory is unavailable or malformed");
          }
          const actual = metadata.tools.map(tool => tool.name);
          const directories = config.skillDirectories ?? [];
          if (directories.length > 0 && !actual.includes("skill")) {
            throw new Error("Requested skills require the native skill tool for model-facing availability");
          }
          const expectedTools = directories.length === 0 && !actual.includes("skill")
            ? policy.availableTools.filter(name => name !== "skill") : policy.availableTools;
          if (actual.length !== expectedTools.length || new Set(actual).size !== actual.length
            || actual.some(name => !expectedTools.includes(name))) {
            throw new Error("Restricted tool inventory does not match the explicit allowlist; unsupported or unexpected tools");
          }
          const instructions = await bounded(() => session.rpc.instructions.getSources(),
            timeoutMs, "Restricted instruction inventory");
          if (!Array.isArray(instructions?.sources) || instructions.sources.length !== 0) {
            throw new Error("Restricted sessions require an empty custom-instruction inventory");
          }
          if (!config.workingDirectory || !isAbsolute(config.workingDirectory)) {
            throw new Error("Startup inventory requires the actual absolute native working directory");
          }
          run.inventoryDirectory ??= mkdtempSync(join(
            prepareAuditRoot(config.workingDirectory, run.auditRoot), "skill-evidence-"));
          const file = await captureInventory(session, appliedConfig, run.inventoryDirectory, {
            timeoutMs, toolNames: actual, instructionSources: instructions.sources, executionProfile,
            clientMode: run.clientMode ?? null,
          });
          run.inventories.push(backupInventory(file));
          verifySkillInventory(JSON.parse(readFileSync(file, "utf8")).skillDetails.skills, directories);
          return session;
        } catch (error) {
          if (session) {
            try {
              await bounded(() => session.disconnect(), timeoutMs, "Restricted failed-session disconnect");
            } catch (cleanupError) {
              throw new AggregateError([error, cleanupError], "Restricted session preflight and disconnect failed; shutdown is unverified");
            }
          }
          throw error;
        }
      };
      return client;
    },
  };
}

export class RestrictedCopilotExecutor extends CopilotSdkExecutor {
  name = "restricted-copilot-sdk";
  #context;

  constructor(createClient) {
    const context = new AsyncLocalStorage();
    super(restrictedFactories(context, createClient));
    this.#context = context;
  }

  validateConfig(config) {
    validateSessionPolicy(config);
    const profile = validateWindowsProfile(config.executionProfile);
    if (profile && config.provider !== undefined) {
      throw new Error("windows-native uses normal local login; explicit provider configuration is unsupported");
    }
    super.validateConfig(config.provider === undefined ? {} : { provider: config.provider });
  }

  async execute(stimulus, options) {
    this.validateConfig(options.executorConfig);
    if (options.sessionID !== undefined) throw new Error("restricted-copilot-sdk does not support session resume");
    if (!options.env || typeof options.env !== "object" || Array.isArray(options.env)
      || Object.keys(options.env).length === 0
      || Object.values(options.env).some(value => typeof value !== "string")) {
      throw new Error("restricted-copilot-sdk requires explicit nonempty environment.env");
    }
    if (!Number.isFinite(options.timeout) || options.timeout <= 0) {
      throw new Error("restricted-copilot-sdk requires a positive finite native timeout");
    }
    const policy = validateSessionPolicy(options.executorConfig);
    const auditRoot = prepareAuditRoot(options.workDir, options.executorConfig.auditDirectory);
    const nativeConfig = options.executorConfig.provider === undefined ? {} : { provider: options.executorConfig.provider };
    const run = { policy, timeoutMs: Math.min(options.timeout, 10000),
      startupTimeoutMs: Math.min(options.timeout, 30000), auditRoot,
      profile: validateWindowsProfile(options.executorConfig.executionProfile),
      clientMode: options.executorConfig.clientMode, inventories: [] };
    return this.#context.run(run, async () => {
      let result;
      const errors = [];
      try {
        result = await super.execute(stimulus, { ...options, executorConfig: nativeConfig });
      } catch (error) {
        errors.push(error);
      }
      for (const reference of run.inventories) {
        try { verifyInventoryBackup(reference); } catch (error) { errors.push(error); }
      }
      if (errors.length === 1) throw errors[0];
      if (errors.length > 1) throw new AggregateError(errors, "Native execution and startup-evidence verification failed");
      return result;
    });
  }
}

export function registerExecutors(registry) {
  for (const [name, expected] of [
    ["@microsoft/vally", "0.19.0"], ["@github/copilot-sdk", "1.0.15"], ["@github/copilot", "1.0.89"],
  ]) {
    const actual = JSON.parse(readFileSync(findPackageJSON(name, import.meta.url), "utf8")).version;
    if (actual !== expected) {
      throw new Error(`restricted-copilot-sdk requires ${name} ${expected}; installed ${actual}. Complete exact-stack integration before use.`);
    }
  }
  registry.register(new RestrictedCopilotExecutor());
}
