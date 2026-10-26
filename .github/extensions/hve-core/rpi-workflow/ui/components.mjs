// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, DECISION_STATUS, FEEDBACK_KIND, FEEDBACK_STATE, h, icon, idChip, known, PHASE_META, plural, sr, timeEl } from './dom.mjs';
import { editorUri, externalLink, renderMarkdown } from './markdown.mjs';

/** Shared components: rows with margins, editing, evidence, traces, and decision cards. */

/** Rows whose margins render decision cards, by phase. */
const DECISION_MARGIN_ROWS = Object.freeze({
    research: /^F\d{1,2}$/,
    plan: /^P\d{2}(?:-T\d{2})?$/,
    implement: /^DS-\d{3}$/,
    review: /^RV-\d{3}$/,
});

/** Rows that list the decisions a phase's artifact records, by phase. */
export const DECISION_ROWS = Object.freeze({ research: 'research-decisions', plan: 'plan-decisions' });

/** True when a decision margin or Decisions row with this ID can render in a phase view that has started. */
export function rendersDecisionMargin(ctx, rowId) {
    if (typeof rowId !== 'string') return false;
    return Object.entries(DECISION_MARGIN_ROWS).some(([phase, pattern]) => {
        const status = ctx.data.session.phases[phase]?.status;
        if (status === 'upcoming' || status === 'skipped') return false;
        return rowId === DECISION_ROWS[phase] || (pattern.test(rowId) && Boolean(ctx.find(rowId)));
    });
}

/** Decisions with no rendered margin or Decisions row are shown as full cards in the steering panel instead. */
export const hasMarginHome = (ctx, decision) => rendersDecisionMargin(ctx, decision?.anchor?.rowId);

/** Native disclosure whose open state survives re-renders. */
export function disclosure(ctx, key, className, summary, ...content) {
    return h('details', { class: className, open: ctx.ui.openDetails.has(key), ontoggle: (event) => ctx.act.setDetailsOpen(key, event.target.open) }, h('summary', { text: summary, dataset: { key: `summary-${key}` } }), content);
}

/**
 * A disclosure that builds its content only while open, for long artifact text. Its summary
 * is an h4, so the section is reachable by heading and its own headings nest below it.
 */
function lazyDisclosure(ctx, key, className, summary, build) {
    const open = ctx.ui.openDetails.has(key);
    return h('details', { class: className, open, ontoggle: (event) => {
        const details = event.target;
        ctx.act.setDetailsOpen(key, details.open);
        if (details.open && details.children.length < 2) details.append(build());
    } }, h('summary', { dataset: { key: `summary-${key}` } }, h('h4', { class: 'summary-heading', text: summary })), open ? build() : null);
}

/** Markdown with navigable IDs; `label` names the text's section for its table regions. */
export const md = (ctx, text, label) => renderMarkdown(text ?? '', { resolveId: (id) => Boolean(ctx.resolve(id)), navigate: ctx.act.navigate, label });

/** Feedback notes anchored to any of these rows, except dismissed ones. */
export const notesFor = (ctx, rowIds) => ctx.data.session.feedback.filter((item) => item.target && rowIds.includes(item.target.id) && ['comment', 'context', 'research-request', 'correction', 'task-request'].includes(item.kind) && item.state !== 'dismissed');

/**
 * Editor link for a workspace-relative path when the canvas reads a real workspace, or null.
 *
 * @param {any} ctx
 * @param {string | null | undefined} path
 */
export function workspaceEditorUri(ctx, path) {
    const root = ctx.data.session.source?.root;
    if (typeof root !== 'string' || !root || typeof path !== 'string' || !path || path.split(/[\\/]/).includes('..')) {
        return null;
    }
    return editorUri(`${root.replace(/[\\/]+$/, '')}/${path.replace(/^\.?[\\/]/, '')}`);
}

const slug = (text) => String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);

/** Sections of a phase's files that no other row shows, each collapsed and rendered as written. */
export function recordSections(ctx, phase) {
    return (ctx.data.session.records?.[phase] ?? []).map((record) => lazyDisclosure(ctx, `record-${phase}-${slug(record.heading)}`, 'record', record.heading,
        () => h('div', { class: 'prose record-body' }, md(ctx, record.markdown, record.heading))));
}

/**
 * A phase's record row for the sections its files hold beyond what the view shows, or null.
 *
 * @param {any} ctx
 * @param {'plan' | 'implement' | 'review'} phase
 * @param {string} title
 */
export function recordRow(ctx, phase, title) {
    const sections = recordSections(ctx, phase);
    if (!sections.length) return null;
    return row(ctx, { id: `${phase}-record`, idLabel: null, title, level: 2, body: [h('p', { class: 'meta', text: "Other sections of this phase's files, as written." }), ...sections] });
}

/**
 * A phase's Decisions row: the decisions its artifact records, as cards, or null when it
 * records none.
 *
 * @param {any} ctx
 * @param {'research' | 'plan'} phase
 */
