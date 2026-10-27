// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { homedir } from "node:os";
import { dirname, isAbsolute, join } from "node:path";

export function validateWindowsProfile(profile) {
  if (profile === undefined) return undefined;
  assert.ok(profile && Object.getPrototypeOf(profile) === Object.prototype
    && Object.keys(profile).every(key => ["name", "readonlyPaths", "deniedPaths"].includes(key)),
  "executionProfile requires only name, readonlyPaths and deniedPaths");
  assert.equal(profile.name, "windows-native", "Unsupported executionProfile.name");
  const paths = key => {
    assert.ok(Array.isArray(profile[key]) && Array.from(profile[key]).every(value =>
      typeof value === "string" && value === value.trim() && isAbsolute(value))
      && new Set(profile[key]).size === profile[key].length,
    `executionProfile.${key} requires distinct absolute paths`);
    return Object.freeze([...profile[key]]);
  };
  return Object.freeze({ name: profile.name, readonlyPaths: paths("readonlyPaths"), deniedPaths: paths("deniedPaths") });
}

export function windowsClientOptions(options) {
  assert.equal(process.platform, "win32", "windows-native requires Windows; no unrestricted fallback");
  assert.equal(options.gitHubToken, undefined,
    "Client-level token authentication is not allowed for windows-native");
  assert.equal(options.connection?.kind, "stdio", "windows-native requires the pinned stdio runtime");
  assert.equal(options.env, undefined, "Use the stdio connection environment");
  const env = { ...options.connection.env };
  for (const key of Object.keys(env)) {
    if (/^(COPILOT_PROVIDER_|COPILOT_GITHUB_TOKEN$|COPILOT_SDK_AUTH_TOKEN$|GITHUB_COPILOT_API_TOKEN$|GH_TOKEN$|GITHUB_TOKEN$|GH_ENTERPRISE_TOKEN$|GITHUB_ENTERPRISE_TOKEN$|PSModulePath$)/i.test(key)) {
      delete env[key];
    }
  }
  return { ...options, connection: { ...options.connection, env }, useLoggedInUser: true };
}

export async function applyWindowsSandbox(client, session, config, profile, auditRoot) {
  const support = await client.rpc.sandbox.getHostSupport();
  assert.equal(support?.supported, true, "Native Windows sandbox unavailable; no unrestricted fallback");
  for (const name of ["shell", "denied_paths", "network"]) {
    assert.equal(support.capabilities?.find(item => item.name === name)?.supported, true,
      "Required native sandbox capability missing: " + name);
  }
  const sandboxConfig = {
    enabled: true, addCurrentWorkingDirectory: false, allowBypass: false, allowDevToolAccess: false,
    sandboxMcpServers: true, sandboxLspServers: true, auth: { git: false, gh: false },
    userPolicy: {
      filesystem: {
        readwritePaths: [config.workingDirectory],
        readonlyPaths: [...new Set([dirname(process.execPath), ...profile.readonlyPaths, ...(config.skillDirectories ?? [])])],
        deniedPaths: [...new Set([auditRoot, join(homedir(), ".copilot"), join(homedir(), ".git-credentials"),
          join(homedir(), ".npmrc"), ...(process.env.COPILOT_HOME ? [process.env.COPILOT_HOME] : []),
          ...(config.configDirectory ? [config.configDirectory] : []), ...profile.deniedPaths])],
      },
      network: { allowOutbound: false, allowLocalNetwork: false },
    },
  };
  const result = await session.rpc.options.update({
    sandboxConfig, sandboxConfigSource: "session_flag",
    shell: { credentials: { git: false, gh: false }, initScripts: [] },
  });
  assert.equal(result?.success, true, "Native sandbox configuration failed");
  const enforcement = await session.rpc.sandbox.getEnforcementStatus();
  assert.equal(enforcement?.blocked, false, enforcement?.reason ?? "Native sandbox enforcement failed");
  const auth = await session.rpc.gitHubAuth.getStatus();
  assert.equal(auth?.isAuthenticated, true, "windows-native requires authenticated normal local login");
  return { name: profile.name, sandboxConfig, support, enforcement, isAuthenticated: true,
    limitation: "Explicit native command policy, not an enterprise managed-policy floor or full task/grader qualification" };
}
