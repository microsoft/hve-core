#!/usr/bin/env node
// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Runs the capability probes against GitHub's workflow parser alone and writes
// observations for scripts/security/Get-UpstreamWatchStatus.ps1:
//   {"parserVersion": "x.y.z", "probes": {"<id>": "pass" | "fail"}}
// A probe passes when the parser behaves as it should: it reports an error for a
// known-bad sample (expect "error") and none for valid syntax (expect "clean").
// Usage: node run-probes.mjs [--parser-root <dir>] [--out <file>]
import './json-import-hooks.mjs';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * Reads the probe manifest.
 * @returns {{ id: string, file: string, expect: 'error' | 'clean', coveredBy: string, description: string }[]}
 */
export function readProbes() {
  return JSON.parse(readFileSync(join(here, 'probes', 'probes.json'), 'utf8'));
}

/**
 * Loads the parser from parserRoot/node_modules, or the validator's own install.
 * @param {string | null} parserRoot
 */
export async function loadParser(parserRoot) {
  const root = parserRoot ?? here;
  const packageDir = join(root, 'node_modules', '@actions', 'workflow-parser');
  const { version } = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'));
  const parser = await import(pathToFileURL(join(packageDir, 'dist', 'index.js')).href);
  return { version, parser };
}

/**
 * Runs every probe and returns its outcome.
 * @param {{ parseWorkflow: Function, convertWorkflowTemplate: Function, NoOperationTraceWriter: Function }} parser
 */
export async function runProbes(parser) {
  const outcomes = {};
  for (const probe of readProbes()) {
    const content = readFileSync(join(here, 'probes', probe.file), 'utf8');
    const parsed = parser.parseWorkflow({ name: probe.file, content }, new parser.NoOperationTraceWriter());
    if (parsed.value) await parser.convertWorkflowTemplate(parsed.context, parsed.value);
    const reported = parsed.context.errors.getErrors().length > 0;
    outcomes[probe.id] = reported === (probe.expect === 'error') ? 'pass' : 'fail';
  }
  return outcomes;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    const option = (name) => {
      const index = args.indexOf(name);
      return index >= 0 ? args[index + 1] : null;
    };
    const parserRoot = option('--parser-root');
    const out = option('--out');
    const { version, parser } = await loadParser(parserRoot ? resolve(parserRoot) : null);
    const observations = { parserVersion: version, probes: await runProbes(parser) };
    const text = `${JSON.stringify(observations, null, 2)}\n`;
    if (out) {
      mkdirSync(dirname(resolve(out)), { recursive: true });
      writeFileSync(resolve(out), text);
    }
    process.stdout.write(text);
  } catch (error) {
    console.error(`Capability probes failed: ${error.message}`);
    process.exitCode = 2;
  }
}
