// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { chromium } from 'playwright';
import { execFile } from 'node:child_process';
import { mkdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';

import { evaluateAssertion } from './assertions.mjs';
import { resolveDestinationUrl, resolveRouteUrl } from './route.mjs';
import { retainScreenReaderTranscript } from './transcript.mjs';
import { assertArtifactId, assertHttpUrl } from './validation.mjs';
import {
  buildProbeResults,
  emitProbeResult,
  findNamelessControls,
  loadProbeCriteriaMap,
  redactUrl,
} from './_core.mjs';
import { createScreenReaderDriver } from './drivers/driver-contract.mjs';

const DEFAULT_VIEWPORT = { width: 1440, height: 900 };

const CHROME_HARDENING_ARGS = Object.freeze([
  '--disable-session-crashed-bubble',
  '--hide-crash-restore-bubble',
  '--no-default-browser-check',
  '--no-first-run',
  // Chrome builds its native accessibility tree lazily. A CDP client reading
  // the accessibility tree does not by itself make Chrome emit the platform
  // (IAccessible2/UIA) events a screen reader listens to, so live-region
  // mutations can go unannounced while static content still reads correctly.
  // Forcing renderer accessibility keeps the native event path active.
  '--force-renderer-accessibility',
]);

const execFileAsync = promisify(execFile);

// Reads the title of the window the operating system currently has in the
// foreground. This is the window a screen reader actually reads, which is not
// necessarily the window the automation drives over the DevTools protocol.
const FOREGROUND_WINDOW_TITLE_SCRIPT = [
  'Add-Type -Namespace RuntimeA11y -Name Win -MemberDefinition \'',
  '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
  '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, System.Text.StringBuilder s, int n);',
  '\';',
  '$h = [RuntimeA11y.Win]::GetForegroundWindow();',
  '$b = New-Object System.Text.StringBuilder 1024;',
  '[void][RuntimeA11y.Win]::GetWindowTextW($h, $b, $b.Capacity);',
  '[Console]::Out.Write($b.ToString())',
].join(' ');

// Reads the foreground window's owning process id alongside its title. The
// process id is the binding authority because, unlike document.title, the page
// under test cannot choose it.
const FOREGROUND_WINDOW_IDENTITY_SCRIPT = [
  'Add-Type -Namespace RuntimeA11yId -Name Win -MemberDefinition \'',
  '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
  '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, System.Text.StringBuilder s, int n);',
  '[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);',
  '\';',
  '$h = [RuntimeA11yId.Win]::GetForegroundWindow();',
  '$b = New-Object System.Text.StringBuilder 1024;',
  '[void][RuntimeA11yId.Win]::GetWindowTextW($h, $b, $b.Capacity);',
  '$pid2 = 0;',
  '[void][RuntimeA11yId.Win]::GetWindowThreadProcessId($h, [ref]$pid2);',
  '[Console]::Out.Write((ConvertTo-Json -Compress ([ordered]@{ title = $b.ToString(); processId = $pid2 })))',
].join(' ');

// Lists every process id with its parent, so the caller can decide whether the
// foreground window belongs to the browser it launched or to one of its
// children. Emitted as JSON with no interpolated input.
const PROCESS_TREE_SCRIPT =
  '[Console]::Out.Write((Get-CimInstance Win32_Process | '
  + 'Select-Object -Property ProcessId, ParentProcessId | ConvertTo-Json -Compress))';

// Lists screen reader process ids so cleanup can confirm the driver actually
// exited. Guidepup's stop() issues `nvda --quit` and returns without checking,
// so a hung screen reader is reported as stopped while it keeps speaking.
const SCREEN_READER_PROCESS_SCRIPT =
  '[Console]::Out.Write((@(Get-Process -Name nvda -ErrorAction SilentlyContinue '
  + '| Select-Object -ExpandProperty Id) | ConvertTo-Json -Compress))';

export async function readScreenReaderProcessIds() {
  if (process.platform !== 'win32') {
    return [];
  }
  try {
    // Fixed script text with no interpolated input.
    const { stdout } = await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', SCREEN_READER_PROCESS_SCRIPT],
      { timeout: 20000, windowsHide: true },
    );
    const text = String(stdout || '').trim();
    if (!text) {
      return [];
    }
    const parsed = JSON.parse(text);
    const entries = Array.isArray(parsed) ? parsed : [parsed];
    return entries.map((entry) => Number(entry)).filter((id) => Number.isInteger(id) && id > 0);
  } catch {
    return null;
  }
}

async function terminateProcessIds(processIds) {
  if (process.platform !== 'win32' || !Array.isArray(processIds) || processIds.length === 0) {
    return false;
  }
  try {
    await execFileAsync(
      'taskkill.exe',
      ['/F', '/T', ...processIds.flatMap((id) => ['/PID', String(id)])],
      { timeout: 20000, windowsHide: true },
    );
    return true;
  } catch {
    return false;
  }
}

