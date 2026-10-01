// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, 'content.js'), 'utf8'), context);
vm.runInContext(fs.readFileSync(path.join(__dirname, 'components.js'), 'utf8'), context);
const { sources, examples, demos, moveStep, diffStats, depthTier } = context.DeckContent;
const { kinds } = context.DeckComponents;
const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const snapshot = '7e2de1aa135133acc4e9592adffc220cad9bdfdf';

test('slides have unique IDs, headings, chapters, notes and valid citation keys', () => {
  const slides = [...html.matchAll(/<section\b([^>]*)>([\s\S]*?)<\/section>/g)];
  assert.ok(slides.length > 0);
  const ids = new Set();
  for (const [, attributes, body] of slides) {
    const id = attributes.match(/\bid="([^"]+)"/)?.[1];
    assert.ok(id && !ids.has(id));
    ids.add(id);
    assert.match(attributes, /data-title="[^"]+"/);
    assert.match(attributes, /data-chapter="[^"]+"/);
    assert.match(body, /<h[12]\b/);
    assert.match(body, /class="notes"/);
    for (const source of (attributes.match(/data-sources="([^"]*)"/)?.[1] || '').split(',').filter(Boolean)) {
      assert.ok(sources[source], source);
      assert.ok(['https:', 'http:'].includes(new URL(sources[source].url).protocol));
    }
  }
});

test('example mounts and walkthrough contracts match their data', () => {
  for (const [, name] of html.matchAll(/data-example="([^"]+)"/g)) {
    assert.ok(examples[name], name);
    assert.ok(kinds.includes(examples[name].kind), examples[name].kind);
    assert.ok(examples[name].caption.trim(), name);
  }
  const hosts = [...html.matchAll(/data-demo="([^"]+)"/g)].map(match => match[1]);
  assert.deepEqual(hosts, ['assess', 'extend']);
  assert.deepEqual(Object.keys(demos).sort(), [...hosts].sort());
  for (const name of hosts) {
    const demo = demos[name];
    assert.ok(demo?.steps.length);
    assert.equal(new Set(demo.phases).size, demo.phases.length);
    for (const phase of demo.phases) assert.ok(demo.steps.some(step => step.phase === phase), `${name} phase ${phase} has no step`);
    let lastPhase = 0;
    for (const step of demo.steps) {
      assert.ok(demo.phases.includes(step.phase));
      assert.ok(demo.phases.indexOf(step.phase) >= lastPhase, `${name} steps move backward at ${step.title}`);
      lastPhase = demo.phases.indexOf(step.phase);
      assert.ok(kinds.includes(step.kind), step.kind);
      for (const field of ['kind', 'title', 'state', 'insight', 'caption']) assert.ok(typeof step[field] === 'string' && step[field].trim(), `${step.title}: ${field}`);
    }
  }
});

test('scripted chat steps use supported roles, blocks and checklist statuses', () => {
  const chats = Object.values(demos).flatMap(demo => demo.steps).filter(step => step.kind === 'chat');
  assert.ok(chats.length > 0);
  for (const step of chats) {
    assert.ok(step.messages.length > 0);
    for (const message of step.messages) {
      assert.ok(['user', 'assistant'].includes(message.role));
      assert.ok(message.author.trim());
      for (const block of message.blocks) {
        assert.ok(['text', 'note', 'code', 'callout', 'list', 'checklist'].includes(block.type), block.type);
        if (block.type === 'checklist') for (const item of block.items) assert.ok(['done', 'pending', 'skipped'].includes(item.status));
      }
    }
  }
});

