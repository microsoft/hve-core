// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// validate-topics.mjs
//
// Static topic-integrity linter for a Copilot Studio agent scaffold. This is
// the executable companion to the prose "pre-pack topic-integrity gate": it
// parses the hand-authored (and packed) *.mcs.yml topic files and fails closed
// on the structural defect classes that otherwise only surface at runtime after
// a deploy (unbound tokens, non-schema skeletons, system-trigger collisions,
// duplicate system triggers, componentName/filename drift, topicCount drift).
//
// Usage:
//   node validate-topics.mjs <path> [--state <state.json>] [--json <out.json>]
//                                   [--allow-prefix System,Topic,Global,Env]
//
//   <path>  A scaffold root (auto-discovers workspace/topics/*.mcs.yml and a
//           state.json under **/.copilot-tracking/** or a top-level state.json)
//           OR a directory that directly contains *.mcs.yml files. When both a
//           workspace/topics tree and loose files exist, workspace/topics wins.
//
// Exit codes:
//   0  every topic passes every invariant (and topicCount reconciles)
//   1  one or more topics FAIL, or the topicCount reconciliation fails
//   2  usage / parse / IO error (bad args, unreadable path, YAML syntax error)
//
// Known limitations (accepted for this gate):
//   S-1  The token check validates namespace hygiene (first segment is a known
//        prefix), not declaration — an undeclared {Topic.X} is NOT detected
//        without full variable-declaration tracking.
//   S-3  topicCount reconciles on the OnRecognizedIntent file count, so a stock
//        topic authored with that trigger would inflate the count.
//   S-4  A YAML syntax error forces exit 2, which can mask a co-occurring
//        exit-1 content FAIL in the same run.
//
// cspell:ignore mcs yml yaml Signin

