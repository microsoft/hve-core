#!/usr/bin/env node
// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Usage: node validate-workflows.mjs [--repo-root <dir>] [--sarif <file>] [--shellcheck <path>]
// Exits 0 with no findings, 1 with findings, and 2 when validation cannot run.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertShellcheckVersion, getManifestShellcheckVersion, toSarif, validateRepository } from './validator.mjs';

const here = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const options = { repoRoot: resolve(here, '..', '..', '..'), sarif: null, shellcheck: process.env.SHELLCHECK ?? 'shellcheck' };
  for (let index = 0; index < argv.length; index++) {
    const value = argv[index + 1];
    switch (argv[index]) {
      case '--repo-root':
        options.repoRoot = resolve(value);
        index++;
        break;
      case '--sarif':
        options.sarif = resolve(value);
        index++;
        break;
      case '--shellcheck':
        options.shellcheck = value;
        index++;
        break;
      default:
        throw new Error(`Unknown argument: ${argv[index]}`);
    }
  }
  return options;
}

try {
  const options = parseArgs(process.argv.slice(2));
  const { version } = JSON.parse(readFileSync(join(here, 'package.json'), 'utf8'));
  assertShellcheckVersion(options.shellcheck, getManifestShellcheckVersion(options.repoRoot));
  const result = await validateRepository(options.repoRoot, { shellcheck: options.shellcheck });
  for (const finding of result.findings) {
    console.log(`${finding.file}:${finding.line}:${finding.column}: [${finding.ruleId}] ${finding.message}`);
  }
  if (options.sarif) {
    mkdirSync(dirname(options.sarif), { recursive: true });
    writeFileSync(options.sarif, `${JSON.stringify(toSarif(result.findings, version), null, 2)}\n`);
  }
  console.log(`Workflow validation: ${result.findings.length} finding(s) across ${result.files.length} file(s) and ${result.scripts} run script(s).`);
  process.exitCode = result.findings.length === 0 ? 0 : 1;
} catch (error) {
  console.error(`Workflow validation failed: ${error.message}`);
  process.exitCode = 2;
}
