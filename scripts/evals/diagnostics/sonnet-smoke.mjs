// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const MODEL = 'claude-sonnet-4.6';
export const CLI = '1.0.80';
export const BRANCH = 'refs/heads/diag/2894-sonnet-smoke-20260911';
export const CELLS = Object.freeze({
  historical: Object.freeze({ vally: '0.14.0', sdk: '1.0.11', experimental: false }),
  current: Object.freeze({ vally: '0.15.0', sdk: '1.0.9', experimental: false }),
  'old-core-old-sdk': Object.freeze({ vally: '0.14.0', sdk: '1.0.9', experimental: true }),
  'new-core-new-sdk': Object.freeze({ vally: '0.15.0', sdk: '1.0.11', experimental: true }),
});
const STAGES = ['dependencies', 'guard', 'setup', 'runtime-start', 'runtime-status', 'session-create', 'turn', 'complete'];
const CATEGORIES = ['none', 'unknown', 'model-not-supported', 'model-not-found', 'model-not-enabled',
  'model-unavailable', 'authentication-or-authorization', 'rate-limited', 'timeout', 'connection',
  'protocol-mismatch', 'package-resolution', 'runtime-version-mismatch', 'unexpected-response',
  'tool-requested', 'cleanup-failed', 'invalid-evidence', 'missing-evidence'];
const PROMPT = 'What is 2 + 2? Reply with only the digit. Do not use tools.';
const json = value => `${JSON.stringify(value, null, 2)}\n`;
const hash = value => createHash('sha256').update(value).digest('hex');
const readJson = path => JSON.parse(readFileSync(path, 'utf8'));

export function cellFor(id) {
  if (!Object.hasOwn(CELLS, id)) throw new Error('Invalid diagnostic cell');
  return CELLS[id];
}

export function manifestFor(id) {
  const cell = cellFor(id);
  return {
    name: 'isolated-sonnet-smoke', version: '1.0.0', private: true, type: 'module',
    dependencies: { '@microsoft/vally': cell.vally, '@github/copilot-sdk': cell.sdk, '@github/copilot': CLI },
    overrides: { '@github/copilot-sdk': '$@github/copilot-sdk', '@github/copilot': '$@github/copilot' },
  };
}

export function liveAllowed(env) {
  return env.GITHUB_ACTIONS === 'true' && env.GITHUB_REPOSITORY === 'microsoft/hve-core'
    && env.GITHUB_REF === BRANCH && env.SMOKE_LIVE === '1'
    && typeof env.COPILOT_GITHUB_TOKEN === 'string' && env.COPILOT_GITHUB_TOKEN.trim().length > 0;
}

export function classify(error) {
  const message = typeof error?.message === 'string' ? error.message.slice(0, 4096) : '';
  if (/runtime-version-mismatch/.test(message)) return 'runtime-version-mismatch';
  if (/protocol.*mismatch/i.test(message)) return 'protocol-mismatch';
  if (/platform package|cannot find (package|module)|package.*mismatch/i.test(message)) return 'package-resolution';
  if (/\bmodel\b[^\r\n]*(not supported|unsupported)/i.test(message)) return 'model-not-supported';
  if (/\bmodel\b[^\r\n]*not found/i.test(message)) return 'model-not-found';
  if (/\bmodel\b[^\r\n]*not enabled/i.test(message)) return 'model-not-enabled';
  if (/\bmodel\b[^\r\n]*(unavailable|not available)/i.test(message)) return 'model-unavailable';
  if (/unauthori[sz]ed|forbidden|authentication|invalid token|\b(401|403)\b/i.test(message)) return 'authentication-or-authorization';
  if (/rate.limit|\b429\b/i.test(message)) return 'rate-limited';
  if (/timed? ?out|timeout/i.test(message)) return 'timeout';
  if (/econn|socket|connection.*(closed|disposed)/i.test(message)) return 'connection';
  return 'unknown';
}

function initialResult() {
  return { status: 'not-run', stage: 'dependencies', category: 'none', graphVerified: false,
    runtimeVersionMatches: null, targetListed: null, catalogStatus: 'not-run', catalogCategory: 'none',
    responseMatches: false, reportedModelMatches: null, permissionRequests: 0, cleanup: 'not-run',
    lockSha256: null, cliEntrySha256: null };
}

