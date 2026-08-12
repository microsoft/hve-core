// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { realScreenReaderStatus } from '../../../scripts/runtime_a11y/runner/_core.mjs';
import { evaluateAssertion } from '../../../scripts/runtime_a11y/runner/assertions.mjs';
import {
  ensureAutomationWindowFocused,
  ensureScreenReaderStopped,
  isScreenReaderCleanupUnproven,
  resolveScreenReaderVerifier,
  runRealScreenReaderProbe,
} from '../../../scripts/runtime_a11y/runner/_shared.mjs';
import { createScreenReaderDriver, validateScreenReaderConfig } from '../../../scripts/runtime_a11y/runner/drivers/driver-contract.mjs';
import { createGuidepupDriverAdapter } from '../../../scripts/runtime_a11y/runner/drivers/guidepup-adapter.mjs';

test('validateScreenReaderConfig accepts generic commands and functional assertions', () => {
  const result = validateScreenReaderConfig({
    commands: [{ kind: 'command', value: 'next' }, { kind: 'pause', durationMs: 200 }],
    expectedAnnouncements: [
      { id: 'role-name', type: 'contains', value: 'button' },
      { id: 'name', type: 'orderedContains', value: 'Clear search' },
    ],
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.errors, []);
});

test('validateScreenReaderConfig accepts explicit key commands from the allowlist and rejects unsupported values', () => {
  const allowed = validateScreenReaderConfig({
    commands: [{ kind: 'key', value: 'Shift+Tab' }, { kind: 'key', value: 'ArrowDown' }],
  });
  const rejected = validateScreenReaderConfig({
    commands: [{ kind: 'key', value: 'Ctrl+Alt+Delete' }],
  });

  assert.equal(allowed.ok, true);
  assert.equal(rejected.ok, false);
  assert.match(rejected.errors[0], /Unsupported key/);
});

test('validateScreenReaderConfig accepts allowlisted perform commands and rejects unknown ones', () => {
  const allowed = validateScreenReaderConfig({
    commands: [{ kind: 'perform', value: 'moveToNextFormField' }, { kind: 'perform', value: 'performDefaultActionForItem' }],
  });
  const rejected = validateScreenReaderConfig({
    commands: [{ kind: 'perform', value: 'notARealNvdaCommand' }],
  });

  assert.equal(allowed.ok, true);
  assert.equal(rejected.ok, false);
  assert.match(rejected.errors[0], /Unsupported perform/);
});

test('validateScreenReaderConfig accepts Control+A as a bounded edit command', () => {
  const allowed = validateScreenReaderConfig({
    commands: [{ kind: 'key', value: 'Control+A' }],
  });

  assert.equal(allowed.ok, true);
  assert.deepEqual(allowed.errors, []);
});

test('validateScreenReaderConfig accepts bounded type commands and rejects empty strings', () => {
  const allowed = validateScreenReaderConfig({
    commands: [{ kind: 'type', value: 'agent' }],
  });
  const rejected = validateScreenReaderConfig({
    commands: [{ kind: 'type', value: '' }],
  });
  const overLength = validateScreenReaderConfig({
    commands: [{ kind: 'type', value: 'x'.repeat(257) }],
  });

  assert.equal(allowed.ok, true);
  assert.equal(rejected.ok, false);
  assert.equal(overLength.ok, false);
  assert.match(rejected.errors[0], /non-empty/);
  assert.match(overLength.errors[0], /256/);
});

test('validateScreenReaderConfig accepts harness-executed waitFor commands', () => {
  const allowed = validateScreenReaderConfig({
    commands: [{ kind: 'waitFor', value: '[role="listbox"]', durationMs: 5000 }],
  });
  const missingSelector = validateScreenReaderConfig({
    commands: [{ kind: 'waitFor', value: '   ' }],
  });
  const negativeDuration = validateScreenReaderConfig({
    commands: [{ kind: 'waitFor', value: '[role="listbox"]', durationMs: -1 }],
  });

  assert.equal(allowed.ok, true);
  assert.deepEqual(allowed.errors, []);
  assert.equal(missingSelector.ok, false);
  assert.match(missingSelector.errors[0], /selector/);
  assert.equal(negativeDuration.ok, false);
  assert.match(negativeDuration.errors[0], /non-negative/);
});

test('createScreenReaderDriver reports unsupported platforms without starting a real screen reader', async () => {
  const driver = await createScreenReaderDriver({ platform: 'linux', driverName: 'guidepup' });

  assert.equal(driver.supported, false);
  assert.equal(driver.status, 'unsupported-platform');
});

test('realScreenReaderStatus returns candidate for unsupported, missing, or adapter-error snapshots', () => {
  assert.equal(realScreenReaderStatus({ ran: false, error: 'unsupported platform' }), 'candidate');
  assert.equal(realScreenReaderStatus({ ran: true, phrases: [], assertions: [] }), 'candidate');
  assert.equal(realScreenReaderStatus({ ran: true, phrases: ['button, Clear search'], assertions: [{ status: 'fail' }] }), 'fail');
});

test('evaluateAssertion supports contains, orderedContains, and matches semantics', () => {
  assert.deepEqual(evaluateAssertion({ type: 'contains', value: 'button' }, ['button, Clear search']), {
    status: 'pass',
    detail: 'contains matched the speech evidence',
    evidenceType: 'speech',
  });
  assert.deepEqual(evaluateAssertion({ type: 'orderedContains', value: 'Clear search' }, ['button, Clear search']), {
    status: 'pass',
    detail: 'orderedContains matched the speech evidence',
    evidenceType: 'speech',
  });
  assert.deepEqual(evaluateAssertion({ type: 'orderedContains', value: 'search clear' }, ['button, Clear search']), {
    status: 'fail',
    detail: 'orderedContains tokens were not found in order for speech',
    evidenceType: 'speech',
  });
  assert.deepEqual(evaluateAssertion({ type: 'matches', value: 'button.*search' }, ['button, Clear search']), {
    status: 'pass',
    detail: 'matches matched the speech evidence',
    evidenceType: 'speech',
  });
});

test('evaluateAssertion reports invalid regular expressions without throwing', () => {
  const result = evaluateAssertion({ type: 'matches', value: '[' }, ['button, Clear search']);

  assert.equal(result.status, 'invalid-config');
  assert.equal(result.detail.includes('Invalid regular expression'), true);
});

test('evaluateAssertion bounds config-supplied patterns before compiling them', () => {
  const overlong = evaluateAssertion(
    { type: 'matches', value: 'a'.repeat(513) },
    ['button, Clear search'],
  );
  assert.equal(overlong.status, 'invalid-config');
  assert.match(overlong.detail, /exceeds 512 characters/);

  const nested = evaluateAssertion(
    { type: 'matches', value: '(a+)+'.repeat(9) },
    ['button, Clear search'],
  );
  assert.equal(nested.status, 'invalid-config');
  assert.match(nested.detail, /quantifiers/);

  // Quantifier characters inside a character class are literals and must not
  // count toward the budget, so a legitimate pattern is still compiled.
  const literalClass = evaluateAssertion(
    { type: 'matches', value: '[*+{]*button' },
    ['button, Clear search'],
  );
  assert.equal(literalClass.status, 'pass');
});

test('assertion families evaluate independently for speech, browser state, and accessibility tree evidence', () => {
  const speech = evaluateAssertion({ id: 'speech', type: 'contains', value: 'checked', evidenceType: 'speech' }, ['checked', 'checkbox']);
  const browser = evaluateAssertion({ id: 'browser', type: 'contains', value: 'checked', evidenceType: 'browserState' }, ['checked', 'checkbox']);
  const tree = evaluateAssertion({ id: 'tree', type: 'contains', value: 'checkbox', evidenceType: 'accessibilityTree' }, ['checked', 'checkbox']);

  assert.equal(speech.status, 'pass');
  assert.equal(browser.status, 'pass');
  assert.equal(tree.status, 'pass');
  assert.equal(speech.evidenceType, 'speech');
  assert.equal(browser.evidenceType, 'browserState');
  assert.equal(tree.evidenceType, 'accessibilityTree');
});

test('evaluation can use raw speech by default and normalized speech when explicitly selected', () => {
  const rawResult = evaluateAssertion(
    { type: 'contains', value: 'search results' },
    { speech: ['Search Results'], normalizedSpeech: ['results'] },
    { useNormalizedSpeech: false },
  );
  const normalizedResult = evaluateAssertion(
    { type: 'contains', value: 'search results' },
    { speech: ['Search Results'], normalizedSpeech: ['search results'] },
    { useNormalizedSpeech: true },
  );

  assert.equal(rawResult.status, 'pass');
  assert.equal(normalizedResult.status, 'pass');
});

test('createScreenReaderDriver supports a fake driver seam for deterministic tests', async () => {
  const driver = await createScreenReaderDriver({ platform: 'win32', driverName: 'fake', config: { commands: [{ kind: 'command', value: 'perform' }] } });

  assert.equal(driver.supported, true);
  assert.equal(driver.status, 'ready');
  assert.equal(driver.driver, 'fake');
});

test('ensureAutomationWindowFocused succeeds when the foreground probe matches the controlled browser window', async () => {
  const page = {
    title: async () => 'Example Page',
    bringToFront: async () => undefined,
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 42, bounds: { windowState: 'maximized' } };
          }
          if (method === 'Target.getTargetInfo') {
            return { targetInfo: { title: 'Example Page', url: 'https://example.test/' } };
          }
          throw new Error(`Unexpected CDP method: ${method}`);
        },
      };
    },
  };

  const result = await ensureAutomationWindowFocused({
    page,
    browser: { process: () => ({ pid: 5100 }) },
    context,
    timeoutMs: 1000,
    pollIntervalMs: 10,
    platform: 'win32',
    readForegroundIdentity: async () => ({
      title: 'Example Page - Google Chrome',
      processId: 5150,
    }),
    readProcesses: async () => new Map([[5150, 5100], [5100, 800]]),
  });

  assert.equal(result.status, 'bound');
  assert.equal(result.expectedIdentity?.windowId, 42);
  assert.equal(result.foregroundIdentity?.windowTitle, 'Example Page - Google Chrome');
});

