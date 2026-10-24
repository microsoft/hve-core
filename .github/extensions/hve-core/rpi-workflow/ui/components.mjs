// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, DECISION_STATUS, FEEDBACK_KIND, FEEDBACK_STATE, h, icon, idChip, PHASE_META, sr, timeEl } from './dom.mjs';
import { editorUri, externalLink, renderMarkdown } from './markdown.mjs';

/** Shared components: rows with margins, editing, evidence, traces, and decision cards. */

/** Rows whose margins render decision cards, by phase. */
const DECISION_MARGIN_ROWS = Object.freeze({
    research: /^F\d{1,2}$/,
    plan: /^P\d{2}(?:-T\d{2})?$/,
    implement: /^DS-\d{3}$/,
    review: /^RV-\d{3}$/,
});

/** True when a decision margin row with this ID can render in a phase view that has started. */
export function rendersDecisionMargin(ctx, rowId) {
    if (typeof rowId !== 'string' || !ctx.find(rowId)) return false;
    return Object.entries(DECISION_MARGIN_ROWS).some(([phase, pattern]) => {
        const status = ctx.data.session.phases[phase]?.status;
        return pattern.test(rowId) && status !== 'upcoming' && status !== 'skipped';
    });
}

/** Decisions with no rendered margin are shown as full cards in the steering panel instead. */
export const hasMarginHome = (ctx, decision) => rendersDecisionMargin(ctx, decision?.anchor?.rowId);

/** Native disclosure whose open state survives re-renders. */
export function disclosure(ctx, key, className, summary, ...content) {
    return h('details', { class: className, open: ctx.ui.openDetails.has(key), ontoggle: (event) => ctx.act.setDetailsOpen(key, event.target.open) }, h('summary', { text: summary, dataset: { key: `summary-${key}` } }), content);
}

/** Markdown with navigable IDs. */
export const md = (ctx, text) => renderMarkdown(text ?? '', { resolveId: (id) => Boolean(ctx.resolve(id)), navigate: ctx.act.navigate });

/**
 * A document row: header, text column, and a margin for that row's annotations.
 *
 * @param {any} ctx
 * @param {{ id: string, idLabel?: string, title: string, badges?: any[], actions?: any[], body: any[], margin?: any[], className?: string, level?: number }} spec
 */
export function row(ctx, spec) {
    const titleId = `row-${spec.id}-title`;
    const margin = (spec.margin ?? []).filter(Boolean);
    const section = h('section', {
        class: ['row', margin.length ? 'has-margin' : null, spec.className, ctx.ui.highlight === spec.id ? 'is-highlight' : null],
        id: `row-${spec.id}`,
        dataset: { row: spec.id },
        tabindex: '-1',
        'aria-labelledby': titleId,
    },
    h('div', { class: 'row-main' },
        h('header', { class: 'row-head' },
            spec.idLabel === null ? null : h('span', { class: 'id-chip', text: spec.idLabel ?? spec.id }),
            h('h3', { class: ['row-title', spec.level === 2 ? 'is-major' : null], id: titleId, text: spec.title }),
            (spec.badges ?? []).length ? h('span', { class: 'row-badges' }, spec.badges) : null,
            (spec.actions ?? []).length ? h('span', { class: 'row-actions' }, spec.actions) : null),
        h('div', { class: 'row-text' }, spec.body)),
    margin.length ? h('aside', { class: 'row-margin', 'aria-label': `Notes for ${spec.idLabel ?? spec.id}` }, margin) : null);
    return section;
}

/** Always-visible row actions: Edit section, Comment, and optional Research this. */
export function rowActions(ctx, { sectionId, rowId, research = false, ask = false }) {
    const items = [];
    if (sectionId && ctx.data.session.sections[sectionId]) {
        items.push(button('Edit section', { iconName: 'pencil', hideLabel: true, onClick: () => ctx.act.startEdit(sectionId), attrs: { 'aria-keyshortcuts': ctx.ui.shortcuts ? 'e' : undefined, 'data-key': `edit-section-${rowId}` } }));
    }
    items.push(button('Comment', { iconName: 'message', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'comment'), attrs: { 'aria-keyshortcuts': ctx.ui.shortcuts ? 'c' : undefined, 'data-key': `comment-${rowId}` } }));
    if (research) {
        items.push(button('Research this', { iconName: 'search', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'research-request') }));
    }
    if (ask) {
        items.push(button('Ask the agent', { iconName: 'sparkle', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'comment') }));
    }
    return items;
}

/** Section Markdown, or the editor when this section is being edited. */
export function sectionBody(ctx, sectionId) {
    const section = ctx.data.session.sections[sectionId];
    if (!section) {
        return h('p', { class: 'empty', text: 'Not recorded' });
    }
    if (ctx.ui.editing?.sectionId === sectionId) {
        return editor(ctx, section);
    }
    const body = h('div', { class: 'prose' }, md(ctx, section.markdown));
    if (section.editedBy === 'user') {
        const event = [...ctx.data.session.feedback].reverse().find((item) => item.kind === 'edit' && item.target?.id === sectionId);
        body.append(h('p', { class: 'edited-note' }, icon('person'), 'Edited by you', event ? [' ', badge(FEEDBACK_STATE[event.state])] : null));
    }
    return body;
}

