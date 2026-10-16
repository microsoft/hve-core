// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { cpSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const assets = dirname(fileURLToPath(import.meta.url));
const skillRoot = resolve(assets, "..");
const read = name => readFileSync(join(assets, name), "utf8");

test("generated commands invoke native Vally directly and only execution preloads capture", () => {
  const pkg = JSON.parse(read("package.template.json"));
  const cli = "node_modules/@microsoft/vally-cli/dist/index.js";
  assert.equal(pkg.engines.node, ">=24");
  assert.equal(pkg.scripts.vally, `node ${cli}`);
  assert.equal(pkg.scripts["study:dry-run"], `node ${cli} experiment run --dry-run`);
  assert.equal(pkg.scripts["study:run"], `node --import ./scripts/native-inventory.mjs ${cli} experiment run`);
  assert.equal(pkg.scripts["review:images"], "node scripts/review-images.mjs");
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
  assert.equal(local.scripts.test, "node --test assets/*.test.mjs");
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

test("the recorder and native executor share the pinned Copilot runtime", () => {
  const local = JSON.parse(readFileSync(join(skillRoot, "package.json"), "utf8"));
  const native = JSON.parse(readFileSync(join(skillRoot, "node_modules", "@microsoft", "vally", "package.json"), "utf8"));
  assert.equal(native.version, local.devDependencies["@microsoft/vally"]);
  for (const name of ["@github/copilot", "@github/copilot-sdk"]) {
    assert.equal(native.dependencies[name], local.devDependencies[name]);
  }
});

test("the transferable package has only declared content and two small runtime helpers", () => {
  const files = readdirSync(skillRoot).filter(name => !["node_modules", "assets", "references", "coverage-node.info"].includes(name)
    && !name.startsWith(".native-package-test-"));
  files.push(...readdirSync(assets).map(name => `assets/${name}`),
    ...readdirSync(join(skillRoot, "references")).map(name => `references/${name}`));
  assert.deepEqual(files.sort(), [
    ".gitignore", ".npmrc", "SKILL.md", "SECURITY.md", "package.json", "package-lock.json",
    "assets/EVALS.template.md", "assets/native-eval.template.yaml", "assets/native-experiment.template.yaml",
    "assets/native-inventory.mjs", "assets/native-inventory.test.mjs", "assets/native-templates.test.mjs",
    "assets/package.template.json", "assets/skill-package-architecture.test.mjs",
    "assets/review-images.mjs", "assets/review-images.test.mjs",
    "references/experiment-method.md", "references/holistic-review.md",
    "references/repository-intake.md", "references/visual-review.md",
  ].sort());
  const npmrc = readFileSync(join(skillRoot, ".npmrc"), "utf8");
  assert.match(npmrc, /^registry=https:\/\/registry\.npmjs\.org\/$/m);
  assert.match(npmrc, /^ignore-scripts=true$/m);
  assert.deepEqual(files.filter(name => name.endsWith(".mjs") && !name.endsWith(".test.mjs")).sort(),
    ["assets/native-inventory.mjs", "assets/review-images.mjs"]);
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

  const standalone = mkdtempSync(join(tmpdir(), "skill-effectiveness-docs-"));
  t.after(() => rmSync(standalone, { recursive: true, force: true }));
  for (const name of [".gitignore", ".npmrc", "SKILL.md", "SECURITY.md", "package.json", "package-lock.json",
    "assets", "references"]) {
    cpSync(join(skillRoot, name), join(standalone, name), { recursive: true });
  }
  checkLinks(standalone);

  const copiedSkill = join(standalone, "SKILL.md");
  writeFileSync(copiedSkill, `${skill}\n[Missing internal document](references/missing.md)\n`);
  assert.throws(() => checkLinks(standalone), /missing references\/missing\.md/);
});
