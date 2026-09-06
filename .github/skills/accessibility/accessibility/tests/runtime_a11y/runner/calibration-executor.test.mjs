// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';

import {
  classifyAtCaseResult,
  defaultRunAtCase,
  detectGuidepupNvda,
  persistSampleEvidence,
  probePrerequisites,
  resolveArtifactPath,
  resolveCalibrationCases,
  resolveContainedArtifactPath,
  runDefaultVisualPreflight,
  runRealCalibrationSession,
} from '../../../scripts/runtime_a11y/runner/calibration-executor.mjs';

function computeArtifactHash(filePath) {
  return createHash('sha256').update(readFileSync(filePath)).digest('hex');
}

test('resolveCalibrationCases ignores the unvalidated journeyId alias', () => {
  const cases = resolveCalibrationCases({
    calibration: { journeys: [{ id: 'safe', journeyId: '../../../../outside' }] },
  });
  assert.equal(cases.length, 1);
  assert.equal(cases[0].journeyId, 'safe');
});

test('resolveCalibrationCases rejects a traversal-bearing journey identifier', () => {
  assert.throws(
    () => resolveCalibrationCases({ calibration: { journeys: [{ journeyId: '../../escape' }] } }),
    /Journey ID/,
  );
  assert.throws(
    () => resolveCalibrationCases({ calibration: { journeys: [{ id: '../../escape' }] } }),
    /Journey ID/,
  );
});

test('persistSampleEvidence refuses to write outside the run root', () => {
  const runRoot = mkdtempSync(join(tmpdir(), 'a11y-calibration-escape-'));
  const escapeRoot = mkdtempSync(join(tmpdir(), 'a11y-calibration-outside-'));
  try {
    assert.throws(
      () => persistSampleEvidence({
        runRoot,
        journeyId: '../../escape',
        ordinal: 0,
        payload: { marker: 'should-not-be-written' },
      }),
      /Journey ID/,
    );
    // The containment assertion is proven independently of the identifier grammar.
    assert.throws(
      () => persistSampleEvidence({
        runRoot: join(runRoot, 'nested'),
        journeyId: '..',
        ordinal: 0,
        payload: { marker: 'should-not-be-written' },
      }),
      /Journey ID|escapes the run root/,
    );
    assert.equal(existsSync(join(runRoot, '..', 'escape')), false);
    assert.deepEqual(readdirSync(escapeRoot), []);
  } finally {
    rmSync(runRoot, { recursive: true, force: true });
    rmSync(escapeRoot, { recursive: true, force: true });
  }
});

// Minimal Playwright browser double. runRealCalibrationSession opens one shared
// page per session; without this the session launches real headed Chrome, which
// has no display on a CI runner.
function stubBrowser() {
  const page = {
    context() {
      return {};
    },
    async close() {},
  };
  return {
    async newPage() {
      return page;
    },
    async close() {},
  };
}