function editor(ctx, section) {
    const state = ctx.ui.editing;
    const textareaId = `edit-${section.id}`;
    const showPreview = state.mode === 'preview';
    const tabs = h('div', { class: 'edit-tabs', role: 'tablist', 'aria-label': `Edit ${section.title}` },
        ['write', 'preview'].map((mode) => h('button', {
            type: 'button', role: 'tab', class: 'edit-tab', 'aria-selected': String(state.mode === mode), tabindex: state.mode === mode ? '0' : '-1',
            onclick: () => ctx.act.setEditMode(mode),
            onkeydown: (event) => {
                if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
                    ctx.act.setEditMode(mode === 'write' ? 'preview' : 'write');
                }
            },
        }, mode === 'write' ? 'Write' : 'Preview')));
    const area = h('textarea', { id: textareaId, class: 'edit-area', rows: String(Math.min(18, Math.max(6, state.draft.split('\n').length + 2))), spellcheck: 'true', oninput: (event) => ctx.act.setDraft(event.target.value) });
    area.value = state.draft;
    const conflict = state.conflict
        ? h('div', { class: 'notice tone-attention', role: 'alert', tabindex: '-1', id: `conflict-${section.id}` },
            h('p', { class: 'notice-title' }, icon('alert'), 'The agent changed this section while you were editing.'),
            state.compare ? h('div', { class: 'compare' },
                h('div', null, h('h4', { text: "The agent's version" }), h('div', { class: 'prose' }, md(ctx, state.conflict.markdown))),
                h('div', null, h('h4', { text: 'Your version' }), h('div', { class: 'prose' }, md(ctx, state.draft)))) : null,
            h('div', { class: 'btn-row' },
                button(state.compare ? 'Hide comparison' : 'Compare', { onClick: () => ctx.act.toggleCompare() }),
                button('Keep my version', { kind: 'primary', onClick: () => ctx.act.keepMine() }),
                button("Use the agent's version", { onClick: () => ctx.act.useTheirs() })))
        : null;
    return h('div', { class: 'editor' },
        conflict,
        tabs,
        showPreview ? h('div', { class: 'prose preview-pane', role: 'tabpanel', 'aria-label': 'Preview' }, md(ctx, state.draft)) : h('div', { role: 'tabpanel', 'aria-label': 'Write' }, h('label', { class: 'visually-hidden', for: textareaId, text: `${section.title} in Markdown` }), area),
        state.confirmDiscard
            ? h('div', { class: 'notice tone-attention discard-confirm', role: 'group', 'aria-labelledby': `discard-${section.id}` },
                h('p', { class: 'notice-title', id: `discard-${section.id}` }, icon('alert'), 'Discard your unsaved changes?'),
                h('div', { class: 'btn-row' },
                    button('Keep editing', { kind: 'primary', attrs: { 'data-key': 'keep-editing' }, onClick: () => ctx.act.keepEditing() }),
                    button('Discard changes', { attrs: { 'data-key': 'discard-changes' }, onClick: () => ctx.act.cancelEdit() })))
            : h('div', { class: 'btn-row' },
                button(state.saving ? 'Saving' : 'Save', { kind: 'primary', iconName: 'check', disabled: state.saving, attrs: { 'data-key': 'save-edit' }, onClick: () => ctx.act.saveEdit() }),
                button('Cancel', { attrs: { 'data-key': 'cancel-edit' }, onClick: () => ctx.act.requestCancelEdit() }),
                h('span', { class: 'meta', text: `Editing revision ${state.baseRevision}. Saving tells the agent.` })));
}

/** Evidence chips with an expandable detail list directly below them. */
export function evidenceChips(ctx, rowKey, ids) {
    if (!ids?.length) {
        return null;
    }
    const regionId = `ev-${rowKey}`;
    const open = ids.filter((id) => ctx.ui.openEvidence.has(`${rowKey}:${id}`));
    const chips = h('div', { class: 'evidence-chips' }, h('span', { class: 'meta', text: 'Evidence' }),
        ids.map((id) => {
            const item = ctx.find(id);
            const expanded = ctx.ui.openEvidence.has(`${rowKey}:${id}`);
            return h('button', {
                type: 'button', class: ['id-chip', 'is-link', 'evidence-chip', expanded ? 'is-open' : null], 'aria-expanded': String(expanded), 'aria-controls': regionId,
                title: item?.claim ?? id, onclick: () => ctx.act.toggleEvidence(rowKey, id),
            }, icon(item?.kind === 'web' ? 'external' : 'file', { className: 'icon-inline' }), id);
        }));
    const details = h('div', { class: 'evidence-details', id: regionId, hidden: open.length === 0 },
        open.map((id) => {
            const item = ctx.find(id);
            if (!item) return h('p', { class: 'meta', text: `${id}: Not recorded` });
            return h('div', { class: 'evidence-detail' },
                h('p', null, h('span', { class: 'id-chip', text: id }), ' ', item.claim),
                h('p', { class: 'meta' },
                    item.url ? externalLink(item.url, item.source) : h('code', { text: item.source }),
                    ` · Confidence ${item.confidence}`, item.retrieved ? ` · Retrieved ${item.retrieved}` : ''));
        }));
    return h('div', { class: 'evidence' }, chips, details);
}

