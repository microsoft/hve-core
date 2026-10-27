// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";
import { CopilotClient, CopilotRequestHandler } from "@github/copilot-sdk";
import { RestrictedCopilotExecutor } from "../scripts/restricted-copilot-executor.mjs";

const enabled = process.env.SKILL_EFFECTIVENESS_RUNTIME_TESTS === "1";

for (const [treatment, nativeSandbox, emptyMode] of [
  [false, false, false], [true, false, false], [false, true, false], [true, true, false],
  [false, false, true], [true, false, true],
]) {
  test(`native ${emptyMode ? "empty-mode nested-instructions " : ""}${nativeSandbox ? "Windows sandbox " : ""}synthetic ${treatment ? "treatment activates full skill" : "baseline has no skill"} and completes file task`, {
    skip: !enabled || (nativeSandbox && process.platform !== "win32"), timeout: 120000,
  }, async t => {
    const model = process.env.SKILL_EFFECTIVENESS_TEST_MODEL;
    assert.ok(model, "Select a locally available model for tool metadata; synthetic responses never forward");
    const workDir = realpathSync.native(mkdtempSync(join(tmpdir(), "skill-ab-")));
    t.after(() => rmSync(workDir, { recursive: true, force: true }));
    const auditRoot = realpathSync.native(mkdtempSync(join(tmpdir(), "skill-audit-")));
    t.after(() => rmSync(auditRoot, { recursive: true, force: true }));
    writeFileSync(join(auditRoot, "operator-marker.txt"), "SYNTHETIC_AUDIT");
    for (const directory of ["task-fixture", "deliverable", "focus"]) mkdirSync(join(workDir, directory));
    const body = "# Synthetic focus\n\nPreserve the supplied input and write only the requested deliverable.\n";
    const rawContent = "---\nname: synthetic-focus\ndescription: Synthetic file-authoring test guidance.\n---\n" + body;
    const skillPath = join(workDir, "focus", "SKILL.md");
    writeFileSync(skillPath, rawContent);
    writeFileSync(join(workDir, "task-fixture", "input.txt"), "SYNTHETIC_INPUT");
    writeFileSync(join(workDir, "protected.txt"), "SYNTHETIC_PROTECTED");
    if (emptyMode) {
      mkdirSync(join(workDir, "nested"));
      writeFileSync(join(workDir, "nested", "AGENTS.md"),
        "# Synthetic nested instruction\n\nSYNTHETIC_CHILD_INSTRUCTION_MUST_NOT_REACH_MODEL\n");
    }
    const events = [];
    const permissionRequests = [];
    let requests = 0;
    const handler = new class extends CopilotRequestHandler {
      async openWebSocket() {
        throw new Error("Synthetic test never opens an upstream WebSocket");
      }

      async sendRequest(request) {
        const payload = await request.json();
        const serialized = JSON.stringify(payload);
        assert.doesNotMatch(serialized, /SYNTHETIC_CHILD_INSTRUCTION_MUST_NOT_REACH_MODEL|Child instruction files/,
          "Disabled nested instructions must not reach the model-facing request");
        if (emptyMode) {
          const strings = value => typeof value === "string" ? [value]
            : value && typeof value === "object" ? Object.values(value).flatMap(strings) : [];
          assert.ok(strings(payload).some(text => text.includes(JSON.stringify(workDir))),
            "Empty-mode model-facing context must identify the actual working directory");
          assert.match(serialized, /Resolve relative file paths against this directory/);
        }
        assert.equal(serialized.includes("synthetic-focus"), treatment);
        const action = requests++ - (treatment ? 1 : 0);
        assert.ok(action <= 3, "No real model request or extra synthetic retry is allowed");
        let item;
        if (action === -1) {
          item = { type: "function_call", id: "fc_skill", call_id: "call_skill", name: "skill",
            arguments: JSON.stringify({ skill: "synthetic-focus" }), status: "completed" };
        } else if (action === 0) {
          if (treatment) assert.ok(serialized.includes(JSON.stringify(body.trim()).slice(1, -1)),
            "Complete original skill body must reach the next model-facing request");
          item = { type: "function_call", id: "fc_list", call_id: "call_list", name: "view",
            arguments: JSON.stringify({ path: workDir }), status: "completed" };
        } else if (action === 1) {
          assert.doesNotMatch(serialized, /skill-evidence-|startup-backups|file-policy\.json|native-audit/,
            "Workspace listing must not expose operator audit entries");
          item = { type: "function_call", id: "fc_read", call_id: "call_read", name: "view",
            arguments: JSON.stringify({ path: emptyMode ? join("task-fixture", "input.txt")
              : join(workDir, "task-fixture", "input.txt") }), status: "completed" };
        } else if (action === 2) {
          assert.match(serialized, /SYNTHETIC_INPUT/);
          item = { type: "custom_tool_call", id: "ctc_write", call_id: "call_write", name: "apply_patch",
            input: "*** Begin Patch\n*** Add File: deliverable/result.md\n+SYNTHETIC_OUTPUT\n*** End Patch",
            status: "completed" };
        } else {
          assert.equal(readFileSync(join(workDir, "deliverable", "result.md"), "utf8").trim(), "SYNTHETIC_OUTPUT");
          item = { type: "message", id: "msg_done", role: "assistant", status: "completed",
            content: [{ type: "output_text", text: "SYNTHETIC_DONE", annotations: [] }] };
        }
        assert.notEqual(payload.stream, true, "Native executor uses the non-streaming response contract");
        return Response.json({ id: `synthetic-${requests}`, object: "response", status: "completed",
          created_at: Math.floor(Date.now() / 1000), model, output: [item],
          usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 } });
      }
    }();
    const executor = new RestrictedCopilotExecutor(options => {
      const client = new CopilotClient({ ...options, requestHandler: handler });
      const createSession = client.createSession.bind(client);
      client.createSession = async config => {
        const session = await createSession({ ...config, onPermissionRequest: request => {
          permissionRequests.push(request);
          return config.onPermissionRequest(request);
        } });
        assert.deepEqual((await session.rpc.instructions.getSources()).sources, []);
        await session.rpc.tools.initializeAndValidate();
        for (const file of [auditRoot, join(auditRoot, "operator-marker.txt")]) {
          const denied = await session.rpc.tools.execute({ name: "view",
            arguments: { path: file }, toolCallId: "deny-external-audit" });
          assert.equal(denied.resultType, "rejected");
        }
        return session;
      };
      return client;
    });
    const portable = file => file.replaceAll("\\", "/");
    const allow = [workDir, join(workDir, "task-fixture"), join(workDir, "task-fixture", "**"),
      join(workDir, "deliverable"), join(workDir, "deliverable", "**"),
      ...(treatment ? [join(workDir, "focus"), join(workDir, "focus", "**")] : [])]
      .map(file => `Read(${portable(file)})`);
    allow.push(`Write(${portable(join(workDir, "deliverable", "**"))})`);
    try {
      const trajectory = await executor.execute({
        name: "synthetic-file-task", prompt: "Read the supplied input and create deliverable/result.md.",
      }, {
        workDir, model, timeout: 90000, env: { DO_NOT_TRACK: "1", VALLY_TELEMETRY_OPTOUT: "1" },
        mcpServers: {}, onRawEvent: event => events.push(event),
        skills: treatment ? [{ name: "synthetic-focus", description: "Synthetic test guidance",
          path: skillPath, rawContent, frontmatter: {}, fileReferences: [] }] : [],
        executorConfig: { auditDirectory: auditRoot,
          ...(emptyMode ? { clientMode: "empty" } : {}),
          ...(nativeSandbox ? { executionProfile: { name: "windows-native", readonlyPaths: [], deniedPaths: [] } } : {}),
          sessionPolicy: { availableTools: ["view", "apply_patch", "skill"],
          permissions: { allow, deny: ["Shell(*)"] } } },
        sessionLog: { rootDir: auditRoot },
      });
      assert.match(trajectory.output, /SYNTHETIC_DONE/, JSON.stringify({ requests,
        workDir, allow, permissionRequests,
        endReason: trajectory.endReason, errors: events.filter(event =>
          event.type === "session.error" || event.type === "tool.execution_complete") }));
      assert.equal(trajectory.endReason, "completed");
      assert.equal(requests, treatment ? 5 : 4);
      assert.equal(trajectory.metrics.skillActivationCount, treatment ? 1 : 0);
      assert.equal(events.filter(event => event.type === "tool.execution_complete").length, treatment ? 4 : 3);
      assert.ok(events.filter(event => event.type === "tool.execution_complete").every(event => event.data.success));
      assert.equal(readFileSync(join(workDir, "protected.txt"), "utf8"), "SYNTHETIC_PROTECTED");
      assert.deepEqual(readdirSync(workDir).sort(),
        ["deliverable", "focus", ...(emptyMode ? ["nested"] : []), "protected.txt", "task-fixture"].sort());
      const auditDirectory = join(auditRoot, readdirSync(auditRoot).find(name => name.startsWith("skill-evidence-")));
      const inventory = join(auditDirectory, trajectory.metadata.sessionID + ".json");
      const verification = JSON.parse(readFileSync(inventory.replace(".json", ".verification.json"), "utf8"));
      assert.equal(verification.status, "verified");
      assert.equal(JSON.parse(readFileSync(inventory, "utf8")).workingDirectory, workDir);
      assert.equal(JSON.parse(readFileSync(inventory, "utf8")).executionProfile?.name ?? null,
        nativeSandbox ? "windows-native" : null);
      assert.equal(JSON.parse(readFileSync(inventory, "utf8")).clientMode, emptyMode ? "empty" : null);
      assert.deepEqual(readFileSync(inventory),
        readFileSync(join(auditDirectory, "startup-backups", trajectory.metadata.sessionID + ".json")));
    } finally {
      await executor.shutdown();
    }
  });
}

