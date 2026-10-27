// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { AsyncLocalStorage } from "node:async_hooks";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { findPackageJSON } from "node:module";
import test from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parse, stringify } from "yaml";
import { applyEnvironment, createDefaultGraderRegistry, hasGraderError, PromptGrader, RunCommandGrader, resolveGradePass } from "@microsoft/vally";
import { CopilotSdkExecutor } from "@microsoft/vally/executor";
import { CopilotClient } from "@github/copilot-sdk";
import { RestrictedCopilotExecutor, registerExecutors, restrictedFactories, runtimeClientOptions,
  prepareAuditRoot, validateSessionPolicy, verifySkillInventory } from "../scripts/restricted-copilot-executor.mjs";

const runtime = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const assets = join(runtime, "assets");
const read = name => readFileSync(join(assets, name), "utf8");
const fill = text => text.replace(/<[^>\r\n]+>/g, value => ({
  "<task>": "task", "<task-name>": "task", "<candidate-skill>": "demo",
  "<artifact>": "result.txt", "<experiment-name>": "baseline-first",
  "<checker-entry>": "check.mjs",
})[value] ?? "example");

function fixture(t) {
  const temporary = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(temporary, { recursive: true, force: true }));
  const root = join(temporary, "package with spaces");
  const write = (name, text) => {
    const file = join(root, name);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, text);
    return file;
  };
  write("package.json", fill(read("package.template.json")));
  symlinkSync(join(runtime, "node_modules"), join(root, "node_modules"), process.platform === "win32" ? "junction" : "dir");
  mkdirSync(join(root, "scripts"));
  copyFileSync(join(runtime, "scripts", "native-inventory.mjs"), join(root, "scripts", "native-inventory.mjs"));
  copyFileSync(join(runtime, "scripts", "review-images.mjs"), join(root, "scripts", "review-images.mjs"));
  copyFileSync(join(runtime, "scripts", "restricted-copilot-executor.mjs"), join(root, "scripts", "restricted-copilot-executor.mjs"));
  copyFileSync(join(runtime, "scripts", "native-windows-sandbox.mjs"), join(root, "scripts", "native-windows-sandbox.mjs"));
  write("skills/demo/SKILL.md", "---\nname: demo\ndescription: Local fixture.\n---\nCheck your work.\n");
  write("fixtures/task/public/request.txt", "Create deliverable/result.txt. Synthetic test input.");
  write("grading/task/check.mjs", `import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
writeFileSync(join(process.env.EVALUATE_WORKSPACE, "checker-entered"), "entered");
if (JSON.parse(readFileSync(process.argv[2], "utf8")).answer !== 42) process.exit(1);`);
  const spec = parse(fill(read("native-eval.template.yaml")));
  spec.defaults.executor.config.auditDirectory = join(temporary, "operator-audit");
  const grade = parse(fill(read("native-grade-eval.template.yaml")));
  grade.stimuli[0].graders[0].config.args[3] =
    createHash("sha256").update(readFileSync(join(root, "grading/task/check.mjs"))).digest("hex");
  const review = parse(fill(read("native-review-eval.template.yaml")));
  const experiment = parse(fill(read("native-experiment.template.yaml")));
  write("evals/task.eval.yaml", stringify(spec));
  write("evals/task.grade.eval.yaml", stringify(grade));
  write("evals/task.review.eval.yaml", stringify(review));
  write("experiments/task.experiment.yaml", stringify(experiment));
  const environment = { ...process.env, DO_NOT_TRACK: "1", VALLY_TELEMETRY_OPTOUT: "1" };
  for (const key of ["NODE_OPTIONS", "SKILL_EVAL_INVENTORY_DIR", "SKILL_EVAL_INVENTORY_PACKAGE",
    "EVALUATE_USE_HOST_COPILOT_HOME", "COPILOT_HOME_SETTINGS_JSON", "NODE_TEST_CONTEXT"]) delete environment[key];
  const run = (args, env = {}, input, cwd = root) => {
    const child = spawnSync(process.execPath, args, {
      cwd, input, env: { ...environment, ...env }, encoding: "utf8", timeout: 90000, maxBuffer: 4 * 1024 * 1024,
    });
    assert.ifError(child.error);
    return child;
  };
  const scripts = JSON.parse(readFileSync(join(root, "package.json"), "utf8")).scripts;
  const script = (name, args, env, input) => {
    const [node, ...command] = scripts[name].split(" ");
    assert.equal(node, "node");
    return run([...command, ...args], env, input);
  };
  return { root, temporary, write, spec, grade, review, experiment, run, script };
}

function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory() ? files(join(directory, entry.name)) : [join(directory, entry.name)]);
}

test("copied native templates lint and dry-run both role orders without capture or model calls", { timeout: 90000 }, t => {
  const f = fixture(t);
  const lint = f.script("vally", ["lint", "--strict", "--eval-spec", "evals/task.eval.yaml"]);
  assert.equal(lint.status, 0, lint.stdout + lint.stderr);
  assert.deepEqual(f.spec.stimuli[0].graders.map(grader => grader.type),
    ["completed", "file-exists"]);
  const gradeLint = f.script("vally", ["lint", "--strict", "--eval-spec", "evals/task.grade.eval.yaml"]);
  assert.equal(gradeLint.status, 0, gradeLint.stdout + gradeLint.stderr);
  const reviewLint = f.script("vally", ["lint", "--strict", "--eval-spec", "evals/task.review.eval.yaml"]);
  assert.equal(reviewLint.status, 0, reviewLint.stdout + reviewLint.stderr);
  assert.deepEqual(f.review.stimuli[0].graders[0].config.evidence, ["repo"]);
  assert.deepEqual(f.experiment.vary, ["/environment/skills"]);
  assert.deepEqual(f.experiment.variants["a-baseline"].environment.skills, []);
  assert.deepEqual(f.experiment.variants["b-treatment"].environment.skills, ["../skills/demo"]);
  const reversed = { ...f.experiment, name: "treatment-first", baseline: "b-baseline", variants: {
    "a-treatment": f.experiment.variants["b-treatment"], "b-baseline": f.experiment.variants["a-baseline"],
  } };
  for (const experiment of [f.experiment, reversed]) {
    f.write("experiments/task.experiment.yaml", stringify(experiment));
    const output = join(f.temporary, experiment.name);
    const result = f.script("study:dry-run", ["experiments/task.experiment.yaml", "--param", "AGENT_MODEL=mock",
      "--output-dir", output, "--workspace", join(f.temporary, "workspaces", experiment.name)]);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(experiment.name));
    for (const variant of Object.keys(experiment.variants)) assert.ok(result.stdout.includes(variant));
  }
  assert.equal(existsSync(join(f.root, "inventories")), false);
  assert.equal(existsSync(join(f.root, "RESULTS.md")), false);
});