export function decisionsRow(ctx, phase) {
    const rowId = DECISION_ROWS[phase];
    const decisions = ctx.data.session.decisions.filter((decision) => decision.anchor?.rowId === rowId);
    if (!decisions.length) return null;
    const waiting = decisions.filter((decision) => decision.status === 'needs-input').length;
    const notes = notesFor(ctx, [rowId]);
    return row(ctx, {
        id: rowId, idLabel: null, title: 'Decisions', level: 2,
        badges: [waiting ? badge({ icon: 'hand', label: `${waiting} ${waiting === 1 ? 'needs' : 'need'} you`, tone: 'attention' }) : chip(plural(decisions.length, 'decision'), 'muted')],
        actions: rowActions(ctx, { rowId }),
        body: [
            h('p', { class: 'meta', text: `Recorded in the ${phase === 'plan' ? 'plan' : 'research'} file. Answer or override one here; the agent reads your input and updates the file.` }),
            h('ul', { class: 'decision-grid', 'aria-label': `${PHASE_META[phase].label} decisions` }, decisions.map((decision) => h('li', null, decisionCard(ctx, decision)))),
            notes.length ? h('div', { class: 'decision-notes' }, notes.map((item) => marginNote(ctx, item))) : null,
        ],
    });
}

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

/** Always-visible row actions: Suggest an edit, Comment, and optional Research this. */
export function rowActions(ctx, { sectionId, rowId, research = false, ask = false }) {
    const items = [];
    if (sectionId && ctx.data.session.sections[sectionId]) {
        items.push(button('Suggest an edit', { iconName: 'pencil', hideLabel: true, onClick: () => ctx.act.startEdit(sectionId), attrs: { 'aria-keyshortcuts': ctx.ui.shortcuts ? 'e' : undefined, 'data-key': `edit-section-${rowId}` } }));
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

/** Items the person has not sent yet, apart from any being sent right now. */
export const pendingItems = (ctx) => ctx.data.session.feedback.filter((item) => item.state === 'queued' && !isSending(ctx, item));

/** Suggestions for a section that are waiting to be sent, with the agent, or read back. */
const openSuggestions = (ctx, sectionId) => ctx.data.session.feedback.filter((item) => item.kind === 'edit' && item.target?.id === sectionId && ['queued', 'sent', 'interpreted'].includes(item.state));

/**
 * Section Markdown as its source has it, any suggestions for it, the editor when this
 * section is being edited, or null when the section was never recorded.
 */
export function sectionBody(ctx, sectionId) {
    const section = ctx.data.session.sections[sectionId];
    if (!section) {
        return null;
    }
    if (ctx.ui.editing?.sectionId === sectionId) {
        return editor(ctx, section);
    }
    const suggestions = openSuggestions(ctx, sectionId);
    const body = h('div', { class: 'prose' }, md(ctx, section.markdown));
    return suggestions.length ? h('div', { class: 'section-with-suggestions' }, body, suggestions.map((item) => suggestionCallout(ctx, section, item))) : body;
}

/** One suggested edit beside the section it changes: its state, its line changes, and what the person can do with it. */
function suggestionCallout(ctx, section, item) {
    const sending = isSending(ctx, item);
    const pending = item.state === 'queued' && !sending;
    const moved = Number.isInteger(item.section?.revision) && item.section.revision !== section.revision;
    const where = ctx.data.session.source?.kind === 'rpi' ? 'The file' : 'The document';
    const status = pending
        ? `Waits for Send to agent. ${where} changes when the agent applies it.`
        : item.state === 'interpreted' ? 'The agent read it back. Check that it understood you.' : `${where} changes when the agent applies it.`;
    const titleId = `suggestion-${item.id}-t`;
    const changes = typeof item.section?.diff === 'string'
        ? diffView(item.section.diff, `Your changes to ${section.title}`)
        : h('div', { class: 'prose suggestion-text' }, md(ctx, item.section?.markdown ?? ''));
    return h('section', { class: ['suggestion', `is-${item.state}`], 'aria-labelledby': titleId, dataset: { item: item.id } },
        h('header', { class: 'suggestion-head' },
            icon('pencil', { className: 'tone-user-fg' }),
            h('h4', { class: 'suggestion-title', id: titleId, text: 'Your suggested edit' }),
            badge(sending ? SENDING : FEEDBACK_STATE[item.state]),
            Number.isFinite(item.section?.added) ? h('span', { class: 'meta', text: `+${item.section.added} −${item.section.removed}` }) : null),
        h('p', { class: 'meta', text: status }),
        moved ? h('p', { class: 'suggestion-moved' }, icon('alert', { className: 'tone-attention-fg' }), h('span', { text: 'This section changed after you made this suggestion. Check that it still fits.' })) : null,
        changes,
        item.section?.diffTruncated ? h('p', { class: 'meta', text: 'Showing the first part of a long change; the agent receives all of it.' }) : null,
        item.interpretation ? voice('agent', 'Agent understood', [h('p', { text: item.interpretation.text }), item.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), item.interpretation.effect) : null], { reveal: ctx.ui.revealed.has(item.id) }) : null,
        pending ? h('div', { class: 'btn-row' },
            button('Edit suggestion', { iconName: 'pencil', attrs: { 'data-key': `edit-suggestion-${item.id}` }, onClick: () => ctx.act.startEdit(section.id) }),
            button('Remove', { iconName: 'x', attrs: { 'data-key': `remove-suggestion-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'dismissed') })) : null,
        item.state === 'interpreted' ? readBackActions(ctx, item, 'card') : null);
}

/**
 * Unified diff lines with a marker and a spoken prefix on every added and removed line, or
 * null when there are none.
 *
 * @param {string} text
 * @param {string} label
 */
export function diffView(text, label) {
    const lines = (text || '').split('\n').filter((line, index, all) => line !== '' || index < all.length - 1);
    if (!lines.length) return null;
    return h('div', { class: 'diff', role: 'region', tabindex: '0', 'aria-label': label },
        lines.map((line) => {
            const type = line.startsWith('@@') ? 'hunk' : line.startsWith('+') ? 'add' : line.startsWith('-') ? 'del' : 'ctx';
            const marker = type === 'add' ? '+' : type === 'del' ? '−' : type === 'hunk' ? '' : ' ';
            return h('div', { class: ['diff-line', `is-${type}`] },
                type === 'add' ? sr('Added: ') : type === 'del' ? sr('Removed: ') : null,
                h('span', { class: 'diff-marker', 'aria-hidden': 'true', text: marker }),
                h('span', { class: 'diff-code', text: type === 'hunk' ? line : line.slice(1) }));
        }));
}

function editor(ctx, section) {
    const state = ctx.ui.editing;
    const textareaId = `edit-${section.id}`;
    const showPreview = state.mode === 'preview';
    const updating = Boolean(state.suggestionId);
    const tabs = h('div', { class: 'edit-tabs', role: 'tablist', 'aria-label': `Suggest an edit to ${section.title}` },
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
            h('p', { class: 'notice-title' }, icon('alert'), 'This section changed while you were editing.'),
            state.compare ? h('div', { class: 'compare' },
                h('div', null, h('h4', { text: 'The section now' }), h('div', { class: 'prose' }, md(ctx, state.conflict.markdown))),
                h('div', null, h('h4', { text: 'Your suggestion' }), h('div', { class: 'prose' }, md(ctx, state.draft)))) : null,
            h('div', { class: 'btn-row' },
                button(state.compare ? 'Hide comparison' : 'Compare', { onClick: () => ctx.act.toggleCompare() }),
                button('Keep my suggestion', { kind: 'primary', onClick: () => ctx.act.keepMine() }),
                button('Start from the new text', { onClick: () => ctx.act.useTheirs() })))
        : null;
    return h('div', { class: 'editor' },
        conflict,
        tabs,
        showPreview ? h('div', { class: 'prose preview-pane', role: 'tabpanel', 'aria-label': 'Preview' }, md(ctx, state.draft)) : h('div', { role: 'tabpanel', 'aria-label': 'Write' }, h('label', { class: 'visually-hidden', for: textareaId, text: `Your version of ${section.title}, in Markdown` }), area),
        state.confirmDiscard
            ? h('div', { class: 'notice tone-attention discard-confirm', role: 'group', 'aria-labelledby': `discard-${section.id}` },
                h('p', { class: 'notice-title', id: `discard-${section.id}` }, icon('alert'), 'Discard your unsaved changes?'),
                h('div', { class: 'btn-row' },
                    button('Keep editing', { kind: 'primary', attrs: { 'data-key': 'keep-editing' }, onClick: () => ctx.act.keepEditing() }),
                    button('Discard changes', { attrs: { 'data-key': 'discard-changes' }, onClick: () => ctx.act.cancelEdit() })))
            : h('div', { class: 'btn-row' },
                button(state.saving ? 'Saving' : updating ? 'Update suggestion' : 'Add suggestion', { kind: 'primary', iconName: 'check', disabled: state.saving, attrs: { 'data-key': 'save-edit' }, onClick: () => ctx.act.saveEdit() }),
                button('Cancel', { attrs: { 'data-key': 'cancel-edit' }, onClick: () => ctx.act.requestCancelEdit() }),
                h('span', { class: 'meta', text: `Your suggestion waits for Send to agent. ${ctx.data.session.source?.kind === 'rpi' ? 'The file' : 'The document'} changes when the agent applies it.` })));
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
            if (!item) return h('p', { class: 'meta', text: `${id} is not in the evidence log.` });
            return h('div', { class: 'evidence-detail' },
                h('p', null, h('span', { class: 'id-chip', text: id }), ' ', item.claim),
                h('p', { class: 'meta' },
                    item.url ? externalLink(item.url, item.source) : h('code', { text: item.source }),
                    item.confidence ? ` · Confidence ${item.confidence}` : '', item.retrieved ? ` · Retrieved ${item.retrieved}` : ''));
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
 * with override, and resolved. A decision without options takes an answer in the user's
 * words; an agent decision without alternatives takes an override in the user's words.
 *
 * @param {any} ctx
 * @param {any} decision
 */
export function decisionCard(ctx, decision) {
    const session = ctx.data.session;
    const feedback = decision.feedbackId ? session.feedback.find((item) => item.id === decision.feedbackId) : null;
    const chosen = decision.options.find((option) => option.id === decision.chosen);
    const initial = { optionId: decision.options.find((o) => o.recommended)?.id ?? null, note: '' };
    const draft = ctx.ui.decisionDrafts.get(decision.id) ?? initial;
    // Handlers read the stored draft so a note typed before choosing an option is kept.
    const update = (patch) => ctx.act.setDecisionDraft(decision.id, { ...(ctx.ui.decisionDrafts.get(decision.id) ?? initial), ...patch });
    const current = () => ctx.ui.decisionDrafts.get(decision.id) ?? initial;
    const head = h('header', { class: 'card-head' },
        icon('signpost', { className: 'card-icon' }),
        h('span', { class: 'id-chip', text: decision.ref ?? decision.id }),
        h('h4', { class: 'card-title', text: decision.title }),
        badge(known(DECISION_STATUS, decision.status)));
    const owner = h('p', { class: 'card-owner meta' }, decision.owner === 'user' ? 'Your decision' : "The agent's decision", ` · ${PHASE_META[decision.phase]?.label ?? decision.phase}`);
    const parts = [head, owner];
    const evidence = evidenceChips(ctx, `dec-${decision.id}`, decision.evidence);
    const submitKey = `submit-${decision.id}`;

    if (decision.status === 'needs-input') {
        const name = `decision-${decision.id}`;
        const noteId = `${name}-note`;
        const ownWords = decision.options.length === 0;
        parts.push(
            decision.question && decision.question !== decision.title ? h('p', { class: 'card-question', text: decision.question }) : null,
            decision.context ? h('div', { class: 'card-context prose' }, md(ctx, decision.context)) : null,
            ownWords ? null : optionList(ctx, decision, name, draft.optionId, (optionId) => update({ optionId })),
            evidence,
            decision.impact ? h('p', { class: 'card-impact' }, icon('arrow-right'), h('span', null, h('strong', { text: 'If you answer: ' }), decision.impact)) : null,
            h('label', { class: 'field-label', for: noteId, text: ownWords ? 'Your answer' : 'Add a note (optional)' }),
            h('textarea', { id: noteId, class: 'note', rows: ownWords ? '3' : '2', 'aria-required': ownWords ? 'true' : undefined, oninput: (event) => update({ note: event.target.value }) }, draft.note),
            h('div', { class: 'btn-row' },
                button('Answer', { kind: 'primary', iconName: 'check', disabled: ownWords ? !draft.note.trim() : !draft.optionId, attrs: { 'data-key': submitKey, 'data-needs-text': ownWords ? 'true' : undefined }, onClick: () => ctx.act.answer(decision.id, 'answer', ownWords ? { optionId: null, note: current().note } : current()) }),
                h('span', { class: 'meta', text: 'Waits for Send to agent' })));
    } else if (decision.status === 'decided' || decision.status === 'override-pending') {
        const overriding = ctx.ui.overrides.has(decision.id);
        const pending = decision.status === 'override-pending' ? feedback : null;
        // While an override waits, the agent's own choice stays on the card above it.
        const agentChoice = pending?.previousChosen !== undefined && pending?.previousChosen !== null ? decision.options.find((option) => option.id === pending.previousChosen) : chosen;
        const said = [
            agentChoice && agentChoice.label !== decision.title ? h('p', null, h('strong', { text: agentChoice.label })) : null,
            decision.rationale ? h('p', { text: decision.rationale }) : null,
        ].filter(Boolean);
        parts.push(said.length ? voice('agent', 'Agent decided', said) : null, evidence);
        const alternatives = decision.options.filter((option) => option.id !== agentChoice?.id);
        if (pending) {
            parts.push(readBack(ctx, decision, pending, 'Your override'));
        } else if (overriding) {
            const name = `override-${decision.id}`;
            const noteId = `${name}-note`;
            const ownWords = alternatives.length === 0;
            parts.push(
                ownWords ? null : h('p', { class: 'card-question', text: 'Choose a different option:' }),
                ownWords ? null : optionList(ctx, decision, name, draft.optionId === decision.chosen ? null : draft.optionId, (optionId) => update({ optionId }), decision.chosen),
                h('label', { class: 'field-label', for: noteId, text: ownWords ? 'What should the agent do instead?' : 'Why (optional)' }),
                h('textarea', { id: noteId, class: 'note', rows: ownWords ? '3' : '2', 'aria-required': ownWords ? 'true' : undefined, oninput: (event) => update({ note: event.target.value }) }, draft.note),
                h('div', { class: 'btn-row' },
                    button('Save override', { kind: 'primary', disabled: ownWords ? !draft.note.trim() : !draft.optionId || draft.optionId === decision.chosen, attrs: { 'data-key': submitKey, 'data-needs-text': ownWords ? 'true' : undefined }, onClick: () => ctx.act.answer(decision.id, 'override', ownWords ? { optionId: null, note: current().note } : current()) }),
                    button('Cancel', { onClick: () => ctx.act.toggleOverride(decision.id) })));
        } else {
            parts.push(h('div', { class: 'btn-row' }, button('Override', { iconName: 'undo', attrs: { 'data-key': `override-${decision.id}` }, onClick: () => ctx.act.toggleOverride(decision.id) })));
        }
    } else if (decision.status === 'answered' && feedback) {
        parts.push(readBack(ctx, decision, feedback, 'You'));
    } else {
        const history = feedback ? readBack(ctx, decision, feedback, 'You', { compact: true }) : null;
        const outcome = chosen?.label ?? (feedback?.text ? `“${feedback.text}”` : null);
        parts.push(h('p', { class: 'resolved-line' }, icon('check', { className: 'tone-success-fg' }), h('span', null, outcome ? ['Resolved: ', h('strong', { text: outcome })] : 'Resolved', decision.impact ? ` · ${decision.impact}` : '')),
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
        : voice('user', youLabel, [chosen?.label ?? feedback.optionLabel ? h('p', null, h('strong', { text: chosen?.label ?? feedback.optionLabel })) : null, feedback.text ? h('p', { text: `“${feedback.text}”` }) : null], { meta: FEEDBACK_STATE[feedback.state]?.label }));
    if (feedback.interpretation) {
        parts.push(voice('agent', 'Agent understood', [h('p', { text: feedback.interpretation.text }), feedback.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), feedback.interpretation.effect) : null], { reveal: fresh }));
    } else if (!options.compact && (feedback.state === 'queued' || feedback.state === 'sent')) {
        parts.push(h('p', { class: 'waiting meta' }, icon(feedback.state === 'queued' ? 'inbox' : 'send'), feedback.state === 'queued' ? 'Not sent yet. It goes to the agent when you choose Send to agent.' : 'Sent. The agent will read back how it understood this.'));
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

/** A comment or other feedback shown in a row margin. */
export function marginNote(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    return h('article', { class: ['card', 'note-card'], dataset: { item: item.id } },
        h('header', { class: 'card-head' }, icon(kind.icon, { className: 'card-icon' }), h('span', { class: 'id-chip', text: item.id }), h('h4', { class: 'card-title', text: kind.label }), badge(FEEDBACK_STATE[item.state])),
        voice('user', 'You', h('p', { text: item.text }), { meta: null }),
        item.interpretation ? voice('agent', 'Agent understood', [h('p', { text: item.interpretation.text }), item.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), item.interpretation.effect) : null], { reveal: ctx.ui.revealed.has(item.id) }) : null,
        item.state === 'interpreted' ? readBackActions(ctx, item, 'card') : null,
        item.createdAt ? h('p', { class: 'meta' }, timeEl(item.createdAt, ctx.now)) : null);
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
                button('Save correction', { kind: 'primary', iconName: 'check', attrs: { 'data-key': `send-correction-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'corrected', { correction: ctx.ui.corrections.get(item.id)?.text ?? '' }) }),
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

/** Matches the model's claim window: a send holds its items for up to 10 minutes. */
const isSending = (ctx, item) => item.state === 'queued' && Boolean(item.deliveringSince) && ctx.now - Date.parse(item.deliveringSince) < 10 * 60 * 1000;
const SENDING = Object.freeze({ icon: 'send', label: 'Sending', tone: 'accent' });
const DELIVERY_WORDS = Object.freeze({ send: 'sent as a message', queue: 'collected by the agent', attach: 'attached to a message' });

/** What a feedback item is about, as the steering panel and the send dialog name it. */
function feedbackTarget(ctx, item) {
    if (item.kind === 'checklist') {
        return h('span', null, ` for ${PHASE_META[item.phase]?.label ?? 'this phase'}`);
    }
    if (!item.target) return null;
    const decision = item.target.type === 'decision' ? ctx.data.session.decisions.find((candidate) => candidate.id === item.target.id) : null;
    // A namespaced decision such as plan.D1 shows its artifact ID and phase.
    const scoped = decision?.ref && decision.ref !== decision.id ? { label: decision.ref, title: `Go to ${decision.ref} in ${PHASE_META[decision.phase]?.label ?? decision.phase}` } : {};
    const section = item.target.type === 'section' ? ctx.data.session.sections[item.target.id] : null;
    if (section) {
        return h('span', null, ' to ', h('strong', { text: section.title }), ` in ${PHASE_META[section.doc]?.label ?? section.doc}`);
    }
    return h('span', null, ' about ', ctx.resolve(item.target.id) ? idChip(item.target.id, ctx.act.navigate, scoped) : h('span', { class: 'id-chip', text: scoped.label ?? item.target.id }), scoped.label ? ` in ${PHASE_META[decision.phase]?.label ?? decision.phase}` : null);
}

function feedbackRow(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    const actions = [];
    const sending = isSending(ctx, item);
    const remove = !sending && (item.state === 'queued' || item.state === 'draft')
        ? button(`Remove ${item.id}`, { iconName: 'x', hideLabel: true, attrs: { 'data-key': `dismiss-${item.id}` }, onClick: () => ctx.act.transition(item.id, 'dismissed') })
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
    const how = item.delivery && item.state !== 'queued' ? DELIVERY_WORDS[item.delivery] : null;
    return h('li', { class: 'fb-item', dataset: { item: item.id } },
        h('div', { class: 'fb-head' }, icon(kind.icon), h('span', { class: 'fb-kind' }, kind.label, feedbackTarget(ctx, item)), badge(sending ? SENDING : FEEDBACK_STATE[item.state]), remove),
        item.optionLabel ? h('p', { class: 'fb-text' }, h('strong', { text: item.optionLabel })) : null,
        item.text ? h('p', { class: 'fb-text', text: excerpt(item.text, 160) }) : null,
        item.interpretation ? h('p', { class: 'fb-interp' }, icon('sparkle'), h('span', { text: item.interpretation.text })) : null,
        h('p', { class: 'fb-meta meta' }, h('span', { class: 'id-chip', text: item.id }), ' ', timeEl(item.updatedAt ?? item.createdAt, ctx.now), how ? ` · ${how}` : ''),
        actions.length ? h('div', { class: 'btn-row' }, actions) : null,
        readBack);
}

const excerpt = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

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
    const refOf = (id) => decisionOf(id)?.ref ?? id;
    const needs = h('ul', { class: 'steer-list' },
        view.needsYou.map((item) => (hasMarginHome(ctx, decisionOf(item.id)) ? h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `needs-${item.id}` }, onclick: () => ctx.act.navigate(item.id) },
                icon('hand', { className: 'tone-attention-fg' }), h('span', { class: 'steer-link-text' }, h('span', { class: 'id-chip', text: refOf(item.id) }), ' ', item.title), h('span', { class: 'meta', text: phaseLabel(item.phase) }))) : steerCard(decisionOf(item.id)))),
        waiting.map((item) => h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `check-${item.id}` }, onclick: () => ctx.act.navigate(item.target?.type === 'decision' ? item.target.id : item.id) },
                icon('sparkle', { className: 'tone-agent-fg' }), h('span', { class: 'steer-link-text' }, 'Check how the agent read ', h('span', { class: 'id-chip', text: item.id })), h('span', { class: 'meta', text: phaseLabel(item.target?.phase) })))));
    const needsCount = view.needsYou.length + waiting.length;
    // Agent decisions listed in a phase's Decisions row collapse to one link per row.
    const rowGroups = new Map();
    const decidedSingles = [];
    for (const item of view.decidedByAgent) {
        const decision = decisionOf(item.id);
        const rowId = decision?.anchor?.rowId;
        if (Object.values(DECISION_ROWS).includes(rowId) && hasMarginHome(ctx, decision)) {
            if (!rowGroups.has(rowId)) rowGroups.set(rowId, { phase: decision.anchor.phase, count: 0 });
            rowGroups.get(rowId).count += 1;
        } else {
            decidedSingles.push(item);
        }
    }
    const decided = h('ul', { class: 'steer-list' },
        [...rowGroups].map(([rowId, group]) => h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `decided-${rowId}` }, onclick: () => ctx.act.navigate(rowId, group.phase) },
                icon('sparkle', { className: 'tone-agent-fg' }), h('span', { class: 'steer-link-text', text: `${plural(group.count, 'recorded decision')}` }), h('span', { class: 'meta', text: phaseLabel(group.phase) })))),
        decidedSingles.map((item) => (hasMarginHome(ctx, decisionOf(item.id)) ? h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `decided-${item.id}` }, onclick: () => ctx.act.navigate(item.id) },
                icon('sparkle', { className: 'tone-agent-fg' }), h('span', { class: 'steer-link-text' }, h('span', { class: 'id-chip', text: refOf(item.id) }), ' ', item.title), h('span', { class: 'meta', text: phaseLabel(item.phase) }))) : steerCard(decisionOf(item.id)))));

    const pending = pendingItems(ctx);
    const inFlight = session.feedback.filter((item) => item.state === 'sent' || item.state === 'interpreted' || isSending(ctx, item));
    const earlier = session.feedback.filter((item) => ['applied', 'corrected', 'dismissed'].includes(item.state));
    const feedback = h('div', null,
        pending.length
            ? [h('h4', { class: 'group-title', text: `Not sent yet (${pending.length})` }), h('ul', { class: 'fb-list' }, pending.map((item) => feedbackRow(ctx, item))),
                h('div', { class: 'btn-row send-row' }, button('Review and send…', { kind: 'primary', iconName: 'send', attrs: { 'data-key': 'open-send', 'aria-haspopup': 'dialog' }, onClick: () => ctx.act.openSend() })),
                h('p', { class: 'meta', text: 'Or use Send to agent at the top of the canvas.' })]
            : h('p', { class: 'empty', text: 'Nothing waiting to send. Your answers, comments, suggested edits, and checklist reviews collect here until you choose Send to agent at the top of the canvas.' }),
        inFlight.length ? [h('h4', { class: 'group-title', text: `With the agent (${inFlight.length})` }), h('ul', { class: 'fb-list' }, inFlight.map((item) => feedbackRow(ctx, item)))] : null,
        earlier.length ? disclosure(ctx, 'earlier-feedback', 'earlier', `Earlier feedback (${earlier.length})`, h('ul', { class: 'fb-list' }, earlier.slice().reverse().map((item) => feedbackRow(ctx, item)))) : null);

    return [
        steerSection('needs', 'Needs your input', needsCount, needsCount ? needs : h('p', { class: 'empty', text: 'Nothing needs you right now. Decisions the agent asks you about appear here.' }), { iconName: 'hand', className: needsCount ? 'has-items' : null }),
        steerSection('decided', 'Decided by the agent', view.decidedByAgent.length, view.decidedByAgent.length ? decided : h('p', { class: 'empty', text: 'No agent decisions yet.' }), { iconName: 'sparkle' }),
        steerSection('feedback', 'Your feedback', pending.length + inFlight.length, feedback, { iconName: 'inbox' }),
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
    h('div', { class: 'btn-row' }, h('button', { type: 'submit', class: 'btn btn-primary', disabled: !state.text.trim(), dataset: { key: 'composer-submit' } }, icon('plus'), h('span', { text: { comment: 'Add comment', context: 'Add context', 'research-request': 'Add research request' }[state.kind] ?? 'Add' }))),
    h('p', { class: 'meta', text: 'What you add waits in Your feedback until you choose Send to agent.' }));
}

