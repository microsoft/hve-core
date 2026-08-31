// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

import { evaluateAssertion, normalizeSpokenOutput } from './assertions.mjs';
import { applyStateEmulation, applyTrigger, resolveTargetUrl, launchChrome, maximizeBrowserWindow, snapshotAccessibilityTree, ensureAutomationWindowFocused, ensureScreenReaderStopped } from './_shared.mjs';
import { createScreenReaderDriver } from './drivers/driver-contract.mjs';

const ALLOWED_STATUSES = new Set(['pass', 'fail', 'candidate', 'unsupported', 'error']);

function normalizeStatus(status) {
  return ALLOWED_STATUSES.has(status) ? status : 'error';
}

function normalizePlatform(platform) {
  return String(platform || process.platform || 'linux').toLowerCase();
}

function isCompatiblePlatform(platform, at) {
  const normalized = normalizePlatform(platform);
  if (at === 'nvda') {
    return normalized === 'win32' || normalized === 'windows';
  }
  if (at === 'jaws') {
    return normalized === 'win32' || normalized === 'windows';
  }
  return false;
}

function selectVariant(matrixCase) {
  const explicit = matrixCase?.variant || null;
  if (explicit) {
    return explicit;
  }

  const variants = Array.isArray(matrixCase?.variants) ? matrixCase.variants : [];
  const eligible = variants.filter((variant) => variant?.automationEligible !== false);
  if (eligible.length === 0) {
    return null;
  }
  return eligible[0];
}

function resolveCommands(matrixCase, variant) {
  if (Array.isArray(variant?.commands) && variant.commands.length > 0) {
    return variant.commands;
  }
  if (Array.isArray(matrixCase?.commands) && matrixCase.commands.length > 0) {
    return matrixCase.commands;
  }
  return [];
}

function resolveAssertions(matrixCase, variant) {
  if (Array.isArray(variant?.assertions) && variant.assertions.length > 0) {
    return variant.assertions;
  }
  if (Array.isArray(matrixCase?.assertions) && matrixCase.assertions.length > 0) {
    return matrixCase.assertions;
  }
  return [];
}

function resolveTriggerSequence(matrixCase, surface) {
  const fallbackTrigger = matrixCase?.trigger || surface?.trigger || null;
  if (Array.isArray(matrixCase?.triggerSequence) && matrixCase.triggerSequence.length > 0) {
    return matrixCase.triggerSequence.filter((trigger) => trigger && typeof trigger === 'object');
  }
  return fallbackTrigger ? [fallbackTrigger] : [];
}

function resolveNavigationPolicy(runtimeConfig = {}) {
  const rawPolicy = runtimeConfig?.navigationPolicy || runtimeConfig?.navigation || {};
  const timeoutMs = Number.isFinite(Number(rawPolicy?.timeoutMs ?? runtimeConfig?.navigationTimeoutMs))
    ? Number(rawPolicy?.timeoutMs ?? runtimeConfig?.navigationTimeoutMs)
    : 30000;
  const maxRetries = Number.isFinite(Number(rawPolicy?.maxRetries ?? runtimeConfig?.navigationMaxRetries))
    ? Number(rawPolicy?.maxRetries ?? runtimeConfig?.navigationMaxRetries)
    : 1;
  const retryableErrorPatterns = Array.isArray(rawPolicy?.retryableErrorPatterns)
    ? rawPolicy.retryableErrorPatterns
    : ['timeout', 'timed out', 'connection reset', 'err_connection_reset', 'ecnnreset', 'net::err_connection_reset', 'net::err_timed_out'];

  return {
    timeoutMs: Math.max(1000, timeoutMs),
    maxRetries: Math.max(0, Math.min(1, Math.round(maxRetries))),
    retryableErrorPatterns: retryableErrorPatterns.filter(Boolean),
  };
}

function isRetryableNavigationError(error, retryableErrorPatterns) {
  const message = String(error?.message || error || '').toLowerCase();
  return retryableErrorPatterns.some((pattern) => message.includes(String(pattern).toLowerCase()));
}

