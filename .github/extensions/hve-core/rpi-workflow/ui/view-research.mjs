// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, confidenceMeta, EVIDENCE_STATE, h, icon, idChip, PRIORITY, riskTypeMeta, timeEl } from './dom.mjs';
import { decisionCard, decisionsRow, DECISION_ROWS, evidenceChips, marginNote, md, mdInline, notesFor, recordSections, row, rowActions, sectionBody, table, traceStrip } from './components.mjs';
import { evidenceSource } from './source-view.mjs';

/** Research view: summary, unknowns, questions, findings with decision margins, alternatives, risks, and the record. */

export const anchoredDecisions = (ctx, rowIds) => ctx.data.session.decisions.filter((decision) => decision.anchor && rowIds.includes(decision.anchor.rowId));

/** Outline entry for a phase's Decisions row, when it has decisions. */
export function decisionsOutline(ctx, phase) {
    const count = anchoredDecisions(ctx, [DECISION_ROWS[phase]]).length;
    return count ? [{ id: DECISION_ROWS[phase], label: 'Decisions', count }] : [];
}

const researchNotes = (ctx, rowIds) => notesFor(ctx, rowIds).filter((item) => !(item.kind === 'research-request' && ['queued', 'sent'].includes(item.state)));

const LANE_STATUS = {
    queued: { icon: 'inbox', label: 'Queued', tone: 'accent' },
    running: { icon: 'active', label: 'Running', tone: 'accent' },
    done: { icon: 'check-circle', label: 'Done', tone: 'success' },
    cancelled: { icon: 'x', label: 'Cancelled', tone: 'muted' },
};

const DISPOSITION = {
    selected: { icon: 'check-circle', label: 'Selected', tone: 'success' },
    rejected: { icon: 'x-circle', label: 'Rejected', tone: 'muted' },
    deferred: { icon: 'clock', label: 'Deferred', tone: 'attention' },
    viable: { icon: 'circle', label: 'Viable', tone: 'muted' },
};

/** Research lanes, including research you requested that the agent has not started. */
export function lanesCard(ctx, filter) {
    const { session } = ctx.data;
    if (ctx.readOnly) return null;
    const lanes = session.research.lanes.filter((lane) => !filter || lane.findingId === filter);
    const startedFrom = new Set(lanes.map((lane) => lane.origin).filter(Boolean));
    const requested = session.feedback.filter((item) => item.kind === 'research-request' && ['queued', 'sent'].includes(item.state) && !startedFrom.has(item.id) && (!filter || item.target?.id === filter));
    if (filter && !lanes.length && !requested.length) {
        return null;
    }
    return h('article', { class: ['card', 'lanes-card'] },
        h('header', { class: 'card-head' }, icon('search', { className: 'card-icon' }), h('h4', { class: 'card-title', text: filter ? 'Research on this finding' : 'Research lanes' }), chip(String(lanes.length + requested.length))),
        h('ul', { class: 'lane-list' },
            lanes.map((lane) => h('li', { class: 'lane', dataset: { item: lane.id } },
                h('p', { class: 'lane-head' }, badge(LANE_STATUS[lane.status]), h('span', { class: 'id-chip', text: lane.id }), lane.origin ? h('span', { class: 'meta' }, ' from ', idChip(lane.origin, null)) : null),
                h('p', { class: 'lane-question', text: lane.question }),
                lane.summary ? h('p', { class: 'lane-summary' }, icon('sparkle'), h('span', { text: lane.summary })) : null,
                h('p', { class: 'meta' }, [lane.effort ? `Effort ${lane.effort}` : null, timeEl(lane.updatedAt, ctx.now)].filter(Boolean).flatMap((part, index) => (index ? [' · ', part] : [part]))))),
            requested.map((item) => h('li', { class: 'lane is-requested', dataset: { item: item.id } },
                h('p', { class: 'lane-head' }, badge({ icon: 'person', label: item.state === 'queued' ? 'Requested by you · queued' : 'Requested by you · sent', tone: 'user' }), h('span', { class: 'id-chip', text: item.id })),
                h('p', { class: 'lane-question', text: item.text })))),
        filter ? null : h('div', { class: 'btn-row' }, button('Request more research', { iconName: 'plus', onClick: () => ctx.act.anchorComposer(null, 'research-request') })));
}

export function outline(ctx) {
    const { research, sections } = ctx.data.session;
    return [
        { id: 'research-summary', label: 'Summary' },
        sections['research-unknowns'] ? { id: 'research-unknowns', label: 'What you may not know' } : null,
        { id: 'questions', label: 'Questions', count: research.questions.length },
        ...research.findings.map((finding) => ({ id: finding.id, label: finding.title, prefix: finding.id, meta: EVIDENCE_STATE[finding.state] })),
        { id: 'research-recommendation', label: 'Recommendation and alternatives' },
        ...decisionsOutline(ctx, 'research'),
        { id: 'risks', label: 'Risks and open questions' },
        { id: 'record', label: 'Research record' },
    ].filter(Boolean);
}

