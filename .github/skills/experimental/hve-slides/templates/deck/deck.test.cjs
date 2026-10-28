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

test('presenter bar, slide footer and walkthrough controls follow the shared bottom chrome', () => {
  const theme = fs.readFileSync(path.join(__dirname, 'theme.css'), 'utf8');
  const source = fs.readFileSync(path.join(__dirname, 'deck.js'), 'utf8');
  // Returns the declarations of the unprefixed rule for a selector, so assertions do not depend on declaration order.
  const rule = selector => {
    const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = theme.match(new RegExp(`^${escaped} \\{([^}]*)\\}`, 'm'));
    assert.ok(match, `Missing rule: ${selector}`);
    return match[1];
  };
  // The bar names the deck and the current chapter before its controls.
  assert.match(html, /<nav id="presenter-controls"[^>]*>\s*<div class="brand"><span class="brand-dot" aria-hidden="true"><\/span>[^<]+<span id="chapter-label">/);
  // Short chapter labels keep the bar on one row at desktop widths.
  for (const [, chapter] of html.matchAll(/data-chapter="([^"]+)"/g)) assert.ok(chapter.length <= 28, `Chapter label too long for the bar: ${chapter}`);
  // One variable sizes the bar and the slide area above it, including the stacked layouts.
  assert.match(theme, /--presenter-height: 64px;/);
  assert.match(theme, /:root:not\(\[data-reading-view="true"\]\) \{ --presenter-height: 108px; \}/);
  assert.match(rule('.reveal'), /inset: 0 0 var\(--presenter-height\);/);
  assert.match(rule('.reveal'), /height: calc\(100% - var\(--presenter-height\)\);/);
  const bar = rule('#presenter-controls');
  assert.match(bar, /height: var\(--presenter-height\);/);
  // reveal.js gives the current slide z-index 11; reading view would otherwise paint scrolled content over the bar.
  assert.ok(Number(bar.match(/z-index: (\d+);/)?.[1]) > 11);
  // Footer labels sit above a divider in body text.
  assert.match(html, /<div class="slide-bottom">/);
  assert.match(rule('.slide-bottom'), /border-top: 1px solid/);
  assert.doesNotMatch(rule('.slide-bottom'), /font-mono/);
  // Step controls are the footer of the example frame, with Next step as the primary action.
  assert.match(source, /main\.append\(header, element\('div', 'demo-body'\), controls\);/);
  assert.match(source, /host\.replaceChildren\(sidebar, main\);/);
  assert.match(rule('.demo-main'), /overflow: hidden;/);
  assert.match(rule('.demo-main'), /border: 1px solid/);
  assert.match(rule('.demo-controls'), /border-top: 1px solid/);
  assert.match(rule('.demo-controls [data-action="next"]'), /font-weight: 600;/);
  // Compact presenter buttons on the canvas. In reading view, the presenter-specific selector outranks the bar's 40px rule.
  assert.match(rule('#presenter-controls button'), /min-height: 40px;/);
  assert.match(theme, /^\[data-reading-view="true"\] button, \[data-reading-view="true"\] #presenter-controls button \{ min-height: 44px; \}$/m);
  assert.doesNotMatch(theme, /^button \{ min-height: 44px; \}$/m);
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
    dependencyRoot: __dirname,
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
    if (asset === 'vendor/reveal.js') continue;
    assert.ok(standalone.includes(fs.readFileSync(path.join(output, asset), 'utf8')), asset);
  }
  const provenance = [...standalone.matchAll(/<script type="application\/json" id="hve-slide-provenance">([\s\S]*?)<\/script>/g)];
  assert.equal(provenance.length, 1);
  assert.equal(JSON.parse(provenance[0][1]).securityCheckResult, 'passed');
  assert.match(standalone, /Permission is hereby granted/);
  assert.doesNotMatch(standalone, /<script[^>]+\bsrc=|<link rel="stylesheet"/);
});

const revealFixture = [
  'a(e,`img[data-src]`).forEach(e=>{(e.setAttribute(`src`,e.getAttribute(`data-src`)),e.removeAttribute(`data-src`))});',
  'a(e,`source[data-src]`).forEach(e=>{e.setAttribute(`src`,e.getAttribute(`data-src`)),n+=1});',
  'o.split(`,`).forEach(t=>{let n=document.createElement(`source`);n.setAttribute(`src`,t);e.appendChild(n)});',
  'a&&a.getAttribute(`src`)!==r&&a.setAttribute(`src`,r);',
  'i&&(e.removeEventListener(`load`,f),e.setAttribute(`src`,e.getAttribute(`data-src`)));',
  '/youtube\\.com\\/embed\\//.test(t.getAttribute(`src`))&&e?p(1):/player\\.vimeo\\.com\\//.test(t.getAttribute(`src`))&&e?p(2):p(3);',
  'function Ve(){f.postMessage&&window.addEventListener(`message`,Jt,!1)}',
  'function O(e,t){let n=M()[e],r=n&&n.querySelectorAll(`section`);return r&&r.length&&typeof t==`number`?r?r[t]:void 0:n}'
].join('\n');
const revealMessageListener = /addEventListener\(`message`/;
const revealRedundantGetSlide = 'r?r[t]:void 0';

function revealPage() {
  return {
    page: '<html><head><link rel="stylesheet" href="theme.css"><script defer src="vendor/reveal.js"></script><script defer src="deck.js"></script></head><body></body></html>',
    assets: new Map([['theme.css', 'body { color: white; }'], ['vendor/reveal.js', revealFixture], ['deck.js', 'globalThis.ready = true;']])
  };
}

test('reveal.js lazy-load sinks, embed host checks, message listener and redundant getSlide branch are removed from the installed release and every inlined script', async () => {
  const { neutralizeRevealSinks, supportedRevealVersion, createStandaloneHtml } = await import('./bundle.mjs');
  const flow = /setAttribute\(`src`,(?:e\.getAttribute\(`data-src`\)|t\)|r\))/;
  const installed = path.join(__dirname, 'node_modules/reveal.js/dist/reveal.js');
  for (const source of [revealFixture, ...(fs.existsSync(installed) ? [fs.readFileSync(installed, 'utf8')] : [])]) {
    const patched = neutralizeRevealSinks(source, supportedRevealVersion);
    assert.doesNotMatch(patched, flow);
    for (const hostCheck of ['/youtube\\.com\\/embed\\//.test(', '/player\\.vimeo\\.com\\//.test(']) {
      assert.ok(!patched.includes(hostCheck), hostCheck);
    }
    assert.doesNotMatch(patched, revealMessageListener);
    assert.ok(!patched.includes(revealRedundantGetSlide));
    assert.ok(patched.includes('r&&r.length&&typeof t==`number`?r[t]:n'));
    assert.doesNotThrow(() => new vm.Script(patched));
  }
  const { page, assets } = revealPage();
  const firstParty = 'el.setAttribute("src", el.getAttribute("data-src"));';
  assert.throws(
    () => createStandaloneHtml(page, new Map([...assets, ['deck.js', firstParty]]), 'Fixture', undefined, { revealVersion: supportedRevealVersion }),
    /copies a data-src attribute into src/
  );
});