// Reconstruct, never spread untrusted model, SDK, exception or file objects into output.
export function publicResult(raw, id) {
  const cell = cellFor(id);
  raw = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const pick = (value, allowed, fallback) => allowed.includes(value) ? value : fallback;
  const bool = value => typeof value === 'boolean' ? value : null;
  const sha = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value) ? value : null;
  const result = {
    schemaVersion: 1, cell: id, model: MODEL, vally: cell.vally, sdk: cell.sdk, cli: CLI,
    experimental: cell.experimental,
    status: pick(raw.status, ['not-run', 'running', 'blocked', 'error', 'pass'], 'error'),
    stage: pick(raw.stage, STAGES, 'setup'), category: pick(raw.category, CATEGORIES, 'unknown'),
    graphVerified: raw.graphVerified === true,
    runtimeVersionMatches: bool(raw.runtimeVersionMatches), targetListed: bool(raw.targetListed),
    catalogStatus: pick(raw.catalogStatus, ['not-run', 'read', 'error'], 'error'),
    catalogCategory: pick(raw.catalogCategory, CATEGORIES, 'unknown'),
    responseMatches: raw.responseMatches === true, reportedModelMatches: bool(raw.reportedModelMatches),
    permissionRequests: Number.isInteger(raw.permissionRequests) && raw.permissionRequests >= 0
      && raw.permissionRequests <= 100 ? raw.permissionRequests : 100,
    cleanup: pick(raw.cleanup, ['not-run', 'complete', 'error'], 'error'),
    lockSha256: sha(raw.lockSha256), cliEntrySha256: sha(raw.cliEntrySha256),
  };
  if (result.status === 'pass' && !(result.stage === 'complete' && result.category === 'none'
    && result.graphVerified && result.lockSha256 && result.cliEntrySha256
    && result.runtimeVersionMatches === true && result.responseMatches
    && result.reportedModelMatches === true && result.permissionRequests === 0 && result.cleanup === 'complete')) {
    result.status = 'error'; result.category = 'invalid-evidence';
  }
  if (result.status === 'running') { result.status = 'error'; result.category = 'missing-evidence'; }
  return result;
}

async function bounded(action, ms) {
  let timer;
  try {
    return await Promise.race([Promise.resolve().then(action), new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('Diagnostic timeout')), ms);
    })]);
  } finally { clearTimeout(timer); }
}

export async function runProbe({ client, Executor, workDir, result, save = () => {}, limitMs = 45000 }) {
  let executor;
  let sends = 0;
  let sessions = 0;
  const stage = value => { result.stage = value; save(result); };
  const bind = (target, property) => typeof target[property] === 'function' ? target[property].bind(target) : target[property];
  const wrapped = new Proxy(client, {
    get(target, property) {
      if (property === 'resumeSession') return async () => { throw new Error('Session resume prohibited'); };
      if (property !== 'createSession') return bind(target, property);
      return async options => {
        if (++sessions !== 1) throw new Error('Additional session prohibited');
        stage('session-create');
        const session = await target.createSession({
          ...options, model: MODEL, workingDirectory: workDir, configDirectory: join(workDir, 'config'),
          availableTools: [], tools: [], mcpServers: {}, customAgents: [], skillDirectories: [],
          requestExtensions: false, disabledMcpServers: ['github-mcp-server'],
          onPermissionRequest: () => { result.permissionRequests++; return { kind: 'denied-by-rules' }; },
        });
        return new Proxy(session, {
          get(inner, key) {
            if (key !== 'sendAndWait') return bind(inner, key);
            return async (...args) => {
              if (++sends !== 1) throw new Error('Additional turn prohibited');
              stage('turn');
              return inner.sendAndWait(...args);
            };
          },
        });
      };
    },
  });
  result.status = 'running';
  try {
    stage('runtime-start'); await bounded(() => client.start(), Math.min(limitMs, 20000));
    stage('runtime-status');
    const status = await bounded(() => client.getStatus(), Math.min(limitMs, 10000));
    result.runtimeVersionMatches = status?.version === CLI;
    if (!result.runtimeVersionMatches) throw new Error('runtime-version-mismatch');
    try {
      const models = await bounded(() => client.listModels(), Math.min(limitMs, 10000));
      if (!Array.isArray(models)) throw new Error('Invalid catalog');
      result.catalogStatus = 'read'; result.targetListed = models.some(model => model?.id === MODEL);
    } catch (error) { result.catalogStatus = 'error'; result.catalogCategory = classify(error); }
    executor = new Executor({ createClient: () => wrapped, flushWindowMs: 0 });
    const trajectory = await bounded(() => executor.execute({ name: 'sonnet-smoke', prompt: PROMPT },
      { model: MODEL, skills: [], workDir, timeout: limitMs }), limitMs);
    result.responseMatches = typeof trajectory?.output === 'string' && trajectory.output.trim() === '4';
    result.reportedModelMatches = trajectory?.metadata?.model === MODEL;
    result.stage = 'complete';
    result.status = result.responseMatches && result.reportedModelMatches && result.permissionRequests === 0 ? 'pass' : 'error';
    result.category = result.permissionRequests ? 'tool-requested' : result.status === 'pass' ? 'none' : 'unexpected-response';
  } catch (error) { result.status = 'error'; result.category = classify(error); }
  finally {
    result.cleanup = 'complete';
    try { if (executor) await bounded(() => executor.shutdown(), Math.min(limitMs, 5000)); }
    catch { result.cleanup = 'error'; }
    try { await bounded(() => client.forceStop(), Math.min(limitMs, 5000)); }
    catch { result.cleanup = 'error'; }
    if (result.cleanup === 'error' && result.status === 'pass') {
      result.status = 'error'; result.category = 'cleanup-failed';
    }
    save(result);
  }
  return result;
}