export function renderView(ctx) {
    const { session } = ctx.data;
    const research = session.research;
    const readiness = research.readiness;
    const readinessBadge = readiness ? badge(readiness.status === 'ready' ? { icon: 'check-circle', label: 'Ready for planning', tone: 'success' } : { icon: 'hand', label: 'Not ready', tone: 'attention' }) : null;
    const rows = [];

    rows.push(row(ctx, {
        id: 'research-summary', idLabel: null, title: 'Summary', level: 2, badges: [readinessBadge],
        actions: rowActions(ctx, { sectionId: 'research-summary', rowId: 'research-summary', research: true }),
        body: [sectionBody(ctx, 'research-summary'), readiness ? h('p', { class: 'readiness-line' }, icon(readiness.status === 'ready' ? 'check' : 'hand'), h('span', null, mdInline(ctx, readiness.text, { doc: 'research' }))) : null],
        margin: [lanesCard(ctx), ...researchNotes(ctx, ['research-summary']).map((item) => marginNote(ctx, item))],
    }));

    if (session.sections['research-unknowns']) {
        rows.push(row(ctx, {
            id: 'research-unknowns', idLabel: null, title: 'What you may not know', level: 2,
            actions: rowActions(ctx, { sectionId: 'research-unknowns', rowId: 'research-unknowns' }),
            body: [h('div', { class: 'callout' }, icon('bulb', { className: 'callout-icon' }), sectionBody(ctx, 'research-unknowns'))],
            margin: researchNotes(ctx, ['research-unknowns']).map((item) => marginNote(ctx, item)),
        }));
    }

    rows.push(row(ctx, {
        id: 'questions', idLabel: null, title: 'Questions', level: 2, badges: [chip(`${research.questions.filter((q) => q.status === 'answered').length} of ${research.questions.length} answered`, 'muted')],
        body: [h('ol', { class: 'question-list' }, research.questions.map((question) => h('li', { class: 'question', dataset: { item: question.id }, tabindex: '-1' },
            h('span', { class: 'id-chip', text: question.id }),
            h('span', { class: 'question-text' }, mdInline(ctx, question.text, { doc: 'research' })),
            badge(question.status === 'answered' ? { icon: 'check', label: 'Answered', tone: 'success' } : question.status === 'blocked' ? { icon: 'alert', label: 'Blocked', tone: 'danger' } : { icon: 'hand', label: 'Open', tone: 'attention' }),
            h('span', { class: 'question-links' }, question.findings.map((id) => idChip(id, ctx.act.navigate))))))],
    }));

    for (const finding of research.findings) {
        const sectionId = `finding-${finding.id.toLowerCase()}`;
        rows.push(row(ctx, {
            id: finding.id, title: finding.title,
            badges: [badge(EVIDENCE_STATE[finding.state]), finding.confidence ? badge(confidenceMeta(finding.confidence), { prefix: 'Confidence', strong: true }) : null],
            actions: rowActions(ctx, { sectionId, rowId: finding.id, research: true }),
            body: [sectionBody(ctx, sectionId), h('p', { class: 'meta answers' }, 'Answers ', finding.questions.map((id) => idChip(id, ctx.act.navigate))), evidenceChips(ctx, finding.id, finding.evidence), traceStrip(ctx, finding.id)],
            margin: [...anchoredDecisions(ctx, [finding.id]).map((decision) => decisionCard(ctx, decision)), lanesCard(ctx, finding.id), ...researchNotes(ctx, [finding.id]).map((item) => marginNote(ctx, item))],
        }));
    }

    rows.push(row(ctx, {
        id: 'research-recommendation', idLabel: null, title: 'Recommendation and alternatives', level: 2,
        actions: rowActions(ctx, { sectionId: 'research-recommendation', rowId: 'research-recommendation' }),
        body: [sectionBody(ctx, 'research-recommendation'), table('Alternatives', ['Option', 'Benefits', 'Costs and risks', 'Evidence', 'Disposition'], research.alternatives.map((alt) => [
            h('strong', { text: alt.option }), mdInline(ctx, alt.benefits, { doc: 'research' }), mdInline(ctx, alt.costs, { doc: 'research' }), h('span', { class: 'chip-row' }, alt.evidence.map((id) => idChip(id, ctx.act.navigate))), badge(DISPOSITION[alt.disposition]),
        ]))],
        margin: researchNotes(ctx, ['research-recommendation']).map((item) => marginNote(ctx, item)),
    }));

    const decisions = decisionsRow(ctx, 'research');
    if (decisions) rows.push(decisions);

    rows.push(row(ctx, {
        id: 'risks', idLabel: null, title: 'Risks and open questions', level: 2,
        body: [table('Risks and open questions', ['Priority', 'Type', 'Item', 'Impact', 'Next action', 'Owner'], research.risks.map((risk) => [
            badge(PRIORITY[risk.priority] ?? PRIORITY.M, { strong: true }),
            badge(riskTypeMeta(risk.type), { strong: true }),
            h('span', { dataset: { item: risk.id } }, mdInline(ctx, risk.text, { doc: 'research' })),
            mdInline(ctx, risk.impact, { doc: 'research' }),
            mdInline(ctx, risk.action, { doc: 'research' }),
            risk.owner,
        ]), { className: 'risk-table' })],
    }));

    const record = h('details', { class: 'record', open: ctx.ui.recordOpen, ontoggle: (event) => ctx.act.setRecordOpen(event.target.open) },
        h('summary', null, `Evidence log (${research.evidence.length})`),
        table('Evidence log', ['ID', 'Claim', 'Source', 'Confidence'], research.evidence.map((item) => [
            h('span', { class: 'id-chip', dataset: { item: item.id }, tabindex: '-1', text: item.id }),
            mdInline(ctx, item.claim, { doc: 'research' }),
            evidenceSource(ctx, item),
            badge(confidenceMeta(item.confidence), { strong: true }),
        ]), { className: 'evidence-log' }));
    rows.push(row(ctx, { id: 'record', idLabel: null, title: 'Research record', level: 2, body: [h('p', { class: 'meta', text: 'Method, evidence, and sources behind the findings. Evidence chips open their row here.' }), record, ...recordSections(ctx, 'research')] }));
    return rows;
}

/** Re-exported so other views can render Markdown and margin notes. */
export { md, notesFor };