test("native staging templates separate public inputs, offline checkers and saved review evidence", () => {
  const candidate = parse(fill(read("native-eval.template.yaml")));
  const grade = parse(fill(read("native-grade-eval.template.yaml")));
  const review = parse(fill(read("native-review-eval.template.yaml")));
  assert.deepEqual(candidate.agent_environment.files, [{ src: "../fixtures/task/public", dest: "task-fixture" }]);
  assert.equal(candidate.grading_environment, undefined);
  assert.deepEqual(candidate.stimuli[0].graders.map(grader => grader.type), ["completed", "file-exists"]);
  assert.equal(grade.stimuli[0].name, candidate.stimuli[0].name);
  assert.deepEqual(grade.stimuli[0].graders.map(grader => grader.type), ["program"]);
  assert.doesNotMatch(grade.stimuli[0].graders[0].config.args[2], /\$\{/);
  for (const key of ["agent_environment", "grading_environment", "executor_plugins"]) assert.equal(grade[key], undefined);
  assert.equal(grade.defaults, undefined);
  assert.match(candidate.stimuli[0].prompt, /private evaluator is unavailable/);
  assert.doesNotMatch(candidate.stimuli[0].prompt, /check\.mjs|Public checks run:/);
  assert.equal(candidate.defaults.judge_model, undefined);
  assert.equal(candidate.defaults.judge_provider, undefined);
  assert.equal(candidate.stimuli[0].rubric, undefined);
  assert.equal(review.name, candidate.name);
  assert.equal(review.stimuli[0].name, candidate.stimuli[0].name);
  assert.deepEqual(review.stimuli[0].graders.map(grader => grader.type), ["prompt"]);
  assert.deepEqual(review.stimuli[0].graders[0].config.evidence, ["repo"]);
  for (const key of ["agent_environment", "grading_environment", "executor_plugins"]) assert.equal(review[key], undefined);
  assert.equal(review.defaults.executor, undefined);
});

test("native candidate staging preserves both complete skill arms without private checkers", async t => {
  const f = fixture(t);
  const input = readFileSync(join(f.root, "fixtures", "task", "public", "request.txt"), "utf8");
  const publicTool = "export const validate = value => value !== undefined;\n";
  f.write("skills/demo/validate.mjs", publicTool);
  f.write("EVALS.md", "Evaluator-only notes.");
  f.write("review-inputs/review.txt", "Reviewer-only input.");
  for (const [variant, environment] of Object.entries(f.experiment.variants)) {
    const submission = join(f.root, "submissions", variant);
    mkdirSync(submission, { recursive: true });
    await applyEnvironment({ ...f.spec.agent_environment, ...environment.environment },
      submission, join(f.root, "experiments"));
    for (const path of ["evaluator", "grading", "review-inputs", "EVALS.md", "scripts"]) {
      assert.equal(existsSync(join(submission, path)), false, `${variant}: ${path} must not be staged`);
    }
    assert.equal(readFileSync(join(submission, "task-fixture", "request.txt"), "utf8"), input);
    const skill = join(submission, "demo");
    assert.equal(existsSync(skill), variant === "b-treatment");
    if (existsSync(skill)) {
      assert.equal(readFileSync(join(skill, "SKILL.md"), "utf8"),
        readFileSync(join(f.root, "skills", "demo", "SKILL.md"), "utf8"));
      assert.equal(readFileSync(join(skill, "validate.mjs"), "utf8"), publicTool);
    }
  }
});

test("native staging fails explicitly for missing public inputs", async t => {
  const f = fixture(t);
  const submission = join(f.root, "submission");
  mkdirSync(submission);
  await assert.rejects(applyEnvironment({
    files: [{ src: "../fixtures/missing", dest: "task-fixture" }],
  }, submission, join(f.root, "evals")), /ENOENT|not found|does not exist/);
});

async function protectedCases(t, native) {
  for (const name of ["valid", "alternative", "wrong", "missing-output", "wrong-digest",
    "malformed-digest", "missing-digest", "modified-checker", "missing-checker", "workspace-impostor",
    "checker-escape", "linked-checker", "output-escape", "missing-assets", "missing-snapshot",
    "unavailable-snapshot", "overlapping-roots", "body-error", "linked-submission", "snapshot-checker-impostor"]) {
    await t.test(name, async t => {
      const f = fixture(t), config = structuredClone(f.grade.stimuli[0].graders[0].config);
      const scratch = join(f.root, "scratch"), snapshot = join(f.root, "snapshot"), assetsDir = join(f.root, "grading/task");
      mkdirSync(scratch); mkdirSync(snapshot);
      if (name !== "missing-output") f.write("snapshot/deliverable/result.txt",
        JSON.stringify({ answer: ["wrong", "snapshot-checker-impostor"].includes(name) ? 7 : 42,
          ...(name === "alternative" ? { explanation: "Valid alternative." } : {}) }));
      f.write("scratch/evaluator/check.mjs", 'throw new Error("Workspace impostor entered");');
      const trajectory = { workDir: scratch, assetsDir, artifactDir: snapshot };
      if (name === "wrong-digest") config.args[3] = "0".repeat(64);
      if (name === "malformed-digest") config.args[3] = "bad";
      if (name === "missing-digest") config.args.pop();
      if (name === "modified-checker") f.write("grading/task/check.mjs", 'throw new Error("Altered checker entered");');
      if (name === "missing-checker") rmSync(join(assetsDir, "check.mjs"));
      if (name === "checker-escape") config.args[2] = config.args[2].replace('"check.mjs"', '"../check.mjs"');
      if (name === "linked-checker") {
        f.write("outside/check.mjs", readFileSync(join(assetsDir, "check.mjs")));
        symlinkSync(join(f.root, "outside"), join(assetsDir, "link"), process.platform === "win32" ? "junction" : "dir");
        config.args[2] = config.args[2].replace('"check.mjs"', '"link/check.mjs"');
      }
      if (name === "linked-submission") {
        f.write("outside/result.txt", '{"answer":42}');
        rmSync(join(snapshot, "deliverable"), { recursive: true });
        symlinkSync(join(f.root, "outside"), join(snapshot, "deliverable"), process.platform === "win32" ? "junction" : "dir");
      }
      if (name === "snapshot-checker-impostor") {
        f.write("snapshot/check.mjs", 'console.log(JSON.stringify({passed:true,score:1}));');
      }
      if (name === "output-escape") config.args[2] = config.args[2].replace('"deliverable/result.txt"', '"../result.txt"');
      if (name === "missing-assets") delete trajectory.assetsDir;
      if (name === "missing-snapshot") delete trajectory.artifactDir;
      if (name === "unavailable-snapshot") trajectory.artifactDir = join(f.temporary, "missing-snapshot");
      if (name === "overlapping-roots") trajectory.artifactDir = assetsDir;
      if (name === "body-error") {
        const checker = 'throw new Error("Trusted checker body failed");';
        f.write("grading/task/check.mjs", checker);
        config.args[3] = createHash("sha256").update(checker).digest("hex");
      }
      const passed = ["valid", "alternative", "workspace-impostor"].includes(name);
      const wrong = ["wrong", "snapshot-checker-impostor"].includes(name);
      const operational = !["valid", "alternative", "wrong", "missing-output", "workspace-impostor", "snapshot-checker-impostor"].includes(name);
      if (native) {
        const grade = await createDefaultGraderRegistry().get("program").grade({ trajectory, config: { ...config, program: process.execPath } });
        assert.equal(grade.passed, passed, JSON.stringify(grade));
        assert.equal(hasGraderError(grade), operational, JSON.stringify(grade));
      } else {
        const result = f.run(config.args, { ...config.env, EVALUATE_WORKSPACE: scratch,
          EVALUATE_ASSETS: trajectory.assetsDir ?? "", EVALUATE_ARTIFACT_DIR: trajectory.artifactDir ?? "" }, undefined, scratch);
        assert.equal(result.status, wrong ? 1 : 0, result.stderr);
        if (wrong) assert.equal(result.stdout, "");
        else {
          const verdict = JSON.parse(result.stdout);
          assert.equal(verdict.passed, passed);
          assert.equal(verdict.status === "error", operational, verdict.evidence);
        }
      }
      assert.equal(existsSync(join(scratch, "checker-entered")), ["valid", "alternative", "wrong", "workspace-impostor", "snapshot-checker-impostor"].includes(name));
      assert.match(readFileSync(join(scratch, "evaluator/check.mjs"), "utf8"), /Workspace impostor/);
    });
  }
}

test("authored protected prelude executes directly without native runtime or model calls", t => protectedCases(t, false));
test("native protected program distinguishes task failures from integrity and checker errors", t => protectedCases(t, true));

test("native protected program reports interpreter startup as a grader error", async t => {
  const f = fixture(t);
  const grade = await createDefaultGraderRegistry().get("program").grade({ trajectory: { workDir: f.root },
    config: { ...f.grade.stimuli[0].graders[0].config, program: join(f.temporary, "missing-interpreter.exe") } });
  assert.equal(grade.passed, false);
  assert.equal(hasGraderError(grade), true);
  assert.match(JSON.stringify(grade), /ENOENT|not found|spawn/i);
});

const policyConfig = (tools = []) => ({
  sessionPolicy: { availableTools: tools, permissions: { allow: [], deny: [] } },
});

test("restricted policy requires an exact explicit configuration and immutable lists", () => {
  const original = policyConfig();
  const policy = validateSessionPolicy(original);
  assert.deepEqual(policy, original.sessionPolicy);
  assert.notEqual(policy, original.sessionPolicy);
  assert.throws(() => policy.availableTools.push("shell"), TypeError);
  assert.throws(() => policy.permissions.allow.push("Shell(*)"), TypeError);
  const malformed = [undefined, null, [], {}, { ...original, extra: true },
    { sessionPolicy: {} },
    { sessionPolicy: { availableTools: [], permissions: { allow: [] } } },
    { sessionPolicy: { ...original.sessionPolicy, extra: [] } },
    { sessionPolicy: { ...original.sessionPolicy, permissions: { allow: [], deny: [], extra: [] } } }];
  for (const value of malformed) assert.throws(() => validateSessionPolicy(value));
  for (const value of [undefined, null, "", {}, [""], [" "], [" view"], [1], ["view", "view"], ["*"], ["view?"]]) {
    const config = policyConfig();
    config.sessionPolicy.availableTools = value;
    assert.throws(() => validateSessionPolicy(config));
  }
  for (const key of ["allow", "deny"]) {
    for (const value of [undefined, {}, [""], [false], ["Read(x)", "Read(x)"]]) {
      const config = policyConfig();
      config.sessionPolicy.permissions[key] = value;
      assert.throws(() => validateSessionPolicy(config));
    }
  }
  assert.deepEqual(original, policyConfig());
});

test("restricted executor rejects missing policy, invalid providers, default mode and resume without SDK startup", async () => {
  const executor = new RestrictedCopilotExecutor();
  const stimulus = { name: "unit", prompt: "Never send this prompt." };
  const options = { executorConfig: policyConfig(), timeout: 1000 };
  await assert.rejects(executor.execute(stimulus, { ...options, executorConfig: {} }), /sessionPolicy/);
  assert.throws(() => executor.validateConfig({ ...policyConfig(), provider: { invalid: true } }));
  for (const env of [undefined, {}, [], { FLAG: 1 }]) {
    await assert.rejects(executor.execute(stimulus, { ...options, env }), /environment\.env/);
  }
  for (const sessionID of ["prior-session", ""]) {
    await assert.rejects(executor.execute(stimulus, { ...options, env: { FLAG: "1" }, sessionID }), /resume/);
  }
  for (const timeout of [0, -1, Infinity, NaN]) {
    await assert.rejects(executor.execute(stimulus, { ...options, env: { FLAG: "1" }, timeout }), /timeout/);
  }
});

test("audit storage rejects missing, nested, ancestor and redirected operator roots", t => {
  const root = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const work = join(root, "work");
  mkdirSync(work);
  for (const audit of [undefined, "", "relative", work, join(work, "audit"), root]) {
    assert.throws(() => prepareAuditRoot(work, audit), /absolute|overlap/);
  }
  const alias = join(root, "audit-alias");
  symlinkSync(work, alias, process.platform === "win32" ? "junction" : "dir");
  assert.throws(() => prepareAuditRoot(work, alias), /overlap/);
  const audit = join(root, "native-logs");
  assert.ok(isAbsolute(prepareAuditRoot(work, audit)));
  assert.deepEqual(readdirSync(work), []);
});

test("missing durable audit logs reject before native execution or client startup", async t => {
  let started = false;
  t.mock.method(CopilotSdkExecutor.prototype, "execute", async () => { started = true; });
  const executor = new RestrictedCopilotExecutor(() => { throw new Error("Unexpected client startup"); });
  await assert.rejects(executor.execute({ name: "unit", prompt: "No model call" }, {
    executorConfig: policyConfig(), env: { DO_NOT_TRACK: "1" }, timeout: 1000,
    workDir: resolve("synthetic-work"),
  }), /auditDirectory/);
  assert.equal(started, false);
});

test("restricted execution delegates native options and results unchanged except adapter configuration", async t => {
  const root = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const workDir = join(root, "work");
  mkdirSync(workDir);
  const executor = new RestrictedCopilotExecutor();
  const stimulus = Object.freeze({ name: "unit", prompt: "No model call." });
  const options = Object.freeze({
    env: Object.freeze({ DO_NOT_TRACK: "1" }), timeout: 1000,
    executorConfig: Object.freeze({ ...policyConfig(), auditDirectory: join(root, "audit") }),
    model: "synthetic", workDir, sessionLog: { rootDir: join(root, "audit") },
  });
  const result = Object.freeze({ output: "native result" });
  const delegated = t.mock.method(CopilotSdkExecutor.prototype, "execute", async (input, nativeOptions) => {
    assert.equal(input, stimulus);
    assert.deepEqual(nativeOptions, { ...options, executorConfig: {} });
    assert.equal(nativeOptions.env, options.env);
    return result;
  });
  assert.equal(await executor.execute(stimulus, options), result);
  assert.equal(delegated.mock.callCount(), 1);
  assert.deepEqual(options.executorConfig, { ...policyConfig(), auditDirectory: join(root, "audit") });
  const failure = new Error("native execution failed");
  delegated.mock.mockImplementation(async () => { throw failure; });
  await assert.rejects(executor.execute(stimulus, options), error => error === failure);
  delegated.mock.mockImplementation(async () => { throw undefined; });
  await assert.rejects(executor.execute(stimulus, options), error => error === undefined);
});

test("restricted factories forward native environment and hooks and deny every host request on replacement clients", async t => {
  const workingDirectory = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(workingDirectory, { recursive: true, force: true }));
  const context = new AsyncLocalStorage();
  const config = policyConfig(["view"]);
  config.sessionPolicy.permissions = { allow: ["Read(approved/**)"], deny: ["Shell(*)"] };
  const original = structuredClone(config);
  const creations = [];
  const sessions = [];
  let approvals = 0;
  const factories = restrictedFactories(context, options => {
    creations.push(options);
    return {
      createSession: async options => {
        sessions.push(options);
        return { sessionId: `replacement-${sessions.length}`, rpc: {
          instructions: { getSources: async () => ({ sources: [] }) },
          skills: { list: async () => ({ skills: [] }) }, tools: {
          initializeAndValidate: async () => {},
          getCurrentMetadata: async () => ({ tools: options.availableTools.map(name => ({ name })) }),
        } } };
      },
      stop: async () => "native cleanup",
    };
  });
  assert.throws(() => factories.createClient(), /default clients/);
  assert.throws(() => factories.createEnvClient({}), /active validated execution/);
  const env = Object.freeze({ COPILOT_HOME: "native-owned-home", FLAG: "1" });
  const telemetry = Object.freeze({ otlpEndpoint: "synthetic" });
  const trace = () => ({ traceparent: "synthetic" });
  const input = Object.freeze({ sessionId: "fresh", workingDirectory, onPermissionRequest: () => { approvals++; } });
  const run = { policy: validateSessionPolicy(config), timeoutMs: 1000, inventories: [],
    auditRoot: workingDirectory + "-audit" };
  t.after(() => rmSync(run.auditRoot, { recursive: true, force: true }));
  for (let replacement = 0; replacement < 2; replacement++) {
    const client = context.run(run, () => factories.createEnvClient(env, telemetry, trace));
    await client.createSession(input);
    await assert.rejects(client.resumeSession("old"), /resume/);
    await assert.rejects(client.createSession({ managedSettings: {} }), /conflicting/);
    await assert.rejects(client.createSession({ availableTools: [] }), /conflicting/);
    assert.equal(await client.stop(), "native cleanup");
  }
  assert.equal(creations.length, 2);
  for (const options of creations) {
    assert.deepEqual(options.connection.env, env);
    assert.notEqual(options.connection.env, env);
    assert.equal(options.connection.kind, "stdio");
    assert.match(options.connection.path, /copilot/);
    assert.equal(options.telemetry, telemetry);
    assert.equal(options.onGetTraceContext, trace);
  }
  for (const options of sessions) {
    assert.equal(options.sessionId, "fresh");
    assert.equal(options.enableConfigDiscovery, false);
    assert.equal(options.skipCustomInstructions, true);
    assert.equal(options.enableOnDemandInstructionDiscovery, false);
    assert.equal(options.requestExtensions, false);
    assert.equal(options.enableFileHooks, false);
    assert.equal(options.enableHostGitOperations, false);
    assert.equal(options.enableSessionStore, false);
    assert.equal(options.enableSkills, true);
    assert.deepEqual(options.includedBuiltinSkills, []);
    assert.deepEqual(options.availableTools, ["view"]);
    assert.deepEqual(options.managedSettings.permissions, {
      allow: ["Read(approved/**)"], deny: ["Shell(*)"], disableBypassPermissionsMode: "disable",
    });
    for (const kind of ["read", "write", "shell", "url", "mcp", "custom-tool", "future-kind"]) {
      assert.deepEqual(await options.onPermissionRequest({ kind }), {
        kind: "reject",
      });
    }
    options.availableTools.push("unexpected-mutation");
    options.managedSettings.permissions.allow.push("unexpected-mutation");
  }
  assert.equal(approvals, 0);
  assert.deepEqual(config, original);
  assert.deepEqual(run.policy.availableTools, ["view"]);
  assert.deepEqual(run.policy.permissions.allow, ["Read(approved/**)"]);
  assert.equal(run.inventories.length, 2);
});

