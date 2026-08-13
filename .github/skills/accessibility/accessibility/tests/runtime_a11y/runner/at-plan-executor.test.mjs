// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  executeAtPlanCase,
  processAtPlanCase,
  runAtPlanCase,
} from '../../../scripts/runtime_a11y/runner/at-plan-executor.mjs';
import { classifyAtCaseResult } from '../../../scripts/runtime_a11y/runner/calibration-executor.mjs';
import { maximizeBrowserWindow, snapshotAccessibilityTree } from '../../../scripts/runtime_a11y/runner/_shared.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = resolve(__dirname, '../../../scripts/runtime_a11y/aria-at-catalog.json');

function createSyntheticDriver({ phrases = [], status = 'ready', throwOnStart = false } = {}) {
  let stopped = false;
  return {
    stopped: () => stopped,
    driver: {
      supported: true,
      status,
      driver: 'synthetic',
      synthetic: true,
      async start() {
        if (throwOnStart) {
          throw new Error('synthetic start failed');
        }
        return { driver: 'synthetic' };
      },
      async stop() {
        stopped = true;
      },
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return {
          phrases,
          assertions: [],
          synthetic: true,
          evidenceKind: 'synthetic',
        };
      },
    },
    get stoppedValue() {
      return stopped;
    },
  };
}

function createRealPageStub() {
  return {
    goto: async () => undefined,
    title: 'Example Page',
    url: 'http://127.0.0.1:3000/',
    locator: () => ({ focus: async () => undefined }),
    evaluate: async () => ({ url: 'http://127.0.0.1:3000/', title: 'Example Page', activeElement: 'body', bodyText: 'body' }),
    viewportSize: () => ({ width: 1280, height: 900 }),
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    bringToFront: async () => undefined,
    waitForSelector: async () => undefined,
    context: () => ({
      async newCDPSession() {
        return {
          async send() {
            return {};
          },
        };
      },
    }),
    accessibility: {
      snapshot: async () => ({ role: 'rootWebArea', name: 'Example page' }),
    },
  };
}

test('checkbox NVDA catalog variant exposes a Space sequence and reviewed assertions', async () => {
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const checkboxMapping = catalog.mappings.find((mapping) => mapping.pattern === 'checkbox');
  const checkboxVariant = checkboxMapping?.variants?.find((variant) => variant.at === 'nvda');

  assert.ok(checkboxMapping, 'checkbox mapping should exist');
  assert.ok(checkboxVariant, 'checkbox NVDA variant should exist');
  assert.equal(checkboxVariant.automationEligible, false);
  assert.deepEqual(checkboxVariant.commands, [{ kind: 'key', value: 'Space' }]);
  assert.deepEqual(checkboxVariant.assertions, [
    { type: 'contains', value: 'checkbox' },
    { type: 'contains', value: 'accept terms' },
    { type: 'matches', value: 'checked|not checked' },
  ]);
});

test('tabs NVDA catalog variant exposes distinct navigation and selection commands/assertions', async () => {
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const tabsMapping = catalog.mappings.find((mapping) => mapping.pattern === 'tabs');
  const tabsVariant = tabsMapping?.variants?.find((variant) => variant.at === 'nvda');

  assert.ok(tabsMapping, 'tabs mapping should exist');
  assert.ok(tabsVariant, 'tabs NVDA variant should exist');
  assert.equal(tabsVariant.automationEligible, false);
  assert.deepEqual(tabsVariant.commands, [
    { kind: 'key', value: 'ArrowRight' },
    { kind: 'key', value: 'ArrowLeft' },
    { kind: 'key', value: 'Home' },
    { kind: 'key', value: 'End' },
    { kind: 'key', value: 'Space' },
    { kind: 'key', value: 'Enter' },
  ]);
  assert.deepEqual(tabsVariant.assertions, [
    { type: 'contains', value: 'active tab' },
    { type: 'contains', value: 'selected' },
  ]);
});

