// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { demos, sources, rpiAgentSelection, participationQuestion, graphs, mermaidSource, diffStats, moveStep } = require('./content.js');
const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const standaloneModule = import('./bundle.mjs');

function standaloneFixture() {
  return {
    page: '<!doctype html><html><head><link rel="stylesheet" href="theme.css"><script defer src="content.js"></script><script defer src="deck.js"></script></head><body><main id="slides">Example</main></body></html>',
    assets: new Map([
      ['theme.css', 'body { color: white; background: url("data:image/svg+xml;base64,AAAA"); }'],
      ['content.js', 'globalThis.example = "Hello <world> $&";'],
      ['deck.js', 'document.querySelector("#slides").dataset.ready = "true";']
    ])
  };
}

test('every walkthrough can advance, reverse, clamp and reset without affecting another', () => {
  for (const demo of Object.values(demos)) {
    let index = 0;
    assert.equal(moveStep(index, 'back', demo.steps.length), 0);
    for (let i = 1; i < demo.steps.length; i++) {
      index = moveStep(index, 'next', demo.steps.length);
      assert.equal(index, i);
    }
    assert.equal(moveStep(index, 'next', demo.steps.length), index);
    assert.equal(moveStep(index, 'reset', demo.steps.length), 0);
    for (let i = demo.steps.length - 2; i >= 0; i--) {
      index = moveStep(index, 'back', demo.steps.length);
      assert.equal(index, i);
    }
  }
  assert.equal(moveStep(3, 'reset', demos.rpi.steps.length), 0);
  assert.equal(moveStep(3, 'next', demos.builder.steps.length), 4);
});

test('invalid state and unknown actions are surfaced', () => {
  for (const args of [[-1, 'next', 4], [0, 'next', 0], [4, 'next', 4], [0.5, 'next', 4]]) {
    assert.throws(() => moveStep(...args), RangeError);
  }
  assert.throws(() => moveStep(0, 'skip', 4), TypeError);
});

test('every step has a known phase and a complete display contract', () => {
  for (const demo of Object.values(demos)) {
    assert.ok(demo.steps.length >= 4);
    for (const step of demo.steps) {
      for (const field of ['title', 'state', 'context', 'body', 'insight']) assert.ok(step[field]?.trim(), field);
      assert.ok(demo.phases.includes(step.phase));
      assert.ok(['code', 'agent-picker', 'composer', 'question', 'answer', 'graph', 'plan', 'implementation', 'install'].includes(step.kind));
      if (step.kind === 'install') assert.ok(['chat', 'plugins', 'source', 'trust', 'installed'].includes(step.view));
      if (step.kind === 'composer') assert.ok(step.mode && step.attachments.length);
      if (step.kind === 'question') assert.ok(step.options.length >= 2);
      if (step.kind === 'answer') assert.ok(step.answer && step.detail);
      if (step.kind === 'graph' || step.kind === 'plan') assert.ok(graphs[step.graph]);
      if (step.kind === 'implementation') assert.ok(step.tasks.length && step.changes && step.diff.length);
    }
  }
});

test('installation sequence distinguishes the Plugins action and source quick input', () => {
  assert.deepEqual(demos.install.steps.map(step => step.view), ['chat', 'plugins', 'source', 'trust', 'installed']);
  assert.equal(demos.install.steps[0].body, 'Open Customizations');
  const source = demos.install.steps.find(step => step.view === 'source');
  assert.equal(source.source, 'microsoft/hve-core');
  assert.match(source.body, /GitHub repository, git URL, or local folder/);
  assert.match(demos.install.steps.at(-1).insight, /Nothing was installed/);
  for (const key of ['customizations-editor', 'plugins-page', 'source-quick-input']) assert.ok(sources[key]);
});

test('research and plan questions have matching completed-answer states', () => {
  for (const phase of ['Research', 'Plan']) {
    const index = demos.rpi.steps.findIndex(step => step.phase === phase && step.kind === 'question');
    assert.ok(index >= 0);
    const question = demos.rpi.steps[index];
    const answer = demos.rpi.steps[index + 1];
    assert.equal(answer.kind, 'answer');
    assert.equal(answer.phase, phase);
    assert.equal(answer.body, question.body);
    assert.ok(question.options.some(option => option.label === answer.answer));
  }
});