// Confirms the screen reader actually exited after the driver reported stopping.
//
// Termination is limited to processes absent from the pre-start baseline, so a
// screen reader the operator was already running is never force-terminated.
// That matters because the operator may depend on it. A remnant this run
// started is force-terminated instead, since leaving one alive hijacks the
// machine's speech and blocks the next run's driver startup. A surviving
// process the run does not own is reported as unverified cleanup rather than
// killed.
export async function ensureScreenReaderStopped({
  timeoutMs = 10000,
  pollIntervalMs = 500,
  readProcessIds = readScreenReaderProcessIds,
  terminate = terminateProcessIds,
  preexistingProcessIds = null,
} = {}) {
  const preexisting = new Set(
    Array.isArray(preexistingProcessIds) ? preexistingProcessIds : [],
  );
  const ownedBy = (ids) => ids.filter((id) => !preexisting.has(id));

  const deadline = Date.now() + timeoutMs;
  let remaining = await readProcessIds();
  while (
    Array.isArray(remaining) &&
    ownedBy(remaining).length > 0 &&
    Date.now() < deadline
  ) {
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    remaining = await readProcessIds();
  }
  if (remaining === null) {
    return { stopped: false, terminated: false, reason: 'screen-reader-state-unreadable' };
  }

  const owned = ownedBy(remaining);
  if (owned.length === 0) {
    return { stopped: true, terminated: false, reason: null };
  }
  const terminated = await terminate(owned);
  const after = await readProcessIds();
  const stopped = Array.isArray(after) && ownedBy(after).length === 0;
  return {
    stopped,
    terminated,
    reason: stopped ? null : 'screen-reader-still-running',
  };
}

// Activates the browser's own top-level window.
//
// The window is selected by owning process id, never by title, so remediation
// cannot raise an unrelated window that merely shares the page title. The
// process main window handle is used rather than an EnumWindows scan because a
// browser owns several visible helper windows and only the main one is the
// window a screen reader reads.
//
// Windows refuses SetForegroundWindow from a process that does not hold the
// foreground or the most recent input, which silently degrades to a taskbar
// flash. Attaching to the current foreground thread's input queue for the
// duration of the call is the supported way to make the request take effect.
const ACTIVATE_BROWSER_WINDOW_SCRIPT = [
  'Add-Type -Namespace RuntimeA11y -Name Win -MemberDefinition \'',
  '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);',
  '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);',
  '[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);',
  '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
  '[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr pid);',
  '[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);',
  '[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();',
  '\';',
  '$expected = [Environment]::GetEnvironmentVariable("RUNTIME_A11Y_BROWSER_PROCESS_ID");',
  '$expectedPid = 0;',
  'if (-not [int]::TryParse($expected, [ref]$expectedPid)) { return; }',
  'if ($expectedPid -le 0) { return; }',
  '$deadline = (Get-Date).AddSeconds(5);',
  '$handle = [IntPtr]::Zero;',
  'while ((Get-Date) -lt $deadline -and $handle -eq [IntPtr]::Zero) {',
  '  $candidates = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $expectedPid -or $_.Parent.Id -eq $expectedPid };',
  '  foreach ($candidate in $candidates) {',
  '    if ($candidate.MainWindowHandle -ne [IntPtr]::Zero) { $handle = $candidate.MainWindowHandle; break; }',
  '  }',
  '  if ($handle -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 200 }',
  '}',
  'if ($handle -eq [IntPtr]::Zero) { return; }',
  '[void][RuntimeA11y.Win]::ShowWindowAsync($handle, 9);',
  '$foreground = [RuntimeA11y.Win]::GetForegroundWindow();',
  '$foregroundThread = [RuntimeA11y.Win]::GetWindowThreadProcessId($foreground, [IntPtr]::Zero);',
  '$currentThread = [RuntimeA11y.Win]::GetCurrentThreadId();',
  '$attached = $false;',
  'if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {',
  '  $attached = [RuntimeA11y.Win]::AttachThreadInput($currentThread, $foregroundThread, $true);',
  '}',
  'try {',
  '  [void][RuntimeA11y.Win]::BringWindowToTop($handle);',
  '  [void][RuntimeA11y.Win]::SetForegroundWindow($handle);',
  '}',
  'finally { if ($attached) { [void][RuntimeA11y.Win]::AttachThreadInput($currentThread, $foregroundThread, $false); } }',
].join(' ');

export async function readForegroundWindowTitle() {
  if (process.platform !== 'win32') {
    return null;
  }
  try {
    // Fixed script text with no interpolated input.
    const { stdout } = await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', FOREGROUND_WINDOW_TITLE_SCRIPT],
      { timeout: 5000, windowsHide: true },
    );
    return String(stdout || '').trim();
  } catch {
    return null;
  }
}

export async function readForegroundWindowIdentity() {
  if (process.platform !== 'win32') {
    return null;
  }
  try {
    // Fixed script text with no interpolated input. The timeout accommodates
    // Add-Type compiling the interop shim on a machine already loaded by a
    // running screen reader; a shorter budget reports a false read failure.
    const { stdout } = await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', FOREGROUND_WINDOW_IDENTITY_SCRIPT],
      { timeout: 20000, windowsHide: true },
    );
    const parsed = JSON.parse(String(stdout || '').trim());
    const processId = Number(parsed?.processId);
    return {
      title: typeof parsed?.title === 'string' ? parsed.title.trim() : null,
      processId: Number.isInteger(processId) && processId > 0 ? processId : null,
    };
  } catch {
    return null;
  }
}

