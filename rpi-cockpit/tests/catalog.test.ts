import { describe, it, expect } from "vitest";
import { WORKFLOWS } from "../src/catalog.js";

describe("WORKFLOWS catalog", () => {
  it("has the six front-door workflows", () => {
    expect(WORKFLOWS.map((w) => w.id)).toEqual(["build", "review", "plan", "docs", "data", "coach"]);
  });

  it("gives every workflow a name, hint, description, and intent", () => {
    for (const w of WORKFLOWS) {
      expect(w.name.length).toBeGreaterThan(0);
      expect(w.hint.length).toBeGreaterThan(0);
      expect(w.description.length).toBeGreaterThan(0);
      expect(w.intent.length).toBeGreaterThan(0);
    }
  });

  it("has unique ids", () => {
    expect(new Set(WORKFLOWS.map((w) => w.id)).size).toBe(WORKFLOWS.length);
  });
});
