// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  function element(tag, className = '', text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function codeSurface(file, body) {
    const surface = element('div', 'code-surface');
    const pre = element('pre');
    pre.append(element('code', '', body));
    surface.append(element('div', 'file-header', file), pre);
    return surface;
  }
  function composer(example, compact = false) {
    const box = element('div', `copilot-composer${compact ? ' compact-composer' : ''}`);
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Reconstructed Copilot request; display only');
    if (example.attachments?.length && !compact) {
      const chips = element('div', 'context-chips');
      example.attachments.forEach(name => chips.append(element('span', 'context-chip', name)));
      box.append(chips);
    }
    const toolbar = element('div', 'composer-toolbar');
    const send = element('span', 'composer-send', '\u2191');
    send.setAttribute('aria-hidden', 'true');
    toolbar.append(element('span', '', '+'), element('span', '', example.mode || 'Agent'), element('span', '', 'Auto'), send);
    box.append(element('div', 'composer-text', compact ? 'Describe the next change...' : example.body), toolbar);
    return box;
  }
  function renderExample(example) {
    if (!example || typeof example.kind !== 'string') throw new Error('Missing example kind.');
    const scene = element('div', 'example-scene');
    scene.append(element('div', 'example-caption', 'Reconstructed / scripted example'));
    if (example.kind === 'code') scene.append(codeSurface(example.file, example.body));
    else if (example.kind === 'composer') scene.append(composer(example));
    else if (example.kind === 'question') {
      if (!Array.isArray(example.options) || !Number.isInteger(example.selected)
        || example.selected < 0 || example.selected >= example.options.length) throw new Error('Invalid scripted question.');
      const card = element('div', 'copilot-question');
      const list = element('ol', 'question-options');
      example.options.forEach((option, index) => {
        const row = element('li', index === example.selected ? 'selected' : '');
        row.append(element('span', 'question-index', String(index + 1)), element('span', '', `${option}${index === example.selected ? ' (selected)' : ''}`));
        list.append(row);
      });
      card.append(element('h4', '', example.body), list, element('p', 'question-answer', 'Custom answer: type a different response in the real client.'));
      scene.append(card);
    } else if (example.kind === 'answer') {
      scene.append(element('div', 'answer-summary', example.body));
    } else if (example.kind === 'implementation') {
      const layout = element('div', 'implementation-scene');
      const artifacts = element('div', 'implementation-artifacts');
      const tasks = element('div', 'code-surface');
      const list = element('ul', 'task-list');
      example.tasks.forEach(task => list.append(element('li', '', `[x] ${task}`)));
      tasks.append(element('div', 'file-header', 'Completed example tasks'), list);
      artifacts.append(tasks, codeSurface('Illustrative changes', example.changes));
      const edits = element('div', 'implementation-editing');
      const stats = globalThis.DeckContent.diffStats(example.diff);
      const summary = element('div', 'diff-summary');
      summary.append(element('span', '', example.file), element('span', '', `+${stats.added} / -${stats.removed}`));
      const diff = element('div', 'diff-lines');
      diff.setAttribute('aria-label', 'Illustrative source diff');
      example.diff.forEach(row => {
        const line = element('div', `diff-row ${row.type}`);
        line.append(element('span', '', { add: '+', remove: '-', context: ' ' }[row.type]), element('span', '', row.text));
        diff.append(line);
      });
      edits.append(summary, diff, composer({ mode: 'Agent' }, true));
      layout.append(artifacts, edits);
      scene.append(layout);
    } else throw new Error(`Unknown example component: ${example.kind}`);
    return scene;
  }
  globalThis.DeckComponents = { element, renderExample };
}());
