// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(async function () {
  'use strict';
  function showError(error) {
    console.error(error);
    let notice = document.querySelector('#startup');
    if (!notice) {
      notice = document.createElement('div');
      notice.id = 'startup';
      document.body.prepend(notice);
    }
    notice.hidden = false;
    notice.setAttribute('role', 'alert');
    notice.textContent = `The presentation could not start: ${error.message}`;
  }
  try {
    if (!globalThis.Reveal || !globalThis.DeckConfig || !globalThis.DeckContent || !globalThis.DeckComponents) {
      throw new Error('Required local assets are missing. Build the deck and open dist/index.html.');
    }
    const required = selector => {
      const node = document.querySelector(selector);
      if (!node) throw new Error(`Missing presentation element: ${selector}`);
      return node;
    };
    const { sources, examples, demos, moveStep } = globalThis.DeckContent;
    const { element, renderExample } = globalThis.DeckComponents;
    const config = globalThis.DeckConfig;
    const startup = required('#startup');
    const sections = [...document.querySelectorAll('.slides > section')];
    if (!sections.length || new Set(sections.map(section => section.id)).size !== sections.length) {
      throw new Error('The deck requires slides with unique IDs.');
    }
    const sourceIds = section => (section.dataset.sources || '').split(',').map(id => id.trim()).filter(Boolean);
    sections.forEach(section => {
      if (!section.id || !section.dataset.title || !section.dataset.chapter) throw new Error('Each slide needs an ID, title and chapter.');
      for (const id of sourceIds(section)) {
        if (!sources[id]) throw new Error(`Missing citation: ${id}`);
        if (!['https:', 'http:'].includes(new URL(sources[id].url).protocol)) throw new Error(`Unsupported citation URL: ${id}`);
      }
    });
    document.querySelectorAll('[data-deck-title]').forEach(node => { node.textContent = config.title; });
    document.querySelectorAll('[data-deck-description]').forEach(node => { node.textContent = config.description; });
    document.querySelectorAll('[data-example]').forEach(node => {
      if (!examples[node.dataset.example]) throw new Error(`Missing example: ${node.dataset.example}`);
      node.replaceChildren(renderExample(examples[node.dataset.example]));
    });
    const previous = required('#previous-slide');
    const next = required('#next-slide');
    const overview = required('#overview-button');
    const motionButton = required('#motion-button');
    const dialog = required('#detail-dialog');
    const dialogContent = required('#dialog-content');
    const closeDialog = required('#close-dialog');
    const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
    const states = new Map();
    let returnFocus = null;
    let motionEnabled = false;
    let ready = false;
    const announce = text => { required('#announcement').textContent = text; };

    function renderDemo(host, speak = false) {
      const demo = demos[host.dataset.demo];
      const index = states.get(host.dataset.demo);
      const step = demo.steps[index];
      host.querySelectorAll('.demo-phases li').forEach(item => {
        if (item.textContent === step.phase) item.setAttribute('aria-current', 'step');
        else item.removeAttribute('aria-current');
      });
      host.querySelector('.demo-state strong').textContent = step.state;
      host.querySelector('.demo-insight').textContent = step.insight;
      host.querySelector('.demo-header h3').textContent = step.title;
      host.querySelector('.demo-count').textContent = `${index + 1} / ${demo.steps.length}`;
      host.querySelector('.demo-body').replaceChildren(renderExample(step));
      const back = host.querySelector('[data-action="back"]');
      const forward = host.querySelector('[data-action="next"]');
      const focused = document.activeElement;
      back.disabled = index === 0;
      forward.disabled = index === demo.steps.length - 1;
      if ((focused === back && back.disabled) || (focused === forward && forward.disabled)) {
        (back.disabled ? forward.disabled ? host.querySelector('[data-action="reset"]') : forward : back).focus();
      }
      if (speak) announce(`${demo.label}. Step ${index + 1} of ${demo.steps.length}. ${step.phase}. ${step.state}.`);
    }
    function performStep(host, action) {
      const name = host.dataset.demo;
      states.set(name, moveStep(states.get(name), action, demos[name].steps.length));
      renderDemo(host, true);
    }
    document.querySelectorAll('[data-demo]').forEach(host => {
      const name = host.dataset.demo;
      const demo = demos[name];
      if (!demo?.steps?.length || demo.steps.some(step => !demo.phases.includes(step.phase))) throw new Error(`Invalid walkthrough: ${name}`);
      if (states.has(name)) throw new Error(`Duplicate walkthrough host: ${name}`);
      states.set(name, 0);
      const sidebar = element('aside', 'demo-sidebar');
      const phases = element('ol', 'demo-phases');
      phases.setAttribute('aria-label', `${demo.label} phases`);
      demo.phases.forEach(phase => phases.append(element('li', '', phase)));
      const state = element('div', 'demo-state');
      state.append(element('strong'));
      sidebar.append(element('div', 'demo-label', demo.label), phases, state, element('p', 'demo-insight'));
      const main = element('div', 'demo-main');
      const header = element('div', 'demo-header');
      header.append(element('h3'), element('output', 'demo-count'));
      const controls = element('div', 'demo-controls');
      controls.setAttribute('role', 'group');
      controls.setAttribute('aria-label', `${demo.label} controls`);
      for (const [action, label] of [['back', 'Back'], ['next', 'Next step'], ['reset', 'Reset']]) {
        const button = element('button', '', label);
        button.type = 'button';
        button.dataset.action = action;
        button.addEventListener('click', () => performStep(host, action));
        controls.append(button);
      }
      main.append(header, element('div', 'demo-body'), controls);
      host.replaceChildren(sidebar, main);
      renderDemo(host);
    });

    const deck = new Reveal({
      width: 1600, height: 900, margin: .015, center: false, controls: false,
      progress: false, hash: true, history: true, keyboard: false, overview: false,
      transition: 'none', backgroundTransition: 'none', autoSlide: 0, loop: false, help: false
    });
    function updateSlide() {
      const current = deck.getCurrentSlide();
      const index = sections.indexOf(current);
      const focused = document.activeElement;
      sections.forEach(section => { section.inert = section !== current; });
      document.title = `${current.dataset.title} | ${config.title}`;
      required('#slide-count').textContent = `${index + 1} / ${sections.length}`;
      required('#chapter-label').textContent = current.dataset.chapter;
      previous.disabled = index === 0;
      next.disabled = index === sections.length - 1;
      if ((focused === previous && previous.disabled) || (focused === next && next.disabled)) {
        (previous.disabled ? next.disabled ? overview : next : previous).focus();
      } else if (focused instanceof Element && focused.closest('section[inert]')) overview.focus();
      announce(`Slide ${index + 1} of ${sections.length}. ${current.dataset.title}`);
    }
    function sourceList(ids) {
      const list = element('ol', 'source-list');
      ids.forEach(id => {
        const source = sources[id];
        const link = element('a', '', source.title);
        link.href = source.url;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        const item = element('li');
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
      const title = required('#dialog-title');
      if (kind === 'sources') {
        title.textContent = `Sources / ${current.dataset.title}`;
        const ids = sourceIds(current);
        dialogContent.append(element('p', '', config.sourceNote));
        dialogContent.append(ids.length ? sourceList(ids) : element('p', '', 'No sources assigned to this slide.'));
      } else if (kind === 'notes') {
        title.textContent = `Notes / ${current.dataset.title}`;
        dialogContent.append(element('p', '', current.querySelector('.notes')?.textContent || 'No presenter notes for this slide.'));
        dialogContent.append(element('p', 'source-note', 'Recipients can read all bundled notes.'));
      } else if (kind === 'overview') {
        title.textContent = 'Slide index';
        const list = element('div', 'slide-index');
        sections.forEach((section, index) => {
          const button = element('button', '', `${index + 1}. ${section.dataset.title}`);
          button.type = 'button';
          if (section === current) button.setAttribute('aria-current', 'page');
          button.addEventListener('click', () => { dialog.close(); deck.slide(index); });
          list.append(button);
        });
        dialogContent.append(list);
      } else if (kind === 'help') {
        title.textContent = 'Presentation keys';
        const grid = element('div', 'key-grid');
        for (const [key, description] of [
          ['Left / Right', 'Previous / next slide. Page Up / Page Down also work.'],
          ['Space', 'Next slide; Shift+Space goes back.'],
          ['Home / End', 'First / last slide.'],
          ['[ / ] / R', 'Back / next / reset the current walkthrough.'],
          ['O / S / N', 'Slide index / sources / notes.'],
          ['? / F', 'This help / full screen.'],
          ['Escape', 'Close an overlay and return focus.'],
          ['Tab / Enter', 'Reach and activate controls; focused controls keep their normal keys.']
        ]) grid.append(element('kbd', '', key), element('span', '', description));
        dialogContent.append(grid, element('p', 'source-note', 'Walkthroughs keep their step on slide revisits. Reload preserves the slide hash but resets walkthroughs. Motion is optional and respects reduced motion.'));
      } else throw new Error(`Unknown dialog: ${kind}`);
      if (!dialog.open) dialog.showModal();
      dialogContent.scrollTop = 0;
      closeDialog.focus();
    }
    dialog.addEventListener('close', () => {
      const active = document.activeElement;
      // Native focus restoration can precede the queued close event.
      if (active instanceof HTMLElement && active !== document.body && active !== document.documentElement
        && !dialog.contains(active) && !active.closest('[inert]')) return;
      if (returnFocus?.isConnected && !returnFocus.disabled && !returnFocus.closest('[inert]')) returnFocus.focus();
      else overview.focus();
    });
    dialog.addEventListener('keydown', event => {
      if (event.key !== 'Tab') return;
      const nodes = [...dialog.querySelectorAll('button, a[href], summary, input, select, textarea, [tabindex]:not([tabindex="-1"])')]
        .filter(node => !node.disabled && node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden');
      const first = nodes[0];
      const last = nodes.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    });
    closeDialog.addEventListener('click', () => dialog.close());
    document.querySelectorAll('[data-dialog]').forEach(button => button.addEventListener('click', () => showDialog(button.dataset.dialog, button)));
    overview.addEventListener('click', () => showDialog('overview', overview));
    previous.addEventListener('click', () => { if (ready) deck.prev(); });
    next.addEventListener('click', () => { if (ready) deck.next(); });
    async function fullscreen() {
      try {
        if (document.fullscreenElement) await document.exitFullscreen();
        else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
        else throw new Error('Use the browser full-screen command.');
      } catch (error) {
        showDialog('help');
        dialogContent.prepend(element('p', 'source-note', `Full screen is unavailable: ${error.message}`));
      }
    }
    required('#fullscreen-button').addEventListener('click', fullscreen);
    document.addEventListener('keydown', event => {
      if (!ready || dialog.open || event.altKey || event.ctrlKey || event.metaKey) return;
      if (event.target instanceof Element && event.target.closest('button, a, input, textarea, select, summary, [contenteditable]')) return;
      if (globalThis.getSelection()?.toString()) return;
      const key = event.key.toLowerCase();
      const demo = deck.getCurrentSlide().querySelector('[data-demo]');
      if (!['arrowright', 'pagedown', ' ', 'arrowleft', 'pageup', 'home', 'end', 'o', 's', 'n', '?', 'f'].includes(key)
        && !(demo && ['[', ']', 'r'].includes(key))) return;
      event.preventDefault();
      if (['arrowright', 'pagedown', ' '].includes(key)) event.shiftKey && key === ' ' ? deck.prev() : deck.next();
      else if (['arrowleft', 'pageup'].includes(key)) deck.prev();
      else if (key === 'home') deck.slide(0);
      else if (key === 'end') deck.slide(sections.length - 1);
      else if (key === 'f') void fullscreen();
      else if (['o', 's', 'n', '?'].includes(key)) showDialog({ o: 'overview', s: 'sources', n: 'notes', '?': 'help' }[key]);
      else performStep(demo, { '[': 'back', ']': 'next', r: 'reset' }[key]);
    });
    function updateMotion() {
      const enabled = motionEnabled && !reducedMotion.matches;
      deck.configure({ transition: enabled ? 'fade' : 'none' });
      motionButton.disabled = reducedMotion.matches;
      motionButton.setAttribute('aria-pressed', String(enabled));
      motionButton.textContent = enabled ? 'Motion on' : 'Motion off';
      motionButton.title = reducedMotion.matches ? 'Reduced-motion preference is active.' : 'Toggle optional slide fades.';
    }
    motionButton.addEventListener('click', () => { motionEnabled = !motionEnabled; updateMotion(); });
    reducedMotion.addEventListener('change', updateMotion);
    deck.on('slidechanged', updateSlide);
    await deck.initialize();
    ready = true;
    updateMotion();
    updateSlide();
    startup.hidden = true;
    document.documentElement.dataset.deckReady = 'true';
  } catch (error) {
    showError(error);
  }
}());