export async function readProcessTree() {
  if (process.platform !== 'win32') {
    return null;
  }
  try {
    // Fixed script text with no interpolated input.
    const { stdout } = await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', PROCESS_TREE_SCRIPT],
      { timeout: 10000, windowsHide: true },
    );
    const parsed = JSON.parse(String(stdout || '').trim());
    const entries = Array.isArray(parsed) ? parsed : [parsed];
    const parents = new Map();
    for (const entry of entries) {
      const processId = Number(entry?.ProcessId);
      const parentProcessId = Number(entry?.ParentProcessId);
      if (Number.isInteger(processId) && processId > 0) {
        parents.set(processId, Number.isInteger(parentProcessId) ? parentProcessId : null);
      }
    }
    return parents;
  } catch {
    return null;
  }
}

// True when candidatePid is ancestorPid or descends from it. Chrome owns its
// top-level window in the browser process, but a launcher shim can place that
// process one level below the pid Playwright reports, so ancestry is checked
// rather than identity alone. The walk is depth-bounded so a cyclic or
// malformed tree cannot spin.
export function isSameOrDescendantProcess(candidatePid, ancestorPid, parents) {
  if (!Number.isInteger(candidatePid) || !Number.isInteger(ancestorPid) || !parents) {
    return false;
  }
  let current = candidatePid;
  for (let depth = 0; depth < 64; depth += 1) {
    if (current === ancestorPid) {
      return true;
    }
    const next = parents.get(current);
    if (!Number.isInteger(next) || next <= 0 || next === current) {
      return false;
    }
    current = next;
  }
  return false;
}

export async function activateBrowserWindow(browserProcessId) {
  if (process.platform !== 'win32') {
    return false;
  }
  if (!Number.isInteger(browserProcessId) || browserProcessId <= 0) {
    return false;
  }
  try {
    await execFileAsync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', ACTIVATE_BROWSER_WINDOW_SCRIPT],
      {
        timeout: 5000,
        windowsHide: true,
        env: {
          ...process.env,
          RUNTIME_A11Y_BROWSER_PROCESS_ID: String(browserProcessId),
        },
      },
    );
    return true;
  } catch {
    return false;
  }
}

export async function activatePageTarget({ page, context, browser, targetId } = {}) {
  const resolvedTargetId = typeof targetId === 'string' ? targetId.trim() : '';
  if (!resolvedTargetId) {
    return false;
  }

  const targetContext = context || page?.context?.();
  const cdpSessionFactory = targetContext?.newCDPSession?.bind(targetContext);
  const browserCdpFactory = browser?.newBrowserCDPSession?.bind(browser);
  if (!cdpSessionFactory && !browserCdpFactory) {
    return false;
  }

  try {
    const cdpSession = cdpSessionFactory
      ? await cdpSessionFactory(page)
      : await browserCdpFactory();
    await cdpSession.send('Target.activateTarget', { targetId: resolvedTargetId });
    await page?.bringToFront?.().catch(() => undefined);
    return true;
  } catch {
    return false;
  }
}

async function collectControlledWindowIdentity({ page, browser, context } = {}) {
  const pageTitle = await page?.title?.().catch(() => null);
  let pageUrl = null;
  try {
    if (typeof page?.url === 'function') {
      pageUrl = page.url() || null;
    }
  } catch {
    pageUrl = null;
  }
  const targetContext = context || page?.context?.();
  const cdpSessionFactory = targetContext?.newCDPSession?.bind(targetContext);
  const browserCdpFactory = browser?.newBrowserCDPSession?.bind(browser);

  let windowId = null;
  let targetInfo = null;
  if (cdpSessionFactory || browserCdpFactory) {
    try {
      const cdpSession = cdpSessionFactory ? await cdpSessionFactory(page) : await browserCdpFactory();
      const windowForTarget = await cdpSession.send('Browser.getWindowForTarget').catch(() => null);
      if (Number.isFinite(Number(windowForTarget?.windowId))) {
        windowId = Number(windowForTarget.windowId);
      }
      targetInfo = await cdpSession.send('Target.getTargetInfo').catch(() => null);
    } catch {
      // Fall back to the lightweight title/url identity captured from Playwright.
    }
  }

  return {
    windowId,
    pageTitle,
    pageUrl,
    pageTargetId: targetInfo?.targetInfo?.targetId || targetInfo?.targetId || null,
    targetTitle: targetInfo?.targetInfo?.title || targetInfo?.title || pageTitle || null,
    targetUrl: targetInfo?.targetInfo?.url || targetInfo?.url || pageUrl || null,
  };
}