const PHASE_NOUNS = Object.freeze({ research: 'the research', plan: 'the plan', implement: 'the implementation', review: 'the review', followup: 'the follow-up' });

/** A checklist item's verdict; items saved before verdicts read `checked` as Looks good. */
const verdictOf = (item) => (item.verdict === 'ok' || item.verdict === 'needs-work' ? item.verdict : item.checked === true ? 'ok' : null);

/**
 * The phase's review checklist: why it exists and what reaches the agent, then each
 * statement with Looks good and Needs work toggles and, for Needs work, a note.
 */
function checklist(ctx) {
    const phase = ctx.ui.phase;
    const items = ctx.data.session.checklists[phase] ?? [];
    if (!items.length) {
        return h('p', { class: 'empty', text: 'A checklist appears when this phase has content to review.' });
    }
    const reviewed = items.filter((item) => verdictOf(item)).length;
    const work = items.filter((item) => verdictOf(item) === 'needs-work').length;
    const review = ctx.data.session.feedback.filter((item) => item.kind === 'checklist' && item.phase === phase);
    const pending = review.find((item) => item.state === 'queued');
    const sent = review.findLast((item) => ['sent', 'interpreted', 'applied', 'corrected'].includes(item.state));
    const status = pending ? 'Your review goes with your next send.' : sent ? 'The agent has your latest review.' : 'Nothing here goes to the agent yet.';
    return h('div', { class: 'checklist' },
        h('p', { class: 'checklist-intro', text: `Optional questions for reviewing ${PHASE_NOUNS[phase] ?? 'this phase'}. Mark each one as you read. Items that need work, with your notes, go to the agent with your next send, and so does an all-good list. Other marks only track your progress.` }),
        h('p', { class: ['checklist-status', pending ? 'is-pending' : null], role: 'status' },
            icon(pending ? 'send' : 'checklist'),
            h('span', { text: `${reviewed} of ${items.length} reviewed${work ? `, ${work} ${work === 1 ? 'needs' : 'need'} work` : ''}. ${status}` })),
        h('ul', { class: 'check-list' }, items.map((item) => checkItem(ctx, phase, item))));
}