/** Linear trace: question to finding to decision to task to change to review finding. */
export function traceStrip(ctx, id) {
    const chain = (ctx.data.view.traces[id] ?? []).filter((step) => ctx.find(step));
    if (chain.length < 2) {
        return null;
    }
    return h('nav', { class: 'trace', 'aria-label': `Trace for ${id}` },
        h('span', { class: 'trace-label' }, icon('nodes'), 'Trace'),
        h('ol', null, chain.map((step, index) => h('li', null,
            index > 0 ? icon('chevron', { className: 'trace-sep' }) : null,
            step === id ? h('span', { class: 'id-chip is-current', 'aria-current': 'location', text: step }) : idChip(step, ctx.act.navigate)))));
}

/** One voice in the read-back exchange. */
export function voice(kind, label, children, options = {}) {
    return h('div', { class: ['voice', `voice-${kind}`, options.reveal ? 'is-reveal' : null] },
        h('p', { class: 'voice-label' }, icon(kind === 'agent' ? 'sparkle' : 'person'), label, options.meta ? h('span', { class: 'meta', text: ` · ${options.meta}` }) : null, options.reveal ? h('span', { class: 'badge tone-accent new-badge', text: 'New' }) : null),
        h('div', { class: 'voice-body' }, children));
}

function optionList(ctx, decision, name, selected, onChange, exclude) {
    return h('fieldset', { class: 'options' },
        h('legend', { class: 'visually-hidden', text: decision.question || decision.title }),
        decision.options.filter((option) => option.id !== exclude).map((option) => {
            const id = `${name}-${option.id}`;
            const input = h('input', { type: 'radio', name, id, value: option.id, checked: selected === option.id, onchange: () => onChange(option.id) });
            return h('label', { class: ['option', selected === option.id ? 'is-selected' : null], for: id },
                input,
                h('span', { class: 'option-body' },
                    h('span', { class: 'option-label' }, option.label, option.recommended ? h('span', { class: 'badge tone-accent rec-tag' }, icon('sparkle'), 'Recommended') : null),
                    option.consequence ? h('span', { class: 'option-consequence', text: option.consequence }) : null,
                    option.recommended && option.why ? h('span', { class: 'option-why', text: `Why: ${option.why}` }) : null));
        }));
}

/**
 * Decision card for every status: needs input, answered with read-back, agent decided
 * with override, and resolved.
 *
 * @param {any} ctx
 * @param {any} decision
 */
