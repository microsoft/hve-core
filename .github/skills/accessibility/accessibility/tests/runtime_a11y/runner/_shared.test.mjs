// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { applyTrigger, buildChromeLaunchOptions, ensureAutomationWindowFocused, ensureScreenReaderStopped } from '../../../scripts/runtime_a11y/runner/_shared.mjs';
import { assertArtifactId, assertHttpUrl } from '../../../scripts/runtime_a11y/runner/validation.mjs';

test('assertHttpUrl accepts absolute HTTP targets and rejects browser sink bypasses', () => {
  assert.equal(assertHttpUrl('https://example.com/path', 'Runtime base URL'), 'https://example.com/path');
  for (const value of [
    'file:///tmp/page.html',
    '//example.com/path',
    'http:example.com/path',
    'http:\\example.com\\path',
    'https://user:password@example.com',
    'https://example.com/a b',
  ]) {
    assert.throws(() => assertHttpUrl(value, 'Runtime base URL'), undefined, value);
  }
});

test('assertArtifactId rejects path separators, collisions, unicode, and invalid lengths', () => {
  assert.equal(assertArtifactId('search-results_2.0'), 'search-results_2.0');
  assert.equal(assertArtifactId(`a${'b'.repeat(127)}`).length, 128);
  for (const value of [
    '',
    '-leading',
    '../escape',
    'bad/name',
    'bad name',
    'résumé',
    `a${'b'.repeat(128)}`,
  ]) {
    assert.throws(() => assertArtifactId(value), undefined, value);
  }
});

test('assertArtifactId rejects Windows device names and trailing dots', () => {
  // Win32 resolves these in any directory and strips trailing dots, so both
  // forms would break or silently collide as evidence path segments.
  for (const value of [
    'CON',
    'con',
    'NUL',
    'PRN',
    'AUX',
    'COM1',
    'LPT9',
    'CON.txt',
    'nul.json',
    'trailing.',
  ]) {
    assert.throws(() => assertArtifactId(value), undefined, value);
  }
  assert.equal(assertArtifactId('console'), 'console');
  assert.equal(assertArtifactId('com10'), 'com10');
  assert.equal(assertArtifactId('contrast'), 'contrast');
});

test('applyTrigger rejects invalid navigation before permissive action handling', async () => {
  const navigations = [];
  const page = {
    url: () => 'http://127.0.0.1:3000/current',
    goto: async (url) => navigations.push(url),
    locator: () => ({}),
  };

  await assert.rejects(
    applyTrigger(page, { action: 'navigate', value: 'https://attacker.example/path' }),
    /configured origin/,
  );
  assert.deepEqual(navigations, []);
});

test('applyTrigger navigates relative and absolute same-origin destinations', async () => {
  const navigations = [];
  const page = {
    url: () => 'http://127.0.0.1:3000/current',
    goto: async (url) => navigations.push(url),
    locator: () => ({}),
  };

  await applyTrigger(page, { action: 'navigate', value: '/next' });
  await applyTrigger(page, {
    action: 'visit',
    target: { value: 'http://127.0.0.1:3000/visited' },
  });
  assert.deepEqual(navigations, [
    'http://127.0.0.1:3000/next',
    'http://127.0.0.1:3000/visited',
  ]);
});

test('buildChromeLaunchOptions ignores generic caller arguments', () => {
  const options = buildChromeLaunchOptions({ headless: false, args: ['--window-size=1440,900'] });

  assert.equal(options.channel, 'chrome');
  assert.equal(options.headless, false);
  assert.deepEqual(options.args, [
    '--disable-session-crashed-bubble',
    '--hide-crash-restore-bubble',
    '--no-default-browser-check',
    '--no-first-run',
    '--force-renderer-accessibility',
  ]);
});