// Resolves the process id of the browser under automation.
//
// Playwright only exposes `browser.process()` for a browser this process
// launched directly; it is absent when the Browser arrives over a connection or
// is handed through as a shared instance, which is how the calibration executor
// drives it. Falling back to the CDP SystemInfo domain reports the actual
// browser process id in both cases.
export async function resolveBrowserProcessId({ browser, context, page } = {}) {
  const direct = typeof browser?.process === 'function' ? browser.process()?.pid : null;
  if (Number.isInteger(direct) && direct > 0) {
    return direct;
  }
  const targetContext = context || page?.context?.();
  const factory = browser?.newBrowserCDPSession?.bind(browser)
    || (targetContext?.newCDPSession ? () => targetContext.newCDPSession(page) : null);
  if (!factory) {
    return null;
  }
  let session = null;
  try {
    session = await factory();
    const info = await session.send('SystemInfo.getProcessInfo');
    const entries = Array.isArray(info?.processInfo) ? info.processInfo : [];
    const browserEntry = entries.find((entry) => entry?.type === 'browser') ?? entries[0];
    const pid = Number(browserEntry?.id);
    return Number.isInteger(pid) && pid > 0 ? pid : null;
  } catch {
    return null;
  } finally {
    if (session && typeof session.detach === 'function') {
      await session.detach().catch(() => undefined);
    }
  }
}

// Binds the screen reader's reading context to the window under test.
//
// Playwright controls a specific window over CDP, but a screen reader narrates
// whichever window the OS has focused. Without this check the harness can
// synthesize keystrokes into an unrelated window and capture that window's
// speech, which silently produces evidence about the wrong surface.
//
// The binding authority is the foreground window's owning process, not its
// title. A title comparison is page-controllable: a page that sets a short
// common title would satisfy a substring match from any window containing it.
// Process ancestry cannot be chosen by page content.
export async function ensureAutomationWindowFocused({
  page,
  browser,
  context,
  timeoutMs = 5000,
  pollIntervalMs = 250,
  platform = process.platform,
  readForegroundIdentity = readForegroundWindowIdentity,
  readProcesses = readProcessTree,
  activateWindow = activateBrowserWindow,
  activateTarget = activatePageTarget,
} = {}) {
  if (String(platform).toLowerCase() !== 'win32' && String(platform).toLowerCase() !== 'windows') {
    return { status: 'unsupported', reason: 'foreground-check-requires-windows' };
  }
  if (!page || typeof page.title !== 'function') {
    return { status: 'unbound', reason: 'page-unavailable', attempts: 0 };
  }

  const documentTitle = await page.title().catch(() => null);
  const browserProcessId = await resolveBrowserProcessId({ browser, context, page });
  if (!Number.isInteger(browserProcessId)) {
    // Without an authoritative process identity this check cannot tell the
    // window under test from any other, so it fails closed rather than falling
    // back to a page-controllable title comparison.
    return {
      status: 'unbound',
      reason: 'browser-process-identity-unavailable',
      expectedTitle: documentTitle,
      attempts: 0,
    };
  }

  const expectedIdentity = {
    ...(await collectControlledWindowIdentity({ page, browser, context })),
    browserProcessId,
  };
  const deadline = Date.now() + timeoutMs;
  let attempts = 0;
  let remediationAttempted = false;
  let foregroundIdentity = null;

  while (Date.now() < deadline && attempts < 2) {
    attempts += 1;
    await maximizeBrowserWindow({ browser, context, page });
    await page.bringToFront?.().catch(() => undefined);
    if (typeof page.focus === 'function') {
      await page.focus().catch(() => undefined);
    }
    const foreground = await readForegroundIdentity();
    foregroundIdentity = {
      windowTitle: foreground?.title || null,
      processId: Number.isInteger(foreground?.processId) ? foreground.processId : null,
    };

    if (foregroundIdentity.processId !== null) {
      const parents = await readProcesses();
      if (isSameOrDescendantProcess(foregroundIdentity.processId, browserProcessId, parents)) {
        return {
          status: 'bound',
          expectedIdentity,
          foregroundIdentity,
          expectedTitle: documentTitle,
          foregroundTitle: foregroundIdentity.windowTitle,
          attempts,
          remediationAttempted,
          reason: null,
        };
      }
    }

    if (attempts === 1 && timeoutMs > 0) {
      remediationAttempted = true;
      await activateTarget({
        page,
        context,
        browser,
        targetId: expectedIdentity?.pageTargetId,
      }).catch(() => undefined);
      await activateWindow(browserProcessId).catch(() => undefined);
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
      continue;
    }
  }

  return {
    status: 'unbound',
    expectedIdentity,
    foregroundIdentity,
    expectedTitle: documentTitle,
    foregroundTitle: foregroundIdentity?.windowTitle || null,
    attempts,
    remediationAttempted,
    // An unreadable foreground is a distinct failure from a foreground owned by
    // another process; reporting them alike sends diagnosis down the wrong path.
    reason: foregroundIdentity?.processId == null
      ? 'foreground-identity-unreadable'
      : 'foreground-window-does-not-belong-to-the-browser-under-test',
  };
}

