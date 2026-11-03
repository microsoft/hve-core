// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { elements, installFakeDom } from './helpers/fake-dom.mjs';

let restore;
let view;
before(async () => {
    restore = installFakeDom();
    view = await import('../ui/connect-view.mjs');
});
after(() => restore());

const REQUEST = "RPI canvas 3WF0: connect this canvas to this conversation's RPI session.";
const MISSING = '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-state.json';
const NOW = Date.parse('2026-10-27T15:00:00.000Z');
const idle = { asking: false, askedAt: 0, retryAfterMs: 30000, error: null, helpOpen: false };

function render(model = {}, calls = []) {
    const act = {
        ask: () => calls.push('ask'),
        copyRequest: () => calls.push('copy-request'),
        copyDetails: (text) => calls.push(['copy-details', text]),
        showSample: () => calls.push('sample'),
        toggleHelp: (open) => calls.push(['help', open]),
    };
    return view.notConnectedView({ reason: 'no-input', detail: null, request: REQUEST, canAsk: true, handle: '3WF0', editor: 'Visual Studio Code - Insiders', now: NOW, ui: idle, ...model }, act);
}

const byKey = (root, key) => elements(root).find((el) => el.getAttribute('data-key') === key) ?? null;
const textOf = (root) => root.textContent.replace(/\s+/g, ' ');

describe('Not connected screen', () => {
    it('says what the canvas shows, that the agent connects it, and shows the request', () => {
        const root = render();
        assert.equal(root.querySelector('h2').textContent, 'Not connected to an RPI session');
        assert.match(textOf(root), /The chat agent connects it when it opens the canvas/);
        assert.equal(root.querySelector('blockquote').textContent, REQUEST);
        assert.equal(root.querySelector('h3').textContent, 'Ask the agent to connect it');
    });

    it('offers Ask the agent, Copy request, and the sample, each doing its one thing', () => {
        const calls = [];
        const root = render({}, calls);
        for (const key of ['connect-ask', 'connect-copy', 'connect-sample']) byKey(root, key).listeners.click[0]();
        assert.deepEqual(calls, ['ask', 'copy-request', 'sample']);
        assert.match(byKey(root, 'connect-ask').getAttribute('title'), /starts an agent turn/);
    });

    it('offers Copy request alone where the host cannot take messages', () => {
        const root = render({ canAsk: false });
        assert.equal(byKey(root, 'connect-ask'), null);
        assert.match(textOf(root), /Copy this request and paste it in the chat/);
        assert.ok(byKey(root, 'connect-copy').classList.contains('btn-primary'));
    });

    it('confirms an ask, keeps the button off until the interval passes, and shows a failure', () => {
        const asked = render({ ui: { ...idle, askedAt: NOW - 1000 } });
        assert.equal(byKey(asked, 'connect-ask').textContent, 'Asked the agent');
        assert.equal(byKey(asked, 'connect-ask').getAttribute('aria-disabled'), 'true');
        assert.equal(byKey(asked, 'connect-ask').hasAttribute('disabled'), false);
        const later = render({ ui: { ...idle, askedAt: NOW - 31000 } });
        assert.equal(byKey(later, 'connect-ask').hasAttribute('aria-disabled'), false);
        const failed = render({ ui: { ...idle, error: 'The request was not sent.' } });
        assert.equal(failed.querySelector('.connect-error').getAttribute('role'), 'alert');
    });

    it('explains the reason and shows a missing path only on screen', () => {
        const calls = [];
        const root = render({ reason: 'missing-session', detail: MISSING }, calls);
        assert.match(textOf(root), /could not be found/);
        assert.equal(root.querySelector('.connect-path').textContent, MISSING);
        const details = root.querySelector('.connect-details').textContent;
        assert.doesNotMatch(details, /copilot-tracking/, 'copied details carry no path');
        assert.match(details, /Reason: missing-session\nCanvas: 3WF0\nHost: Visual Studio Code - Insiders\nTime: 2026-10-27T15:00:00.000Z/);
        byKey(root, 'connect-copy-details').listeners.click[0]();
        assert.deepEqual(calls, [['copy-details', details]]);
    });

    it('links to a prefilled bug report and the contributing guide without paths', () => {
        const links = render({ reason: 'missing-session', detail: MISSING }).querySelectorAll('a');
        assert.deepEqual(links.map((a) => a.textContent.replace(' (opens in a new tab)', '')), ['report a bug', 'contribute a fix']);
        const report = new URL(links[0].getAttribute('href'));
        assert.equal(`${report.origin}${report.pathname}`, 'https://github.com/microsoft/hve-core/issues/new');
        assert.equal(report.searchParams.get('template'), 'bug-report.yml');
        assert.equal(report.searchParams.get('title'), 'fix(rpi-workflow): canvas is not connected to an RPI session');
        assert.match(report.searchParams.get('description'), /Canvas: 3WF0/);
        assert.doesNotMatch(links[0].getAttribute('href'), /copilot-tracking/);
        assert.equal(links[1].getAttribute('href'), 'https://github.com/microsoft/hve-core/blob/main/CONTRIBUTING.md');
        assert.equal(links[0].getAttribute('rel'), 'noopener noreferrer');
    });

    it('keeps the help open across renders and reports when it opens', () => {
        const calls = [];
        const root = render({ ui: { ...idle, helpOpen: true } }, calls);
        const help = root.querySelector('details');
        assert.equal(help.hasAttribute('open'), true);
        help.listeners.toggle[0]({ currentTarget: { open: false } });
        assert.deepEqual(calls, [['help', false]]);
        assert.equal(render().querySelector('details').hasAttribute('open'), false);
    });
});
