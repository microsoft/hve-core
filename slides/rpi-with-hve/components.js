// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
// cspell:words titlebar sublabel
(function () {
  'use strict';
  let flowSerial = 0;
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
    folder: 'M3 5h7l2 3h9v12H3z',
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
  function codeBlock(text, { numbered = true, startLine = 1 } = {}) {
    if (!Number.isInteger(startLine) || startLine < 1) throw new Error('Invalid excerpt start line.');
    const pre = element('pre', `numbered-code${numbered ? '' : ' plain-code'}`);
    const code = element('code');
    text.split('\n').forEach((line, index) => {
      const row = element('span', 'code-line');
      if (numbered) {
        const number = element('span', 'line-number', String(index + startLine));
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
    plan.append(fileHeader(example.plan, 'Agent report'));
    const checklist = element('div', 'completed-checklist');
    checklist.append(element('strong', '', example.phaseTitle));
    example.tasks.forEach(task => {
      const row = element('div', 'completed-task');
      const mark = element('span', 'completed-box', '\u2713');
      mark.setAttribute('aria-hidden', 'true');
      row.append(mark, element('span', 'sr-only', 'Reported complete: '), element('code', '', task));
      checklist.append(row);
    });
    plan.append(checklist);
    const log = element('div', 'code-surface');
    log.append(fileHeader('log-retention-changes.md', 'Checks'), codeBlock(example.changes, { numbered: false }));
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
  function editorContents(editor) {
    const content = document.createDocumentFragment();
    if (editor.kind === 'files') {
      const files = element('ul', 'workbench-files');
      editor.files.forEach(name => {
        const row = element('li');
        row.append(icon(name.endsWith('/') ? 'folder' : 'file'), element('code', '', name));
        files.append(row);
      });
      content.append(files);
    } else if (editor.kind === 'code') {
      content.append(codeBlock(editor.body, { numbered: editor.numbered !== false, startLine: editor.startLine ?? 1 }));
    } else if (editor.kind === 'definitions') {
      const meanings = element('dl', 'workbench-meanings');
      editor.meanings.forEach(meaning => {
        const description = element('dd');
        description.append(element('code', '', meaning.path), element('p', '', meaning.use));
        meanings.append(element('dt', '', meaning.name), description);
      });
      content.append(meanings);
    } else throw new Error(`Unknown workbench pane: ${editor.kind}`);
    return content;
  }
  function renderWorkbench(example) {
    const { editor, messages } = example;
    if (!editor || !Array.isArray(messages) || !messages.length) throw new Error('Incomplete scripted workbench.');
    const workbench = element('div', 'workbench');
    workbench.dataset.focus = example.focus;
    workbench.setAttribute('role', 'group');
    workbench.setAttribute('aria-label', 'Scripted VS Code workbench; display only');
    const titlebar = element('div', 'workbench-titlebar');
    const commandCenter = element('div', 'workbench-command-center');
    commandCenter.append(icon('search'), element('span', '', example.workspace));
    titlebar.append(element('span', '', 'VS Code'), commandCenter, element('span', 'workbench-window-mark', '...'));
    const grid = element('div', 'workbench-grid');
    const activity = element('div', 'workbench-activity');
    activity.setAttribute('aria-hidden', 'true');
    for (const name of ['file', 'search', 'sparkle']) activity.append(icon(name));
    const filePane = element('div', 'workbench-editor');
    const fileHeading = element('div', 'workbench-pane-heading');
    fileHeading.append(icon(editor.kind === 'files' ? 'folder' : 'file'), element('h4', '', editor.title));
    filePane.append(fileHeading, element('p', 'workbench-caption', editor.caption), editorContents(editor));
    const chat = element('div', 'workbench-chat');
    const chatHeading = element('div', 'workbench-pane-heading');
    chatHeading.append(icon('sparkle'), element('h4', '', 'Chat'), element('span', 'workbench-agent', example.agent));
    const conversation = element('div', 'workbench-conversation');
    messages.forEach(message => {
      if (!['request', 'message', 'tool', 'helper', 'notice', 'summary', 'answer'].includes(message.kind)) {
        throw new Error(`Unknown scripted message: ${message.kind}`);
      }
      const item = element('div', `workbench-message workbench-message-${message.kind}`);
      item.append(element('strong', 'workbench-speaker', message.title));
      if (message.detail) item.append(element('div', 'workbench-detail', message.detail));
      if (message.kind === 'request') item.append(composer({ body: message.body, mode: 'Agent' }));
      else if (['tool', 'summary'].includes(message.kind)) item.append(codeBlock(message.body, { numbered: false }));
      else item.append(element('p', '', message.body));
      conversation.append(item);
    });
    chat.append(chatHeading, conversation);
    grid.append(activity, filePane, chat);
    const status = element('div', 'workbench-status');
    status.append(element('span', '', 'main'), element('span', '', 'No connected agent'));
    workbench.append(titlebar, grid, status);
    return workbench;
  }
  function flowArrow(from, to) {
    const arrow = svgElement('svg', {
      viewBox: '0 0 30 22', class: 'debug-flow-arrow',
      'aria-hidden': 'true', focusable: 'false', 'data-from': from, 'data-to': to
    });
    arrow.append(svgElement('path', {
      d: 'M15 1V19M9 13L15 19L21 13',
      fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8,
      'stroke-linecap': 'round', 'stroke-linejoin': 'round'
    }));
    return arrow;
  }
  function renderAgentFlow(example) {
    const { demos, flowKinds, flowTrace } = globalThis.DeckContent;
    const trace = flowTrace(example.flow?.nodes);
    const nodes = new Map(trace.nodes.map(node => [node.id, node]));
    if (!nodes.has(example.flow.selected)) throw new Error('The selected event is outside the flow excerpt.');
    const prefix = `agent-flow-${++flowSerial}`;
    const surface = element('div', 'agent-debugger');
    const breadcrumb = element('div', 'debug-breadcrumb');
    for (const [index, label] of ['Agent Debug Logs', 'Tracking files', 'Agent Flow Chart'].entries()) {
      if (index) {
        const separator = element('span', 'debug-breadcrumb-separator', '\u203a');
        separator.setAttribute('aria-hidden', 'true');
        breadcrumb.append(separator);
      }
      breadcrumb.append(element(index === 2 ? 'strong' : 'span', '', label));
    }
    const legend = element('div', 'debug-legend');
    for (const kind of ['modelTurn', 'toolCall', 'subagentInvocation', 'agentResponse', 'generic']) {
      legend.append(element('span', `debug-legend-${kind}`, flowKinds[kind]));
    }
    legend.append(element('span', 'debug-flow-hint', 'Focused trace / select a node'));
    const panes = element('div', 'debug-panes');
    const diagram = element('div', 'debug-diagram');
    diagram.setAttribute('role', 'group');
    diagram.setAttribute('aria-label', 'Agent Flow Chart, focused excerpt');
    diagram.setAttribute('aria-describedby', `${prefix}-description`);
    const sequence = trace.nodes.map(node => `${node.label} (${flowKinds[node.kind]}${node.parent ? ', inside Explore' : ''})`).join(' to ');
    const description = element('p', 'sr-only', `Arrows connect ${sequence}. This is a focused excerpt; other events are omitted.`);
    description.id = `${prefix}-description`;
    const list = element('ol', 'debug-trace');
    const groups = new Map();
    const buttons = new Map();
    const inspector = element('div', 'debug-inspector');
    const inspectorKind = element('div', 'debug-inspector-kind');
    const inspectorTitle = element('h4', 'debug-inspector-title');
    inspectorTitle.id = `${prefix}-title`;
    const inspectorHeading = element('div', 'debug-inspector-heading');
    inspectorHeading.append(inspectorTitle, inspectorKind);
    const views = element('div', 'debug-detail-views');
    views.setAttribute('role', 'group');
    views.setAttribute('aria-label', 'Event detail view');
    const eventButton = element('button', '', 'Event');
    const contextButton = element('button', '', 'Missed context');
    for (const button of [eventButton, contextButton]) {
      button.type = 'button';
      button.setAttribute('aria-controls', `${prefix}-details`);
    }
    const details = element('div', 'debug-inspector-body');
    details.id = `${prefix}-details`;
    details.tabIndex = 0;
    details.setAttribute('role', 'region');
    details.setAttribute('aria-labelledby', inspectorTitle.id);
    details.addEventListener('keydown', event => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'PageUp', 'PageDown', 'Home', 'End'].includes(event.key)) {
        event.stopPropagation();
      }
    });
    let selected = example.flow.selected;
    function selectNode(id, view = 'event') {
      const node = nodes.get(id);
      if (!node || !['event', 'context'].includes(view)) throw new Error('Invalid flow detail selection.');
      const source = demos.tracking.steps[node.sourceStep];
      const message = source?.messages[node.messageIndex];
      if (!message) throw new Error(`Missing event evidence: ${id}`);
      selected = id;
      surface.dataset.selectedEvent = id;
      surface.dataset.detailView = view;
      buttons.forEach((button, key) => button.setAttribute('aria-pressed', String(key === id)));
      eventButton.setAttribute('aria-pressed', String(view === 'event'));
      contextButton.setAttribute('aria-pressed', String(view === 'context'));
      inspectorKind.textContent = `${flowKinds[node.kind]} / ${node.parent ? 'Explore' : 'Agent'}`;
      inspectorTitle.textContent = node.label;
      details.replaceChildren();
      if (view === 'context') {
        const caption = element('p', 'debug-context-label', 'Presenter-only context: ');
        caption.append(element('code', '', source.editor.title), ` / ${source.editor.caption}`);
        details.append(caption, editorContents(source.editor));
      } else {
        if (message.detail) details.append(element('h5', '', 'Input'), codeBlock(message.detail, { numbered: false }));
        const heading = message.kind === 'tool' ? 'Output' : message.kind === 'summary' ? 'Retained summary' : 'Message';
        details.append(element('h5', '', heading));
        details.append(['tool', 'summary'].includes(message.kind)
          ? codeBlock(message.body, { numbered: false })
          : element('p', message.kind === 'answer' ? 'debug-unsupported' : 'debug-message', message.body));
        if (node.note) details.append(element('p', 'debug-context-caption', node.note));
      }
      details.scrollTop = 0;
    }
    function nodeButton(node) {
      const button = element('button', `debug-event debug-event-${node.kind}`);
      button.type = 'button';
      button.dataset.flowNode = node.id;
      button.setAttribute('aria-controls', details.id);
      const detail = node.sublabel === flowKinds[node.kind] ? '' : ` ${node.sublabel}.`;
      button.setAttribute('aria-label', `${flowKinds[node.kind]}: ${node.label}.${detail} Inspect event.`);
      if (node.id === example.flow.selected) button.setAttribute('aria-current', 'step');
      button.append(element('strong', 'debug-node-label', node.label), element('span', 'debug-node-detail', node.sublabel));
      button.addEventListener('click', () => selectNode(node.id));
      buttons.set(node.id, button);
      return button;
    }
    trace.nodes.forEach((node, index) => {
      const entry = element('li', 'debug-trace-entry');
      if (index) entry.append(flowArrow(trace.nodes[index - 1].id, node.id));
      if (node.kind === 'subagentInvocation') {
        const group = element('div', 'debug-subgraph');
        group.setAttribute('role', 'group');
        group.setAttribute('aria-label', `${node.label} subagent`);
        const children = element('ol', 'debug-child-trace');
        group.append(nodeButton(node), children);
        entry.append(group);
        list.append(entry);
        groups.set(node.id, children);
      } else {
        entry.append(nodeButton(node));
        (node.parent ? groups.get(node.parent) : list).append(entry);
      }
    });
    const orderedButtons = [...buttons.values()];
    orderedButtons.forEach((button, index) => {
      button.addEventListener('keydown', event => {
        if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
        const delta = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }[event.key];
        if (delta === undefined && !['Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        event.stopPropagation();
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? orderedButtons.length - 1
          : Math.max(0, Math.min(orderedButtons.length - 1, index + delta));
        orderedButtons[next].focus();
      });
    });
    eventButton.addEventListener('click', () => selectNode(selected, 'event'));
    contextButton.addEventListener('click', () => selectNode(selected, 'context'));
    views.append(eventButton, contextButton);
    inspector.append(inspectorHeading, views, details);
    diagram.append(description, list);
    panes.append(diagram, inspector);
    surface.append(breadcrumb, legend, panes);
    selectNode(selected, example.flow.detailView ?? 'event');
    return surface;
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
    else if (example.kind === 'workbench') scene.append(renderWorkbench(example));
    else if (example.kind === 'agent-flow') scene.append(renderAgentFlow(example));
    else throw new Error(`Unknown example component: ${example.kind}`);
    return scene;
  }
  globalThis.DeckComponents = { element, renderExample };
}());