// Installed as an init script before navigation so it observes the live DOM from
// first paint. Records post-load live-region announcements into a window global
// that probes (notably probe-live-region) read to decide whether a status
// message actually fired rather than merely existing. The shared runner clears
// the update log immediately before the state trigger so recorded updates are
// genuine trigger-driven announcements, not hydration noise.
export function liveRegionObserverScript() {
  const LIVE_SELECTOR =
    '[aria-live="polite"],[aria-live="assertive"],[role="status"],[role="alert"],[role="log"]';
  const state = { updates: [], loadCount: 0, emptyAtLoad: 0 };
  window.__runtimeA11yLiveRegion = state;

  const regionFor = (node) => {
    const element = node && node.nodeType === 1 ? node : node && node.parentElement;
    return element && element.closest ? element.closest(LIVE_SELECTOR) : null;
  };

  let started = false;
  const start = () => {
    if (started || !document.body) {
      return;
    }
    started = true;
    const regions = Array.from(document.querySelectorAll(LIVE_SELECTOR));
    state.loadCount = regions.length;
    state.emptyAtLoad = regions.filter((region) => (region.textContent || '').trim() === '').length;

    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        const region = regionFor(mutation.target);
        if (!region) {
          continue;
        }
        const text = (region.textContent || '').trim();
        state.updates.push({ text: text.slice(0, 120), at: Date.now() });
        if (state.updates.length > 20) {
          state.updates.shift();
        }
      }
    });
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ['aria-live'],
    });
  };

  if (document.body) {
    start();
  } else {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  }
}

function getRuntimeConfig() {
  const raw = process.env.RUNTIME_A11Y_CONFIG || '{}';
  return JSON.parse(raw);
}

function getRuntimeContext() {
  const config = getRuntimeConfig();
  return {
    config,
    probeId: process.env.RUNTIME_A11Y_PROBE_ID || 'probe-unknown',
    surfaceId: process.env.RUNTIME_A11Y_SURFACE_ID || '',
    state: process.env.RUNTIME_A11Y_STATE || 'default',
    baseUrl: process.env.RUNTIME_A11Y_BASE_URL || config.baseUrl || 'http://127.0.0.1:3000',
    trace: process.env.RUNTIME_A11Y_TRACE === '1',
  };
}

export function resolveTargetUrl(baseUrl, surface) {
  const route = surface?.route || '';
  if (!route) {
    return baseUrl;
  }
  return resolveRouteUrl(route, baseUrl);
}

export function resolveLocator(page, target) {
  if (typeof target === 'string') {
    return page.locator(target);
  }

  if (target && typeof target === 'object') {
    if (target.kind === 'role') {
      return page.getByRole(target.role || 'button', { name: target.name || undefined });
    }
    if (target.value) {
      return page.locator(target.value);
    }
  }

  return page.locator('body');
}

async function runTriggerAction(action, strict) {
  if (strict) {
    await action();
    return;
  }
  await action().catch(() => undefined);
}

export async function applyTrigger(page, trigger, { strict = false, baseUrl = null } = {}) {
  if (!trigger) {
    return;
  }

  const action = trigger.action || 'visit';
  const target = trigger.target;
  const locator = resolveLocator(page, target);
  const currentUrl = baseUrl || (typeof page?.url === 'function' ? page.url() : page?.url);
  let navigationUrl = null;
  if (action === 'navigate') {
    navigationUrl = resolveDestinationUrl(trigger.value || '/', currentUrl);
  } else if (action === 'visit' && (typeof target === 'string' || target?.value)) {
    navigationUrl = resolveDestinationUrl(target?.value || target, currentUrl);
  }

  switch (action) {
    case 'click':
      await runTriggerAction(() => locator.click({ timeout: 1000 }), strict);
      break;
    case 'focus':
      await runTriggerAction(() => locator.focus({ timeout: 1000 }), strict);
      break;
    case 'hover':
      await runTriggerAction(() => locator.hover({ timeout: 1000 }), strict);
      break;
    case 'type':
      await runTriggerAction(
        () => locator.fill(trigger.value || '', { timeout: 1000 }),
        strict,
      );
      break;
    case 'press':
      await runTriggerAction(
        () => page.keyboard.press(trigger.value || 'Enter'),
        strict,
      );
      break;
    case 'navigate':
      await runTriggerAction(
        () => page.goto(navigationUrl, { waitUntil: 'domcontentloaded' }),
        strict,
      );
      break;
    case 'visit':
      if (navigationUrl) {
        await runTriggerAction(
          () => page.goto(navigationUrl, { waitUntil: 'domcontentloaded' }),
          strict,
        );
      }
      break;
    default:
      if (strict) {
        throw new Error(`Unsupported trigger action: ${action}`);
      }
      break;
  }

  if (trigger.waitFor) {
    const waitFor = resolveLocator(page, trigger.waitFor);
    await runTriggerAction(
      () => waitFor.waitFor({ state: 'visible', timeout: 1000 }),
      strict,
    );
  }
}