test('diagram source and preview share valid declared nodes and edges', () => {
  for (const graph of Object.values(graphs)) {
    const ids = graph.nodes.map(node => node.id);
    assert.equal(new Set(ids).size, ids.length);
    for (const edge of graph.edges) assert.ok(edge.every(id => ids.includes(id)));
  }
  const source = mermaidSource(graphs.plan);
  assert.ok(source.startsWith('flowchart LR\n'));
  for (const node of graphs.plan.nodes) assert.ok(source.includes(`${node.id}["${node.label}"]`));
  for (const [from, to] of graphs.plan.edges) assert.ok(source.includes(`${from} --> ${to}`));
  assert.ok(graphs.research.nodes.some(node => node.kind === 'tool'));
  assert.ok(graphs.research.nodes.some(node => node.kind === 'subagent'));
});

test('implementation includes completion evidence and accurate diff counts', () => {
  const step = demos.rpi.steps.find(step => step.kind === 'implementation');
  assert.equal(step.tasks.length, 2);
  assert.match(step.changes, /Completed Work/);
  assert.match(step.changes, /Validation Record/);
  assert.deepEqual(diffStats(step.diff), { added: 2, removed: 1 });
  assert.ok(step.diff.some(line => line.type === 'remove'));
  assert.ok(step.diff.some(line => line.type === 'add' && line.text.includes('renderVotes')));
});

test('each slide has unique identity, source provenance and notes', () => {
  const slides = [...html.matchAll(/<section\b([^>]*)>([\s\S]*?)<\/section>/g)];
  assert.ok(slides.length >= 24);
  const ids = slides.map(([, attributes]) => attributes.match(/\bid="([^"]+)"/)[1]);
  assert.equal(new Set(ids).size, slides.length);
  for (const [, attributes, body] of slides) {
    assert.match(attributes, /data-title="[^"]+"/);
    assert.match(attributes, /data-chapter="[^"]+"/);
    assert.match(body, /<aside class="notes">[\s\S]+<\/aside>/);
    const references = attributes.match(/data-sources="([^"]+)"/)[1].split(',');
    for (const reference of references) assert.ok(sources[reference], reference);
  }
});

test('citations use public HTTPS URLs without credentials', () => {
  for (const source of Object.values(sources)) {
    const url = new URL(source.url);
    assert.equal(url.protocol, 'https:');
    assert.equal(url.username, '');
    assert.equal(url.password, '');
    assert.ok(source.title && source.note);
  }
});

test('core historical, fidelity and installation distinctions remain explicit', () => {
  assert.match(html, /Research already uses a subagent/);
  assert.match(html, /plugin support predates August/);
  assert.match(html, /RPI Agent can coordinate the phases, but is optional/);
  assert.match(html, /copilot plugin marketplace add microsoft\/hve-core/);
  assert.match(html, /copilot plugin install hve-core@hve-core/);
  assert.match(html, /Manual path sharing can differ/);
  assert.match(html, /RPI \/ SCRIPTED WALKTHROUGH/);
  assert.match(html, /HVE BUILDER \/ SCRIPTED WALKTHROUGH/);
  assert.match(demos.builder.steps.at(-1).body, /\[ \] Reviewed by a qualified human/);
  assert.ok(demos.rpi.steps.some(step => step.state === 'Paused at Plan'));
});