function checkItem(ctx, phase, item) {
    const verdict = verdictOf(item);
    const labelId = `check-${phase}-${item.id}`;
    const noteId = `check-note-${phase}-${item.id}`;
    // Pressing the selected verdict clears it; the labels never change, so the pressed state carries the meaning.
    const toggle = (value, iconName, text) => h('button', {
        type: 'button', class: ['verdict', `is-${value}`], 'aria-pressed': String(verdict === value), dataset: { key: `verdict-${phase}-${item.id}-${value}` },
        onclick: () => ctx.act.markChecklist(phase, item.id, verdict === value ? null : value, value === 'needs-work' ? item.note ?? '' : undefined),
    }, icon(iconName), h('span', { text }));
    return h('li', { class: ['check-item', verdict ? `is-${verdict}` : null] },
        h('p', { class: 'check-label', id: labelId, text: item.label }),
        h('div', { class: 'verdicts', role: 'group', 'aria-labelledby': labelId }, toggle('ok', 'check', 'Looks good'), toggle('needs-work', 'flag', 'Needs work')),
        verdict === 'needs-work'
            ? h('div', { class: 'check-note' },
                h('label', { class: 'field-label', for: noteId, text: 'What needs work? (optional)' }),
                h('textarea', { id: noteId, class: 'note', rows: '2', onchange: (event) => ctx.act.markChecklist(phase, item.id, 'needs-work', event.target.value) }, item.note ?? ''))
            : null);
}

