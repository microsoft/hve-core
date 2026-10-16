// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parse, stringify } from "yaml";
import { PromptGrader, RunCommandGrader, resolveGradePass } from "@microsoft/vally";

const assets = dirname(fileURLToPath(import.meta.url));
const runtime = resolve(assets, "..");
const read = name => readFileSync(join(assets, name), "utf8");
const fill = text => text.replace(/<[^>\r\n]+>/g, value => ({
  "<task>": "task", "<task-name>": "task", "<candidate-skill>": "demo",
  "<artifact>": "result.txt", "<experiment-name>": "baseline-first",
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
  copyFileSync(join(assets, "native-inventory.mjs"), join(root, "scripts", "native-inventory.mjs"));
  copyFileSync(join(assets, "review-images.mjs"), join(root, "scripts", "review-images.mjs"));
  write("skills/demo/SKILL.md", "---\nname: demo\ndescription: Local fixture.\n---\nCheck your work.\n");
  write("fixtures/task/request.txt", "Create deliverable/result.txt. Synthetic test input.");
  write("fixtures/task/check.mjs", `import { readFileSync } from "node:fs";
if (!readFileSync(process.argv[2], "utf8").trim()) process.exit(1);`);
  const spec = parse(fill(read("native-eval.template.yaml")));
  const experiment = parse(fill(read("native-experiment.template.yaml")));
  write("evals/task.eval.yaml", stringify(spec));
  write("experiments/task.experiment.yaml", stringify(experiment));
  const environment = { ...process.env, DO_NOT_TRACK: "1", VALLY_TELEMETRY_OPTOUT: "1" };
  for (const key of ["NODE_OPTIONS", "SKILL_EVAL_INVENTORY_DIR", "SKILL_EVAL_INVENTORY_PACKAGE",
    "EVALUATE_USE_HOST_COPILOT_HOME", "COPILOT_HOME_SETTINGS_JSON", "NODE_TEST_CONTEXT"]) delete environment[key];
  const run = (args, env = {}) => {
    const child = spawnSync(process.execPath, args, {
      cwd: root, env: { ...environment, ...env }, encoding: "utf8", timeout: 90000, maxBuffer: 4 * 1024 * 1024,
    });
    assert.ifError(child.error);
    return child;
  };
  const scripts = JSON.parse(readFileSync(join(root, "package.json"), "utf8")).scripts;
  const script = (name, args, env) => {
    const [node, ...command] = scripts[name].split(" ");
    assert.equal(node, "node");
    return run([...command, ...args], env);
  };
  return { root, temporary, write, spec, experiment, run, script };
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
    ["completed", "file-exists", "run-command", "prompt"]);
  assert.deepEqual(f.spec.stimuli[0].graders.at(-1).config.evidence, ["repo"]);
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
      "--param", "JUDGE_MODEL=mock",
      "--output-dir", output, "--workspace", join(f.temporary, "workspaces", experiment.name)]);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(experiment.name));
  }
  assert.equal(existsSync(join(f.root, "inventories")), false);
  assert.equal(existsSync(join(f.root, "RESULTS.md")), false);
});

test("native execution preload requires an absolute evidence directory and preserves CLI errors", t => {
  const f = fixture(t);
  for (const directory of [undefined, "relative-evidence"]) {
    const result = f.script("study:run", ["--help"], directory ? { SKILL_EVAL_INVENTORY_DIR: directory } : {});
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /SKILL_EVAL_INVENTORY_DIR must be an absolute evidence directory/);
  }
  const inventories = join(f.temporary, "inventories");
  const invalid = f.script("study:run", ["--not-a-native-option"], { SKILL_EVAL_INVENTORY_DIR: inventories });
  assert.notEqual(invalid.status, 0);
  assert.match(invalid.stderr, /unknown option/i);
  assert.deepEqual(readdirSync(inventories), []);
  const copilot = JSON.parse(readFileSync(join(runtime, "node_modules", "@github", "copilot", "package.json"), "utf8"));
  assert.equal(copilot.optionalDependencies[`@github/copilot-${process.platform}-${process.arch}`], "1.0.85");
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
    `import { CopilotClient } from "@github/copilot-sdk";
     await CopilotClient.prototype.createSession.call({}, {sessionId: "copied-session", enableConfigDiscovery: true});`],
  { SKILL_EVAL_INVENTORY_DIR: inventories });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const record = JSON.parse(readFileSync(join(inventories, "copied-session.json"), "utf8"));
  assert.equal(record.sessionId, "copied-session");
  assert.equal(record.enableConfigDiscovery, true);
  assert.deepEqual(record.skillDetails.skills, [{ name: "ambient", enabled: true, path: "fixture/SKILL.md" }]);
});

test("native mock runs preserve identities, task failures and operational errors without a converter", { timeout: 120000 }, t => {
  const f = fixture(t);
  f.spec.defaults.executor = "mock";
  f.spec.stimuli[0].graders = f.spec.stimuli[0].graders.filter(grader => grader.type !== "prompt");
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
  f.write("fixtures/mock/deliverable/result.txt", "Synthetic output staged for native delivery checks.");
  f.write("evals/task.eval.yaml", stringify(f.spec));
  const execute = (name, expectedExit) => {
    const output = join(f.temporary, name);
    const result = f.script("study:run", ["experiments/task.experiment.yaml", "--param", "AGENT_MODEL=mock",
      "--output-dir", output, "--workspace", join(f.temporary, "workspaces", name), "--workers", "1"],
    { SKILL_EVAL_INVENTORY_DIR: join(f.temporary, "inventories", name) });
    assert.equal(result.status, expectedExit, result.stdout + result.stderr);
    const outputs = files(output);
    assert.ok(outputs.some(file => file.endsWith("report.md")));
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
});

test("native code and prompt graders retain separate outcomes and supply actual artifact evidence", async t => {
  const f = fixture(t);
  const stimulus = f.spec.stimuli[0];
  const semantic = stimulus.graders.find(grader => grader.type === "prompt");
  f.write("source.txt", "The required answer is 42; prose or a table is acceptable.");
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
    const trajectory = { workDir: f.root, output: "Do not grade only this final message.", events: [], metrics: {} };
    const code = await new RunCommandGrader().grade({ trajectory,
      config: { command: process.execPath, args: ["check.mjs"], expected_exit_code: 0, timeout: "10s" } });
    const review = await judge.grade({ trajectory, stimulus, config: { ...semantic.config, model: "mock" } });
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