test("restricted concurrent factories capture their own policy, including an empty explicit tool set", async t => {
  const workingDirectory = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(workingDirectory, { recursive: true, force: true }));
  const context = new AsyncLocalStorage();
  const received = [];
  const factories = restrictedFactories(context, () => ({
    createSession: async config => {
      await new Promise(resolve => setImmediate(resolve));
      received.push(config);
      return { sessionId: config.sessionId, rpc: {
        instructions: { getSources: async () => ({ sources: [] }) },
        skills: { list: async () => ({ skills: [] }) }, tools: {
        initializeAndValidate: async () => {},
        getCurrentMetadata: async () => ({ tools: config.availableTools.map(name => ({ name })) }),
      } } };
    },
  }));
  await Promise.all([[], ["view"], ["edit"]].map(async (tools, index) => {
    const auditRoot = workingDirectory + "-audit-" + index;
    t.after(() => rmSync(auditRoot, { recursive: true, force: true }));
    const client = await context.run({ policy: validateSessionPolicy(policyConfig(tools)), timeoutMs: 1000,
      auditRoot, inventories: [] }, async () => {
      await new Promise(resolve => setImmediate(resolve));
      return factories.createEnvClient({ RUN: `${index}` });
    });
    await client.createSession({ sessionId: `${index}`, workingDirectory });
  }));
  for (const [index, tools] of [[], ["view"], ["edit"]].entries()) {
    assert.deepEqual(received.find(config => config.sessionId === `${index}`).availableTools, tools);
  }
});

