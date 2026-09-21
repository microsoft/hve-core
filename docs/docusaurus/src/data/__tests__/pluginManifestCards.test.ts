// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import * as fs from "fs";
import * as path from "path";
import {
  countPluginComponents,
  loadPackageCards,
  summarizePluginComponents,
} from "../pluginManifestCards";
import { labelRegistry } from "../labelRegistry";

const pluginLocatorPath = path.resolve(
  __dirname,
  "../../../../../.github/plugin/marketplace.json",
);

interface PluginManifest {
  name: string;
  description: string;
  version: string;
  [field: string]: unknown;
}

const catalog = JSON.parse(fs.readFileSync(pluginLocatorPath, "utf-8")) as {
  plugins: Array<{ name: string; source: string; version: string }>;
};
const [locator] = catalog.plugins;
const manifestPath = path.resolve(
  __dirname,
  `../../../../../${locator.source}/plugin.json`,
);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf-8")) as PluginManifest;

// Independent re-derivation of the component tally so expected values come from
// the manifest itself rather than from the function under test or a magic number.
const componentFields = ["agents", "commands", "rules", "skills"];
const expectedContents = [
  { field: "agents", kind: "agents", label: "Agents", href: "/docs/reference/agents" },
  { field: "commands", kind: "prompts", label: "Prompts", href: "/docs/reference/prompts" },
  { field: "rules", kind: "instructions", label: "Instructions", href: "/docs/reference/instructions" },
  { field: "skills", kind: "skills", label: "Skills", href: "/docs/reference/skills" },
].flatMap(({ field, ...definition }) => {
  const value = manifest[field];
  const count = typeof value === "string" ? 1 : Array.isArray(value) ? value.length : 0;
  return count === 0 ? [] : [{ ...definition, count }];
});

function expectedComponentCount(entry: PluginManifest): number {
  return componentFields.reduce((total, field) => {
    const value = entry[field];
    if (typeof value === "string") return total + 1;
    if (Array.isArray(value)) return total + value.length;
    return total;
  }, 0);
}

const packageCards = loadPackageCards(pluginLocatorPath);

describe("loadPackageCards against the canonical plugin manifest", () => {
  it("derives one stable card from the locator and plugin manifest", () => {
    expect(packageCards).toEqual([{
      name: locator.name,
      title: labelRegistry.hveCore,
      description: manifest.description,
      href: `/docs/plugins/${locator.name}`,
      maturity: labelRegistry.stable,
      artifacts: expectedComponentCount(manifest),
      contents: expectedContents,
    }]);
  });
});

describe("countPluginComponents", () => {
  it("counts a string component field as one component", () => {
    expect(
      countPluginComponents({ skills: ".github/skills/rpi/rpi-plan" }),
    ).toBe(1);
  });

  it("counts an array component field by its length", () => {
    expect(
      countPluginComponents({ agents: ["a.md", "b.md", "c.md"] }),
    ).toBe(3);
  });

  it("sums every declared component field", () => {
    expect(
      countPluginComponents({
        agents: ["a.md", "b.md"],
        commands: ["c.md"],
        rules: [],
        skills: ["s"],
      }),
    ).toBe(4);
  });

  it("ignores a retired field the manifest no longer declares", () => {
    expect(
      countPluginComponents({
        agents: ["a.md"],
        hooks: "hooks/shared/telemetry.json",
      }),
    ).toBe(1);
  });

  it("ignores fields that are neither a string nor an array", () => {
    expect(
      countPluginComponents({ agents: ["a.md"], version: 3, author: {} }),
    ).toBe(1);
  });

  it("returns zero for an entry with no component fields", () => {
    expect(countPluginComponents({ name: "empty" })).toBe(0);
  });

  it("matches an independent count of the canonical manifest", () => {
    expect(countPluginComponents(manifest)).toBe(expectedComponentCount(manifest));
    expect(countPluginComponents(manifest)).toBeGreaterThan(0);
  });

  it("summarizes non-empty component kinds in display order", () => {
    expect(summarizePluginComponents(manifest)).toEqual(expectedContents);
  });

  it("omits component kinds with no declared entries", () => {
    expect(summarizePluginComponents({
      agents: ["a.md"],
      commands: [],
      rules: null,
      skills: "skill-path",
    })).toEqual([
      { kind: "agents", label: "Agents", count: 1, href: "/docs/reference/agents" },
      { kind: "skills", label: "Skills", count: 1, href: "/docs/reference/skills" },
    ]);
  });
});