/**
 * Content of the Send to agent dialog: what goes, from which canvas, an optional message,
 * the exact text the agent reads, and Send. With nothing waiting it explains how to add
 * something instead.
 *
 * @param {any} ctx
 */
export function sendSheet(ctx) {
    const pending = pendingItems(ctx);
    const send = ctx.ui.send;
    const handle = ctx.data.canvas?.handle;
    const rpi = ctx.data.session.source?.kind === 'rpi';
    const head = h('div', { class: 'dialog-head' },
        h('h2', { id: 'sendSheetTitle', tabindex: '-1' }, icon('send'), 'Send to the agent'),
        h('button', { type: 'button', class: 'icon-btn', 'data-close': '', dataset: { key: 'send-close' } }, icon('x'), sr('Close')));
    const from = handle ? ['Canvas ', h('code', { class: 'canvas-handle', text: handle })] : ['This canvas'];
    if (!pending.length) {
        return [head,
            h('p', { class: 'send-intro' }, ...from, ' has nothing waiting to send.'),
            h('p', { text: 'Add something first, then send it all here:' }),
            h('ul', { class: 'send-howto' },
                h('li', { text: 'Answer a decision the agent asks you, or override one it made.' }),
                h('li', { text: 'Comment on a row, or suggest an edit to its text.' }),
                h('li', { text: 'Add context or a research request under Add input.' }),
                h('li', { text: 'Mark items in the review checklist.' })),
            h('div', { class: 'btn-row' }, button('Close', { attrs: { 'data-close': '', 'data-key': 'send-cancel' } }))];
    }
    const noun = plural(pending.length, 'item');
    return [head,
        h('p', { class: 'send-intro' }, ...from, ` sends ${pending.length === 1 ? 'this item' : `these ${pending.length} items`} to the agent in your chat as one message that starts with “RPI canvas${handle ? ` ${handle}` : ''}”. The agent ${rpi ? "changes the task's files" : 'makes the changes'} and reads back how it understood each item.`),
        h('ul', { class: 'send-list', 'aria-label': 'Items to send' }, pending.map((item) => sendRow(ctx, item))),
        h('label', { class: 'field-label', for: 'send-note', text: 'Message to the agent (optional)' }),
        h('textarea', { id: 'send-note', class: 'note', rows: '3', 'aria-describedby': 'send-note-hint', oninput: (event) => ctx.act.setSendNote(event.target.value) }, send.note),
        h('p', { class: 'meta', id: 'send-note-hint', text: 'Shown in the chat above the line that names this canvas.' }),
        h('details', { class: 'send-exact' },
            h('summary', { text: 'Exact message the agent receives' }),
            h('pre', { class: 'preview-text', id: 'send-preview', tabindex: '0', text: send.preview?.prompt ?? 'Preparing the message…' })),
        send.error ? h('div', { class: 'notice tone-danger', role: 'alert', id: 'send-error' }, h('p', { class: 'notice-title' }, icon('alert'), send.error)) : null,
        h('div', { class: 'btn-row send-actions' },
            button(send.sending ? 'Sending' : `Send ${noun}`, { kind: 'primary', iconName: 'send', disabled: send.sending || !send.preview, attrs: { 'data-key': 'send-confirm', id: 'send-confirm' }, onClick: () => ctx.act.send() }),
            button('Cancel', { attrs: { 'data-close': '', 'data-key': 'send-cancel' } }))].filter(Boolean);
}

