// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  function element(tag, className = '', text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function svgElement(tag, attributes = {}) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, String(value)));
    return node;
  }
  const iconPaths = {
    file: 'M6 3h8l4 4v14H6z M14 3v5h4 M9 12h6 M9 16h6',
    chevron: 'm8 10 4 4 4-4',
    send: 'M12 19V5 M6 11l6-6 6 6',
    plus: 'M12 5v14 M5 12h14',
    sparkle: 'm12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5z',
    check: 'm5 12 4 4L19 6',
    diff: 'M4 4h16v16H4z M12 4v16 M6 10h4 M15 9v6 M13 12h4',
    search: 'M15 15l6 6 M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0',
    close: 'm6 6 12 12 M18 6 6 18'
  };
  function icon(name) {
    if (!iconPaths[name]) throw new Error(`Unknown presentation icon: ${name}`);
    const svg = svgElement('svg', { viewBox: '0 0 24 24', class: 'ui-icon', 'aria-hidden': 'true', focusable: 'false' });
    svg.append(svgElement('path', { d: iconPaths[name], fill: 'none', stroke: 'currentColor', 'stroke-width': 1.65, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }));
    return svg;
  }
  function codeBlock(text, { numbered = true } = {}) {
    const pre = element('pre', `numbered-code${numbered ? '' : ' plain-code'}`);
    const code = element('code');
    text.split('\n').forEach((line, index) => {
      const row = element('span', 'code-line');
      if (numbered) {
        const number = element('span', 'line-number', String(index + 1));
        number.setAttribute('aria-hidden', 'true');
        row.append(number);
      }
      const content = element('span', 'code-text');
      const key = line.match(/^([A-Za-z][\w -]*:)(\s.*)?$/);
      if (line.startsWith('#')) content.append(element('span', 'tok-heading', line));
      else if (/^[([]/.test(line)) content.append(element('span', 'tok-highlight', line));
      else if (line.startsWith('...')) content.append(element('span', 'tok-muted', line));
      else if (key) content.append(element('span', 'tok-key', key[1]), key[2] || '');
      else content.textContent = line || ' ';
      row.append(content);
      code.append(row);
    });
    pre.append(code);
    return pre;
  }
  function fileHeader(name, label, kind = 'file') {
    const header = element('div', 'file-header');
    header.append(icon(kind), element('span', 'file-name', name));
    if (label) header.append(element('span', 'file-state', label));
    return header;
  }
  function composer(example) {
    const box = element('div', 'copilot-composer');
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Reconstructed Copilot Chat input; display only');
    if (example.attachments?.length) {
      const chips = element('div', 'context-chips');
      example.attachments.forEach(name => {
        const chip = element('span', 'context-chip');
        chip.append(icon('file'), element('span', '', name));
        chips.append(chip);
      });
      box.append(chips);
    }
    box.append(element('div', 'composer-text', example.body));
    const toolbar = element('div', 'composer-toolbar');
    const attach = element('span', 'composer-tool');
    attach.append(icon('plus'));
    const selected = example.mode === 'RPI Agent';
    const mode = element('span', `composer-picker${selected ? ' agent-selected' : ''}`, example.mode || 'Agent');
    mode.append(icon('chevron'));
    if (selected) mode.append(element('span', 'sr-only', '(selected agent)'));
    const model = element('span', 'composer-picker', 'Auto');
    model.append(icon('chevron'));
    const send = element('span', 'composer-send');
    send.setAttribute('aria-hidden', 'true');
    send.append(icon('send'));
    toolbar.append(attach, mode, model, element('span', 'toolbar-space'), send);
    box.append(toolbar);
    return box;
  }
  function renderComposer(example) {
    const scene = element('div', 'copilot-scene');
    const identity = element('div', 'copilot-identity');
    identity.append(icon('sparkle'), element('span', '', 'GitHub Copilot'));
    scene.append(identity, composer(example));
    return scene;
  }
  function renderQuestion(example) {
    const options = example.options;
    if (!Array.isArray(options) || !options.length || options.some(option => typeof option?.label !== 'string' || typeof option.detail !== 'string')
      || !Number.isInteger(example.selected) || example.selected < 0 || example.selected >= options.length) {
      throw new Error('Invalid scripted question.');
    }
    const card = element('div', 'copilot-question');
    card.setAttribute('role', 'group');
    card.setAttribute('aria-label', 'Reconstructed Copilot question; display only');
    const header = element('div', 'question-header');
    header.append(element(`h${example.headingLevel || 4}`, '', example.body), element('span', 'toolbar-space'), icon('close'));
    const list = element('ol', 'question-options');
    options.forEach((option, index) => {
      const row = element('li', `question-option${index === example.selected ? ' selected-option' : ''}`);
      const copy = element('div', 'option-copy');
      copy.append(element('div', 'option-title', option.label), element('div', 'option-description', option.detail));
      row.append(element('span', 'option-index', String(index + 1)), copy);
      if (index === example.selected) row.append(icon('check'), element('span', 'sr-only', '(shown selected)'));
      list.append(row);
    });
    const freeform = element('div', 'question-freeform');
    freeform.append(element('span', 'option-index', String(options.length + 1)), element('span', 'question-custom-answer', 'Enter custom answer'));
    card.append(header, list, freeform);
    return card;
  }
  function renderImplementation(example) {
    const layout = element('div', 'implementation-scene');
    const artifacts = element('div', 'implementation-artifacts');
    const plan = element('div', 'code-surface');
    plan.append(fileHeader(example.plan, 'Checked'));
    const checklist = element('div', 'completed-checklist');
    checklist.append(element('strong', '', example.phaseTitle));
    example.tasks.forEach(task => {
      const row = element('div', 'completed-task');
      const mark = element('span', 'completed-box', '\u2713');
      mark.setAttribute('aria-hidden', 'true');
      row.append(mark, element('span', 'sr-only', 'Completed: '), element('code', '', task));
      checklist.append(row);
    });
    plan.append(checklist);
    const log = element('div', 'code-surface');
    log.append(fileHeader('log-retention-changes.md', 'Evidence'), codeBlock(example.changes, { numbered: false }));
    artifacts.append(plan, log);
    const editing = element('div', 'implementation-editing');
    const stats = globalThis.DeckContent.diffStats(example.diff);
    const summary = element('div', 'diff-summary');
    summary.append(icon('diff'), element('code', '', example.file), element('span', 'toolbar-space'),
      element('span', 'diff-added', `+${stats.added}`), element('span', 'diff-removed', `-${stats.removed}`));
    const diff = element('div', 'inline-diff');
    diff.setAttribute('role', 'group');
    diff.setAttribute('aria-label', `${example.file} illustrative diff: ${stats.added} lines added, ${stats.removed} removed`);
    let oldLine = example.startLine || 1;
    let newLine = example.startLine || 1;
    example.diff.forEach(row => {
      const line = element('div', `diff-row diff-${row.type}`);
      const before = element('span', 'diff-line-number', row.type === 'add' ? '' : String(oldLine));
      const after = element('span', 'diff-line-number', row.type === 'remove' ? '' : String(newLine));
      before.setAttribute('aria-hidden', 'true');
      after.setAttribute('aria-hidden', 'true');
      const sign = element('span', 'diff-sign', { add: '+', remove: '-', context: ' ' }[row.type]);
      sign.setAttribute('aria-hidden', 'true');
      const label = element('span', 'sr-only', { add: 'Added: ', remove: 'Removed: ', context: 'Unchanged: ' }[row.type]);
      line.append(before, after, sign, label, element('code', '', row.text));
      if (row.type !== 'add') oldLine += 1;
      if (row.type !== 'remove') newLine += 1;
      diff.append(line);
    });
    editing.append(summary, diff);
    layout.append(artifacts, editing);
    return layout;
  }
  function renderExample(example) {
    if (!example || typeof example.kind !== 'string') throw new Error('Missing example kind.');
    const scene = element('div', `example-scene example-${example.kind}`);
    scene.append(element('div', 'example-caption', example.label || 'Reconstructed / scripted example'));
    if (example.kind === 'code') {
      const tool = example.surface === 'tool';
      const surface = element('div', 'code-surface');
      surface.append(fileHeader(example.file, tool ? 'Tool output' : 'Markdown', tool ? 'search' : 'file'), codeBlock(example.body, { numbered: !tool }));
      scene.append(surface);
    } else if (example.kind === 'composer') scene.append(renderComposer(example));
    else if (example.kind === 'question') scene.append(renderQuestion(example));
    else if (example.kind === 'implementation') scene.append(renderImplementation(example));
    else throw new Error(`Unknown example component: ${example.kind}`);
    return scene;
  }
  globalThis.DeckComponents = { element, renderExample };
}());
