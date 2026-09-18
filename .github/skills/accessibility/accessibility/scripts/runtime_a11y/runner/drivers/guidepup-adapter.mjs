// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { ALLOWLISTED_NAVIGATE_VALUES, ALLOWLISTED_PERFORM_VALUES, validateScreenReaderCommand } from './command-contract.mjs';

const DRIVER_DIR = path.dirname(fileURLToPath(import.meta.url));
const GUIDEPUP_MODULE = path.resolve(DRIVER_DIR, '../../node_modules/@guidepup/guidepup');
const RUNTIME_PACKAGE_PATH = path.resolve(DRIVER_DIR, '../../package.json');
const PROFILE_ID = 'guidepup-nvda-isolated-v1';
const APPROVED_NVDA_SETTINGS = Object.freeze({
  general: {
    language: 'Windows',
    saveConfigurationOnExit: false,
  },
  presentation: {
    reportDynamicContentChanges: true,
  },
  virtualBuffers: {
    autoSayAllOnPageLoad: false,
  },
  vision: {
    NVDAHighlighter: {
      enabled: false,
      highlightFocus: false,
      highlightNavigator: false,
      highlightBrowseMode: false,
    },
  },
});

function normalizePlatform(platform) {
  return String(platform || '').toLowerCase();
}

function selectDriver(platform) {
  const normalized = normalizePlatform(platform);
  if (normalized === 'win32' || normalized === 'windows') {
    return 'nvda';
  }
  return null;
}

function readGuidepupLibraryVersion() {
  try {
    return JSON.parse(readFileSync(RUNTIME_PACKAGE_PATH, 'utf8'))?.optionalDependencies?.['@guidepup/guidepup'] || null;
  } catch {
    return null;
  }
}

function projectEffectiveSettings(settings = {}) {
  return {
    general: {
      language: settings?.general?.language ?? null,
      saveConfigurationOnExit: settings?.general?.saveConfigurationOnExit ?? null,
    },
    presentation: {
      reportDynamicContentChanges: settings?.presentation?.reportDynamicContentChanges ?? null,
    },
    virtualBuffers: {
      autoSayAllOnPageLoad: settings?.virtualBuffers?.autoSayAllOnPageLoad ?? null,
    },
    vision: {
      highlighterEnabled: settings?.vision?.NVDAHighlighter?.enabled ?? null,
    },
  };
}

function buildProfileFingerprint(settings) {
  const effectiveSettings = projectEffectiveSettings(settings);
  const digest = createHash('sha256').update(JSON.stringify(effectiveSettings)).digest('hex');
  return {
    profileId: PROFILE_ID,
    digest,
    effectiveSettings,
  };
}

function buildMetadata(target, platform) {
  const guidepupLibraryVersion = readGuidepupLibraryVersion();
  const nvdaAssetVersion = target?.version || null;

  return {
    driver: 'nvda',
    platform,
    nvdaVersion: nvdaAssetVersion,
    guidepupVersion: guidepupLibraryVersion,
    nvdaAssetVersion,
    guidepupLibraryVersion,
    guidepupCapabilities: [
      'nvda',
      ...(typeof target?.capture === 'function' ? ['action-capture'] : []),
      ...(ALLOWLISTED_NAVIGATE_VALUES.size > 0 ? ['semantic-navigation'] : []),
      ...(typeof target?.getSettings === 'function' ? ['isolated-settings'] : []),
    ],
    profileFingerprint: null,
  };
}

function resolvePositiveInteger(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.round(parsed);
}

function resolveNonNegativeInteger(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return Math.round(parsed);
}

async function runWithTimeout(operation, timeoutMs, label) {
  const timeout = resolveNonNegativeInteger(timeoutMs, 0);
  if (timeout <= 0) {
    return operation();
  }

  let timer = null;
  try {
    return await Promise.race([
      operation(),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          reject(new Error(`${label} timed out after ${timeout}ms`));
        }, timeout);
      }),
    ]);
  } finally {
    if (timer) {
      clearTimeout(timer);
    }
  }
}

