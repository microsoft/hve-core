// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import * as fs from "fs";
import * as path from "path";
import type { PackageCardData } from "../packageCards";
import {
  countMarketplaceComponents,
  loadPackageCards,
} from "../marketplaceCounts";

const marketplacePath = path.resolve(
  __dirname,
  "../../../../../.github/plugin/marketplace.json",
);

interface MarketplaceEntry {
  name: string;
  description: string;
  "x-hve": { displayName: string; documentation: string; maturity?: string };
  [field: string]: unknown;
}

const catalog = JSON.parse(fs.readFileSync(marketplacePath, "utf-8")) as {
  plugins: MarketplaceEntry[];
};

// Independent re-derivation of the component tally so expected values come from
// the catalog itself rather than from the function under test or a magic number.
const componentFields = ["agents", "commands", "rules", "skills", "hooks"];
function expectedComponentCount(entry: MarketplaceEntry): number {
  return componentFields.reduce((total, field) => {
    const value = entry[field];
    if (typeof value === "string") return total + 1;
    if (Array.isArray(value)) return total + value.length;
    return total;
  }, 0);
}

const retired = new Set(["deprecated", "removed"]);
const expectedLabels: Record<string, PackageCardData["maturity"]> = {
  stable: "Stable",
  preview: "Preview",
  experimental: "Experimental",
};
const activeEntries = catalog.plugins.filter(
  (entry) => !retired.has(entry["x-hve"]?.maturity ?? "stable"),
);
const packageCards = loadPackageCards(marketplacePath);
const cardsByName = new Map(packageCards.map((card) => [card.name, card]));

describe("loadPackageCards against the canonical catalog", () => {
  it("produces one sorted unique card for every active entry", () => {
    const expected = activeEntries.map((entry) => entry.name).sort();
    expect(packageCards.map((card) => card.name)).toEqual(expected);
    expect(new Set(packageCards.map((card) => card.name)).size).toBe(
      packageCards.length,
    );
  });

  it.each(
    activeEntries.map((entry): [string, MarketplaceEntry] => [
      entry.name,
      entry,
    ]),
  )("%s derives all card fields from its catalog entry", (name, entry) => {
    const card = cardsByName.get(name)!;
    expect(card.title).toBe(entry["x-hve"].displayName);
    expect(card.description).toBe(entry.description);
    expect(card.href).toBe(`/docs/plugins/${name}`);
    expect(card.maturity).toBe(
      expectedLabels[entry["x-hve"].maturity ?? "stable"],
    );
    expect(card.artifacts).toBe(expectedComponentCount(entry));
    expect(card.artifacts).toBeGreaterThan(0);
  });
});

describe("countMarketplaceComponents", () => {
  it("counts a string component field as one component", () => {
    expect(
      countMarketplaceComponents({ hooks: "hooks/shared/telemetry.json" }),
    ).toBe(1);
  });

  it("counts an array component field by its length", () => {
    expect(
      countMarketplaceComponents({ agents: ["a.md", "b.md", "c.md"] }),
    ).toBe(3);
  });

  it("sums every declared component field", () => {
    expect(
      countMarketplaceComponents({
        agents: ["a.md", "b.md"],
        commands: ["c.md"],
        rules: [],
        skills: ["s"],
        hooks: "hooks/shared/telemetry.json",
      }),
    ).toBe(5);
  });

  it("ignores fields that are neither a string nor an array", () => {
    expect(
      countMarketplaceComponents({ agents: ["a.md"], version: 3, author: {} }),
    ).toBe(1);
  });

  it("returns zero for an entry with no component fields", () => {
    expect(countMarketplaceComponents({ name: "empty" })).toBe(0);
  });

  it("counts a catalog package that declares hooks as a single string", () => {
    const withStringHooks = catalog.plugins.filter(
      (entry) => typeof entry.hooks === "string",
    );
    expect(withStringHooks.length).toBeGreaterThan(0);

    for (const entry of withStringHooks) {
      const withoutHooks = { ...entry, hooks: undefined };
      expect(countMarketplaceComponents(entry)).toBe(
        countMarketplaceComponents(withoutHooks) + 1,
      );
    }
  });
});
