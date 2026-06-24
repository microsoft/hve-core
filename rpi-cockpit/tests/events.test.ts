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