function sendRow(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    const detail = item.kind === 'edit' && Number.isFinite(item.section?.added)
        ? `${plural(item.section.added, 'line')} added, ${item.section.removed} removed`
        : item.optionLabel ?? item.text ?? '';
    const where = item.kind === 'checklist' ? { phase: item.phase } : item.target ? { id: item.target.id } : null;
    return h('li', { class: 'send-item', dataset: { item: item.id } },
        icon(kind.icon, { className: 'send-item-icon' }),
        h('div', { class: 'send-item-text' },
            h('p', { class: 'send-item-kind' }, kind.label, feedbackTarget(ctx, item)),
            detail ? h('p', { class: 'meta', text: excerpt(detail.split('\n')[0], 140) }) : null),
        h('div', { class: 'send-item-actions' },
            where ? button(`Show ${item.id} in the canvas`, { iconName: 'eye', hideLabel: true, attrs: { 'data-key': `send-show-${item.id}` }, onClick: () => ctx.act.showPending(item) }) : null,
            button(`Remove ${item.id}`, { iconName: 'x', hideLabel: true, attrs: { 'data-key': `send-remove-${item.id}` }, onClick: () => ctx.act.removePending(item.id) })));
}

/**
 * File preview sheet content with a symbol-marked diff and file actions.
 *
 * @param {any} ctx
 * @param {any} change
 * @param {any} file
 */
