// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export const ALLOWLISTED_KEY_VALUES = new Set([
  'Space',
  'ArrowDown',
  'ArrowRight',
  'ArrowUp',
  'ArrowLeft',
  'Home',
  'End',
  'Enter',
  'Escape',
  'Tab',
  'Shift+Tab',
  'Shift+F',
  'Shift+X',
  'Shift+B',
  'Control+A',
  'Control+K',
  // Chrome cycles keyboard focus between browser panes with F6. A freshly
  // launched window leaves focus in the address bar, where the screen reader
  // tracks omnibox suggestions instead of the document, so journeys must be
  // able to move focus into the web page before asserting on page speech.
  'F6',
]);

export const ALLOWLISTED_PERFORM_VALUES = new Set([
  'toggleBetweenBrowseAndFocusMode',
  'moveToNextFormField',
  'performDefaultActionForItem',
]);

// Printable characters only: no C0 or C1 control characters, no line breaks.
const TYPEABLE_TEXT_PATTERN = /^[^\p{Cc}\p{Cf}\p{Cs}]+$/u;

export function validateScreenReaderCommand(command) {
  if (!command || typeof command !== 'object') {
    return 'Each command must be an object.';
  }

  if (command.kind === 'command') {
    return typeof command.value === 'string' && command.value.trim() !== ''
      ? null
      : 'Command entries require a non-empty string value.';
  }

  if (command.kind === 'key' || command.kind === 'keyboard') {
    if (typeof command.value !== 'string' || command.value.trim() === '') {
      return 'Key entries require a non-empty string value.';
    }
    return ALLOWLISTED_KEY_VALUES.has(command.value)
      ? null
      : `Unsupported key value: ${command.value}`;
  }

  if (command.kind === 'type') {
    if (typeof command.value !== 'string') {
      return 'Type entries require a string value.';
    }
    if (command.value.trim() === '') {
      return 'Type entries require a non-empty string value.';
    }
    if (command.value.length > 256) {
      return 'Type entries require a string value no longer than 256 characters.';
    }
    // Typed text reaches OS-level keystroke synthesis, so it is restricted to
    // printable characters. Control characters and newlines would be delivered
    // as command keystrokes rather than as text.
    if (!TYPEABLE_TEXT_PATTERN.test(command.value)) {
      return 'Type entries require printable characters without control characters or line breaks.';
    }
    return null;
  }

  if (command.kind === 'pause') {
    return typeof command.durationMs === 'number' && command.durationMs >= 0
      ? null
      : 'Pause entries require a non-negative durationMs number.';
  }

  // waitFor is executed by the harness against the page, not dispatched to the
  // screen reader. It bounds how long a journey waits for the element that
  // produces an announcement before continuing.
  if (command.kind === 'waitFor') {
    const selector = typeof command.value === 'string' ? command.value : command.target;
    if (typeof selector !== 'string' || selector.trim() === '') {
      return 'WaitFor entries require a non-empty selector value.';
    }
    if (command.durationMs !== undefined && (typeof command.durationMs !== 'number' || command.durationMs < 0)) {
      return 'WaitFor entries require a non-negative durationMs number.';
    }
    return null;
  }

  if (command.kind === 'perform') {
    if (typeof command.value !== 'string' || command.value.trim() === '') {
      return 'Perform entries require a non-empty string value.';
    }
    return ALLOWLISTED_PERFORM_VALUES.has(command.value)
      ? null
      : `Unsupported perform value: ${command.value}`;
  }

  return `Unsupported command kind: ${command.kind || 'unknown'}`;
}
