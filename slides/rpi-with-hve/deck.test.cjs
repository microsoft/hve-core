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
const { sources, examples, demos, moveStep, diffStats } = context.DeckContent;
const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
// Values created inside the vm context have their own Array prototype.
const plain = value => JSON.parse(JSON.stringify(value));

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
  for (const [, name] of html.matchAll(/data-example="([^"]+)"/g)) assert.ok(examples[name], name);
  const hosts = [...html.matchAll(/data-demo="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(hosts).size, hosts.length);
  for (const name of hosts) {
    const demo = demos[name];
    assert.ok(demo?.steps.length);
    for (const step of demo.steps) {
      assert.ok(demo.phases.includes(step.phase));
      for (const field of ['kind', 'title', 'state', 'insight']) assert.equal(typeof step[field], 'string');
    }
  }
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
  assert.doesNotMatch(source, /if \(speak\) announce\(/);
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

test('displayed diff counts and question selections are consistent', () => {
  const implementation = demos.rpi.steps.find(step => step.kind === 'implementation');
  const stats = diffStats(implementation.diff);
  assert.equal(stats.added, implementation.diff.filter(row => row.type === 'add').length);
  assert.equal(stats.added, 10);
  assert.equal(stats.removed, 0);
  assert.throws(() => diffStats([{ type: 'invalid', text: '' }]), /Invalid/);
  const questions = [examples.participation, ...demos.rpi.steps.filter(step => step.kind === 'question')];
  assert.ok(questions.length >= 2);
  for (const question of questions) {
    assert.ok(question.selected >= 0 && question.selected < question.options.length);
    for (const option of question.options) assert.ok(option.label && option.detail);
  }
});

test('every slide cites at least one public HTTPS source without credentials', () => {
  for (const [, attributes] of html.matchAll(/<section\b([^>]*)>/g)) {
    assert.ok((attributes.match(/data-sources="([^"]+)"/)?.[1] || '').split(',').filter(Boolean).length, attributes);
  }
  for (const [id, source] of Object.entries(sources)) {
    const url = new URL(source.url);
    assert.equal(url.protocol, 'https:', id);
    assert.equal(url.username + url.password, '', id);
    assert.ok(source.title && source.note, id);
    assert.doesNotMatch(source.url, /copilot-tracking|\/Users\/|file:/, id);
  }
});

test('frontier model and tool claims keep their dates, versions and qualifiers', () => {
  assert.match(sources['gpt6-astra'].note, /1,050,000/);
  assert.match(sources['gpt6-release'].note, /September 3, 2026/);
  assert.match(sources['opus-55'].note, /September 22, 2026.*1M/);
  assert.match(sources['vscode-search-tool'].url, /\/blob\/1\.139\.0\//);
  assert.match(sources['vscode-read-tool'].url, /\/blob\/1\.139\.0\//);
  const models = html.match(/<section id="frontier-models"[\s\S]*?<\/section>/)[0];
  assert.match(models, /SEPTEMBER 3, 2026[\s\S]*1,050,000/);
  assert.match(models, /SEPTEMBER 22, 2026[\s\S]*1M/);
  assert.match(models, /Effective limits depend on the client/);
  const tools = html.match(/<section id="bounded-tools"[\s\S]*?<\/section>/)[0];
  assert.match(tools, /showing 100 matches in 14 files/);
  assert.match(tools, /File content truncated at line 2000/);
  assert.match(tools, /experiment-based settings/);
  assert.match(tools, /Other hosts use different limits/);
});

test('research evidence is dated and the observed session is labelled as one observation', () => {
  const budget = html.match(/<section id="context-budget"[\s\S]*?<\/section>/)[0];
  assert.match(budget, /Bars are conceptual, not measurements/);
  assert.match(budget, /studies tested earlier models/);
  for (const label of ['CHROMA / 2025', 'SHI ET AL. / 2023', 'LIU ET AL. / 2023']) assert.ok(budget.includes(label), label);
  for (const segment of [...budget.matchAll(/<li class="seg-[^"]+"><span>([^<]+)<\/span><\/li>/g)]) assert.ok(segment[1].trim());
  const session = html.match(/<section id="observed-session"[\s\S]*?<\/section>/)[0];
  assert.equal((session.match(/<li><strong>/g) || []).length, 6);
  assert.match(session, /An observation, not a benchmark/);
  assert.doesNotMatch(html, /\/Users\/|copilot-tracking\/workshop/);
});

test('RPI Agent selection precedes the phase overview and stays optional', () => {
  const ids = [...html.matchAll(/<section\b[^>]*\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(ids.indexOf('start-rpi') + 1, ids.indexOf('phase-contract'));
  const start = html.match(/<section id="start-rpi"[\s\S]*?<\/section>/)[0];
  assert.match(start, /Select <strong>RPI Agent<\/strong>/);
  assert.match(start, /RPI Agent is optional and uses the same phase skills/);
  for (const skill of ['/rpi-research', '/rpi-plan', '/rpi-implement', '/rpi-review']) assert.ok(start.includes(`<code>${skill}</code>`), skill);
  assert.equal(examples.request.mode, 'RPI Agent');
  assert.equal(demos.rpi.steps[0], examples.request);
});

test('participation example keeps the four RPI Agent choices in order', () => {
  assert.equal(examples.participation.body, 'How would you like us to work on this?');
  assert.deepEqual(plain(examples.participation.options.map(option => option.label)), [
    'Handle it end to end',
    'Keep going, but check with me',
    'Research and plan with me',
    'Work through each phase with me'
  ]);
  assert.equal(examples.participation.selected, 2);
  assert.match(examples.participation.options[2].detail, /stop before Implementation/);
  assert.match(html, /Safety confirmations, required gates and human review apply in every mode/);
});

test('walkthrough follows one task from request through a routed review finding', () => {
  const demo = demos.rpi;
  assert.deepEqual(plain(demo.phases), ['Request', 'Research', 'Plan', 'Implement', 'Review']);
  assert.deepEqual(plain(demo.steps.map(step => step.phase)), ['Request', 'Research', 'Research', 'Plan', 'Implement', 'Review']);
  for (let index = 1; index < demo.steps.length; index++) {
    assert.ok(demo.phases.indexOf(demo.steps[index].phase) >= demo.phases.indexOf(demo.steps[index - 1].phase));
  }
  assert.equal(demo.steps[1].surface, 'tool');
  assert.match(demo.steps[1].body, /showing 100 matches/);
  assert.match(demo.steps[3].body, /PC-001[\s\S]*Resolved/);
  assert.match(demo.steps.at(-1).body, /Route: rpi-implement[\s\S]*Execution: Complete\nOutcome: Defects found/);
  for (const step of demo.steps) assert.match(step.label, /Reconstructed|Illustrative|Scripted/);
});

test('trade-off slide keeps the direct-edit path and the limits of RPI', () => {
  const tradeoffs = html.match(/<section id="when-to-use"[\s\S]*?<\/section>/)[0];
  assert.match(tradeoffs, /USE A DIRECT EDIT/);
  assert.match(tradeoffs, /describe the diff in one sentence/);
  assert.match(tradeoffs, /It needs your review/);
  const cited = tradeoffs.match(/data-sources="([^"]+)"/)[1].split(',');
  for (const source of ['rpi-overview', 'claude-code-practices', 'codex-practices', 'anthropic-context-eng']) assert.ok(cited.includes(source), source);
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
