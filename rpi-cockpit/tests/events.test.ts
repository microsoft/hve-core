// rpi-cockpit/tests/events.test.ts
import { describe, it, expect } from "vitest";
import { Beat, OptionItem, InboundDirective, SteerMsg } from "../src/events.js";

describe("events", () => {
  it("parses a valid phase.enter beat", () => {
    const b = Beat.parse({ type: "phase.enter", phase: "implement" });
    expect(b).toEqual({ type: "phase.enter", phase: "implement" });
  });
  it("rejects an unknown phase", () => {
    expect(() => Beat.parse({ type: "phase.enter", phase: "nope" })).toThrow();
  });
  it("parses an option item", () => {
    expect(OptionItem.parse({ id: "b", title: "Token middleware", recommended: true }).id).toBe("b");
  });

  describe("review beats", () => {
    it("parses review.start", () => {
      expect(Beat.safeParse({ type: "review.start", target: "branch x" }).success).toBe(true);
    });
    it("parses finding.add with optional file and line", () => {
      expect(Beat.safeParse({ type: "finding.add", severity: "high", title: "SQL injection", file: "a.ts", line: 12 }).success).toBe(true);
      expect(Beat.safeParse({ type: "finding.add", severity: "low", title: "nit" }).success).toBe(true);
    });
    it("rejects an unknown severity", () => {
      expect(Beat.safeParse({ type: "finding.add", severity: "blocker", title: "x" }).success).toBe(false);
    });
  });
});

it("parses an approaches.offer beat", () => {
  const b = Beat.parse({ type: "approaches.offer", label: "Pick", options: [{ id: "a", title: "A" }] });
  expect(b).toMatchObject({ type: "approaches.offer", label: "Pick" });
});

it("parses an inbound note directive and rejects an empty one", () => {
  expect(InboundDirective.parse({ kind: "note", text: "focus on errors" }).kind).toBe("note");
  expect(() => InboundDirective.parse({ kind: "note", text: "" })).toThrow();
});

it("parses a steer message carrying an approach directive", () => {
  const m = SteerMsg.parse({ type: "steer", directive: { kind: "approach", value: "faster", label: "Move faster" } });
  expect(m.directive).toMatchObject({ kind: "approach", value: "faster" });
});

it("parses a screen.show beat with and without a title", () => {
  expect(Beat.parse({ type: "screen.show", html: "<p>hi</p>", title: "Mockup" })).toMatchObject({
    type: "screen.show", html: "<p>hi</p>", title: "Mockup",
  });
  expect(Beat.parse({ type: "screen.show", html: "<p>hi</p>" })).toMatchObject({ type: "screen.show", html: "<p>hi</p>" });
});

it("rejects a screen.show beat with no html", () => {
  expect(() => Beat.parse({ type: "screen.show", title: "Mockup" })).toThrow();
});

it("parses a screen.clear beat", () => {
  expect(Beat.parse({ type: "screen.clear" })).toEqual({ type: "screen.clear" });
});
