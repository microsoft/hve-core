// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { BRANCH, CELLS, CLI, MODEL, cellFor, classify, liveAllowed, manifestFor,
  publicResult, runProbe, verifyLock } from '../../evals/diagnostics/sonnet-smoke.mjs';

const evidence = () => ({ status: 'running', stage: 'setup', category: 'none', graphVerified: true,
  lockSha256: 'a'.repeat(64), cliEntrySha256: 'b'.repeat(64), permissionRequests: 0,
  catalogStatus: 'not-run', catalogCategory: 'none', targetListed: null });

function fake({ failStage, output = '4', listed = true, askPermission = false, cleanupFails = false } = {}) {
  const calls = [];
  let captured;
  const failure = () => new Error('Model not supported; Bearer SYNTHETIC_SECRET https://example.invalid/?token=SYNTHETIC_SECRET');
  const client = {
    async start() { calls.push('start'); if (failStage === 'runtime-start') throw failure(); },
    async getStatus() { calls.push('status'); return { version: CLI }; },
    async listModels() { calls.push('catalog'); if (failStage === 'catalog') throw failure(); return listed ? [{ id: MODEL }] : []; },
    async createSession(options) {
      calls.push('create'); captured = options;
      if (failStage === 'session-create') throw failure();
      if (askPermission) assert.deepEqual(options.onPermissionRequest({}), { kind: 'denied-by-rules' });
      return {
        async sendAndWait() { calls.push('send'); if (failStage === 'turn') throw failure(); return output; },
      };
    },
    async forceStop() { calls.push('stop'); if (cleanupFails) throw failure(); },
  };
  class Executor {
    constructor(options) { this.client = options.createClient(); }
    async execute(stimulus, options) {
      assert.equal(stimulus.prompt, 'What is 2 + 2? Reply with only the digit. Do not use tools.');
      const session = await this.client.createSession({ ...options, enableConfigDiscovery: true });
      return { output: await session.sendAndWait(), metadata: { model: MODEL }, secret: 'SYNTHETIC_SECRET' };
    }
    async shutdown() { calls.push('shutdown'); }
  }
  return { client, Executor, calls, options: () => captured };
}

test('four fixed cells hold CLI constant and label the controls', () => {
  assert.equal(Object.keys(CELLS).length, 4);
  assert.equal(new Set(Object.values(CELLS).map(c => `${c.vally}/${c.sdk}`)).size, 4);
  for (const id of Object.keys(CELLS)) {
    const manifest = manifestFor(id);
    assert.equal(manifest.dependencies['@github/copilot'], '1.0.80');
    assert.equal(manifest.dependencies['@github/copilot-sdk'], CELLS[id].sdk);
    assert.equal(manifest.overrides['@github/copilot-sdk'], '$@github/copilot-sdk');
  }
  assert.throws(() => cellFor('__proto__'));
  assert.throws(() => manifestFor('current; unwanted-command'));
});

test('live entry requires the declared Actions repository, branch and secret', () => {
  const env = { GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: 'microsoft/hve-core',
    GITHUB_REF: BRANCH, SMOKE_LIVE: '1', COPILOT_GITHUB_TOKEN: 'SYNTHETIC_SECRET' };
  assert.equal(liveAllowed(env), true);
  for (const key of Object.keys(env)) assert.equal(liveAllowed({ ...env, [key]: '' }), false);
  assert.equal(liveAllowed({ ...env, GITHUB_REF: 'refs/heads/main' }), false);
  assert.equal(liveAllowed({ ...env, COPILOT_GITHUB_TOKEN: '  ' }), false);
});

test('lock validation rejects wrong and nested runtime graphs', () => {
  const packages = Object.fromEntries(Object.entries(manifestFor('current').dependencies)
    .map(([name, version]) => [`node_modules/${name}`, { version }]));
  verifyLock({ packages }, 'current');
  assert.throws(() => verifyLock({ packages: { ...packages,
    'node_modules/@github/copilot': { version: '1.0.81' } } }, 'current'));
  assert.throws(() => verifyLock({ packages: { ...packages,
    'node_modules/@microsoft/vally/node_modules/@github/copilot-sdk': { version: '1.0.9' } } }, 'current'));
  assert.throws(() => verifyLock({ packages: {} }, 'current'));
});