export function decisionCard(ctx, decision) {
    const session = ctx.data.session;
    const feedback = decision.feedbackId ? session.feedback.find((item) => item.id === decision.feedbackId) : null;
    const meta = DECISION_STATUS[decision.status];
    const chosen = decision.options.find((option) => option.id === decision.chosen);
    const draft = ctx.ui.decisionDrafts.get(decision.id) ?? { optionId: decision.options.find((o) => o.recommended)?.id ?? null, note: '' };
    const head = h('header', { class: 'card-head' },
        icon('signpost', { className: 'card-icon' }),
        h('span', { class: 'id-chip', text: decision.id }),
        h('h4', { class: 'card-title', text: decision.title }),
        badge(meta));
    const owner = h('p', { class: 'card-owner meta' }, decision.owner === 'user' ? 'Your decision' : "The agent's decision", ` · ${PHASE_META[decision.phase]?.label ?? decision.phase}`);
    const parts = [head, owner];
    const evidence = evidenceChips(ctx, `dec-${decision.id}`, decision.evidence);

    if (decision.status === 'needs-input') {
        const name = `decision-${decision.id}`;
        const noteId = `${name}-note`;
        parts.push(
            h('p', { class: 'card-question', text: decision.question }),
            decision.context ? h('div', { class: 'card-context prose' }, md(ctx, decision.context)) : null,
            optionList(ctx, decision, name, draft.optionId, (optionId) => ctx.act.setDecisionDraft(decision.id, { ...draft, optionId })),
            evidence,
            decision.impact ? h('p', { class: 'card-impact' }, icon('arrow-right'), h('span', null, h('strong', { text: 'If you answer: ' }), decision.impact)) : null,
            h('label', { class: 'field-label', for: noteId, text: 'Add a note (optional)' }),
            h('textarea', { id: noteId, class: 'note', rows: '2', oninput: (event) => ctx.act.setDecisionDraft(decision.id, { ...draft, note: event.target.value }) }, draft.note),
            h('div', { class: 'btn-row' },
                button('Answer', { kind: 'primary', iconName: 'check', disabled: !draft.optionId, onClick: () => ctx.act.answer(decision.id, 'answer', draft) }),
                h('span', { class: 'meta' }, deliveryHint(ctx))));
    } else if (decision.status === 'decided' || decision.status === 'override-pending') {
        const overriding = ctx.ui.overrides.has(decision.id);
        parts.push(voice('agent', 'Agent decided', [h('p', null, h('strong', { text: chosen?.label ?? 'Not recorded' })), decision.rationale ? h('p', { text: decision.rationale }) : null]), evidence);
        if (decision.status === 'override-pending' && feedback) {
            parts.push(readBack(ctx, decision, feedback, 'Your override'));
        } else if (overriding) {
            const name = `override-${decision.id}`;
            parts.push(
                h('p', { class: 'card-question', text: 'Choose a different option:' }),
                optionList(ctx, decision, name, draft.optionId === decision.chosen ? null : draft.optionId, (optionId) => ctx.act.setDecisionDraft(decision.id, { ...draft, optionId }), decision.chosen),
                h('label', { class: 'field-label', for: `${name}-note`, text: 'Why (optional)' }),
                h('textarea', { id: `${name}-note`, class: 'note', rows: '2', oninput: (event) => ctx.act.setDecisionDraft(decision.id, { ...draft, note: event.target.value }) }, draft.note),
                h('div', { class: 'btn-row' },
                    button('Send override', { kind: 'primary', disabled: !draft.optionId || draft.optionId === decision.chosen, onClick: () => ctx.act.answer(decision.id, 'override', draft) }),
                    button('Cancel', { onClick: () => ctx.act.toggleOverride(decision.id) })));
        } else {
            parts.push(h('div', { class: 'btn-row' }, button('Override', { iconName: 'undo', onClick: () => ctx.act.toggleOverride(decision.id) })));
        }
    } else if (decision.status === 'answered' && feedback) {
        parts.push(readBack(ctx, decision, feedback, 'You'));
    } else {
        const history = feedback ? readBack(ctx, decision, feedback, 'You', { compact: true }) : null;
        parts.push(h('p', { class: 'resolved-line' }, icon('check', { className: 'tone-success-fg' }), h('span', null, 'Resolved: ', h('strong', { text: chosen?.label ?? 'Not recorded' }), decision.impact ? ` · ${decision.impact}` : '')),
            history ? disclosure(ctx, `history-${decision.id}`, 'history', 'How this was decided', history) : null);
    }
    return withLabel(h('article', { class: ['card', 'decision', `is-${decision.status}`], id: `card-${decision.id}`, dataset: { item: decision.id }, tabindex: '-1' }, parts), decision);
}

function withLabel(article, decision) {
    const title = article.querySelector('.card-title');
    if (title) {
        title.id = `card-${decision.id}-t`;
        article.setAttribute('aria-labelledby', title.id);
    }
    return article;
}

/** The two-voice read-back for a decision's answer or override. */
export function readBack(ctx, decision, feedback, youLabel, options = {}) {
    const origin = feedback.kind === 'correction' ? ctx.data.session.feedback.find((item) => item.id === feedback.correctionOf) : null;
    const chosen = decision.options.find((option) => option.id === (feedback.optionId ?? origin?.optionId));
    const fresh = ctx.ui.revealed.has(feedback.id);
    const parts = [];
    if (origin && !options.compact) {
        parts.push(disclosure(ctx, `exchange-${origin.id}`, 'history', 'Earlier exchange', readBack(ctx, decision, origin, origin.kind === 'override' ? 'Your override' : 'You', { compact: true })));
    }
    parts.push(origin
        ? voice('user', 'Your correction', [chosen ? h('p', null, 'For ', h('strong', { text: chosen.label })) : null, h('p', { text: `“${feedback.text}”` })], { meta: FEEDBACK_STATE[feedback.state]?.label })
        : voice('user', youLabel, [h('p', null, h('strong', { text: chosen?.label ?? feedback.optionLabel ?? '' })), feedback.text ? h('p', { text: `“${feedback.text}”` }) : null], { meta: FEEDBACK_STATE[feedback.state]?.label }));
    if (feedback.interpretation) {
        parts.push(voice('agent', 'Agent understood', [h('p', { text: feedback.interpretation.text }), feedback.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), feedback.interpretation.effect) : null], { reveal: fresh }));
    } else if (!options.compact && (feedback.state === 'queued' || feedback.state === 'sent')) {
        parts.push(h('p', { class: 'waiting meta' }, icon(feedback.state === 'queued' ? 'inbox' : 'send'), feedback.state === 'queued' ? 'Queued for the agent. It reads feedback at its next checkpoint.' : 'Sent. The agent will read back how it understood this.'));
        if (feedback.state === 'queued') {
            const overriding = (origin ?? feedback).kind === 'override';
            parts.push(h('div', { class: 'btn-row' }, button(overriding ? 'Edit override' : 'Edit answer', { iconName: 'pencil', onClick: () => ctx.act.editAnswer(decision.id, feedback, origin) })));
        }
    }
    if (!options.compact && feedback.state === 'interpreted') {
        parts.push(readBackActions(ctx, feedback, 'card'));
    }
    return h('div', { class: 'readback' }, parts);
}