export async function applyStateEmulation(page, state) {
  const viewport = state === 'mobile'
    ? { width: 390, height: 844 }
    : state === 'reflow-320'
      ? { width: 320, height: 900 }
      : state === 'zoom-400'
        ? { width: 1280, height: 900 }
        : DEFAULT_VIEWPORT;

  await page.setViewportSize(viewport);
  await page.emulateMedia({
    colorScheme: state.includes('dark') ? 'dark' : 'light',
    forcedColors: state.includes('forced-colors') ? 'active' : 'none',
    reducedMotion: state.includes('reduced-motion') ? 'reduce' : 'no-preference',
  });

  if (state.includes('zoom-400')) {
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '200%';
    }).catch(() => undefined);
  }

  if (state.includes('reflow-320')) {
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '16px';
    }).catch(() => undefined);
  }
}

async function gatherTracingAssets(page, context, tracePath) {
  if (!tracePath) {
    return null;
  }

  await page.screenshot({ path: tracePath.replace(/\.zip$/, '.png'), fullPage: true }).catch(() => undefined);
  await context.tracing.stop({ path: tracePath }).catch(() => undefined);
  return tracePath;
}

export async function maximizeBrowserWindow({ browser, context, page } = {}) {
  const targetContext = context || page?.context?.();
  const targetPage = page || null;
  const cdpSessionFactory = targetContext?.newCDPSession?.bind(targetContext);
  const browserCdpFactory = browser?.newBrowserCDPSession?.bind(browser);

  if (!cdpSessionFactory && !browserCdpFactory) {
    return { status: 'unavailable', reason: 'browser-cdp-unavailable' };
  }

  try {
    const cdpSession = cdpSessionFactory
      ? await cdpSessionFactory(targetPage)
      : await browserCdpFactory();
    const windowForTarget = await cdpSession.send('Browser.getWindowForTarget');
    if (!windowForTarget?.windowId) {
      return { status: 'unavailable', reason: 'browser-window-id-unavailable' };
    }

    await cdpSession.send('Browser.setWindowBounds', {
      windowId: windowForTarget.windowId,
      bounds: { windowState: 'maximized' },
    });

    if (targetPage && typeof targetPage.bringToFront === 'function') {
      await targetPage.bringToFront().catch(() => undefined);
    }

    return {
      status: 'maximized',
      reason: null,
      windowId: windowForTarget.windowId,
      browserContext: context ? 'context-provided' : 'context-absent',
      pageTarget: page ? 'page-provided' : 'page-absent',
    };
  } catch (error) {
    return {
      status: 'unavailable',
      reason: error instanceof Error ? error.message : String(error),
      browserContext: context ? 'context-provided' : 'context-absent',
      pageTarget: page ? 'page-provided' : 'page-absent',
    };
  }
}

export async function injectAxe(page) {
  try {
    const mod = await import('@axe-core/playwright');
    const AxeBuilder = mod.default || mod.AxeBuilder;
    if (!AxeBuilder) {
      return null;
    }
    const builder = new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']);
    return await builder.analyze();
  } catch {
    return null;
  }
}

export async function snapshotAccessibilityTree(page) {
  if (!page) {
    return null;
  }

  try {
    const context = typeof page.context === 'function' ? page.context() : null;
    const cdpSessionFactory = context?.newCDPSession?.bind(context);
    if (cdpSessionFactory) {
      const cdpSession = await cdpSessionFactory(page);
      await cdpSession.send('Accessibility.enable');
      const axTree = await cdpSession.send('Accessibility.getFullAXTree');
      return {
        source: 'cdp',
        nodes: Array.isArray(axTree?.nodes) ? axTree.nodes : [],
      };
    }
  } catch {
    // Fall back to the legacy snapshot API when the browser does not expose a
    // target-bound CDP session for accessibility capture.
  }

  try {
    return await page.accessibility.snapshot();
  } catch {
    return null;
  }
}

// Launch headless system Chrome by default. Real AT execution explicitly opts
// into a headed browser via the options passed from the executor path.
//
// Playwright gives each launched browser its own ephemeral profile directory and
// removes it on close, so automation never reads or writes a real browsing
// profile. Do not pass an explicit --user-data-dir; Playwright rejects it.
export function buildChromeLaunchOptions(options = {}) {
  const args = [...CHROME_HARDENING_ARGS];

  return {
    channel: 'chrome',
    headless: options.headless ?? true,
    args,
  };
}

export async function launchChrome(options = {}) {
  return chromium.launch(buildChromeLaunchOptions(options));
}

// The virtual screen reader's browser build is a self-contained ESM bundle,
// resolved from the skill-local node_modules relative to this module.
const VSR_BROWSER_BUILD = new URL(
  '../node_modules/@guidepup/virtual-screen-reader/lib/esm/index.browser.js',
  import.meta.url,
);

