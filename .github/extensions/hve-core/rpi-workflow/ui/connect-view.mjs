// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { button, h, icon } from './dom.mjs';
import { externalLink } from './markdown.mjs';

const REPOSITORY = 'https://github.com/microsoft/hve-core';
const CONTRIBUTING = `${REPOSITORY}/blob/main/CONTRIBUTING.md`;

/** Why the canvas shows no session, in words. */
const REASONS = Object.freeze({
    'no-input': 'The canvas opened without an RPI session to show.',
    'missing-session': 'The session this canvas showed before could not be found.',
});

/**
 * The details a bug report needs: the reason, the canvas, the host, and the time. They never
 * carry a path or session content, because people paste them in public.
 *
 * @param {{ reason?: string | null, handle?: string | null, editor?: string | null }} model
 * @param {string} at ISO time
 */
export function connectDetails(model, at) {
    return [
        'RPI Workflow canvas: Not connected to an RPI session',
        `Reason: ${model.reason || 'unknown'}`,
        `Canvas: ${model.handle || 'unknown'}`,
        `Host: ${model.editor || 'unknown'}`,
        `Time: ${at}`,
    ].join('\n');
}

/**
 * A bug report on microsoft/hve-core with its title and description filled in; GitHub's form
 * applies its own labels.
 *
 * @param {string} details
 */
export function bugReportUrl(details) {
    const query = new URLSearchParams({
        template: 'bug-report.yml',
        title: 'fix(rpi-workflow): canvas is not connected to an RPI session',
        description: `The RPI Workflow canvas showed "Not connected to an RPI session", and asking the agent did not connect it.\n\n${details}`,
    });
    return `${REPOSITORY}/issues/new?${query}`;
}

/**
 * The Not connected screen. It says what the canvas shows and that the chat agent connects it,
 * offers Ask the agent (when the host can take messages) and Copy request, puts the sample on
 * a button, and keeps help for when it keeps happening in a disclosure.
 *
 * @param {{
 *   reason: string, detail: string | null, request: string, canAsk: boolean,
 *   handle: string | null, editor: string | null, now: number,
 *   ui: { asking: boolean, askedAt: number, retryAfterMs: number, error: string | null, helpOpen: boolean },
 * }} model
 * @param {{ ask: () => void, copyRequest: () => void, copyDetails: (text: string) => void, showSample: () => void, toggleHelp: (open: boolean) => void }} act
 */
export function notConnectedView(model, act) {
    const asked = model.ui.askedAt > 0 && model.now - model.ui.askedAt < model.ui.retryAfterMs;
    const details = connectDetails(model, new Date(model.now).toISOString());
    const askLabel = asked ? 'Asked the agent' : model.ui.asking ? 'Asking the agent' : 'Ask the agent';
    // aria-disabled rather than disabled, so the button keeps keyboard focus while it waits.
    const waiting = model.ui.asking || asked;
    return h('section', { class: 'connect-card', 'aria-labelledby': 'connectTitle' },
        h('div', { class: 'connect-icon' }, icon('plug')),
        h('h2', { id: 'connectTitle', class: 'connect-title', text: 'Not connected to an RPI session' }),
        h('p', { class: 'connect-lead', text: 'This canvas shows the research, plan, implementation, and review of the RPI session your chat works on. The chat agent connects it when it opens the canvas, so you should rarely see this page.' }),
        h('div', { class: 'connect-step' },
            h('h3', { class: 'connect-step-title', text: 'Ask the agent to connect it' }),
            h('p', { class: 'connect-hint', text: model.canAsk ? 'Ask the agent sends this request to the chat. You can also copy it and paste it there yourself.' : 'Copy this request and paste it in the chat.' }),
            h('blockquote', { class: 'connect-request' }, h('p', { text: model.request })),
            h('div', { class: 'btn-row' },
                model.canAsk ? button(askLabel, { kind: 'primary', iconName: asked ? 'check' : 'send', onClick: () => { if (!waiting) act.ask(); }, title: 'Sends the request above to the chat, which starts an agent turn', attrs: { 'data-key': 'connect-ask', 'aria-disabled': waiting ? 'true' : undefined } }) : null,
                button('Copy request', { kind: model.canAsk ? 'neutral' : 'primary', iconName: 'copy', onClick: act.copyRequest, title: 'Copies the request to paste in the chat', attrs: { 'data-key': 'connect-copy' } })),
            model.ui.error ? h('p', { class: 'connect-error', role: 'alert' }, icon('alert'), h('span', { text: model.ui.error })) : null,
            h('p', { class: 'connect-note', text: asked ? 'The agent has the request. This page changes by itself once the canvas is connected.' : 'This page changes by itself once the canvas is connected.' })),
        h('div', { class: 'connect-sample' },
            h('p', { text: 'Want to look around first? The sample session shows what the canvas does, with made-up data.' }),
            button('Show the sample session', { iconName: 'eye', onClick: act.showSample, attrs: { 'data-key': 'connect-sample' } })),
        h('details', { class: 'connect-help', open: model.ui.helpOpen, ontoggle: (event) => act.toggleHelp(event.currentTarget.open) },
            h('summary', { dataset: { key: 'connect-help' } }, 'Still seeing this?'),
            h('div', { class: 'connect-help-body' },
                h('p', null, h('strong', { text: 'Why: ' }), REASONS[model.reason] ?? 'The canvas has no RPI session to show.', model.detail ? [' It looked for ', h('code', { class: 'connect-path', text: model.detail }), '.'] : null),
                h('ol', { class: 'connect-steps' },
                    h('li', { text: 'Check that the chat uses the RPI Agent or an rpi skill. They work with RPI sessions and connect the canvas.' }),
                    h('li', { text: "Ask the agent to connect the canvas, as above. It can also open the canvas again with the session's state file." }),
                    h('li', null, 'If it keeps happening, tell the hve-core maintainers: ', externalLink(bugReportUrl(details), 'report a bug'), ' with the details below, or ', externalLink(CONTRIBUTING, 'contribute a fix'), ' to microsoft/hve-core.')),
                h('pre', { class: 'connect-details', tabindex: '0', 'aria-label': 'Details for a bug report' }, h('code', { text: details })),
                h('div', { class: 'btn-row' },
                    button('Copy details', { iconName: 'copy', onClick: () => act.copyDetails(details), title: 'Copies the details above; they include no file paths', attrs: { 'data-key': 'connect-copy-details' } })))));
}
