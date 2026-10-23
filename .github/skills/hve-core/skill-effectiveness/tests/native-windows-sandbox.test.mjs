// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { createServer } from "node:net";
import test from "node:test";
import { RestrictedCopilotExecutor } from "../scripts/restricted-copilot-executor.mjs";
import { applyWindowsSandbox, validateWindowsProfile, windowsClientOptions } from "../scripts/native-windows-sandbox.mjs";

const profile = () => ({ name: "windows-native", readonlyPaths: [], deniedPaths: [] });
const support = () => ({ supported: true,
  capabilities: ["shell", "denied_paths", "network"].map(name => ({ name, supported: true })) });

test("native profile is opt-in, exact, immutable and does not accept provider configuration", () => {
  assert.equal(validateWindowsProfile(undefined), undefined);
  const input = profile();
  const validated = validateWindowsProfile(input);
  assert.deepEqual(validated, input);
  assert.throws(() => validated.readonlyPaths.push(resolve("other")), TypeError);
  for (const value of [null, [], {}, { ...input, name: "other" }, { ...input, enabled: true },
    { ...input, readonlyPaths: ["relative"] }, { ...input, readonlyPaths: Array(1) },
    { ...input, deniedPaths: [resolve("x"), resolve("x")] }]) {
    assert.throws(() => validateWindowsProfile(value));
  }
  const executor = new RestrictedCopilotExecutor();
  assert.throws(() => executor.validateConfig({ executionProfile: input, provider: {},
    sessionPolicy: { availableTools: [], permissions: { allow: [], deny: [] } } }), /explicit provider/);
});

test("native child environment excludes credentials while ordinary provider profile remains separate", {
  skip: process.platform !== "win32",
}, () => {
  const env = Object.freeze({ PATH: "synthetic-path", COPILOT_HOME: "synthetic-home",
    COPILOT_SDK_AUTH_TOKEN: "SYNTHETIC", copilot_github_token: "SYNTHETIC",
    GH_TOKEN: "SYNTHETIC", GITHUB_TOKEN: "SYNTHETIC", GITHUB_COPILOT_API_TOKEN: "SYNTHETIC",
    GH_ENTERPRISE_TOKEN: "SYNTHETIC", COPILOT_PROVIDER_API_KEY: "SYNTHETIC",
    PSModulePath: "synthetic-parent-powershell-modules" });
  const options = windowsClientOptions({ connection: { kind: "stdio", path: "pinned-runtime", env } });
  assert.deepEqual(options.connection.env, { PATH: "synthetic-path", COPILOT_HOME: "synthetic-home" });
  assert.equal(options.useLoggedInUser, true);
  assert.equal(env.COPILOT_SDK_AUTH_TOKEN, "SYNTHETIC");
  assert.throws(() => windowsClientOptions({ gitHubToken: "SYNTHETIC" }), /Client-level token/);
  assert.throws(() => windowsClientOptions({ connection: { kind: "uri" } }), /stdio/);
});

test("native policy fixes authentication, bypass and network limits and records applied configuration", async () => {
  let applied;
  const work = resolve("synthetic-work"), audit = resolve("synthetic-audit");
  const client = { rpc: { sandbox: { getHostSupport: async () => support() } } };
  const session = { rpc: {
    options: { update: async value => { applied = value; return { success: true }; } },
    sandbox: { getEnforcementStatus: async () => ({ required: false, blocked: false }) },
    gitHubAuth: { getStatus: async () => ({ isAuthenticated: true }) },
  } };
  const result = await applyWindowsSandbox(client, session, { workingDirectory: work }, profile(), audit);
  assert.equal(applied.sandboxConfig.allowBypass, false);
  assert.equal(applied.sandboxConfig.allowDevToolAccess, false);
  assert.equal(applied.sandboxConfig.addCurrentWorkingDirectory, false);
  assert.deepEqual(applied.sandboxConfig.userPolicy.filesystem.readwritePaths, [work]);
  assert.ok(applied.sandboxConfig.userPolicy.filesystem.deniedPaths.includes(audit));
  assert.deepEqual(applied.sandboxConfig.userPolicy.network, { allowOutbound: false, allowLocalNetwork: false });
  assert.deepEqual(applied.shell.credentials, { git: false, gh: false });
  assert.equal(result.isAuthenticated, true);
  assert.equal(result.enforcement.required, false);
});

