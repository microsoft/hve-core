// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, h, icon } from './dom.mjs';
import { marginNote, md, row, rowActions, sectionBody } from './components.mjs';
import { notesFor } from './view-research.mjs';

/** Follow-up view: summary, ranked follow-ups, and loop lineage. */

const STATUS = {
    proposed: { icon: 'circle', label: 'Proposed', tone: 'muted' },
    selected: { icon: 'check', label: 'Selected', tone: 'accent' },
    skipped: { icon: 'dash-circle', label: 'Skipped', tone: 'muted' },
    'in-progress': { icon: 'active', label: 'Child loop running', tone: 'accent' },
};
const LINEAGE = { completed: { icon: 'check-circle', label: 'Completed', tone: 'success' }, running: { icon: 'active', label: 'Running', tone: 'accent' }, stopped: { icon: 'pause', label: 'Stopped', tone: 'muted' } };

export function outline(ctx) {
    return [
        { id: 'followup-summary', label: 'Summary' },
        { id: 'followups', label: 'Ranked follow-ups', count: ctx.data.session.followUps.items.length },
        { id: 'lineage', label: 'Loop lineage' },
    ];
}

function lineage(ctx) {
    const items = ctx.data.session.followUps.lineage;
    return h('ol', { class: 'lineage', 'aria-label': 'Loop lineage, parent first' }, items.map((item, index) => h('li', { class: ['lineage-step', item.relation === 'this' ? 'is-this' : null] },
        index > 0 ? icon('arrow-right', { className: 'lineage-arrow' }) : null,
        h('span', { class: 'lineage-card' },
            h('span', { class: 'meta', text: item.relation === 'this' ? 'This task' : item.relation === 'child' ? 'Child loop' : 'Parent task' }),
            h('strong', { text: item.title }),
            h('code', { class: 'lineage-id', text: item.id }),
            badge(LINEAGE[item.status] ?? { icon: 'info', label: item.status, tone: 'muted' })))));
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
                    h('p', { class: 'followup-head' }, h('strong', { text: item.title }), badge(item.required ? { icon: 'flag', label: 'Required', tone: 'attention' } : { icon: 'info', label: 'Optional', tone: 'muted' }), badge(STATUS[item.status])),
                    h('p', { text: item.rationale }),
                    h('div', { class: 'meta followup-evidence' }, h('span', { class: 'followup-evidence-label', text: 'Evidence' }), md(ctx, item.evidence)),
                    item.status === 'proposed' ? h('div', { class: 'btn-row' },
                        button('Select as next loop', { iconName: 'check', onClick: () => ctx.act.requestTask(item.id, `Select ${item.id} (${item.title}) as the next child loop.`) }),
                        button('Skip', { iconName: 'dash-circle', onClick: () => ctx.act.requestTask(item.id, `Skip ${item.id} (${item.title}).`) })) : null))))],
        margin: notesFor(ctx, followUps.items.map((item) => item.id)).map((item) => marginNote(ctx, item)),
    }));
    rows.push(row(ctx, { id: 'lineage', idLabel: null, title: 'Loop lineage', level: 2, body: [lineage(ctx)] }));
    return rows;
}