export function verifyLock(lock, id) {
  const cell = cellFor(id);
  const expected = { '@microsoft/vally': cell.vally, '@github/copilot-sdk': cell.sdk, '@github/copilot': CLI };
  for (const [name, version] of Object.entries(expected)) {
    if (lock.packages?.[`node_modules/${name}`]?.version !== version) throw new Error('Package version mismatch');
    for (const [path, entry] of Object.entries(lock.packages ?? {})) {
      if (path.endsWith(`/node_modules/${name}`)) throw new Error('Nested package resolution mismatch');
      if (name === '@github/copilot' && /node_modules\/@github\/copilot-(linux|darwin|win32)/.test(path)
        && entry.version !== CLI) throw new Error('Platform package version mismatch');
    }
  }
}

function assertRoot(root, id) {
  if (!process.env.RUNNER_TEMP || root !== resolve(process.env.RUNNER_TEMP, `sonnet-smoke-${id}`)) {
    throw new Error('Diagnostic root must be the dedicated runner temporary directory');
  }
}

async function main() {
  const [command, rootArg, id, output] = process.argv.slice(2);
  cellFor(id);
  const root = resolve(rootArg);
  assertRoot(root, id);
  const checkpoint = join(root, 'checkpoint.json');
  if (command === 'prepare') {
    if (existsSync(root)) throw new Error('Diagnostic directory already exists');
    mkdirSync(root);
    writeFileSync(join(root, 'package.json'), json(manifestFor(id)), { flag: 'wx' });
    writeFileSync(checkpoint, json(initialResult()), { flag: 'wx' });
    return;
  }
  if (command === 'publish') {
    let raw;
    try { raw = readJson(checkpoint); }
    catch { raw = { ...initialResult(), status: 'error', category: 'missing-evidence' }; }
    const safe = publicResult(raw, id);
    mkdirSync(dirname(resolve(output)), { recursive: true });
    writeFileSync(output, json(safe));
    console.log(json(safe));
    return;
  }
  if (command !== 'probe') throw new Error('Unknown diagnostic command');
  const result = initialResult();
  const save = value => writeFileSync(checkpoint, json(publicResult(value, id)));
  if (!liveAllowed(process.env)) {
    result.status = 'blocked'; result.stage = 'guard'; save(result); process.exitCode = 1; return;
  }
  result.stage = 'setup'; result.status = 'running'; save(result);
  try {
    if (process.platform !== 'linux' || process.arch !== 'x64') throw new Error('Platform package mismatch');
    const lockBytes = readFileSync(join(root, 'package-lock.json'));
    verifyLock(JSON.parse(lockBytes), id);
    const req = createRequire(join(root, 'package.json'));
    const expected = manifestFor(id).dependencies;
    for (const [name, version] of Object.entries(expected)) {
      if (readJson(join(root, 'node_modules', name, 'package.json')).version !== version) throw new Error('Package version mismatch');
    }
    const cliRoot = join(root, 'node_modules/@github/copilot-linux-x64');
    if (readJson(join(cliRoot, 'package.json')).version !== CLI) throw new Error('Platform package mismatch');
    const cliPath = join(cliRoot, 'index.js');
    result.cliEntrySha256 = hash(readFileSync(cliPath)); result.lockSha256 = hash(lockBytes);
    const sdkPath = req.resolve('@github/copilot-sdk');
    const executorPath = req.resolve('@microsoft/vally/executor');
    if (createRequire(executorPath).resolve('@github/copilot-sdk') !== sdkPath) throw new Error('Nested package resolution mismatch');
    result.graphVerified = true;
    const { CopilotClient } = await import(pathToFileURL(sdkPath).href);
    const { CopilotSdkExecutor } = await import(pathToFileURL(executorPath).href);
    const workDir = join(root, 'workspace');
    const home = join(root, 'home');
    mkdirSync(join(workDir, 'config'), { recursive: true }); mkdirSync(home);
    // Pin the runtime explicitly and do not inherit unrelated workflow credentials/config.
    const env = { PATH: process.env.PATH, HOME: home, TMPDIR: root, COPILOT_HOME: join(workDir, 'config') };
    const client = new CopilotClient({ connection: { kind: 'stdio', path: cliPath }, env,
      workingDirectory: workDir, gitHubToken: process.env.COPILOT_GITHUB_TOKEN, useLoggedInUser: false });
    await runProbe({ client, Executor: CopilotSdkExecutor, workDir, result, save });
  } catch (error) { result.status = 'error'; result.category = classify(error); save(result); }
  process.exitCode = result.status === 'pass' ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(() => { console.error('Diagnostic failed; raw details withheld.'); process.exitCode = 1; });
}