export async function createGuidepupDriverAdapter({
  platform = process.platform,
  config = {},
  target = null,
  sleep = (durationMs) => new Promise((resolve) => setTimeout(resolve, durationMs)),
} = {}) {
  const driver = selectDriver(platform);
  if (!driver) {
    return {
      supported: false,
      status: 'unsupported-platform',
      reason: `Guidepup real screen-reader support is only available on Windows for NVDA. Received platform ${platform}.`,
    };
  }

  try {
    let runtimeTarget = target;
    if (!runtimeTarget) {
      if (!existsSync(GUIDEPUP_MODULE)) {
        return {
          supported: false,
          status: 'unavailable-driver',
          reason: 'Guidepup dependency is not installed in the skill-local runtime_a11y package.',
        };
      }
      const mod = await import('@guidepup/guidepup');
      runtimeTarget = mod.nvda;
    }

    if (!runtimeTarget || typeof runtimeTarget.start !== 'function' || typeof runtimeTarget.stop !== 'function') {
      throw new Error('Guidepup NVDA driver is unavailable.');
    }

    const commands = Array.isArray(config?.commands) ? config.commands : [];
    const expectedAnnouncements = Array.isArray(config?.expectedAnnouncements)
      ? config.expectedAnnouncements
      : [];
    const metadata = buildMetadata(runtimeTarget, platform);
    const lifecycle = config?.lifecycle || {};
    const startAttempts = resolvePositiveInteger(lifecycle.startAttempts, 2);
    const startRetryDelayMs = resolveNonNegativeInteger(lifecycle.startRetryDelayMs, 2000);
    const startTimeoutMs = resolvePositiveInteger(lifecycle.startTimeoutMs, 30000);
    const stopTimeoutMs = resolvePositiveInteger(lifecycle.stopTimeoutMs, 10000);
    const stopSettleDelayMs = resolveNonNegativeInteger(lifecycle.stopSettleDelayMs, 1200);
    let startedByAdapter = false;
    let started = false;

    return {
      supported: true,
      status: 'ready',
      driver,
      platform,
      metadata,
      async start() {
        if (startedByAdapter || started) {
          return { driver, platform };
        }
        let lastError = null;
        for (let attempt = 1; attempt <= startAttempts; attempt += 1) {
          try {
            await runWithTimeout(
              () => runtimeTarget.start({ capture: true, settings: APPROVED_NVDA_SETTINGS }),
              startTimeoutMs,
              'Guidepup NVDA startup',
            );
            if (typeof runtimeTarget.getSettings !== 'function') {
              throw new Error('Guidepup NVDA target does not expose effective settings.');
            }
            metadata.profileFingerprint = buildProfileFingerprint(runtimeTarget.getSettings());
            startedByAdapter = true;
            started = true;
            return { driver, platform };
          } catch (error) {
            lastError = error;
            try {
              await runWithTimeout(
                () => runtimeTarget.stop(),
                stopTimeoutMs,
                'Guidepup NVDA stop after failed startup',
              );
            } catch {
              // Best effort cleanup before retrying startup.
            }
            if (attempt < startAttempts && startRetryDelayMs > 0) {
              await sleep(startRetryDelayMs);
            }
          }
        }
        throw lastError instanceof Error
          ? lastError
          : new Error(lastError ? String(lastError) : 'Guidepup NVDA startup failed.');
      },
      // Ownership flags describe what the adapter has observed, so they survive
      // a stop that rejects or times out. Clearing them early would report a
      // clean exit for a screen reader that is still running and would make a
      // retried stop return without calling through.
      async stop() {
        if (!startedByAdapter && !started) {
          return { driver, platform, cleanup: { startedByAdapter, started } };
        }
        if (!startedByAdapter || !started) {
          startedByAdapter = false;
          started = false;
          return { driver, platform, cleanup: { startedByAdapter, started } };
        }
        await runWithTimeout(
          () => runtimeTarget.stop(),
          stopTimeoutMs,
          'Guidepup NVDA stop',
        );
        if (stopSettleDelayMs > 0) {
          await sleep(stopSettleDelayMs);
        }
        startedByAdapter = false;
        started = false;
        return { driver, platform, cleanup: { startedByAdapter, started } };
      },
      cleanupState() {
        return { startedByAdapter, started };
      },
      async executeCommand(command) {
        const validationError = validateScreenReaderCommand(command);
        if (validationError) {
          throw new Error(validationError);
        }
        if (driver !== 'nvda') {
          throw new Error(`Unsupported real screen-reader target: ${driver}`);
        }
        if (command.kind === 'pause') {
          const durationMs = Number(command.durationMs || 0);
          await new Promise((resolve) => setTimeout(resolve, durationMs));
          return { kind: 'pause', durationMs };
        }
        if (command.kind === 'command') {
          const value = String(command.value || '');
          if (value === 'next') {
            await runtimeTarget.next();
          } else if (value === 'previous') {
            await runtimeTarget.previous();
          } else {
            throw new Error(`Unsupported Guidepup command value: ${value}`);
          }
          return { kind: 'command', value };
        }
        if (command.kind === 'navigate') {
          const value = String(command.value || '');
          if (!ALLOWLISTED_NAVIGATE_VALUES.has(value) || typeof runtimeTarget[value] !== 'function') {
            throw new Error(`Unsupported Guidepup navigate value: ${value}`);
          }
          await runtimeTarget[value]({ capture: true });
          return { kind: 'navigate', value };
        }
        if (command.kind === 'keyboard' || command.kind === 'key') {
          const value = String(command.value || '');
          await runtimeTarget.press(value);
          return { kind: 'key', value };
        }
        if (command.kind === 'perform') {
          const value = String(command.value || '');
          const keyboardCommands = runtimeTarget.keyboardCommands || {};
          if (!ALLOWLISTED_PERFORM_VALUES.has(value)) {
            throw new Error(`Unsupported perform value: ${value}`);
          }
          const resolvedCommand = Object.prototype.hasOwnProperty.call(keyboardCommands, value)
            ? keyboardCommands[value]
            : value;
          await runtimeTarget.perform(resolvedCommand);
          return { kind: 'perform', value };
        }
        if (command.kind === 'type') {
          const value = String(command.value || '');
          if (typeof runtimeTarget.type !== 'function') {
            throw new Error('Guidepup NVDA target does not support text entry.');
          }
          await runtimeTarget.type(value);
          return { kind: 'type', value };
        }
        throw new Error(`Unsupported Guidepup command kind: ${command.kind}`);
      },
      async clearLog() {
        if (typeof runtimeTarget.clearSpokenPhraseLog === 'function') {
          await runtimeTarget.clearSpokenPhraseLog();
        }
        return { driver, platform };
      },
      async captureAction(action) {
        if (typeof action !== 'function') {
          throw new Error('Action-scoped capture requires a trusted action callback.');
        }
        if (typeof runtimeTarget.capture !== 'function') {
          throw new Error('Guidepup NVDA target does not support action-scoped capture.');
        }
        return runtimeTarget.capture(action, { capture: true });
      },
      async reset() {
        await this.clearLog();
        return { driver, platform, baseline: 'speech-log-cleared' };
      },
      async captureLog() {
        const phrases = Array.isArray(await runtimeTarget.spokenPhraseLog()) ? await runtimeTarget.spokenPhraseLog() : [];
        const assertions = expectedAnnouncements.map((assertion) => ({
          id: assertion.id || 'announcement',
          type: assertion.type,
          value: assertion.value,
          status: 'pending',
        }));
        return { driver, platform, phrases, assertions, commands };
      },
    };
  } catch (error) {
    return {
      supported: false,
      status: 'adapter-error',
      reason: error instanceof Error ? error.message : String(error),
    };
  }
}