async function navigatePageWithRetry({ page, context, targetUrl, runtimeConfig }) {
  const policy = resolveNavigationPolicy(runtimeConfig);
  const attempts = [];
  let resolvedPage = page;
  let lastError = null;

  for (let attempt = 0; attempt <= policy.maxRetries; attempt += 1) {
    try {
      if (!resolvedPage && context?.newPage) {
        resolvedPage = await context.newPage();
      }
      if (!resolvedPage) {
        throw new Error('No page was available for navigation.');
      }
      await resolvedPage.goto?.(targetUrl, { waitUntil: 'domcontentloaded', timeout: policy.timeoutMs });
      attempts.push({ attempt: attempt + 1, status: 'success', timeoutMs: policy.timeoutMs, retried: attempt > 0 });
      return {
        page: resolvedPage,
        evidence: {
          attempts,
          retried: attempts.some((entry) => entry.retried),
          policy,
        },
      };
    } catch (error) {
      lastError = error;
      const shouldRetry = attempt < policy.maxRetries && isRetryableNavigationError(error, policy.retryableErrorPatterns);
      attempts.push({
        attempt: attempt + 1,
        status: shouldRetry ? 'retry' : 'failed',
        timeoutMs: policy.timeoutMs,
        retried: attempt > 0,
        error: error instanceof Error ? error.message : String(error),
      });

      if (!shouldRetry) {
        throw error;
      }

      if (resolvedPage?.close && typeof resolvedPage.close === 'function') {
        try {
          await resolvedPage.close();
        } catch {
          // Ignore close failures so the retry path can still recover.
        }
      }
      if (context?.newPage) {
        resolvedPage = await context.newPage();
      }
    }
  }

  throw lastError || new Error('Navigation failed without an error payload.');
}

async function preparePageLifecycle({
  page,
  pageFactory,
  matrixCase,
  runtimeConfig,
  targetUrl,
  surface,
  state,
  browser,
  context,
  triggerAfterDriverStart = false,
}) {
  let resolvedPage = page;
  if (!resolvedPage && typeof pageFactory === 'function') {
    resolvedPage = await pageFactory({
      matrixCase,
      runtimeConfig,
      surface,
      state,
      targetUrl,
      browser,
      context,
    });
  }

  if (!resolvedPage) {
    return { page: null, targetUrl: targetUrl || resolveTargetUrl(runtimeConfig?.baseUrl, surface) || 'http://127.0.0.1:3000' };
  }

  const resolvedTargetUrl = targetUrl || resolveTargetUrl(runtimeConfig?.baseUrl, surface) || 'http://127.0.0.1:3000';
  const navigation = await navigatePageWithRetry({
    page: resolvedPage,
    context,
    targetUrl: resolvedTargetUrl,
    runtimeConfig,
  });
  resolvedPage = navigation.page;
  const maximizeResult = await maximizeBrowserWindow({ browser, context, page: resolvedPage });
  await applyStateEmulation(resolvedPage, state || matrixCase?.state || 'default');
  const cssViewport = typeof resolvedPage?.viewportSize === 'function' ? resolvedPage.viewportSize() : null;
  const triggerSequence = resolveTriggerSequence(matrixCase, surface);
  if (triggerSequence.length > 0 && !triggerAfterDriverStart) {
    for (const trigger of triggerSequence) {
      await applyTrigger(resolvedPage, trigger, { strict: true });
    }
  }
  return {
    page: resolvedPage,
    targetUrl: resolvedTargetUrl,
    maximizeWindow: maximizeResult,
    viewport: cssViewport,
    navigation: navigation.evidence,
  };
}

function buildCapability(driver, { driverName, at, platform, synthetic, reason }) {
  const driverReason = driver?.reason || (Array.isArray(driver?.errors) && driver.errors.length > 0 ? driver.errors[0] : null) || reason || null;
  return {
    driver: driver?.driver || driverName,
    at,
    platform,
    supported: Boolean(driver?.supported),
    status: driver?.status || (driver?.supported ? 'ready' : 'unsupported-driver'),
    reason: driverReason,
    synthetic: Boolean(driver?.synthetic || synthetic),
  };
}

function buildResultPayload({
  caseId,
  mappingId,
  driverName,
  at,
  platform,
  capability,
  startedAt,
  completedAt,
  commandsExecuted,
  capturedPhrases,
  assertionResults,
  status,
  targetUrl,
  sourceMatrixRef,
  sourceMatrixMetadata,
  ariaAtReferences,
  variantId,
  variantAt,
  variantPlatform,
  evidence,
  cleanup,
}) {
  const mergedCleanup = cleanup || {
    driverStarted: false,
    driverStopped: false,
    browserClosed: false,
    contextClosed: false,
    browserOwned: false,
    contextOwned: false,
  };
  return {
    caseId,
    mappingId,
    driver: capability?.driver || driverName,
    at: variantAt || at || null,
    platform,
    variantId: variantId || null,
    variantAt: variantAt || null,
    variantPlatform: variantPlatform || null,
    capability,
    startedAt,
    completedAt,
    commandsExecuted,
    capturedPhrases,
    assertions: assertionResults,
    status: normalizeStatus(status),
    sourceMatrixRef: sourceMatrixRef || null,
    sourceMatrixMetadata: sourceMatrixMetadata || null,
    ariaAtReferences: Array.isArray(ariaAtReferences) ? ariaAtReferences : [],
    evidence: { ...(evidence || {}), cleanup: mergedCleanup },
    cleanup: mergedCleanup,
  };
}