test('one successful synthetic turn is tool-denied and safely summarized', async () => {
  const f = fake();
  const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 100 });
  assert.deepEqual(f.calls, ['start', 'status', 'catalog', 'create', 'send', 'shutdown', 'stop']);
  assert.deepEqual(f.options().availableTools, []);
  assert.deepEqual(f.options().mcpServers, {});
  assert.equal(f.options().requestExtensions, false);
  assert.equal(f.options().enableConfigDiscovery, true);
  assert.equal(publicResult(result, 'current').status, 'pass');
});

for (const failStage of ['runtime-start', 'session-create', 'turn']) {
  test(`failure preserves ${failStage} without exposing raw error`, async () => {
    const f = fake({ failStage });
    const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 100 });
    const safe = publicResult(result, 'current');
    assert.equal(safe.status, 'error'); assert.equal(safe.stage, failStage);
    assert.equal(safe.category, 'model-not-supported');
    assert.equal(JSON.stringify(safe).includes('SYNTHETIC_SECRET'), false);
    assert.equal(JSON.stringify(safe).includes('https:'), false);
    assert.equal(f.calls.at(-1), 'stop');
  });
}

test('missing model from catalog does not suppress the actual smoke', async () => {
  const f = fake({ listed: false });
  const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 100 });
  assert.equal(result.targetListed, false); assert.equal(result.status, 'pass');
  assert.equal(f.calls.filter(call => call === 'send').length, 1);
});

test('catalog errors remain separate and do not fabricate a denial', async () => {
  const f = fake({ failStage: 'catalog' });
  const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 100 });
  assert.equal(result.catalogStatus, 'error'); assert.equal(result.targetListed, null);
  assert.equal(result.status, 'pass');
});

for (const options of [{ output: 'SYNTHETIC_SECRET' }, { askPermission: true }, { cleanupFails: true }]) {
  test(`unexpected response, tool attempt or cleanup cannot pass: ${Object.keys(options)[0]}`, async () => {
    const result = await runProbe({ ...fake(options), workDir: '/empty', result: evidence(), limitMs: 100 });
    const safe = publicResult(result, 'current');
    assert.equal(safe.status, 'error');
    assert.equal(JSON.stringify(safe).includes('SYNTHETIC_SECRET'), false);
  });
}

test('startup timeout is bounded and forces cleanup', async () => {
  const f = fake(); f.client.start = () => new Promise(() => {});
  const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 5 });
  assert.equal(result.category, 'timeout'); assert.equal(result.stage, 'runtime-start');
  assert.equal(f.calls.at(-1), 'stop');
});

test('public projection drops arbitrary fields and rejects incomplete passes', () => {
  for (const raw of [null, [], 'SYNTHETIC_SECRET', { status: 'pass' },
    { ...evidence(), status: 'running', message: 'SYNTHETIC_SECRET', model: 'SYNTHETIC_SECRET',
      category: 'SYNTHETIC_SECRET', lockSha256: 'SYNTHETIC_SECRET', permissionRequests: 'SYNTHETIC_SECRET' }]) {
    const result = publicResult(raw, 'current');
    assert.notEqual(result.status, 'pass');
    assert.equal(JSON.stringify(result).includes('SYNTHETIC_SECRET'), false);
  }
  assert.equal(classify({ message: 'unknown SYNTHETIC_SECRET' }), 'unknown');
});

test('workflow confines secrets and uploads to the intended boundary', () => {
  const workflow = readFileSync(new URL('../../../.github/workflows/sonnet-smoke.yml', import.meta.url), 'utf8');
  assert.equal((workflow.match(/secrets\.COPILOT_GITHUB_TOKEN/g) ?? []).length, 1);
  assert.match(workflow, /persist-credentials: false/);
  assert.match(workflow, /max-parallel: 1/);
  assert.match(workflow, /fail-fast: false/);
  assert.match(workflow, /timeout --signal=TERM --kill-after=5s 120s/);
  assert.match(workflow, /path: sonnet-results\/\$\{\{ matrix.cell \}\}\.json/);
  assert.doesNotMatch(workflow, /path:.*(?:runtime\.log|install\.log|checkpoint|results\.jsonl)/);
  for (const match of workflow.matchAll(/uses: ([^\s]+)@([^\s]+)/g)) assert.match(match[2], /^[a-f0-9]{40}$/);
});