/** Where an answer goes, in words. */
export function deliveryHint(ctx) {
    const mode = ctx.ui.deliveryMode;
    return mode === 'queue' ? 'Queued for the agent' : mode === 'attach' ? 'Queued; attach it to your next message from Steer' : 'Queued; send it from Steer';
}

/** A comment or other feedback shown in a row margin. */
export function marginNote(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    return h('article', { class: ['card', 'note-card'], dataset: { item: item.id } },
        h('header', { class: 'card-head' }, icon(kind.icon, { className: 'card-icon' }), h('span', { class: 'id-chip', text: item.id }), h('h4', { class: 'card-title', text: kind.label }), badge(FEEDBACK_STATE[item.state])),
        voice('user', 'You', h('p', { text: item.text }), { meta: null }),
        item.interpretation ? voice('agent', 'Agent understood', [h('p', { text: item.interpretation.text }), item.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), item.interpretation.effect) : null], { reveal: ctx.ui.revealed.has(item.id) }) : null,
        item.state === 'interpreted' ? readBackActions(ctx, item, 'card') : null,
        h('p', { class: 'meta' }, timeEl(item.createdAt, ctx.now)));
}

/**
 * Looks right and Not what I meant, or the prefilled correction field when it is open here.
 *
 * @param {any} ctx
 * @param {any} item interpreted feedback item
 * @param {'card' | 'row'} where the decision card or margin note, or the steering feedback row
 */
function readBackActions(ctx, item, where) {
    const open = ctx.ui.corrections.get(item.id);
    if (open && open.where === where) {
        const fieldId = `${where === 'row' ? 'steer-correct' : 'correct'}-${item.id}`;
        return h('div', { class: 'correction' },
            h('label', { class: 'field-label', for: fieldId, text: 'What did you mean?' }),
            h('textarea', { id: fieldId, class: 'note', rows: '3', oninput: (event) => ctx.act.setCorrection(item.id, event.target.value) }, open.text),
            h('div', { class: 'btn-row' },
                button('Send correction', { kind: 'primary', iconName: 'send', attrs: { 'data-key': `send-correction-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'corrected', { correction: ctx.ui.corrections.get(item.id)?.text ?? '' }) }),
                button('Cancel', { attrs: { 'data-key': `cancel-correction-${item.id}` }, onClick: () => ctx.act.toggleCorrection(item.id, null) })));
    }
    return h('div', { class: 'btn-row' },
        button('Looks right', { kind: 'primary', iconName: 'check', attrs: { 'data-key': `looks-right-${where}-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'applied') }),
        button('Not what I meant', { iconName: 'undo', attrs: { 'data-key': `not-meant-${where}-${item.id}` }, onClick: () => ctx.act.toggleCorrection(item.id, item.text ?? '', where) }));
}

/** Simple accessible table inside a scrollable well. */
export function table(caption, headers, rows) {
    return h('div', { class: 'table-well', tabindex: '0', role: 'region', 'aria-label': `${caption} table` },
        h('table', { class: 'data-table' },
            h('caption', { class: 'visually-hidden', text: caption }),
            h('thead', null, h('tr', null, headers.map((header) => h('th', { scope: 'col', text: header })))),
            h('tbody', null, rows.map((cells) => h('tr', null, cells.map((cell) => h('td', null, cell)))))));
}

const DELIVERY_MODES = [
    { id: 'queue', short: 'Queue', label: 'Queue for the agent', hint: 'The agent collects it at its next checkpoint.' },
    { id: 'attach', short: 'Attach', label: 'Attach to my next message', hint: 'Adds a pill to your chat box; you decide when to send.' },
    { id: 'send', short: 'Send now', label: 'Send now', hint: 'Starts an agent turn, or waits behind the current one.' },
];

/** Matches the model's claim window: a delivery holds queued items for up to 10 minutes. */
const isSending = (ctx, item) => item.state === 'queued' && Boolean(item.deliveringSince) && ctx.now - Date.parse(item.deliveringSince) < 10 * 60 * 1000;
const SENDING = Object.freeze({ icon: 'send', label: 'Sending', tone: 'accent' });

function feedbackRow(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    const target = item.target ? h('span', null, ' about ', ctx.resolve(item.target.id) ? idChip(item.target.id, ctx.act.navigate) : h('span', { class: 'id-chip', text: item.target.id })) : null;
    const actions = [];
    const sending = isSending(ctx, item);
    const dismiss = !sending && (item.state === 'queued' || item.state === 'draft')
        ? button(`Dismiss ${item.id}`, { iconName: 'x', hideLabel: true, attrs: { 'data-key': `dismiss-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'dismissed') })
        : null;
    let readBack = null;
    if (item.state === 'interpreted') {
        if (item.target?.type === 'decision') {
            actions.push(button('Looks right', { iconName: 'check', kind: 'primary', attrs: { 'data-key': `looks-right-row-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'applied') }),
                button('Not what I meant', { iconName: 'undo', attrs: { 'data-key': `not-meant-row-${item.id}` }, onClick: () => ctx.act.openDecisionCorrection(item) }));
        } else {
            readBack = readBackActions(ctx, item, 'row');
        }
    }
    return h('li', { class: 'fb-item', dataset: { item: item.id } },
        h('div', { class: 'fb-head' }, icon(kind.icon), h('span', { class: 'fb-kind' }, kind.label, target), badge(sending ? SENDING : FEEDBACK_STATE[item.state]), dismiss),
        item.optionLabel ? h('p', { class: 'fb-text' }, h('strong', { text: item.optionLabel })) : null,
        item.text ? h('p', { class: 'fb-text', text: item.text.length > 160 ? `${item.text.slice(0, 159)}…` : item.text }) : null,
        item.interpretation ? h('p', { class: 'fb-interp' }, icon('sparkle'), h('span', { text: item.interpretation.text })) : null,
        h('p', { class: 'fb-meta meta' }, h('span', { class: 'id-chip', text: item.id }), ' ', timeEl(item.updatedAt ?? item.createdAt, ctx.now), item.delivery && item.state !== 'queued' ? ` · via ${item.delivery === 'queue' ? 'queue' : item.delivery === 'attach' ? 'attachment' : 'message'}` : ''),
        actions.length ? h('div', { class: 'btn-row' }, actions) : null,
        readBack);
}