test('executeAtPlanCase reports candidate results for tabs navigation and selection cases without mutating coverage or human-review state', async () => {
  const fixture = {
    navigationPhrases: ['active tab'],
    selectionPhrases: ['selected'],
  };

  const navigationCase = {
    caseId: 'tabs-navigation',
    variant: {
      id: 'nvda-tabs-manual-activation',
      at: 'nvda',
      platform: 'win32',
      automationEligible: false,
      automationExclusionReason: 'Synthetic tabs navigation evidence is non-eligible pending real host calibration.',
      commands: [
        { kind: 'key', value: 'ArrowRight' },
        { kind: 'key', value: 'ArrowLeft' },
        { kind: 'key', value: 'Home' },
        { kind: 'key', value: 'End' },
        { kind: 'key', value: 'Space' },
        { kind: 'key', value: 'Enter' },
      ],
      assertions: [{ type: 'contains', value: 'active tab' }],
    },
    coverage: { status: 'pending' },
    humanReview: { status: 'pending' },
  };

  const selectionCase = {
    caseId: 'tabs-selection',
    variant: {
      id: 'nvda-tabs-manual-activation',
      at: 'nvda',
      platform: 'win32',
      automationEligible: false,
      automationExclusionReason: 'Synthetic tabs selection evidence is non-eligible pending real host calibration.',
      commands: [
        { kind: 'key', value: 'ArrowRight' },
        { kind: 'key', value: 'ArrowLeft' },
        { kind: 'key', value: 'Home' },
        { kind: 'key', value: 'End' },
        { kind: 'key', value: 'Space' },
        { kind: 'key', value: 'Enter' },
      ],
      assertions: [{ type: 'contains', value: 'selected' }],
    },
    coverage: { status: 'pending' },
    humanReview: { status: 'pending' },
  };

  const navigationResult = await executeAtPlanCase({
    matrixCase: navigationCase,
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: fixture.navigationPhrases }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  const selectionResult = await executeAtPlanCase({
    matrixCase: selectionCase,
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: fixture.selectionPhrases }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  assert.equal(navigationResult.status, 'candidate');
  assert.equal(selectionResult.status, 'candidate');
  assert.deepEqual(navigationCase.coverage, { status: 'pending' });
  assert.deepEqual(navigationCase.humanReview, { status: 'pending' });
  assert.deepEqual(selectionCase.coverage, { status: 'pending' });
  assert.deepEqual(selectionCase.humanReview, { status: 'pending' });
  assert.equal(navigationResult.assertions[0].status, 'pass');
  assert.equal(selectionResult.assertions[0].status, 'pass');
});

test('executeAtPlanCase reports candidate results for checkbox parity cases without mutating coverage or human-review state', async () => {
  const matrixCase = {
    caseId: 'checkbox-parity',
    variant: {
      id: 'nvda-checkbox',
      at: 'nvda',
      platform: 'win32',
      automationEligible: false,
      automationExclusionReason: 'Synthetic checkbox candidate evidence is non-eligible pending real host calibration.',
      commands: [{ kind: 'key', value: 'Space' }],
      assertions: [
        { type: 'contains', value: 'checkbox' },
        { type: 'contains', value: 'accept terms' },
        { type: 'matches', value: 'checked|not checked' },
      ],
    },
    coverage: { status: 'pending' },
    humanReview: { status: 'pending' },
  };

  const firstResult = await executeAtPlanCase({
    matrixCase,
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: ['checkbox', 'accept terms', 'not checked'] }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  const secondResult = await executeAtPlanCase({
    matrixCase,
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: ['checkbox', 'accept terms', 'checked'] }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  assert.equal(firstResult.status, 'candidate');
  assert.equal(secondResult.status, 'candidate');
  assert.deepEqual(matrixCase.coverage, { status: 'pending' });
  assert.deepEqual(matrixCase.humanReview, { status: 'pending' });
  assert.equal(firstResult.assertions.every((assertion) => assertion.status === 'pass'), true);
  assert.equal(secondResult.assertions.every((assertion) => assertion.status === 'pass'), true);
});

test('executeAtPlanCase returns unsupported when the driver is not supported', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-unsupported',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({ supported: false, status: 'unsupported-driver', reason: 'disabled' }),
  });

  assert.equal(result.status, 'unsupported');
  assert.equal(result.capability.supported, false);
  assert.equal(result.evidence.synthetic, false);
});

test('processAtPlanCase resolves settle precedence and provenance for real runs', async () => {
  const observed = [];
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-settle-precedence',
      postCommandSettleMs: 25,
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: {
      baseUrl: 'http://127.0.0.1:3000',
      calibration: { defaults: { postCommandSettleMs: 1000 } },
      postCommandSettleMs: 2000,
    },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        observed.push(`command:${command.value}`);
      },
      async captureLog() {
        observed.push('captureLog');
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => {
      observed.push('binding');
      return {
        status: 'bound',
        expectedIdentity: { pageTitle: 'Example Page' },
        foregroundIdentity: { pageTitle: 'Example Page' },
        reason: 'ok',
      };
    },
  });

  assert.equal(result.status, 'pass');
  assert.deepEqual(observed, ['binding', 'command:next', 'binding', 'binding', 'captureLog']);
  assert.equal(result.evidence.provenance.postCommandSettleMsApplied, 25);
  assert.equal(result.evidence.provenance.settleSource, 'case');
  assert.equal(typeof result.evidence.provenance.captureTimestamp, 'string');
  assert.ok(result.evidence.provenance.captureTimestamp.length > 0);
});

test('processAtPlanCase falls back to the calibration default settle window', async () => {
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-settle-calibration-default',
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: {
      baseUrl: 'http://127.0.0.1:3000',
      calibration: { defaults: { postCommandSettleMs: 25 } },
      postCommandSettleMs: 2000,
    },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand() {},
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => ({
      status: 'bound',
      expectedIdentity: { pageTitle: 'Example Page' },
      foregroundIdentity: { pageTitle: 'Example Page' },
      reason: 'ok',
    }),
  });

  assert.equal(result.status, 'pass');
  assert.equal(result.evidence.provenance.postCommandSettleMsApplied, 25);
  assert.equal(result.evidence.provenance.settleSource, 'calibration-default');
});

test('processAtPlanCase waits for settle before capture and fails closed after settle if binding is lost', async () => {
  const observed = [];
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-settle-ordering',
      postCommandSettleMs: 25,
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        observed.push(`command:${command.value}`);
      },
      async captureLog() {
        observed.push('captureLog');
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => {
      observed.push('binding');
      const bindingCount = observed.filter((entry) => entry === 'binding').length;
      return {
        status: bindingCount >= 3 ? 'unbound' : 'bound',
        expectedIdentity: { pageTitle: 'Example Page' },
        foregroundIdentity: { pageTitle: 'Other Page' },
        reason: 'foreground-window-does-not-match-page-under-test',
      };
    },
  });

  assert.equal(result.status, 'error');
  assert.match(result.evidence.error, /Automation window lost focus/i);
  assert.deepEqual(observed, ['binding', 'command:next', 'binding', 'binding']);
  assert.equal(observed.includes('captureLog'), false);
});

