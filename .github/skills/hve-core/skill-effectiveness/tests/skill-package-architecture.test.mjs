// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { cpSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const assets = join(skillRoot, "assets");
const read = name => readFileSync(join(assets, name), "utf8");

test("generated commands retain native dry-run and CLI access without paid convenience aliases", () => {
  const pkg = JSON.parse(read("package.template.json"));
  const cli = "node_modules/@microsoft/vally-cli/dist/index.js";
  assert.equal(pkg.engines.node, ">=24");
  assert.equal(pkg.scripts.vally, `node ${cli}`);
  const plugin = "--executor-plugin ../scripts/restricted-copilot-executor.mjs";
  assert.equal(pkg.scripts["study:dry-run"], `node ${cli} experiment run --dry-run ${plugin}`);
  assert.deepEqual(Object.keys(pkg.scripts).sort(), ["study:dry-run", "vally"]);
  assert.equal(Object.hasOwn(pkg.scripts, "study:run"), false);
  assert.equal(Object.hasOwn(pkg.scripts, "review:images"), false);
});

test("shipped instructions disclose paid-alias omission without claiming spending enforcement", () => {
  for (const file of ["SKILL.md", "references/experiment-method.md", "references/visual-review.md"]) {
    const text = readFileSync(join(skillRoot, file), "utf8");
    assert.doesNotMatch(text, /npm run (?:study:run|review:images)\b/);
    assert.match(text, /omit/);
    assert.match(text, /manual/);
    assert.match(text, /(?:does not|not a).*spending (?:ceiling|cap)/);
  }
  assert.ok(existsSync(join(skillRoot, "scripts", "review-images.mjs")));
  assert.ok(existsSync(join(skillRoot, "scripts", "restricted-copilot-executor.mjs")));
});

test("local pins, generated pins and lockfile agree without direct server duplication", () => {
  const local = JSON.parse(readFileSync(join(skillRoot, "package.json"), "utf8"));
  const lock = JSON.parse(readFileSync(join(skillRoot, "package-lock.json"), "utf8"));
  assert.deepEqual(local.devDependencies, JSON.parse(read("package.template.json")).devDependencies);
  assert.deepEqual(local.overrides, JSON.parse(read("package.template.json")).overrides);
  assert.deepEqual(lock.packages[""].devDependencies, local.devDependencies);
  assert.equal(local.devDependencies["@microsoft/vally-server"], undefined);
  for (const [name, version] of Object.entries(local.devDependencies)) {
    assert.match(version, /^\d+\.\d+\.\d+$/);
    assert.equal(lock.packages[`node_modules/${name}`].version, version);
  }
  for (const [name, entry] of Object.entries(lock.packages)) {
    if (!name) continue;
    if (entry.resolved !== undefined) {
      const url = new URL(entry.resolved);
      assert.equal(url.protocol, "https:");
      assert.equal(url.hostname, "registry.npmjs.org", `${name}: canonical public registry`);
      assert.equal(url.username, "");
      assert.equal(url.password, "");
    }
    assert.match(entry.integrity, /^sha512-/, `${name}: SHA-512 integrity required`);
  }
  assert.equal(local.engines.node, ">=24");
});

test("standalone license matches the canonical notice and tests use the supported layout", () => {
  assert.deepEqual(readFileSync(join(skillRoot, "LICENSE")),
    readFileSync(resolve(skillRoot, "..", "..", "..", "..", "LICENSE")));
  assert.equal(JSON.parse(readFileSync(join(skillRoot, "package.json"), "utf8")).scripts.test,
    "node --test tests/*.test.mjs");
});

test("copied materials retain scoped licensing without licensing independently authored outputs", t => {
  const notice = readFileSync(join(skillRoot, "NOTICE"), "utf8");
  assert.match(notice, /Copyright \(c\) Microsoft Corporation/);
  assert.ok(notice.includes("https://github.com/microsoft/hve-core/tree/main/.github/skills/hve-core/skill-effectiveness"));
  assert.ok(notice.includes("https://creativecommons.org/licenses/by/4.0/"));
  assert.match(notice, /LICENSE contains the MIT terms/);
  assert.match(notice, /Indicate changes/);
  assert.match(notice, /not automatically to\s+operator-authored/);
  assert.equal(JSON.parse(read("package.template.json")).license, undefined);
  const notes = read("EVALS.template.md");
  assert.match(notes, /Microsoft HVE Core evaluation-notes template/);
  assert.match(notes, /CC BY 4\.0/);
  assert.match(notes, /record changes to copied template material/);
  const skill = readFileSync(join(skillRoot, "SKILL.md"), "utf8");
  assert.match(skill, /\[License allocation and attribution\]\(NOTICE\)\s*\|\s*`NOTICE`/);
  const generated = mkdtempSync(join(tmpdir(), "skill-effectiveness-licenses-"));
  t.after(() => rmSync(generated, { recursive: true, force: true }));
  for (const file of ["LICENSE", "NOTICE"]) cpSync(join(skillRoot, file), join(generated, file));
  writeFileSync(join(generated, "EVALS.md"), notes);
  assert.equal(readFileSync(join(generated, "NOTICE"), "utf8"), notice);
  assert.match(readFileSync(join(generated, "EVALS.md"), "utf8"), /CC BY 4\.0/);
});