export function filePreview(ctx, change, file) {
    const kindTone = { added: 'success', modified: 'accent', deleted: 'danger', renamed: 'muted' }[file.kind] ?? 'muted';
    const counted = Number.isFinite(file.additions) && Number.isFinite(file.deletions);
    const diff = diffView(file.diff, `Changes in ${file.path}`)
        ?? h('p', { class: 'empty', text: counted ? 'No diff was recorded for this file. The changes record lists it with its line counts.' : 'No diff was recorded for this file. Open it in the editor to see its current content.' });
    const editorLink = workspaceEditorUri(ctx, file.path) ?? editorUri(file.path);
    return [
        h('div', { class: 'dialog-head' },
            h('h2', { id: 'fileSheetTitle', class: 'sheet-title' }, icon('file'), h('code', { text: file.path })),
            h('button', { type: 'button', class: 'icon-btn', 'data-close': '' }, icon('x'), sr('Close'))),
        h('p', { class: 'sheet-meta' }, h('span', { class: ['badge', `tone-${kindTone}`], text: file.kind }), counted ? ` +${file.additions} −${file.deletions}` : '', ' · ', h('span', { class: 'id-chip', text: change.id }), ` ${change.title}`, change.taskId ? [' · ', h('span', { class: 'id-chip', text: change.taskId })] : null),
        diff,
        h('div', { class: 'btn-row' },
            button('Copy path', { iconName: 'copy', onClick: () => ctx.act.copy(file.path) }),
            button('Ask the agent about this change', { iconName: 'message', onClick: () => ctx.act.anchorComposer(change.id, 'comment', true) }),
            editorLink ? h('a', { class: 'btn', href: editorLink }, icon('external'), h('span', { text: 'Open in editor' })) : h('span', { class: 'meta', text: 'Open in editor appears for files in your workspace once the canvas reads real changes.' })),
    ];
}