import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, basename, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const HVE_ROOT = process.env.HVE_ROOT || process.cwd();
const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// js-yaml resolution — zero new dependencies. Prefer normal Node resolution
// from this script's location (walks up parent node_modules to the repo root);
// fall back to <HVE_ROOT>/node_modules, then an explicit walk-up from the
// script dir. Never added to any package.json.
// ---------------------------------------------------------------------------
function loadYaml() {
  try { return require('js-yaml'); } catch { /* fall through */ }
  try { return require(join(HVE_ROOT, 'node_modules', 'js-yaml')); } catch { /* fall through */ }
  let dir = SCRIPT_DIR;
  for (let i = 0; i < 12; i++) {
    const candidate = join(dir, 'node_modules', 'js-yaml');
    if (existsSync(candidate)) {
      try { return require(candidate); } catch { /* keep walking */ }
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

const yaml = loadYaml();
if (!yaml) {
  fail2("cannot resolve 'js-yaml' from the repo node_modules; run npm/pnpm install at the repo root, or set HVE_ROOT to the repo that vendors js-yaml");
}

// ---------------------------------------------------------------------------
// System-trigger model. Copilot Studio permits at most one topic per system
// trigger kind, and component identity on `pac copilot pack` derives from
// `componentName` (-> <prefix>.topic.<name>), NOT the filename. A custom topic
// authored with a system trigger kind silently collapses into the built-in
// topic of that kind, so the authored intent vanishes from the deployed agent.
// ---------------------------------------------------------------------------
const CANON = {
  OnConversationStart: { name: 'ConversationStart', display: 'Conversation Start' },
  OnUnknownIntent:     { name: 'Fallback',          display: 'Fallback' },
  OnEscalate:          { name: 'Escalate',          display: 'Escalate' },
  OnError:             { name: 'OnError',           display: 'On Error' },
  OnSignIn:            { name: 'Signin',            display: 'Sign in' },
};
const SYSTEM_TRIGGER_KINDS = new Set(Object.keys(CANON));
const CUSTOM_TRIGGER_KIND = 'OnRecognizedIntent';

// A topic is a *legitimate* system topic only when its trigger kind is a system
// trigger AND its filename basename matches that kind's canonical or display
// name. (componentName is intentionally NOT used to establish legitimacy: a
// componentName that matches the canonical name is precisely the collapse
// mechanism — see Fraud.mcs.yml with componentName `Escalate`.)
function isLegitSystemTopic(triggerKind, base) {
  if (!SYSTEM_TRIGGER_KINDS.has(triggerKind)) return false;
  const c = CANON[triggerKind];
  return base === c.name || base === c.display;
}

// Normalize a topic name for filename<->componentName comparison. pac derives
// filenames from componentName by stripping whitespace and case-folding
// (e.g. "Thank you" -> ThankYou), so the compare must be whitespace- and
// case-insensitive. This still catches genuine drift (fraud != escalate).
const norm = (s) => String(s).replace(/\s+/g, '').toLowerCase();

// ---------------------------------------------------------------------------
// CLI parsing
// ---------------------------------------------------------------------------
function fail2(msg) {
  process.stderr.write(`ERROR: ${msg}\n`);
  process.stderr.write('Usage: node validate-topics.mjs <path> [--state <state.json>] [--json <out.json>] [--allow-prefix System,Topic,Global,Env]\n');
  process.exit(2);
}

function parseArgs(argv) {
  const opts = {
    inputPath: null,
    statePath: null,
    jsonOut: null,
    allowPrefix: ['System', 'Topic', 'Global', 'Env'],
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--state') {
      opts.statePath = argv[++i];
      if (opts.statePath == null) fail2('--state requires a value');
    } else if (a === '--json') {
      opts.jsonOut = argv[++i];
      if (opts.jsonOut == null) fail2('--json requires a value');
    } else if (a === '--allow-prefix') {
      const v = argv[++i];
      if (v == null) fail2('--allow-prefix requires a value');
      opts.allowPrefix = v.split(',').map((s) => s.trim()).filter(Boolean);
    } else if (a === '-h' || a === '--help') {
      fail2('help requested');
    } else if (a.startsWith('--')) {
      fail2(`unknown option: ${a}`);
    } else if (opts.inputPath === null) {
      opts.inputPath = a;
    } else {
      fail2(`unexpected extra argument: ${a}`);
    }
  }
  if (!opts.inputPath) fail2('missing required <path> argument');
  return opts;
}

// ---------------------------------------------------------------------------
// Discovery helpers
// ---------------------------------------------------------------------------
function isDir(p) {
  try { return statSync(p).isDirectory(); } catch { return false; }
}

function mcsFilesIn(dir) {
  return readdirSync(dir)
    .filter((n) => n.toLowerCase().endsWith('.mcs.yml'))
    .sort()
    .map((n) => join(dir, n));
}

function dirHasMcs(dir) {
  return isDir(dir) && mcsFilesIn(dir).length > 0;
}

// Bounded recursive search for a `<...>/workspace/topics` directory holding
// *.mcs.yml files. Skips node_modules and VCS dirs. Returns the first match.
function findWorkspaceTopics(root, maxDepth = 6) {
  const stack = [{ dir: root, depth: 0 }];
  while (stack.length) {
    const { dir, depth } = stack.pop();
    const wt = join(dir, 'workspace', 'topics');
    if (dirHasMcs(wt)) return wt;
    if (depth >= maxDepth) continue;
    let entries = [];
    try { entries = readdirSync(dir, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      if (e.name === 'node_modules' || e.name === '.git') continue;
      stack.push({ dir: join(dir, e.name), depth: depth + 1 });
    }
  }
  return null;
}

// Find the first state.json under `root` living inside a `.copilot-tracking`
// directory; otherwise a top-level `<root>/state.json`. Only searches *under*
// the given path (never walks upward), so pointing at a bare topics directory
// deliberately yields no state and skips reconciliation.
function findState(root, maxDepth = 8) {
  const stack = [{ dir: root, depth: 0 }];
  while (stack.length) {
    const { dir, depth } = stack.pop();
    let entries = [];
    try { entries = readdirSync(dir, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      const full = join(dir, e.name);
      if (e.isFile() && e.name === 'state.json' && full.split(sep).includes('.copilot-tracking')) {
        return full;
      }
    }
    if (depth >= maxDepth) continue;
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      if (e.name === 'node_modules' || e.name === '.git') continue;
      stack.push({ dir: join(dir, e.name), depth: depth + 1 });
    }
  }
  const top = join(root, 'state.json');
  return existsSync(top) ? top : null;
}

function resolveTopicSet(inputPath) {
  const abs = resolve(inputPath);
  if (!existsSync(abs)) fail2(`path not found: ${abs}`);
  if (!isDir(abs)) fail2(`path is not a directory: ${abs}`);

  // 1. Prefer an immediate workspace/topics.
  const immediate = join(abs, 'workspace', 'topics');
  if (dirHasMcs(immediate)) return { topicsDir: immediate, files: mcsFilesIn(immediate), root: abs };

  // 2. Otherwise search for a workspace/topics tree beneath the root.
  const found = findWorkspaceTopics(abs);
  if (found) return { topicsDir: found, files: mcsFilesIn(found), root: abs };

  // 3. Otherwise treat the path itself as a directory of *.mcs.yml files.
  if (dirHasMcs(abs)) return { topicsDir: abs, files: mcsFilesIn(abs), root: abs };

  fail2(`no *.mcs.yml topic files found under ${abs}`);
  return null; // unreachable
}

// ---------------------------------------------------------------------------
// Token scanning — recurse every string scalar in the parsed document.
// {...} tokens must resolve to a declared variable namespace (the allow-prefix
// set). Power Fx expressions (scalars beginning with `=`) are not {} tokens and
// are never scanned.
// ---------------------------------------------------------------------------
const TOKEN_RE = /\{([^{}]+)\}/g;

function* walkStrings(node, seen = new WeakSet()) {
  if (node == null) return;
  if (typeof node === 'string') { yield node; return; }
  if (typeof node !== 'object') return;
  if (seen.has(node)) return;            // cyclic anchor/alias guard
  seen.add(node);
  if (Array.isArray(node)) { for (const v of node) yield* walkStrings(v, seen); return; }
  for (const k of Object.keys(node)) yield* walkStrings(node[k], seen);
}

// A real mcs variable reference is a dotted identifier path: {balance},
// {System.Bot.Name}, {Topic.Answer}. Serialized Adaptive-Card JSON bodies and
// prose with braces are NOT variable refs and must not be flagged. We (a) skip
// the mcs.metadata subtree (authoring metadata, never runtime-interpolated) and
// (b) only treat a {...} whose inner text is an identifier path as a candidate.
const VAR_TOKEN_RE = /^[A-Za-z_][\w]*(\s*\.\s*[A-Za-z_][\w]*)*$/;

function findUndeclaredTokens(doc, allowSet) {
  const bad = new Set();
  const scanTarget = (doc && typeof doc === 'object' && !Array.isArray(doc))
    ? Object.fromEntries(Object.entries(doc).filter(([k]) => k !== 'mcs.metadata'))
    : doc;
  for (const s of walkStrings(scanTarget)) {
    if (s.trim().startsWith('=')) continue; // Power Fx expression, not a token
    TOKEN_RE.lastIndex = 0;
    let m;
    while ((m = TOKEN_RE.exec(s)) !== null) {
      const inner = m[1].trim();
      if (!VAR_TOKEN_RE.test(inner)) continue; // JSON/card/prose brace, not a var ref
      const firstSegment = inner.split('.')[0].trim();
      if (!allowSet.has(firstSegment)) bad.add(`{${m[1]}}`);
    }
  }
  return [...bad];
}

// ---------------------------------------------------------------------------
// Per-topic validation (structural + token invariants). Cross-topic invariants
// (duplicate system triggers, componentName uniqueness) are applied afterwards
// over the whole set.
// ---------------------------------------------------------------------------
function validateTopic(file, allowSet) {
  const base = basename(file).replace(/\.mcs\.yml$/i, '');
  const result = {
    file: basename(file),
    path: file,
    base,
    componentName: null,
    triggerKind: null,
    isSystemTrigger: false,
    isLegitSystem: false,
    parseError: false,
    fails: [],   // { invariant, message }
    warns: [],   // { invariant, message }
  };

  let text;
  try { text = readFileSync(file, 'utf8'); }
  catch (e) { result.fails.push({ invariant: 'io', message: `cannot read file: ${e.message}` }); return result; }

  let doc;
  try { doc = yaml.load(text); }
  catch (e) {
    result.parseError = true;
    result.fails.push({ invariant: 'schema-parse', message: `YAML parse error: ${e.message}` });
    return result;
  }
  if (doc == null || typeof doc !== 'object') {
    result.fails.push({ invariant: 'schema-skeleton', message: 'file does not parse to a mapping' });
    return result;
  }

  try {
  const meta = doc['mcs.metadata'];
  const componentName = meta && typeof meta === 'object' ? meta.componentName : undefined;
  const topKind = doc.kind;
  const bd = doc.beginDialog;
  const triggerKind = bd && typeof bd === 'object' ? bd.kind : undefined;
  const bdId = bd && typeof bd === 'object' ? bd.id : undefined;

  result.componentName = (typeof componentName === 'string' && componentName.length) ? componentName : null;
  result.triggerKind = (typeof triggerKind === 'string' && triggerKind.length) ? triggerKind : null;
  result.isSystemTrigger = SYSTEM_TRIGGER_KINDS.has(result.triggerKind);
  result.isLegitSystem = isLegitSystemTopic(result.triggerKind, base);

  // (1) schema-skeleton -----------------------------------------------------
  const skeletonMisses = [];
  if (!result.componentName) skeletonMisses.push('mcs.metadata.componentName');
  if (topKind !== 'AdaptiveDialog') skeletonMisses.push('kind: AdaptiveDialog');
  if (!result.triggerKind) skeletonMisses.push('beginDialog.kind');
  if (bdId !== 'main') skeletonMisses.push('beginDialog.id: main');
  if (skeletonMisses.length) {
    result.fails.push({ invariant: 'schema-skeleton', message: `missing/invalid: ${skeletonMisses.join(', ')}` });
  }
  if (meta && typeof meta === 'object' && (typeof meta.description !== 'string' || !meta.description.length)) {
    result.warns.push({ invariant: 'schema-skeleton', message: 'mcs.metadata.description missing' });
  }

  // (2) undeclared-tokens ---------------------------------------------------
  const badTokens = findUndeclaredTokens(doc, allowSet);
  if (badTokens.length) {
    result.fails.push({ invariant: 'undeclared-tokens', message: `undeclared token(s): ${badTokens.join(', ')}` });
  }

  // (3) system-trigger-collision -------------------------------------------
  if (result.isSystemTrigger && !result.isLegitSystem) {
    const canon = CANON[result.triggerKind].name;
    result.fails.push({
      invariant: 'system-trigger-collision',
      message: `custom topic '${result.file}' uses system trigger kind '${result.triggerKind}' -> will collapse into the built-in '${canon}' topic on pack`,
    });
  }

  // (3b) reserved-name collision -------------------------------------------
  // A non-system-trigger (custom) topic whose componentName matches a built-in
  // system topic name collapses into that built-in on `pac copilot pack` —
  // component identity derives from componentName. Fires independent of filename
  // and of whether the real stock topic is present in this validated set.
  if (!result.isSystemTrigger && result.componentName) {
    const cn = norm(result.componentName);
    const hit = Object.values(CANON).find((c) => norm(c.name) === cn || norm(c.display) === cn);
    if (hit) {
      result.fails.push({
        invariant: 'reserved-name-collision',
        message: `custom topic '${result.file}' has componentName '${result.componentName}' which collapses into the built-in '${hit.name}' topic on pack`,
      });
    }
  }

  // (5a) filename == componentName (custom + masquerading topics only) ------
  if (!result.isLegitSystem && result.componentName && norm(base) !== norm(result.componentName)) {
    result.fails.push({
      invariant: 'filename-mismatch',
      message: `filename '${base}' != componentName '${result.componentName}'`,
    });
  }

  return result;
  } catch (e) {
    result.fails.push({ invariant: 'internal-error', message: `unexpected error while validating: ${e && e.message ? e.message : e}` });
    return result;
  }
}

// Cross-topic: (4) at most one topic per system trigger kind.
function applyDuplicateSystemTrigger(results) {
  const byKind = new Map();
  for (const r of results) {
    if (!r.isSystemTrigger) continue;
    if (!byKind.has(r.triggerKind)) byKind.set(r.triggerKind, []);
    byKind.get(r.triggerKind).push(r);
  }
  for (const [kind, group] of byKind) {
    if (group.length > 1) {
      const names = group.map((g) => g.file).join(', ');
      for (const r of group) {
        r.fails.push({
          invariant: 'duplicate-system-trigger',
          message: `system trigger kind '${kind}' is defined by ${group.length} topics (${names}); at most one is allowed`,
        });
      }
    }
  }
}

// Cross-topic: (5b) componentName uniqueness.
function applyComponentNameUniqueness(results) {
  const byName = new Map();
  for (const r of results) {
    if (!r.componentName) continue;
    if (!byName.has(r.componentName)) byName.set(r.componentName, []);
    byName.get(r.componentName).push(r);
  }
  for (const [name, group] of byName) {
    if (group.length > 1) {
      const files = group.map((g) => g.file).join(', ');
      for (const r of group) {
        r.fails.push({
          invariant: 'componentName-uniqueness',
          message: `componentName '${name}' is shared by ${group.length} topics (${files})`,
        });
      }
    }
  }
}

// Scaffold-level: (6) topicCount reconciliation.
function reconcileTopicCount(statePath, results) {
  let state;
  try { state = JSON.parse(readFileSync(statePath, 'utf8')); }
  catch (e) { return { ok: false, error: `cannot read/parse state.json: ${e.message}`, statePath }; }

  const recorded = state?.phases?.topics?.topicCount;
  const customCount = results.filter((r) => r.triggerKind === CUSTOM_TRIGGER_KIND).length;
  if (recorded === undefined || recorded === null) {
    return { ok: true, warn: true, recorded: null, customCount, statePath,
             message: 'state.phases.topics.topicCount is absent; reconciliation skipped' };
  }
  const coerced = typeof recorded === 'number' ? recorded : Number(recorded);
  if (!Number.isFinite(coerced)) {
    return { ok: false, error: `state.phases.topics.topicCount present but non-numeric (${JSON.stringify(recorded)}); cannot reconcile`, statePath };
  }
  return {
    ok: coerced === customCount,
    recorded: coerced,
    customCount,
    statePath,
    message: `state.phases.topics.topicCount=${recorded} vs custom (${CUSTOM_TRIGGER_KIND}) topic files=${customCount}`,
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function main() {
  const opts = parseArgs(process.argv.slice(2));
  const allowSet = new Set(opts.allowPrefix);
  const { topicsDir, files, root } = resolveTopicSet(opts.inputPath);

  const results = files.map((f) => validateTopic(f, allowSet));
  applyDuplicateSystemTrigger(results);
  applyComponentNameUniqueness(results);

  // Reconciliation: explicit --state wins; else auto-discover under the root.
  let statePath = null;
  if (opts.statePath) {
    if (!existsSync(opts.statePath)) fail2(`--state file not found: ${opts.statePath}`);
    statePath = opts.statePath;
  } else {
    statePath = findState(root);
  }
  const reconciliation = statePath ? reconcileTopicCount(statePath, results) : null;

  // Reporting ---------------------------------------------------------------
  process.stdout.write(`Topic-integrity gate — ${topicsDir}\n`);
  let passCount = 0;
  let parseError = false;
  for (const r of results) {
    if (r.parseError) parseError = true;
    const passed = r.fails.length === 0;
    if (passed) passCount++;
    const invariants = [...new Set(r.fails.map((x) => x.invariant))];
    process.stdout.write(`${passed ? 'PASS' : 'FAIL'}  ${r.file}${invariants.length ? `  [${invariants.join(', ')}]` : ''}\n`);
    for (const f of r.fails) process.stdout.write(`        ${f.invariant}: ${f.message}\n`);
    for (const w of r.warns) process.stdout.write(`        warn ${w.invariant}: ${w.message}\n`);
  }

  const failCount = results.length - passCount;

  let reconciliationFailed = false;
  if (reconciliation) {
    if (reconciliation.error) {
      // A state.json was found/provided but could not be parsed. Fail closed:
      // reconciliation cannot be verified, so the gate must not go green.
      reconciliationFailed = true;
      process.stdout.write(`SCAFFOLD FAIL  topicCount-reconciliation: ${reconciliation.error}\n`);
    } else if (reconciliation.warn) {
      process.stdout.write(`SCAFFOLD WARN  topicCount-reconciliation: ${reconciliation.message}\n`);
    } else if (!reconciliation.ok) {
      reconciliationFailed = true;
      process.stdout.write(`SCAFFOLD FAIL  topicCount-reconciliation: ${reconciliation.message}\n`);
    } else {
      process.stdout.write(`SCAFFOLD PASS  topicCount-reconciliation: ${reconciliation.message}\n`);
    }
  } else {
    process.stdout.write('SCAFFOLD ----  topicCount-reconciliation: no state.json found (skipped)\n');
  }

  process.stdout.write(`\n${results.length} topics, ${passCount} pass, ${failCount} fail`);
  process.stdout.write(reconciliationFailed ? ' + topicCount-reconciliation FAIL\n' : '\n');

  // JSON output -------------------------------------------------------------
  if (opts.jsonOut) {
    const payload = {
      target: topicsDir,
      summary: { topics: results.length, pass: passCount, fail: failCount, reconciliationFailed },
      reconciliation,
      results: results.map((r) => ({
        file: r.file,
        pass: r.fails.length === 0,
        componentName: r.componentName,
        triggerKind: r.triggerKind,
        fails: r.fails,
        warns: r.warns,
      })),
    };
    try { writeFileSync(opts.jsonOut, JSON.stringify(payload, null, 2)); }
    catch (e) { fail2(`cannot write --json output: ${e.message}`); }
  }

  if (parseError) process.exit(2);
  process.exit(failCount > 0 || reconciliationFailed ? 1 : 0);
}

try {
  main();
} catch (e) {
  process.stderr.write(`validate-topics: unexpected error: ${e && e.stack ? e.stack : e}\n`);
  process.exit(2);
}