test('the use walkthrough stays within the planner question limit and gate order', () => {
  const steps = demos.assess.steps;
  const scoping = steps.find(step => step.phase === 'Scope');
  const questions = scoping.messages.flatMap(message => message.blocks).filter(block => block.type === 'checklist')
    .flatMap(block => block.items).filter(item => item.status === 'pending');
  assert.ok(questions.length >= 1 && questions.length <= 7);
  const start = steps.filter(step => step.phase === 'Start').map(step => JSON.stringify(step));
  assert.ok(start.some(text => text.includes('CAUTION')) && start.some(text => text.includes('NIST AI Risk Management Framework 1.0')));
  const risk = JSON.stringify(steps.find(step => step.phase === 'Risk'));
  assert.ok(risk.indexOf('Prohibited uses gate') < risk.indexOf('safety_reliability'));
  assert.match(steps.find(step => step.phase === 'Threats').body, /T-RAI-001/);
});

test('walkthrough boundaries clamp, reset and reject malformed state', () => {
  assert.equal(moveStep(0, 'back', 4), 0);
  assert.equal(moveStep(3, 'next', 4), 3);
  assert.equal(moveStep(2, 'reset', 4), 0);
  assert.equal(moveStep(0, 'next', 1), 0);
  assert.throws(() => moveStep(0, 'next', 0), /Invalid/);
  assert.throws(() => moveStep(8, 'next', 4), /Invalid/);
  assert.throws(() => moveStep(0, 'unknown', 4), /Unknown/);
  const states = { first: 2, second: 1 };
  states.first = moveStep(states.first, 'reset', 4);
  assert.equal(states.second, 1);
});

test('walkthrough step announcements coalesce after focus settles', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  // A step announcement written in the same task as the focus move is superseded
  // before it is spoken, and a superseded step must not announce at all.
  assert.match(source, /if \(pendingAnnouncement\) clearTimeout\(pendingAnnouncement\)/);
  assert.match(source, /if \(states\.get\(name\) !== index\) return/);
  assert.match(source, /deck\.getCurrentSlide\(\)\.querySelector\('\[data-demo\]'\)\?\.dataset\.demo !== name/);
  assert.doesNotMatch(source, /if \(speak\) announce\(/);
});

test('dialog Escape closes without relying on the browser close request', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  // Escape must be handled before the Tab-only focus trap returns early.
  assert.match(source, /dialog\.addEventListener\('keydown', event => \{\s*if \(event\.key === 'Escape'\) \{[^}]*event\.preventDefault\(\);[^}]*dialog\.close\(\);[^}]*return;\s*\}\s*if \(event\.key !== 'Tab'\) return;/);
});

test('fullscreen state and forced-colors behavior are part of the starter contract', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  const theme = fs.readFileSync(path.join(__dirname, 'theme.css'), 'utf8');
  assert.match(html, /id="fullscreen-button" aria-pressed="false"/);
  assert.match(source, /addEventListener\('fullscreenchange'/);
  assert.match(source, /setAttribute\('aria-pressed', String\(active\)\)/);
  assert.match(source, /fullscreenInitiator \|\| fullscreenButton/);
  assert.match(theme, /@media \(forced-colors: active\)/);
  assert.match(theme, /ButtonFace/);
  assert.match(theme, /Highlight/);
});

test('arrow and Page keys page from focused controls but not from text entry or a slide selection', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  // Paging is decided before the focused-control guard, so a clicked presenter button does not end keyboard paging.
  const selectionGuard = source.indexOf('if (globalThis.getSelection()?.toString() && !onButtonOrLink) return;');
  const textEntryGuard = source.search(/if \(target\?\.closest\('input, textarea, select, \[contenteditable[^'\]]*\]'\)\) return;/);
  const paging = source.indexOf('if (Object.hasOwn(pagingKeys, key))');
  const controlGuard = source.indexOf("if (target?.closest('button, a, summary')) return;");
  assert.ok(selectionGuard > -1 && textEntryGuard > selectionGuard && paging > textEntryGuard && controlGuard > paging);
  assert.match(source, /const pagingKeys = \{ arrowright: 1, pagedown: 1, arrowleft: -1, pageup: -1 \}/);
  // Only a focused button or link overrides a text selection; other shortcuts also wait on a summary.
  assert.match(source, /const onButtonOrLink = Boolean\(target\?\.closest\('button, a'\)\);/);
  assert.match(source, /if \(!ready \|\| dialog\.open \|\| event\.defaultPrevented/);
});