function steerSection(id, title, count, content, options = {}) {
    return h('section', { class: ['steer-section', options.className], 'aria-labelledby': `steer-${id}` },
        h('h3', { class: 'steer-title', id: `steer-${id}` }, options.iconName ? icon(options.iconName) : null, title, count !== null ? h('span', { class: 'count', text: String(count) }) : null),
        content);
}

/**
 * The steering panel: needs your input, decided by the agent, your feedback with
 * delivery, add input, and the phase checklist, always in that order.
 *
 * @param {any} ctx
 */
export function steerPanel(ctx) {
    const { session, view } = ctx.data;
    const phaseLabel = (phase) => PHASE_META[phase]?.label ?? phase;
    const waiting = view.interpretations.map((id) => session.feedback.find((item) => item.id === id)).filter(Boolean);
    const decisionOf = (id) => session.decisions.find((decision) => decision.id === id);
    const steerCard = (decision) => h('li', { class: 'steer-card' }, decisionCard(ctx, decision));
    const needs = h('ul', { class: 'steer-list' },
        view.needsYou.map((item) => (hasMarginHome(ctx, decisionOf(item.id)) ? h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `needs-${item.id}` }, onclick: () => ctx.act.navigate(item.id) },
                icon('hand', { className: 'tone-attention-fg' }), h('span', { class: 'steer-link-text' }, h('span', { class: 'id-chip', text: item.id }), ' ', item.title), h('span', { class: 'meta', text: phaseLabel(item.phase) }))) : steerCard(decisionOf(item.id)))),
        waiting.map((item) => h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `check-${item.id}` }, onclick: () => ctx.act.navigate(item.target?.type === 'decision' ? item.target.id : item.id) },
                icon('sparkle', { className: 'tone-agent-fg' }), h('span', { class: 'steer-link-text' }, 'Check how the agent read ', h('span', { class: 'id-chip', text: item.id })), h('span', { class: 'meta', text: phaseLabel(item.target?.phase) })))));
    const needsCount = view.needsYou.length + waiting.length;
    const decided = h('ul', { class: 'steer-list' },
        view.decidedByAgent.map((item) => (hasMarginHome(ctx, decisionOf(item.id)) ? h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `decided-${item.id}` }, onclick: () => ctx.act.navigate(item.id) },
                icon('sparkle', { className: 'tone-agent-fg' }), h('span', { class: 'steer-link-text' }, h('span', { class: 'id-chip', text: item.id }), ' ', item.title), h('span', { class: 'meta', text: phaseLabel(item.phase) }))) : steerCard(decisionOf(item.id)))));

    const queued = session.feedback.filter((item) => item.state === 'queued' && !isSending(ctx, item));
    const inFlight = session.feedback.filter((item) => item.state === 'sent' || item.state === 'interpreted' || isSending(ctx, item));
    const earlier = session.feedback.filter((item) => ['applied', 'corrected', 'dismissed'].includes(item.state));
    const modeName = 'delivery-mode';
    const preview = ctx.ui.deliveryPreview;
    const selectedMode = DELIVERY_MODES.find((mode) => mode.id === ctx.ui.deliveryMode) ?? DELIVERY_MODES[0];
    const deliveryControls = h('div', { class: 'delivery' },
        h('fieldset', { class: 'segmented compact delivery-modes' }, h('legend', { text: 'Deliver feedback by' }),
            DELIVERY_MODES.map((mode) => h('label', { for: `${modeName}-${mode.id}`, title: mode.label },
                h('input', { type: 'radio', name: modeName, id: `${modeName}-${mode.id}`, value: mode.id, checked: ctx.ui.deliveryMode === mode.id, 'aria-describedby': 'delivery-mode-hint', onchange: () => ctx.act.setDeliveryMode(mode.id) }),
                h('span', { text: mode.short })))),
        h('p', { class: 'mode-hint', id: 'delivery-mode-hint' }, h('strong', { text: `${selectedMode.label}. ` }), selectedMode.hint),
        ctx.ui.deliveryMode !== 'queue' && queued.length
            ? h('div', { class: 'delivery-preview' },
                preview && preview.ids.join() === queued.map((item) => item.id).join()
                    ? [h('p', { class: 'meta', text: 'Exactly this text will be sent:' }), h('pre', { class: 'preview-text', tabindex: '0', text: preview.prompt }),
                        h('div', { class: 'btn-row' }, button(`Deliver ${queued.length === 1 ? '1 item' : `${queued.length} items`}`, { kind: 'primary', iconName: ctx.ui.deliveryMode === 'send' ? 'send' : 'anchor', disabled: ctx.ui.delivering, attrs: { 'data-key': 'deliver' }, onClick: () => ctx.act.deliver(queued.map((item) => item.id)) }))]
                    : button('Preview what will be sent', { iconName: 'eye', attrs: { 'data-key': 'preview-delivery' }, onClick: () => ctx.act.preview(queued.map((item) => item.id)) }),
                h('p', { class: 'meta', text: 'Nothing is sent until you choose Deliver.' }))
            : null);
    const feedback = h('div', null,
        queued.length ? [h('h4', { class: 'group-title', text: `Queued (${queued.length})` }), h('ul', { class: 'fb-list' }, queued.map((item) => feedbackRow(ctx, item)))] : h('p', { class: 'empty', text: 'Nothing queued. Answers, comments, and edits you make appear here before the agent reads them.' }),
        deliveryControls,
        inFlight.length ? [h('h4', { class: 'group-title', text: `With the agent (${inFlight.length})` }), h('ul', { class: 'fb-list' }, inFlight.map((item) => feedbackRow(ctx, item)))] : null,
        earlier.length ? disclosure(ctx, 'earlier-feedback', 'earlier', `Earlier feedback (${earlier.length})`, h('ul', { class: 'fb-list' }, earlier.slice().reverse().map((item) => feedbackRow(ctx, item)))) : null);

    return [
        steerSection('needs', 'Needs your input', needsCount, needsCount ? needs : h('p', { class: 'empty', text: 'Nothing needs you right now. Decisions the agent asks you about appear here.' }), { iconName: 'hand', className: needsCount ? 'has-items' : null }),
        steerSection('decided', 'Decided by the agent', view.decidedByAgent.length, view.decidedByAgent.length ? decided : h('p', { class: 'empty', text: 'No agent decisions yet.' }), { iconName: 'sparkle' }),
        steerSection('feedback', 'Your feedback', queued.length + inFlight.length, feedback, { iconName: 'inbox' }),
        steerSection('add', 'Add input', null, composer(ctx), { iconName: 'plus' }),
        steerSection('checklist', ctx.ui.phase === 'review' ? 'Review checklist' : `${PHASE_META[ctx.ui.phase]?.label ?? ''} review checklist`, null, checklist(ctx), { iconName: 'checklist' }),
    ];
}