test('ensureAutomationWindowFocused performs one remediation attempt before failing closed', async () => {
  let remediationCount = 0;
  const page = {
    title: async () => 'Example Page',
    async bringToFront() {
      remediationCount += 1;
    },
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 7, bounds: { windowState: 'normal' } };
          }
          throw new Error(`Unexpected CDP method: ${method}`);
        },
      };
    },
  };
  let foregroundPasses = 0;

  const result = await ensureAutomationWindowFocused({
    page,
    browser: { process: () => ({ pid: 5100 }) },
    context,
    timeoutMs: 100,
    pollIntervalMs: 10,
    platform: 'win32',
    readForegroundIdentity: async () => {
      foregroundPasses += 1;
      return foregroundPasses === 1
        ? { title: 'Different Window', processId: 6000 }
        : { title: 'Example Page - Google Chrome', processId: 5150 };
    },
    readProcesses: async () => new Map([[6000, 800], [5150, 5100], [5100, 800]]),
    activateWindow: async () => true,
  });

  assert.equal(result.status, 'bound');
  assert.equal(remediationCount, 2);
  assert.equal(result.remediationAttempted, true);
});

test('createGuidepupDriverAdapter resolves allowlisted perform commands through a stubbed NVDA target', async () => {
  const performed = [];
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    target: {
      start: async () => undefined,
      stop: async () => undefined,
      press: async () => undefined,
      perform: async (command) => {
        performed.push(command);
      },
      keyboardCommands: {
        moveToNextFormField: { id: 'moveToNextFormField' },
        performDefaultActionForItem: { id: 'performDefaultActionForItem' },
      },
      spokenPhraseLog: async () => [],
    },
  });

  await adapter.executeCommand({ kind: 'perform', value: 'moveToNextFormField' });
  await adapter.executeCommand({ kind: 'perform', value: 'performDefaultActionForItem' });

  assert.equal(adapter.supported, true);
  assert.deepEqual(performed, [{ id: 'moveToNextFormField' }, { id: 'performDefaultActionForItem' }]);
});

