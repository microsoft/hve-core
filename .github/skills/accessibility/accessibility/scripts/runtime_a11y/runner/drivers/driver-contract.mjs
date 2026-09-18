// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createGuidepupDriverAdapter } from './guidepup-adapter.mjs';
import { validateScreenReaderCommand } from './command-contract.mjs';

const CAPTURE_MODES = new Set(['single', 'clear-and-capture', 'action']);
const ASSERTION_EVIDENCE_TYPES = new Set([
  'speech',
  'normalizedSpeech',
  'browserState',
  'accessibilityTree',
  'actionSpeech',
  'actionNormalizedSpeech',
]);

function createSyntheticDriver({ platform, config = {}, matrixCase = null, variant = null, driverName = 'synthetic' } = {}) {
  const commands = Array.isArray(config?.commands) ? config.commands : [];
  const phrases = Array.isArray(config?.syntheticPhrases)
    ? config.syntheticPhrases.filter((item) => typeof item === 'string' && item.trim() !== '')
    : [];
  return {
    supported: true,
    status: 'ready',
    driver: driverName,
    platform,
    synthetic: true,
    async start() {
      return { driver: 'synthetic', platform };
    },
    async stop() {
      return undefined;
    },
    async executeCommand(command) {
      const validationError = validateScreenReaderCommand(command);
      if (validationError) {
        throw new Error(validationError);
      }
      if (command.kind === 'pause') {
        return { kind: 'pause', durationMs: Number(command.durationMs || 0) };
      }
      if (command.kind === 'command') {
        return { kind: 'command', value: command.value };
      }
      if (command.kind === 'navigate') {
        return { kind: 'navigate', value: command.value };
      }
      if (command.kind === 'keyboard' || command.kind === 'key') {
        return { kind: 'key', value: command.value };
      }
      if (command.kind === 'perform') {
        return { kind: 'perform', value: command.value };
      }
      if (command.kind === 'type') {
        return { kind: 'type', value: command.value };
      }
      throw new Error(`Unsupported synthetic-driver command kind: ${command.kind}`);
    },
    async captureLog() {
      return {
        driver: 'synthetic',
        platform,
        phrases: phrases.slice(),
        assertions: [],
        commands,
        synthetic: true,
        evidenceKind: 'synthetic',
      };
    },
    async captureAction() {
      throw new Error('Action-scoped capture is unavailable for synthetic screen-reader drivers.');
    },
  };
}

export function validateScreenReaderConfig(config = {}) {
  const errors = [];
  const commands = Array.isArray(config?.commands) ? config.commands : [];
  const expectedAnnouncements = Array.isArray(config?.expectedAnnouncements)
    ? config.expectedAnnouncements
    : [];

  if (config?.captureMode !== undefined && !CAPTURE_MODES.has(config.captureMode)) {
    errors.push(`Unsupported capture mode: ${config.captureMode}`);
  }
  if (config?.captureMode === 'action') {
    if (config?.triggerAfterDriverStart !== true) {
      errors.push('Action capture requires triggerAfterDriverStart to be true.');
    }
    if (config?.hasActionTrigger !== true) {
      errors.push('Action capture requires at least one declarative trigger.');
    }
  }

  for (const command of commands) {
    const validationError = validateScreenReaderCommand(command);
    if (validationError) {
      errors.push(validationError);
    }
  }

  for (const assertion of expectedAnnouncements) {
    if (!assertion || typeof assertion !== 'object') {
      errors.push('Each expected announcement must be an object.');
      continue;
    }
    if (!['contains', 'matches', 'orderedContains'].includes(assertion.type)) {
      errors.push('Expected announcements support contains, matches, or orderedContains.');
    }
    if (typeof assertion.value !== 'string' || assertion.value.trim() === '') {
      errors.push('Expected announcements require a non-empty string value.');
    }
    if (assertion.evidenceType !== undefined && !ASSERTION_EVIDENCE_TYPES.has(assertion.evidenceType)) {
      errors.push(`Unsupported assertion evidence type: ${assertion.evidenceType}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

export async function createScreenReaderDriver({ platform = process.platform, driverName = 'guidepup', config = null } = {}) {
  const normalizedDriver = String(driverName || 'guidepup').toLowerCase();
  if (normalizedDriver === 'fake' || normalizedDriver === 'synthetic') {
    const validation = validateScreenReaderConfig(config || {});
    if (!validation.ok) {
      return {
        supported: false,
        status: 'invalid-config',
        errors: validation.errors,
      };
    }
    if (config?.captureMode === 'action') {
      return {
        supported: false,
        status: 'invalid-config',
        errors: ['Action-scoped capture requires a real Guidepup screen-reader driver.'],
      };
    }
    return createSyntheticDriver({
      platform,
      config: config || {},
      driverName: normalizedDriver === 'fake' ? 'fake' : 'synthetic',
    });
  }

  if (normalizedDriver !== 'guidepup') {
    return {
      supported: false,
      status: 'unsupported-driver',
      reason: `Unsupported screen-reader driver: ${driverName}`,
    };
  }

  const validation = validateScreenReaderConfig(config || {});
  if (!validation.ok) {
    return {
      supported: false,
      status: 'invalid-config',
      errors: validation.errors,
    };
  }

  const adapter = await createGuidepupDriverAdapter({ platform, config: config || {} });
  return adapter;
}
