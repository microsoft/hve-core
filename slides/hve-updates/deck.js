// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  const startup = document.querySelector('#startup');
  if (!globalThis.Reveal || !globalThis.HVEContent || !globalThis.HVEComponents) {
    startup.setAttribute('role', 'alert');
    return;
  }
  const { sources, demos, rpiAgentSelection, participationQuestion, moveStep } = globalThis.HVEContent;
  const { element, icon, renderExample, renderAgentCue } = globalThis.HVEComponents;
  const states = new Map();
  const sections = [...document.querySelectorAll('.slides > section')];
  const dialog = document.querySelector('#detail-dialog');
  const dialogContent = document.querySelector('#dialog-content');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const motionButton = document.querySelector('#motion-button');
  const previous = document.querySelector('#previous-slide');
  const next = document.querySelector('#next-slide');
  let returnFocus = null;
  let ready = false;
  let motionEnabled = false;

  document.querySelector('#participation-example').append(renderExample(participationQuestion));
  document.querySelector('#agent-selection-example').append(renderExample(rpiAgentSelection));
  document.querySelectorAll('section[data-rpi-agent]').forEach(section => {
    section.querySelector(':scope > .eyebrow').replaceWith(renderAgentCue(opener => showDialog('agent', opener)));
  });

  function announce(text) {
    document.querySelector('#announcement').textContent = text;
  }

  function renderDemo(host, speak = false) {
    const name = host.dataset.demo;
    const demo = demos[name];
    const index = states.get(name);
    const step = demo.steps[index];
    host.querySelectorAll('.demo-phases li').forEach(item => {
      if (item.textContent === step.phase) item.setAttribute('aria-current', 'step');
      else item.removeAttribute('aria-current');
    });
    host.querySelector('.demo-state strong').textContent = step.state;
    host.querySelector('.demo-state p').textContent = name === 'install' ? 'Installation example' : 'Illustrative workflow';
    const titlebar = host.querySelector('.demo-main .editor-bar');
    titlebar.replaceChildren(icon(step.kind === 'graph' ? 'branch' : 'sparkle'), element('span', '', step.context), element('span', 'surface-tag', 'Reconstructed'));
    host.querySelector('.demo-heading h3').textContent = step.title;
    host.querySelector('.demo-heading p').textContent = `Step ${index + 1} of ${demo.steps.length} / ${step.phase}`;
    const body = host.querySelector('.demo-body');
    const hadComponentFocus = body.contains(document.activeElement);
    body.dataset.component = step.kind;
    body.replaceChildren(renderExample(step, {
      advance: () => performStep(host, 'next'),
      back: () => performStep(host, 'back')
    }));
    host.querySelector('.demo-insight').textContent = step.insight;
    host.querySelector('.demo-count').textContent = `${index + 1} / ${demo.steps.length}`;
    const back = host.querySelector('[data-action="back"]');
    const forward = host.querySelector('[data-action="next"]');
    const focused = document.activeElement;
    back.disabled = index === 0;
    forward.disabled = index === demo.steps.length - 1;
    if (focused === back && back.disabled) forward.focus();
    if (focused === forward && forward.disabled) back.focus();
    if (hadComponentFocus) {
      const target = body.querySelector('[data-install-focus], [data-install-action]');
      if (target) target.focus();
      else (forward.disabled ? back : forward).focus();
    }
    if (speak) announce(`${demo.label}, step ${index + 1} of ${demo.steps.length}. ${step.phase}: ${step.title}. ${step.state}.`);
  }

  function performStep(host, action) {
    const name = host.dataset.demo;
    states.set(name, moveStep(states.get(name), action, demos[name].steps.length));
    renderDemo(host, true);
  }

  document.querySelectorAll('[data-demo]').forEach(host => {
    const demo = demos[host.dataset.demo];
    if (!demo) throw new Error(`Missing demo content: ${host.dataset.demo}`);
    states.set(host.dataset.demo, 0);
    const sidebar = element('div', 'demo-sidebar');
    sidebar.append(element('span', 'label', demo.label));
    const phases = element('ol', 'demo-phases');
    phases.setAttribute('aria-label', demo.label);
    demo.phases.forEach(phase => phases.append(element('li', '', phase)));
    const state = element('div', 'demo-state');
    state.append(element('strong'), element('p'));
    sidebar.append(phases, state, element('div', 'demo-insight'));
    const main = element('div', 'demo-main');
    const heading = element('div', 'demo-heading');
    heading.append(element('h3'), element('p'));
    const controls = element('div', 'demo-controls');
    controls.setAttribute('role', 'group');
    controls.setAttribute('aria-label', `${demo.label} step controls`);
    for (const [action, label] of [['back', 'Back'], ['next', 'Next step'], ['reset', 'Reset']]) {
      const button = element('button', action === 'reset' ? 'demo-reset' : '', label);
      button.type = 'button';
      button.dataset.action = action;
      button.addEventListener('click', () => performStep(host, action));
      controls.append(button);
    }
    controls.append(element('output', 'demo-count'));
    main.append(element('div', 'editor-bar'), heading, element('div', 'demo-body'), controls);
    host.append(sidebar, main);
    renderDemo(host);
  });

  const deck = new Reveal({
    width: 1600, height: 900, margin: 0.015, center: false,
    controls: false, progress: false, hash: true, history: true,
    keyboard: false, overview: false, transition: 'none',
    transitionSpeed: 'fast', backgroundTransition: 'none',
    touch: true, loop: false, autoSlide: 0, help: false,
    disableLayout: false
  });

  function updateSlide() {
    const current = deck.getCurrentSlide();
    const index = sections.indexOf(current);
    sections.forEach(section => { section.inert = section !== current; });
    document.querySelector('#slide-count').textContent = `${index + 1} / ${sections.length}`;
    document.querySelector('#chapter-label').textContent = current.dataset.chapter;
    document.title = `${current.dataset.title} | HVE Core`;
    previous.disabled = index === 0;
    next.disabled = index === sections.length - 1;
    if (document.activeElement === previous && previous.disabled) next.focus();
    if (document.activeElement === next && next.disabled) previous.focus();
    announce(`Slide ${index + 1} of ${sections.length}. ${current.dataset.title}`);
  }

  function sourceList(ids) {
    const list = element('ol', 'source-list');
    ids.forEach(id => {
      const source = sources[id];
      if (!source) throw new Error(`Missing source: ${id}`);
      const item = document.createElement('li');
      const link = element('a', '', source.title);
      link.href = source.url;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      item.append(link, element('small', '', source.note));
      list.append(item);
    });
    return list;
  }

  function showDialog(kind, opener = document.activeElement) {
    if (!ready) return;
    returnFocus = opener instanceof HTMLElement ? opener : null;
    dialogContent.replaceChildren();
    const current = deck.getCurrentSlide();
    const title = document.querySelector('#dialog-title');
    dialog.dataset.view = kind;
    if (kind === 'agent') {
      title.textContent = 'Select RPI Agent in VS Code Chat';
      dialogContent.append(renderExample(rpiAgentSelection));
      dialogContent.append(element('p', 'source-note', 'RPI Agent coordinates the phases. The skills can also run on their own. This example does not change your Chat agent or permissions.'));
    } else if (kind === 'sources') {
      title.textContent = `Sources / ${current.dataset.title}`;
      dialogContent.append(element('p', '', 'References checked September 10, 2026. HVE source uses commit 3e29a0b2 unless a historical version is named. Example transcripts and results are scripted.'));
      dialogContent.append(sourceList(current.dataset.sources.split(',')));
      if (current.dataset.chapter === 'Plugins') {
        dialogContent.append(element('p', 'source-note', 'VS Code can read plugins installed by CLI in the same user home. VS Code-managed installations use a separate path by default. Manual sharing, remote environments, profiles and policy can affect discovery. This walkthrough does not install plugins.'));
      }
      const all = document.createElement('details');
      all.append(element('summary', '', 'All references and visual provenance'), sourceList(Object.keys(sources)));
      dialogContent.append(all);
    } else if (kind === 'notes') {
      title.textContent = `Presenter notes / ${current.dataset.title}`;
      dialogContent.append(element('p', '', current.querySelector('.notes').textContent));
      dialogContent.append(element('p', 'source-note', 'Anyone who receives the deck can read these notes. The examples are scripted; no live agent or installer runs here.'));
    } else if (kind === 'overview') {
      title.textContent = 'Slide index';
      const index = element('div', 'slide-index');
      sections.forEach((section, i) => {
        const button = element('button');
        button.type = 'button';
        button.append(element('small', '', `${String(i + 1).padStart(2, '0')} / ${section.dataset.chapter}`), element('span', '', section.dataset.title));
        if (section === current) button.setAttribute('aria-current', 'page');
        button.addEventListener('click', () => { dialog.close(); deck.slide(i); });
        index.append(button);
      });
      dialogContent.append(index);
    } else {
      title.textContent = 'Presentation keys';
      const grid = element('div', 'key-grid');
      [
        ['Left / Right', 'Previous / next slide. Page Up / Page Down and Space also navigate.'],
        ['Home / End', 'First / last slide.'],
        ['[ / ]', 'Previous / next demonstration step on a demo slide.'],
        ['R', 'Reset only the current demonstration.'],
        ['O', 'Open the slide index.'],
        ['S / N / ?', 'Sources / presenter notes / this help.'],
        ['F', 'Toggle full screen when the browser supports it.'],
        ['Motion button', 'Optional short slide fades. Off by default; reduced-motion preference takes priority.'],
        ['Escape', 'Close a dialog and return focus; exits browser full screen.'],
        ['Tab / Enter', 'Reach and activate visible controls. Arrow/Space shortcuts do not hijack focused controls.']
      ].forEach(([key, description]) => grid.append(element('kbd', '', key), element('span', '', description)));
      dialogContent.append(grid, element('p', 'source-note', 'Slides and demo steps are separate. Steps are preserved when revisiting a slide. Reload restores the slide URL but resets all demonstrations. Reduced-motion preference disables transitions. For presenting, use landscape desktop/full screen; compact screens retain navigation.'));
    }
    if (!dialog.open) dialog.showModal();
    dialog.scrollTop = 0;
    dialogContent.scrollTop = 0;
    document.querySelector('#close-dialog').focus();
  }

  dialog.addEventListener('close', () => {
    const active = document.activeElement;
    // Native restoration or a new user focus choice can precede the queued close event.
    if (active instanceof HTMLElement && active !== document.body && active !== document.documentElement
      && !dialog.contains(active) && !active.closest('[inert]')) return;
    if (returnFocus?.isConnected && !returnFocus.closest('[inert]') && !returnFocus.disabled) returnFocus.focus();
    else document.querySelector('#overview-button').focus();
  });
  dialog.addEventListener('keydown', event => {
    if (event.key !== 'Tab') return;
    const focusable = [...dialog.querySelectorAll('button, a[href], summary, input, select, textarea, [tabindex]:not([tabindex="-1"])')]
      .filter(node => !node.disabled && node.getClientRects().length > 0 && getComputedStyle(node).visibility !== 'hidden');
    const first = focusable[0];
    const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });
  document.querySelector('#close-dialog').addEventListener('click', () => dialog.close());
  document.querySelectorAll('[data-dialog]').forEach(button => button.addEventListener('click', () => showDialog(button.dataset.dialog, button)));
  document.querySelector('#overview-button').addEventListener('click', event => showDialog('overview', event.currentTarget));
  previous.addEventListener('click', () => { if (ready) deck.prev(); });
  next.addEventListener('click', () => { if (ready) deck.next(); });

  async function fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
      else throw new Error('Full screen is unavailable in this browser. Use the browser full-screen command.');
    } catch (error) {
      showDialog('help');
      dialogContent.prepend(element('p', 'source-note', `Full screen could not start: ${error.message}`));
    }
  }
  document.querySelector('#fullscreen-button').addEventListener('click', fullscreen);

  document.addEventListener('keydown', event => {
    if (!ready || dialog.open || event.altKey || event.ctrlKey || event.metaKey) return;
    const target = event.target;
    if (target instanceof Element && target.closest('button, a, input, textarea, select, summary, [contenteditable="true"]')) return;
    if (globalThis.getSelection()?.toString()) return;
    const key = event.key.toLowerCase();
    const activeDemo = deck.getCurrentSlide().querySelector('[data-demo]');
    const handled = ['arrowright', 'pagedown', ' ', 'arrowleft', 'pageup', 'home', 'end', 'o', 's', 'n', '?', 'f'].includes(key)
      || (activeDemo && ['[', ']', 'r'].includes(key));
    if (!handled) return;
    event.preventDefault();
    if (['arrowright', 'pagedown', ' '].includes(key)) event.shiftKey && key === ' ' ? deck.prev() : deck.next();
    else if (['arrowleft', 'pageup'].includes(key)) deck.prev();
    else if (key === 'home') deck.slide(0);
    else if (key === 'end') deck.slide(sections.length - 1);
    else if (key === 'f') void fullscreen();
    else if (['o', 's', 'n', '?'].includes(key)) showDialog({ o: 'overview', s: 'sources', n: 'notes', '?': 'help' }[key]);
    else performStep(activeDemo, { '[': 'back', ']': 'next', r: 'reset' }[key]);
  });
  function updateMotion() {
    const effective = motionEnabled && !reducedMotion.matches;
    deck.configure({ transition: effective ? 'fade' : 'none' });
    motionButton.setAttribute('aria-pressed', String(effective));
    motionButton.textContent = effective ? 'Motion on' : 'Motion off';
    motionButton.disabled = reducedMotion.matches;
    motionButton.title = reducedMotion.matches ? 'Reduced-motion preference is active' : 'Toggle optional slide fades';
  }
  motionButton.addEventListener('click', () => { motionEnabled = !motionEnabled; updateMotion(); });
  reducedMotion.addEventListener('change', updateMotion);
  deck.on('slidechanged', updateSlide);
  deck.initialize().then(() => {
    ready = true;
    updateMotion();
    startup.hidden = true;
    document.documentElement.dataset.deckReady = 'true';
    updateSlide();
  }).catch(error => {
    startup.textContent = `The presentation could not initialize: ${error.message}`;
    startup.setAttribute('role', 'alert');
  });
}());