const COMPOSER_KINDS = [
    { id: 'comment', label: 'Comment' },
    { id: 'context', label: 'Context' },
    { id: 'research-request', label: 'Research request' },
];

function composer(ctx) {
    const state = ctx.ui.composer;
    const textId = 'composer-text';
    const anchor = state.anchor ? ctx.find(state.anchor) : null;
    const placeholder = state.kind === 'research-request' ? 'What should the agent research? A research subagent lane starts when the agent takes this.' : state.kind === 'context' ? 'Facts, links, or constraints the agent should know.' : 'Your comment for the agent.';
    return h('form', { class: 'composer', onsubmit: (event) => {
        event.preventDefault();
        ctx.act.submitComposer();
    } },
    h('fieldset', { class: 'segmented compact' }, h('legend', { class: 'visually-hidden', text: 'Kind of input' }),
        COMPOSER_KINDS.map((kind) => h('label', { for: `composer-kind-${kind.id}` },
            h('input', { type: 'radio', name: 'composer-kind', id: `composer-kind-${kind.id}`, value: kind.id, checked: state.kind === kind.id, onchange: () => ctx.act.setComposer({ kind: kind.id }) }),
            h('span', { text: kind.label })))),
    state.anchor
        ? h('p', { class: 'anchor-chip' }, icon('anchor'), 'About ', h('span', { class: 'id-chip', text: state.anchor }), anchor?.title ? h('span', { class: 'anchor-title', text: ` ${anchor.title}` }) : null,
            button('Remove anchor', { iconName: 'x', hideLabel: true, attrs: { 'data-key': 'remove-anchor' }, onClick: () => ctx.act.setComposer({ anchor: null }) }))
        : h('p', { class: 'meta', text: 'Tip: use Comment or Research this on a row to anchor your input to it.' }),
    h('label', { class: 'visually-hidden', for: textId, text: 'Your input' }),
    h('textarea', { id: textId, class: 'note', rows: '3', placeholder, oninput: (event) => ctx.act.setComposer({ text: event.target.value }, false) }, state.text),
    h('div', { class: 'btn-row' }, h('button', { type: 'submit', class: 'btn btn-primary', disabled: !state.text.trim(), dataset: { key: 'composer-submit' } }, icon('plus'), h('span', { text: state.kind === 'research-request' ? 'Request research' : 'Add to feedback' }))));
}

