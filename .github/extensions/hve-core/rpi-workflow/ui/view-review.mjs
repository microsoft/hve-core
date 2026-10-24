// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, h, icon, idChip, SEVERITY, timeEl, VALIDATION } from './dom.mjs';
import { decisionCard, marginNote, md, row, rowActions, sectionBody, table, traceStrip } from './components.mjs';
import { anchoredDecisions, notesFor } from './view-research.mjs';

/** Review view: assessment, findings with expected and observed behavior, decision history, and validation. */

export const FINDING_DECISION = {
    proposed: { icon: 'question', label: 'Proposed', tone: 'muted' },
    accepted: { icon: 'check', label: 'Accepted', tone: 'success' },
    rejected: { icon: 'x', label: 'Rejected', tone: 'muted' },
    deferred: { icon: 'clock', label: 'Deferred', tone: 'attention' },
    resolved: { icon: 'check-circle', label: 'Resolved', tone: 'success' },
};
const ROUTE = { 'rpi-implement': 'Implement', 'rpi-plan': 'Plan', 'rpi-research': 'Research', 'follow-up': 'Follow-up', none: 'No route' };

export function outline(ctx) {
    const review = ctx.data.session.review;
    return [
        { id: 'review-summary', label: 'Assessment' },
        ...review.findings.map((finding) => ({ id: finding.id, label: finding.title, prefix: finding.id, meta: SEVERITY[finding.severity] })),
        { id: 'history', label: 'Decision history', count: review.history.length },
        { id: 'review-validation', label: 'Validation evidence', count: review.validation.length },
    ];
}

export function renderView(ctx) {
    const review = ctx.data.session.review;
    const rows = [];
    const counts = ['critical', 'high', 'medium', 'low'].map((severity) => [severity, review.findings.filter((finding) => finding.severity === severity).length]).filter(([, count]) => count);
    rows.push(row(ctx, {
        id: 'review-summary', idLabel: null, title: 'Assessment', level: 2,
        badges: [badge({ icon: 'check-circle', label: `Execution: ${review.execution}`, tone: 'success' }), badge({ icon: 'alert', label: review.outcome, tone: review.outcome === 'Defects found' ? 'severe' : 'success' })],
        actions: rowActions(ctx, { sectionId: 'review-summary', rowId: 'review-summary' }),
        body: [sectionBody(ctx, 'review-summary')],
        margin: [h('article', { class: 'card' },
            h('header', { class: 'card-head' }, icon('eye', { className: 'card-icon' }), h('h4', { class: 'card-title', text: 'Findings by severity' })),
            h('ul', { class: 'severity-list' }, counts.map(([severity, count]) => h('li', null, badge(SEVERITY[severity]), h('span', { class: 'count-text', text: String(count) })))),
            h('p', { class: 'meta', text: `Depth: ${review.depth}. Decisions are agent-owned in this session; you can question any of them.` }))],
    }));

    for (const finding of review.findings) {
        const event = [...review.history].reverse().find((item) => item.subject === finding.id);
        rows.push(row(ctx, {
            id: finding.id, title: finding.title,
            badges: [badge(SEVERITY[finding.severity]), chip(`Route: ${ROUTE[finding.route] ?? finding.route}`, 'muted')],
            actions: rowActions(ctx, { rowId: finding.id, ask: true }),
            body: [
                h('p', { text: finding.summary }),
                h('div', { class: 'compare' },
                    h('div', { class: 'compare-col' }, h('h4', null, icon('check'), 'Expected'), h('p', { text: finding.expected })),
                    h('div', { class: 'compare-col is-observed' }, h('h4', null, icon('eye'), 'Observed'), h('div', { class: 'prose' }, md(ctx, finding.observed)))),
                h('dl', { class: 'facts' }, h('dt', { text: 'Impact' }), h('dd', { text: finding.impact }), h('dt', { text: 'Resolved when' }), h('dd', { text: finding.resolution })),
                finding.related.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Related' }), finding.related.map((id) => idChip(id, ctx.act.navigate))) : null,
                traceStrip(ctx, finding.id),
            ],
            margin: [
                h('article', { class: ['card', 'decision', 'is-decided'] },
                    h('header', { class: 'card-head' }, icon('sparkle', { className: 'card-icon tone-agent-fg' }), h('h4', { class: 'card-title', text: 'Agent decided' }), badge(FINDING_DECISION[finding.decision])),
                    h('p', null, h('strong', { text: finding.decision === 'accepted' ? `Fix it in ${ROUTE[finding.route]}` : finding.decision === 'deferred' ? 'Defer to a follow-up' : FINDING_DECISION[finding.decision].label })),
                    event?.rationale ? h('p', { text: event.rationale }) : null,
                    event ? h('p', { class: 'meta' }, h('span', { class: 'id-chip', text: event.id }), ' ', timeEl(event.at, ctx.now)) : null,
                    h('div', { class: 'btn-row' }, button('Question this decision', { iconName: 'message', onClick: () => ctx.act.anchorComposer(finding.id, 'comment') }))),
                ...anchoredDecisions(ctx, [finding.id]).map((decision) => decisionCard(ctx, decision)),
                ...notesFor(ctx, [finding.id]).map((item) => marginNote(ctx, item)),
            ],
        }));
    }

    rows.push(row(ctx, {
        id: 'history', idLabel: null, title: 'Decision history', level: 2,
        body: [h('p', { class: 'meta', text: 'Append-only. The latest event for a subject is current.' }), h('ol', { class: 'timeline' }, review.history.map((event) => h('li', { class: 'timeline-item', dataset: { item: event.id }, tabindex: '-1' },
            h('span', { class: 'timeline-dot', 'aria-hidden': 'true' }),
            h('p', { class: 'timeline-head' }, h('span', { class: 'id-chip', text: event.id }), /^RV-\d{3}$/.test(event.subject) ? idChip(event.subject, ctx.act.navigate) : h('strong', { text: event.subject }), badge(FINDING_DECISION[event.status] ?? { icon: 'info', label: event.status, tone: 'muted' }), timeEl(event.at, ctx.now)),
            h('p', { class: 'meta', text: `${event.owner}: ${event.rationale}` }))))],
    }));

    rows.push(row(ctx, {
        id: 'review-validation', idLabel: null, title: 'Validation evidence', level: 2,
        body: [table('Validation evidence', ['Check', 'Scope', 'Status', 'Result'], review.validation.map((check) => [h('code', { text: check.check }), check.scope, badge(VALIDATION[check.status]), check.summary]))],
    }));
    return rows;
}
