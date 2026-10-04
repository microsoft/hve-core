// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Validates workflows and composite actions with GitHub's workflow parser and
// runs a pinned shellcheck over every bash and sh `run:` script.
import './json-import-hooks.mjs';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isMap, isScalar, isSeq, LineCounter, parseDocument } from 'yaml';
import { CHECK_RULES, fetchTextFromGitHub, getCheckFindings } from './checks.mjs';

// The parser's JSON schema imports resolve only after the hook above is
// registered, so the parser is loaded dynamically rather than statically.
const { parseWorkflow, convertWorkflowTemplate, NoOperationTraceWriter } = await import('@actions/workflow-parser');
const { parseAction, convertActionTemplate } = await import('@actions/workflow-parser/actions/index');

export const TOOL_NAME = 'hve-workflow-validator';
export const PARSER_RULE = 'workflow-parser/error';

const SHELLCHECK_LEVELS = { error: 'error', warning: 'warning', info: 'note', style: 'note' };
const SHELLCHECK_BATCH = 100;

/**
 * Lists repository-relative workflow and composite action files.
 * @param {string} repoRoot
 * @returns {{ path: string, kind: 'workflow' | 'action' }[]}
 */
export function discoverFiles(repoRoot) {
  const files = [];
  const workflows = join(repoRoot, '.github', 'workflows');
  for (const name of safeReaddir(workflows).sort()) {
    if (/\.ya?ml$/.test(name) && statSync(join(workflows, name)).isFile()) {
      files.push({ path: toPosix(relative(repoRoot, join(workflows, name))), kind: 'workflow' });
    }
  }
  const walk = (directory) => {
    for (const name of safeReaddir(directory).sort()) {
      const full = join(directory, name);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (/^action\.ya?ml$/.test(name)) {
        files.push({ path: toPosix(relative(repoRoot, full)), kind: 'action' });
      }
    }
  };
  walk(join(repoRoot, '.github', 'actions'));
  return files;
}

/**
 * Parses one file with GitHub's parser and returns its schema, expression, and
 * semantic errors as findings.
 * @param {string} path Repository-relative path used in messages and locations.
 * @param {string} content
 * @param {'workflow' | 'action'} kind
 */