async function focusDeterministicTarget(page, target) {
  if (!page || typeof page.locator !== 'function') {
    return false;
  }

  const candidates = [];
  if (target && typeof target === 'string') {
    candidates.push(target);
  } else if (target && typeof target === 'object') {
    if (target.selector) {
      candidates.push(target.selector);
    }
    if (target.value) {
      candidates.push(target.value);
    }
    if (target.role) {
      candidates.push(`[role="${target.role}"]`);
    }
  }
  candidates.push('body');

  for (const candidate of candidates) {
    try {
      await page.locator(candidate).focus({ timeout: 500 }).catch(() => undefined);
      return true;
    } catch {
      // Fall through to the next target candidate.
    }
  }

  return false;
}

async function resetDriverState(driver) {
  if (!driver) {
    return { reset: false, baseline: 'none' };
  }

  try {
    await driver.reset?.({ reason: 'fresh-baseline' });
  } catch {
    // The adapter can decide whether to support a dedicated reset path.
  }

  try {
    await driver.clearLog?.();
  } catch {
    // Clear failure is non-fatal for a synthetic execution harness.
  }

  return { reset: true, baseline: 'speech-log-cleared' };
}

async function snapshotBrowserState(page) {
  if (!page || typeof page.evaluate !== 'function') {
    return null;
  }

  return page.evaluate(() => ({
    url: window.location.href,
    title: document.title,
    activeElement: document.activeElement ? document.activeElement.tagName.toLowerCase() : null,
    bodyText: document.body ? document.body.innerText.slice(0, 240) : '',
  })).catch(() => null);
}

function buildCommandSequence(commands) {
  if (!Array.isArray(commands)) {
    return [];
  }

  const ordered = [];
  for (const command of commands) {
    if (!command || typeof command !== 'object') {
      throw new Error('Each command in the ordered sequence must be an object.');
    }
    ordered.push(command);
  }
  return ordered;
}

async function pauseForDuration(page, durationMs) {
  if (!Number.isFinite(Number(durationMs)) || Number(durationMs) <= 0) {
    return;
  }

  await new Promise((resolve) => setTimeout(resolve, Number(durationMs)));
}

function resolvePostCommandSettleMs({ matrixCase, runtimeConfig, capability } = {}) {
  const defaultDurationMs = capability?.synthetic ? 0 : 4000;
  const candidates = [
    matrixCase?.postCommandSettleMs,
    runtimeConfig?.calibration?.defaults?.postCommandSettleMs,
    runtimeConfig?.postCommandSettleMs,
  ];

  for (const [index, candidate] of candidates.entries()) {
    if (candidate === null || candidate === undefined || candidate === '' || typeof candidate === 'boolean' || typeof candidate === 'object') {
      continue;
    }

    const numericCandidate = Number(candidate);
    if (!Number.isFinite(numericCandidate) || numericCandidate < 0) {
      continue;
    }

    const clampedCandidate = Math.min(30000, Math.max(0, numericCandidate));
    const source = index === 0 ? 'case' : index === 1 ? 'calibration-default' : 'runtime-config';
    return { durationMs: clampedCandidate, source };
  }

  return {
    durationMs: defaultDurationMs,
    source: capability?.synthetic ? 'synthetic' : 'default',
  };
}

function resolveCaptureMode({ matrixCase, runtimeConfig } = {}) {
  const candidates = [
    matrixCase?.captureMode,
    runtimeConfig?.calibration?.defaults?.captureMode,
    runtimeConfig?.captureMode,
  ];

  for (const [index, candidate] of candidates.entries()) {
    if (candidate === 'single' || candidate === 'clear-and-capture') {
      const source = index === 0 ? 'case' : index === 1 ? 'calibration-default' : 'runtime-config';
      return { captureMode: candidate, source };
    }
  }

  return { captureMode: 'single', source: 'default' };
}

function throwIfWindowBindingUnbound(windowBinding, stage) {
  if (windowBinding?.status === 'unbound') {
    const bindingReason = [
      stage === 'pre-command'
        ? 'Automation window is not focused; the screen reader would read a different window.'
        : 'Automation window lost focus before speech capture; the transcript would not belong to the surface under test.',
      `Expected identity: ${JSON.stringify(windowBinding.expectedIdentity || {})}`,
      `Foreground identity: ${JSON.stringify(windowBinding.foregroundIdentity || {})}`,
      `Reason: ${windowBinding.reason || 'foreground-window-does-not-match-page-under-test'}`,
    ].join(' ');
    throw new Error(bindingReason);
  }
}