test('presenter bar ends stay clear of viewer overlays', () => {
  const theme = fs.readFileSync(path.join(__dirname, 'theme.css'), 'utf8');
  assert.match(theme, /--presenter-inset: clamp\(96px, 8vw, 128px\);/);
  assert.match(theme, /#presenter-controls \{[^}]*padding: \S+ var\(--presenter-inset\);/);
  assert.match(theme, /\[data-reading-view="true"\] body \{[^}]*padding-bottom: var\(--presenter-inset\);/);
});

test('deck initialization disables the unused cross-window API', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  assert.match(source, /postMessage:\s*false/);
  assert.match(source, /postMessageEvents:\s*false/);
  assert.match(source, /setAttribute\('aria-roledescription', 'presentation'\)/);
  assert.match(source, /setAttribute\('aria-roledescription', 'slide'\)/);
  assert.match(source, /setAttribute\('aria-label', `\$\{section\.dataset\.title\}, \$\{index \+ 1\} of \$\{sections\.length\}`\)/);
  assert.match(source, /setAttribute\('aria-current', 'page'\)/);
  assert.match(source, /section\.inert = section !== current/);
});

test('the review correction matches the drafted instruction and keeps NIST active', () => {
  const steps = demos.extend.steps;
  const review = steps.find(step => step.kind === 'review');
  const draft = steps.find(step => step.kind === 'code' && step.file.endsWith('woodgrove-rai.instructions.md'));
  const stats = diffStats(review.diff);
  assert.equal(stats.added, 2);
  assert.equal(stats.removed, 2);
  for (const row of review.diff.filter(row => row.type !== 'add')) assert.ok(draft.body.includes(row.text), row.text);
  assert.match(draft.body, /applyTo: '\*\*\/\.copilot-tracking\/rai-plans\/\*\*'/);
  const result = steps.at(-1);
  assert.match(result.body, /"replaceDefaultFramework": false/);
  assert.match(result.body, /"type": "standard"/);
  assert.match(result.body, /"type": "prohibited-use-framework"/);
  const skill = steps.find(step => step.kind === 'code' && step.file.endsWith('/SKILL.md'));
  const name = skill.body.match(/^name: (.+)$/m)[1];
  assert.equal(skill.file.split('/').at(-2), name);
  assert.match(name, /^[a-z0-9]+(?:-[a-z0-9]+)*$/);
  assert.throws(() => diffStats([{ type: 'invalid', text: '' }]), /Invalid/);
});

test('depth tier follows the activated indicator count', () => {
  assert.equal(depthTier(0), 'basic');
  assert.equal(depthTier(1), 'standard');
  assert.equal(depthTier(2), 'comprehensive');
  assert.equal(depthTier(3), 'comprehensive');
  for (const invalid of [-1, 1.5, 4, '2']) assert.throws(() => depthTier(invalid), /Invalid/);
  const { indicators, tiers } = examples.tier;
  assert.deepEqual(Array.from(indicators, item => `${item.name}:${item.method}`), [
    'safety_reliability:binary', 'rights_fairness_privacy:categorical', 'security_explainability:continuous'
  ]);
  assert.deepEqual(Array.from(tiers, tier => tier.name), ['basic', 'standard', 'comprehensive']);
});