test('resolveContainedArtifactPath rejects absolute, traversal, URI, and symlink escape paths', () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-artifact-'));
  try {
    const safePath = join(tempDir, 'safe', 'artifact.json');
    mkdirSync(dirname(safePath), { recursive: true });
    writeFileSync(safePath, JSON.stringify({ ok: true }), 'utf8');

    assert.equal(resolveContainedArtifactPath('safe/artifact.json', tempDir), safePath);
    assert.equal(resolveContainedArtifactPath('../outside.json', tempDir), null);
    assert.equal(resolveContainedArtifactPath('/tmp/outside.json', tempDir), null);
    assert.equal(resolveContainedArtifactPath('https://example.test/artifact.json', tempDir), null);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('resolveCalibrationCases preserves the configured journeys and profile metadata', () => {
  const cases = resolveCalibrationCases({
    baseUrl: 'http://127.0.0.1:3000',
    calibration: {
      journeys: [
        {
          id: 'search-keyboard-reachability',
          route: '/',
          surfaceId: 'homepage',
          state: 'desktop',
          trigger: { action: 'focus', target: '#search' },
          triggerAfterDriverStart: true,
          commands: [{ kind: 'keyboard', value: 'Tab' }],
          assertions: [{ id: 'speech', type: 'orderedContains', value: 'search' }],
          profileFingerprint: { locale: 'en-US' },
        },
        {
          id: 'search-status-announcement',
          route: '/search',
          surfaceId: 'search-results',
          state: 'desktop',
          trigger: { action: 'click', target: '#search-results' },
          commands: [{ kind: 'keyboard', value: 'Enter' }],
          assertions: [{ id: 'speech', type: 'contains', value: 'results' }],
          profileFingerprint: { locale: 'en-US' },
        },
      ],
    },
  });

  assert.equal(cases.length, 2);
  assert.equal(cases[0].journeyId, 'search-keyboard-reachability');
  assert.equal(cases[0].profileFingerprint.locale, 'en-US');
  assert.equal(cases[0].triggerAfterDriverStart, true);
  assert.equal(cases[1].journeyId, 'search-status-announcement');
});

test('defaultRunAtCase preserves trigger timing metadata for the AT executor', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-trigger-meta-'));
  try {
    const journey = {
      journeyId: 'search-keyboard-reachability',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      triggerAfterDriverStart: true,
      commands: [{ kind: 'keyboard', value: 'Tab' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
      profileFingerprint: { locale: 'en-US' },
    };

    await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 0,
      processAtPlanCaseImpl: async ({ matrixCase, runtimeConfig }) => {
        assert.equal(matrixCase.triggerAfterDriverStart, true);
        assert.equal(runtimeConfig.triggerAfterDriverStart, true);
        return {
          status: 'pass',
          evidence: {
            rawPhrases: ['search'],
            normalizedPhrases: ['search'],
            browserState: { url: 'http://127.0.0.1:3000/' },
            accessibilityTree: { role: 'searchbox' },
            provenance: {
              driver: 'guidepup',
              profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
              nvdaVersion: '2024.1',
              browserVersion: '120',
            },
          },
        };
      },
    });
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('defaultRunAtCase forwards a provided browser to the AT executor', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-browser-pass-through-'));
  try {
    const sharedBrowser = { id: 'shared-browser' };
    const journey = {
      journeyId: 'search-keyboard-reachability',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      commands: [{ kind: 'keyboard', value: 'Tab' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
      profileFingerprint: { locale: 'en-US' },
    };

    await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 0,
      browser: sharedBrowser,
      processAtPlanCaseImpl: async ({ browser }) => {
        assert.equal(browser, sharedBrowser);
        return {
          status: 'pass',
          assertions: [{ id: 'speech', status: 'pass' }],
          evidence: {
            rawPhrases: ['search'],
            normalizedPhrases: ['search'],
            browserState: { url: 'http://127.0.0.1:3000/' },
            accessibilityTree: { role: 'searchbox' },
            provenance: {
              driver: 'guidepup',
              profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
              nvdaVersion: '2024.1',
              browserVersion: '120',
            },
          },
        };
      },
    });
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('defaultRunAtCase carries journey postCommandSettleMs onto matrixCase and leaves omitted values undefined', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-settle-propagation-'));
  try {
    const journeys = [
      {
        journeyId: 'search-keyboard-reachability',
        title: 'Search results announcement',
        route: '/',
        surfaceId: 'homepage',
        state: 'desktop',
        trigger: { action: 'focus', target: '#search' },
        commands: [{ kind: 'keyboard', value: 'Tab' }],
        assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
        postCommandSettleMs: 25,
        profileFingerprint: { locale: 'en-US' },
      },
      {
        journeyId: 'search-status-announcement',
        title: 'Search status update',
        route: '/search',
        surfaceId: 'search-results',
        state: 'desktop',
        trigger: { action: 'click', target: '#search-results' },
        commands: [{ kind: 'keyboard', value: 'Enter' }],
        assertions: [{ id: 'speech', type: 'contains', value: 'results' }],
        profileFingerprint: { locale: 'en-US' },
      },
    ];

    const observed = [];

    for (const journey of journeys) {
      await defaultRunAtCase({
        journey,
        config: { baseUrl: 'http://127.0.0.1:3000' },
        runRoot: tempDir,
        ordinal: 0,
        processAtPlanCaseImpl: async ({ matrixCase }) => {
          observed.push(matrixCase.postCommandSettleMs);
          return {
            status: 'pass',
            assertions: [{ id: 'speech', status: 'pass' }],
            evidence: {
              rawPhrases: ['search'],
              normalizedPhrases: ['search'],
              browserState: { url: 'http://127.0.0.1:3000/' },
              accessibilityTree: { role: 'searchbox' },
              provenance: {
                driver: 'guidepup',
                profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
                nvdaVersion: '2024.1',
                browserVersion: '120',
              },
            },
          };
        },
      });
    }

    assert.deepEqual(observed, [25, undefined]);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('resolveCalibrationCases preserves captureMode and defaultRunAtCase forwards it onto matrixCase', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-capture-mode-'));
  try {
    const cases = resolveCalibrationCases({
      baseUrl: 'http://127.0.0.1:3000',
      calibration: {
        journeys: [
          {
            id: 'search-keyboard-reachability',
            title: 'Search results announcement',
            route: '/',
            surfaceId: 'homepage',
            state: 'desktop',
            trigger: { action: 'focus', target: '#search' },
            captureMode: 'clear-and-capture',
            commands: [{ kind: 'keyboard', value: 'Tab' }],
            assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
            profileFingerprint: { locale: 'en-US' },
          },
        ],
      },
    });

    assert.equal(cases[0].captureMode, 'clear-and-capture');

    const observed = [];
    await defaultRunAtCase({
      journey: cases[0],
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 0,
      processAtPlanCaseImpl: async ({ matrixCase }) => {
        observed.push(matrixCase.captureMode);
        return {
          status: 'pass',
          assertions: [{ id: 'speech', status: 'pass' }],
          evidence: {
            rawPhrases: ['search'],
            normalizedPhrases: ['search'],
            browserState: { url: 'http://127.0.0.1:3000/' },
            accessibilityTree: { role: 'searchbox' },
            provenance: {
              driver: 'guidepup',
              profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
              nvdaVersion: '2024.1',
              browserVersion: '120',
            },
          },
        };
      },
    });

    assert.deepEqual(observed, ['clear-and-capture']);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('runRealCalibrationSession records browser teardown failures without throwing', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-teardown-'));
  try {
    const sharedContext = {};
    const sharedPage = {
      context() {
        return sharedContext;
      },
      async close() {},
    };
    const sharedBrowser = {
      async newPage() {
        return sharedPage;
      },
      async close() {
        throw new Error('browser close failed');
      },
      isConnected() {
        return false;
      },
    };

    const session = await runRealCalibrationSession({
      config: {
        baseUrl: 'http://127.0.0.1:3000',
        calibration: {
          journeys: [
            {
              id: 'baseline',
              bugId: 'baseline',
              title: 'Baseline',
              route: '/',
              surfaceId: 'homepage',
              state: 'desktop',
              trigger: { action: 'focus', target: 'body' },
              commands: [],
              assertions: [{ id: 'speech', type: 'contains', value: 'baseline' }],
            },
          ],
        },
      },
      runRoot: tempDir,
      probePrerequisites: async () => ({ nvdaAvailable: true, desktopUnlocked: true }),
      runVisualPreflight: async () => ({ status: 'pass', summary: { classification: 'pass' } }),
      launchBrowser: async () => sharedBrowser,
      runAtCase: async ({ journey }) => {
        const evidencePath = join(tempDir, 'journeys', journey.journeyId, '0', 'evidence.json');
        mkdirSync(dirname(evidencePath), { recursive: true });
        writeFileSync(evidencePath, JSON.stringify({ ok: true, journeyId: journey.journeyId }), 'utf8');
        const artifactReference = `journeys/${journey.journeyId}/0/evidence.json`;
        return {
          journeyId: journey.journeyId,
          classification: 'pass',
          profileFingerprint: { locale: 'en-US' },
          provenance: { driver: 'guidepup', at: 'nvda' },
          artifactHashes: { [artifactReference]: computeArtifactHash(evidencePath) },
          evidence: {
            rawPhrases: [journey.journeyId],
            normalizedPhrases: [journey.journeyId],
            browserState: { url: 'http://127.0.0.1:3000/' },
            accessibilityTree: { role: 'document' },
            assertions: [{ id: 'speech', status: 'pass' }],
            provenance: { driver: 'guidepup', at: 'nvda' },
          },
          outcome: { status: 'pass' },
        };
      },
    });

    assert.equal(session.browserTeardown.pageCloseStatus, 'closed');
    assert.equal(session.browserTeardown.pageCloseError, null);
    assert.equal(session.browserTeardown.browserCloseStatus, 'failed');
    assert.equal(session.browserTeardown.browserCloseError, 'browser close failed');
    assert.equal(session.browserTeardown.browserConnectedAfterClose, false);
    assert.equal(session.aggregate.status, 'successful');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('defaultRunAtCase handles circular evidence payloads without overflowing the stack', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-circular-'));
  try {
    const journey = {
      journeyId: 'search-keyboard-reachability',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      commands: [{ kind: 'keyboard', value: 'Tab' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
      profileFingerprint: { locale: 'en-US' },
    };

    const circularPayload = { self: null };
    circularPayload.self = circularPayload;

    const result = await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 5,
      processAtPlanCaseImpl: async () => ({
        status: 'pass',
        driver: 'guidepup',
        at: 'nvda',
        capability: { supported: true, synthetic: false, at: 'nvda' },
        assertions: [{ id: 'speech', status: 'pass' }],
        evidence: {
          synthetic: false,
          rawPhrases: ['search'],
          normalizedPhrases: ['search'],
          browserState: { url: 'http://127.0.0.1:3000/' },
          accessibilityTree: { role: 'searchbox' },
          provenance: {
            profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
            nvdaVersion: '2024.1',
            browserVersion: '120',
          },
          circular: circularPayload,
        },
      }),
    });

    assert.equal(result.classification, 'pass');
    assert.equal(Object.keys(result.artifactHashes).length, 1);
    const evidencePath = join(tempDir, 'journeys', 'search-keyboard-reachability', '5', 'evidence.json');
    assert.equal(readFileSync(evidencePath, 'utf8').includes('"journeyId": "search-keyboard-reachability"'), true);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('defaultRunAtCase writes evidence files and classifies pass only when evidence is real', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-executor-'));
  try {
    const journey = {
      journeyId: '14399',
      bugId: '14399',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      selector: '#search',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      commands: [{ kind: 'keyboard', value: 'Tab' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
      profileFingerprint: { locale: 'en-US' },
    };

    const result = await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 3,
      processAtPlanCaseImpl: async ({ matrixCase }) => {
        assert.equal(matrixCase.surface, 'homepage');
        assert.equal(matrixCase.runtimeConfig.approvedProfile.locale, 'en-US');
        return {
          status: 'pass',
          assertions: [{ id: 'speech', status: 'pass' }],
          evidence: {
            rawPhrases: ['search'],
            normalizedPhrases: ['search'],
            browserState: { url: 'http://127.0.0.1:3000/' },
            accessibilityTree: { role: 'searchbox' },
            provenance: {
              driver: 'guidepup',
              profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
              nvdaVersion: '2024.1',
              browserVersion: '120',
            },
          },
        };
      },
    });

    const evidencePath = join(tempDir, 'journeys', '14399', '3', 'evidence.json');
    const evidenceReference = Object.keys(result.artifactHashes)[0];
    assert.equal(result.classification, 'pass');
    assert.equal(resolveArtifactPath(evidenceReference, tempDir), evidencePath);
    assert.equal(readFileSync(evidencePath, 'utf8').includes('"journeyId": "14399"'), true);
    assert.equal(computeArtifactHash(evidencePath), result.artifactHashes[evidenceReference]);

    const noEvidenceResult = await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 4,
      processAtPlanCaseImpl: async () => ({ status: 'pass', assertions: [{ id: 'speech', status: 'pass' }], evidence: { synthetic: false } }),
    });
    assert.equal(noEvidenceResult.classification, 'infrastructureFailure');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('classifyAtCaseResult enforces Gate B evidence and assertion gating', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-gate-b-'));
  try {
    const evidencePath = join(tempDir, 'artifacts', 'evidence.json');
    mkdirSync(dirname(evidencePath), { recursive: true });
    writeFileSync(evidencePath, JSON.stringify({ ok: true }), 'utf8');
    const artifactHash = computeArtifactHash(evidencePath);

    const buildResult = (overrides = {}) => ({
      status: 'pass',
      classification: 'pass',
      driver: 'guidepup',
      at: 'nvda',
      capability: { supported: true, synthetic: false, at: 'nvda' },
      requiredAssertions: [{ id: 'speech' }],
      assertions: [{ id: 'speech', status: 'pass' }],
      artifactHashes: { 'artifacts/evidence.json': artifactHash },
      evidence: {
        synthetic: false,
        rawPhrases: ['search'],
        normalizedPhrases: ['search'],
        browserState: { url: 'http://127.0.0.1:3000/' },
        accessibilityTree: { role: 'searchbox' },
        provenance: {
          driver: 'guidepup',
          at: 'nvda',
          profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
          nvdaVersion: '2024.1',
          browserVersion: '120',
        },
      },
      ...overrides,
    });

    const cases = [
      { name: 'explicit pass cannot override candidate', mutate: (result) => { result.status = 'candidate'; result.classification = 'pass'; }, expected: 'unavailable' },
      { name: 'explicit pass cannot override unsupported', mutate: (result) => { result.status = 'unsupported'; result.classification = 'pass'; }, expected: 'unavailable' },
      { name: 'explicit pass cannot override error', mutate: (result) => { result.status = 'error'; result.classification = 'pass'; }, expected: 'infrastructureFailure' },
      { name: 'explicit pass cannot override unsupported capability', mutate: (result) => { result.capability.supported = false; result.classification = 'pass'; }, expected: 'unavailable' },
      { name: 'synthetic plus pass', mutate: (result) => { result.capability.synthetic = true; result.evidence.synthetic = true; }, expected: 'unavailable' },
      { name: 'missing assertion', mutate: (result) => { result.assertions = []; }, expected: 'assertionFailure' },
      { name: 'failed assertion', mutate: (result) => { result.assertions = [{ id: 'speech', status: 'fail' }]; }, expected: 'assertionFailure' },
      { name: 'product reason cannot pass', mutate: (result) => { result.evidence.reason = 'deterministic product defect'; }, expected: 'productFailure' },
      { name: 'transcript drift cannot pass', mutate: (result) => { result.evidence.reason = 'baseline mismatch'; }, expected: 'transcriptDrift' },
      { name: 'infrastructure error cannot pass', mutate: (result) => { result.evidence.error = 'browser launch failed'; }, expected: 'infrastructureFailure' },
      { name: 'empty phrases', mutate: (result) => { result.evidence.rawPhrases = []; result.evidence.normalizedPhrases = []; }, expected: 'infrastructureFailure' },
      { name: 'unpersisted evidence', mutate: (result) => { result.artifactHashes = {}; }, expected: 'infrastructureFailure' },
      { name: 'hash mismatch', mutate: (result) => { result.artifactHashes['artifacts/evidence.json'] = 'deadbeef'; }, expected: 'infrastructureFailure' },
      { name: 'valid real pass', mutate: () => {}, expected: 'pass' },
    ];

    for (const testCase of cases) {
      const result = buildResult();
      testCase.mutate(result);
      assert.equal(classifyAtCaseResult(result, tempDir), testCase.expected, testCase.name);
    }
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('runRealCalibrationSession uses the final on-disk artifact hash and strips stale embedded hashes', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-hash-contract-'));
  try {
    const journey = {
      journeyId: '14399',
      bugId: '14399',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      commands: [{ kind: 'key', value: 'Shift+Tab' }, { kind: 'pause', durationMs: 50 }, { kind: 'type', value: 'agent' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'result' }],
      profileFingerprint: { locale: 'en-US' },
    };

    const session = await runRealCalibrationSession({
      config: {
        baseUrl: 'http://127.0.0.1:3000',
        calibration: { journeys: [journey] },
      },
      runRoot: tempDir,
      probePrerequisites: async () => ({ nvdaAvailable: true, desktopUnlocked: true }),
      runVisualPreflight: async () => ({ status: 'pass', summary: { classification: 'pass' } }),
      launchBrowser: async () => stubBrowser(),
      runAtCase: async () => ({
        journeyId: '14399',
        classification: 'pass',
        profileFingerprint: { locale: 'en-US' },
        provenance: { driver: 'guidepup', at: 'nvda' },
        artifactHashes: { 'journeys/14399/0/evidence.json': 'deadbeef' },
        assertions: [{ id: 'speech', status: 'pass' }],
      evidence: {
          persistedArtifact: 'journeys/14399/0/evidence.json',
          persistedArtifactHash: 'stale-self-hash',
          rawPhrases: ['result'],
          normalizedPhrases: ['result'],
          browserState: { url: 'http://127.0.0.1:3000/' },
          accessibilityTree: { role: 'searchbox' },
          assertions: [{ id: 'speech', status: 'pass' }],
          provenance: { driver: 'guidepup', at: 'nvda' },
        },
        outcome: { status: 'pass' },
      }),
    });

    const evidencePath = join(tempDir, 'journeys', '14399', '0', 'evidence.json');
    assert.equal(session.checkpoints[0].artifactHashes['journeys/14399/0/evidence.json'], computeArtifactHash(evidencePath));
    const persisted = JSON.parse(readFileSync(evidencePath, 'utf8'));
    assert.equal(persisted.evidence.persistedArtifact, 'journeys/14399/0/evidence.json');
    assert.equal(persisted.evidence.persistedArtifactHash, undefined);
    assert.equal(persisted.evidence.rawPhrases[0], 'result');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('runRealCalibrationSession reuses a single browser across journeys and closes it once', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-shared-browser-'));
  try {
    const sharedPage = {
      closeCalls: 0,
      context() {
        return sharedContext;
      },
      async close() {
        this.closeCalls += 1;
      },
    };
    const sharedContext = {};
    const sharedBrowser = {
      newPageCalls: 0,
      closeCalls: 0,
      async newPage() {
        this.newPageCalls += 1;
        return sharedPage;
      },
      async close() {
        this.closeCalls += 1;
      },
    };
    let launchCalls = 0;
    const seenBrowsers = [];
    const seenContexts = [];
    const seenPages = [];

    const session = await runRealCalibrationSession({
      config: {
        baseUrl: 'http://127.0.0.1:3000',
        calibration: {
          journeys: [
            {
              id: 'baseline',
              bugId: 'baseline',
              title: 'Baseline',
              route: '/',
              surfaceId: 'homepage',
              state: 'desktop',
              trigger: { action: 'focus', target: 'body' },
              commands: [],
              assertions: [{ id: 'speech', type: 'contains', value: 'baseline' }],
            },
            {
              id: 'alert',
              bugId: 'alert',
              title: 'Alert',
              route: '/alert',
              surfaceId: 'homepage',
              state: 'desktop',
              trigger: { action: 'focus', target: 'body' },
              commands: [],
              assertions: [{ id: 'speech', type: 'contains', value: 'alert' }],
            },
          ],
        },
      },
      runRoot: tempDir,
      probePrerequisites: async () => ({ nvdaAvailable: true, desktopUnlocked: true }),
      runVisualPreflight: async () => ({ status: 'pass', summary: { classification: 'pass' } }),
      launchBrowser: async () => {
        launchCalls += 1;
        return sharedBrowser;
      },
      runAtCase: async ({ browser, journey }) => {
        seenBrowsers.push(browser);
        seenContexts.push(sharedContext);
        seenPages.push(sharedPage);
        const evidencePath = join(tempDir, 'journeys', journey.journeyId, '0', 'evidence.json');
        mkdirSync(dirname(evidencePath), { recursive: true });
        writeFileSync(evidencePath, JSON.stringify({ ok: true, journeyId: journey.journeyId }), 'utf8');
        const artifactReference = `journeys/${journey.journeyId}/0/evidence.json`;
        return {
          journeyId: journey.journeyId,
          classification: 'pass',
          profileFingerprint: { locale: 'en-US' },
          provenance: { driver: 'guidepup', at: 'nvda' },
          artifactHashes: { [artifactReference]: computeArtifactHash(evidencePath) },
          evidence: {
            rawPhrases: [journey.journeyId],
            normalizedPhrases: [journey.journeyId],
            browserState: { url: `http://127.0.0.1:3000${journey.route}` },
            accessibilityTree: { role: 'document' },
            assertions: [{ id: 'speech', status: 'pass' }],
            provenance: { driver: 'guidepup', at: 'nvda' },
          },
          outcome: { status: 'pass' },
        };
      },
    });

    assert.equal(launchCalls, 1);
    assert.equal(sharedBrowser.newPageCalls, 1);
    assert.equal(seenBrowsers.length, 2);
    assert.equal(seenContexts.length, 2);
    assert.equal(seenPages.length, 2);
    assert.equal(seenBrowsers[0], sharedBrowser);
    assert.equal(seenBrowsers[1], sharedBrowser);
    assert.equal(seenContexts[0], sharedContext);
    assert.equal(seenContexts[1], sharedContext);
    assert.equal(seenPages[0], sharedPage);
    assert.equal(seenPages[1], sharedPage);
    assert.equal(sharedPage.closeCalls, 1);
    assert.equal(sharedBrowser.closeCalls, 1);
    assert.equal(session.aggregate.status, 'successful');
    assert.equal(session.checkpoints.length, 2);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('defaultRunAtCase classifies a fully persisted real-evidence result as pass', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-pass-fixture-'));
  try {
    const journey = {
      journeyId: '14399',
      bugId: '14399',
      title: 'Search results announcement',
      route: '/',
      surfaceId: 'homepage',
      state: 'desktop',
      trigger: { action: 'focus', target: '#search' },
      commands: [{ kind: 'keyboard', value: 'Tab' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
      profileFingerprint: { locale: 'en-US' },
    };

    const result = await defaultRunAtCase({
      journey,
      config: { baseUrl: 'http://127.0.0.1:3000' },
      runRoot: tempDir,
      ordinal: 0,
      processAtPlanCaseImpl: async () => ({
        status: 'pass',
        driver: 'guidepup',
        at: 'nvda',
        capability: { supported: true, synthetic: false, at: 'nvda' },
        assertions: [{ id: 'speech', status: 'pass' }],
        evidence: {
          synthetic: false,
          rawPhrases: ['search'],
          normalizedPhrases: ['search'],
          browserState: { url: 'http://127.0.0.1:3000/' },
          accessibilityTree: { role: 'searchbox' },
          provenance: {
            profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
            nvdaVersion: '2024.1',
            browserVersion: '120',
          },
        },
      }),
    });

    assert.equal(result.classification, 'pass');
    const evidencePath = join(tempDir, 'journeys', '14399', '0', 'evidence.json');
    assert.equal(readFileSync(evidencePath, 'utf8').includes('"journeyId": "14399"'), true);
    assert.equal(result.artifactHashes[Object.keys(result.artifactHashes)[0]], computeArtifactHash(evidencePath));
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('classifyAtCaseResult maps unsupported, assertion, product, infrastructure, and transcript drift consistently', async () => {
  const cases = [
    { name: 'unsupported', input: { status: 'unsupported', evidence: { synthetic: false } }, expected: 'unavailable' },
    { name: 'assertion', input: { status: 'fail', evidence: { assertions: [{ status: 'fail' }] } }, expected: 'assertionFailure' },
    { name: 'product', input: { status: 'fail', evidence: { reason: 'explicit deterministic product marker' } }, expected: 'productFailure' },
    { name: 'drift', input: { status: 'fail', evidence: { reason: 'baseline mismatch' } }, expected: 'transcriptDrift' },
    { name: 'infrastructure', input: { status: 'error', evidence: { error: 'browser launch failed' } }, expected: 'infrastructureFailure' },
  ];

  for (const testCase of cases) {
    const { classifyAtCaseResult } = await import('../../../scripts/runtime_a11y/runner/calibration-executor.mjs');
    assert.equal(classifyAtCaseResult(testCase.input), testCase.expected, testCase.name);
  }
});

test('detectGuidepupNvda accepts registry-backed NVDA registration without persisting installation paths', async () => {
  const result = await detectGuidepupNvda({
    platform: 'win32',
    spawn: (command, args) => {
      if (command === 'C:\\Windows\\System32\\reg.exe') {
        return {
          stdout: 'HKEY_CURRENT_USER\\Software\\Guidepup\\Nvda\n    guidepup_nvda_0.2.0-2026.1.1\n',
          stderr: '',
        };
      }
      return { stdout: '', stderr: '' };
    },
    importGuidepup: async () => null,
  });

  assert.equal(result.guidepupRegistered, true);
  assert.equal(result.guidepupVersion, '0.2.0-2026.1.1');
});

test('probePrerequisites reports ready for interactive desktop, Chrome, and isolated Guidepup NVDA', async () => {
  let browserClosed = false;
  const runtime = {
    platform: 'win32',
    env: {
      SESSIONNAME: '',
      LOCALAPPDATA: 'C:\\Users\\TestUser\\AppData\\Local',
    },
    spawnSync: (command, args = []) => {
      if (command === 'powershell.exe' || command === 'pwsh') {
        if (Array.isArray(args) && args.some((entry) => String(entry).includes('UserInteractive'))) {
          return { stdout: 'True\r\n', stderr: '' };
        }
        return { stdout: '150.0.7871.127\r\n', stderr: '' };
      }
      if (command === 'where.exe') {
        return { stdout: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe\r\n', stderr: '' };
      }
      if (command === 'tasklist') {
        return { stdout: '', stderr: '' };
      }
      return { stdout: '', stderr: '' };
    },
    dependencies: {
      launchBrowser: async () => ({
        version: () => '150.0.7871.127',
        close: async () => {
          browserClosed = true;
        },
      }),
      importGuidepup: async () => ({
        nvda: {
          start: async () => {},
          stop: async () => {},
          press: async () => {},
          spokenPhraseLog: async () => [],
          clearSpokenPhraseLog: async () => {},
          capabilities: ['nvda'],
        },
      }),
    },
  };
  const result = await probePrerequisites({}, runtime);
  assert.equal(result.ok, true);
  assert.equal(result.desktopUnlocked, true);
  assert.equal(result.chromeExecutable, 'channel:chrome');
  assert.equal(result.chromeVersion, '150.0.7871.127');
  assert.equal(result.nvdaAvailable, true);
  assert.equal(result.guidepupRegistered, true);
  assert.equal(result.reason, null);
  assert.equal(result.metadata.chromeExecutable, 'channel:chrome');
  assert.equal(result.metadata.platform, 'win32');
  assert.equal(browserClosed, true);
});

test('probePrerequisites reports the blocking reasons when Windows prerequisites are missing', async () => {
  const runtime = {
    platform: 'win32',
    env: {
      SESSIONNAME: 'Services',
    },
    spawnSync: (command, args) => {
      if (command === 'powershell.exe' || command === 'pwsh') {
        return { stdout: 'False\r\n', stderr: '' };
      }
      if (command === 'tasklist') {
        return { stdout: 'Image Name,PID,Session Name\r\nNVDA.exe,1234,Console\r\n', stderr: '' };
      }
      return { stdout: '', stderr: '' };
    },
    dependencies: {
      launchBrowser: async () => {
        throw new Error('system Chrome unavailable');
      },
      importGuidepup: async () => null,
    },
  };
  const result = await probePrerequisites({}, runtime);
  assert.equal(result.ok, false);
  assert.equal(result.desktopUnlocked, false);
  assert.equal(result.chromeExecutable, null);
  assert.equal(result.chromeVersion, null);
  assert.equal(result.nvdaAvailable, false);
  assert.equal(result.guidepupRegistered, false);
  assert.ok(result.reasons.includes('Interactive desktop was not available.'));
  assert.ok(result.reasons.includes('Chrome launch failed: system Chrome unavailable'));
  assert.ok(result.reasons.includes('NVDA registration for isolated Guidepup execution was not verified.'));
});

test('probePrerequisites fails when launched Chrome cannot be closed', async () => {
  const runtime = {
    platform: 'linux',
    env: { RUNTIME_A11Y_INTERACTIVE_DESKTOP: 'true' },
    spawnSync: () => ({ stdout: '', stderr: '' }),
    dependencies: {
      launchBrowser: async () => ({
        version: () => '150.0.7871.127',
        close: async () => {
          throw new Error('close blocked');
        },
      }),
      importGuidepup: async () => ({
        nvda: { capabilities: ['nvda'] },
      }),
    },
  };

  const result = await probePrerequisites({}, runtime);

  assert.equal(result.ok, false);
  assert.equal(result.chromeExecutable, null);
  assert.equal(result.chromeVersion, null);
  assert.ok(result.reasons.includes('Chrome close failed: close blocked'));
});

test('runDefaultVisualPreflight writes a 2x5 preflight summary and hashes the captured artifacts', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-preflight-'));
  try {
    let calls = 0;
    const runConfig = {
      baseUrl: 'http://127.0.0.1:3000',
      visualReview: {
        routes: [{ path: '/', surfaceId: 'home' }, { path: '/search', surfaceId: 'search' }],
        states: ['desktop', 'reflow-320', 'zoom-200', 'text-spacing', 'forced-colors'],
      },
    };
    const payload = await runDefaultVisualPreflight({
      config: runConfig,
      runRoot: tempDir,
      captureVisualReviewEvidenceImpl: async (config) => {
        calls += 1;
        assert.equal(config.visualReview.routes.length, 2);
        assert.equal(config.visualReview.states.length, 5);
        const runs = [];
        for (const route of config.visualReview.routes) {
          for (const state of config.visualReview.states) {
            const artifactDir = join(tempDir, 'artifacts', `${route.surfaceId}-${state}`);
            mkdirSync(artifactDir, { recursive: true });
            const screenshotPath = join(artifactDir, 'screenshot.png');
            const measurementPath = join(artifactDir, 'measurements.json');
            const tracePath = join(artifactDir, 'trace.zip');
            writeFileSync(screenshotPath, 'screenshot', 'utf8');
            writeFileSync(measurementPath, JSON.stringify({ state }), 'utf8');
            writeFileSync(tracePath, 'trace', 'utf8');
            runs.push({
              route: route.path,
              state,
              surface: route.surfaceId,
              screenshotPath: join('artifacts', `${route.surfaceId}-${state}`, 'screenshot.png').replace(/\\/g, '/'),
              measurementPath: join('artifacts', `${route.surfaceId}-${state}`, 'measurements.json').replace(/\\/g, '/'),
              tracePath: join('artifacts', `${route.surfaceId}-${state}`, 'trace.zip').replace(/\\/g, '/'),
              probeOutcomes: [{ status: 'pass' }],
            });
          }
        }
        return { runs };
      },
    });

    assert.equal(calls, 1);
    assert.equal(payload.status, 'pass');
    assert.equal(payload.summary.routeCount, 2);
    assert.equal(payload.summary.stateCount, 5);
    assert.equal(payload.summary.runCount, 10);
    assert.equal(resolveArtifactPath('preflight-summary.json', tempDir), join(tempDir, 'preflight-summary.json'));
    assert.equal(Object.keys(payload.artifactHashes).length, 31);
    assert.equal(readFileSync(join(tempDir, 'preflight-summary.json'), 'utf8').includes('"classification": "pass"'), true);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('runRealCalibrationSession preserves injection callbacks while using defaults for the rest', async () => {
  const tempDir = mkdtempSync(join(tmpdir(), 'calibration-session-'));
  try {
    const preflightArtifactPath = join(tempDir, 'artifacts', 'preflight.json');
    const caseArtifactPath = join(tempDir, 'artifacts', 'case.json');
    mkdirSync(dirname(preflightArtifactPath), { recursive: true });
    mkdirSync(dirname(caseArtifactPath), { recursive: true });
    writeFileSync(preflightArtifactPath, JSON.stringify({ status: 'pass' }, null, 2), 'utf8');
    writeFileSync(caseArtifactPath, JSON.stringify({ status: 'pass', journeyId: '14399' }, null, 2), 'utf8');
    const preflightArtifactHash = createHash('sha256').update(readFileSync(preflightArtifactPath)).digest('hex');
    const caseArtifactHash = createHash('sha256').update(readFileSync(caseArtifactPath)).digest('hex');
    let preflightRuns = 0;
    const executed = [];
    const session = await runRealCalibrationSession({
      config: {
        baseUrl: 'http://127.0.0.1:3000',
        calibration: {
          journeys: [
            {
              id: '14399',
              bugId: '14399',
              route: '/',
              surfaceId: 'homepage',
              state: 'desktop',
              trigger: { action: 'focus', target: '#search' },
              commands: [{ kind: 'keyboard', value: 'Tab' }],
              assertions: [{ id: 'speech', type: 'contains', value: 'search' }],
              profileFingerprint: { locale: 'en-US' },
            },
          ],
        },
      },
      runRoot: tempDir,
      probePrerequisites: async () => ({ nvdaAvailable: true, desktopUnlocked: true, reason: null }),
      launchBrowser: async () => stubBrowser(),
      runVisualPreflight: async () => {
        preflightRuns += 1;
        return { status: 'pass', artifactHashes: { 'artifacts/preflight.json': preflightArtifactHash }, summary: { classification: 'pass' } };
      },
      runAtCase: async ({ journeyId }) => {
        executed.push(journeyId);
        return {
          journeyId,
          classification: 'pass',
          artifactHashes: { 'artifacts/case.json': caseArtifactHash },
          capability: { supported: true, synthetic: false, at: 'nvda' },
          driver: 'guidepup',
          at: 'nvda',
          provenance: { locale: 'en-US', driver: 'guidepup', at: 'nvda' },
          outcome: { status: 'pass' },
          assertions: [{ id: 'speech', status: 'pass' }],
          evidence: {
            rawPhrases: ['search'],
            normalizedPhrases: ['search'],
            browserState: { role: 'searchbox' },
            accessibilityTree: { role: 'searchbox' },
            assertions: [{ id: 'speech', status: 'pass' }],
            provenance: {
              profileFingerprint: { locale: 'en-US', verbosity: 'default', punctuation: 'preserve', speechMode: 'default', addOnPosture: 'default' },
              driver: 'guidepup',
              at: 'nvda',
              nvdaVersion: '2024.1',
              browserVersion: '120',
            },
          },
        };
      },
    });

    assert.equal(preflightRuns, 1);
    assert.deepEqual(executed, ['14399']);
    assert.equal(session.aggregate.status, 'successful');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});