test('ensureAutomationWindowFocused binds when the foreground window belongs to the browser process', async () => {
  const events = [];
  const page = {
    async title() {
      return 'Docs';
    },
    async evaluate(callback, value) {
      if (typeof callback === 'function') {
        if (value === undefined) {
          return 'Docs';
        }
        return value;
      }
      return value;
    },
    async bringToFront() {
      events.push('bring-to-front');
    },
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          events.push(method);
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 3 };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };

  const result = await ensureAutomationWindowFocused({
    page,
    browser: { process: () => ({ pid: 4100 }) },
    context,
    platform: 'win32',
    timeoutMs: 20,
    pollIntervalMs: 5,
    readForegroundIdentity: async () => ({ title: 'Docs - Google Chrome', processId: 4200 }),
    readProcesses: async () => new Map([[4200, 4100], [4100, 900]]),
    activateWindow: async () => false,
    activateTarget: async () => false,
  });

  assert.equal(result.status, 'bound');
  assert.equal(result.foregroundIdentity.processId, 4200);
  assert.equal(result.expectedIdentity.browserProcessId, 4100);
  assert.equal(events.includes('bring-to-front'), true);
});

test('ensureAutomationWindowFocused refuses a foreign window that mimics the page title', async () => {
  // The decisive case for the binding authority: the foreground window title
  // contains the page's own title, which the old substring comparison accepted,
  // but the window belongs to an unrelated process.
  const page = {
    async title() {
      return 'Docs';
    },
    async evaluate(callback, value) {
      if (typeof callback === 'function') {
        return 'Docs';
      }
      return value;
    },
    async bringToFront() {},
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 4 };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };

  const result = await ensureAutomationWindowFocused({
    page,
    browser: { process: () => ({ pid: 4100 }) },
    context,
    platform: 'win32',
    timeoutMs: 20,
    pollIntervalMs: 5,
    readForegroundIdentity: async () => ({ title: 'Docs - Notepad', processId: 7777 }),
    readProcesses: async () => new Map([[7777, 900], [4100, 900]]),
    activateWindow: async () => false,
    activateTarget: async () => false,
  });

  assert.equal(result.status, 'unbound');
  assert.equal(
    result.reason.includes('foreground-window-does-not-belong-to-the-browser-under-test'),
    true,
  );
});

test('ensureAutomationWindowFocused fails closed when the browser process identity is unavailable', async () => {
  const page = {
    async title() {
      return 'Docs';
    },
    async bringToFront() {},
  };

  const result = await ensureAutomationWindowFocused({
    page,
    browser: null,
    context: null,
    platform: 'win32',
    timeoutMs: 20,
    pollIntervalMs: 5,
    readForegroundIdentity: async () => ({ title: 'Docs - Google Chrome', processId: 4200 }),
    readProcesses: async () => new Map([[4200, 4100]]),
    activateWindow: async () => false,
    activateTarget: async () => false,
  });

  assert.equal(result.status, 'unbound');
  assert.equal(result.reason, 'browser-process-identity-unavailable');
});

test('ensureAutomationWindowFocused binds when the browser exposes no process() accessor', async () => {
  // Playwright omits browser.process() for any Browser this process did not
  // launch itself, which is how the calibration executor shares one browser
  // across cases. The binding authority must still obtain the real process id,
  // so it asks the browser over CDP instead of trusting the accessor.
  const page = {
    async title() {
      return 'Docs';
    },
    async bringToFront() {},
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 5 };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };
  const browser = {
    async newBrowserCDPSession() {
      return {
        async send(method) {
          if (method === 'SystemInfo.getProcessInfo') {
            return {
              processInfo: [
                { type: 'renderer', id: 4300 },
                { type: 'browser', id: 4100 },
              ],
            };
          }
          throw new Error(`unexpected method: ${method}`);
        },
        async detach() {},
      };
    },
  };

  const result = await ensureAutomationWindowFocused({
    page,
    browser,
    context,
    platform: 'win32',
    timeoutMs: 20,
    pollIntervalMs: 5,
    readForegroundIdentity: async () => ({ title: 'Docs - Google Chrome', processId: 4200 }),
    readProcesses: async () => new Map([[4200, 4100], [4100, 900]]),
    activateWindow: async () => false,
    activateTarget: async () => false,
  });

  assert.equal(result.status, 'bound');
  assert.equal(result.expectedIdentity.browserProcessId, 4100);
});