test('real CLI refuses live execution locally before importing dependencies', () => {
  const temp = mkdtempSync(join(tmpdir(), 'sonnet-offline-'));
  try {
    const root = join(temp, 'sonnet-smoke-current');
    const script = fileURLToPath(new URL('../../evals/diagnostics/sonnet-smoke.mjs', import.meta.url));
    const env = { ...process.env, RUNNER_TEMP: temp, GITHUB_ACTIONS: 'false', SMOKE_LIVE: '0',
      COPILOT_GITHUB_TOKEN: '', NODE_OPTIONS: '' };
    const invoke = (...args) => spawnSync(process.execPath, [script, ...args], { env, encoding: 'utf8', timeout: 5000 });
    assert.equal(invoke('prepare', root, 'current').status, 0);
    assert.equal(invoke('prepare', root, 'current').status, 1);
    const probe = invoke('probe', root, 'current');
    assert.equal(probe.status, 1);
    const checkpoint = JSON.parse(readFileSync(join(root, 'checkpoint.json'), 'utf8'));
    assert.equal(checkpoint.status, 'blocked'); assert.equal(checkpoint.stage, 'guard');
    assert.equal(checkpoint.graphVerified, false);
    assert.equal(invoke('publish', root, 'current', join(temp, 'public.json')).status, 0);
    const safe = JSON.parse(readFileSync(join(temp, 'public.json'), 'utf8'));
    assert.equal(safe.status, 'blocked');
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('real publisher rejects missing and malformed evidence without printing payloads', () => {
  const temp = mkdtempSync(join(tmpdir(), 'sonnet-publish-'));
  try {
    const root = join(temp, 'sonnet-smoke-current');
    const output = join(temp, 'public.json');
    const script = fileURLToPath(new URL('../../evals/diagnostics/sonnet-smoke.mjs', import.meta.url));
    const env = { ...process.env, RUNNER_TEMP: temp, GITHUB_ACTIONS: 'false', SMOKE_LIVE: '0',
      COPILOT_GITHUB_TOKEN: '', NODE_OPTIONS: '' };
    const invoke = (...args) => spawnSync(process.execPath, [script, ...args], { env, encoding: 'utf8', timeout: 5000 });
    for (const malformed of [false, true]) {
      if (malformed) {
        assert.equal(invoke('prepare', root, 'current').status, 0);
        writeFileSync(join(root, 'checkpoint.json'), '{SYNTHETIC_SECRET');
      }
      const published = invoke('publish', root, 'current', output);
      assert.equal(published.status, 0);
      assert.equal(`${published.stdout}${published.stderr}`.includes('SYNTHETIC_SECRET'), false);
      const safe = JSON.parse(readFileSync(output, 'utf8'));
      assert.equal(safe.status, 'error'); assert.equal(safe.category, 'missing-evidence');
    }
  } finally { rmSync(temp, { recursive: true, force: true }); }
});

test('runtime mismatch stops before catalog, session or prompt', async () => {
  const f = fake(); f.client.getStatus = async () => ({ version: 'different-runtime' });
  const result = await runProbe({ ...f, workDir: '/empty', result: evidence(), limitMs: 100 });
  assert.equal(result.category, 'runtime-version-mismatch');
  assert.deepEqual(f.calls, ['start', 'stop']);
});

test('an executor cannot send a second model turn', async () => {
  const f = fake();
  class Twice extends f.Executor {
    async execute() {
      const session = await this.client.createSession({});
      await session.sendAndWait();
      await session.sendAndWait();
    }
  }
  const result = await runProbe({ ...f, Executor: Twice, workDir: '/empty', result: evidence(), limitMs: 100 });
  assert.equal(result.status, 'error');
  assert.equal(f.calls.filter(call => call === 'send').length, 1);
});