test('createGuidepupDriverAdapter rejects unknown perform commands before dispatch', async () => {
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    target: {
      start: async () => undefined,
      stop: async () => undefined,
      press: async () => undefined,
      perform: async () => undefined,
      keyboardCommands: {
        toggleBetweenBrowseAndFocusMode: { id: 'toggleBetweenBrowseAndFocusMode' },
      },
      spokenPhraseLog: async () => [],
    },
  });

  await assert.rejects(adapter.executeCommand({ kind: 'perform', value: 'notARealNvdaCommand' }), /Unsupported perform/);
});

test('createGuidepupDriverAdapter dispatches type commands through the NVDA target', async () => {
  const typed = [];
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    target: {
      start: async () => undefined,
      stop: async () => undefined,
      press: async () => undefined,
      type: async (value) => {
        typed.push(value);
      },
      spokenPhraseLog: async () => [],
    },
  });

  await adapter.executeCommand({ kind: 'type', value: 'agent' });

  assert.deepEqual(typed, ['agent']);
});

test('createGuidepupDriverAdapter tracks ownership and cleanup state for start/stop lifecycle', async () => {
  const stopCalls = [];
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    target: {
      start: async () => undefined,
      stop: async () => {
        stopCalls.push('stopped');
      },
      press: async () => undefined,
      spokenPhraseLog: async () => [],
    },
  });

  assert.equal(adapter.cleanupState().startedByAdapter, false);
  assert.equal(adapter.cleanupState().started, false);

  await adapter.start();
  assert.equal(adapter.cleanupState().startedByAdapter, true);
  assert.equal(adapter.cleanupState().started, true);

  await adapter.stop();
  assert.equal(stopCalls.length, 1);
  assert.equal(adapter.cleanupState().startedByAdapter, false);
  assert.equal(adapter.cleanupState().started, false);

  await adapter.stop();
  assert.equal(stopCalls.length, 1);
});

