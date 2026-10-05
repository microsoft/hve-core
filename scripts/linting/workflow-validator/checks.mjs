// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Custom checks for workflow problems GitHub's parser does not report.
// Each rule has a capability probe in probes/, so a check can be retired once
// the parser catches the same case.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { isMap, isScalar, isSeq, LineCounter, parseDocument } from 'yaml';

export const CHECK_RULES = {
  'workflow-check/unknown-context-property': 'Expression reads a property the context does not have',
  'workflow-check/undefined-step': 'Expression reads steps.<id> for a step id the job does not define',
  'workflow-check/undefined-need': 'Expression reads needs.<job> for a job not listed in needs',
  'workflow-check/undefined-matrix-key': 'Expression reads matrix.<key> for a key the matrix does not define',
  'workflow-check/undefined-input': 'Expression reads inputs.<name> for an input the workflow or action does not declare',
  'workflow-check/invalid-path-filter': 'Branch, tag, or path filter pattern is not a valid glob',
  'workflow-check/always-true-if': 'if: mixes ${{ }} with other text, so it is a non-empty string and always true',
  'workflow-check/deprecated-workflow-command': 'run: script uses a disabled workflow command',
  'workflow-check/invalid-env-name': 'Environment variable name is not a valid shell identifier',
  'workflow-check/unknown-action-input': 'with: passes an input the action or reusable workflow does not declare',
  'workflow-check/missing-required-input': 'A required reusable workflow input or secret is not passed',
  'workflow-check/action-metadata-unavailable': 'Action or reusable workflow metadata could not be read, so its inputs were not verified',
  'workflow-check/sourced-helper-unavailable': 'A gh-aw helper script that a run: step sources could not be read at its pinned commit, so shellcheck could not follow it',
};

// First-level properties of contexts with a fixed shape, lowercase because
// context property names are case-insensitive.
const CONTEXT_PROPERTIES = {
  github: new Set([
    'action', 'action_path', 'action_ref', 'action_repository', 'action_status', 'actor', 'actor_id', 'api_url',
    'base_ref', 'env', 'event', 'event_name', 'event_path', 'graphql_url', 'head_ref', 'job', 'path', 'ref',
    'ref_name', 'ref_protected', 'ref_type', 'repository', 'repository_id', 'repository_owner', 'repository_owner_id',
    'repositoryurl', 'retention_days', 'run_attempt', 'run_id', 'run_number', 'secret_source', 'server_url', 'sha',
    'token', 'triggering_actor', 'workflow', 'workflow_ref', 'workflow_sha', 'workspace',
  ]),
  runner: new Set(['arch', 'debug', 'environment', 'name', 'os', 'temp', 'tool_cache']),
  job: new Set(['check_run_id', 'container', 'services', 'status', 'workflow_file_path', 'workflow_ref', 'workflow_repository', 'workflow_sha']),
  strategy: new Set(['fail-fast', 'job-index', 'job-total', 'max-parallel']),
};
const STEP_PROPERTIES = new Set(['conclusion', 'outcome', 'outputs']);
const NEED_PROPERTIES = new Set(['outputs', 'result']);
const FILTER_KEYS = new Set(['branches', 'branches-ignore', 'tags', 'tags-ignore', 'paths', 'paths-ignore']);
const DEPRECATED_COMMANDS = /::(set-output|save-state|set-env|add-path)\b/;
const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;
const REMOTE_USES = /^(?<owner>[A-Za-z0-9_.-]+)\/(?<repo>[A-Za-z0-9_.-]+)(?<path>\/[^@]*)?@(?<ref>[^\s]+)$/;

// One lookup per URL per fetch function, so a missing file is fetched once per
// run however many workflows reference it.
const fetchMemo = new WeakMap();
function memoizedFetch(fetchText, url) {
  if (!fetchMemo.has(fetchText)) fetchMemo.set(fetchText, new Map());
  const memo = fetchMemo.get(fetchText);
  if (!memo.has(url)) memo.set(url, fetchText(url));
  return memo.get(url);
}

/**
 * Runs every custom check on one file.
 * @param {string} path Repository-relative path.
 * @param {string} content
 * @param {'workflow' | 'action'} kind
 * @param {{ repoRoot: string, fetchText?: (url: string) => Promise<string | null>, cacheDir?: string }} options
 */