test("locked MCP and OpenTelemetry dependencies include the advisory fixes", () => {
  const lock = JSON.parse(readFileSync(join(skillRoot, "package-lock.json"), "utf8"));
  for (const [name, major, minor] of [
    ["@modelcontextprotocol/sdk", 1, 31],
    ["@opentelemetry/core", 2, 8],
  ]) {
    const entries = Object.entries(lock.packages).filter(([key]) => key.endsWith(`node_modules/${name}`));
    assert.ok(entries.length > 0, `${name}: dependency must be present`);
    for (const [key, entry] of entries) {
      assert.match(entry.version, /^\d+\.\d+\.\d+$/);
      const [actualMajor, actualMinor] = entry.version.split(".").map(Number);
      assert.ok(actualMajor > major || (actualMajor === major && actualMinor >= minor),
        `${key}: ${entry.version} predates the advisory fix`);
    }
  }
});

test("the recorder and native executor resolve the same pinned SDK and the separate CLI pin is installed", () => {
  const local = JSON.parse(readFileSync(join(skillRoot, "package.json"), "utf8"));
  const nativeManifest = join(skillRoot, "node_modules", "@microsoft", "vally", "package.json");
  const native = JSON.parse(readFileSync(nativeManifest, "utf8"));
  assert.equal(native.version, local.devDependencies["@microsoft/vally"]);
  assert.equal(native.dependencies["@github/copilot-sdk"], local.devDependencies["@github/copilot-sdk"]);
  assert.equal(createRequire(nativeManifest).resolve("@github/copilot-sdk"),
    createRequire(join(skillRoot, "package.json")).resolve("@github/copilot-sdk"));
  for (const name of ["@github/copilot", "@github/copilot-sdk"]) {
    const installed = JSON.parse(readFileSync(join(skillRoot, "node_modules", ...name.split("/"), "package.json"), "utf8"));
    assert.equal(installed.version, local.devDependencies[name]);
  }
});

test("the transferable package has only declared helpers, policy plugin and optional native profile", () => {
  const files = readdirSync(skillRoot).filter(name => !["node_modules", "assets", "references", "scripts", "tests", "coverage-node.info"].includes(name)
    && !name.startsWith(".native-package-test-"));
  files.push(...readdirSync(assets).map(name => `assets/${name}`),
    ...readdirSync(join(skillRoot, "scripts")).map(name => `scripts/${name}`),
    ...readdirSync(join(skillRoot, "tests")).map(name => `tests/${name}`),
    ...readdirSync(join(skillRoot, "references")).map(name => `references/${name}`));
  assert.deepEqual(files.sort(), [
    ".gitignore", ".npmrc", "LICENSE", "NOTICE", "SKILL.md", "SECURITY.md", "package.json", "package-lock.json",
    "assets/EVALS.template.md", "assets/native-eval.template.yaml", "assets/native-experiment.template.yaml",
    "assets/native-grade-eval.template.yaml", "assets/native-review-eval.template.yaml",
    "assets/package.template.json",
    "references/experiment-method.md", "references/first-evaluation.md", "references/holistic-review.md",
    "references/repository-intake.md", "references/visual-review.md",
    "scripts/native-inventory.mjs", "scripts/review-images.mjs", "scripts/restricted-copilot-executor.mjs",
    "scripts/native-windows-sandbox.mjs",
    "tests/native-inventory.test.mjs", "tests/review-images.test.mjs", "tests/evidence-backup.test.mjs",
    "tests/native-runtime.test.mjs",
    "tests/native-windows-sandbox.test.mjs",
    "tests/native-linux-rendering.test.mjs",
    "tests/native-templates.test.mjs", "tests/skill-package-architecture.test.mjs",
  ].sort());
  const npmrc = readFileSync(join(skillRoot, ".npmrc"), "utf8");
  assert.match(npmrc, /^registry=https:\/\/registry\.npmjs\.org\/$/m);
  assert.match(npmrc, /^ignore-scripts=true$/m);
  assert.deepEqual(files.filter(name => name.endsWith(".mjs") && !name.endsWith(".test.mjs")).sort(),
    ["scripts/native-inventory.mjs", "scripts/native-windows-sandbox.mjs",
      "scripts/restricted-copilot-executor.mjs", "scripts/review-images.mjs"]);
});

