// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { mkdir } from "node:fs/promises";
import { join, resolve } from "node:path";

import { writeJson } from "./contracts.mts";
import { RCA_SKILL_NAMES, type EvaluationCondition } from "./conditions.mts";
import type { CliInvoker } from "./cli-orchestrator.mts";

interface InventoryEntry {
  readonly name: string;
  readonly enabled: boolean;
  readonly path?: string;
}

export interface CliIsolation {
  readonly verified: true;
  readonly enabledSkills: readonly string[];
  readonly disabledSkillCount: number;
  readonly enabledPlugins: 0;
}

/** Uses private configuration without copying credentials, plugins, hooks, memory, or IDE state. */
export function isolatedCliEnvironment(workspace: string): NodeJS.ProcessEnv {
  const home = join(workspace, ".isolated-home");
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    HOME: home,
    USERPROFILE: home,
    COPILOT_HOME: join(home, ".copilot"),
    XDG_CONFIG_HOME: join(home, ".config"),
  };
  delete env.COPILOT_CUSTOM_INSTRUCTIONS_DIRS;
  delete env.COPILOT_AGENT_SESSION_ID;
  return env;
}

/**
 * Disables inherited skills only in the private settings and verifies CLI discovery before inference.
 * Rejects unsupported inventory output, enabled plugins, and skills outside the exact staged bundle.
 */
export async function verifyCliIsolation(
  workspace: string,
  condition: EvaluationCondition,
  invoker: CliInvoker,
  env: NodeJS.ProcessEnv,
): Promise<CliIsolation> {
  const configRoot = env.COPILOT_HOME;
  if (configRoot !== join(workspace, ".isolated-home", ".copilot")) {
    throw new Error("CLI isolation settings must be inside the temporary workspace");
  }
  await mkdir(configRoot, { recursive: true });
  const settings = {
    disableAllHooks: true,
    ide: { autoConnect: false },
  };
  await writeJson(join(configRoot, "settings.json"), settings);
  const inventory = async (kind: "skill" | "plugin"): Promise<readonly InventoryEntry[]> => {
    const response = await invoker(
      ["--no-auto-update", "--disable-client-telemetry", kind, "list", "--json"],
      { cwd: workspace, timeoutMs: 30_000, env },
    );
    if (response.exitCode !== 0 || response.timedOut) {
      throw new Error(`CLI ${kind} isolation inventory failed: ${response.stderr || response.stdout}`);
    }
    const parsed: unknown = JSON.parse(response.stdout);
    if (!Array.isArray(parsed)) {
      throw new Error(`CLI ${kind} isolation inventory must be an array`);
    }
    return parsed.map((entry: unknown) => {
      if (
        entry === null || typeof entry !== "object" ||
        !("name" in entry) || typeof entry.name !== "string" ||
        !("enabled" in entry) || typeof entry.enabled !== "boolean" ||
        ("path" in entry && typeof entry.path !== "string")
      ) {
        throw new Error(`CLI ${kind} isolation inventory has an unsupported entry`);
      }
      return {
        name: entry.name,
        enabled: entry.enabled,
        path: "path" in entry && typeof entry.path === "string" ? entry.path : undefined,
      };
    });
  };
  const permitted = (entry: InventoryEntry): boolean =>
    condition === "with-skill" &&
    RCA_SKILL_NAMES.some((name) =>
      entry.name === name && entry.path !== undefined &&
      resolve(entry.path) === resolve(workspace, ".github", "skills", name),
    );
  const discovered = await inventory("skill");
  const disabledSkills = [...new Set(discovered.filter((entry) => !permitted(entry)).map((entry) => entry.name))];
  await writeJson(join(configRoot, "settings.json"), { ...settings, disabledSkills });
  const enabled = (await inventory("skill")).filter((entry) => entry.enabled);
  if (
    enabled.some((entry) => !permitted(entry)) ||
    (condition === "with-skill" && RCA_SKILL_NAMES.some((name) => !enabled.some((entry) => entry.name === name)))
  ) {
    throw new Error("CLI isolation failed: enabled skills do not match the selected condition");
  }
  if ((await inventory("plugin")).some((entry) => entry.enabled)) {
    throw new Error("CLI isolation failed: an enabled plugin remains");
  }
  return {
    verified: true,
    enabledSkills: enabled.map((entry) => entry.name).sort(),
    disabledSkillCount: disabledSkills.length,
    enabledPlugins: 0,
  };
}