// Inject the virtual screen reader into the live page, drive it end to end, and
// return a snapshot of the announced phrase log with the nameless interactive
// controls it exposes. Shared by probe-virtual-sr and its smoke tests so both
// exercise the identical capture path.
export async function captureVirtualSr(page) {
  try {
    const moduleSource = await readFile(VSR_BROWSER_BUILD, 'utf8');
    const traversal = await page.evaluate(async (source) => {
      const blob = new Blob([source], { type: 'text/javascript' });
      const url = URL.createObjectURL(blob);
      try {
        const { virtual } = await import(url);
        await virtual.start({ container: document.body });
        let guard = 0;
        let reachedEnd = false;
        while (guard < 2000) {
          guard += 1;
          await virtual.next();
          if ((await virtual.lastSpokenPhrase()) === 'end of document') {
            reachedEnd = true;
            break;
          }
        }
        const log = await virtual.spokenPhraseLog();
        await virtual.stop();
        return { log, reachedEnd };
      } finally {
        URL.revokeObjectURL(url);
      }
    }, moduleSource);

    const nameless = findNamelessControls(traversal.log);
    return {
      ran: true,
      phraseCount: traversal.log.length,
      reachedEnd: traversal.reachedEnd,
      namelessCount: nameless.length,
      nameless: nameless.slice(0, 5),
    };
  } catch (error) {
    return { ran: false, error: error instanceof Error ? error.message : String(error) };
  }
}

// Clear the live-region announcement log so only updates after this point count
// as a fired status message.
export async function clearLiveRegionLog(page) {
  await page
    .evaluate(() => {
      if (window.__runtimeA11yLiveRegion) {
        window.__runtimeA11yLiveRegion.updates = [];
      }
    })
    .catch(() => undefined);
}

// Read the live-region observation snapshot after allowing debounced announcers
// to settle. Shared by probe-live-region and its smoke tests.
export async function readLiveRegionSnapshot(page, { settleMs = 500 } = {}) {
  if (settleMs > 0) {
    await page.waitForTimeout(settleMs).catch(() => undefined);
  }
  return page.evaluate(() => {
    const LIVE_SELECTOR =
      '[aria-live="polite"],[aria-live="assertive"],[role="status"],[role="alert"],[role="log"]';
    const live = window.__runtimeA11yLiveRegion || { updates: [], loadCount: 0, emptyAtLoad: 0 };
    return {
      regionsAtLoad: live.loadCount,
      regionsNow: document.querySelectorAll(LIVE_SELECTOR).length,
      emptyAtLoad: live.emptyAtLoad,
      fired: live.updates.length > 0,
      firedTexts: live.updates.map((update) => update.text).slice(-3),
    };
  });
}

export async function runProbeWithPage(callback) {
  const contextData = getRuntimeContext();
  const { config, probeId, surfaceId, state, baseUrl, trace } = contextData;
  assertHttpUrl(baseUrl, 'Runtime base URL');
  const surface = (config.surfaces || []).find((entry) => entry.id === surfaceId) || null;
  const targetUrl = resolveTargetUrl(baseUrl, surface);
  const browser = await chromium.launch(buildChromeLaunchOptions({ headless: true }));
  const context = await browser.newContext({
    viewport: DEFAULT_VIEWPORT,
    colorScheme: 'light',
    forcedColors: 'none',
    reducedMotion: 'no-preference',
  });
  const page = await context.newPage();
  // Observe live-region announcements from first paint so probes can decide
  // whether a status message fires, not merely whether a region exists.
  await page.addInitScript(liveRegionObserverScript);

  let tracePath = null;
  if (trace) {
    assertArtifactId(probeId, 'Probe ID');
    assertArtifactId(surfaceId, 'Surface ID');
    assertArtifactId(state, 'State ID');
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    const artifactsDir = path.join(
      process.cwd(),
      'artifacts',
      probeId,
      surfaceId,
      state,
    );
    await mkdir(artifactsDir, { recursive: true });
    tracePath = path.join(artifactsDir, 'trace.zip');
  }

  try {
    await applyStateEmulation(page, state);
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
    // Allow client frameworks to hydrate so probes observe the settled DOM
    // rather than transient pre-hydration markup. Capped so a page that never
    // reaches network idle does not stall the run.
    await page.waitForLoadState('networkidle', { timeout: 2500 }).catch(() => undefined);
    const trigger = surface?.states?.find((entry) => entry.state === state)?.trigger || null;
    // Discard any live-region updates from hydration so only trigger-driven
    // announcements are counted as a fired status message.
    await clearLiveRegionLog(page);
    await applyTrigger(page, trigger, { baseUrl });
    return await callback({ browser, context, page, targetUrl, surface, state, tracePath, baseUrl, probeId, surfaceId });
  } finally {
    if (tracePath) {
      await gatherTracingAssets(page, context, tracePath).catch(() => undefined);
    }
    await context.close().catch(() => undefined);
    await browser.close().catch(() => undefined);
  }
}

// Resolves the cleanup verifier used by the real screen-reader probe.
//
// The injection seam exists so failure paths are reachable without a real
// screen reader. It deliberately falls back to the production verifier: a
// permissive default would reintroduce the fail-open this verification closes.
export function resolveScreenReaderVerifier(verifier) {
  return typeof verifier === 'function' ? verifier : ensureScreenReaderStopped;
}