test('reveal.js patch fails closed on a changed anchor or unsupported version', async () => {
  const { neutralizeRevealSinks, supportedRevealVersion } = await import('./bundle.mjs');
  assert.throws(() => neutralizeRevealSinks(revealFixture.replace('n.setAttribute(`src`,t);', 'n.src=t;'), supportedRevealVersion), /anchor "background video source" matched 0 times/);
  assert.throws(() => neutralizeRevealSinks(`${revealFixture}\na.setAttribute(\`src\`,r)`, supportedRevealVersion), /anchor "background iframe" matched 2 times/);
  assert.throws(() => neutralizeRevealSinks(revealFixture.replace('/player\\.vimeo\\.com\\//', '/vimeo\\.com\\//'), supportedRevealVersion), /anchor "embedded Vimeo host check" matched 0 times/);
  assert.throws(() => neutralizeRevealSinks(revealFixture.replace('window.addEventListener(`message`,Jt,!1)', 'window.addEventListener(`message`,Qt,!1)'), supportedRevealVersion), /anchor "window message listener registration" matched 0 times/);
  assert.throws(() => neutralizeRevealSinks(revealFixture.replace('r?r[t]:void 0:n', 'r[t]:n'), supportedRevealVersion), /anchor "getSlide redundant conditional" matched 0 times/);
  assert.throws(() => neutralizeRevealSinks(revealFixture, '6.1.0'), /reveal\.js 6\.1\.0 is not supported/);
  assert.throws(() => neutralizeRevealSinks(revealFixture, undefined), /is not supported/);
});

test('provenance block matches its contract, is deterministic, and cannot terminate its script', async () => {
  const { createStandaloneHtml, supportedRevealVersion } = await import('./bundle.mjs');
  const { page, assets } = revealPage();
  const metadata = { title: 'Deck', description: 'Description' };
  const options = { revealVersion: supportedRevealVersion };
  const first = createStandaloneHtml(page, assets, 'Fixture notice', metadata, options);
  assert.equal(createStandaloneHtml(page, assets, 'Fixture notice', metadata, options), first);
  const blocks = [...first.matchAll(/<script type="application\/json" id="hve-slide-provenance">([\s\S]*?)<\/script>/g)];
  assert.equal(blocks.length, 1);
  assert.doesNotMatch(blocks[0][1], /</);
  assert.deepEqual(JSON.parse(blocks[0][1]), {
    generator: 'hve-slides',
    revealVersion: '6.0.2',
    patches: [
      'reveal-lazy-src-neutralized',
      'reveal-embed-host-regex-neutralized',
      'reveal-postmessage-listener-removed',
      'reveal-getslide-redundant-conditional-removed'
    ],
    securityChecks: ['raw-text-delimiters', 'inline-styles', 'resource-markup', 'reveal-lazy-src'],
    securityCheckResult: 'passed'
  });
  assert.ok(first.indexOf('id="hve-slide-provenance"') > first.indexOf('id="hve-slide-metadata"'));
  assert.doesNotMatch(createStandaloneHtml(page.replace('vendor/reveal.js', 'deck.js'), assets, 'Fixture notice', metadata), /hve-slide-provenance/);
});

test('installed reveal.js must match the deck pin before bundling', async t => {
  const { readRevealVersion } = await import('./bundle.mjs');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'hve-deck-reveal-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(path.join(root, 'package.json'), JSON.stringify({ dependencies: { 'reveal.js': '6.0.2' } }));
  await assert.rejects(readRevealVersion(root), /reveal\.js is missing/);
  fs.mkdirSync(path.join(root, 'node_modules/reveal.js'), { recursive: true });
  fs.writeFileSync(path.join(root, 'node_modules/reveal.js/package.json'), JSON.stringify({ version: '6.1.0' }));
  await assert.rejects(readRevealVersion(root), /Installed reveal\.js 6\.1\.0 does not match the deck pin 6\.0\.2/);
  fs.writeFileSync(path.join(root, 'node_modules/reveal.js/package.json'), JSON.stringify({ version: '6.0.2' }));
  assert.equal(await readRevealVersion(root), '6.0.2');
});