test("restricted policy and scoped inventory backup complete before returning a session", async t => {
  const root = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const context = new AsyncLocalStorage();
  const calls = [];
  const session = {
    sessionId: "policy-and-inventory",
    rpc: {
      instructions: { getSources: async () => ({ sources: [] }) },
      tools: {
        initializeAndValidate: async () => { calls.push("initialize"); },
        getCurrentMetadata: async () => ({ tools: [{ name: "view" }] }),
      },
      skills: { list: async () => { calls.push("skills"); return { skills: [] }; } },
    },
    disconnect: async () => { throw new Error("unexpected disconnect"); },
  };
  let received;
  t.mock.method(CopilotClient.prototype, "createSession", async config => {
    received = config;
    return session;
  });
  const auditRoot = root + "-audit";
  t.after(() => rmSync(auditRoot, { recursive: true, force: true }));
  const run = { policy: validateSessionPolicy(policyConfig(["view"])), timeoutMs: 1000, auditRoot, inventories: [] };
  const factories = restrictedFactories(context, () => Object.create(CopilotClient.prototype));
  const client = context.run(run,
    () => factories.createEnvClient({ DO_NOT_TRACK: "1" }));
  const input = Object.freeze({ workingDirectory: root, skillDirectories: Object.freeze([]) });
  assert.equal(await client.createSession(input), session);
  assert.deepEqual(received.availableTools, ["view"]);
  assert.equal(received.managedSettings.permissions.disableBypassPermissionsMode, "disable");
  assert.equal(received.onPermissionRequest({ kind: "shell" }).kind, "reject");
  assert.equal(input.availableTools, undefined);
  assert.deepEqual(calls, ["initialize", "initialize", "skills"]);
  assert.equal(run.inventories.length, 1);
  const record = JSON.parse(readFileSync(run.inventories[0].file, "utf8"));
  assert.equal(record.phase, "before-first-prompt");
  assert.deepEqual(record.skillDetails.skills, []);
  assert.equal(record.enableConfigDiscovery, false);
  assert.equal(record.skipCustomInstructions, true);
  assert.deepEqual(record.actualTools, ["view"]);
  assert.deepEqual(record.instructionSources, []);
  assert.deepEqual(readdirSync(root), []);
  assert.ok(run.inventories[0].file.startsWith(auditRoot));
  await assert.rejects(client.resumeSession("old"), /resume/);
});