test('processAtPlanCase uses clear-and-capture ordering and records capture-mode provenance', async () => {
  const observed = [];
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-capture-mode-ordering',
      captureMode: 'clear-and-capture',
      postCommandSettleMs: 25,
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        observed.push(`command:${command.value}`);
      },
      async clearLog() {
        observed.push('clearLog');
      },
      async captureLog() {
        observed.push('captureLog');
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => {
      observed.push('binding');
      return {
        status: 'bound',
        expectedIdentity: { pageTitle: 'Example Page' },
        foregroundIdentity: { pageTitle: 'Example Page' },
        reason: 'ok',
      };
    },
  });

  assert.equal(result.status, 'pass');
  assert.deepEqual(observed, ['clearLog', 'binding', 'command:next', 'binding', 'clearLog', 'binding', 'captureLog']);
  assert.equal(result.evidence.provenance.captureModeApplied, 'clear-and-capture');
  assert.equal(result.evidence.provenance.captureModeSource, 'case');
  assert.equal(result.evidence.provenance.speechLogClearedBeforeSettle, true);
});

test('processAtPlanCase falls back to single capture mode and skips clearing the log for invalid or synthetic values', async () => {
  const invalidValueObserved = [];
  const invalidValueResult = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-capture-mode-fallback',
      captureMode: 'invalid-mode',
      postCommandSettleMs: 25,
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: {
      baseUrl: 'http://127.0.0.1:3000',
      calibration: { defaults: { captureMode: 'also-invalid' } },
      captureMode: 'still-invalid',
    },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand() {},
      async clearLog() {
        invalidValueObserved.push('clearLog');
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => ({
      status: 'bound',
      expectedIdentity: { pageTitle: 'Example Page' },
      foregroundIdentity: { pageTitle: 'Example Page' },
      reason: 'ok',
    }),
  });

  assert.equal(invalidValueResult.status, 'pass');
  assert.equal(invalidValueResult.evidence.provenance.captureModeApplied, 'single');
  assert.equal(invalidValueResult.evidence.provenance.captureModeSource, 'default');
  assert.equal(invalidValueResult.evidence.provenance.speechLogClearedBeforeSettle, false);
  assert.deepEqual(invalidValueObserved, ['clearLog']);

  const syntheticObserved = [];
  const syntheticResult = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-capture-mode-synthetic',
      captureMode: 'clear-and-capture',
      postCommandSettleMs: 25,
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand() {},
      async clearLog() {
        syntheticObserved.push('clearLog');
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => ({
      status: 'bound',
      expectedIdentity: { pageTitle: 'Example Page' },
      foregroundIdentity: { pageTitle: 'Example Page' },
      reason: 'ok',
    }),
  });

  assert.equal(syntheticResult.status, 'candidate');
  assert.equal(syntheticResult.evidence.provenance.captureModeApplied, 'clear-and-capture');
  assert.equal(syntheticResult.evidence.provenance.captureModeSource, 'case');
  assert.equal(syntheticResult.evidence.provenance.speechLogClearedBeforeSettle, false);
  assert.deepEqual(syntheticObserved, ['clearLog']);
});

test('processAtPlanCase uses zero settle for synthetic runs and skips binding checks', async () => {
  const observed = [];
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-settle-synthetic',
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        observed.push(`command:${command.value}`);
      },
      async captureLog() {
        observed.push('captureLog');
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
    page: createRealPageStub(),
    ensureWindowBinding: async () => {
      observed.push('binding');
      return {
        status: 'bound',
        expectedIdentity: { pageTitle: 'Example Page' },
        foregroundIdentity: { pageTitle: 'Example Page' },
        reason: 'ok',
      };
    },
  });

  assert.equal(result.status, 'candidate');
  assert.deepEqual(observed, ['command:next', 'captureLog']);
  assert.equal(result.evidence.provenance.postCommandSettleMsApplied, 0);
  assert.equal(result.evidence.provenance.settleSource, 'synthetic');
});