async function waitForSelector(page, selector, timeoutMs) {
  if (!selector || typeof selector !== 'string' || selector.trim().length === 0) {
    return;
  }
  if (!page || typeof page.waitForSelector !== 'function') {
    return;
  }

  const timeout = Number.isFinite(Number(timeoutMs)) && Number(timeoutMs) > 0
    ? Number(timeoutMs)
    : 1000;

  await page.waitForSelector(selector, { state: 'visible', timeout }).catch(() => undefined);
}

async function resolveBrowserVersion(browser) {
  if (!browser) {
    return null;
  }
  if (typeof browser.version === 'function') {
    try {
      return await browser.version();
    } catch {
      return browser.version || null;
    }
  }
  return browser.version || null;
}

async function buildProvenance({ capability, driver, runtimeConfig, browser, platform, variant, matrixCase, targetUrl, maximizeWindow, cssViewport }) {
  const locale = String(
    runtimeConfig?.locale
    || process.env.LC_ALL
    || process.env.LANG
    || process.env.LC_MESSAGES
    || 'en-US',
  ).replace(/_/g, '-').split(',')[0] || 'en-US';
  const approvedProfile = runtimeConfig?.approvedProfile || runtimeConfig?.profileFingerprint || {
    locale,
    verbosity: 'default',
    punctuation: 'preserve',
    speechMode: 'default',
    addOnPosture: 'default',
  };
  const profileFingerprint = {
    locale,
    verbosity: approvedProfile?.verbosity || 'default',
    punctuation: approvedProfile?.punctuation || 'preserve',
    speechMode: approvedProfile?.speechMode || 'default',
    addOnPosture: approvedProfile?.addOnPosture || 'default',
  };
  const browserVersion = await resolveBrowserVersion(browser);

  return {
    at: variant?.at || matrixCase?.at || null,
    driver: capability?.driver || driver?.driver || null,
    driverStatus: capability?.status || driver?.status || null,
    nvdaVersion: driver?.metadata?.nvdaVersion || driver?.nvdaVersion || null,
    guidepupVersion: driver?.metadata?.guidepupVersion || driver?.guidepupVersion || null,
    guidepupCapabilities: Array.isArray(driver?.metadata?.guidepupCapabilities) ? driver.metadata.guidepupCapabilities : [],
    chromeVersion: browserVersion || null,
    browserVersion: browserVersion || null,
    os: platform || process.platform || null,
    locale,
    profileFingerprint,
    approvedProfile,
    targetUrl: targetUrl || null,
    maximizeWindow: maximizeWindow || null,
    cssViewport: cssViewport || null,
    synthetic: Boolean(capability?.synthetic),
    realAtPassAllowed: Boolean(capability?.supported && !capability?.synthetic),
  };
}

function collectProvenanceWarnings({ rawPhrases = [], profileFingerprint = {} } = {}) {
  const warnings = [];
  const phrases = Array.isArray(rawPhrases) ? rawPhrases.filter((phrase) => typeof phrase === 'string' && phrase.trim() !== '') : [];
  const connectionChatter = phrases.filter((phrase) => /connected as|controlled computer|remote add|remote desktop|remote access|remote mode|add-on|add on/i.test(phrase));
  const isolationClaimed = ['isolated', 'true'].includes(String(profileFingerprint?.isolation || '').toLowerCase())
    || ['isolated', 'true'].includes(String(profileFingerprint?.addOnPosture || '').toLowerCase());

  if (connectionChatter.length > 0 && isolationClaimed) {
    const preview = connectionChatter.slice(0, 3).join(' | ');
    warnings.push(`Captured speech includes connection chatter (${preview}), so the isolation posture was not verified.`);
  }

  return warnings;
}