test("runtime connection pins the platform executable and drops host controls without dropping provider configuration", () => {
  const env = Object.freeze({
    PATH: "synthetic-path", COPILOT_HOME: "native-home", CUSTOM_PROVIDER_SETTING: "explicit",
    COPILOT_PROVIDER_TYPE: "explicit-provider", COPILOT_GITHUB_TOKEN: "synthetic-auth",
    COPILOT_CLI_PATH: "ignored-other-runtime", COPILOT_AGENT_SESSION_ID: "parent",
    COPILOT_CLI_RUN_AS_NODE: "1", COPILOT_EXP_COPILOT_CLI_EXECUTION_SUBAGENT: "1",
    COPILOT_EXP_COPILOT_CLI_EXECUTION_SUBAGENT_MODEL: "parent-model",
    NODE_OPTIONS: "--synthetic", NODE_TEST_CONTEXT: "test", copilot_cli: "parent",
  });
  const options = runtimeClientOptions(env);
  assert.equal(options.connection.kind, "stdio");
  assert.ok(isAbsolute(options.connection.path));
  assert.ok(options.connection.path.includes(`copilot-${process.platform}-${process.arch}`));
  for (const key of ["COPILOT_AGENT_SESSION_ID", "COPILOT_CLI_RUN_AS_NODE", "copilot_cli",
    "COPILOT_EXP_COPILOT_CLI_EXECUTION_SUBAGENT", "COPILOT_EXP_COPILOT_CLI_EXECUTION_SUBAGENT_MODEL",
    "NODE_OPTIONS", "NODE_TEST_CONTEXT"]) assert.equal(options.connection.env[key], undefined);
  for (const key of ["PATH", "COPILOT_HOME", "CUSTOM_PROVIDER_SETTING", "COPILOT_PROVIDER_TYPE",
    "COPILOT_GITHUB_TOKEN", "COPILOT_CLI_PATH"]) assert.equal(options.connection.env[key], env[key]);
  assert.equal(env.COPILOT_AGENT_SESSION_ID, "parent");
});

test("skill inventory rejects ambient, missing, duplicate and disabled treatment skills", () => {
  const directory = resolve("synthetic-focus");
  const expected = { name: "focus", enabled: true, path: join(directory, "SKILL.md") };
  verifySkillInventory([], []);
  verifySkillInventory([expected], [directory]);
  for (const [skills, dirs] of [[[expected], []], [[], [directory]],
    [[expected, expected], [directory]], [[{ ...expected, enabled: false }], [directory]],
    [[{ ...expected, path: join(directory, "other.md") }], [directory]]]) {
    assert.throws(() => verifySkillInventory(skills, dirs), /skill inventory/);
  }
});

test("native skill tool omission is allowed only in the no-skill arm and instructions fail closed", async t => {
  const workingDirectory = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(workingDirectory, { recursive: true, force: true }));
  for (const scenario of ["baseline", "treatment", "hidden-treatment", "ambient", "instructions", "instructions-missing"]) {
    const context = new AsyncLocalStorage();
    const dirs = scenario.includes("treatment") ? [join(workingDirectory, "focus")] : [];
    const tools = scenario === "treatment" ? ["view", "skill"] : ["view"];
    let disconnected = false;
    const factories = restrictedFactories(context, () => ({
      createSession: async () => ({ sessionId: scenario, rpc: {
        tools: { initializeAndValidate: async () => {},
          getCurrentMetadata: async () => ({ tools: tools.map(name => ({ name })) }) },
        instructions: { getSources: async () => scenario === "instructions-missing" ? {}
          : { sources: scenario === "instructions" ? [{ id: "unexpected-host" }] : [] } },
        skills: { list: async () => ({ skills: dirs.length || scenario === "ambient"
          ? [{ name: "focus", enabled: true, path: join(workingDirectory, "focus", "SKILL.md") }] : [] }) },
      }, disconnect: async () => { disconnected = true; } }),
    }));
    const auditRoot = workingDirectory + "-audit-" + scenario;
    t.after(() => rmSync(auditRoot, { recursive: true, force: true }));
    const run = { policy: validateSessionPolicy(policyConfig(["view", "skill"])), timeoutMs: 1000, auditRoot, inventories: [] };
    const client = context.run(run, () => factories.createEnvClient({ FLAG: "1" }));
    const operation = () => client.createSession({ workingDirectory, skillDirectories: dirs });
    if (["baseline", "treatment"].includes(scenario)) {
      await operation();
      assert.equal(disconnected, false);
      assert.deepEqual(JSON.parse(readFileSync(run.inventories[0].file)).actualTools, tools);
    } else {
      await assert.rejects(operation(), /native skill tool|skill inventory|instruction inventory/);
      assert.equal(disconnected, true);
    }
  }
});