test("missing capabilities, failed policy updates, blocked sandbox and absent login reject", async () => {
  for (const failure of ["unsupported", "capability", "update", "blocked", "auth"]) {
    let updated = false;
    const client = { rpc: { sandbox: { getHostSupport: async () => failure === "unsupported"
      ? { supported: false } : failure === "capability" ? { supported: true, capabilities: [] } : support() } } };
    const session = { rpc: {
      options: { update: async () => { updated = true; return { success: failure !== "update" }; } },
      sandbox: { getEnforcementStatus: async () => ({ blocked: failure === "blocked" }) },
      gitHubAuth: { getStatus: async () => ({ isAuthenticated: failure !== "auth" }) },
    } };
    await assert.rejects(applyWindowsSandbox(client, session,
      { workingDirectory: resolve("work") }, profile(), resolve("audit")));
    if (["unsupported", "capability"].includes(failure)) assert.equal(updated, false);
  }
});

test("integrated native Windows profile permits useful commands but denies external auth and audit reads", {
  skip: process.platform !== "win32" || process.env.SKILL_EFFECTIVENESS_RUNTIME_TESTS !== "1",
  timeout: 120000,
}, async t => {
  const model = process.env.SKILL_EFFECTIVENESS_TEST_MODEL;
  assert.ok(model, "Select a local metadata model; this test sends no prompt");
  const root = realpathSync.native(mkdtempSync(join(tmpdir(), "native-profile-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const work = join(root, "candidate"), audit = join(root, "audit"), privateDir = join(root, "private");
  for (const path of [work, audit, privateDir]) mkdirSync(path);
  writeFileSync(join(privateDir, "auth-canary.txt"), "SYNTHETIC_AUTH_FILE");
  writeFileSync(join(work, "node-control.cjs"), "require('node:fs').writeFileSync('node-output.txt','NODE_EXECUTED');console.log('NODE_EXECUTED');");
  const { CopilotClient } = await import("@github/copilot-sdk");
  let commandResult;
  let interceptedPrompts = 0;
  let acceptedConnections = 0;
  const server = createServer(socket => { acceptedConnections++; socket.end(); });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  t.after(() => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve())));
  const port = server.address().port;
  const executor = new RestrictedCopilotExecutor(options => {
    assert.equal(options.useLoggedInUser, true);
    for (const key of ["COPILOT_SDK_AUTH_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"]) {
      assert.equal(options.connection.env[key], undefined);
    }
    const client = new CopilotClient(options);
    const createSession = client.createSession.bind(client);
    client.createSession = async config => {
      const session = await createSession(config);
      session.sendAndWait = async () => {
          interceptedPrompts++;
          await session.rpc.tools.initializeAndValidate();
          const command = [
            "$ErrorActionPreference='Stop'",
            `[IO.File]::WriteAllText('${join(work, "positive.txt")}', 'WRITE_OK')`,
            "$authRead=$false; $auditRead=$false; $outsideWrite=$false; $connected=$false",
            `try { $authRead = [IO.File]::ReadAllText('${join(privateDir, "auth-canary.txt")}') -eq 'SYNTHETIC_AUTH_FILE' } catch [UnauthorizedAccessException] {} catch [IO.IOException] {}`,
            `try { $null=[IO.Directory]::GetFiles('${audit}'); $auditRead=$true } catch [UnauthorizedAccessException] {} catch [IO.IOException] {}`,
            `try { [IO.File]::WriteAllText('${join(privateDir, "outside.txt")}','BAD');$outsideWrite=$true } catch [UnauthorizedAccessException] {} catch [IO.IOException] {}`,
            `$tcp=[Net.Sockets.TcpClient]::new();try{$pending=$tcp.ConnectAsync('127.0.0.1',${port});$connected=$pending.Wait(3000) -and $tcp.Connected}catch [AggregateException]{}finally{$tcp.Dispose()}`,
            "$start=[Diagnostics.ProcessStartInfo]::new(); $start.UseShellExecute=$false; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true",
            `$start.FileName='${process.execPath}';$start.Arguments='"${join(work, "node-control.cjs")}"';$start.WorkingDirectory='${work}'`,
            "$p=[Diagnostics.Process]::Start($start);if(-not $p.WaitForExit(10000)){$p.Kill();throw 'Node timeout'};$code=$p.ExitCode;$output=$p.StandardOutput.ReadToEnd();$errorText=$p.StandardError.ReadToEnd();$p.Dispose()",
            "[ordered]@{authRead=$authRead;auditRead=$auditRead;outsideWrite=$outsideWrite;connected=$connected;nodeExit=$code;nodeOutput=$output;nodeError=$errorText}|ConvertTo-Json -Compress",
          ].join("\n");
          const tool = await session.rpc.tools.execute({ name: "powershell",
            arguments: { command, description: "Synthetic useful execution and protected-file controls" },
            toolCallId: "native-profile-preflight" });
          assert.equal(tool.resultType, "success", tool.textResultForLlm);
          commandResult = tool.textResultForLlm;
          throw new Error("NATIVE_PROFILE_MODEL_FREE_STOP");
      };
      return session;
    };
    return client;
  });
  try {
    await assert.rejects(executor.execute({ name: "preflight", prompt: "Never sent" }, {
      workDir: work, model, timeout: 90000, env: { DO_NOT_TRACK: "1" },
      executorConfig: { auditDirectory: audit, executionProfile: {
        ...profile(), readonlyPaths: [dirname(process.execPath)], deniedPaths: [privateDir],
      }, sessionPolicy: { availableTools: ["powershell"], permissions: { allow: ["Shell(*)"], deny: [] } } },
    }), /NATIVE_PROFILE_MODEL_FREE_STOP/);
  } finally { await executor.shutdown(); }
  assert.match(commandResult, /"authRead":false/);
  assert.match(commandResult, /"auditRead":false/);
  assert.match(commandResult, /"outsideWrite":false/);
  assert.match(commandResult, /"connected":false/);
  assert.equal(acceptedConnections, 0);
  assert.match(commandResult, /"nodeExit":0/);
  assert.match(commandResult, /NODE_EXECUTED/);
  assert.equal(readFileSync(join(work, "node-output.txt"), "utf8"), "NODE_EXECUTED");
  assert.equal(interceptedPrompts, 1, "One native send was intercepted; none was forwarded to the model");
  const auditFolder = join(audit, readdirSync(audit).find(name => name.startsWith("skill-evidence-")));
  const reportFile = readdirSync(auditFolder).find(name => name.endsWith(".verification.json"));
  assert.equal(JSON.parse(readFileSync(join(auditFolder, reportFile), "utf8")).status, "verified");
  const inventoryFile = readdirSync(auditFolder).find(name => name.endsWith(".json") && !name.endsWith(".verification.json"));
  const inventory = JSON.parse(readFileSync(join(auditFolder, inventoryFile), "utf8"));
  assert.equal(inventory.executionProfile.name, "windows-native");
  assert.equal(inventory.executionProfile.isAuthenticated, true);
  assert.equal(inventory.executionProfile.sandboxConfig.allowBypass, false);
  assert.deepEqual(readdirSync(work).sort(), ["node-control.cjs", "node-output.txt", "positive.txt"]);
});
