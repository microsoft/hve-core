// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import os from "node:os";
import { test } from "node:test";

import { redactArtifact } from "../../../evals/rca-real-world/redaction.mts";

test("retains fallback redaction for Windows and Unix home paths", () => {
  const result = redactArtifact(
    {
      windowsPath: "C:\\Users\\person\\secret",
      unixPath: "/home/person/secret",
      macPath: "/Users/person/secret",
    },
    [],
  );
  assert.deepEqual(result.value, {
    windowsPath: "[REDACTED_HOME]\\secret",
    unixPath: "[REDACTED_HOME]/secret",
    macPath: "[REDACTED_HOME]/secret",
  });
  assert.equal(result.replacements, 3);
});

test("redacts the OS home directory without an explicit caller path", () => {
  const home = os.homedir().replaceAll("\\", "/").replace(/\/+$/, "");
  const input = { nested: [{ error: `${home}/private/output.txt` }] };
  const result = redactArtifact(input, []);
  assert.deepEqual(result.value, { nested: [{ error: "[REDACTED_PATH]/private/output.txt" }] });
  assert.deepEqual(input, { nested: [{ error: `${home}/private/output.txt` }] });
  assert.equal(result.replacements, 1);
});

test("handles HOME, USERPROFILE, missing variables, and duplicate home paths", (context) => {
  context.mock.method(os, "homedir", () => "/var/lib/os-home");
  const savedHome = process.env.HOME;
  const savedProfile = process.env.USERPROFILE;
  try {
    process.env.HOME = "/root";
    process.env.USERPROFILE = "D:\\Profiles\\fixture";
    const result = redactArtifact({
      linux: "/root/private",
      windows: "d:/profiles/FIXTURE/private",
    }, ["/root", "/root/"]);
    assert.deepEqual(result.value, {
      linux: "[REDACTED_PATH]/private",
      windows: "[REDACTED_PATH]/private",
    });
    assert.equal(result.replacements, 2);

    process.env.HOME = "/srv/custom.home+directory/";
    process.env.USERPROFILE = "";
    assert.deepEqual(
      redactArtifact({ path: "/srv/custom.home+directory/file" }, []).value,
      { path: "[REDACTED_PATH]/file" },
    );

    delete process.env.HOME;
    delete process.env.USERPROFILE;
    assert.deepEqual(redactArtifact({ caseId: "case-01" }, ["", "/"]).value, { caseId: "case-01" });
  } finally {
    if (savedHome === undefined) delete process.env.HOME;
    else process.env.HOME = savedHome;
    if (savedProfile === undefined) delete process.env.USERPROFILE;
    else process.env.USERPROFILE = savedProfile;
  }
});

test("redacts longer repository and workspace paths before their parents", () => {
  const result = redactArtifact({
    repository: "/srv/private/repo/file.mts",
    workspace: "/srv/private/temp/rca-cli-case-01-1-random/AGENTS.md",
    shortHome: "/x/private",
  }, [
    "/srv/private/",
    "/srv/private/repo/",
    "/srv/private/temp/rca-cli-case-01-1-random",
    "/srv/private/repo",
    "/x",
    "/",
    "C:\\",
  ]);
  assert.deepEqual(result.value, {
    repository: "[REDACTED_PATH]/file.mts",
    workspace: "[REDACTED_PATH]/AGENTS.md",
    shortHome: "[REDACTED_PATH]/private",
  });
  assert.equal(result.replacements, 3);
});

test("handles Windows slash variants, UNC paths, and nested JSON captures", () => {
  const result = redactArtifact({
    native: "D:\\Build Agents\\repo\\file.mts",
    forward: "d:/build agents/repo/file.mts",
    unc: "\\\\server\\share\\workspace\\file.mts",
    capture: JSON.stringify({ cwd: "D:\\Build Agents\\repo\\file.mts" }),
  }, ["D:\\Build Agents\\repo\\", "\\\\server\\share\\workspace"]);
  assert.deepEqual(result.value, {
    native: "[REDACTED_PATH]\\file.mts",
    forward: "[REDACTED_PATH]/file.mts",
    unc: "[REDACTED_PATH]\\file.mts",
    capture: JSON.stringify({ cwd: "[REDACTED_PATH]\\file.mts" }),
  });
  assert.equal(result.replacements, 4);
});

test("preserves credential redaction and leaves diagnostic values unchanged", () => {
  const result = redactArtifact({
    credential: "github_pat_abcdefghijklmnopqrstuvwxyz",
    authorization: "Bearer abcdefghijklmnopqrstuvwxyz",
    caseId: "case-01",
    service: "checkoutservice",
    value: 42,
  }, []);
  assert.deepEqual(result.value, {
    credential: "[REDACTED_CREDENTIAL]",
    authorization: "[REDACTED_CREDENTIAL]",
    caseId: "case-01",
    service: "checkoutservice",
    value: 42,
  });
  assert.equal(result.replacements, 2);
});

