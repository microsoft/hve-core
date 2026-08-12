// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createGuidepupDriverAdapter } from './guidepup-adapter.mjs';
import { validateScreenReaderCommand } from './command-contract.mjs';

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
  };
}

export function validateScreenReaderConfig(config = {}) {
  const errors = [];
  const commands = Array.isArray(config?.commands) ? config.commands : [];
  const expectedAnnouncements = Array.isArray(config?.expectedAnnouncements)
    ? config.expectedAnnouncements
    : [];

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
