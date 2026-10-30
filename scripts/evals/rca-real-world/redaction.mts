// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import os from "node:os";

import { stableJson } from "./contracts.mts";

/**
 * Redacts host paths and credential-shaped values without mutating the input.
 *
 * Home paths come from the OS, HOME, and USERPROFILE. Callers supply repository and temporary
 * workspace paths, which cannot be inferred retrospectively. Longer paths are replaced first;
 * slash variants and JSON-escaped backslashes are recognized. Filesystem roots are excluded.
 */
export function redactArtifact<T>(value: T, explicitPaths: readonly string[]): {
  readonly value: T;
  readonly replacements: number;
} {
  const paths = [...new Set(
    [...explicitPaths, os.homedir(), process.env.HOME, process.env.USERPROFILE]
      .filter((path): path is string => typeof path === "string" && path.length > 0)
      .map((path) => path.replaceAll("\\", "/").replace(/\/+$/, ""))
      .filter((path) => path.length > 0 && !/^[a-z]:$/i.test(path)),
  )].sort((left, right) => right.length - left.length);
  let text = stableJson(value);
  let replacements = 0;
  for (const path of paths) {
    const encodedPath = JSON.stringify(path).slice(1, -1);
    const pattern = encodedPath
      .split("/")
      .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
      .join(String.raw`[\\/]+`);
    const flags = /^(?:[a-z]:|\/\/)/i.test(path) ? "gi" : "g";
    text = text.replace(new RegExp(pattern, flags), () => {
      replacements += 1;
      return "[REDACTED_PATH]";
    });
  }
  text = text.replace(/[A-Za-z]:\\\\Users\\\\[^\\"/]+/gi, () => {
    replacements += 1;
    return "[REDACTED_HOME]";
  });
  text = text.replace(/\/(?:home|Users)\/[^/\\"']+/g, () => {
    replacements += 1;
    return "[REDACTED_HOME]";
  });
  const patterns = [
    /(?:ghp|github_pat|gho|ghu|ghs)_[A-Za-z0-9_]{20,}/g,
    /(?:Bearer\s+)[A-Za-z0-9._~+/=-]{16,}/gi,
    /(?:api[_-]?key|token|password|secret)["']?\s*[:=]\s*["'][^"']+["']/gi,
  ];
  for (const pattern of patterns) {
    text = text.replace(pattern, () => {
      replacements += 1;
      return "[REDACTED_CREDENTIAL]";
    });
  }
  return { value: JSON.parse(text) as T, replacements };
}