export async function getParserFindings(path, content, kind) {
  const file = { name: path, content };
  const trace = new NoOperationTraceWriter();
  const parsed = kind === 'action' ? parseAction(file, trace) : parseWorkflow(file, trace);
  const errors = [...parsed.context.errors.getErrors()];
  if (parsed.value) {
    if (kind === 'action') {
      convertActionTemplate(parsed.context, parsed.value);
    } else {
      await convertWorkflowTemplate(parsed.context, parsed.value);
    }
    for (const error of parsed.context.errors.getErrors()) {
      if (!errors.includes(error)) errors.push(error);
    }
  }

  const seen = new Set();
  const findings = [];
  for (const error of errors) {
    const message = error.rawMessage ?? error.message;
    const line = error.range?.start?.line ?? 1;
    const column = error.range?.start?.column ?? 1;
    const key = `${line}:${column}:${message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    findings.push({ ruleId: PARSER_RULE, level: 'error', message, file: path, line, column });
  }
  return findings;
}

/**
 * Extracts bash and sh `run:` scripts with the file position of each script line.
 * `${{ }}` expressions are replaced with same-length placeholders so columns
 * still match the source.
 * @param {string} content
 * @param {'workflow' | 'action'} kind
 * @returns {{ dialect: 'bash' | 'sh', text: string, lines: { line: number, column: number }[] }[]}
 */
export function extractRunScripts(content, kind) {
  const lineCounter = new LineCounter();
  const doc = parseDocument(content, { lineCounter, keepSourceTokens: true });
  const root = doc.contents;
  if (!isMap(root)) return [];

  const scripts = [];
  const sourceLines = content.split(/\r?\n/);
  const addSteps = (steps, inheritedShell) => {
    if (!isSeq(steps)) return;
    for (const step of steps.items) {
      if (!isMap(step)) continue;
      const runNode = step.get('run', true);
      if (!isScalar(runNode) || typeof runNode.value !== 'string') continue;
      const shell = scalarString(step.get('shell', true)) ?? inheritedShell;
      const dialect = shellDialect(shell);
      if (!dialect) continue;
      scripts.push(buildScript(runNode, dialect, lineCounter, sourceLines));
    }
  };

  if (kind === 'action') {
    const runs = root.get('runs', true);
    if (isMap(runs) && scalarString(runs.get('using', true)) === 'composite') {
      addSteps(runs.get('steps', true), null);
    }
    return scripts;
  }

  const workflowShell = defaultShell(root) ?? 'bash';
  const jobs = root.get('jobs', true);
  if (!isMap(jobs)) return scripts;
  for (const pair of jobs.items) {
    const job = pair.value;
    if (!isMap(job)) continue;
    addSteps(job.get('steps', true), defaultShell(job) ?? workflowShell);
  }
  return scripts;
}

/**
 * Runs shellcheck over extracted scripts and maps each comment to the source file.
 * Sourced files are followed relative to options.sourcePath (the repository
 * root), so a `source scripts/x.sh` resolves as it does on the runner.
 * @param {{ file: string, script: ReturnType<typeof extractRunScripts>[number] }[]} entries
 * @param {{ shellcheck: string, sourcePath?: string, run?: typeof spawnSync }} options
 */
export function getShellcheckFindings(entries, options) {
  const run = options.run ?? spawnSync;
  const sourceArgs = options.sourcePath ? ['--external-sources', `--source-path=${options.sourcePath}`] : [];
  const findings = [];
  if (entries.length === 0) return findings;
  const directory = mkdtempSync(join(tmpdir(), 'hve-workflow-validator-'));
  try {
    for (const dialect of ['bash', 'sh']) {
      const group = entries.map((entry, index) => ({ ...entry, index })).filter((entry) => entry.script.dialect === dialect);
      for (let start = 0; start < group.length; start += SHELLCHECK_BATCH) {
        const batch = group.slice(start, start + SHELLCHECK_BATCH);
        const byName = new Map();
        for (const entry of batch) {
          const name = join(directory, `script-${entry.index}.sh`);
          writeFileSync(name, entry.script.text);
          byName.set(name, entry);
        }
        const result = run(options.shellcheck, ['--format=json1', `--shell=${dialect}`, ...sourceArgs, ...byName.keys()], {
          encoding: 'utf8',
          maxBuffer: 64 * 1024 * 1024,
        });
        if (result.error) throw new Error(`shellcheck could not run: ${result.error.message}`);
        if (result.status !== 0 && result.status !== 1) {
          throw new Error(`shellcheck exited ${result.status}: ${(result.stderr ?? '').trim()}`);
        }
        const report = JSON.parse(result.stdout || '{"comments":[]}');
        for (const comment of report.comments ?? []) {
          const entry = byName.get(comment.file);
          if (!entry) continue;
          const position = entry.script.lines[comment.line - 1] ?? entry.script.lines.at(-1);
          findings.push({
            ruleId: `shellcheck/SC${comment.code}`,
            level: SHELLCHECK_LEVELS[comment.level] ?? 'warning',
            message: `SC${comment.code}: ${comment.message}`,
            file: entry.file,
            line: position.line,
            column: position.column + comment.column - 1,
          });
        }
      }
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
  return findings;
}

/**
 * Returns the installed shellcheck version and requires it to match the manifest.
 * @param {string} shellcheck
 * @param {string} expectedVersion
 */
export function assertShellcheckVersion(shellcheck, expectedVersion, run = spawnSync) {
  const result = run(shellcheck, ['--version'], { encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    throw new Error(`shellcheck ${expectedVersion} from scripts/security/tool-checksums.json is required but '${shellcheck}' could not run`);
  }
  const version = /version:\s*(\S+)/.exec(result.stdout ?? '')?.[1];
  if (version !== expectedVersion) {
    throw new Error(`shellcheck ${expectedVersion} from scripts/security/tool-checksums.json is required, but '${shellcheck}' is ${version ?? 'unknown'}`);
  }
  return version;
}

/**
 * Reads the manifest shellcheck version.
 * @param {string} repoRoot
 */
export function getManifestShellcheckVersion(repoRoot) {
  const manifest = JSON.parse(readFileSync(join(repoRoot, 'scripts', 'security', 'tool-checksums.json'), 'utf8'));
  const tool = manifest.tools.find((entry) => entry.name === 'shellcheck');
  if (!tool) throw new Error('scripts/security/tool-checksums.json has no shellcheck entry');
  return tool.version;
}

/**
 * Validates every workflow and composite action under repoRoot.
 * Remote action metadata is read at its pinned commit and cached under
 * options.cacheDir; options.fetchText replaces the network for tests.
 * @param {string} repoRoot
 * @param {{ shellcheck: string, run?: typeof spawnSync, fetchText?: (url: string) => Promise<string | null>, cacheDir?: string }} options
 */
export async function validateRepository(repoRoot, options) {
  const files = discoverFiles(repoRoot);
  const findings = [];
  const entries = [];
  const checkOptions = {
    repoRoot,
    fetchText: options.fetchText ?? fetchTextFromGitHub,
    cacheDir: options.cacheDir ?? join(dirname(fileURLToPath(import.meta.url)), 'node_modules', '.cache', 'hve-workflow-validator'),
  };
  for (const file of files) {
    const content = readFileSync(join(repoRoot, file.path), 'utf8');
    findings.push(...(await getParserFindings(file.path, content, file.kind)));
    findings.push(...(await getCheckFindings(file.path, content, file.kind, checkOptions)));
    for (const script of extractRunScripts(content, file.kind)) {
      entries.push({ file: file.path, script });
    }
  }
  findings.push(...getShellcheckFindings(entries, { sourcePath: repoRoot, ...options }));
  findings.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line || a.column - b.column || a.ruleId.localeCompare(b.ruleId));
  return { files, scripts: entries.length, findings };
}

/**
 * Builds a SARIF 2.1.0 document for the findings.
 * @param {{ ruleId: string, level: string, message: string, file: string, line: number, column: number }[]} findings
 * @param {string} version Tool version.
 */
export function toSarif(findings, version) {
  const ruleIds = [...new Set([PARSER_RULE, ...Object.keys(CHECK_RULES), ...findings.map((finding) => finding.ruleId)])].sort();
  const describe = (id) => {
    if (id === PARSER_RULE) return { text: 'GitHub workflow parser error', help: 'https://github.com/actions/languageservices' };
    if (CHECK_RULES[id]) return { text: CHECK_RULES[id], help: 'https://github.com/microsoft/hve-core/blob/main/scripts/linting/README.md' };
    const code = id.slice('shellcheck/'.length);
    return { text: `shellcheck ${code} in a run: script`, help: `https://www.shellcheck.net/wiki/${code}` };
  };
  const rules = ruleIds.map((id) => ({
    id,
    name: id.replace(/[^A-Za-z0-9]+/g, ''),
    shortDescription: { text: describe(id).text },
    helpUri: describe(id).help,
  }));
  return {
    version: '2.1.0',
    $schema: 'https://json.schemastore.org/sarif-2.1.0.json',
    runs: [
      {
        tool: { driver: { name: TOOL_NAME, version, informationUri: 'https://github.com/microsoft/hve-core', rules } },
        results: findings.map((finding) => ({
          ruleId: finding.ruleId,
          level: finding.level,
          message: { text: finding.message },
          locations: [
            {
              physicalLocation: {
                artifactLocation: { uri: finding.file },
                region: { startLine: Math.max(1, finding.line), startColumn: Math.max(1, finding.column) },
              },
            },
          ],
        })),
      },
    ],
  };
}