test("actual native CLI cleanup retains external audit originals, backups and reports for both arms", {
  skip: !enabled, timeout: 120000,
}, t => {
  const model = process.env.SKILL_EFFECTIVENESS_TEST_MODEL;
  assert.ok(model, "Select a local metadata model for synthetic CLI coverage");
  const root = realpathSync.native(mkdtempSync(join(tmpdir(), "skill-cli-audit-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const require = createRequire(join(source, "package.json"));
  const { stringify } = require("yaml");
  const plugin = join(root, "synthetic-executor.mjs");
  writeFileSync(plugin, `import sdk from ${JSON.stringify(pathToFileURL(require.resolve("@github/copilot-sdk")).href)};
const { CopilotClient, CopilotRequestHandler } = sdk;
import { RestrictedCopilotExecutor } from ${JSON.stringify(pathToFileURL(join(source, "scripts", "restricted-copilot-executor.mjs")).href)};
class Handler extends CopilotRequestHandler {
  async openWebSocket() { throw new Error("No real model transport permitted"); }
  async sendRequest(request) {
    const payload = await request.json();
    return Response.json({ id: "synthetic", object: "response", status: "completed",
      model: payload.model, created_at: Math.floor(Date.now()/1000),
      output: [{ type: "message", id: "msg", role: "assistant", status: "completed",
        content: [{ type: "output_text", text: "SYNTHETIC_DONE", annotations: [] }] }],
      usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 } });
  }
}
export function registerExecutors(registry) {
  registry.register(new RestrictedCopilotExecutor(options =>
    new CopilotClient({ ...options, requestHandler: new Handler() })));
}
`);
  const audit = join(root, "durable-audit"), work = join(root, "work"), output = join(root, "output");
  writeFileSync(join(root, ".vally.yaml"), "{}\n");
  writeFileSync(join(root, "eval.yaml"), stringify({
    name: "audit-retention", version: "1.0.0", type: "capability", description: "Native synthetic audit lifecycle",
    defaults: { runs: 1, timeout: "1m", model,
      executor: { name: "restricted-copilot-sdk", config: { auditDirectory: audit,
        sessionPolicy: { availableTools: [], permissions: { allow: [], deny: ["Shell(*)"] } } } } },
    agent_environment: { env: { DO_NOT_TRACK: "1" }, skills: [] },
    stimuli: [{ name: "audit-retention", prompt: "Return the synthetic response.", graders: [{ type: "completed" }] }],
  }));
  writeFileSync(join(root, "experiment.yaml"), stringify({
    name: "synthetic-audit-export", evals: ["./eval.yaml"], vary: ["/environment/skills"], baseline: "a-first",
    variants: { "a-first": { environment: { skills: [] } }, "b-second": { environment: { skills: [] } } },
    execution: { workers: 1 }, overrides: { runs: 1 },
  }));
  const cli = join(source, "node_modules", "@microsoft", "vally-cli", "dist", "index.js");
  const child = spawnSync(process.execPath, [cli, "experiment", "run", join(root, "experiment.yaml"),
    "--executor-plugin", plugin, "--workers", "1", "--backend", "local",
    "--workspace", work, "--output-dir", output], {
    cwd: root, env: { ...process.env, DO_NOT_TRACK: "1", VALLY_TELEMETRY_OPTOUT: "1" },
    encoding: "utf8", timeout: 110000, maxBuffer: 2 * 1024 * 1024,
  });
  assert.ifError(child.error);
  assert.equal(child.status, 0, child.stdout + child.stderr);
  const run = join(output, readdirSync(output)[0]);
  const audits = readdirSync(audit).map(name => join(audit, name));
  assert.equal(audits.length, 2);
  const hash = file => createHash("sha256").update(readFileSync(file)).digest("hex");
  for (const arm of ["a-first", "b-second"]) {
    const record = JSON.parse(readFileSync(join(run, arm, "results.jsonl"), "utf8").trim());
    assert.equal(record.gradeResult.passed, true);
    assert.deepEqual(readdirSync(record.workspacePath), []);
    const id = record.trajectory.metadata.sessionID;
    const directory = audits.find(folder => readdirSync(folder).includes(id + ".json"));
    assert.ok(directory, "Native log export must not remove the external audit tree");
    const report = JSON.parse(readFileSync(join(directory, id + ".verification.json"), "utf8"));
    assert.equal(report.status, "verified");
    assert.equal(report.sessionId, id);
    assert.equal(hash(join(directory, id + ".json")), report.expectedSha256);
    assert.equal(hash(join(directory, "startup-backups", id + ".json")), report.expectedSha256);
  }
});
