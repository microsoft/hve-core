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
  function tierExplorer(example, context) {
    const { depthTier } = globalThis.DeckContent;
    const root = element('div', 'tier-explorer');
    const gate = element('div', 'tier-card tier-gate');
    gate.append(element('span', 'tier-step', 'Step 1'), element('h3', '', 'Prohibited uses gate'),
      element('p', '', 'Runs first. If a listed use applies, the planner records it and pauses until you acknowledge it.'));
    const screen = element('div', 'tier-card tier-indicators');
    const buttons = element('div', 'indicator-buttons');
    buttons.setAttribute('role', 'group');
    buttons.setAttribute('aria-label', 'Risk indicators');
    screen.append(element('span', 'tier-step', 'Step 2'), element('h3', '', 'Risk indicators'), buttons);
    const result = element('div', 'tier-card tier-result');
    const count = element('p', 'tier-count');
    const scale = element('ul', 'tier-scale');
    scale.setAttribute('aria-label', 'Activated indicators and depth tier');
    example.tiers.forEach(tier => {
      const row = element('li');
      row.dataset.tier = tier.name;
      row.append(element('span', 'tier-range', tier.activated), element('span', 'sr-only', ' activated: '),
        element('strong', '', tier.name), element('span', 'tier-flag', ''));
      scale.append(row);
    });
    result.append(element('span', 'tier-step', 'Step 3'), element('h3', '', 'Suggested depth'), count, scale,
      element('p', 'tier-gate-note', 'Hard gate: you confirm the tier before Phase 3.'));
    const update = () => {
      const activated = buttons.querySelectorAll('[aria-pressed="true"]').length;
      const tier = depthTier(activated);
      count.replaceChildren(element('strong', '', String(activated)), ` of ${example.indicators.length} activated`);
      scale.querySelectorAll('li').forEach(row => {
        const current = row.dataset.tier === tier;
        if (current) row.setAttribute('aria-current', 'true');
        else row.removeAttribute('aria-current');
        row.querySelector('.tier-flag').textContent = current ? 'Suggested' : '';
      });
      return { activated, tier };
    };
    example.indicators.forEach(indicator => {
      const button = element('button', 'indicator');
      button.type = 'button';
      button.setAttribute('aria-pressed', 'false');
      const state = hidden('Not activated', 'indicator-state');
      button.append(element('code', 'indicator-name', indicator.name),
        element('span', 'indicator-meta', `${indicator.method} / ${indicator.nist.join(', ')}`),
        element('span', 'indicator-focus', indicator.focus), state);
      button.addEventListener('click', () => {
        const pressed = button.getAttribute('aria-pressed') !== 'true';
        button.setAttribute('aria-pressed', String(pressed));
        state.textContent = pressed ? 'Activated' : 'Not activated';
        const { activated, tier } = update();
        context.announce?.(`${activated} of ${example.indicators.length} indicators activated. Suggested depth: ${tier}.`);
      });
      buttons.append(button);
    });
    root.append(gate, screen, result);
    update();
    return root;
  }
  const renderers = {
    code: example => codeSurface(example.file, example.body),
    composer,
    chat,
    review,
    'tier-explorer': tierExplorer
  };
  function renderExample(example, context = {}) {
    if (!example || typeof example.kind !== 'string') throw new Error('Missing example kind.');
    const render = renderers[example.kind];
    if (!render) throw new Error(`Unknown example component: ${example.kind}`);
    if (typeof example.caption !== 'string' || !example.caption.trim()) throw new Error(`Missing fidelity caption: ${example.kind}`);
    const scene = element('div', `example-scene scene-${example.kind}`);
    scene.append(element('p', 'example-caption', example.caption), render(example, context));
    return scene;
  }
  globalThis.DeckComponents = { element, renderExample, kinds: Object.keys(renderers) };
}());