test('createGuidepupDriverAdapter retries startup and settles after stop', async () => {
  const sleeps = [];
  let startCalls = 0;
  let stopCalls = 0;
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    config: {
      lifecycle: {
        startAttempts: 3,
        startRetryDelayMs: 5,
        stopSettleDelayMs: 7,
      },
    },
    sleep: async (durationMs) => {
      sleeps.push(durationMs);
    },
    target: {
      start: async () => {
        startCalls += 1;
        if (startCalls === 1) {
          throw new Error('Timed out waiting for NVDA to be running');
        }
      },
      stop: async () => {
        stopCalls += 1;
      },
      press: async () => undefined,
      spokenPhraseLog: async () => [],
    },
  });

  await adapter.start();
  await adapter.stop();

  assert.equal(startCalls, 2);
  assert.equal(stopCalls, 2);
  assert.equal(sleeps.includes(5), true);
  assert.equal(sleeps.includes(7), true);
});

test('createGuidepupDriverAdapter times out a hung startup attempt and retries', async () => {
  const sleeps = [];
  let startCalls = 0;
  let stopCalls = 0;
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    config: {
      lifecycle: {
        startAttempts: 2,
        startRetryDelayMs: 3,
        startTimeoutMs: 5,
        stopTimeoutMs: 5,
        stopSettleDelayMs: 0,
      },
    },
    sleep: async (durationMs) => {
      sleeps.push(durationMs);
    },
    target: {
      start: async () => {
        startCalls += 1;
        if (startCalls === 1) {
          return new Promise(() => {});
        }
      },
      stop: async () => {
        stopCalls += 1;
      },
      press: async () => undefined,
      spokenPhraseLog: async () => [],
    },
  });

  await adapter.start();
  await adapter.stop();

  assert.equal(startCalls, 2);
  assert.equal(stopCalls >= 2, true);
  assert.equal(sleeps.includes(3), true);
});

