// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash, createHmac, randomBytes } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";

const patterns: readonly (readonly [string, RegExp])[] = [
  ["ENVIRONMENT", /"(?:PATH|HOME|USERPROFILE|GITHUB_TOKEN|COPILOT_GITHUB_TOKEN)"\s*:\s*(?:"(?:\\.|[^"\\])*"|[^\r\n,}]+)/gi],
  ["CREDENTIAL", /(?:api[_-]?key|token|password|secret)["']?\s*[:=]\s*["'][^"'\r\n]+["']/gi],
  ["CREDENTIAL", /(?:ghp|github_pat|gho|ghu|ghs)_[A-Za-z0-9_]{20,}/g],
  ["AUTHORIZATION", /Bearer\s+[A-Za-z0-9._~+/=-]{16,}/gi],
  ["HOME_PATH", /[A-Za-z]:\\(?:\\)?Users\\(?:\\)?[^\\\s"'<>]+/gi],
  ["HOME_PATH", /\/(?:home|Users)\/[^/\s"'<>]+/g],
  ["EMAIL", /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi],
];

/** Detects supported identifier, credential, and home-path patterns, including common encoded forms. */
export function reportSensitiveCategories(text: string): readonly string[] {
  const decoded = decodeForInspection(text);
  return [...new Set(patterns.filter(([, pattern]) => {
    pattern.lastIndex = 0;
    return pattern.test(decoded);
  }).map(([category]) => category))];
}

/**
 * Writes run-local originals and checked presentation copies using a persisted, run-scoped HMAC key.
 *
 * Originals, key, and reveal links rely on existing OS access controls, not application authorization.
 * All copies are checked before any presentation file is written. Source evidence is never mutated.
 */
export async function writeLocalReports(
  runRoot: string,
  reports: readonly { readonly path: string; readonly text: string }[],
): Promise<void> {
  const restrictedRoot = join(runRoot, "restricted-reports");
  await mkdir(join(restrictedRoot, "values"), { recursive: true, mode: 0o700 });
  const keyPath = join(restrictedRoot, "pseudonym-key");
  try {
    await writeFile(keyPath, randomBytes(32), { flag: "wx", mode: 0o600 });
  } catch (error) {
    if (!(error instanceof Error && "code" in error && error.code === "EEXIST")) {
      throw error;
    }
  }
  const key = await readFile(keyPath);
  if (key.length !== 32) {
    throw new Error("Invalid local report pseudonym key; restore the original 32-byte key");
  }
  const values = new Map<string, { category: string; value: string }>();
  const pseudonym = (category: string, value: string): string => {
    const token = `${category}_${createHmac("sha256", key).update(category).update("\0").update(value).digest("hex")}`;
    const previous = values.get(token);
    if (previous && (previous.category !== category || previous.value !== value)) {
      throw new Error("Local report pseudonym collision; presentation withheld");
    }
    values.set(token, { category, value });
    return token;
  };
  const manifest = [];
  const presentations = [];
  for (const report of reports) {
    if (join(runRoot, basename(report.path)) !== report.path) {
      throw new Error("Local presentation reports must be direct children of the run directory");
    }
    const originalHash = sha256(report.text);
    const originalName = `${basename(report.path)}.${originalHash}.txt`;
    await writeFile(join(restrictedRoot, originalName), report.text, { encoding: "utf8", mode: 0o600 });
    const used = new Set<string>();
    let replacements = 0;
    let withheldLines = 0;
    const replace = (category: string, value: string): string => {
      const token = pseudonym(category, value);
      used.add(token);
      replacements += 1;
      return token;
    };
    const masked = report.text.split("\n").map((line) => {
      let result = line;
      for (const [category, pattern] of patterns) {
        result = result.replace(pattern, (value) => replace(category, value));
      }
      if (reportSensitiveCategories(result).length > 0) {
        withheldLines += 1;
        return replace("WITHHELD_LINE", line);
      }
      return result;
    }).join("\n");
    const text = `${masked.trimEnd()}

## Local privacy handling

> [!WARNING]
> Local-only report. Do not commit, publish, or redistribute this copy or its linked originals.
> Reveal links rely on existing OS file permissions; they do not enforce separate authorization.
> Automated masking covers supported patterns only and does not guarantee anonymity.

${replacements} replacements; ${withheldLines} encoded-content lines withheld.
Pseudonyms are stable within this run. Original evidence and scoring are unchanged.

[Full original report](restricted-reports/${originalName})

${[...used].map((token) => `* \`${token}\`: [View original value](restricted-reports/values/${token}.txt)`).join("\n")}
`;
    const remaining = reportSensitiveCategories(text);
    if (remaining.length > 0) {
      throw new Error(`Local report presentation withheld: remaining categories ${remaining.join(", ")}`);
    }
    presentations.push({ path: report.path, text });
    manifest.push({
      report: basename(report.path), original: `restricted-reports/${originalName}`,
      originalSha256: originalHash, presentationSha256: sha256(text),
      replacements, withheldLines, pseudonyms: [...used], status: "pass",
    });
  }
  for (const [token, item] of values) {
    await writeFile(
      join(restrictedRoot, "values", `${token}.txt`),
      JSON.stringify(item, null, 2),
      { encoding: "utf8", mode: 0o600 },
    );
  }
  await writeFile(join(runRoot, "report-privacy.json"), JSON.stringify({
    schemaVersion: "1.0.0", transformation: "local-report-hmac-sha256-v1",
    localOnly: true, authorization: "existing-os-permissions", reports: manifest,
  }, null, 2), "utf8");
  for (const presentation of presentations) {
    await writeFile(presentation.path, presentation.text, "utf8");
  }
}

function sha256(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

function decodeForInspection(text: string): string {
  let decoded = text;
  for (let iteration = 0; iteration < 4; iteration += 1) {
    const next = decoded.replace(/(?:%[0-9a-f]{2})+/gi, (value) => {
      try {
        return decodeURIComponent(value);
      } catch (error) {
        if (!(error instanceof URIError)) {
          throw error;
        }
        return value;
      }
    }).replace(/&#(?:x([0-9a-f]+)|([0-9]+));/gi, (value, hex: string | undefined, decimal: string | undefined) => {
      const codePoint = Number.parseInt(hex ?? decimal!, hex ? 16 : 10);
      return codePoint <= 0x10ffff ? String.fromCodePoint(codePoint) : value;
    }).replace(/&(commat|period|amp|colon|sol|bsol|quot);/gi, (value, name: string) => {
      const entities: Readonly<Record<string, string>> = {
        commat: "@", period: ".", amp: "&", colon: ":", sol: "/", bsol: "\\", quot: '"',
      };
      return entities[name.toLowerCase()] ?? value;
    }).replace(/\\u([0-9a-f]{4})/gi, (_, hex: string) => String.fromCharCode(Number.parseInt(hex, 16)));
    if (next === decoded) {
      break;
    }
    decoded = next;
  }
  return decoded;
}
