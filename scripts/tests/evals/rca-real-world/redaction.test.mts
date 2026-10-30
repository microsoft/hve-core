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