function buildScript(runNode, dialect, lineCounter, sourceLines) {
  const start = lineCounter.linePos(runNode.range[0]);
  const isBlock = runNode.type === 'BLOCK_LITERAL' || runNode.type === 'BLOCK_FOLDED';
  const text = maskExpressions(runNode.value);
  const count = text.split('\n').length;
  const lines = [];
  if (isBlock) {
    let indent = 0;
    for (let index = start.line; index < sourceLines.length; index++) {
      if (sourceLines[index].trim() !== '') {
        indent = sourceLines[index].length - sourceLines[index].trimStart().length;
        break;
      }
    }
    for (let index = 0; index < count; index++) lines.push({ line: start.line + 1 + index, column: indent + 1 });
  } else {
    const offset = runNode.type === 'PLAIN' ? 0 : 1;
    for (let index = 0; index < count; index++) lines.push({ line: start.line + index, column: start.col + offset });
  }
  return { dialect, text, lines };
}

function maskExpressions(text) {
  return text.replace(/\$\{\{[\s\S]*?\}\}/g, (expression) => expression.replace(/[^\n]/g, '_'));
}

function defaultShell(node) {
  const defaults = node.get('defaults', true);
  if (!isMap(defaults)) return null;
  const run = defaults.get('run', true);
  return isMap(run) ? scalarString(run.get('shell', true)) : null;
}

function shellDialect(shell) {
  if (!shell) return null;
  const command = shell.trim().split(/\s+/)[0].split('/').at(-1);
  if (command === 'bash') return 'bash';
  if (command === 'sh') return 'sh';
  return null;
}

function scalarString(node) {
  return isScalar(node) && typeof node.value === 'string' ? node.value : null;
}

function safeReaddir(directory) {
  try {
    return readdirSync(directory);
  } catch {
    return [];
  }
}

function toPosix(path) {
  return path.split('\\').join('/');
}