test("redacts secret-key values recursively without changing keys, types, or the input", () => {
  const input = {
    token: 'fixture-"value\\with-escapes',
    nested: [{ password: "fixture-password", status: true, count: 42, missing: null }],
    clientSecret: { entries: ["fixture-entry", 17, false] },
    "github_pat_abcdefghijklmnopqrstuvwxyz": "ordinary diagnostic value",
  };
  const before = JSON.stringify(input);
  const result = redactArtifact(input, []);
  assert.deepEqual(result.value, {
    ...input,
    token: "[REDACTED_CREDENTIAL]",
    nested: [{ password: "[REDACTED_CREDENTIAL]", status: true, count: 42, missing: null }],
    clientSecret: { entries: ["[REDACTED_CREDENTIAL]", 17, false] },
  });
  assert.equal(JSON.stringify(input), before);
  assert.equal(result.replacements, 3);
  assert.equal(result.notices.reduce((sum, notice) => sum + notice.replacements, 0), 3);
  assert.doesNotMatch(JSON.stringify(result.notices), /fixture-|github_pat_|password|clientSecret/);
  assert.ok(result.notices.every((notice) => /^\$(?:\/(?:member-\d+|\d+|json))*$/.test(notice.location)));
  const again = redactArtifact(result.value, []);
  assert.deepEqual(again.value, result.value);
  assert.equal(again.replacements, 0);
  assert.deepEqual(again.notices, []);
});

test("preserves JSON, fenced JSON and JSONL captures through multiple encoding layers", () => {
  const payload = { token: 'fixture-"escaped\\value', target: "adservice", count: 42 };
  const content = `\`\`\`json\n${JSON.stringify(payload, null, 2)}\n\`\`\``;
  const event = { type: "assistant.message", data: { content } };
  const stdout = `${JSON.stringify(event)}\r\n${JSON.stringify({ type: "done" })}\r\n`;
  const result = redactArtifact({
    report: payload,
    response: content,
    doubleEncoded: JSON.stringify(JSON.stringify(payload)),
    stdout,
  }, []);
  const expected = { ...payload, token: "[REDACTED_CREDENTIAL]" };
  assert.deepEqual(result.value.report, expected);
  assert.deepEqual(JSON.parse(result.value.response.slice(8, -4)), expected);
  assert.deepEqual(JSON.parse(JSON.parse(result.value.doubleEncoded)), expected);
  const lines = result.value.stdout.split("\r\n");
  assert.equal(lines.length, 3);
  assert.deepEqual(JSON.parse(JSON.parse(lines[0]!).data.content.slice(8, -4)), expected);
  assert.equal(lines[1], JSON.stringify({ type: "done" }));
  assert.equal(result.replacements, 4);
  assert.doesNotMatch(JSON.stringify(result.value), /fixture-/);
  assert.equal(redactArtifact(result.value, []).replacements, 0);
});

test("keeps unchanged encoded strings byte-identical and does not repair malformed input", () => {
  const unchanged = ' \n```json\n{ "status": true, "count": 42 }\n``` \n';
  const malformed = '{"token":"fixture-secret","count":42';
  const result = redactArtifact({ unchanged, malformed }, []);
  assert.equal(result.value.unchanged, unchanged);
  assert.equal(result.value.malformed, '{"token":"[REDACTED_CREDENTIAL]","count":42');
  assert.throws(() => JSON.parse(result.value.malformed), SyntaxError);
  assert.equal(result.replacements, 1);
});

test("preserves assignment syntax and escaped quotation boundaries in narrative text", () => {
  const input = 'Observed token="fixture-\\"value" and password=\'fixture-\\\'value\'; count=42.';
  const result = redactArtifact({ narrative: input }, []);
  assert.equal(result.value.narrative,
    'Observed token="[REDACTED_CREDENTIAL]" and password=\'[REDACTED_CREDENTIAL]\'; count=42.');
  assert.equal(result.replacements, 2);
  assert.equal(result.notices.length, 1);
  assert.equal(result.notices[0]!.replacements, 2);
  assert.equal(redactArtifact(result.value, []).replacements, 0);
});

test("redacts JSONL with LF, CRLF or bare CR without changing line separators", () => {
  for (const separator of ["\n", "\r\n", "\r"]) {
    const input = `{"token":"fixture-first"}${separator}{"password":"fixture-second"}${separator}`;
    const result = redactArtifact({ capture: input }, []);
    assert.equal(result.value.capture,
      `{"token":"[REDACTED_CREDENTIAL]"}${separator}{"password":"[REDACTED_CREDENTIAL]"}${separator}`);
    assert.equal(result.replacements, 2);
    assert.equal(redactArtifact(result.value, []).replacements, 0);
  }
});