test("explicit empty client mode retains the instruction guard and private runtime state", async t => {
  const root = mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const mode of ["default", "empty", "empty-unexpected-instructions"]) {
    const work = join(root, mode), auditRoot = join(root, mode + "-audit");
    mkdirSync(work); mkdirSync(auditRoot);
    const context = new AsyncLocalStorage();
    const run = { policy: validateSessionPolicy(policyConfig(["view"])), timeoutMs: 1000,
      auditRoot, inventories: [], ...(mode === "default" ? {} : { clientMode: "empty" }) };
    let options, receivedConfig, disconnected = false;
    const factories = restrictedFactories(context, received => {
      options = received;
      return { createSession: async config => { receivedConfig = config; return { sessionId: mode, rpc: {
        tools: { initializeAndValidate: async () => {},
          getCurrentMetadata: async () => ({ tools: [{ name: "view" }] }) },
        instructions: { getSources: async () => ({ sources: mode.endsWith("unexpected-instructions")
          ? [{ id: "child-instructions" }] : [] }) },
        skills: { list: async () => ({ skills: [] }) },
      }, disconnect: async () => { disconnected = true; } }; } };
    });
    const client = context.run(run, () => factories.createEnvClient({ FLAG: "1" }));
    if (mode.endsWith("unexpected-instructions")) {
      await assert.rejects(client.createSession({ workingDirectory: work }), /empty custom-instruction inventory/);
      assert.equal(disconnected, true);
      assert.equal(run.inventories.length, 0);
    } else {
      await client.createSession({ workingDirectory: work });
      assert.equal(JSON.parse(readFileSync(run.inventories[0].file)).clientMode, mode === "default" ? null : "empty");
    }
    assert.equal(options.mode, mode === "default" ? undefined : "empty");
    if (mode === "default") assert.equal(receivedConfig.systemMessage, undefined);
    else {
      assert.equal(receivedConfig.systemMessage.mode, "customize");
      assert.equal(receivedConfig.systemMessage.sections.environment_context.action, "replace");
      assert.ok(receivedConfig.systemMessage.sections.environment_context.content.includes(JSON.stringify(work)));
      await assert.rejects(client.createSession({ workingDirectory: work, systemMessage: { mode: "replace", content: "other" } }),
        /conflicting system-message environment context/);
      await assert.rejects(client.createSession({ workingDirectory: work, systemMessage: {
        mode: "customize", sections: { environment_context: { action: "remove" } },
      } }), /conflicting system-message environment context/);
    }
    if (mode === "default") assert.equal(options.baseDirectory, undefined);
    else {
      assert.ok(options.baseDirectory.startsWith(auditRoot));
      assert.ok(existsSync(options.baseDirectory));
      assert.equal(options.baseDirectory.startsWith(work + "/"), false);
    }
  }
  for (const clientMode of ["default", "other", null, false, []]) {
    assert.throws(() => validateSessionPolicy({ ...policyConfig([]), clientMode }), /clientMode/);
  }
});

test("restricted preflight rejects unsupported, unexpected and unavailable tool inventories before returning a session", async () => {
  const context = new AsyncLocalStorage();
  for (const tools of [null, undefined, [], [{ name: "shell" }], [{ name: "view" }, { name: "view" }], [{}]]) {
    let disconnected = 0;
    const factories = restrictedFactories(context, () => ({
      createSession: async () => ({
        rpc: { tools: {
          initializeAndValidate: async () => {},
          getCurrentMetadata: async () => ({ tools }),
        } },
        disconnect: async () => { disconnected++; },
      }),
    }));
    const client = context.run({ policy: validateSessionPolicy(policyConfig(["view"])), timeoutMs: 1000 },
      () => factories.createEnvClient({ FLAG: "1" }));
    await assert.rejects(client.createSession({}), /inventory/);
    assert.equal(disconnected, 1);
  }
});

test("restricted startup exceptions and hung RPC or cleanup remain bounded and preserve both errors", { timeout: 3000 }, async () => {
  const context = new AsyncLocalStorage();
  const failure = new Error("native managed-rule validation failed");
  for (const stage of ["creation", "creation-hang", "initialization", "inventory", "disconnect"]) {
    const factories = restrictedFactories(context, () => ({
      createSession: async () => {
        if (stage === "creation") throw failure;
        if (stage === "creation-hang") return new Promise(() => {});
        return {
          rpc: { tools: {
            initializeAndValidate: async () => {
              if (stage === "initialization") return new Promise(() => {});
              if (stage === "disconnect") throw failure;
            },
            getCurrentMetadata: async () => new Promise(() => {}),
          } },
          disconnect: async () => {
            if (stage === "disconnect") return new Promise(() => {});
          },
        };
      },
    }));
    const client = context.run({ policy: validateSessionPolicy(policyConfig()), timeoutMs: 15 },
      () => factories.createEnvClient({ FLAG: "1" }));
    await assert.rejects(client.createSession({}), error => {
      if (stage === "creation") assert.equal(error, failure);
      else if (stage === "disconnect") {
        assert.ok(error instanceof AggregateError);
        assert.equal(error.errors[0], failure);
        assert.match(error.errors[1].message, /disconnect timed out.*shutdown is unverified/);
      } else assert.match(error.message, /timed out.*shutdown is unverified/);
      return true;
    });
  }
});

test("restricted registration checks the exact target stack without starting an SDK client", () => {
  const actual = JSON.parse(readFileSync(findPackageJSON("@microsoft/vally", import.meta.url), "utf8"));
  if (actual.version === "0.19.0") {
    const registered = [];
    registerExecutors({ register: executor => registered.push(executor) });
    assert.equal(registered[0].name, "restricted-copilot-sdk");
  } else {
    assert.throws(() => registerExecutors({ register: () => assert.fail("incompatible stack registered") }),
      /requires @microsoft\/vally 0\.19\.0/);
  }
});

test("generated dry-run needs no process-wide preload and preserves CLI errors", t => {
  const f = fixture(t);
  const help = f.script("study:dry-run", ["--help"]);
  assert.equal(help.status, 0, help.stdout + help.stderr);
  const inventories = join(f.temporary, "inventories");
  const invalid = f.script("study:dry-run", ["--not-a-native-option"], { SKILL_EVAL_INVENTORY_DIR: inventories });
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /unknown option/i);
  assert.equal(existsSync(inventories), false);
  const copilot = JSON.parse(readFileSync(join(runtime, "node_modules", "@github", "copilot", "package.json"), "utf8"));
  assert.equal(copilot.optionalDependencies[`@github/copilot-${process.platform}-${process.arch}`], "1.0.89");
});