export async function processAtPlanCase({
  matrixCase,
  runtimeConfig,
  driverName = 'guidepup',
  platform = process.platform,
  driverFactory,
  page,
  browser,
  context,
  targetUrl,
  surface,
  state,
  pageFactory,
  browserFactory,
  ensureWindowBinding = ensureAutomationWindowFocused,
  verifyScreenReaderStopped = ensureScreenReaderStopped,
}) {
  const startTime = new Date().toISOString();
  const commandsExecuted = [];
  const capturedPhrases = [];
  const assertionResults = [];
  const variant = selectVariant(matrixCase);
  const commands = resolveCommands(matrixCase, variant);
  const assertions = resolveAssertions(matrixCase, variant);
  const sourceMatrixRef = matrixCase?.sourceMatrixRef || matrixCase?.sourceMatrixPath || null;
  const sourceMatrixMetadata = matrixCase?.sourceMatrixMetadata || null;
  const ariaAtReferences = Array.isArray(matrixCase?.ariaAtReferences) ? matrixCase.ariaAtReferences : [];
  const normalizedPlatform = normalizePlatform(platform);
  const resolvedState = state || matrixCase?.state || 'default';
  const resolvedSurface = surface || matrixCase?.surface || null;
  const resolvedTargetUrl = targetUrl || matrixCase?.targetUrl || null;
  const effectiveDriverName = String(process.env.RUNTIME_A11Y_DRIVER_NAME || driverName || 'guidepup').toLowerCase();
  const triggerAfterDriverStart = Boolean(matrixCase?.triggerAfterDriverStart || runtimeConfig?.triggerAfterDriverStart);

  let resolvedBrowser = browser;
  let resolvedContext = context;
  let resolvedPage = page;
  let resolvedTarget = resolvedTargetUrl
    || resolveTargetUrl(runtimeConfig?.baseUrl, resolvedSurface)
    || 'http://127.0.0.1:3000';
  let driver = null;
  let capability = null;
  let pageLifecycle = { page: null, targetUrl: resolvedTarget };
  let ownsBrowser = false;
  let ownsContext = false;
  let driverStarted = false;
  let windowBinding = null;
  const ensureWindowBindingImpl = ensureWindowBinding;
  let driverStopped = false;
  let speechLogClearedBeforeSettle = false;
  let cleanupState = {
    driverStarted: false,
    driverStopped: false,
    browserClosed: false,
    contextClosed: false,
    browserOwned: false,
    contextOwned: false,
  };

  try {
    const driverInput = {
      platform: normalizedPlatform,
      driverName: effectiveDriverName,
      config: {
        ...(matrixCase?.runtimeConfig || runtimeConfig || {}),
        commands,
        expectedAnnouncements: assertions,
      },
      matrixCase,
      variant,
    };
    driver = await (driverFactory?.(driverInput) ?? createScreenReaderDriver(driverInput));
    capability = buildCapability(driver, {
      driverName,
      at: variant?.at || matrixCase?.at || null,
      platform: normalizedPlatform,
      synthetic: Boolean(driver?.synthetic),
      reason: driver?.reason || null,
    });

    if (!driver?.supported) {
      const isAdapterFailure = ['adapter-error', 'start-error', 'invalid-config'].includes(String(driver?.status || '').toLowerCase());
      return buildResultPayload({
        caseId: matrixCase?.caseId || null,
        mappingId: matrixCase?.mappingId || null,
        driverName,
        at: matrixCase?.at || null,
        platform: normalizedPlatform,
        capability,
        startedAt: startTime,
        completedAt: new Date().toISOString(),
        commandsExecuted,
        capturedPhrases,
        assertionResults,
        status: isAdapterFailure ? 'error' : 'unsupported',
        targetUrl: resolvedTarget,
        sourceMatrixRef,
        sourceMatrixMetadata,
        ariaAtReferences,
        variantId: variant?.id || null,
        variantAt: variant?.at || null,
        variantPlatform: variant?.platform || null,
        evidence: {
          synthetic: Boolean(capability.synthetic),
          reason: capability.reason || (isAdapterFailure ? 'Driver initialization failed.' : 'unsupported'),
          error: isAdapterFailure ? (capability.reason || driver?.errors?.[0] || 'Driver initialization failed.') : null,
          targetUrl: resolvedTarget,
        },
      });
    }

    if (variant?.at && !capability.synthetic && !isCompatiblePlatform(normalizedPlatform, variant.at)) {
      return buildResultPayload({
        caseId: matrixCase?.caseId || null,
        mappingId: matrixCase?.mappingId || null,
        driverName,
        at: matrixCase?.at || null,
        platform: normalizedPlatform,
        capability,
        startedAt: startTime,
        completedAt: new Date().toISOString(),
        commandsExecuted,
        capturedPhrases,
        assertionResults,
        status: 'unsupported',
        targetUrl: resolvedTarget,
        sourceMatrixRef,
        sourceMatrixMetadata,
        ariaAtReferences,
        variantId: variant?.id || null,
        variantAt: variant?.at || null,
        variantPlatform: variant?.platform || null,
        evidence: {
          synthetic: Boolean(capability.synthetic),
          reason: `The selected variant requires ${variant.at} on a compatible Windows platform.`,
          targetUrl: resolvedTarget,
        },
      });
    }

    if (commands.length === 0 || assertions.length === 0) {
      return buildResultPayload({
        caseId: matrixCase?.caseId || null,
        mappingId: matrixCase?.mappingId || null,
        driverName,
        at: matrixCase?.at || null,
        platform: normalizedPlatform,
        capability,
        startedAt: startTime,
        completedAt: new Date().toISOString(),
        commandsExecuted,
        capturedPhrases,
        assertionResults,
        status: 'candidate',
        targetUrl: resolvedTarget,
        sourceMatrixRef,
        sourceMatrixMetadata,
        ariaAtReferences,
        variantId: variant?.id || null,
        variantAt: variant?.at || null,
        variantPlatform: variant?.platform || null,
        evidence: {
          synthetic: Boolean(capability.synthetic),
          reason: 'No executable commands or assertions were supplied.',
          targetUrl: resolvedTarget,
        },
      });
    }

    const shouldPreparePage = !capability.synthetic
      || Boolean(resolvedPage)
      || typeof pageFactory === 'function';
    const settleResolution = resolvePostCommandSettleMs({ matrixCase, runtimeConfig, capability });
    const captureModeResolution = resolveCaptureMode({ matrixCase, runtimeConfig });

    if (shouldPreparePage) {
      if (
        !capability.synthetic
        && !resolvedBrowser
        && !resolvedPage
        && typeof pageFactory !== 'function'
        && typeof browserFactory === 'function'
      ) {
        resolvedBrowser = await browserFactory({
          matrixCase,
          runtimeConfig,
          surface: resolvedSurface,
          state: resolvedState,
          targetUrl: resolvedTarget,
        });
        ownsBrowser = true;
      }
      if (
        !capability.synthetic
        && !resolvedBrowser
        && !resolvedPage
        && typeof pageFactory !== 'function'
      ) {
        resolvedBrowser = await launchChrome({ headless: false });
        ownsBrowser = true;
      }
      if (!capability.synthetic && !resolvedBrowser && !resolvedPage && !pageFactory) {
        throw new Error('A browser instance was not available for real execution.');
      }
      if (!resolvedContext && resolvedBrowser && !resolvedPage) {
        resolvedContext = await resolvedBrowser.newContext({ viewport: { width: 1280, height: 900 } });
        ownsContext = true;
      }
      if (!resolvedPage && resolvedContext) {
        resolvedPage = await resolvedContext.newPage();
      }
      pageLifecycle = await preparePageLifecycle({
        page: resolvedPage,
        pageFactory,
        matrixCase,
        runtimeConfig,
        targetUrl: resolvedTarget,
        surface: resolvedSurface,
        state: resolvedState,
        browser: resolvedBrowser,
        context: resolvedContext,
        triggerAfterDriverStart,
      });
      resolvedPage = pageLifecycle.page;
      resolvedTarget = pageLifecycle.targetUrl;
    }

    await driver.start();
    driverStarted = true;
    cleanupState.driverStarted = true;
    cleanupState.browserOwned = ownsBrowser;
    cleanupState.contextOwned = ownsContext;
    const baseline = await resetDriverState(driver);
    await focusDeterministicTarget(resolvedPage, resolvedSurface?.target || matrixCase?.target || null);

    // A screen reader narrates the OS foreground window, which is not
    // necessarily the window the automation drives. Verify the two agree before
    // any keystroke is synthesized, and fail closed otherwise: an unbound window
    // means keystrokes could land in an unrelated application and captured
    // speech could describe a surface that is not under test.
    if (!capability.synthetic) {
      windowBinding = await ensureWindowBindingImpl({
        page: resolvedPage,
        browser: resolvedBrowser,
        context: resolvedContext,
      });
      throwIfWindowBindingUnbound(windowBinding, 'pre-command');
    }

    if (resolvedPage && triggerAfterDriverStart) {
      const triggerSequence = resolveTriggerSequence(matrixCase, resolvedSurface);
      for (const trigger of triggerSequence) {
        await applyTrigger(resolvedPage, trigger, { strict: true });
      }
    }

    const orderedCommands = buildCommandSequence(commands);
    for (const command of orderedCommands) {
      const normalizedCommand = command.kind === 'mode'
        ? { ...command, kind: 'perform', value: 'toggleBetweenBrowseAndFocusMode' }
        : command;
      commandsExecuted.push({ ...normalizedCommand, executed: true });
      if (normalizedCommand.kind === 'pause') {
        await driver.executeCommand(normalizedCommand);
        await pauseForDuration(resolvedPage, normalizedCommand.durationMs);
        continue;
      }
      if (normalizedCommand.kind === 'waitFor') {
        await waitForSelector(resolvedPage, normalizedCommand.value || normalizedCommand.target || null, normalizedCommand.durationMs);
        continue;
      }
      await driver.executeCommand(normalizedCommand);
    }

    if (!capability.synthetic) {
      windowBinding = await ensureWindowBindingImpl({
        page: resolvedPage,
        browser: resolvedBrowser,
        context: resolvedContext,
      });
      throwIfWindowBindingUnbound(windowBinding, 'post-command');
    }

    if (captureModeResolution.captureMode === 'clear-and-capture' && !capability.synthetic && typeof driver.clearLog === 'function') {
      try {
        await driver.clearLog();
        speechLogClearedBeforeSettle = true;
      } catch {
        speechLogClearedBeforeSettle = false;
      }
    }

    // Speech arrives asynchronously after the final command. Wait for the
    // configured settle window so the transcript spans the announcement, then
    // re-verify binding: focus can be stolen during a multi-second wait, and a
    // transcript captured afterward would not belong to the surface under test.
    if (!capability.synthetic && settleResolution.durationMs > 0) {
      await pauseForDuration(resolvedPage, settleResolution.durationMs);
      windowBinding = await ensureWindowBindingImpl({
        page: resolvedPage,
        browser: resolvedBrowser,
        context: resolvedContext,
      });
      throwIfWindowBindingUnbound(windowBinding, 'post-settle');
    }

    const captureTimestamp = new Date().toISOString();
    const capture = await driver.captureLog();
    const rawPhrases = Array.isArray(capture?.phrases) ? capture.phrases : [];
    const normalizationOptions = runtimeConfig?.speechNormalization || matrixCase?.speechNormalization || { punctuationMode: 'preserve', dedupeAdjacentPhrases: true };
    const normalizedPhrases = normalizeSpokenOutput(rawPhrases, normalizationOptions);
    if (rawPhrases.length > 0) {
      capturedPhrases.push(...rawPhrases);
    }

    const browserState = await snapshotBrowserState(resolvedPage);
    const accessibilityTree = resolvedPage ? await snapshotAccessibilityTree(resolvedPage) : null;
    const provenance = await buildProvenance({
      capability,
      driver,
      runtimeConfig,
      browser: resolvedBrowser,
      platform: normalizedPlatform,
      variant,
      matrixCase,
      targetUrl: resolvedTarget,
      maximizeWindow: pageLifecycle.maximizeWindow || null,
      cssViewport: pageLifecycle.viewport || null,
    });
    if (windowBinding) {
      provenance.windowBinding = windowBinding;
    }
    provenance.postCommandSettleMsApplied = settleResolution.durationMs;
    provenance.captureTimestamp = captureTimestamp;
    provenance.settleSource = settleResolution.source;
    provenance.captureModeApplied = captureModeResolution.captureMode;
    provenance.captureModeSource = captureModeResolution.source;
    provenance.speechLogClearedBeforeSettle = speechLogClearedBeforeSettle;
    const provenanceWarnings = collectProvenanceWarnings({ rawPhrases, profileFingerprint: provenance?.profileFingerprint || {} });
    if (provenanceWarnings.length > 0) {
      provenance.warnings = provenanceWarnings;
    }
    const checkpoints = [
      { order: 0, evidenceType: 'commands', value: commandsExecuted.slice() },
      { order: 1, evidenceType: 'spokenPhrases', value: rawPhrases.slice() },
      { order: 2, evidenceType: 'normalizedPhrases', value: normalizedPhrases.slice() },
      { order: 3, evidenceType: 'browserState', value: browserState },
      { order: 4, evidenceType: 'accessibilityTree', value: accessibilityTree },
    ];
    const assertionEvidence = {
      speech: rawPhrases,
      normalizedSpeech: normalizedPhrases,
      browserState,
      accessibilityTree,
    };

    for (const assertion of assertions) {
      const evaluated = evaluateAssertion(assertion, assertionEvidence, normalizationOptions);
      assertionResults.push({
        id: assertion?.id || 'assertion',
        type: assertion?.type,
        value: assertion?.value,
        evidenceType: assertion?.evidenceType || 'speech',
        attributedEvidence: {
          assertionValue: assertion?.value,
          normalizedAssertionValue: evaluated.normalizedValue || null,
          rawPhrases: rawPhrases.slice(),
          normalizedPhrases: normalizedPhrases.slice(),
        },
        ...evaluated,
      });
    }

    const hasFailures = assertionResults.some((item) => item.status === 'fail');
    const hasInvalidConfig = assertionResults.some((item) => item.status === 'invalid-config');
    const passed = assertionResults.length > 0 && assertionResults.every((item) => item.status === 'pass');
    let status = 'candidate';
    if (hasFailures) {
      status = 'fail';
    } else if (hasInvalidConfig) {
      status = 'candidate';
    } else if (passed) {
      status = capability.synthetic ? 'candidate' : 'pass';
    }

    const invalidConfigReason = assertionResults.find((item) => item.status === 'invalid-config')?.detail || null;

    return buildResultPayload({
      caseId: matrixCase?.caseId || null,
      mappingId: matrixCase?.mappingId || null,
      driverName,
      at: matrixCase?.at || null,
      platform: normalizedPlatform,
      capability,
      startedAt: startTime,
      completedAt: new Date().toISOString(),
      commandsExecuted,
      capturedPhrases,
      assertionResults,
      status,
      targetUrl: resolvedTarget,
      sourceMatrixRef,
      sourceMatrixMetadata,
      ariaAtReferences,
      variantId: variant?.id || null,
      variantAt: variant?.at || null,
      variantPlatform: variant?.platform || null,
      evidence: {
        synthetic: Boolean(capability.synthetic),
        invalidConfig: hasInvalidConfig,
        reason: invalidConfigReason || (capability.synthetic ? 'Synthetic execution produced a non-pass result.' : null),
        rawPhrases: rawPhrases.slice(),
        normalizedPhrases: normalizedPhrases.slice(),
        phrases: capturedPhrases,
        assertions: assertionResults,
        commandSequence: commandsExecuted.slice(),
        browserState,
        accessibilityTree,
        targetUrl: resolvedTarget,
        checkpoints,
        baseline,
        provenance,
        provenanceWarnings,
        windowBinding,
        maximizeWindow: pageLifecycle.maximizeWindow || null,
        cssViewport: pageLifecycle.viewport || null,
        navigation: pageLifecycle.navigation || null,
        realAtPass: Boolean(!capability.synthetic && capability.supported && status === 'pass'),
      },
      cleanup: cleanupState,
    });
  } catch (error) {
    return buildResultPayload({
      caseId: matrixCase?.caseId || null,
      mappingId: matrixCase?.mappingId || null,
      driverName,
      at: matrixCase?.at || null,
      platform: normalizedPlatform,
      capability,
      startedAt: startTime,
      completedAt: new Date().toISOString(),
      commandsExecuted,
      capturedPhrases,
      assertionResults,
      status: 'error',
      targetUrl: resolvedTarget,
      sourceMatrixRef,
      sourceMatrixMetadata,
      ariaAtReferences,
      variantId: variant?.id || null,
      variantAt: variant?.at || null,
      variantPlatform: variant?.platform || null,
      evidence: {
        synthetic: Boolean(capability?.synthetic),
        error: error instanceof Error ? error.message : String(error),
        targetUrl: resolvedTarget,
        windowBinding,
        checkpoints: [],
        baseline: { reset: false, baseline: 'none' },
        navigation: null,
      },
      cleanup: cleanupState,
    });
  } finally {
    if (driverStarted) {
      try {
        await driver?.stop?.();
      } catch {
        // A failed stop request still requires the verification below; the
        // screen reader may have exited anyway, and may need terminating if not.
      }
      // The driver's stop request is asynchronous and unverified, so cleanup is
      // only recorded as complete once the screen reader is observably gone.
      const screenReaderStop = await verifyScreenReaderStopped().catch(() => null);
      driverStopped = screenReaderStop?.stopped === true;
      cleanupState.driverStopped = driverStopped;
    }
    if (ownsContext && resolvedContext) {
      try {
        await resolvedContext.close?.();
        cleanupState.contextClosed = true;
      } catch {
        cleanupState.contextClosed = false;
      }
    }
    if (ownsBrowser && resolvedBrowser) {
      try {
        await resolvedBrowser.close?.();
        cleanupState.browserClosed = true;
      } catch {
        cleanupState.browserClosed = false;
      }
    }
    cleanupState.browserOwned = ownsBrowser;
    cleanupState.contextOwned = ownsContext;
    cleanupState.driverStarted = driverStarted;
    cleanupState.driverStopped = driverStopped;
  }
}