export async function getCheckFindings(path, content, kind, options) {
  const lineCounter = new LineCounter();
  const doc = parseDocument(content, { lineCounter, keepSourceTokens: true });
  const root = doc.contents;
  if (!isMap(root)) return [];
  const ctx = { path, lineCounter, lines: content.split(/\r?\n/), findings: [], options };

  if (kind === 'action') {
    const inputs = mapKeys(root.get('inputs', true));
    const runs = root.get('runs', true);
    const steps = isMap(runs) ? runs.get('steps', true) : null;
    const scope = { inputs, steps: stepIds(steps), needs: null, matrix: null, inJob: true };
    walkExpressions(ctx, root, scope);
    checkEnvNames(ctx, root);
    if (isSeq(steps)) {
      for (const step of steps.items) await checkStep(ctx, step, scope);
    }
    return ctx.findings;
  }

  const on = root.get('on', true);
  const workflowInputs = workflowInputNames(on);
  checkFilters(ctx, on);
  checkEnvNames(ctx, root);
  const topScope = { inputs: workflowInputs, steps: null, needs: null, matrix: null, inJob: false };
  for (const pair of root.items) {
    const key = scalarString(pair.key);
    if (key === 'jobs' || key === 'on') continue;
    walkExpressions(ctx, pair.value, topScope);
  }
  if (isMap(on)) walkExpressions(ctx, on, topScope);

  const jobs = root.get('jobs', true);
  if (!isMap(jobs)) return ctx.findings;
  for (const pair of jobs.items) {
    const job = pair.value;
    if (!isMap(job)) continue;
    const scope = {
      inputs: workflowInputs,
      steps: stepIds(job.get('steps', true)),
      needs: needsList(job.get('needs', true)),
      matrix: matrixKeys(job.get('strategy', true)),
      inJob: true,
    };
    walkExpressions(ctx, job, scope);
    checkEnvNames(ctx, job);
    const steps = job.get('steps', true);
    if (isSeq(steps)) {
      for (const step of steps.items) await checkStep(ctx, step, scope);
    }
    const uses = scalarString(job.get('uses', true));
    if (uses) await checkReusableWorkflowCall(ctx, job, uses);
  }
  return ctx.findings;
}

async function checkStep(ctx, step, scope) {
  if (!isMap(step)) return;
  checkEnvNames(ctx, step);
  const run = step.get('run', true);
  if (isScalar(run) && typeof run.value === 'string') {
    const match = DEPRECATED_COMMANDS.exec(run.value);
    if (match) {
      report(ctx, 'workflow-check/deprecated-workflow-command', run, match.index,
        `'::${match[1]}' is disabled on GitHub-hosted runners; write to $GITHUB_OUTPUT, $GITHUB_STATE, $GITHUB_ENV, or $GITHUB_PATH instead`);
    }
  }
  const usesNode = step.get('uses', true);
  const uses = scalarString(usesNode);
  if (uses) await checkActionInputs(ctx, step, uses, usesNode);
}

function walkExpressions(ctx, node, scope) {
  visitScalars(node, null, (scalar, key) => {
    if (typeof scalar.value !== 'string') return;
    const text = scalar.value;
    if (key === 'if') {
      checkAlwaysTrueIf(ctx, scalar);
      if (!text.includes('${{')) {
        checkExpression(ctx, scope, scalar, text, 0);
        return;
      }
    }
    for (const match of text.matchAll(/\$\{\{([\s\S]*?)\}\}/g)) {
      checkExpression(ctx, scope, scalar, match[1], match.index + 3);
    }
  });
}

