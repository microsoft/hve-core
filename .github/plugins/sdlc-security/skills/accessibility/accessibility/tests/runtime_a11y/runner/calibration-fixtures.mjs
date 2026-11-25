// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export const calibrationFixtures = {
  checkbox: {
    pattern: 'checkbox',
    state: {
      role: 'checkbox',
      name: 'Accept terms',
      checked: true,
    },
    expected: {
      speech: 'checked',
      browserState: 'checked',
      accessibilityTree: 'checkbox',
    },
  },
  tabs: {
    pattern: 'tabs',
    state: {
      role: 'tab',
      name: 'Overview',
      selected: true,
    },
    expected: {
      speech: 'overview',
      browserState: 'selected',
      accessibilityTree: 'tab',
    },
  },
  modal: {
    pattern: 'modal',
    state: {
      role: 'dialog',
      name: 'Settings',
      open: true,
    },
    expected: {
      speech: 'settings',
      browserState: 'open',
      accessibilityTree: 'dialog',
    },
  },
  'menu-button': {
    pattern: 'menu-button',
    state: {
      role: 'button',
      name: 'Actions',
      expanded: true,
    },
    expected: {
      speech: 'actions',
      browserState: 'expanded',
      accessibilityTree: 'button',
    },
  },
  combobox: {
    pattern: 'combobox',
    state: {
      role: 'combobox',
      name: 'Choose a color',
      value: 'green',
    },
    expected: {
      speech: 'green',
      browserState: 'green',
      accessibilityTree: 'combobox',
    },
  },
};

export function createCalibrationFixture(pattern) {
  const fixture = calibrationFixtures[pattern];
  if (!fixture) {
    throw new Error(`Unknown calibration pattern: ${pattern}`);
  }
  return fixture;
}