export async function runRealScreenReaderProbe(page, {
  surface,
  state,
  targetUrl,
  config = {},
  createDriver = createScreenReaderDriver,
  verifyScreenReaderStopped,
} = {}) {
  const runtimeConfig = config || getRuntimeContext().config || {};
  const surfaceConfig = surface?.states?.find((entry) => entry.state === state) || {};
  const probeConfig = surfaceConfig?.realScreenReader || runtimeConfig?.realScreenReader || {};
  const verifyStopped = resolveScreenReaderVerifier(verifyScreenReaderStopped);
  let driver = null;
  let driverStarted = false;
  let preexistingProcessIds = [];
  // Cleanup is a separate outcome from the accessibility verdict. A run can
  // produce a valid finding and still fail to stop the screen reader, so the
  // facts travel on the result rather than replacing it with a throw.
  const cleanup = {
    driverStarted: false,
    driverStopped: false,
    terminated: false,
    stopError: null,
    reason: null,
  };
  let result = null;

  try {
    driver = await createDriver({ platform: process.platform, config: probeConfig });

    if (!driver?.supported) {
      result = {
        ran: false,
        supported: false,
        reason: driver?.reason || driver?.status || 'unsupported',
        phrases: [],
        assertions: [],
        driver: driver?.driver || null,
        platform: process.platform,
      };
    } else {
      // Record which screen-reader processes were already running so cleanup
      // can tell a remnant this run started from a session the operator was
      // relying on before it began.
      preexistingProcessIds = (await readScreenReaderProcessIds()) || [];
      await driver.start();
      driverStarted = true;
      for (const command of probeConfig.commands || []) {
        await driver.executeCommand(command);
      }
      const snapshot = await driver.captureLog();
      const phrases = Array.isArray(snapshot?.phrases) ? snapshot.phrases : [];
      const expectedAnnouncements = Array.isArray(probeConfig.expectedAnnouncements)
        ? probeConfig.expectedAnnouncements
        : [];
      const assertions = (Array.isArray(snapshot?.assertions) ? snapshot.assertions : []).map((assertion) => ({
        ...assertion,
        ...evaluateAssertion(assertion, phrases),
      }));

      if (expectedAnnouncements.length > 0) {
        for (const assertion of expectedAnnouncements) {
          const evaluation = evaluateAssertion(assertion, phrases);
          assertions.push({
            id: assertion.id || 'announcement',
            type: assertion.type,
            value: assertion.value,
            ...evaluation,
          });
        }
      }

      // Assertions are evaluated above against the raw phrases, so verdict
      // fidelity is unaffected by what leaves this boundary. A screen reader
      // speaks whatever is on screen, which on an authenticated surface
      // includes names, addresses, and account details. Only the phrase count
      // and the assertion outcomes travel onward; the transcript itself is
      // retained separately and only when explicitly requested.
      const transcript = retainScreenReaderTranscript(phrases, {
        surfaceId: surface?.id || null,
        state,
      });

      result = {
        ran: true,
        supported: true,
        phraseCount: phrases.length,
        assertions,
        transcript,
        driver: snapshot?.driver || driver?.driver || null,
        platform: process.platform,
        targetUrl,
        state,
        evidence: JSON.stringify({
          phraseCount: phrases.length,
          assertions: assertions.map(({ id, type, status, detail, evidenceType }) => ({
            id,
            type,
            status,
            detail,
            evidenceType,
          })),
          driver: snapshot?.driver || driver?.driver || null,
        }),
      };
    }
  } catch (error) {
    result = {
      ran: false,
      supported: false,
      reason: error instanceof Error ? error.message : String(error),
      phrases: [],
      assertions: [],
      driver: driver?.driver || null,
      platform: process.platform,
    };
  } finally {
    if (driver?.supported && typeof driver.stop === 'function') {
      try {
        await driver.stop();
      } catch (error) {
        cleanup.stopError = error instanceof Error ? error.message : String(error);
      }
    }
    if (driverStarted) {
      // The driver's stop request is asynchronous and unverified, so cleanup is
      // only recorded as complete once the screen reader is observably gone.
      const verification = await verifyStopped({ preexistingProcessIds }).catch((error) => ({
        stopped: false,
        terminated: false,
        reason: error instanceof Error ? error.message : 'screen-reader-verification-failed',
      }));
      cleanup.driverStopped = verification?.stopped === true;
      cleanup.terminated = verification?.terminated === true;
      cleanup.reason = verification?.reason ?? null;
    }
    cleanup.driverStarted = driverStarted;
    result.cleanup = cleanup;
  }

  return result;
}

// A started screen reader that cannot be proven stopped leaves the operator's
// machine under its control, so the invoking command must fail even though the
// accessibility result is still valid and emitted.
export function isScreenReaderCleanupUnproven(cleanup) {
  return cleanup?.driverStarted === true && cleanup?.driverStopped !== true;
}

export { redactUrl, buildProbeResults, emitProbeResult, loadProbeCriteriaMap };