test('repository citations are pinned to the source snapshot', () => {
  const pinned = Object.entries(sources).filter(([, source]) => /github\.com\/microsoft\/hve-core\/(?:blob|tree)\//.test(source.url));
  assert.ok(pinned.length > 20);
  for (const [key, source] of pinned) assert.ok(source.url.includes(`/${snapshot}/`) || source.url.endsWith(`/${snapshot}`) || source.url.endsWith(`/${snapshot}/`), key);
  for (const [key, source] of Object.entries(sources)) {
    assert.ok(source.title.trim() && source.note.trim(), key);
    assert.equal(new URL(source.url).protocol, 'https:', key);
  }
  const used = new Set([...html.matchAll(/data-sources="([^"]*)"/g)].flatMap(match => match[1].split(',')));
  for (const key of Object.keys(sources)) assert.ok(used.has(key), `Unused source: ${key}`);
});

test('configuration serialization rejects missing fields and escapes HTML delimiters', async () => {
  const { configScript } = await import('./build.mjs');
  assert.throws(() => configScript({ title: 'Example' }), /description/);
  const title = 'An example </script> <!-- title';
  const script = configScript({ title, description: 'Description', sourceNote: 'Example source' });
  assert.doesNotMatch(script, /<\/script|<!--/);
  const target = vm.createContext({});
  vm.runInContext(script, target);
  assert.equal(target.DeckConfig.title, title);
});

test('bundler preserves script order after markup and rejects unsupported resources', async () => {
  const { createStandaloneHtml } = await import('./bundle.mjs');
  const page = '<html><head><link rel="stylesheet" href="theme.css"><script defer src="content.js"></script><script defer src="deck.js"></script></head><body><main></main></body></html>';
  const assets = new Map([['theme.css', 'body { color: white; }'], ['content.js', 'globalThis.data = 1;'], ['deck.js', 'globalThis.ready = data;']]);
  const result = createStandaloneHtml(page, assets, 'Fixture notice');
  assert.ok(result.indexOf('<script data-bundled-source="content.js">') > result.indexOf('</main>'));
  assert.ok(result.indexOf('<script data-bundled-source="deck.js">') > result.indexOf('<script data-bundled-source="content.js">'));
  assert.doesNotMatch(result, /<script[^>]+\bsrc=|<link\b/);
  assert.match(result, /bundled-third-party-notices/);
  assert.throws(() => createStandaloneHtml(page, new Map(), 'Fixture'), /Missing bundle asset/);
  assert.throws(() => createStandaloneHtml(page, assets, ''), /license is required/);
  for (const css of ['@import "extra.css";', 'a { background: url(extra.png); }', '/* </STYLE> */']) {
    assert.throws(() => createStandaloneHtml(page, new Map([...assets, ['theme.css', css]]), 'Fixture'), /must be bundled|not embedded|style end tag/);
  }
  for (const script of ['"</script>"', '"<!--"']) {
    assert.throws(() => createStandaloneHtml(page, new Map([...assets, ['deck.js', script]]), 'Fixture'), /raw-text delimiter/);
  }
  assert.throws(() => createStandaloneHtml(page.replace('theme.css', '../theme.css'), assets, 'Fixture'), /Unsupported bundle asset path/);
  assert.throws(() => createStandaloneHtml(page.replace('</main>', '</main><img src="image.png">'), assets, 'Fixture'), /unsupported resource markup/);
  for (const inline of [
    '<style>body { background: url(https://example.com/image.png); }</style>',
    '<style>/* </style> */</style>',
    '<div style="background: url(image.png)"></div>'
  ]) {
    assert.throws(() => createStandaloneHtml(page.replace('</main>', `${inline}</main>`), assets, 'Fixture'), /Inline source styles/);
  }
});

test('moving indented script tags does not leave trailing whitespace in generated HTML', async () => {
  const { createStandaloneHtml } = await import('./bundle.mjs');
  const page = '<html><head>\n  <link rel="stylesheet" href="theme.css">\n  <script defer src="deck.js"></script>\n</head><body></body></html>';
  const assets = new Map([['theme.css', 'body { color: white; }'], ['deck.js', 'globalThis.ready = true;']]);
  const result = createStandaloneHtml(page, assets, 'Fixture notice');
  assert.doesNotMatch(result, /[ \t]+$/m);
  const script = 'globalThis.text = `Keep spaces  \ninside this string`;';
  const withSpaces = createStandaloneHtml(page, new Map([...assets, ['deck.js', script]]), 'Fixture notice');
  assert.ok(withSpaces.includes(script));
});

test('validation masking does not join markup across comments or embedded styles', async () => {
  const { createStandaloneHtml } = await import('./bundle.mjs');
  const page = '<html><head><link rel="stylesheet" href="theme.css"><script defer src="deck.js"></script></head><body><main></main></body></html>';
  const assets = new Map([['theme.css', 'body { color: white; }'], ['deck.js', 'globalThis.ready = true;']]);
  for (const fragment of [
    '<<!-- separator -->style>',
    '<<!-- separator -->script>',
    '<<link rel="stylesheet" href="theme.css">script>'
  ]) {
    assert.doesNotThrow(() => createStandaloneHtml(page.replace('<main>', `<main>${fragment}`), assets, 'Fixture notice'));
  }
  assert.throws(
    () => createStandaloneHtml(page.replace('<main>', '<main><!-- separator --><img src="image.png">'), assets, 'Fixture notice'),
    /unsupported resource markup/
  );
});

test('catalog metadata is validated and cannot terminate the inert JSON block', async () => {
  const { createStandaloneHtml } = await import('./bundle.mjs');
  const page = '<html><head><link rel="stylesheet" href="theme.css"><script defer src="deck.js"></script></head><body></body></html>';
  const assets = new Map([['theme.css', 'body { color: white; }'], ['deck.js', 'globalThis.ready = true;']]);
  const metadata = { title: 'Example </script> title', description: 'An <example> & "quotes".' };
  const result = createStandaloneHtml(page, assets, 'Fixture notice', metadata);
  const json = result.match(/<script type="application\/json" id="hve-slide-metadata">([\s\S]*?)<\/script>/)[1];
  assert.deepEqual(JSON.parse(json), metadata);
  assert.doesNotMatch(json, /</);
  for (const invalid of [null, {}, { title: 'Title' }, { title: ' ', description: 'Description' }]) {
    assert.throws(() => createStandaloneHtml(page, assets, 'Fixture notice', invalid), /deck.json requires/);
  }
});

test('complete bundle has current local assets, derived filename and full library notice', async t => {
  const { bundleDeck } = await import('./bundle.mjs');
  const { buildDeck, sourceFiles } = await import('./build.mjs');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'hve-deck-bundle-'));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const name = path.basename(__dirname);
  const output = path.join(temporary, 'slides', name, 'dist');
  const filename = await bundleDeck({
    build: async () => {
      fs.cpSync(await buildDeck(), output, { recursive: true });
      return output;
    }
  });
  assert.equal(filename, path.join(temporary, 'docs/slides', `${name}.html`));
  const standalone = fs.readFileSync(filename, 'utf8');
  const metadata = JSON.parse(fs.readFileSync(path.join(__dirname, 'deck.json'), 'utf8'));
  const catalog = standalone.match(/<script type="application\/json" id="hve-slide-metadata">([\s\S]*?)<\/script>/)[1];
  assert.deepEqual(JSON.parse(catalog), { title: metadata.title, description: metadata.description });
  for (const file of sourceFiles) {
    assert.equal(fs.readFileSync(path.join(__dirname, file), 'utf8'), fs.readFileSync(path.join(output, file), 'utf8'));
  }
  for (const [, asset] of html.matchAll(/<(?:link|script)\b[^>]*(?:href|src)="([^"]+)"/g)) {
    assert.ok(!/^(?:https?:)?\/\//.test(asset));
    assert.ok(standalone.includes(fs.readFileSync(path.join(output, asset), 'utf8')), asset);
  }
  assert.match(standalone, /Permission is hereby granted/);
  assert.doesNotMatch(standalone, /<script[^>]+\bsrc=|<link rel="stylesheet"/);
});
