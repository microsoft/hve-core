// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

import type { CliInvoker, CliInvocationResult } from "../../../evals/rca-real-world/cli-orchestrator.mts";

/** Models CLI inventories against the actual private settings and staged test workspace. */
export async function fixtureInventory(
  args: readonly string[],
  options: Parameters<CliInvoker>[1],
): Promise<CliInvocationResult | undefined> {
  if (!args.includes("list")) {
    return undefined;
  }
  let entries: { name: string; enabled: boolean; path?: string }[];
  if (args.includes("plugin")) {
    entries = [{ name: "browser-use", enabled: false }];
  } else {
    const skillsRoot = join(options.cwd, ".github", "skills");
    let names: string[];
    try {
      names = await readdir(skillsRoot);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
      names = [];
    }
    const configRoot = options.env?.COPILOT_HOME;
    if (!configRoot) {
      throw new Error("Fixture inventory requires a private CLI home");
    }
    const settings = JSON.parse(
      await readFile(join(configRoot, "settings.json"), "utf8"),
    ) as { disabledSkills?: readonly string[] };
    entries = [
      ...names.map((name) => ({ name, path: join(skillsRoot, name) })),
      { name: "unrelated-global-skill", path: join(options.cwd, "inherited", "unrelated-global-skill") },
    ].map((entry) => ({
      ...entry,
      enabled: !settings.disabledSkills?.includes(entry.name),
    }));
  }
  return {
    exitCode: 0, stdout: JSON.stringify(entries), stderr: "", durationMs: 1, timedOut: false,
  };
}