test('processAtPlanCase executes waitFor commands before continuing the command sequence', async () => {
  const observed = [];
  const fakePage = {
    goto: async () => undefined,
    waitForSelector: async (selector, options = {}) => {
      observed.push({ type: 'waitFor', selector, options });
    },
    locator: () => ({ focus: async () => undefined }),
    evaluate: async () => ({ url: 'http://127.0.0.1:3000/' }),
    viewportSize: () => ({ width: 1280, height: 900 }),
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-wait-for',
      commands: [
        { kind: 'waitFor', value: '[role="listbox"]', durationMs: 750 },
        { kind: 'key', value: 'ArrowDown' },
      ],
      assertions: [{ id: 'speech', type: 'contains', value: 'result' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        observed.push({ type: 'command', kind: command.kind, value: command.value });
      },
      async captureLog() {
        return { phrases: ['result'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
    page: fakePage,
    browser: null,
    context: null,
  });

  assert.equal(result.status, 'candidate');
  assert.equal(observed[0].type, 'waitFor');
  assert.equal(observed[1].type, 'command');
  assert.equal(observed[1].value, 'ArrowDown');
});

test('classifyAtCaseResult preserves closed-browser errors as infrastructure failures', () => {
  const result = {
    status: 'error',
    evidence: {
      error: 'Target page, context or browser has been closed',
      rawPhrases: [],
      normalizedPhrases: [],
      browserState: null,
      accessibilityTree: null,
    },
    capability: { supported: true, synthetic: false, at: 'nvda' },
    artifactHashes: {},
  };

  assert.equal(classifyAtCaseResult(result), 'infrastructureFailure');
});

test('processAtPlanCase fails closed as infrastructure when window binding cannot be established', async () => {
  const fakePage = {
    goto: async () => undefined,
    title: async () => 'Example Page',
    url: async () => 'http://127.0.0.1:3000/',
    locator: () => ({ focus: async () => undefined }),
    evaluate: async () => ({ url: 'http://127.0.0.1:3000/' }),
    viewportSize: () => ({ width: 1280, height: 900 }),
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'binding-failure',
      commands: [{ kind: 'command', value: 'next' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand() {},
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: false, evidenceKind: 'real' };
      },
    }),
    page: fakePage,
    ensureWindowBinding: async () => ({
      status: 'unbound',
      expectedIdentity: { windowId: 42, pageTitle: 'Example Page' },
      foregroundIdentity: { windowTitle: 'Unrelated Window' },
      reason: 'foreground-window-does-not-match-page-under-test',
    }),
  });

  assert.equal(result.status, 'error');
  assert.match(result.evidence.error, /Automation window is not focused/i);
  assert.equal(classifyAtCaseResult(result), 'infrastructureFailure');
});

test('classifyAtCaseResult preserves explicit product-failure classifications', () => {
  const result = {
    status: 'error',
    evidence: {
      error: 'Automation window is not focused',
      rawPhrases: [],
      normalizedPhrases: [],
      browserState: null,
      accessibilityTree: null,
    },
    classification: 'product-failure',
    capability: { supported: true, synthetic: false, at: 'nvda' },
    artifactHashes: {},
  };

  assert.equal(classifyAtCaseResult(result), 'productFailure');
});

test('executeAtPlanCase reports candidate for synthetic evidence and variant metadata', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-pass',
      variant: {
        id: 'variant-1',
        at: 'nvda',
        platform: 'win32',
        commands: [{ kind: 'command', value: 'perform' }],
        assertions: [{ id: 'assert-1', type: 'contains', value: 'dialog' }],
      },
      sourceMatrixRef: '/tmp/matrix.json',
      sourceMatrixMetadata: { path: '/tmp/matrix.json', digest: 'abc123' },
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: ['dialog'] }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  assert.equal(result.status, 'candidate');
  assert.equal(result.variantId, 'variant-1');
  assert.equal(result.capability.synthetic, true);
  assert.equal(result.evidence.synthetic, true);
  assert.equal(result.sourceMatrixRef, '/tmp/matrix.json');
  assert.equal(result.assertions[0].status, 'pass');
});

test('executeAtPlanCase surfaces adapter failures as real errors with the original reason', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'adapter-error',
      commands: [{ kind: 'perform', value: 'toggleBetweenBrowseAndFocusMode' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: false,
      status: 'adapter-error',
      reason: 'Guidepup failed to start NVDA',
      driver: 'guidepup',
    }),
  });

  assert.equal(result.status, 'error');
  assert.equal(result.evidence.reason, 'Guidepup failed to start NVDA');
  assert.equal(result.evidence.error, 'Guidepup failed to start NVDA');
});

test('executeAtPlanCase records provenance warnings when captured speech includes connection chatter', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'connection-chatter',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: {
      baseUrl: 'http://127.0.0.1:3000',
      approvedProfile: { addOnPosture: 'isolated' },
    },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['Connected as controlled computer'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'fail');
  assert.equal(result.evidence.provenanceWarnings.length, 1);
  assert.match(result.evidence.provenanceWarnings[0], /connection chatter/i);
  assert.ok(result.evidence.provenance?.warnings?.includes(result.evidence.provenanceWarnings[0]));
});

