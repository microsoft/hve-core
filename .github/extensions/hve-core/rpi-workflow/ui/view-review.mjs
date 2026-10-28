// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, h, icon, idChip, known, SEVERITY, timeEl, VALIDATION } from './dom.mjs';
import { decisionCard, marginNote, md, mdInline, recordRow, row, rowActions, sectionBody, table, traceStrip } from './components.mjs';
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
const PARTICIPATION = {
    'agent-owned': 'The agent makes Review decisions in this session; you can question any of them.',
    'user-retained': 'You keep Review decisions in this session.',
    'user-owned': 'Review decisions are yours in this session.',
};

export function outline(ctx) {
    const review = ctx.data.session.review;
    return [
        { id: 'review-summary', label: 'Assessment' },
        ...review.findings.map((finding) => ({ id: finding.id, label: finding.title, prefix: finding.id, meta: SEVERITY[finding.severity] })),
        { id: 'history', label: 'Decision history', count: review.history.length },
        { id: 'review-validation', label: 'Validation evidence', count: review.validation.length },
        ctx.data.session.records?.review?.length ? { id: 'review-record', label: 'Review record', count: ctx.data.session.records.review.length } : null,
    ].filter(Boolean);
}

export function renderView(ctx) {
    const { review } = ctx.data.session;
    const participation = PARTICIPATION[ctx.data.session.session.participation?.review];
    const rows = [];
    const counts = ['critical', 'high', 'medium', 'low'].map((severity) => [severity, review.findings.filter((finding) => finding.severity === severity).length]).filter(([, count]) => count);
    rows.push(row(ctx, {
        id: 'review-summary', idLabel: null, title: 'Assessment', level: 2,
        badges: [review.execution ? badge({ icon: review.execution === 'Complete' ? 'check-circle' : 'active', label: `Execution: ${review.execution}`, tone: review.execution === 'Complete' ? 'success' : 'accent' }) : null, review.outcome ? badge({ icon: review.outcome === 'Defects found' ? 'alert' : 'check', label: review.outcome, tone: review.outcome === 'Defects found' ? 'severe' : 'success' }) : null],
        actions: rowActions(ctx, { sectionId: 'review-summary', rowId: 'review-summary' }),
        body: [sectionBody(ctx, 'review-summary')],
        margin: [h('article', { class: 'card' },
            h('header', { class: 'card-head' }, icon('eye', { className: 'card-icon' }), h('h4', { class: 'card-title', text: 'Findings by severity' })),
            counts.length ? h('ul', { class: 'severity-list' }, counts.map(([severity, count]) => h('li', null, badge(SEVERITY[severity], { strong: true }), h('span', { class: 'count-text', text: String(count) })))) : h('p', { class: 'meta', text: 'No findings.' }),
            review.depth || participation ? h('p', { class: 'meta', text: [review.depth ? `Depth: ${review.depth}.` : null, participation].filter(Boolean).join(' ') }) : null)],
    }));

    for (const finding of review.findings) {
        const event = [...review.history].reverse().find((item) => item.subject === finding.id);
        rows.push(row(ctx, {
            id: finding.id, title: finding.title,
            badges: [badge(known(SEVERITY, finding.severity), { strong: true }), finding.route ? chip(`Route: ${ROUTE[finding.route] ?? finding.route}`, 'muted') : null],
            actions: rowActions(ctx, { rowId: finding.id, ask: true }),
            body: [
                finding.summary ? h('p', null, mdInline(ctx, finding.summary, { doc: 'review' })) : null,
                finding.expected || finding.observed ? h('div', { class: 'compare' },
                    h('div', { class: 'compare-col' }, h('h4', null, icon('check'), 'Expected'), h('p', null, mdInline(ctx, finding.expected, { doc: 'review' }))),
                    h('div', { class: 'compare-col is-observed' }, h('h4', null, icon('eye'), 'Observed'), h('div', { class: 'prose' }, md(ctx, finding.observed)))) : null,
                finding.impact || finding.resolution ? h('dl', { class: 'facts' }, finding.impact ? [h('dt', { text: 'Impact' }), h('dd', null, mdInline(ctx, finding.impact, { doc: 'review' }))] : null, finding.resolution ? [h('dt', { text: 'Resolved when' }), h('dd', null, mdInline(ctx, finding.resolution, { doc: 'review' }))] : null) : null,
                finding.related.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Related' }), finding.related.map((id) => idChip(id, ctx.act.navigate))) : null,
                traceStrip(ctx, finding.id),
            ],
            margin: [
                h('article', { class: ['card', 'decision', 'is-decided'] },
                    h('header', { class: 'card-head' }, icon('sparkle', { className: 'card-icon tone-agent-fg' }), h('h4', { class: 'card-title', text: 'Agent decided' }), badge(known(FINDING_DECISION, finding.decision))),
                    findingOutcome(finding) ? h('p', null, h('strong', { text: findingOutcome(finding) })) : null,
                    event?.rationale ? h('p', null, mdInline(ctx, event.rationale, { doc: 'review' })) : null,
                    event ? h('p', { class: 'meta' }, h('span', { class: 'id-chip', text: event.id }), ' ', timeEl(event.at, ctx.now)) : null,
                    h('div', { class: 'btn-row' }, button('Question this decision', { iconName: 'message', onClick: () => ctx.act.anchorComposer(finding.id) }))),
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
            event.rationale ? h('p', { class: 'meta' }, event.owner ? `${event.owner}: ` : '', mdInline(ctx, event.rationale, { doc: 'review' })) : null)))],
    }));

    rows.push(row(ctx, {
        id: 'review-validation', idLabel: null, title: 'Validation evidence', level: 2,
        body: [table('Validation evidence', ['Check', 'Scope', 'Status', 'Result'], review.validation.map((check) => [h('code', { text: check.check }), check.scope ?? '', badge(known(VALIDATION, check.status)), mdInline(ctx, check.summary, { doc: 'review' })]))],
    }));

    const record = recordRow(ctx, 'review', 'Review record');
    if (record) rows.push(record);
    return rows;
}

/** What the agent decided about a finding, in words, or null when it recorded no decision. */
function findingOutcome(finding) {
    if (finding.decision === 'accepted') return ROUTE[finding.route] && finding.route !== 'none' ? `Fix it in ${ROUTE[finding.route]}` : 'Fix it';
    if (finding.decision === 'deferred') return 'Defer to a follow-up';
    return known(FINDING_DECISION, finding.decision)?.label ?? null;
}