test("copied Node preload captures the session before returning it without a launcher", t => {
  const f = fixture(t);
  const prime = f.write("prime-sdk.mjs", `
import { CopilotClient } from "@github/copilot-sdk";
CopilotClient.prototype.createSession = async config => ({
  sessionId: config.sessionId,
  rpc: {
    tools: { initializeAndValidate: async () => {} },
    skills: { list: async () => ({ skills: [{ name: "ambient", enabled: true, path: "fixture/SKILL.md" }] }) }
  }
});
`);
  const inventories = join(f.temporary, "inventories");
  const result = f.run(["--import", pathToFileURL(prime).href, "--import=./scripts/native-inventory.mjs", "--input-type=module", "-e",
    `import assert from "node:assert/strict";
     import { CopilotClient } from "@github/copilot-sdk";
     assert.equal(process.env.SKILL_EVAL_INVENTORY_DIR, undefined);
     await CopilotClient.prototype.createSession.call({}, {sessionId: "copied-session", enableConfigDiscovery: true});`],
  { SKILL_EVAL_INVENTORY_DIR: inventories });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stdout.includes(inventories), false);
  const record = JSON.parse(readFileSync(join(inventories, "copied-session.json"), "utf8"));
  assert.equal(record.sessionId, "copied-session");
  assert.equal(record.enableConfigDiscovery, true);
  assert.deepEqual(record.skillDetails.skills, [{ name: "ambient", enabled: true, path: "fixture/SKILL.md" }]);
});

test("native mock runs preserve identities, task failures and operational errors without a converter", { timeout: 240000 }, t => {
  const f = fixture(t);
  f.spec.defaults.executor = "mock";
  f.experiment.overrides.runs = 2;
  f.write("experiments/task.experiment.yaml", stringify(f.experiment));
  f.spec.agent_environment.files.push({ src: "../fixtures/mock", dest: "." });
  const successful = f.spec.stimuli[0];
  const zero = { type: "run-command", config: { command: process.execPath, args: ["-e", "process.exit(1)"], timeout: "10s" } };
  const emptyError = { type: "program", config: { program: process.execPath, args: ["-e",
    `console.log(JSON.stringify({name:"unavailable",kind:"code",status:"error",passed:false,score:0,evidence:""}))`], timeout: "10s" } };
  const missingChecker = { type: "program", config: { program: join(f.temporary, "missing-runtime.exe"), timeout: "10s" } };
  f.spec.stimuli.push(...[
    ["measured-zero", zero], ["empty-error", emptyError], ["missing-checker", missingChecker],
    ["missing-output", { type: "file-exists", config: { path: "deliverable/missing.txt" } }],
  ].map(([name, grader]) => ({ name, prompt: "Synthetic outcome, no model call.", graders: [grader] })));
  for (const stimulus of f.spec.stimuli) {
    f.write(`fixtures/mock/.mock-executor/${stimulus.name}.json`, JSON.stringify({
      output: "Synthetic result.", events: [{ type: "turn_end", data: {}, timestamp: new Date().toISOString() }],
    }));
  }
  f.write("fixtures/mock/deliverable/result.txt", JSON.stringify({ answer: 42 }));
  f.write("evals/task.eval.yaml", stringify(f.spec));
  const originals = new Map();
  const execute = (name, expectedExit) => {
    const output = join(f.temporary, name);
    const result = f.script("vally", ["experiment", "run", "experiments/task.experiment.yaml", "--param", "AGENT_MODEL=mock",
      "--output-dir", output, "--workspace", join(f.temporary, "workspaces", name), "--workers", "1"],
    { SKILL_EVAL_INVENTORY_DIR: join(f.temporary, "inventories", name) });
    assert.equal(result.status, expectedExit, result.stdout + result.stderr);
    assert.ok(existsSync(output), result.stdout + result.stderr);
    const outputs = files(output);
    assert.ok(outputs.some(file => file.endsWith("report.md")));
    for (const file of outputs.filter(file => file.endsWith(".jsonl"))) originals.set(file, readFileSync(file));
    return outputs.filter(file => file.endsWith(".jsonl")).flatMap(file =>
      readFileSync(file, "utf8").split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line))
        .filter(record => record.type === "trial-result"));
  };
  const records = execute("baseline-first", 1);
  assert.equal(records.length, 20);
  assert.equal(new Set(records.map(record => record.shardKey)).size, 20);
  for (const record of records) {
    assert.ok([0, 1].includes(record.trialIndex));
    assert.ok(["a-baseline", "b-treatment"].includes(record.variant));
    if (record.stimulus === "task") {
      assert.equal(record.gradeResult.passed, true);
      assert.equal(record.trajectory.output, "Synthetic result.");
      continue;
    }
    const detail = record.gradeResult.details[0];
    assert.equal(detail.passed, false);
    if (["empty-error", "missing-checker"].includes(record.stimulus)) {
      assert.equal(detail.status, "error");
      assert.equal(record.gradeResult.status, "error");
      if (record.stimulus === "empty-error") assert.equal(detail.evidence, "");
    } else {
      assert.notEqual(detail.status, "error");
      assert.equal(detail.score, 0);
    }
  }
  assert.deepEqual(records.filter(record => record.stimulus === "task").map(record => record.variant),
    ["a-baseline", "a-baseline", "b-treatment", "b-treatment"]);
  for (const variant of ["a-baseline", "b-treatment"]) {
    assert.deepEqual(records.filter(record => record.stimulus === "task" && record.variant === variant)
      .map(record => record.trialIndex).sort(), [0, 1]);
  }
  f.spec.stimuli = [successful];
  f.write("evals/task.eval.yaml", stringify(f.spec));
  f.experiment.name = "treatment-first";
  f.experiment.overrides.runs = 1;
  f.experiment.baseline = "b-baseline";
  f.experiment.variants = {
    "a-treatment": f.experiment.variants["b-treatment"], "b-baseline": f.experiment.variants["a-baseline"],
  };
  f.write("experiments/task.experiment.yaml", stringify(f.experiment));
  const reversed = execute("treatment-first", 0);
  assert.equal(reversed.length, 2);
  assert.deepEqual(reversed.map(record => record.variant), ["a-treatment", "b-baseline"]);
  assert.ok(reversed.every(record => record.trialIndex === undefined && typeof record.shardKey === "string"));
  assert.ok(reversed.every(record => record.experiment.baseline === "b-baseline"));
  f.spec.stimuli = [{ ...successful, supported_executors: ["copilot-sdk"] }];
  f.write("evals/task.eval.yaml", stringify(f.spec));
  const skippedRecords = execute("unsupported-executor", 0);
  assert.equal(skippedRecords.length, 2);
  assert.ok(skippedRecords.every(record => record.status === "skipped" && record.trajectory === null));
  const bindings = [];
  const gradeOriginal = (record, snapshot, expectedExit = 0) => {
    const index = bindings.length, scratch = join(f.root, "grade-scratch", String(index));
    mkdirSync(scratch, { recursive: true });
    const child = f.script("vally", ["grade", "--eval-spec", "evals/task.grade.eval.yaml",
      "--workspace", scratch, "--assets-dir", join(f.root, "grading/task"),
      "--artifact-dir", snapshot, "--output", "jsonl", "--require-pass"], {}, JSON.stringify(record) + "\n");
    assert.equal(child.status, expectedExit, child.stdout + child.stderr);
    const outcomes = child.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
    assert.equal(outcomes.length, 1);
    const output = f.write(`grade-output/${index}.jsonl`, child.stdout);
    bindings.push({ record, snapshot, output, scratch });
    assert.equal(outcomes[0].runId, record.runId);
    for (const key of ["variant", "itemId", "experiment"]) assert.equal(outcomes[0][key], undefined);
    return outcomes[0];
  };
  const successfulRecords = [...records, ...reversed].filter(record => record.stimulus === "task");
  for (const [index, record] of successfulRecords.entries()) {
    assert.equal(record.gradeResult.passed, true, "original public grade already exists");
    assert.equal(record.status, "success");
    assert.equal(typeof record.workspacePath, "string", "completed native workspace export required");
    assert.equal(record.trajectory.workDir, record.workspacePath);
    const snapshot = join(f.root, "snapshots", String(index));
    f.write(`snapshots/${index}/deliverable/result.txt`,
      readFileSync(join(record.workspacePath, "deliverable/result.txt")));
    const outcome = gradeOriginal(record, snapshot);
    assert.equal(outcome.gradeResult.passed, true);
    assert.equal(outcome.gradeResult.details[0].name, "behavior");
    assert.equal(existsSync(join(bindings.at(-1).scratch, "checker-entered")), true);
  }
  assert.equal(new Set(bindings.map(binding => binding.record.shardKey)).size, successfulRecords.length);
  const wrong = join(f.root, "wrong-snapshot");
  f.write("wrong-snapshot/deliverable/result.txt", JSON.stringify({ answer: 7 }));
  assert.equal(gradeOriginal(successfulRecords[0], wrong, 1).gradeResult.passed, false,
    "an earlier successful public grade must not bypass fresh quality grading");
  // A vanilla native pass cannot authenticate the operator's arm/snapshot pairing.
  assert.notEqual(successfulRecords[0].variant, successfulRecords[2].variant);
  assert.equal(gradeOriginal(successfulRecords[2], bindings[0].snapshot).gradeResult.passed, true);
  const skippedAttempt = skippedRecords[0];
  const skippedOutcome = gradeOriginal(skippedAttempt, bindings[0].snapshot);
  assert.equal(skippedOutcome.status, "skipped");
  assert.equal(skippedOutcome.trajectory, null);
  assert.equal(skippedOutcome.gradeResult, null);
  assert.equal(existsSync(join(bindings.at(-1).scratch, "checker-entered")), false);
  const nullTrajectoryFixture = { ...successfulRecords[0], trajectory: null };
  const echoed = gradeOriginal(nullTrajectoryFixture, bindings[0].snapshot);
  assert.equal(echoed.trajectory, null);
  assert.equal(echoed.gradeResult.details.some(detail => detail.name === "behavior"), false);
  assert.equal(existsSync(join(bindings.at(-1).scratch, "checker-entered")), false);
  assert.equal(new Set(bindings.map(binding => binding.output)).size, bindings.length);
  for (const [file, bytes] of originals) assert.deepEqual(readFileSync(file), bytes);
});