test('timeline shows the merged HVE Builder introduction', () => {
  const timeline = html.match(/<section id="timeline"[\s\S]*?<\/section>/)[0];
  assert.match(timeline, /JUL 11<\/span><h3>HVE Builder/);
  assert.match(timeline, /Introduced in PR #2438/);
  assert.doesNotMatch(timeline, /Consolidated|JUL 26/);
  assert.match(sources['builder-introduction'].note, /Merged July 11, 2026/);
  assert.equal(sources['builder-introduction'].url, 'https://github.com/microsoft/hve-core/pull/2438');
});

test('opening and historical handoffs have explicit ordered stages', () => {
  const opening = html.match(/<ol class="opening-workflow"[\s\S]*?<\/ol>/)[0];
  assert.deepEqual([...opening.matchAll(/<strong>([^<]+)<\/strong>/g)].map(match => match[1]), ['Research', 'Plan', 'Implement', 'Review']);
  const legacy = html.match(/<ol class="legacy-flow"[\s\S]*?<\/ol>/)[0];
  assert.deepEqual([...legacy.matchAll(/<strong>([^<]+)<\/strong>/g)].map(match => match[1]), ['Task Researcher', 'Task Planner', 'Task Implementor']);
  assert.equal((legacy.match(/class="handoff-link"/g) || []).length, 2);
});

test('participation popup retains all modes and the example stop-before-code choice', () => {
  assert.equal(participationQuestion.body, 'How would you like us to work on this?');
  assert.deepEqual(participationQuestion.options.map(option => option.label), [
    'Handle it end to end',
    'Keep going, but check with me',
    'Research and plan with me',
    'Work through each phase with me'
  ]);
  assert.equal(participationQuestion.selected, 2);
  assert.match(participationQuestion.options[2].detail, /stop before Implementation/);
});

test('RPI usage slides call out selecting RPI Agent without requiring it for standalone skills', () => {
  const expected = ['then-now', 'select-rpi-agent', 'spine', 'research-evidence', 'plan-evidence', 'critique-changes', 'review-evidence', 'modes', 'bounded-loop', 'helpers', 'rpi-demo', 'extend-rpi', 'two-loops', 'one-plugin', 'closing'];
  const slides = [...html.matchAll(/<section\b([^>]*)>([\s\S]*?)<\/section>/g)];
  const guided = slides.filter(([, attributes]) => /\bdata-rpi-agent\b/.test(attributes));
  assert.deepEqual(guided.map(([, attributes]) => attributes.match(/\bid="([^"]+)"/)[1]), expected);
  for (const [, attributes] of guided) {
    assert.ok(attributes.match(/data-sources="([^"]+)"/)[1].split(',').includes('agent'));
  }
  for (const [, attributes] of slides.filter(([, attributes]) => /data-chapter="RPI"/.test(attributes))) {
    assert.match(attributes, /\bdata-rpi-agent\b/);
  }
  const ids = slides.map(([, attributes]) => attributes.match(/\bid="([^"]+)"/)[1]);
  assert.equal(ids.indexOf('select-rpi-agent') + 1, ids.indexOf('spine'));
  assert.equal(ids.length, 26);
  assert.equal(rpiAgentSelection.kind, 'agent-picker');
  assert.match(rpiAgentSelection.body, /Select RPI Agent/);
  assert.equal(demos.rpi.steps.length, 15);
  assert.equal(demos.rpi.steps[0].kind, 'composer');
  assert.ok(!demos.rpi.steps.some(step => step.kind === 'agent-picker'));
  assert.match(html, /id="agent-selection-example"/);
  assert.match(html, /skills can also run independently/);
});

test('critique and review distinguish missing plan evidence from observed defects', () => {
  const critique = html.match(/<section id="critique-changes"[\s\S]*?<\/section>/)[0];
  const review = html.match(/<section id="review-evidence"[\s\S]*?<\/section>/)[0];
  assert.match(critique, /PC-001: missing reset check/);
  assert.match(critique, /Verdict<\/dt><dd>Revise/);
  assert.match(review, /visible count of 3/);
  assert.match(review, /Complete \/ Defects found/);
  assert.match(review, /Primary assistant's decision/);
});

test('built bundle is complete and has no remote runtime assets', () => {
  const built = fs.readFileSync(path.join(__dirname, 'dist/index.html'), 'utf8');
  for (const match of built.matchAll(/<(?:link|script)\b[^>]*(?:src|href)="([^"]+)"/g)) {
    assert.ok(!/^(?:https?:)?\/\//.test(match[1]), match[1]);
    assert.ok(fs.existsSync(path.join(__dirname, 'dist', match[1])), match[1]);
  }
  assert.ok(fs.existsSync(path.join(__dirname, 'dist/vendor/reveal-LICENSE.txt')));
  for (const name of ['index.html', 'theme.css', 'components.css', 'content.js', 'components.js', 'deck.js']) {
    assert.equal(fs.readFileSync(path.join(__dirname, name), 'utf8'), fs.readFileSync(path.join(__dirname, 'dist', name), 'utf8'));
  }
});

test('standalone renderer embeds styles and runs scripts in order after document markup', async () => {
  const { createStandaloneHtml } = await standaloneModule;
  const { page, assets } = standaloneFixture();
  const bundled = createStandaloneHtml(page, assets, 'MIT License\nCopyright Example <author>');
  assert.match(bundled, /<style data-bundled-source="theme.css">/);
  assert.ok(bundled.includes(assets.get('theme.css')));
  assert.ok(bundled.includes(assets.get('content.js')));
  assert.ok(bundled.indexOf('</main>') < bundled.indexOf('<script data-bundled-source="content.js">'));
  assert.ok(bundled.indexOf('<script data-bundled-source="content.js">') < bundled.indexOf('<script data-bundled-source="deck.js">'));
  assert.doesNotMatch(bundled, /<script[^>]+\b(?:src|defer)\b|<link\b/);
  assert.match(bundled, /<template id="bundled-third-party-notices"><pre>MIT License\nCopyright Example &lt;author&gt;<\/pre><\/template>/);
  assert.equal(bundled, createStandaloneHtml(page, assets, 'MIT License\nCopyright Example <author>'));
});

test('standalone renderer refuses missing and unsafe raw-text inputs', async () => {
  const { createStandaloneHtml } = await standaloneModule;
  const { page, assets } = standaloneFixture();
  assert.throws(() => createStandaloneHtml(page, new Map(), 'MIT'), /Missing bundle asset/);
  assert.throws(() => createStandaloneHtml(page, assets, ''), /license is required/);
  for (const delimiter of ['"</ScRiPt>"', '"<!--"']) {
    assert.throws(() => createStandaloneHtml(page, new Map([...assets, ['deck.js', delimiter]]), 'MIT'), /raw-text delimiter/);
  }
  assert.throws(() => createStandaloneHtml(page, new Map([...assets, ['theme.css', '/* </STYLE> */']]), 'MIT'), /style end tag/);
});

test('standalone renderer rejects nonembedded resources and paths outside the deck', async () => {
  const { createStandaloneHtml } = await standaloneModule;
  const { page, assets } = standaloneFixture();
  for (const css of ['@import "other.css";', 'body { background: url(image.png); }', 'body { background: url("https://example.com/image.png"); }']) {
    assert.throws(() => createStandaloneHtml(page, new Map([...assets, ['theme.css', css]]), 'MIT'), /must be bundled|not embedded/);
  }
  for (const source of ['../theme.css', '/theme.css', 'https://example.com/theme.css']) {
    assert.throws(() => createStandaloneHtml(page.replace('href="theme.css"', `href="${source}"`), assets, 'MIT'), /Unsupported bundle asset path/);
  }
  for (const resource of ['<img src="picture.png">', '<script async src="other.js"></script>', '<iframe src="https://example.com"></iframe>']) {
    assert.throws(() => createStandaloneHtml(page.replace('</main>', `</main>${resource}`), assets, 'MIT'), /unsupported resource markup/);
  }
});

test('standalone output contains the full current deck, vendor code and license', async () => {
  const { bundleDeck, createStandaloneHtml } = await standaloneModule;
  const destination = await bundleDeck();
  assert.equal(destination, path.join(__dirname, 'dist/hve-updates.html'));
  const bundled = fs.readFileSync(destination, 'utf8');
  const styles = ['vendor/reveal.css', 'theme.css', 'components.css'];
  const scripts = ['vendor/reveal.js', 'content.js', 'components.js', 'deck.js'];
  const assets = new Map([...styles, ...scripts].map(name => [name, fs.readFileSync(path.join(__dirname, 'dist', name), 'utf8')]));
  const license = fs.readFileSync(path.join(__dirname, 'dist/vendor/reveal-LICENSE.txt'), 'utf8');
  assert.equal(bundled, createStandaloneHtml(html, assets, license));
  for (const name of [...styles, ...scripts]) assert.ok(bundled.includes(assets.get(name)), name);
  assert.equal((bundled.match(/<section\b/g) || []).length, 26);
  assert.equal((bundled.match(/<style data-bundled-source=/g) || []).length, 3);
  assert.equal((bundled.match(/<script data-bundled-source=/g) || []).length, 4);
  assert.match(bundled, /Permission is hereby granted/);
  assert.match(bundled, /download the complete HTML file/);
  assert.doesNotMatch(bundled, /<script[^>]+\bsrc=|<link rel="stylesheet"/);
});
