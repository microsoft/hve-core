// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, h, known } from './dom.mjs';
import { marginNote, md, row, rowActions, sectionBody, sessionTree } from './components.mjs';
import { notesFor } from './view-research.mjs';

/** Follow-up view: summary, ranked follow-ups, and the session's loops. */

const STATUS = {
    proposed: { icon: 'circle', label: 'Proposed', tone: 'muted' },
    selected: { icon: 'check', label: 'Selected', tone: 'accent' },
    skipped: { icon: 'dash-circle', label: 'Skipped', tone: 'muted' },
    'in-progress': { icon: 'active', label: 'Child loop running', tone: 'accent' },
};

export function outline(ctx) {
    return [
        { id: 'followup-summary', label: 'Summary' },
        { id: 'followups', label: 'Ranked follow-ups', count: ctx.data.session.followUps.items.length },
        { id: 'session-loops', label: 'Loops in this session', count: ctx.data.session.followUps.tree.tasks.length },
    ];
}

function sessionLoops(ctx) {
    const { tree } = ctx.data.session.followUps;
    const name = tree.name ? `“${tree.name}”` : 'This session';
    return [
        h('p', { class: 'meta', text: `${name} holds every loop this conversation worked on, parent first.${tree.key ? ` Its state files are in ${tree.key}.` : ''}` }),
        sessionTree(ctx, { label: `Loops in ${tree.name ?? 'this session'}, parent first`, keyPrefix: 'followup' }),
    ];
}

export function renderView(ctx) {
    const { followUps } = ctx.data.session;
    const rows = [];
    rows.push(row(ctx, {
        id: 'followup-summary', idLabel: null, title: 'Summary', level: 2,
        actions: rowActions(ctx, { sectionId: 'followup-summary', rowId: 'followup-summary' }),
        body: [sectionBody(ctx, 'followup-summary')],
        margin: notesFor(ctx, ['followup-summary']).map((item) => marginNote(ctx, item)),
    }));
    rows.push(row(ctx, {
        id: 'followups', idLabel: null, title: 'Ranked follow-ups', level: 2,
        body: [h('p', { class: 'meta', text: 'Ranked by dependency and acceptance impact. Required items keep the session open; optional items never block completion.' }),
            h('ol', { class: 'followup-list' }, followUps.items.map((item) => h('li', { class: ['followup', item.required ? 'is-required' : null], dataset: { item: item.id }, tabindex: '-1' },
                h('span', { class: 'rank', 'aria-hidden': 'true', text: String(item.rank) }),
                h('div', { class: 'followup-body' },
                    h('p', { class: 'followup-head' }, h('strong', { text: item.title }), badge(item.required ? { icon: 'flag', label: 'Required', tone: 'attention' } : { icon: 'info', label: 'Optional', tone: 'muted' }), badge(known(STATUS, item.status))),
                    item.rationale ? h('p', { text: item.rationale }) : null,
                    item.evidence ? h('div', { class: 'meta followup-evidence' }, h('span', { class: 'followup-evidence-label', text: 'Evidence' }), md(ctx, item.evidence)) : null,
                    item.status === 'proposed' ? h('div', { class: 'btn-row' },
                        button('Select as next loop', { iconName: 'check', onClick: () => ctx.act.requestTask(item.id, `Select ${item.id} (${item.title}) as the next child loop.`) }),
                        button('Skip', { iconName: 'dash-circle', onClick: () => ctx.act.requestTask(item.id, `Skip ${item.id} (${item.title}).`) })) : null))))],
        margin: notesFor(ctx, followUps.items.map((item) => item.id)).map((item) => marginNote(ctx, item)),
    }));
    rows.push(row(ctx, { id: 'session-loops', idLabel: null, title: 'Loops in this session', level: 2, body: sessionLoops(ctx) }));
    return rows;
}