export async function executeAtPlanCase(args) {
  return processAtPlanCase(args);
}

export async function runAtPlanCase({
  page,
  browser,
  context,
  matrixCase,
  runtimeConfig,
  driverName = 'guidepup',
  platform = process.platform,
  driverFactory,
  pageFactory,
  browserFactory,
  ensureWindowBinding,
  verifyScreenReaderStopped,
}) {
  const state = matrixCase?.state || 'default';
  const surface = matrixCase?.surface || null;
  const targetUrl = matrixCase?.targetUrl || runtimeConfig?.baseUrl || 'http://127.0.0.1:3000';

  return executeAtPlanCase({
    matrixCase,
    runtimeConfig,
    driverName,
    platform,
    driverFactory,
    page,
    browser,
    context,
    targetUrl,
    surface,
    state,
    pageFactory,
    browserFactory,
    ensureWindowBinding,
    verifyScreenReaderStopped,
  });
}

async function main() {
  let raw = '';
  try {
    raw = readFileSync(0, 'utf8').trim();
  } catch {
    raw = '';
  }

  if (!raw) {
    process.stdout.write(JSON.stringify({ status: 'error', evidence: { error: 'No input payload received.' } }, null, 2));
    return;
  }

  const parsed = JSON.parse(raw);
  const result = await runAtPlanCase({
    matrixCase: parsed,
    runtimeConfig: parsed.runtimeConfig || {},
    driverName: process.env.RUNTIME_A11Y_DRIVER_NAME || 'guidepup',
  });
  process.stdout.write(JSON.stringify(result, null, 2));
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main().catch((error) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}
