// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

import { isolatedCliEnvironment, verifyCliIsolation } from "../../../evals/rca-real-world/cli-isolation.mts";
import { runCliTrial, type CliInvoker } from "../../../evals/rca-real-world/cli-orchestrator.mts";
import { stageSkills } from "../../../evals/rca-real-world/orchestrator.mts";
import { RCA_SKILL_NAMES } from "../../../evals/rca-real-world/conditions.mts";
import { fixtureInventory } from "./cli-fixture.mts";

for (const condition of ["with-skill", "without-skill"] as const) {
  test(`verifies ${condition} inventories after disabling inherited skills in private settings`, async (context) => {
    const workspace = await mkdtemp(join(tmpdir(), "rca-isolation-test-"));
    context.after(() => rm(workspace, { recursive: true, force: true }));
    if (condition === "with-skill") {
      await stageSkills(resolve("."), workspace);
    }
    const env = isolatedCliEnvironment(workspace);
    assert.equal(env.COPILOT_HOME, join(workspace, ".isolated-home", ".copilot"));
    assert.equal(env.HOME, env.USERPROFILE);
    assert.equal(env.COPILOT_AGENT_SESSION_ID, undefined);
    assert.equal(env.COPILOT_CUSTOM_INSTRUCTIONS_DIRS, undefined);
    const invoker: CliInvoker = async (args, options) => {
      const result = await fixtureInventory(args, options);
      assert.ok(result);
      return result;
    };
    const isolation = await verifyCliIsolation(workspace, condition, invoker, env);
    assert.deepEqual(isolation.enabledSkills, condition === "with-skill" ? [...RCA_SKILL_NAMES].sort() : []);
    assert.equal(isolation.disabledSkillCount, 1);
    assert.ok(env.COPILOT_HOME);
    const settings = JSON.parse(await readFile(join(env.COPILOT_HOME, "settings.json"), "utf8"));
    assert.equal(settings.disableAllHooks, true);
    assert.equal(settings.ide.autoConnect, false);
    assert.deepEqual(settings.disabledSkills, ["unrelated-global-skill"]);
    await assert.rejects(readFile(join(workspace, "AGENTS.md")), { code: "ENOENT" });
    if (condition === "without-skill") {
      assert.deepEqual(await readdir(workspace), [".isolated-home"]);
    }
  });
}

for (const failure of ["enabled-plugin", "enabled-skill", "unsupported-inventory"] as const) {
  test(`fails closed before inference when isolation has ${failure}`, async (context) => {
    const root = await mkdtemp(join(tmpdir(), "rca-isolation-failure-"));
    context.after(() => rm(root, { recursive: true, force: true }));
    let modelCalls = 0;
    const artifact = await runCliTrial({
      repositoryRoot: resolve("."), runRoot: root, runId: "isolation-failure",
      caseId: "case-01", trial: 1, condition: "without-skill",
      cliInvoker: async (args, options) => {
        if (args.includes("--version")) {
          return { exitCode: 0, stdout: "Copilot fixture", stderr: "", durationMs: 1, timedOut: false };
        }
        if (args.includes("list")) {
          if (failure === "unsupported-inventory") {
            return { exitCode: 0, stdout: "{}", stderr: "", durationMs: 1, timedOut: false };
          }
          if (args.includes(failure === "enabled-plugin" ? "plugin" : "skill")) {
            return {
              exitCode: 0, stdout: '[{"name":"unwanted","enabled":true}]',
              stderr: "", durationMs: 1, timedOut: false,
            };
          }
          const result = await fixtureInventory(args, options);
          assert.ok(result);
          return result;
        }
        modelCalls += 1;
        throw new Error("Must not invoke a model");
      },
    });
    assert.equal(modelCalls, 0);
    assert.equal(artifact.endReason, "error");
    assert.match(artifact.error ?? "", /isolation/);
    assert.equal(artifact.preflight.isolation, undefined);
  });
}
