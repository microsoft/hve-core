// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import os from "node:os";

import { stableJson } from "./contracts.mts";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

/** A value-free locator for information removed from a persisted artifact. */
export interface RedactionNotice {
  readonly location: string;
  readonly category: "host-path" | "credential";
  readonly replacements: number;
}

/**
 * Redacts JSON values without changing structural keys or mutating the input.
 *
 * Home paths come from the OS, HOME, and USERPROFILE. Callers supply repository and temporary
 * workspace paths, which cannot be inferred retrospectively. Longer paths are replaced first;
 * filesystem roots are excluded. Embedded JSON, JSON fences and JSONL are decoded before value
 * redaction and re-encoded only when changed. Notices use zero-based object-member and array
 * indices, never data-derived keys or removed values. Detection is not a sharing-safety guarantee.
 */
export function redactArtifact<T>(value: T, explicitPaths: readonly string[]): {
  readonly value: T;
  readonly replacements: number;
  readonly notices: readonly RedactionNotice[];
} {
  const paths = [...new Set(
    [...explicitPaths, os.homedir(), process.env.HOME, process.env.USERPROFILE]
      .filter((path): path is string => typeof path === "string" && path.length > 0)
      .map((path) => path.replaceAll("\\", "/").replace(/\/+$/, ""))
      .filter((path) => path.length > 0 && !/^[a-z]:$/i.test(path)),
  )].sort((left, right) => right.length - left.length);
  const pathPatterns = paths.map((path) => {
    const pattern = path.split("/")
      .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
      .join(String.raw`[\\/]+`);
    return new RegExp(pattern, /^(?:[a-z]:|\/\/)/i.test(path) ? "gi" : "g");
  });
  let replacements = 0;
  const notices = new Map<string, RedactionNotice>();
  const record = (location: string, category: RedactionNotice["category"]) => {
    replacements++;
    const key = `${location}/${category}`;
    notices.set(key, {
      location, category, replacements: (notices.get(key)?.replacements ?? 0) + 1,
    });
  };
  const redactText = (input: string, location: string, secret: boolean): string => {
    if (secret && input && !/^\[REDACTED(?:_[A-Z]+)?\]$/.test(input)) {
      record(location, "credential");
      return "[REDACTED_CREDENTIAL]";
    }
    let text = input;
    for (const pattern of pathPatterns) {
      text = text.replace(pattern, () => {
        record(location, "host-path");
        return "[REDACTED_PATH]";
      });
    }
    for (const pattern of [
      /[A-Za-z]:\\+Users\\+[^\\/"'\r\n]+/gi,
      /\/(?:home|Users)\/[^/\\"'\r\n]+/g,
    ]) {
      text = text.replace(pattern, () => {
        record(location, "host-path");
        return "[REDACTED_HOME]";
      });
    }
    for (const pattern of [
      /(?:ghp|github_pat|gho|ghu|ghs)_[A-Za-z0-9_]{20,}/g,
      /Bearer\s+[A-Za-z0-9._~+/=-]{16,}/gi,
    ]) {
      text = text.replace(pattern, () => {
        record(location, "credential");
        return "[REDACTED_CREDENTIAL]";
      });
    }
    return text.replace(
      /((?:api[_-]?key|token|password|secret|credential|authorization)["']?\s*[:=]\s*)("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/gi,
      (_match, prefix: string, quoted: string) => {
        if (/^\[REDACTED(?:_[A-Z]+)?\]$/.test(quoted.slice(1, -1))) return `${prefix}${quoted}`;
        record(location, "credential");
        return `${prefix}${quoted[0]}[REDACTED_CREDENTIAL]${quoted[0]}`;
      },
    );
  };
  const redactString = (text: string, location: string, secret: boolean): string => {
    const fenced = /^(\s*```(?:json)?[ \t]*\r?\n)([\s\S]*?)(\r?\n[ \t]*```\s*)$/i.exec(text);
    const structured = parseStructuredJson(fenced ? fenced[2]! : text);
    if (structured) {
      const before = replacements;
      const redacted = visit(structured.value, `${location}/json`, secret);
      if (before === replacements) return text;
      const encoded = JSON.stringify(redacted);
      return fenced ? `${fenced[1]}${encoded}${fenced[3]}` : encoded;
    }
    if (/[\r\n]/.test(text)) {
      return text.split(/(\r\n|\r|\n)/).map((part, index) =>
        index % 2 === 0 ? redactString(part, `${location}/line-${index / 2}`, secret) : part,
      ).join("");
    }
    return redactText(text, location, secret);
  };
  const visit = (node: JsonValue, location: string, secret = false): JsonValue => {
    if (typeof node === "string") return redactString(node, location, secret);
    if (Array.isArray(node)) return node.map((item, index) => visit(item, `${location}/${index}`, secret));
    if (node !== null && typeof node === "object") {
      return Object.fromEntries(Object.entries(node).map(([key, item], index) => [
        key,
        visit(item, `${location}/member-${index}`,
          secret || /(?:api[_-]?key|token|password|secret|credentials?|authorization)$/i.test(key)),
      ]));
    }
    return node;
  };
  const redacted = visit(JSON.parse(stableJson(value)) as JsonValue, "$");
  return { value: redacted as T, replacements, notices: [...notices.values()] };
}

function parseStructuredJson(text: string): { readonly value: JsonValue } | undefined {
  if (!/^\s*[{["]/.test(text)) return undefined;
  try {
    return { value: JSON.parse(text) as JsonValue };
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    return undefined;
  }
}