test('createGuidepupDriverAdapter keeps ownership state when the stop fails and re-attempts it on retry', async () => {
  let stopCalls = 0;
  const adapter = await createGuidepupDriverAdapter({
    platform: 'win32',
    config: {
      lifecycle: {
        startAttempts: 1,
        stopSettleDelayMs: 0,
      },
    },
    sleep: async () => undefined,
    target: {
      start: async () => undefined,
      stop: async () => {
        stopCalls += 1;
        if (stopCalls === 1) {
          throw new Error('nvda --quit did not exit');
        }
      },
      press: async () => undefined,
      spokenPhraseLog: async () => [],
    },
  });

  await adapter.start();

  await assert.rejects(adapter.stop(), /did not exit/);
  assert.deepEqual(adapter.cleanupState(), { startedByAdapter: true, started: true });

  await adapter.stop();
  assert.equal(stopCalls, 2);
  assert.deepEqual(adapter.cleanupState(), { startedByAdapter: false, started: false });
});

test('runRealScreenReaderProbe keeps its accessibility result while reporting an unproven stop', async () => {
  const result = await runRealScreenReaderProbe(null, {
    config: {},
    createDriver: async () => ({
      supported: true,
      status: 'ready',
      driver: 'fake',
      async start() {},
      async executeCommand() {},
      async captureLog() {
        return { driver: 'fake', phrases: ['button, Clear search'], assertions: [] };
      },
      async stop() {
        throw new Error('Guidepup NVDA stop timed out after 10000ms');
      },
    }),
    verifyScreenReaderStopped: async () => ({
      stopped: false,
      terminated: false,
      reason: 'screen-reader-still-running',
    }),
  });

  assert.equal(result.ran, true);
  assert.equal(result.phraseCount, 1);
  assert.equal(result.phrases, undefined);
  assert.equal(result.transcript.sha256.length, 64);
  assert.equal(result.transcript.retained, false);
  assert.ok(!result.evidence.includes('Clear search'));
  assert.equal(result.cleanup.driverStarted, true);
  assert.equal(result.cleanup.driverStopped, false);
  assert.match(result.cleanup.stopError, /timed out/);
  assert.equal(result.cleanup.reason, 'screen-reader-still-running');
  assert.equal(isScreenReaderCleanupUnproven(result.cleanup), true);
});

test('runRealScreenReaderProbe records a forced termination rather than a clean stop', async () => {
  const result = await runRealScreenReaderProbe(null, {
    config: {},
    createDriver: async () => ({
      supported: true,
      status: 'ready',
      driver: 'fake',
      async start() {},
      async executeCommand() {},
      async captureLog() {
        return { driver: 'fake', phrases: [], assertions: [] };
      },
      async stop() {},
    }),
    verifyScreenReaderStopped: async () => ({ stopped: true, terminated: true, reason: null }),
  });

  assert.equal(result.cleanup.driverStopped, true);
  assert.equal(result.cleanup.terminated, true);
  assert.equal(result.cleanup.stopError, null);
  assert.equal(isScreenReaderCleanupUnproven(result.cleanup), false);
});

test('the probe stop verifier defaults to the production implementation when none is injected', () => {
  assert.equal(resolveScreenReaderVerifier(undefined), ensureScreenReaderStopped);
  assert.equal(resolveScreenReaderVerifier(null), ensureScreenReaderStopped);
  assert.equal(resolveScreenReaderVerifier({ stopped: true }), ensureScreenReaderStopped);

  const injected = async () => ({ stopped: true, terminated: false, reason: null });
  assert.equal(resolveScreenReaderVerifier(injected), injected);
});

test('realScreenReaderStatus passes only when every configured assertion matches', () => {
  const passing = realScreenReaderStatus({
    ran: true,
    phrases: ['button, Clear search', 'button, Close dialog'],
    assertions: [
      { status: 'pass', type: 'contains', value: 'button' },
      { status: 'pass', type: 'orderedContains', value: 'Clear search' },
    ],
  });

  const failing = realScreenReaderStatus({
    ran: true,
    phrases: ['button, Clear search'],
    assertions: [
      { status: 'pass', type: 'contains', value: 'button' },
      { status: 'fail', type: 'orderedContains', value: 'Close dialog' },
    ],
  });

  assert.equal(passing, 'pass');
  assert.equal(failing, 'fail');
});