function checkExpression(ctx, scope, scalar, expression, offset) {
  const code = maskStringLiterals(expression);
  const reference = /(?<![\w.'"\]])(github|runner|job|strategy|steps|needs|matrix|inputs)\s*\.\s*([A-Za-z_][\w-]*)(?:\s*\.\s*([A-Za-z_][\w-]*))?/gi;
  for (const match of code.matchAll(reference)) {
    const context = match[1].toLowerCase();
    const name = match[2];
    const lower = name.toLowerCase();
    const property = match[3]?.toLowerCase();
    const at = offset + match.index;
    if (CONTEXT_PROPERTIES[context] && !CONTEXT_PROPERTIES[context].has(lower)) {
      report(ctx, 'workflow-check/unknown-context-property', scalar, at, `'${context}.${name}' is not a property of the ${context} context`);
    } else if (context === 'steps') {
      if (!scope.inJob || (scope.steps && !scope.steps.has(lower))) {
        report(ctx, 'workflow-check/undefined-step', scalar, at, `'steps.${name}' does not match any step id in this ${scope.inJob ? 'job' : 'scope'}`);
      } else if (property && !STEP_PROPERTIES.has(property)) {
        report(ctx, 'workflow-check/unknown-context-property', scalar, at, `'steps.${name}.${match[3]}' is not a step property; use outputs, outcome, or conclusion`);
      }
    } else if (context === 'needs') {
      if (!scope.needs || !scope.needs.has(lower)) {
        report(ctx, 'workflow-check/undefined-need', scalar, at, `'needs.${name}' is not listed in this job's needs`);
      } else if (property && !NEED_PROPERTIES.has(property)) {
        report(ctx, 'workflow-check/unknown-context-property', scalar, at, `'needs.${name}.${match[3]}' is not a needs property; use outputs or result`);
      }
    } else if (context === 'matrix') {
      if (scope.matrix !== undefined && (scope.matrix === null || !scope.matrix.has(lower))) {
        report(ctx, 'workflow-check/undefined-matrix-key', scalar, at, `'matrix.${name}' is not defined by this job's strategy.matrix`);
      }
    } else if (context === 'inputs') {
      if (!scope.inputs.has(lower)) {
        report(ctx, 'workflow-check/undefined-input', scalar, at, `'inputs.${name}' is not a declared input`);
      }
    }
  }
}

function checkAlwaysTrueIf(ctx, scalar) {
  const text = scalar.value.trim();
  if (!text.includes('${{')) return;
  const whole = /^\$\{\{[\s\S]*\}\}$/.test(text) && text.indexOf('${{', 1) === -1;
  if (!whole) {
    report(ctx, 'workflow-check/always-true-if', scalar, 0,
      'This if: has text outside ${{ }}, so it evaluates to a non-empty string and is always true; write one expression without ${{ }}');
  }
}

function checkFilters(ctx, on) {
  if (!isMap(on)) return;
  for (const eventPair of on.items) {
    const event = eventPair.value;
    if (!isMap(event)) continue;
    for (const pair of event.items) {
      if (!FILTER_KEYS.has(scalarString(pair.key)) || !isSeq(pair.value)) continue;
      for (const item of pair.value.items) {
        if (!isScalar(item)) continue;
        const problem = filterPatternProblem(String(item.value ?? ''));
        if (problem) report(ctx, 'workflow-check/invalid-path-filter', item, 0, `Filter pattern '${item.value}' is invalid: ${problem}`);
      }
    }
  }
}

/**
 * Returns why a branch, tag, or path filter pattern is invalid, or null.
 * @param {string} pattern
 */
export function filterPatternProblem(pattern) {
  const body = pattern.startsWith('!') ? pattern.slice(1) : pattern;
  if (pattern.trim() === '') return 'it is empty';
  if (body === '') return "'!' must be followed by a pattern";
  if (pattern !== pattern.trim()) return 'it has leading or trailing whitespace';
  let inClass = false;
  let classStart = -1;
  for (let index = 0; index < body.length; index++) {
    const char = body[index];
    if (char === '\\') {
      if (index === body.length - 1) return 'it ends with an escape character';
      index++;
      continue;
    }
    if (char === '[') {
      if (inClass) return "'[' cannot appear inside a character class";
      inClass = true;
      classStart = index;
    } else if (char === ']') {
      if (!inClass) return "']' has no matching '['";
      const set = body.slice(classStart + 1, index);
      if (set === '') return 'a character class is empty';
      for (const range of set.matchAll(/(.)-(.)/g)) {
        if (range[1] > range[2]) return `the range '${range[0]}' is reversed`;
      }
      inClass = false;
    }
  }
  if (inClass) return "'[' has no matching ']'";
  return null;
}

function checkEnvNames(ctx, node) {
  const env = node.get('env', true);
  if (!isMap(env)) return;
  for (const pair of env.items) {
    const name = scalarString(pair.key);
    if (name !== null && !ENV_NAME.test(name)) {
      report(ctx, 'workflow-check/invalid-env-name', pair.key, 0, `Environment variable name '${name}' must match ${ENV_NAME.source}`);
    }
  }
}

async function checkActionInputs(ctx, step, uses, usesNode) {
  if (uses.startsWith('docker://')) return;
  const metadata = await readActionMetadata(ctx, uses, usesNode);
  if (!metadata) return;
  const withNode = step.get('with', true);
  if (!isMap(withNode)) return;
  const allowed = new Set(metadata.inputs);
  if (metadata.docker) {
    allowed.add('args');
    allowed.add('entrypoint');
  }
  for (const pair of withNode.items) {
    const name = scalarString(pair.key);
    if (name !== null && !allowed.has(name.toLowerCase())) {
      report(ctx, 'workflow-check/unknown-action-input', pair.key, 0, `'${name}' is not an input of ${uses.split('@')[0]}`);
    }
  }
}

async function checkReusableWorkflowCall(ctx, job, uses) {
  const usesNode = job.get('uses', true);
  const content = await readUsedFile(ctx, uses, usesNode, null);
  if (content === undefined) return;
  const callee = parseDocument(content);
  const call = isMap(callee.contents) ? callee.contents.getIn(['on', 'workflow_call'], true) : null;
  for (const [section, label] of [['inputs', 'input'], ['secrets', 'secret']]) {
    const declared = isMap(call) ? call.get(section, true) : null;
    const declaredNames = mapKeys(declared);
    const passed = job.get(section === 'inputs' ? 'with' : 'secrets', true);
    const passedNames = new Set();
    if (isMap(passed)) {
      for (const pair of passed.items) {
        const name = scalarString(pair.key);
        if (name === null) continue;
        passedNames.add(name.toLowerCase());
        if (!declaredNames.has(name.toLowerCase())) {
          report(ctx, 'workflow-check/unknown-action-input', pair.key, 0, `'${name}' is not a declared ${label} of ${uses.split('@')[0]}`);
        }
      }
    }
    if (section === 'secrets' && scalarString(passed) === 'inherit') continue;
    if (isMap(declared)) {
      for (const pair of declared.items) {
        const name = scalarString(pair.key);
        const spec = pair.value;
        const required = isMap(spec) && spec.get('required') === true && (section === 'secrets' || !spec.has('default'));
        if (name && required && !passedNames.has(name.toLowerCase())) {
          report(ctx, 'workflow-check/missing-required-input', usesNode, 0, `Required ${label} '${name}' of ${uses.split('@')[0]} is not passed`);
        }
      }
    }
  }
}

async function readActionMetadata(ctx, uses, usesNode) {
  const content = await readUsedFile(ctx, uses, usesNode, ['action.yml', 'action.yaml']);
  if (content === undefined) return null;
  const doc = parseDocument(content);
  const root = doc.contents;
  if (!isMap(root)) return null;
  const runs = root.get('runs', true);
  const using = isMap(runs) ? scalarString(runs.get('using', true)) : null;
  return { inputs: [...mapKeys(root.get('inputs', true))], docker: using === 'docker' };
}

// Reads a same-repository (`./` or `$/`) or SHA-pinned remote action or
// workflow file. Returns undefined when it cannot be read (and reports why), or
// when the reference is not pinned to a commit, which the pinning check owns.
async function readUsedFile(ctx, uses, usesNode, actionFiles) {
  const { repoRoot, fetchText, cacheDir } = ctx.options;
  if (uses.startsWith('./') || uses.startsWith('$/')) {
    const base = join(repoRoot, uses.slice(2));
    for (const candidate of actionFiles ? actionFiles.map((name) => join(base, name)) : [base]) {
      if (existsSync(candidate)) return readFileSync(candidate, 'utf8');
    }
    report(ctx, 'workflow-check/action-metadata-unavailable', usesNode, 0, `${uses} has no ${actionFiles ? 'action.yml' : 'workflow file'} in this repository`);
    return undefined;
  }
  const match = REMOTE_USES.exec(uses);
  if (!match || !/^[0-9a-f]{40}$/.test(match.groups.ref)) return undefined;
  const { owner, repo, ref } = match.groups;
  const path = (match.groups.path ?? '').replace(/^\//, '');
  const candidates = actionFiles ? actionFiles.map((name) => (path ? `${path}/${name}` : name)) : [path];
  for (const file of candidates) {
    const cacheFile = cacheDir ? join(cacheDir, owner, repo, ref, file) : null;
    if (cacheFile && existsSync(cacheFile)) return readFileSync(cacheFile, 'utf8');
    const text = fetchText ? await memoizedFetch(fetchText, `https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${file}`) : null;
    if (typeof text === 'string') {
      if (cacheFile) {
        mkdirSync(dirname(cacheFile), { recursive: true });
        writeFileSync(cacheFile, text);
      }
      return text;
    }
  }
  report(ctx, 'workflow-check/action-metadata-unavailable', usesNode, 0, `Could not read ${candidates.join(' or ')} from ${owner}/${repo} at ${ref.slice(0, 12)}, so its inputs were not verified`);
  return undefined;
}

/**
 * Fetches text over HTTPS, returning null for a 404 and throwing for other failures.
 * @param {string} url
 */
export async function fetchTextFromGitHub(url) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await fetch(url, { redirect: 'error' });
      if (response.status === 404) return null;
      if (response.ok) return await response.text();
    } catch {
      // Retried below.
    }
    await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
  }
  return null;
}