function checklist(ctx) {
    const phase = ctx.ui.phase;
    const items = ctx.data.session.checklists[phase] ?? [];
    if (!items.length) {
        return h('p', { class: 'empty', text: 'A checklist appears when this phase has content to review.' });
    }
    const done = items.filter((item) => item.checked).length;
    return h('div', { class: 'checklist' },
        h('p', { class: 'meta', text: `${done} of ${items.length} reviewed. Optional; share it when it helps the agent.` }),
        h('ul', null, items.map((item) => {
            const id = `check-${phase}-${item.id}`;
            return h('li', null, h('label', { class: 'check', for: id }, h('input', { type: 'checkbox', id, checked: item.checked, onchange: (event) => ctx.act.toggleChecklist(phase, item.id, event.target.checked) }), h('span', { text: item.label })));
        })),
        h('div', { class: 'btn-row' }, button('Share review with the agent', { iconName: 'send', attrs: { 'data-key': 'share-checklist' }, onClick: () => ctx.act.shareChecklist(phase) })));
}

/**
 * File preview sheet content with a symbol-marked diff and file actions.
 *
 * @param {any} ctx
 * @param {any} change
 * @param {any} file
 */
export function filePreview(ctx, change, file) {
    const lines = (file.diff || '').split('\n').filter((line, index, all) => line !== '' || index < all.length - 1);
    const kindTone = { added: 'success', modified: 'accent', deleted: 'danger', renamed: 'muted' }[file.kind] ?? 'muted';
    const diff = lines.length
        ? h('div', { class: 'diff', role: 'region', tabindex: '0', 'aria-label': `Changes in ${file.path}` },
            lines.map((line) => {
                const type = line.startsWith('@@') ? 'hunk' : line.startsWith('+') ? 'add' : line.startsWith('-') ? 'del' : 'ctx';
                const marker = type === 'add' ? '+' : type === 'del' ? '−' : type === 'hunk' ? '' : ' ';
                return h('div', { class: ['diff-line', `is-${type}`] },
                    type === 'add' ? sr('Added: ') : type === 'del' ? sr('Removed: ') : null,
                    h('span', { class: 'diff-marker', 'aria-hidden': 'true', text: marker }),
                    h('span', { class: 'diff-code', text: type === 'hunk' ? line : line.slice(1) }));
            }))
        : h('p', { class: 'empty', text: 'No diff was recorded for this file. The changes record lists it with its line counts.' });
    const editorLink = editorUri(file.path);
    return [
        h('div', { class: 'dialog-head' },
            h('h2', { id: 'fileSheetTitle', class: 'sheet-title' }, icon('file'), h('code', { text: file.path })),
            h('button', { type: 'button', class: 'icon-btn', 'data-close': '' }, icon('x'), sr('Close'))),
        h('p', { class: 'sheet-meta' }, h('span', { class: ['badge', `tone-${kindTone}`], text: file.kind }), ` +${file.additions} −${file.deletions} · `, h('span', { class: 'id-chip', text: change.id }), ` ${change.title} · `, h('span', { class: 'id-chip', text: change.taskId })),
        diff,
        h('div', { class: 'btn-row' },
            button('Copy path', { iconName: 'copy', onClick: () => ctx.act.copy(file.path) }),
            button('Ask the agent about this change', { iconName: 'message', onClick: () => ctx.act.anchorComposer(change.id, 'comment', true) }),
            editorLink ? h('a', { class: 'btn', href: editorLink }, icon('external'), h('span', { text: 'Open in editor' })) : h('span', { class: 'meta', text: 'Open in editor appears for files in your workspace once the canvas reads real changes.' })),
    ];
}
