import { describe, it, expect } from "vitest";
import { resolvePort } from "../src/port.js";

describe("resolvePort", () => {
  it("uses PORT when it is a valid port", () => {
    expect(resolvePort({ PORT: "5123" })).toBe(5123);
  });

  it("prefers PORT over RPI_COCKPIT_PORT", () => {
    expect(resolvePort({ PORT: "5123", RPI_COCKPIT_PORT: "6001" })).toBe(5123);
  });

  it("falls back to RPI_COCKPIT_PORT when PORT is absent", () => {
    expect(resolvePort({ RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("falls back to 4399 when neither is set", () => {
    expect(resolvePort({})).toBe(4399);
  });

  it("treats an empty PORT as absent and falls through", () => {
    expect(resolvePort({ PORT: "", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("treats a non-numeric PORT as absent and falls through", () => {
    expect(resolvePort({ PORT: "not-a-port", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("treats PORT=0 as absent and falls through", () => {
    expect(resolvePort({ PORT: "0", RPI_COCKPIT_PORT: "6001" })).toBe(6001);
  });

  it("rejects an out-of-range PORT and falls through to the default", () => {
    expect(resolvePort({ PORT: "70000" })).toBe(4399);
  });

  it("rejects a fractional PORT and falls through to the default", () => {
    expect(resolvePort({ PORT: "8080.5" })).toBe(4399);
  });
});