function report(ctx, ruleId, node, index, message) {
  const position = positionOf(ctx, node, index);
  ctx.findings.push({ ruleId, level: 'error', message, file: ctx.path, line: position.line, column: position.column });
}

function positionOf(ctx, node, index) {
  const start = ctx.lineCounter.linePos(node.range?.[0] ?? 0);
  const value = typeof node.value === 'string' ? node.value : '';
  const before = value.slice(0, index);
  const newlines = (before.match(/\n/g) ?? []).length;
  const lastNewline = before.lastIndexOf('\n');
  if (node.type === 'BLOCK_LITERAL' || node.type === 'BLOCK_FOLDED') {
    const firstContent = ctx.lines.slice(start.line).find((line) => line.trim() !== '') ?? '';
    const indent = firstContent.length - firstContent.trimStart().length;
    return { line: start.line + 1 + newlines, column: indent + 1 + (index - lastNewline - 1) };
  }
  const quote = node.type === 'QUOTE_DOUBLE' || node.type === 'QUOTE_SINGLE' ? 1 : 0;
  return newlines ? { line: start.line + newlines, column: index - lastNewline } : { line: start.line, column: start.col + quote + index };
}

function visitScalars(node, key, callback) {
  if (isScalar(node)) {
    callback(node, key);
  } else if (isMap(node)) {
    for (const pair of node.items) visitScalars(pair.value, scalarString(pair.key), callback);
  } else if (isSeq(node)) {
    for (const item of node.items) visitScalars(item, key, callback);
  }
}

