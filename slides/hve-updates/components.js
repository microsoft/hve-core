// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  const { graphs, mermaidSource, diffStats } = globalThis.HVEContent;
  let graphSerial = 0;

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function svgElement(tag, attributes = {}, text) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, String(value)));
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function icon(name) {
    const paths = {
      file: 'M6 3h8l4 4v14H6z M14 3v5h4 M9 12h6 M9 16h6',
      chevron: 'm8 10 4 4 4-4',
      send: 'M12 19V5 M6 11l6-6 6 6',
      plus: 'M12 5v14 M5 12h14',
      branch: 'M7 3v12a4 4 0 0 0 8 0V9 M4 3h6 M12 6h6v6h-6z',
      sparkle: 'm12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5z',
      check: 'm5 12 4 4L19 6',
      diff: 'M4 4h16v16H4z M12 4v16 M6 10h4 M15 9v6 M13 12h4',
      list: 'M8 6h12 M8 12h12 M8 18h12 M3 6h1 M3 12h1 M3 18h1',
      code: 'm8 6-5 6 5 6 M16 6l5 6-5 6 M14 3l-4 18',
      question: 'M9 8a3 3 0 0 1 6 0c0 3-3 3-3 6 M12 18h.01',
      plugin: 'M8 3v5 M16 3v5 M5 8h14v4a7 7 0 0 1-7 7v3 M7 8v4a5 5 0 0 0 10 0V8',
      close: 'm6 6 12 12 M18 6 6 18',
      search: 'M15 15l6 6 M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0',
      shield: 'm12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6z M8 12l3 3 5-6',
      gear: 'm10 3 4 0 .7 2.6 2 .9 2.4-.8 2 3.5-1.9 1.8v2.1l1.9 1.8-2 3.5-2.4-.8-2 .9L14 21h-4l-.7-2.6-2-.9-2.4.8-2-3.5 1.9-1.8v-2.1L2.9 9.1l2-3.5 2.4.8 2-.9z M15.5 12a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0',
      more: 'M5 12h.01 M12 12h.01 M19 12h.01',
      expand: 'M4 9V4h5 M15 4h5v5 M20 15v5h-5 M9 20H4v-5',
      panel: 'M4 4h16v16H4z M14 4v16',
      external: 'M14 3h7v7 M21 3l-9 9 M10 5H4v15h15v-6',
      home: 'm3 11 9-8 9 8 M5 10v11h5v-7h4v7h5V10',
      server: 'M4 4h16v6H4z M4 14h16v6H4z M7 7h.01 M7 17h.01',
      bulb: 'M9 18h6 M10 21h4 M8 14a7 7 0 1 1 8 0l-1 3H9z',
      book: 'M12 5v16 M12 5C9 3 5 3 3 4v15c3-1 6-1 9 2 3-3 6-3 9-2V4c-2-1-6-1-9 1',
      tools: 'M7 3v8 M4 3v5a3 3 0 0 0 6 0V3 M7 11v10 M17 3v18 M14 8h6v6h-6z',
      edit: 'm16 3 5 5-12 12-6 1 1-6z M13 6l5 5'
    };
    if (!paths[name]) throw new Error(`Unknown presentation icon: ${name}`);
    const svg = svgElement('svg', { viewBox: '0 0 24 24', class: 'ui-icon', 'aria-hidden': 'true' });
    svg.append(svgElement('path', { d: paths[name], fill: 'none', stroke: 'currentColor', 'stroke-width': 1.65, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }));
    return svg;
  }

  function codeBlock(text) {
    const pre = element('pre', 'demo-code numbered-code');
    const code = document.createElement('code');
    text.split('\n').forEach((line, index) => {
      const row = element('span', 'code-line');
      const number = element('span', 'line-number', String(index + 1));
      number.setAttribute('aria-hidden', 'true');
      const token = line.startsWith('#') ? 'tok-heading' : /^[\w -]+:/.test(line) ? 'tok-key' : '';
      row.append(number, element('span', `code-text ${token}`, line || ' '));
      code.append(row);
    });
    pre.append(code);
    return pre;
  }

  function fileHeader(name, label) {
    const header = element('div', 'file-header');
    header.append(icon('file'), element('span', '', name));
    if (label) header.append(element('span', 'file-state', label));
    return header;
  }

  function composer(step, compact = false) {
    const box = element('div', `copilot-composer${compact ? ' compact-composer' : ''}`);
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Reconstructed Copilot request composer; display only');
    if (!compact && step.attachments?.length) {
      const context = element('div', 'context-chips');
      step.attachments.forEach(name => {
        const chip = element('span', 'context-chip');
        chip.append(icon('file'), element('span', '', name));
        context.append(chip);
      });
      box.append(context);
    }
    box.append(element('div', compact ? 'composer-placeholder' : 'composer-text', compact ? 'Describe the next change...' : step.body));
    const toolbar = element('div', 'composer-toolbar');
    const attach = element('span', 'composer-tool');
    attach.append(icon('plus'));
    const mode = element('span', `composer-picker${step.mode === 'RPI Agent' ? ' rpi-selected-picker' : ''}`, step.mode || 'Agent');
    mode.append(icon('chevron'));
    const model = element('span', 'composer-picker', 'Auto');
    model.append(icon('chevron'));
    const send = element('span', 'composer-send');
    send.setAttribute('aria-hidden', 'true');
    send.append(icon('send'));
    toolbar.append(attach, mode, model, element('span', 'toolbar-space'), send);
    box.append(toolbar);
    return box;
  }

  function renderComposer(step) {
    const scene = element('div', 'copilot-scene');
    const identity = element('div', 'copilot-identity');
    identity.append(icon('sparkle'), element('span', '', 'GitHub Copilot'));
    scene.append(identity, composer(step));
    scene.append(element('p', 'reconstruction-caption', 'Use Next step to continue the example.'));
    return scene;
  }

  function renderAgentPicker(step) {
    const example = element('div', 'agent-picker-example');
    example.setAttribute('role', 'group');
    example.setAttribute('aria-label', 'VS Code Chat agent dropdown, showing RPI Agent selected');
    const menu = element('div', 'agent-picker-menu');
    const selected = element('div', 'agent-picker-option agent-picker-option-selected');
    selected.append(icon('check'), element('span', '', 'RPI Agent'), element('span', 'toolbar-space'), icon('edit'));
    menu.append(selected);
    for (const name of ['Security Planner', 'Security Reviewer', 'SSSC Planner', 'SSSC Reviewer', 'System Architecture Reviewer', 'UX UI Designer']) {
      menu.append(element('div', 'agent-picker-option', name));
    }
    menu.append(element('div', 'agent-picker-configure', 'Configure Custom Agents...'));
    example.append(menu, composer({ mode: 'RPI Agent' }, true));
    example.append(element('p', 'agent-picker-caption', step.body));
    return example;
  }

  function renderAgentCue(openExample) {
    const cue = element('div', 'rpi-agent-cue');
    cue.setAttribute('role', 'group');
    cue.setAttribute('aria-label', 'RPI Agent selection guidance');
    const picker = element('button', 'rpi-agent-cue-picker');
    picker.type = 'button';
    picker.setAttribute('aria-haspopup', 'dialog');
    picker.setAttribute('aria-label', 'Show how to select RPI Agent in VS Code Chat');
    picker.append(icon('check'), element('span', '', 'RPI Agent'), icon('chevron'));
    picker.addEventListener('click', () => openExample(picker));
    cue.append(element('span', 'rpi-agent-cue-context', 'VS Code Copilot Chat'), element('span', 'rpi-agent-cue-action', 'Switch the agent dropdown to'), picker, element('span', 'rpi-agent-cue-scope', 'For coordinated RPI'));
    return cue;
  }

  function renderQuestion(step) {
    const scene = element('div', 'question-scene');
    const card = element('div', 'copilot-question');
    card.setAttribute('role', 'group');
    card.setAttribute('aria-label', 'Example Copilot question');
    const header = element('div', 'question-header');
    header.append(element('h4', '', step.body), element('span', 'toolbar-space'), icon('close'), icon('chevron'));
    card.append(header);
    const options = element('ol', 'question-options');
    const selected = step.selected ?? step.options.findIndex(option => option.recommended);
    step.options.forEach((option, index) => {
      const row = element('li', `question-option${index === selected ? ' selected-option' : ''}`);
      row.append(element('span', 'option-index', String(index + 1)));
      const copy = element('div', 'option-copy');
      const title = element('div', 'option-title', option.label);
      if (option.recommended) title.append(element('span', 'recommended-tag', 'Recommended'));
      copy.append(title, element('div', 'option-description', option.detail));
      row.append(copy);
      if (index === selected) {
        row.append(icon('check'), element('span', 'sr-only', 'Shown selected'));
      }
      options.append(row);
    });
    const freeform = element('div', 'question-freeform');
    freeform.append(element('span', 'option-index', String(step.options.length + 1)), element('span', 'question-custom-answer', 'Enter custom answer'));
    const footer = element('div', 'question-footer');
    const prior = icon('chevron');
    prior.classList.add('question-previous');
    const next = icon('chevron');
    next.classList.add('question-next');
    footer.append(prior, next, element('span', '', '1 / 1'), element('span', 'toolbar-space'), element('span', '', 'Example question'));
    card.append(options, freeform, footer);
    scene.append(card);
    return scene;
  }

  function renderAnswer(step) {
    const scene = element('div', 'answer-scene');
    const header = element('div', 'answer-header');
    header.append(icon('check'), element('span', '', 'Answered 1 question'));
    const summary = element('div', 'copilot-answer');
    summary.append(element('div', 'answered-question', step.body));
    const response = element('div', 'answer-branch');
    response.append(icon('branch'), element('div', 'answer-value', step.answer));
    summary.append(response, element('p', 'answer-detail', step.detail));
    scene.append(header, summary, composer({ mode: 'RPI Agent' }, true));
    return scene;
  }

  function edgePath(from, to) {
    if (Math.abs(from.y - to.y) < 12 && to.x > from.x) {
      return `M ${from.x + from.width} ${from.y + from.height / 2} H ${to.x}`;
    }
    const downward = to.y > from.y;
    const startX = from.x + from.width / 2;
    const startY = downward ? from.y + from.height : from.y;
    const endX = to.x + to.width / 2;
    const endY = downward ? to.y : to.y + to.height;
    const middle = (startY + endY) / 2;
    return `M ${startX} ${startY} V ${middle} H ${endX} V ${endY}`;
  }

  function graphSVG(graph, type) {
    const marker = `diagram-arrow-${++graphSerial}`;
    const titleId = `${marker}-title`;
    const svg = svgElement('svg', { viewBox: `0 0 1130 ${type === 'plan' ? 335 : 340}`, class: `component-graph ${type}-graph`, role: 'img', 'aria-labelledby': titleId });
    svg.append(svgElement('title', { id: titleId }, `${graph.title}. ${graph.edges.map(([from, to]) => `${from} to ${to}`).join('; ')}.`));
    const defs = svgElement('defs');
    const arrow = svgElement('marker', { id: marker, viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' });
    arrow.append(svgElement('path', { d: 'M 1 1 L 9 5 L 1 9', fill: 'none', stroke: '#a2a9b3', 'stroke-width': 1.4 }));
    defs.append(arrow);
    svg.append(defs);
    if (type === 'research') {
      svg.append(svgElement('rect', { x: 726, y: 106, width: 366, height: 228, rx: 12, class: 'subagent-frame' }));
      svg.append(svgElement('text', { x: 745, y: 129, class: 'graph-group-label' }, 'SUBAGENT LANE / ILLUSTRATIVE'));
    }
    const byId = new Map(graph.nodes.map(node => [node.id, node]));
    graph.edges.forEach(([from, to]) => {
      svg.append(svgElement('path', { d: edgePath(byId.get(from), byId.get(to)), class: 'graph-edge', 'marker-end': `url(#${marker})` }));
    });
    graph.nodes.forEach(node => {
      const group = svgElement('g', { class: `graph-node ${node.kind || 'plan-node'}` });
      group.append(svgElement('rect', { x: node.x, y: node.y, width: node.width, height: node.height, rx: 8 }));
      group.append(svgElement('text', { x: node.x + 20, y: node.y + 31, class: 'graph-node-label' }, node.label));
      group.append(svgElement('text', { x: node.x + 20, y: node.y + 57, class: 'graph-node-detail' }, node.detail));
      svg.append(group);
    });
    return svg;
  }

  function renderDebug(step) {
    const surface = element('div', 'debug-surface');
    const breadcrumb = element('div', 'debug-breadcrumb');
    breadcrumb.append(icon('branch'), element('span', '', 'Agent Debug Logs'), element('span', '', '/'), element('strong', '', 'Agent Flow Chart'), element('span', 'preview-tag', 'Preview'));
    const legend = element('div', 'graph-legend');
    for (const [kind, label] of [['model', 'Model turn'], ['tool', 'Tool call'], ['subagent', 'Subagent']]) {
      legend.append(element('span', `legend-${kind}`, label));
    }
    surface.append(breadcrumb, graphSVG(graphs[step.graph], 'research'), legend);
    return surface;
  }

  function renderPlan(step) {
    const graph = graphs[step.graph];
    const surface = element('div', 'plan-surface');
    const header = fileHeader('snack-queue-plan.md', 'Preview');
    const toggle = element('button', 'plan-view-toggle', 'Mermaid source');
    toggle.type = 'button';
    toggle.setAttribute('aria-pressed', 'false');
    const content = element('div', 'plan-preview-content');
    content.append(graphSVG(graph, 'plan'));
    toggle.addEventListener('click', () => {
      const showSource = toggle.getAttribute('aria-pressed') !== 'true';
      toggle.setAttribute('aria-pressed', String(showSource));
      toggle.textContent = showSource ? 'Diagram preview' : 'Mermaid source';
      content.replaceChildren(showSource ? codeBlock(mermaidSource(graph)) : graphSVG(graph, 'plan'));
    });
    header.append(toggle);
    surface.append(header, element('div', 'plan-preview-heading', graph.title), content);
    return surface;
  }

  function renderImplementation(step) {
    const scene = element('div', 'implementation-scene');
    const artifacts = element('div', 'implementation-artifacts');
    const plan = element('div', 'result-document');
    plan.append(fileHeader('snack-queue-plan.md', 'Completed'));
    const checklist = element('div', 'completed-checklist');
    checklist.append(element('strong', '', 'P01 / Local snack voting'));
    step.tasks.forEach(task => {
      const row = element('div', 'completed-task');
      const mark = element('span', 'completed-box', '\u2713');
      mark.setAttribute('aria-label', 'Completed');
      row.append(mark, element('code', '', task));
      checklist.append(row);
    });
    plan.append(checklist);
    const log = element('div', 'result-document');
    log.append(fileHeader('changes.md', 'Evidence'), codeBlock(step.changes));
    artifacts.append(plan, log);
    const editing = element('div', 'implementation-editing');
    const summary = element('div', 'changed-file-summary');
    const title = element('div', 'changed-files-heading');
    title.append(icon('chevron'), element('strong', '', 'Changed 1 file'), element('span', 'toolbar-space'), icon('diff'));
    const stats = diffStats(step.diff);
    const file = element('div', 'changed-file');
    file.append(icon('file'), element('code', '', step.file), element('span', 'toolbar-space'), element('span', 'diff-added', `+${stats.added}`), element('span', 'diff-removed', `-${stats.removed}`));
    summary.append(title, file);
    const diff = element('div', 'inline-diff');
    diff.setAttribute('aria-label', `${step.file} illustrative diff: ${stats.added} lines added and ${stats.removed} removed`);
    step.diff.forEach(line => {
      const row = element('div', `diff-row diff-${line.type}`);
      const old = element('span', 'diff-line-number', String(line.old));
      const next = element('span', 'diff-line-number', String(line.next));
      old.setAttribute('aria-hidden', 'true');
      next.setAttribute('aria-hidden', 'true');
      row.append(old, next, element('span', 'diff-sign', line.type === 'add' ? '+' : line.type === 'remove' ? '-' : ' '), element('code', '', line.text));
      diff.append(row);
    });
    editing.append(summary, diff, composer({ mode: 'RPI Agent' }, true));
    scene.append(artifacts, editing);
    return scene;
  }

  function renderCode(step) {
    const surface = element('div', 'code-surface');
    surface.append(fileHeader(step.context, 'Markdown'), codeBlock(step.body));
    return surface;
  }

  function renderChatEntry(step, actions) {
    const scene = element('div', 'chat-launch-scene install-view-chat');
    const chat = element('div', 'chat-launch-panel');
    chat.setAttribute('role', 'group');
    chat.setAttribute('aria-label', 'Reconstructed VS Code Chat panel header');
    const header = element('div', 'chat-launch-header');
    const toolbar = element('div', 'chat-launch-toolbar');
    toolbar.append(icon('plus'), icon('chevron'));
    const gearWrap = element('div', 'chat-customizations-anchor');
    const gear = element('button', 'chat-customizations-button');
    gear.type = 'button';
    gear.dataset.installAction = 'customizations';
    gear.setAttribute('aria-label', 'Open Customizations');
    gear.setAttribute('aria-describedby', 'chat-customizations-tooltip');
    gear.append(icon('gear'));
    gear.addEventListener('click', () => actions.advance());
    const tooltip = element('span', 'chat-customizations-tooltip', step.body);
    tooltip.id = 'chat-customizations-tooltip';
    tooltip.setAttribute('role', 'tooltip');
    gearWrap.append(gear, tooltip);
    toolbar.append(gearWrap, icon('more'), icon('expand'), icon('close'));
    header.append(element('span', 'chat-view-title', 'Chat'), element('span', 'toolbar-space'), toolbar);
    const sessions = element('div', 'chat-launch-sessions');
    sessions.append(element('strong', '', 'Sessions'), element('span', 'toolbar-space'), icon('panel'));
    chat.append(header, sessions, element('div', 'chat-launch-empty'));
    scene.append(chat, element('p', 'chat-launch-caption', 'The Chat gear opens the Agent Customizations editor.'));
    return scene;
  }

  function renderInstall(step, actions) {
    if (step.view === 'chat') return renderChatEntry(step, actions);
    const window = element('div', `customization-window install-view-${step.view}`);
    window.setAttribute('role', 'group');
    window.setAttribute('aria-label', 'Reconstructed Agent Customizations editor; local walkthrough');
    const titlebar = element('div', 'customization-titlebar');
    titlebar.append(element('strong', '', 'Agent Customizations'), element('span', 'customization-harness', '(Copilot \u00b7 snack-mission-control)'), element('span', 'toolbar-space'), icon('external'), icon('expand'), icon('close'));
    const shell = element('div', 'customization-shell');
    const sidebar = element('div', 'customization-sidebar');
    sidebar.setAttribute('aria-label', 'Customization categories');
    const categories = [['Overview', 'home'], ['Plugins', 'plugin'], ['MCP Servers', 'server'], ['Skills', 'bulb'], ['Instructions', 'book'], ['Agents', 'code'], ['Hooks', 'branch'], ['Tools', 'tools']];
    categories.forEach(([label, glyph]) => {
      const selected = label === 'Plugins';
      const item = element('div', `customization-category${selected ? ' selected-category' : ''}`);
      item.append(icon(glyph), element('span', '', label));
      if (selected) {
        item.setAttribute('aria-current', 'page');
        item.append(element('span', 'category-count', step.view === 'installed' ? '1' : '0'));
      }
      sidebar.append(item);
    });
    const content = element('div', 'customization-content');
    const heading = element('div', 'plugins-heading');
    heading.append(element('h4', '', 'Plugins'));
    const search = element('div', 'plugin-search-hint', 'Type to search...');
    content.append(heading, element('p', 'customization-description', 'Extend your agent with skills, commands and integrations.'), search);
    const featured = element('div', 'plugin-featured');
    const featuredTitle = element('div', 'plugin-section-title');
    const collapsed = icon('chevron');
    collapsed.classList.add('collapsed-chevron');
    featuredTitle.append(collapsed, element('strong', '', 'Featured'));
    featured.append(featuredTitle);
    content.append(featured);
    const installed = element('div', 'plugin-section');
    const sectionTitle = element('div', 'plugin-section-title');
    sectionTitle.append(icon('chevron'), element('strong', '', 'Installed'), element('span', 'plugin-section-count', step.view === 'installed' ? '1' : '0'));
    installed.append(sectionTitle);
    if (step.view === 'installed') {
      const row = element('div', 'installed-plugin-row');
      const copy = element('div', 'installed-plugin-copy');
      copy.append(element('strong', '', 'hve-core'), element('span', '', 'microsoft/hve-core'));
      const enabled = element('span', 'plugin-enabled');
      const toggle = element('span', 'plugin-toggle-illustration');
      toggle.setAttribute('aria-hidden', 'true');
      enabled.append(toggle, element('span', '', 'Enabled'));
      row.append(copy, enabled, icon('more'));
      installed.append(row);
    } else {
      installed.append(element('p', 'plugins-empty', 'No plugins installed in this example.'));
    }
    const available = element('div', 'plugin-section plugin-available');
    const availableHeader = element('div', 'plugin-section-title');
    availableHeader.append(icon('chevron'), element('strong', '', 'Available'), element('span', 'toolbar-space'));
    if (step.view === 'plugins') {
      const install = element('button', 'install-source-button', 'Install from Source');
      install.type = 'button';
      install.dataset.installAction = 'source';
      install.title = 'Open the source-entry step in this walkthrough';
      install.addEventListener('click', () => actions.advance());
      availableHeader.append(install);
    } else {
      availableHeader.append(element('span', 'install-source-label', 'Install from Source'));
    }
    available.append(availableHeader, element('p', 'plugins-available-copy', 'Browse and install plugins from your marketplaces.'));
    content.append(installed, available);
    shell.append(sidebar, content);
    window.append(titlebar, shell);
    if (step.view === 'source') {
      const quick = element('div', 'source-quick-input');
      quick.id = 'install-source-quick-input';
      quick.setAttribute('role', 'group');
      quick.setAttribute('aria-label', 'Plugin source quick input, illustrative');
      const inputRow = element('div', 'source-input-row');
      const input = element('input', 'source-input');
      input.type = 'text';
      input.readOnly = true;
      input.value = step.source;
      input.spellcheck = false;
      input.setAttribute('aria-label', 'Plugin source, prefilled example');
      input.setAttribute('aria-describedby', 'install-source-prompt');
      input.dataset.installFocus = 'true';
      input.addEventListener('keydown', event => {
        if (event.key !== 'Enter' && event.key !== 'Escape') return;
        event.preventDefault();
        event.stopPropagation();
        if (event.key === 'Enter') actions.advance();
        else actions.back();
      });
      const close = element('button', 'source-input-close');
      close.type = 'button';
      close.setAttribute('aria-label', 'Close source example');
      close.append(icon('close'));
      close.addEventListener('click', () => actions.back());
      inputRow.append(input, close);
      const prompt = element('p', 'source-input-prompt', step.body);
      prompt.id = 'install-source-prompt';
      quick.append(inputRow, prompt, element('div', 'source-input-help', 'Enter: next example step   /   Esc: back   /   No installation'));
      window.append(quick);
    } else if (step.view === 'trust') {
      const note = element('div', 'source-trust-note');
      note.append(icon('shield'), element('strong', '', 'Next in the real flow: review trust'));
      note.append(element('code', '', step.source), element('p', '', step.body));
      note.append(element('span', '', 'Illustrative checkpoint. Use Next step to view the example result.'));
      window.append(note);
    }
    window.append(element('div', 'customization-status', step.view === 'installed' ? 'Example installed state / no client was changed' : 'Reconstructed VS Code UI / presentation controls remain below'));
    return window;
  }

  function renderExample(step, actions) {
    const renderers = { 'agent-picker': renderAgentPicker, composer: renderComposer, question: renderQuestion, answer: renderAnswer, graph: renderDebug, plan: renderPlan, implementation: renderImplementation, code: renderCode, install: renderInstall };
    const render = renderers[step.kind];
    if (!render) throw new Error(`Unknown example component: ${step.kind}`);
    return render(step, actions);
  }

  globalThis.HVEComponents = { element, icon, renderExample, renderAgentCue };
}());
