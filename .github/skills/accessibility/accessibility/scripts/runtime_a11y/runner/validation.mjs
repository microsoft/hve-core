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

export function assertArtifactId(rawValue, label = 'Artifact ID') {
  if (typeof rawValue !== 'string' || !ARTIFACT_ID_PATTERN.test(rawValue)) {
    throw new Error(
      `${label} must be 1-128 ASCII letters, numbers, dots, underscores, or hyphens and start with a letter or number.`,
    );
  }
  return rawValue;
}