function maskStringLiterals(expression) {
  return expression.replace(/'(?:[^']|'')*'/g, (literal) => ' '.repeat(literal.length));
}

function workflowInputNames(on) {
  const names = new Set();
  if (!isMap(on)) return names;
  for (const event of ['workflow_call', 'workflow_dispatch']) {
    const trigger = on.get(event, true);
    if (isMap(trigger)) for (const name of mapKeys(trigger.get('inputs', true))) names.add(name);
  }
  return names;
}

function stepIds(steps) {
  const ids = new Set();
  if (!isSeq(steps)) return ids;
  for (const step of steps.items) {
    const id = isMap(step) ? scalarString(step.get('id', true)) : null;
    if (id) ids.add(id.toLowerCase());
  }
  return ids;
}

function needsList(node) {
  if (isScalar(node) && typeof node.value === 'string') return new Set([node.value.toLowerCase()]);
  if (isSeq(node)) return new Set(node.items.map((item) => scalarString(item)?.toLowerCase()).filter(Boolean));
  return new Set();
}

// Returns the matrix keys, null when the job has no matrix, or undefined when
// the matrix is computed by an expression and its keys are unknown.
function matrixKeys(strategy) {
  if (!isMap(strategy)) return null;
  const matrix = strategy.get('matrix', true);
  if (matrix === undefined || matrix === null) return null;
  if (!isMap(matrix)) return undefined;
  const keys = new Set();
  for (const pair of matrix.items) {
    const name = scalarString(pair.key);
    if (name === null || name.includes('${{')) return undefined;
    if (isScalar(pair.value) && typeof pair.value.value === 'string' && pair.value.value.includes('${{')) {
      if (name !== 'include' && name !== 'exclude') keys.add(name.toLowerCase());
      if (name === 'include') return undefined;
      continue;
    }
    if (name === 'include' && isSeq(pair.value)) {
      for (const entry of pair.value.items) for (const key of mapKeys(entry)) keys.add(key);
    } else if (name !== 'exclude') {
      keys.add(name.toLowerCase());
    }
  }
  return keys;
}

function mapKeys(node) {
  const keys = new Set();
  if (!isMap(node)) return keys;
  for (const pair of node.items) {
    const name = scalarString(pair.key);
    if (name !== null) keys.add(name.toLowerCase());
  }
  return keys;
}

function scalarString(node) {
  return isScalar(node) && typeof node.value === 'string' ? node.value : null;
}
