// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  function element(tag, className = '', text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function hidden(text, className = '') {
    const node = element('span', className, text);
    node.setAttribute('aria-hidden', 'true');
    return node;
  }
  function codeSurface(file, body) {
    const surface = element('div', 'code-surface');
    const pre = element('pre');
    pre.append(element('code', '', body));
    surface.append(element('div', 'file-header', file), pre);
    return surface;
  }
  function composer(example) {
    const box = element('div', 'copilot-composer');
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Reconstructed Copilot Chat input; display only');
    if (example.attachments?.length) {
      const chips = element('div', 'context-chips');
      example.attachments.forEach(name => chips.append(element('span', 'context-chip', name)));
      box.append(chips);
    }
    const toolbar = element('div', 'composer-toolbar');
    toolbar.append(hidden('+'), element('span', 'composer-agent', example.mode || 'Agent'), element('span', '', 'Auto'), hidden('\u2191', 'composer-send'));
    box.append(element('div', 'composer-text', example.body), toolbar);
    return box;
  }
  const checklistStatus = {
    done: ['\u2705', 'Complete'],
    pending: ['\u2753', 'Pending'],
    skipped: ['\u274c', 'Skipped']
  };
  function chatBlock(block) {
    if (block.type === 'text') return element('p', 'chat-text', block.text);
    if (block.type === 'note') return element('p', 'chat-note', block.text);
    if (block.type === 'code') {
      const pre = element('pre', 'chat-code');
      pre.append(element('code', '', block.text));
      return pre;
    }
    if (block.type === 'callout') {
      const box = element('div', 'chat-callout');
      box.append(element('strong', '', block.label), element('p', '', block.text));
      return box;
    }
    if (block.type === 'list') {
      const list = element('ul', 'chat-list');
      block.items.forEach(item => list.append(element('li', '', item)));
      return list;
    }
    if (block.type === 'checklist') {
      const list = element('ul', 'chat-checklist');
      block.items.forEach(item => {
        const status = checklistStatus[item.status];
        if (!status) throw new Error(`Unknown checklist status: ${item.status}`);
        const row = element('li', item.status);
        row.append(hidden(status[0], 'check-icon'), element('span', 'sr-only', `${status[1]}: `), element('span', '', item.text));
        list.append(row);
      });
      return list;
    }
    throw new Error(`Unknown chat block: ${block.type}`);
  }
  function chat(example) {
    if (!Array.isArray(example.messages) || !example.messages.length) throw new Error('A chat example needs messages.');
    const transcript = element('div', 'chat-transcript');
    transcript.setAttribute('role', 'group');
    transcript.setAttribute('aria-label', 'Scripted chat transcript; display only');
    example.messages.forEach(message => {
      if (!['user', 'assistant'].includes(message.role)) throw new Error(`Unknown chat role: ${message.role}`);
      const item = element('div', `chat-message ${message.role}`);
      const body = element('div', 'chat-body');
      message.blocks.forEach(block => body.append(chatBlock(block)));
      item.append(element('div', 'chat-author', message.author), body);
      transcript.append(item);
    });
    return transcript;
  }
  function review(example) {
    const layout = element('div', 'review-scene');
    const findings = element('div', 'review-findings');
    const checks = element('div', 'review-card');
    const list = element('ul', 'task-list');
    example.checks.forEach(check => {
      const row = element('li');
      row.append(hidden('\u2713', 'task-check'), element('span', 'sr-only', 'Done: '), element('span', '', check));
      list.append(row);
    });
    checks.append(element('p', 'review-label', example.checksTitle), list);
    const finding = element('div', 'review-card finding');
    finding.append(element('p', 'review-label', example.finding.label), element('p', 'review-text', example.finding.text));
    findings.append(checks, finding);
    const edits = element('div', 'review-diff');
    const stats = globalThis.DeckContent.diffStats(example.diff);
    const summary = element('div', 'diff-summary');
    summary.append(element('span', '', example.file), element('span', '', `+${stats.added} / -${stats.removed}`));
    const diff = element('div', 'diff-lines');
    diff.setAttribute('role', 'group');
    diff.setAttribute('aria-label', 'Illustrative diff');
    const labels = { add: ['+', 'Added: '], remove: ['-', 'Removed: '], context: [' ', 'Unchanged: '] };
    example.diff.forEach(row => {
      const line = element('div', `diff-row ${row.type}`);
      const text = element('span');
      text.append(element('span', 'sr-only', labels[row.type][1]), row.text);
      line.append(hidden(labels[row.type][0]), text);
      diff.append(line);
    });
    edits.append(summary, diff);
    layout.append(findings, edits);
    return layout;
  }
  const renderers = {
    code: example => codeSurface(example.file, example.body),
    composer,
    chat,
    review
  };
  function renderExample(example) {
    if (!example || typeof example.kind !== 'string') throw new Error('Missing example kind.');
    const render = renderers[example.kind];
    if (!render) throw new Error(`Unknown example component: ${example.kind}`);
    if (typeof example.caption !== 'string' || !example.caption.trim()) throw new Error(`Missing fidelity caption: ${example.kind}`);
    const scene = element('div', `example-scene scene-${example.kind}`);
    scene.append(element('p', 'example-caption', example.caption), render(example));
    return scene;
  }
  globalThis.DeckComponents = { element, renderExample, kinds: Object.keys(renderers) };
}());