test('ensureAutomationWindowFocused returns unsupported on non-Windows platforms', async () => {
  const result = await ensureAutomationWindowFocused({
    page: null,
    browser: null,
    context: null,
    platform: 'linux',
    timeoutMs: 20,
    pollIntervalMs: 5,
  });

  assert.equal(result.status, 'unsupported');
});

test('ensureAutomationWindowFocused uses activation remediation before second probe', async () => {
  const events = [];
  const page = {
    async title() {
      return 'Docs';
    },
    async bringToFront() {
      events.push('bring-to-front');
    },
  };
  const context = {
    async newCDPSession() {
      return {
        async send(method) {
          if (method === 'Browser.getWindowForTarget') {
            return { windowId: 7 };
          }
          if (method === 'Target.getTargetInfo') {
            return { targetInfo: { targetId: 'target-7' } };
          }
          if (method === 'Browser.setWindowBounds') {
            return {};
          }
          throw new Error(`unexpected method: ${method}`);
        },
      };
    },
  };
  let readCount = 0;
  const result = await ensureAutomationWindowFocused({
    page,
    browser: { process: () => ({ pid: 4100 }) },
    context,
    platform: 'win32',
    timeoutMs: 30,
    pollIntervalMs: 1,
    readForegroundIdentity: async () => {
      readCount += 1;
      if (readCount === 1) {
        return { title: 'New Tab - Google Chrome', processId: 9999 };
      }
      return { title: 'Docs - Google Chrome', processId: 4200 };
    },
    readProcesses: async () => new Map([[9999, 900], [4200, 4100], [4100, 900]]),
    activateWindow: async (processId) => {
      events.push(`activate:${processId}`);
      return true;
    },
    activateTarget: async ({ targetId }) => {
      events.push(`activate-target:${targetId}`);
      return true;
    },
  });

  assert.equal(result.status, 'bound');
  assert.equal(result.remediationAttempted, true);
  assert.equal(events.includes('activate-target:target-7'), true);
  // Remediation must raise the window owned by the browser process, never a
  // window that merely matches the page title.
  assert.equal(events.includes('activate:4100'), true);
  assert.equal(events.includes('activate:Docs'), false);
});

test('ensureScreenReaderStopped reports stopped only once the screen reader is gone', async () => {
  const reads = [[4100], [4100], []];
  let index = 0;
  const result = await ensureScreenReaderStopped({
    timeoutMs: 1000,
    pollIntervalMs: 1,
    readProcessIds: async () => reads[Math.min(index++, reads.length - 1)],
    terminate: async () => {
      throw new Error('termination must not run while the screen reader is still exiting');
    },
  });

  assert.deepEqual(result, { stopped: true, terminated: false, reason: null });
});

test('ensureScreenReaderStopped terminates a screen reader that ignores the quit request', async () => {
  // Guidepup's stop() fires `nvda --quit` without confirming the process
  // exited, so a hung screen reader keeps speaking and blocks the next run's
  // driver startup unless cleanup verifies and force-terminates it.
  const terminated = [];
  let cleared = false;
  const result = await ensureScreenReaderStopped({
    timeoutMs: 5,
    pollIntervalMs: 1,
    readProcessIds: async () => (cleared ? [] : [4100, 4200]),
    terminate: async (processIds) => {
      terminated.push(...processIds);
      cleared = true;
      return true;
    },
  });

  assert.deepEqual(terminated, [4100, 4200]);
  assert.deepEqual(result, { stopped: true, terminated: true, reason: null });
});

test('ensureScreenReaderStopped refuses to claim stopped when the screen reader survives termination', async () => {
  const result = await ensureScreenReaderStopped({
    timeoutMs: 5,
    pollIntervalMs: 1,
    readProcessIds: async () => [4100],
    terminate: async () => false,
  });

  assert.equal(result.stopped, false);
  assert.equal(result.reason, 'screen-reader-still-running');
});

test('ensureScreenReaderStopped refuses to claim stopped when process state is unreadable', async () => {
  const result = await ensureScreenReaderStopped({
    timeoutMs: 5,
    pollIntervalMs: 1,
    readProcessIds: async () => null,
    terminate: async () => true,
  });

  assert.equal(result.stopped, false);
  assert.equal(result.reason, 'screen-reader-state-unreadable');
});
