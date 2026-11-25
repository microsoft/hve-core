// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export function assertHttpUrl(rawValue, label = 'URL') {
  const value = typeof rawValue === 'string' ? rawValue : '';
  if (!/^https?:\/\//i.test(value) || /[\u0000-\u0020\u007f]/.test(value)) {
    throw new Error(`${label} must be an absolute HTTP(S) URL without whitespace or control characters.`);
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${label} must be an absolute HTTP(S) URL with a host.`);
  }

  if (!['http:', 'https:'].includes(parsed.protocol) || !parsed.hostname) {
    throw new Error(`${label} must be an absolute HTTP(S) URL with a host.`);
  }
  if (parsed.username || parsed.password) {
    throw new Error(`${label} must not include credentials.`);
  }

  return value;
}

const ARTIFACT_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;

// Win32 resolves these names as devices in any directory, and it strips trailing
// dots, so either form would break or silently collide as an evidence segment.
const RESERVED_DEVICE_NAMES = new Set([
  'con', 'prn', 'aux', 'nul',
  'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
  'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
]);

export function assertArtifactId(rawValue, label = 'Artifact ID') {
  if (typeof rawValue !== 'string' || !ARTIFACT_ID_PATTERN.test(rawValue)) {
    throw new Error(
      `${label} must be 1-128 ASCII letters, numbers, dots, underscores, or hyphens and start with a letter or number.`,
    );
  }
  if (rawValue.endsWith('.')) {
    throw new Error(`${label} must not end with a dot.`);
  }
  if (RESERVED_DEVICE_NAMES.has(rawValue.split('.')[0].toLowerCase())) {
    throw new Error(`${label} must not use a reserved Windows device name.`);
  }
  return rawValue;
}
