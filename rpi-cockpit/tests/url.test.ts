// rpi-cockpit/tests/url.test.ts
import { describe, it, expect } from "vitest";
import { isLoopbackHttpUrl } from "../src/url.js";

describe("isLoopbackHttpUrl", () => {
  it("accepts loopback http(s) URLs", () => {
    for (const url of [
      "http://localhost",
      "http://localhost:3000/x",
      "http://127.0.0.1:8080",
      "https://localhost",
      "http://[::1]:9229",
    ]) {
      expect(isLoopbackHttpUrl(url)).toBe(true);
    }
  });

  it("rejects non-loopback, non-http, and malformed URLs", () => {
    for (const url of [
      "http://evil.com",
      "https://example.com",
      "http://localhost.evil.com",
      "javascript:alert(1)",
      "file:///x",
      "not a url",
      "ftp://localhost",
    ]) {
      expect(isLoopbackHttpUrl(url)).toBe(false);
    }
  });
});
