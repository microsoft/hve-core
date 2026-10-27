// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { isAbsolute, join } from "node:path";
import test from "node:test";
import sharp from "sharp";

const enabled = process.env.SKILL_EFFECTIVENESS_LINUX_RENDER_TESTS === "1";

test("opt-in Linux Chromium namespace sandbox renders actual Mermaid without model access", {
  skip: !enabled, timeout: 180000,
}, async t => {
  const required = name => {
    const value = process.env["SKILL_EFFECTIVENESS_RENDER_" + name];
    assert.ok(value, "Set SKILL_EFFECTIVENESS_RENDER_" + name);
    return value;
  };
  const image = required("IMAGE");
  assert.match(image, /^(?:sha256:[a-f0-9]{64}|[^\s]+@sha256:[a-f0-9]{64})$/);
  const profile = required("SECCOMP"), config = required("BROWSER_CONFIG"), evidenceRoot = required("EVIDENCE_DIR");
  for (const file of [profile, config, evidenceRoot]) assert.ok(isAbsolute(file), "Use absolute approved paths");
  const policy = JSON.parse(readFileSync(profile, "utf8"));
  assert.equal(policy.defaultAction, "SCMP_ACT_ERRNO", "Unconfined/default-allow policies are unsupported");
  const browserConfig = JSON.parse(readFileSync(config, "utf8"));
  assert.equal(browserConfig.args, undefined, "This smoke profile accepts no browser flag overrides");
  assert.equal(typeof browserConfig.executablePath, "string");
  mkdirSync(evidenceRoot, { recursive: true });
  const evidence = mkdtempSync(join(evidenceRoot, "linux-render-"));
  const staging = mkdtempSync(join(tmpdir(), "linux-render-probe-"));
  t.after(() => rmSync(staging, { recursive: true, force: true }));
  const name = "skill-render-" + randomUUID();
  const invoke = (args, timeout = 150000) => spawnSync("docker", args, {
    encoding: "utf8", timeout, maxBuffer: 2 * 1024 * 1024,
  });
  t.after(() => {
    const inspect = invoke(["container", "inspect", name], 15000);
    if (inspect.status === 0) {
      const cleanup = invoke(["container", "rm", "--force", name], 15000);
      assert.equal(cleanup.status, 0, cleanup.stderr);
    }
  });
  const probe = join(staging, "probe.mjs");
  writeFileSync(probe, `
import assert from "node:assert/strict";
import {readFileSync,writeFileSync} from "node:fs";
import {createRequire} from "node:module";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
import {createConnection} from "node:net";
const status=readFileSync("/proc/self/status","utf8");
assert.equal(process.getuid(),1000);
assert.match(status,/^NoNewPrivs:\\s+1$/m);
assert.match(status,/^CapEff:\\s+0+$/m);
assert.equal(Object.keys(process.env).some(key=>/TOKEN|SECRET|PASSWORD|API_KEY/i.test(key)),false);
const connected=await new Promise(resolve=>{
 const socket=createConnection({host:"1.1.1.1",port:443});
 const done=value=>{socket.destroy();resolve(value)};
 socket.setTimeout(1500);socket.once("connect",()=>done(true));
 socket.once("error",()=>done(false));socket.once("timeout",()=>done(false));
});
assert.equal(connected,false);
const require=createRequire(process.env.MERMAID_CLI);
const {default:puppeteer}=await import(pathToFileURL(require.resolve("puppeteer")));
const config=JSON.parse(readFileSync("/qualification/browser.json","utf8"));
const args=await puppeteer.defaultArgs(config);
assert.equal(args.some(arg=>["--no-sandbox","--disable-setuid-sandbox"].includes(arg)),false);
let browser;
let renderers;
try{
 browser=await puppeteer.launch({...config,timeout:20000});
 const page=await browser.newPage();
 await page.setContent("<h1>Native namespace rendering control</h1>");
 await page.screenshot({path:"/grade-output/browser.png"});
 const cdp=await browser.target().createCDPSession();
 const processes=await cdp.send("SystemInfo.getProcessInfo");
 renderers=processes.processInfo.filter(p=>p.type==="renderer").map(p=>({
  pid:p.id,uidMap:readFileSync("/proc/"+p.id+"/uid_map","utf8").trim(),
  status:readFileSync("/proc/"+p.id+"/status","utf8").split("\\n").filter(line=>
   /^(CapEff|NoNewPrivs|Seccomp|Seccomp_filters):/.test(line))
 }));
 assert.ok(renderers.length>0);
 for(const p of renderers){
  assert.match(p.uidMap,/^1000\\s+1000\\s+1$/);
  assert.ok(p.status.some(line=>/^CapEff:\\s+0+$/.test(line)));
  assert.ok(p.status.some(line=>/^NoNewPrivs:\\s+1$/.test(line)));
  assert.ok(p.status.some(line=>/^Seccomp:\\s+2$/.test(line)));
 }
 await cdp.detach();
}finally{if(browser)await browser.close()}
writeFileSync("/grade-output/control.mmd",'flowchart LR\\n A["Source"] --> B["Target"]\\n');
const result=spawnSync(process.execPath,[process.env.MERMAID_CLI,"-i","/grade-output/control.mmd",
 "-o","/grade-output/mermaid.png","--puppeteerConfigFile","/qualification/browser.json"],{
 encoding:"utf8",timeout:45000
});
assert.ifError(result.error);
assert.equal(result.status,0,result.stdout+result.stderr);
writeFileSync("/grade-output/result.json",JSON.stringify({passed:true,renderers,
 browserArgs:args,networkDenied:true,nonroot:true,noNewPrivileges:true,capabilities:"none",modelCalls:0},null,2));
`);
  const result = invoke(["run", "--rm", "--pull=never", "--name", name,
    "--network", "none", "--read-only", "--cap-drop", "ALL",
    "--security-opt", "no-new-privileges:true", "--security-opt", "seccomp=" + profile,
    "--user", "1000:1000", "--cpus", "2", "--memory", "2g", "--pids-limit", "256", "--shm-size", "256m",
    "--tmpfs", "/tmp:rw,nosuid,nodev,size=512m",
    "--tmpfs", "/workspace:rw,nosuid,nodev,size=128m,uid=1000,gid=1000",
    "--mount", "type=bind,source=" + probe + ",target=/qualification/probe.mjs,readonly",
    "--mount", "type=bind,source=" + config + ",target=/qualification/browser.json,readonly",
    "--mount", "type=bind,source=" + evidence + ",target=/grade-output",
    "--entrypoint", "node", image, "/qualification/probe.mjs"]);
  writeFileSync(join(evidence, "docker.stdout.log"), result.stdout ?? "");
  writeFileSync(join(evidence, "docker.stderr.log"), result.stderr ?? "");
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const report = JSON.parse(readFileSync(join(evidence, "result.json"), "utf8"));
  assert.equal(report.passed, true);
  const images = [];
  for (const file of ["browser.png", "mermaid.png"]) {
    const bytes = readFileSync(join(evidence, file));
    const metadata = await awaitImageMetadata(bytes);
    images.push({ file, sha256: createHash("sha256").update(bytes).digest("hex"), ...metadata });
  }
  writeFileSync(join(evidence, "host-verification.json"), JSON.stringify({
    image, seccompSha256: createHash("sha256").update(readFileSync(profile)).digest("hex"),
    browserConfigSha256: createHash("sha256").update(readFileSync(config)).digest("hex"),
    images, modelCalls: 0,
  }, null, 2) + "\n");
});

async function awaitImageMetadata(bytes) {
  const metadata = await sharp(bytes).metadata();
  const stats = await sharp(bytes).stats();
  assert.equal(metadata.format, "png");
  assert.ok(metadata.width > 0 && metadata.height > 0);
  assert.ok(stats.channels.some(channel => channel.stdev > 2));
  return { width: metadata.width, height: metadata.height };
}