test("first-use walkthrough defines a native skill-only pair and stops at model-free planning", () => {
  const guide = readFileSync(join(skillRoot, "references", "first-evaluation.md"), "utf8");
  const inventory = JSON.parse(guide.match(/```json\r?\n([\s\S]*?)```/)[1]);
  assert.equal(inventory.datasets.length, 2);
  assert.equal(inventory.datasets[1].owner, null);
  assert.equal(inventory.datasets[1].access, "unknown");
  const pair = parse(guide.match(/```yaml\r?\n([\s\S]*?)```/)[1]);
  assert.deepEqual(pair.evals, ["../evals/catalog.eval.yaml"]);
  assert.deepEqual(pair.vary, ["/environment/skills"]);
  assert.equal(pair.baseline, "a-baseline");
  assert.deepEqual(pair.variants["a-baseline"].environment.skills, []);
  assert.deepEqual(pair.variants["b-treatment"].environment.skills, ["../skills/data-catalog"]);
  assert.deepEqual(pair.execution, { workers: 1 });
  assert.deepEqual(pair.overrides, { runs: 1 });
  assert.match(guide, /npm run vally -- lint --strict --eval-spec evals\/catalog\.eval\.yaml/);
  assert.match(guide, /npm run study:dry-run -- experiments\/catalog\.experiment\.yaml --param AGENT_MODEL=mock/);
  assert.doesNotMatch(guide, /npm run (?:study:run|review:images)\b/);
  assert.match(guide, /\[restricted execution profile\]\(experiment-method\.md#restricted-execution-profile\)/);
  assert.match(guide, /\[supervised run policy\]\(experiment-method\.md#execute-an-approved-run-plan\)/);
});

test("skill metadata and shipped documentation links remain valid in a standalone copy", t => {
  const skill = readFileSync(join(skillRoot, "SKILL.md"), "utf8");
  const frontmatter = parse(skill.match(/^---\r?\n([\s\S]*?)\r?\n---/)[1]);
  assert.equal(frontmatter.name, "skill-effectiveness");
  assert.equal(frontmatter.license, "MIT AND CC-BY-4.0");
  assert.equal(frontmatter["user-invocable"], true);
  assert.ok(frontmatter.description.startsWith("Use when"));
  const documents = ["SKILL.md", "SECURITY.md", "assets/EVALS.template.md",
    ...readdirSync(join(skillRoot, "references")).map(name => `references/${name}`)];
  const checkLinks = root => {
    for (const name of documents) {
      const file = join(root, name);
      for (const match of readFileSync(file, "utf8").matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
        if (/^[a-z]+:/i.test(match[1]) || match[1].startsWith("#")) continue;
        assert.ok(existsSync(resolve(dirname(file), match[1].split("#")[0])), `${file}: missing ${match[1]}`);
      }
    }
  };
  checkLinks(skillRoot);
  const checkPolicyActivation = intake => {
    const activationStart = intake.indexOf("### Required Policy Activation");
    const sourceStart = intake.indexOf("### Source-Grounded Candidate");
    assert.ok(activationStart >= 0 && activationStart < sourceStart, "policy activation must precede source inspection");
    const activation = intake.slice(activationStart, sourceStart);
    const link = activation.match(/\[canonical untrusted-content instruction\]\((https:[^)]+)\)/);
    assert.ok(link, "intake requires the canonical public policy link");
    const url = new URL(link[1]);
    assert.equal(url.hostname, "raw.githubusercontent.com");
    assert.match(url.pathname, /^\/microsoft\/hve-core\/[a-f0-9]{40}\/\.github\/instructions\/shared\/untrusted-content-boundary\.instructions\.md$/);
    assert.match(activation, /Before reading target repository files[\s\S]*read\s+the complete/);
    assert.match(activation, /and apply it to this intake/);
    assert.match(activation, /Do not assume automatic activation/);
    assert.match(activation, /If the canonical instruction is unavailable[\s\S]*stop repository intake/);
    assert.match(activation, /Record the resolved policy URL, full commit revision and activation date in\s+`EVALS\.md`/);
    assert.doesNotMatch(activation, /#file:|\.\.\/\.\.\/instructions/);
    return link[1];
  };
  checkPolicyActivation(readFileSync(join(skillRoot, "references", "repository-intake.md"), "utf8"));

  const standalone = mkdtempSync(join(tmpdir(), "skill-effectiveness-docs-"));
  t.after(() => rmSync(standalone, { recursive: true, force: true }));
  for (const name of [".gitignore", ".npmrc", "LICENSE", "NOTICE", "SKILL.md", "SECURITY.md", "package.json", "package-lock.json",
    "assets", "references", "scripts", "tests"]) {
    cpSync(join(skillRoot, name), join(standalone, name), { recursive: true });
  }
  checkLinks(standalone);
  assert.deepEqual(readFileSync(join(standalone, "LICENSE")), readFileSync(join(skillRoot, "LICENSE")));
  assert.deepEqual(readFileSync(join(standalone, "NOTICE")), readFileSync(join(skillRoot, "NOTICE")));
  const standaloneIntake = readFileSync(join(standalone, "references", "repository-intake.md"), "utf8");
  const canonicalPolicy = checkPolicyActivation(standaloneIntake);
  assert.throws(() => checkPolicyActivation(standaloneIntake.replace(canonicalPolicy, "https://example.invalid/policy")));
  assert.throws(() => checkPolicyActivation(standaloneIntake.replace("stop repository intake", "continue repository intake")));
  assert.throws(() => checkPolicyActivation(`[canonical untrusted-content instruction](${canonicalPolicy})`));
  assert.equal(readFileSync(join(standalone, "scripts", "restricted-copilot-executor.mjs"), "utf8"),
    readFileSync(join(skillRoot, "scripts", "restricted-copilot-executor.mjs"), "utf8"));
  assert.equal(readFileSync(join(standalone, "assets", "native-review-eval.template.yaml"), "utf8"),
    read("native-review-eval.template.yaml"));
  const experiment = parse(read("native-experiment.template.yaml"));
  const evaluation = parse(read("native-eval.template.yaml"));
  assert.equal(experiment.executor_plugins, undefined);
  assert.deepEqual(experiment.vary, ["/environment/skills"]);
  assert.equal(evaluation.defaults.executor.name, "restricted-copilot-sdk");
  assert.deepEqual(evaluation.defaults.executor.config.sessionPolicy,
    { availableTools: [], permissions: { allow: [], deny: [] } });
  assert.deepEqual(evaluation.agent_environment.env, { DO_NOT_TRACK: "1" });

  const copiedSkill = join(standalone, "SKILL.md");
  writeFileSync(copiedSkill, `${skill}\n[Missing internal document](references/missing.md)\n`);
  assert.throws(() => checkLinks(standalone), /missing references\/missing\.md/);
});

test("evidence notes persist claim decisions and route nonvisual accessibility beyond screenshot review", () => {
  const notes = read("EVALS.template.md");
  for (const field of ["Claim", "Affected users", "Method", "Sources", "Good / poor outcomes",
    "Valid alternatives", "Unknowns", "Approval", "Not applicable"]) {
    assert.match(notes, new RegExp(`^\\|\\s*${field}\\s*\\|`, "m"));
  }
  assert.match(notes, /`Not applicable` requires a scope-specific rationale/);
  assert.match(notes, /Use `Unknown` for missing evidence, not a pass/);
  assert.match(notes, /canonical policy's resolved URL, full commit\s+revision and activation date before source inspection/);
  const visual = readFileSync(join(skillRoot, "references", "visual-review.md"), "utf8");
  assert.match(visual, /Screenshot review decides visible properties only/);
  assert.match(visual, /activate the `accessibility` skill/);
  assert.match(visual, /https:\/\/github\.com\/microsoft\/hve-core\/blob\/main\/\.github\/skills\/accessibility\/accessibility\/SKILL\.md#method-adequacy-decide-vs-inform/);
  assert.match(visual, /mark the claim unmeasured or unknown/);
  assert.match(visual, /Human visual inspection remains supported/);
  assert.match(visual, /ask the user to run `\/accessibility-coverage-matrix`;\s+it is manual-only/);
  assert.match(visual, /does not authorize browser, screen-reader,\s+service or paid model startup/);
});

test("platform and split-toolchain guidance preserve equal candidate capabilities and full offline evidence", () => {
  const skill = readFileSync(join(skillRoot, "SKILL.md"), "utf8");
  const method = readFileSync(join(skillRoot, "references", "experiment-method.md"), "utf8");
  const notes = read("EVALS.template.md");
  assert.match(skill, /generic adapter are cross-platform/);
  assert.match(skill, /windows-native` profile is Windows-only/);
  assert.match(method, /importing its helper does not\s+activate it/);
  assert.match(method, /Obtain approval if this changes the agreed candidate tool profile/);
  assert.match(method, /Update both\s+arms' task\/tool declarations equally/);
  assert.match(method, /offline execution is not a file-only substitute/);
  assert.match(method, /does not authorize disabling a browser sandbox/);
  assert.match(notes, /candidate and offline-grader toolchains separately/);
  assert.match(notes, /Pin the original\s+prompts and the changed tool disclosures separately/);
});