test('maximizeBrowserWindow uses a target-bound CDP session and brings the page to front', async () => {
  const events = [];
  const browser = {
    newBrowserCDPSession: async () => {
      events.push('browser-cdp');
      throw new Error('should not use browser-level cdp');
    },
  };
  const page = {
    async bringToFront() {
      events.push('bring-to-front');
    },
  };
  const context = {
    async newCDPSession(targetPage) {
      events.push(`context-cdp:${targetPage === page}`);
      return {
        async send(method, params) {
          events.push(`${method}:${JSON.stringify(params || {})}`);
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 17 };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };

  const result = await maximizeBrowserWindow({ browser, context, page });

  assert.equal(result.status, 'maximized');
  assert.equal(result.windowId, 17);
  assert.deepEqual(events, ['context-cdp:true', 'Browser.getWindowForTarget:{}', 'Browser.setWindowBounds:{"windowId":17,"bounds":{"windowState":"maximized"}}', 'bring-to-front']);
});

test('processAtPlanCase navigates before maximizing the window', async () => {
  const events = [];
  const page = {
    goto: async (url) => {
      events.push(`goto:${url}`);
    },
    bringToFront: async () => {
      events.push('bring-to-front');
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  const context = {
    async newCDPSession() {
      events.push('cdp-session');
      return {
        async send(method) {
          events.push(`cdp:${method}`);
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 17 };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-navigation-order',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    context,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  const gotoIndex = events.indexOf('goto:http://127.0.0.1:3000');
  const maximizeIndex = events.indexOf('cdp:Browser.getWindowForTarget');
  assert.ok(gotoIndex >= 0);
  assert.ok(maximizeIndex >= 0);
  assert.ok(gotoIndex < maximizeIndex);
});

test('processAtPlanCase retries once for transient navigation failures and preserves evidence', async () => {
  const events = [];
  let attempt = 0;
  const firstPage = {
    goto: async () => {
      attempt += 1;
      events.push('goto:first');
      throw new Error('net::ERR_CONNECTION_RESET');
    },
    close: async () => {
      events.push('close:first');
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  const secondPage = {
    goto: async (url) => {
      events.push(`goto:${url}`);
    },
    bringToFront: async () => {
      events.push('bring-to-front');
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  const context = {
    async newPage() {
      events.push('new-page');
      return secondPage;
    },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-navigation-retry',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page: firstPage,
    context,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  assert.equal(attempt, 1);
  assert.equal(events.includes('new-page'), true);
  assert.equal(events.includes('close:first'), true);
  assert.equal(result.evidence.navigation.attempts.length, 2);
  assert.equal(result.evidence.navigation.retried, true);
});

test('snapshotAccessibilityTree uses the CDP accessibility tree when available', async () => {
  const page = {
    context() {
      return {
        async newCDPSession() {
          return {
            async send(method) {
              if (method === 'Accessibility.enable') {
                return {};
              }
              if (method === 'Accessibility.getFullAXTree') {
                return {
                  nodes: [
                    {
                      nodeId: '1',
                      role: { type: 'internalRole', value: 'RootWebArea' },
                      name: { type: 'computedString', value: 'Example page' },
                      ignored: false,
                      childIds: ['2'],
                    },
                    {
                      nodeId: '2',
                      role: { type: 'role', value: 'button' },
                      name: { type: 'computedString', value: 'Continue' },
                      ignored: false,
                      childIds: [],
                    },
                  ],
                };
              }
              throw new Error(`unexpected method: ${method}`);
            },
          };
        },
      };
    },
    accessibility: {
      snapshot: async () => {
        throw new Error('legacy snapshot should not be used');
      },
    },
  };

  const result = await snapshotAccessibilityTree(page);

  assert.equal(result.source, 'cdp');
  assert.equal(result.nodes[0].role.value, 'RootWebArea');
  assert.equal(result.nodes[1].name.value, 'Continue');
  assert.deepEqual(result.nodes[0].childIds, ['2']);
});

test('executeAtPlanCase reports invalid-config as a non-pass candidate', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-invalid',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'matches', value: '[' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => {
      const driver = createSyntheticDriver({ phrases: ['dialog'] }).driver;
      return { ...driver, supported: true, status: 'ready', driver: 'synthetic', synthetic: true };
    },
  });

  assert.equal(result.status, 'candidate');
  assert.equal(result.assertions[0].status, 'invalid-config');
  assert.equal(result.evidence.synthetic, true);
});

test('executeAtPlanCase surfaces invalid-config errors in the evidence reason', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-invalid-config-reason',
      commands: [{ kind: 'key', value: 'Control+A' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: false,
      status: 'invalid-config',
      driver: 'guidepup',
      errors: ['Unsupported key value: Control+A'],
    }),
  });

  assert.equal(result.status, 'error');
  assert.equal(result.evidence.reason, 'Unsupported key value: Control+A');
  assert.equal(result.evidence.error, 'Unsupported key value: Control+A');
});

test('executeAtPlanCase dispatches perform commands through the driver and surfaces handler errors', async () => {
  const dispatched = [];
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-perform',
      commands: [{ kind: 'perform', value: 'toggleBetweenBrowseAndFocusMode' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        dispatched.push(command);
        if (command?.kind === 'perform') {
          return { kind: 'perform', value: command.value };
        }
        throw new Error('unexpected command kind');
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  assert.deepEqual(dispatched, [{ kind: 'perform', value: 'toggleBetweenBrowseAndFocusMode' }]);
});

test('executeAtPlanCase reports driver errors for rejected perform commands', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-perform-error',
      commands: [{ kind: 'perform', value: 'unknownPerform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        throw new Error(`Unsupported perform value: ${command.value}`);
      },
      async captureLog() {
        return { phrases: [], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'error');
  assert.match(result.evidence.error, /Unsupported perform value/);
});

test('executeAtPlanCase dispatches type commands through the driver', async () => {
  const dispatched = [];
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-type',
      commands: [{ kind: 'type', value: 'agent' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        dispatched.push(command);
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  assert.deepEqual(dispatched, [{ kind: 'type', value: 'agent' }]);
});

test('executeAtPlanCase reports unsupported for incompatible real platforms', async () => {
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-platform',
      variant: { id: 'variant-1', at: 'nvda', platform: 'win32', commands: [{ kind: 'command', value: 'perform' }], assertions: [{ id: 'a', type: 'contains', value: 'dialog' }] },
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    platform: 'linux',
    driverFactory: async () => ({ supported: true, status: 'ready', driver: 'guidepup', synthetic: false }),
  });

  assert.equal(result.status, 'unsupported');
  assert.equal(result.evidence.synthetic, false);
});

test('executeAtPlanCase reports error and does not stop a driver that never started', async () => {
  let started = 0;
  let stopped = 0;
  const result = await executeAtPlanCase({
    matrixCase: {
      caseId: 'case-error',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {
        started += 1;
        throw new Error('boom');
      },
      async stop() {
        stopped += 1;
      },
    }),
  });

  assert.equal(result.status, 'error');
  assert.equal(started, 1);
  assert.equal(stopped, 0);
  assert.equal(result.evidence.error.includes('boom'), true);
  assert.equal(result.evidence.cleanup.driverStarted, false);
  assert.equal(result.evidence.cleanup.driverStopped, false);
});

test('runAtPlanCase uses pageFactory navigation and stops the driver on cleanup', async () => {
  const navigation = [];
  const page = {
    goto: async (url) => {
      navigation.push(url);
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  let stopped = false;

  const result = await runAtPlanCase({
    pageFactory: async () => page,
    matrixCase: {
      caseId: 'case-lifecycle',
      state: 'default',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {
        stopped = true;
      },
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  assert.equal(navigation[0], 'http://127.0.0.1:3000');
  assert.equal(stopped, true);
});

test('processAtPlanCase runs post-start triggers after driver startup when configured', async () => {
  const events = [];
  const page = {
    goto: async (url) => {
      events.push(`goto:${url}`);
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: (selector) => ({
      click: async () => {
        events.push(`click:${selector}`);
      },
      focus: async () => {
        events.push(`focus:${selector}`);
      },
      hover: async () => {
        events.push(`hover:${selector}`);
      },
      fill: async (value) => {
        events.push(`fill:${selector}:${value}`);
      },
      waitFor: async () => {
        events.push(`wait:${selector}`);
      },
    }),
    keyboard: { press: async () => undefined },
  };

  await processAtPlanCase({
    matrixCase: {
      caseId: 'case-trigger-lifecycle',
      triggerAfterDriverStart: true,
      trigger: { action: 'type', target: 'input.search', value: 'agent', waitFor: '[role="listbox"]' },
      commands: [{ kind: 'keyboard', value: 'ArrowDown' }],
      assertions: [{ id: 'a', type: 'contains', value: 'results' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() { events.push('driver:start'); },
      async stop() { events.push('driver:stop'); },
      async reset() { events.push('driver:reset'); },
      async clearLog() { events.push('driver:clear-log'); },
      async executeCommand(command) {
        events.push(`command:${command.kind}:${command.value}`);
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['results'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  const driverStartIndex = events.indexOf('driver:start');
  const fillIndex = events.indexOf('fill:input.search:agent');
  assert.ok(driverStartIndex >= 0);
  assert.ok(fillIndex >= 0);
  assert.ok(fillIndex > driverStartIndex);
});

test('processAtPlanCase preserves the focus-traversal typing sequence for calibration journeys', async () => {
  const events = [];
  const page = {
    goto: async () => undefined,
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: (selector) => ({
      click: async () => {
        events.push(`click:${selector}`);
      },
      focus: async () => {
        events.push(`focus:${selector}`);
      },
      hover: async () => {
        events.push(`hover:${selector}`);
      },
      fill: async (value) => {
        events.push(`fill:${selector}:${value}`);
      },
      waitFor: async () => {
        events.push(`wait:${selector}`);
      },
    }),
    keyboard: { press: async () => undefined },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-focus-traversal',
      target: 'input.search',
      triggerAfterDriverStart: true,
      commands: [
        { kind: 'key', value: 'Shift+Tab' },
        { kind: 'pause', durationMs: 50 },
        { kind: 'key', value: 'Tab' },
        { kind: 'pause', durationMs: 50 },
        { kind: 'type', value: 'agent' },
        { kind: 'pause', durationMs: 1000 },
        { kind: 'key', value: 'ArrowDown' },
      ],
      assertions: [{ id: 'a', type: 'contains', value: 'results' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() { events.push('driver:start'); },
      async stop() { events.push('driver:stop'); },
      async reset() { events.push('driver:reset'); },
      async clearLog() { events.push('driver:clear-log'); },
      async executeCommand(command) {
        events.push(`command:${command.kind}:${command.value}`);
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        events.push('capture');
        return { phrases: ['results'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  assert.deepEqual(events.filter((entry) => entry.startsWith('command:')), [
    'command:key:Shift+Tab',
    'command:pause:undefined',
    'command:key:Tab',
    'command:pause:undefined',
    'command:type:agent',
    'command:pause:undefined',
    'command:key:ArrowDown',
  ]);
});

test('processAtPlanCase runs ordered post-start trigger sequences before commands and capture', async () => {
  const events = [];
  const page = {
    goto: async (url) => {
      events.push(`goto:${url}`);
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: (selector) => ({
      click: async () => {
        events.push(`click:${selector}`);
      },
      focus: async () => {
        events.push(`focus:${selector}`);
      },
      hover: async () => {
        events.push(`hover:${selector}`);
      },
      fill: async (value) => {
        events.push(`fill:${selector}:${value}`);
      },
      waitFor: async () => {
        events.push(`wait:${selector}`);
      },
    }),
    keyboard: { press: async () => undefined },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-trigger-sequence',
      target: 'input.search',
      triggerAfterDriverStart: true,
      triggerSequence: [
        { action: 'focus', target: 'input.search' },
        { action: 'type', target: 'input.search', value: 'agent', waitFor: '[role="listbox"]' },
      ],
      commands: [{ kind: 'keyboard', value: 'ArrowDown' }],
      assertions: [{ id: 'a', type: 'contains', value: 'results' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() { events.push('driver:start'); },
      async stop() { events.push('driver:stop'); },
      async reset() { events.push('driver:reset'); },
      async clearLog() { events.push('driver:clear-log'); },
      async executeCommand(command) {
        events.push(`command:${command.kind}:${command.value}`);
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        events.push('capture');
        return { phrases: ['results'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  const driverStartIndex = events.indexOf('driver:start');
  const driverResetIndex = events.indexOf('driver:reset');
  const focusIndex = events.indexOf('focus:input.search');
  const fillIndex = events.indexOf('fill:input.search:agent');
  const waitIndex = events.indexOf('wait:[role="listbox"]');
  const commandIndex = events.indexOf('command:keyboard:ArrowDown');
  const captureIndex = events.indexOf('capture');
  assert.ok(driverStartIndex >= 0);
  assert.ok(driverResetIndex >= 0);
  assert.ok(focusIndex >= 0);
  assert.ok(fillIndex >= 0);
  assert.ok(waitIndex >= 0);
  assert.ok(commandIndex >= 0);
  assert.ok(captureIndex >= 0);
  assert.ok(driverStartIndex < driverResetIndex);
  assert.ok(driverResetIndex < focusIndex);
  assert.ok(focusIndex < fillIndex);
  assert.ok(fillIndex < waitIndex);
  assert.ok(waitIndex < commandIndex);
  assert.ok(commandIndex < captureIndex);
});

test('processAtPlanCase preserves click triggers and pause commands for calibration focus sequences', async () => {
  const events = [];
  const page = {
    goto: async () => undefined,
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: (selector) => ({
      click: async () => {
        events.push(`click:${selector}`);
      },
      focus: async () => {
        events.push(`focus:${selector}`);
      },
      hover: async () => {
        events.push(`hover:${selector}`);
      },
      fill: async (value) => {
        events.push(`fill:${selector}:${value}`);
      },
      waitFor: async () => {
        events.push(`wait:${selector}`);
      },
    }),
    keyboard: { press: async () => undefined },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-click-trigger-sequence',
      target: 'input.search',
      triggerAfterDriverStart: true,
      triggerSequence: [
        { action: 'click', target: 'input.search', waitFor: 'input.search' },
      ],
      commands: [
        { kind: 'pause', durationMs: 20 },
        { kind: 'type', value: 'agent' },
      ],
      assertions: [{ id: 'a', type: 'contains', value: 'results' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() { events.push('driver:start'); },
      async stop() { events.push('driver:stop'); },
      async reset() { events.push('driver:reset'); },
      async clearLog() { events.push('driver:clear-log'); },
      async executeCommand(command) {
        events.push(`command:${command.kind}:${command.value ?? command.durationMs ?? ''}`);
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        events.push('capture');
        return { phrases: ['results'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
  });

  assert.equal(result.status, 'candidate');
  const clickIndex = events.indexOf('click:input.search');
  const commandPauseIndex = events.indexOf('command:pause:20');
  const commandTypeIndex = events.indexOf('command:type:agent');
  assert.ok(clickIndex >= 0);
  assert.ok(commandPauseIndex >= 0);
  assert.ok(commandTypeIndex >= 0);
  assert.ok(clickIndex < commandPauseIndex);
  assert.ok(commandPauseIndex < commandTypeIndex);
});

test('processAtPlanCase stops the triggerSequence on the first failing entry', async () => {
  const events = [];
  const page = {
    goto: async () => undefined,
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: (selector) => ({
      focus: async () => {
        events.push(`focus:${selector}`);
      },
      fill: async () => {
        events.push(`fill:${selector}`);
        throw new Error('type failed');
      },
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-trigger-sequence-failure',
      triggerAfterDriverStart: true,
      triggerSequence: [
        { action: 'focus', target: 'input.search' },
        { action: 'type', target: 'input.search', value: 'agent' },
      ],
      commands: [{ kind: 'keyboard', value: 'ArrowDown' }],
      assertions: [{ id: 'a', type: 'contains', value: 'results' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    page,
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() { events.push('driver:start'); },
      async stop() { events.push('driver:stop'); },
      async reset() { events.push('driver:reset'); },
      async clearLog() { events.push('driver:clear-log'); },
      async executeCommand() { events.push('command'); return { kind: 'keyboard', value: 'ArrowDown' }; },
      async captureLog() { events.push('capture'); return { phrases: ['results'], assertions: [], synthetic: true, evidenceKind: 'synthetic' }; },
    }),
  });

  assert.equal(result.status, 'error');
  assert.match(result.evidence.error, /type failed/);
  assert.ok(events.includes('focus:input.search'));
  assert.ok(!events.includes('command'));
});

test('processAtPlanCase launches browser, resolves navigation, and cleans up', async () => {
  const events = [];
  const navigations = [];
  const page = {
    goto: async (url) => {
      navigations.push(url);
      events.push(`goto:${url}`);
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  const browser = {
    newContext: async () => {
      events.push('context');
      return {
        newPage: async () => {
          events.push('page');
          return page;
        },
        close: async () => {
          events.push('context-close');
        },
      };
    },
    close: async () => {
      events.push('browser-close');
    },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-browser',
      state: 'default',
      surface: { id: 'dialog', route: '/dialog' },
      trigger: { action: 'navigate', value: 'http://127.0.0.1:3000/triggered' },
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {
        events.push('driver-stop');
      },
      async executeCommand(command) {
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: false };
      },
    }),
    browserFactory: async () => {
      events.push('browser-launch');
      return browser;
    },
    // A real-driver run only proceeds once the window under test owns focus.
    ensureWindowBinding: async () => ({ status: 'bound', expectedTitle: 'dialog', foregroundTitle: 'dialog - Google Chrome', attempts: 1 }),
  });

  assert.equal(result.status, 'pass');
  assert.equal(navigations[0], 'http://127.0.0.1:3000/dialog');
  assert.equal(navigations[1], 'http://127.0.0.1:3000/triggered');
  assert.equal(events.includes('browser-launch'), true);
  assert.equal(events.includes('browser-close'), true);
  assert.equal(events.includes('context-close'), true);
  assert.equal(events.includes('driver-stop'), true);
});

test('processAtPlanCase reports navigation errors and cleans up the browser', async () => {
  const events = [];
  let navigationCount = 0;
  const page = {
    goto: async () => {
      navigationCount += 1;
      if (navigationCount === 2) {
        throw new Error('trigger navigation failed');
      }
    },
    setViewportSize: async () => undefined,
    emulateMedia: async () => undefined,
    evaluate: async () => undefined,
    locator: () => ({
      click: async () => undefined,
      focus: async () => undefined,
      hover: async () => undefined,
      fill: async () => undefined,
      waitFor: async () => undefined,
    }),
    keyboard: { press: async () => undefined },
  };
  const browser = {
    newContext: async () => {
      events.push('context');
      return {
        newPage: async () => {
          events.push('page');
          return page;
        },
        close: async () => {
          events.push('context-close');
        },
      };
    },
    close: async () => {
      events.push('browser-close');
    },
  };

  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-nav-error',
      state: 'default',
      trigger: { action: 'navigate', value: 'http://127.0.0.1:3000/fail' },
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    surface: { id: 'dialog', route: '/dialog' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {
        events.push('driver-stop');
      },
    }),
    browserFactory: async () => {
      events.push('browser-launch');
      return browser;
    },
  });

  assert.equal(result.status, 'error');
  assert.equal(events.includes('browser-close'), true);
  assert.equal(events.includes('context-close'), true);
  assert.equal(result.evidence.error.includes('trigger navigation failed'), true);
});

test('processAtPlanCase does not launch a browser for synthetic execution', async () => {
  let browserLaunches = 0;
  let commandExecutions = 0;
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-synthetic-browserless',
      commands: [{ kind: 'command', value: 'perform' }],
      assertions: [{ id: 'a', type: 'contains', value: 'dialog' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'synthetic',
      synthetic: true,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        commandExecutions += 1;
        return { kind: command?.kind || 'command', value: command?.value || '' };
      },
      async captureLog() {
        return { phrases: ['dialog'], assertions: [], synthetic: true, evidenceKind: 'synthetic' };
      },
    }),
    browserFactory: async () => {
      browserLaunches += 1;
      throw new Error('browser should not be created');
    },
  });

  assert.equal(result.status, 'candidate');
  assert.equal(result.evidence.synthetic, true);
  assert.equal(browserLaunches, 0);
  assert.equal(commandExecutions, 1);
});


test('processAtPlanCase fails closed when the automation window is not focused', async () => {
  const dispatched = [];
  const result = await processAtPlanCase({
    matrixCase: {
      caseId: 'case-window-binding',
      commands: [{ kind: 'key', value: 'ArrowDown' }],
      assertions: [{ id: 'speech', type: 'contains', value: 'result' }],
    },
    runtimeConfig: { baseUrl: 'http://127.0.0.1:3000' },
    driverFactory: async () => ({
      supported: true,
      status: 'ready',
      driver: 'guidepup',
      synthetic: false,
      async start() {},
      async stop() {},
      async executeCommand(command) {
        dispatched.push(command.value);
      },
      async captureLog() {
        return { phrases: ['unrelated window speech'], assertions: [] };
      },
    }),
    page: {
      goto: async () => undefined,
      title: async () => 'Surface Under Test',
      locator: () => ({ focus: async () => undefined }),
      evaluate: async () => ({ url: 'http://127.0.0.1:3000/' }),
      viewportSize: () => ({ width: 1280, height: 900 }),
      setViewportSize: async () => undefined,
      emulateMedia: async () => undefined,
      bringToFront: async () => undefined,
    },
    browser: null,
    context: null,
    ensureWindowBinding: async () => ({
      status: 'unbound',
      expectedTitle: 'Surface Under Test',
      foregroundTitle: 'New Tab - Google Chrome',
      expectedIdentity: { pageTitle: 'Surface Under Test' },
      foregroundIdentity: { windowTitle: 'New Tab - Google Chrome' },
      attempts: 3,
      reason: 'foreground-window-does-not-match-page-under-test',
    }),
  });

  assert.equal(result.status, 'error');
  assert.match(result.evidence.error, /not focused/);
  assert.match(result.evidence.error, /New Tab - Google Chrome/);
  assert.equal(result.evidence.windowBinding.status, 'unbound');
  // No keystroke may be synthesized once the window under test lost focus.
  assert.deepEqual(dispatched, []);
  // An unowned window is an environment problem, not a product defect.
  assert.equal(classifyAtCaseResult(result), 'infrastructureFailure');
});
