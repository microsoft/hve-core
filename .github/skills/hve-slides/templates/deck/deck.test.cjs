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

test('deck initialization disables the unused cross-window API', () => {
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  assert.match(source, /postMessage:\s*false/);
  assert.match(source, /postMessageEvents:\s*false/);
});

test('displayed diff counts and question selections are consistent', () => {
  const stats = diffStats(examples.implementation.diff);
  assert.equal(stats.added, 2);
  assert.equal(stats.removed, 1);
  assert.throws(() => diffStats([{ type: 'invalid', text: '' }]), /Invalid/);
  assert.ok(examples.question.selected >= 0 && examples.question.selected < examples.question.options.length);
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