test("native code and prompt graders retain separate outcomes and supply actual artifact evidence", async t => {
  const f = fixture(t);
  const stimulus = f.review.stimuli[0];
  const semantic = stimulus.graders[0];
  f.write("review-inputs/source.txt", "The required answer is 42; prose or a table is acceptable.");
  f.write("grading/task/review-excluded.txt", "PRIVATE-EVALUATOR-MARKER");
  f.write("EVALS.md", "EVALUATOR-NOTES-MARKER");
  f.write("check.mjs", `import { readFileSync } from "node:fs";
if (!readFileSync("deliverable/result.txt", "utf8").includes("42")) process.exit(1);`);
  let calls = 0;
  const judge = new PromptGrader({
    supportsWorkspaceDelivery: true,
    async judge(options) {
      calls++;
      assert.match(options.userMessage, /example/);
      const evidence = options.workspace.evidenceFiles.map(path => readFileSync(path, "utf8")).join("\n");
      assert.match(evidence, /The required answer is 42/);
      assert.match(evidence, /deliverable\/result.txt/);
      assert.doesNotMatch(evidence, /PRIVATE-EVALUATOR-MARKER|EVALUATOR-NOTES-MARKER|check\.mjs/);
      const score = evidence.includes("UNSUPPORTED CONCLUSION") ? 1
        : evidence.includes("LIMITED EXPLANATION") ? 3 : 5;
      return { args: { overall_score: score, overall_reasoning: "Synthetic judge response for wiring only.",
        rubric_scores: stimulus.rubric.map(criterion => ({ criterion, score, reasoning: "Mock assessment." })) },
        latencyMs: 1 };
    },
  });
  for (const [output, codePass, judgePass] of [
    ["The answer is 42.", true, true], ["| Answer | 42 |", true, true],
    ["The answer is 42. LIMITED EXPLANATION", true, true],
    ["The answer is 42. UNSUPPORTED CONCLUSION", true, false],
    ["The answer is 7.", false, true],
  ]) {
    f.write("deliverable/result.txt", output);
    f.write("review-inputs/deliverable/result.txt", output);
    const trajectory = { workDir: f.root, output: "Do not grade only this final message.", events: [], metrics: {} };
    const code = await new RunCommandGrader().grade({ trajectory,
      config: { command: process.execPath, args: ["check.mjs"], expected_exit_code: 0, timeout: "10s" } });
    const review = await judge.grade({
      trajectory: { ...trajectory, workDir: join(f.root, "review-inputs") },
      stimulus, config: { ...semantic.config, model: "mock" },
    });
    assert.equal(code.passed, codePass);
    assert.equal(review.passed, judgePass);
    assert.equal(code.kind, "code");
    assert.equal(review.kind, "llm");
    const combined = { score: (2 + code.score + review.score) / 4, passed: code.passed && review.passed };
    assert.equal(f.spec.scoring.threshold, undefined);
    assert.equal(resolveGradePass(combined, f.spec.scoring.threshold), codePass && judgePass);
  }
  const missing = await judge.grade({
    trajectory: { workDir: join(f.root, "missing"), events: [], metrics: {} },
    stimulus, config: { ...semantic.config, model: "mock" },
  });
  assert.equal(missing.status, "error");
  assert.equal(calls, 5, "missing evidence must not call the judge");
});
