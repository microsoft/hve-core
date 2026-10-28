// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, confidenceMeta, DECISION_STATUS, FEEDBACK_KIND, FEEDBACK_STATE, h, icon, idChip, idTag, known, PHASE_META, plural, sr, timeEl } from './dom.mjs';
import { renderInline, renderMarkdown } from './markdown.mjs';
import { editorButton, evidenceSource } from './source-view.mjs';

/** Shared components: rows with margins, editing, evidence, traces, and decision cards. */

/** Rows whose margins render decision cards, by phase. */
const DECISION_MARGIN_ROWS = Object.freeze({
    research: /^F\d{1,3}$/,
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
export const md = (ctx, text, label, baseDir) => renderMarkdown(text ?? '', {
    resolveId: (id) => Boolean(ctx.resolve(id)),
    navigate: ctx.act.navigate,
    label,
    ...(typeof baseDir === 'string' ? { baseDir, openSource: ctx.act.openSource } : {}),
});

/**
 * One line of inline Markdown with navigable IDs, for table cells and short fields. `doc`
 * names the phase whose artifact the text comes from, so its relative links open as sources.
 *
 * @param {any} ctx
 * @param {string | null | undefined} text
 * @param {{ doc?: string, shortUrls?: boolean }} [options]
 */
export function mdInline(ctx, text, options = {}) {
    const baseDir = options.doc ? artifactDir(ctx, options.doc) : undefined;
    return renderInline(text ?? '', {
        resolveId: (id) => Boolean(ctx.resolve(id)),
        navigate: ctx.act.navigate,
        shortUrls: Boolean(options.shortUrls),
        ...(typeof baseDir === 'string' ? { baseDir, openSource: ctx.act.openSource } : {}),
    });
}

/** The workspace folder of a phase's artifact in a real session, so its relative links open as sources. */
export function artifactDir(ctx, doc) {
    if (ctx.data.session.source?.kind !== 'rpi') return undefined;
    const artifact = ctx.data.session.phases?.[doc]?.artifact;
    return typeof artifact === 'string' && artifact.includes('/') ? artifact.slice(0, artifact.lastIndexOf('/')) : undefined;
}

/** Feedback notes anchored to any of these rows, except dismissed ones. */
// An earlier document is read-only: its row IDs can repeat the newest document's, so no notes show on it.
export const notesFor = (ctx, rowIds) => (ctx.readOnly ? [] : ctx.data.session.feedback).filter((item) => item.target && rowIds.includes(item.target.id) && ['comment', 'context', 'research-request', 'correction', 'task-request'].includes(item.kind) && item.state !== 'dismissed');

const slug = (text) => String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);

/** Sections of a phase's files that no other row shows, each collapsed and rendered as written. */
export function recordSections(ctx, phase) {
    return (ctx.data.session.records?.[phase] ?? []).map((record) => lazyDisclosure(ctx, `record-${phase}-${slug(record.heading)}`, 'record', record.heading,
        () => h('div', { class: 'prose record-body' }, md(ctx, record.markdown, record.heading, artifactDir(ctx, phase)))));
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
    const given = (spec.margin ?? []).filter(Boolean);
    // Comments on a part of this row show beside it, even in rows that list no notes of their own.
    const shown = new Set(given.map((element) => element.dataset?.item).filter(Boolean));
    const partNotes = notesFor(ctx, [spec.id]).filter((item) => item.target?.part && !shown.has(item.id) && (item.kind === 'comment' || item.kind === 'context')).map((item) => marginNote(ctx, item));
    const margin = [...given, ...partNotes];
    const section = h('section', {
        class: ['row', margin.length ? 'has-margin' : null, spec.className, ctx.ui.highlight === spec.id ? 'is-highlight' : null],
        id: `row-${spec.id}`,
        dataset: { row: spec.id },
        tabindex: '-1',
        'aria-labelledby': titleId,
    },
    h('div', { class: 'row-main' },
        h('header', { class: 'row-head' },
            h('div', { class: 'row-heading' },
                spec.idLabel === null ? null : h('span', { class: 'id-chip', text: spec.idLabel ?? spec.id }),
                h('h3', { class: ['row-title', spec.level === 2 ? 'is-major' : null], id: titleId, text: spec.title }),
                (spec.badges ?? []).length ? h('span', { class: 'row-badges' }, spec.badges) : null),
            (spec.actions ?? []).length ? h('span', { class: 'row-actions' }, spec.actions) : null),
        h('div', { class: 'row-text' }, spec.body)),
    margin.length ? h('aside', { class: 'row-margin', 'aria-label': `Notes for ${spec.idLabel ?? spec.id}` }, margin) : null);
    return section;
}

/** Row actions, shown while the row is hovered or holds focus: Suggest an edit, Comment, and optional Research this. */
export function rowActions(ctx, { sectionId, rowId, research = false, ask = false }) {
    const items = [];
    if (ctx.readOnly) return items;
    if (sectionId && ctx.data.session.sections[sectionId]) {
        items.push(button('Suggest an edit', { iconName: 'pencil', hideLabel: true, onClick: () => ctx.act.startEdit(sectionId), attrs: { 'aria-keyshortcuts': ctx.ui.shortcuts ? 'e' : undefined, 'data-key': `edit-section-${rowId}` } }));
    }
    items.push(button('Comment', { iconName: 'message', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'comment'), attrs: { 'aria-keyshortcuts': ctx.ui.shortcuts ? 'c' : undefined, 'data-key': `comment-${rowId}` } }));
    if (research) {
        items.push(button('Research this', { iconName: 'search', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'research-request'), attrs: { 'data-key': `research-${rowId}` } }));
    }
    if (ask) {
        items.push(button('Ask the agent', { iconName: 'sparkle', hideLabel: true, onClick: () => ctx.act.anchorComposer(rowId, 'comment') }));
    }
    return items;
}

/** How long an Updated mark stays after the agent changes a section's text. */
export const UPDATED_WINDOW_MS = 10 * 60 * 1000;

/**
 * "Updated" with the time, for a section whose text the agent changed in the last ten
 * minutes after the canvas first read it, or null.
 *
 * @param {any} ctx
 * @param {string | undefined} sectionId
 */
export function updatedMark(ctx, sectionId) {
    const section = sectionId ? ctx.data.session.sections[sectionId] : null;
    if (!section || !(section.revision > 1) || !section.updatedAt) return null;
    const age = ctx.now - Date.parse(section.updatedAt);
    if (!(age >= 0 && age < UPDATED_WINDOW_MS)) return null;
    return h('span', { class: 'badge tone-agent updated-mark' }, icon('pencil'), 'Updated ', timeEl(section.updatedAt, ctx.now));
}

/** True for an unsent item you queued for the agent's next checkpoint; other loops' summaries carry a flag. */
export const queuedForAgent = (item) => Boolean(item.queuedForAgentAt ?? item.queuedForAgent);

/** Items you have not sent or queued yet, apart from any being sent right now. */
export const pendingItems = (ctx) => ctx.data.session.feedback.filter((item) => item.state === 'queued' && !isSending(ctx, item) && !queuedForAgent(item));

/** Items you queued for the agent that it has not collected yet. */
export const agentQueueItems = (ctx) => ctx.data.session.feedback.filter((item) => item.state === 'queued' && !isSending(ctx, item) && queuedForAgent(item));

/** Status of the shown task in its session tree, or from its own state. */
const shownStatus = (ctx) => ctx.data.session.followUps?.tree?.tasks.find((task) => task.shown)?.status ?? (ctx.data.session.session.status === 'completed' ? 'completed' : null);

/**
 * Unsent items across the session, grouped by task: the shown task first, then the other
 * tasks in tree order, each listing items not sent yet before items queued for the agent.
 * Other tasks' items are summaries from the server.
 *
 * @param {any} ctx
 * @returns {{ taskId: string, title: string, status: string | null, shown: boolean, items: any[] }[]}
 */
export function sessionPending(ctx) {
    const { session } = ctx.data;
    const groups = [{ taskId: session.task.id, title: session.task.title, status: shownStatus(ctx), shown: true, items: [...pendingItems(ctx), ...agentQueueItems(ctx)] }];
    for (const task of ctx.data.otherTasks ?? []) {
        const items = [...task.pending.filter((item) => !queuedForAgent(item)), ...task.pending.filter(queuedForAgent)];
        if (items.length) groups.push({ taskId: task.taskId, title: task.title, status: task.status, shown: false, items });
    }
    return groups.filter((group) => group.items.length);
}

/** The items Send now delivers, as `{ taskId, id }` in the order the dialog lists them. */
export const sendItems = (ctx) => sessionPending(ctx).flatMap((group) => group.items.map((item) => ({ taskId: group.taskId, id: item.id })));

/** How many items across the session wait for you to send or queue them. */
export const waitingCount = (ctx) => sessionPending(ctx).reduce((sum, group) => sum + group.items.filter((item) => !queuedForAgent(item)).length, 0);

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
    if (!ctx.readOnly && ctx.ui.editing?.sectionId === sectionId) {
        return editor(ctx, section);
    }
    const suggestions = ctx.readOnly ? [] : openSuggestions(ctx, sectionId);
    const body = h('div', { class: 'prose' }, md(ctx, section.markdown, undefined, artifactDir(ctx, section.doc)));
    return suggestions.length ? h('div', { class: 'section-with-suggestions' }, body, suggestions.map((item) => suggestionCallout(ctx, section, item))) : body;
}

/** One suggested edit beside the section it changes: its state, its line changes, and what the person can do with it. */
function suggestionCallout(ctx, section, item) {
    const sending = isSending(ctx, item);
    const pending = item.state === 'queued' && !sending;
    const moved = Number.isInteger(item.section?.revision) && item.section.revision !== section.revision;
    const where = ctx.data.session.source?.kind === 'rpi' ? 'The file' : 'The document';
    const status = pending
        ? `Waits in Review and send. ${where} changes when the agent applies it.`
        : item.state === 'interpreted' ? 'The agent read it back and has not made the change yet. Correct it if it misunderstood you.' : `${where} changes when the agent applies it.`;
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
                if ((event.key === 'ArrowRight' || event.key === 'ArrowLeft') && !event.altKey && !event.ctrlKey && !event.metaKey) {
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
                h('span', { class: 'meta', text: `Your suggestion waits in Review and send. ${ctx.data.session.source?.kind === 'rpi' ? 'The file' : 'The document'} changes when the agent applies it.` })));
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
            const expanded = ctx.ui.openEvidence.has(`${rowKey}:${id}`);
            return h('button', {
                type: 'button', class: ['id-chip', 'is-link', 'evidence-chip', expanded ? 'is-open' : null], 'aria-expanded': String(expanded), 'aria-controls': regionId,
                dataset: { preview: id }, onclick: () => ctx.act.toggleEvidence(rowKey, id),
            }, id, icon('file', { className: 'icon-inline chip-icon' }));
        }));
    const details = h('div', { class: 'evidence-details', id: regionId, hidden: open.length === 0 },
        open.map((id) => {
            const item = ctx.find(id);
            if (!item) return h('p', { class: 'meta', text: `${id} is not in the evidence log.` });
            return h('div', { class: 'evidence-detail' },
                h('p', null, idChip(id, ctx.act.navigate), ' ', mdInline(ctx, item.claim, { doc: 'research' })),
                h('div', { class: 'evidence-meta' },
                    evidenceSource(ctx, item),
                    h('span', { class: 'evidence-facts' },
                        item.confidence ? badge(confidenceMeta(item.confidence), { prefix: 'Confidence', strong: true }) : null,
                        item.retrieved ? h('span', { class: 'meta', text: `Retrieved ${item.retrieved}` }) : null)));
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

/** The choice that answers in the person's own words; it is never one of the decision's options. */
export const OWN_ANSWER = 'your-own';

function optionList(ctx, decision, name, selected, onChange, exclude, own = null) {
    const ownId = `${name}-${OWN_ANSWER}`;
    const ownChoice = own ? h('label', { class: ['option', 'option-own', selected === OWN_ANSWER ? 'is-selected' : null], for: ownId },
        h('input', { type: 'radio', name, id: ownId, value: OWN_ANSWER, checked: selected === OWN_ANSWER, onchange: () => onChange(OWN_ANSWER) }),
        h('span', { class: 'option-body' }, h('span', { class: 'option-label', text: own.label }), h('span', { class: 'option-consequence', text: own.hint }))) : null;
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
        }),
        ownChoice);
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
    // In an earlier document, a decision shows what was decided, without answering or overriding.
    if (ctx.readOnly) {
        parts.push(
            decision.question && decision.question !== decision.title ? h('p', { class: 'card-question', text: decision.question }) : null,
            chosen ? h('p', { class: 'resolved-line' }, icon('check', { className: 'tone-success-fg' }), h('span', null, 'Chosen: ', h('strong', { text: chosen.label }))) : null,
            decision.rationale ? h('p', null, mdInline(ctx, decision.rationale, { doc: decision.phase })) : null,
            evidence);
        return withLabel(h('article', { class: ['card', 'decision', `is-${decision.status}`], id: `card-${decision.id}`, dataset: { item: decision.id }, tabindex: '-1' }, parts.filter(Boolean)), decision);
    }

    if (decision.status === 'needs-input') {
        const name = `decision-${decision.id}`;
        const noteId = `${name}-note`;
        const hasOptions = decision.options.length > 0;
        const ownWords = !hasOptions || draft.optionId === OWN_ANSWER;
        parts.push(
            decision.question && decision.question !== decision.title ? h('p', { class: 'card-question', text: decision.question }) : null,
            decision.context ? h('div', { class: 'card-context prose' }, md(ctx, decision.context)) : null,
            hasOptions ? optionList(ctx, decision, name, draft.optionId, (optionId) => update({ optionId }), undefined, { label: 'Your own answer', hint: 'Write it in the box below.' }) : null,
            evidence,
            decision.impact ? h('p', { class: 'card-impact' }, icon('arrow-right'), h('span', null, h('strong', { text: 'If you answer: ' }), mdInline(ctx, decision.impact, { doc: decision.phase }))) : null,
            h('label', { class: 'field-label', for: noteId, text: ownWords ? 'Your answer' : 'Add a note (optional)' }),
            h('textarea', { id: noteId, class: 'note', rows: ownWords ? '3' : '2', 'aria-required': ownWords ? 'true' : undefined, oninput: (event) => update({ note: event.target.value }) }, draft.note),
            h('div', { class: 'btn-row' },
                button('Answer', { kind: 'primary', iconName: 'check', disabled: ownWords ? !draft.note.trim() : !draft.optionId, attrs: { 'data-key': submitKey, 'data-needs-text': ownWords ? 'true' : undefined }, onClick: () => ctx.act.answer(decision.id, 'answer', ownWords ? { optionId: null, note: current().note } : current()) }),
                h('span', { class: 'meta', text: 'Waits in Review and send' })));
    } else if (decision.status === 'decided' || decision.status === 'override-pending') {
        const overriding = ctx.ui.overrides.has(decision.id);
        const pending = decision.status === 'override-pending' ? feedback : null;
        // While an override waits, the agent's own choice stays on the card above it.
        const agentChoice = pending?.previousChosen !== undefined && pending?.previousChosen !== null ? decision.options.find((option) => option.id === pending.previousChosen) : chosen;
        const said = [
            agentChoice && agentChoice.label !== decision.title ? h('p', null, h('strong', { text: agentChoice.label })) : null,
            decision.rationale ? h('p', null, mdInline(ctx, decision.rationale, { doc: decision.phase })) : null,
        ].filter(Boolean);
        parts.push(said.length ? voice('agent', 'Agent decided', said) : null, evidence);
        const alternatives = decision.options.filter((option) => option.id !== agentChoice?.id);
        if (pending) {
            parts.push(readBack(ctx, decision, pending, 'Your override'));
        } else if (overriding) {
            const name = `override-${decision.id}`;
            const noteId = `${name}-note`;
            const ownWords = alternatives.length === 0 || draft.optionId === OWN_ANSWER;
            parts.push(
                alternatives.length ? h('p', { class: 'card-question', text: 'Choose a different option, or say what to do instead:' }) : null,
                alternatives.length ? optionList(ctx, decision, name, draft.optionId === decision.chosen ? null : draft.optionId, (optionId) => update({ optionId }), decision.chosen, { label: 'Something else', hint: 'Say what the agent should do instead in the box below.' }) : null,
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
        parts.push(h('p', { class: 'resolved-line' }, icon('check', { className: 'tone-success-fg' }), h('span', null, outcome ? ['Resolved: ', h('strong', { text: outcome })] : 'Resolved', decision.impact ? [' · ', mdInline(ctx, decision.impact, { doc: decision.phase })] : '')),
            history ? disclosure(ctx, `history-${decision.id}`, 'history', 'How this was decided', history) : null,
            feedback && (feedback.state === 'applied' || feedback.state === 'interpreted') ? readBackActions(ctx, feedback, 'card') : null);
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
        const words = feedback.state === 'queued'
            ? queuedForAgent(feedback) ? 'Queued for the agent. It collects this at its next checkpoint.' : 'Not sent yet. It goes to the agent when you send or queue it with Review and send.'
            : feedback.pickedUpAt ? 'The agent has it and will read back how it understood this.' : 'Sent. The agent will read back how it understood this.';
        parts.push(h('p', { class: 'waiting meta' }, icon(stageOf(ctx, feedback).badge.icon), words));
        if (feedback.state === 'queued') {
            const overriding = (origin ?? feedback).kind === 'override';
            parts.push(h('div', { class: 'btn-row' }, button(overriding ? 'Edit override' : 'Edit answer', { iconName: 'pencil', onClick: () => ctx.act.editAnswer(decision.id, feedback, origin) })));
        }
    }
    if (!options.compact && (feedback.state === 'interpreted' || feedback.state === 'applied')) {
        parts.push(readBackActions(ctx, feedback, 'card'));
    }
    return h('div', { class: 'readback' }, parts);
}

/** A comment or other feedback shown in a row margin. */
export function marginNote(ctx, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    return h('article', { class: ['card', 'note-card'], dataset: { item: item.id } },
        h('header', { class: 'card-head' }, icon(kind.icon, { className: 'card-icon' }), h('span', { class: 'id-chip', text: item.id }), h('h4', { class: 'card-title', text: kind.label }), badge(FEEDBACK_STATE[item.state])),
        item.target?.quote ? h('blockquote', { class: 'note-quote' }, item.target.part ? h('span', { class: 'note-part', text: `${item.target.part.charAt(0).toUpperCase()}${item.target.part.slice(1)}` }) : null, h('span', { text: item.target.quote })) : null,
        voice('user', 'You', h('p', { text: item.text }), { meta: null }),
        item.interpretation ? voice('agent', 'Agent understood', [h('p', { text: item.interpretation.text }), item.interpretation.effect ? h('p', { class: 'effect' }, icon('arrow-right'), item.interpretation.effect) : null], { reveal: ctx.ui.revealed.has(item.id) }) : null,
        item.state === 'interpreted' || item.state === 'applied' ? readBackActions(ctx, item, 'card') : null,
        item.createdAt ? h('p', { class: 'meta' }, timeEl(item.createdAt, ctx.now)) : null);
}

/**
 * Correct this, for an item the agent read back, or the prefilled correction field when it is
 * open here. A correction is a new item that names the one it corrects and waits to be sent.
 *
 * @param {any} ctx
 * @param {any} item feedback item the agent read back
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
        button('Correct this', { iconName: 'undo', title: `Tell the agent what you meant by ${item.id}; the correction waits in Review and send`, attrs: { 'data-key': `correct-${where}-${item.id}` }, onClick: () => ctx.act.toggleCorrection(item.id, item.text ?? '', where) }));
}

/** Simple accessible table inside a scrollable well. */
export function table(caption, headers, rows, options = {}) {
    return h('div', { class: 'table-well', tabindex: '0', role: 'region', 'aria-label': `${caption} table` },
        h('table', { class: ['data-table', options.className] },
            h('caption', { class: 'visually-hidden', text: caption }),
            h('thead', null, h('tr', null, headers.map((header) => h('th', { scope: 'col', text: header })))),
            h('tbody', null, rows.map((cells) => h('tr', null, cells.map((cell) => h('td', null, cell)))))));
}

/** Matches the model's claim window: a send holds its items for up to 10 minutes. */
const isSending = (ctx, item) => item.state === 'queued' && Boolean(item.deliveringSince) && ctx.now - Date.parse(item.deliveringSince) < 10 * 60 * 1000;
const SENDING = Object.freeze({ icon: 'send', label: 'Sending', tone: 'accent' });
const QUEUED = Object.freeze({ icon: 'clock', label: 'Queued for the agent', tone: 'agent' });
const HAS_IT = Object.freeze({ icon: 'sparkle', label: 'The agent has it', tone: 'agent' });
const DELIVERY_WORDS = Object.freeze({ send: 'as a chat message', queue: 'collected by the agent', attach: 'attached to a message' });
const PICKUP_WORDS = Object.freeze({ steering: 'at its next step', idle: 'in a new turn', queued: 'after its turn', collected: 'collected from the canvas' });

/**
 * Where an item is and since when: its badge, the time it got there, and a few words on how.
 * Not sent, Queued for the agent, Sent, The agent has it, then Read back, Corrected, or Removed.
 *
 * @param {any} ctx
 * @param {any} item
 * @returns {{ badge: { icon: string, label: string, tone: string }, at: string | null, words: string | null }}
 */
export function stageOf(ctx, item) {
    if (isSending(ctx, item)) return { badge: SENDING, at: item.deliveringSince, words: null };
    if (item.state === 'queued') {
        return queuedForAgent(item)
            ? { badge: QUEUED, at: item.queuedForAgentAt ?? null, words: "for the agent's next checkpoint" }
            : { badge: FEEDBACK_STATE.queued, at: item.updatedAt ?? item.createdAt ?? null, words: null };
    }
    if (item.state === 'sent') {
        return item.pickedUpAt
            ? { badge: HAS_IT, at: item.pickedUpAt, words: PICKUP_WORDS[item.pickedUpHow] ?? null }
            : { badge: FEEDBACK_STATE.sent, at: item.sentAt ?? item.updatedAt ?? null, words: DELIVERY_WORDS[item.delivery] ?? null };
    }
    if (item.state === 'interpreted') return { badge: FEEDBACK_STATE.interpreted, at: item.interpretation?.at ?? item.updatedAt ?? null, words: 'the change is not made yet' };
    if (item.state === 'corrected') {
        const follow = ctx.data.session.feedback.find((entry) => entry.correctionOf === item.id);
        return { badge: FEEDBACK_STATE.corrected, at: item.updatedAt ?? null, words: follow ? `your correction is ${follow.id}` : null };
    }
    return { badge: FEEDBACK_STATE[item.state] ?? FEEDBACK_STATE.queued, at: item.updatedAt ?? item.createdAt ?? null, words: null };
}

/** What a feedback item is about, as the steering panel and the send dialog name it. */
function feedbackTarget(ctx, item) {
    if (!item.target) return null;
    const decision = item.target.type === 'decision' ? ctx.data.session.decisions.find((candidate) => candidate.id === item.target.id) : null;
    // A namespaced decision such as plan.D1 shows its artifact ID and phase.
    const scoped = decision?.ref && decision.ref !== decision.id ? { label: decision.ref } : {};
    const section = item.target.type === 'section' ? ctx.data.session.sections[item.target.id] : null;
    if (section) {
        return h('span', null, ' to ', h('strong', { text: section.title }), ` in ${PHASE_META[section.doc]?.label ?? section.doc}`, item.target.part ? `, ${item.target.part}` : null);
    }
    // A plain ID names its phase in parentheses, as other loops' items do in Review and send.
    const phase = scoped.label ? null : PHASE_META[item.target.phase]?.label ?? null;
    return h('span', null, ' about ', ctx.resolve(item.target.id) ? idChip(item.target.id, ctx.act.navigate, scoped) : h('span', { class: 'id-chip', text: scoped.label ?? item.target.id }), scoped.label ? ` in ${PHASE_META[decision.phase]?.label ?? decision.phase}` : null, phase ? ` (${phase})` : null, item.target.part ? `, ${item.target.part}` : null);
}

/** Matches EDITABLE_KINDS in lib/model.mjs: kinds whose words change here; the rest change where they were made. */
const EDITABLE_KINDS = new Set(['comment', 'context', 'research-request', 'task-request', 'correction', 'answer', 'override']);

/** A second press within this time is a double click, not a decision. */
export const CONFIRM_GUARD_MS = 500;

/**
 * What a press on a second-press button does: the first press arms it, a press inside the guard
 * after arming is ignored, and a later press confirms.
 *
 * @param {{ key: string, at: number } | null | undefined} armed The button armed now, if any.
 * @param {string} key The pressed button's key.
 * @param {number} now The press time in milliseconds.
 * @returns {'arm' | 'ignore' | 'confirm'}
 */
export function confirmPress(armed, key, now) {
    if (armed?.key !== key) return 'arm';
    return now - armed.at < CONFIRM_GUARD_MS ? 'ignore' : 'confirm';
}

/**
 * A button that acts on a deliberate second press. The first press arms it: it becomes a
 * question that names what goes, in the danger tone, and keeps focus. The app ignores
 * presses for half a second after arming and repeated keys, and disarms it after four
 * seconds, on Escape, or when focus leaves it.
 *
 * @param {any} ctx
 * @param {{ key: string, label: string, armedLabel: string, hideLabel?: boolean, onConfirm: () => unknown }} options
 */
export function confirmButton(ctx, { key, label, armedLabel, hideLabel = false, onConfirm }) {
    const armed = ctx.ui.confirm?.key === key;
    const compact = hideLabel && !armed;
    return h('button', {
        type: 'button',
        class: ['btn', 'btn-confirm', armed ? 'is-armed' : null, compact ? 'btn-icon' : null],
        dataset: { key },
        title: compact ? label : undefined,
        onclick: () => ctx.act.pressConfirm(key, onConfirm, armedLabel),
        onkeydown: (event) => {
            if (event.repeat && (event.key === 'Enter' || event.key === ' ')) {
                event.preventDefault();
            } else if (event.key === 'Escape' && armed) {
                event.preventDefault();
                event.stopPropagation();
                ctx.act.disarmConfirm(key);
            }
        },
        onblur: () => {
            if (armed) ctx.act.confirmBlurred(key);
        },
    }, icon('trash'), compact ? sr(label) : h('span', { text: armed ? armedLabel : label }));
}

/** Where an item is edited inline: the Review and send dialog or Your feedback. */
const editingHere = (ctx, where, taskId, item) => {
    const edit = ctx.ui.feedbackEdit;
    return Boolean(edit) && edit.where === where && edit.taskId === taskId && edit.id === item.id;
};

/** The inline editor for an unsent item's words, with Save and Cancel. */
function feedbackEditor(ctx, where, taskId, item) {
    const edit = ctx.ui.feedbackEdit;
    const base = `${where === 'dialog' ? 'review' : 'fb'}-edit-${taskId}-${item.id}`;
    const fieldId = `${base}-text`;
    const withOption = (item.kind === 'answer' || item.kind === 'override') && Boolean(item.optionLabel);
    return h('div', { class: 'fb-editor' },
        h('label', { class: 'field-label', for: fieldId, text: withOption ? `Why, for ${item.id} (optional)` : `Words of ${item.id}` }),
        h('textarea', { id: fieldId, class: 'note', rows: '3', 'aria-invalid': edit.error ? 'true' : undefined, 'aria-describedby': edit.error ? `${base}-error` : undefined, oninput: (event) => ctx.act.setFeedbackDraft(event.target.value) }, edit.text),
        edit.error ? h('p', { class: 'field-error', id: `${base}-error` }, icon('alert'), h('span', { text: `Not saved: ${edit.error} Your words are kept.` })) : null,
        h('div', { class: 'btn-row' },
            button(edit.saving ? 'Saving' : 'Save', { kind: 'primary', iconName: 'check', disabled: edit.saving, attrs: { 'data-key': `${base}-save` }, onClick: () => ctx.act.saveFeedbackEdit() }),
            button('Cancel', { attrs: { 'data-key': `${base}-cancel` }, onClick: () => ctx.act.cancelFeedbackEdit() })));
}

/**
 * Go to, Edit, and Discard for an item: Go to when it is about something in the canvas,
 * Edit and Discard while it has not been sent. `group` is its loop.
 *
 * @param {any} ctx
 * @param {'dialog' | 'steer'} where
 * @param {{ taskId: string, title: string, shown: boolean }} group
 * @param {any} item a feedback item, or another loop's summary of one
 */
export function feedbackActions(ctx, where, group, item) {
    const keyOf = (name) => (where === 'dialog' ? `review-${name}-${group.taskId}-${item.id}` : `fb-${name}-${item.id}`);
    const reachable = Boolean(item.target?.id);
    // Another loop's summaries list only unsent items, so they carry no state.
    const unsent = item.state === undefined || (item.state === 'queued' && !isSending(ctx, item));
    const editable = group.shown ? EDITABLE_KINDS.has(item.kind) : item.editable === true;
    const elsewhere = group.shown ? '' : ` in ${group.title}`;
    const actions = [];
    if (reachable) {
        actions.push(button(`Go to ${item.id}`, { iconName: 'go-to', hideLabel: true, title: `Go to what ${item.id} is about${elsewhere}`, attrs: { 'data-key': keyOf('goto') }, onClick: () => ctx.act.goToFeedback(group.taskId, item) }));
    }
    // A suggested edit changes in its section's editor; a saved item of a kind the canvas no longer creates has nowhere to change.
    if (unsent && (editable || item.kind === 'edit')) {
        actions.push(button(`Edit ${item.id}`, { iconName: 'pencil', hideLabel: true, title: editable ? `Change the words of ${item.id}` : `Edit ${item.id} where you made it${elsewhere}`, attrs: { 'data-key': keyOf('edit') }, onClick: () => (editable ? ctx.act.startFeedbackEdit(where, group.taskId, item) : ctx.act.editInPlace(group.taskId, item)) }));
    }
    if (unsent) {
        actions.push(confirmButton(ctx, { key: keyOf('discard'), label: `Discard ${item.id}`, armedLabel: `Discard ${item.id}?`, hideLabel: true, onConfirm: () => ctx.act.discardFeedback([{ taskId: group.taskId, id: item.id }]) }));
    }
    return actions;
}

function feedbackRow(ctx, item, group) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    const actions = [];
    const sending = isSending(ctx, item);
    const queued = item.state === 'queued' && !sending && queuedForAgent(item);
    const editing = editingHere(ctx, 'steer', group.taskId, item);
    let readBack = null;
    if (queued) {
        actions.push(button('Take back', { iconName: 'undo', title: `Keep ${item.id} here instead of giving it to the agent at its next checkpoint`, attrs: { 'data-key': `take-back-${item.id}` }, onClick: () => ctx.act.takeBack(group.taskId, item) }));
    }
    if (item.state === 'interpreted' || item.state === 'applied') {
        if (item.target?.type === 'decision') {
            actions.push(button('Correct this', { iconName: 'undo', title: `Correct ${item.id} on its decision card; the correction waits in Review and send`, attrs: { 'data-key': `correct-row-${item.id}` }, onClick: () => ctx.act.openDecisionCorrection(item) }));
        } else {
            readBack = readBackActions(ctx, item, 'row');
        }
    }
    const stage = stageOf(ctx, item);
    const tools = feedbackActions(ctx, 'steer', group, item);
    return h('li', { class: 'fb-item', dataset: { item: item.id } },
        h('div', { class: 'fb-head' }, icon(kind.icon), h('span', { class: 'fb-kind' }, kind.label, feedbackTarget(ctx, item)), badge(stage.badge), tools.length && !editing ? h('span', { class: 'fb-tools' }, tools) : null),
        item.optionLabel ? h('p', { class: 'fb-text' }, h('strong', { text: item.optionLabel })) : null,
        editing ? feedbackEditor(ctx, 'steer', group.taskId, item) : item.text ? h('p', { class: 'fb-text', text: excerpt(item.text, 160) }) : null,
        item.interpretation ? h('p', { class: 'fb-interp' }, icon('sparkle'), h('span', { text: item.interpretation.text })) : null,
        h('p', { class: 'fb-meta meta' }, h('span', { class: 'id-chip', text: item.id }), ' ', timeEl(stage.at, ctx.now), stage.words ? ` · ${stage.words}` : ''),
        actions.length ? h('div', { class: 'btn-row' }, actions) : null,
        readBack);
}

const excerpt = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

function steerSection(id, title, count, content, options = {}) {
    return h('section', { class: ['steer-section', options.className], 'aria-labelledby': `steer-${id}`, dataset: options.row ? { row: options.row } : undefined, tabindex: options.row ? '-1' : undefined },
        h('h3', { class: 'steer-title', id: `steer-${id}` }, options.iconName ? icon(options.iconName) : null, title, count !== null ? h('span', { class: 'count', text: String(count) }) : null),
        content);
}

/**
 * The steering panel: needs your input, decided by the agent, your feedback, and add input,
 * always in that order.
 *
 * @param {any} ctx
 */
export function steerPanel(ctx) {
    const { session, view } = ctx.data;
    const phaseLabel = (phase) => PHASE_META[phase]?.label ?? phase;
    const decisionOf = (id) => session.decisions.find((decision) => decision.id === id);
    const steerCard = (decision) => h('li', { class: 'steer-card' }, decisionCard(ctx, decision));
    const refOf = (id) => decisionOf(id)?.ref ?? id;
    const needs = h('ul', { class: 'steer-list' },
        view.needsYou.map((item) => (hasMarginHome(ctx, decisionOf(item.id)) ? h('li', null,
            h('button', { type: 'button', class: 'steer-link', dataset: { key: `needs-${item.id}` }, onclick: () => ctx.act.navigate(item.id) },
                icon('hand', { className: 'tone-attention-fg' }), h('span', { class: 'steer-link-text' }, idTag(refOf(item.id), 'go-to'), ' ', item.title), h('span', { class: 'meta', text: phaseLabel(item.phase) }))) : steerCard(decisionOf(item.id)))));
    const needsCount = view.needsYou.length;
    // Recorded decisions show as two counts, the agent's and yours, each going to the first such
    // decision, in the viewed phase when it has one. A decision with no row to sit beside keeps its card.
    const agentDecisions = view.decidedByAgent.map((item) => decisionOf(item.id)).filter(Boolean);
    const yourDecisions = session.decisions.filter((decision) => decision.owner === 'user' && decision.status !== 'needs-input');
    const homeOf = (list) => list.filter((decision) => hasMarginHome(ctx, decision));
    const firstOf = (list) => list.find((decision) => decision.phase === ctx.ui.phase) ?? list[0];
    const countLink = (key, list, iconName, tone, words) => {
        const homed = homeOf(list);
        if (!homed.length) return null;
        const target = firstOf(homed);
        return h('li', null, h('button', { type: 'button', class: 'steer-link', dataset: { key }, title: `Go to ${refOf(target.id)}, the first of them`, onclick: () => ctx.act.navigate(target.id) },
            icon(iconName, { className: `tone-${tone}-fg` }), h('span', { class: 'steer-link-text', text: words(homed.length) }), idTag(refOf(target.id), 'go-to')));
    };
    const homeless = agentDecisions.filter((decision) => !hasMarginHome(ctx, decision));
    // The count matches what the section lists: both counts, plus the agent's cards.
    const decidedCount = agentDecisions.length + homeOf(yourDecisions).length;
    const decided = h('ul', { class: 'steer-list' },
        countLink('decided-agent', agentDecisions, 'sparkle', 'agent', (count) => `${plural(count, 'decision')} the agent recorded`),
        countLink('decided-yours', yourDecisions, 'person', 'user', (count) => `${plural(count, 'decision')} you made`),
        homeless.map((decision) => steerCard(decision)));

    const pending = pendingItems(ctx);
    const agentQueue = agentQueueItems(ctx);
    const inFlight = session.feedback.filter((item) => item.state === 'sent' || item.state === 'interpreted' || isSending(ctx, item));
    const earlier = session.feedback.filter((item) => ['applied', 'corrected', 'dismissed'].includes(item.state));
    const loop = { taskId: session.task.id, title: session.task.title, shown: true };
    const feedback = h('div', null,
        pending.length
            ? [h('h4', { class: 'group-title', text: `Not sent yet (${pending.length})` }), h('ul', { class: 'fb-list' }, pending.map((item) => feedbackRow(ctx, item, loop)))]
            : h('p', { class: 'empty', text: agentQueue.length ? 'Nothing waits for you to send. What you queued is below.' : 'Nothing waiting to send. Your answers, comments, and suggested edits collect here until you send or queue them with Review and send at the top of the canvas.' }),
        agentQueue.length ? [h('h4', { class: 'group-title', text: `Queued for the agent (${agentQueue.length})` }), h('p', { class: 'meta group-hint', text: 'The agent collects these at its next checkpoint: when it changes phase, finishes a task, asks you something, or ends its turn.' }), h('ul', { class: 'fb-list' }, agentQueue.map((item) => feedbackRow(ctx, item, loop)))] : null,
        inFlight.length ? [h('h4', { class: 'group-title', text: `With the agent (${inFlight.length})` }), h('ul', { class: 'fb-list' }, inFlight.map((item) => feedbackRow(ctx, item, loop)))] : null,
        earlier.length ? disclosure(ctx, 'earlier-feedback', 'earlier', `Feedback history (${earlier.length})`, h('ul', { class: 'fb-list' }, earlier.slice().reverse().map((item) => feedbackRow(ctx, item, loop)))) : null);

    return [
        steerSection('needs', 'Needs your input', needsCount, needsCount ? needs : h('p', { class: 'empty', text: 'Nothing needs you right now. Decisions the agent asks you about appear here.' }), { iconName: 'hand', className: needsCount ? 'has-items' : null }),
        steerSection('decided', 'Recorded decisions', decidedCount, decidedCount ? decided : h('p', { class: 'empty', text: 'No recorded decisions yet.' }), { iconName: 'sparkle' }),
        steerSection('feedback', 'Your feedback', pending.length + agentQueue.length + inFlight.length, feedback, { iconName: 'inbox' }),
        steerSection('add', 'Add input', null, composer(ctx), { iconName: 'plus' }),
    ].filter(Boolean);
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
        ? h('div', { class: 'anchor-box' },
            h('p', { class: 'anchor-chip' }, icon('anchor'), 'About ', h('span', { class: 'id-chip', text: state.anchor }), (anchor?.title ?? state.title) ? h('span', { class: 'anchor-title', title: anchor?.title ?? state.title, text: ` ${anchor?.title ?? state.title}` }) : null,
                state.part ? h('span', { class: 'anchor-part', text: `, ${state.part}` }) : null,
                button('Remove anchor', { iconName: 'x', hideLabel: true, attrs: { 'data-key': 'remove-anchor' }, onClick: () => ctx.act.setComposer({ anchor: null }) })),
            state.quote ? h('blockquote', { class: 'anchor-quote' }, sr('Quote: '), state.quote) : null)
        : h('p', { class: 'meta', text: 'Tip: hover a paragraph, list item, or table row and choose its comment button, or right-click it, to anchor your input to that part.' }),
    h('label', { class: 'visually-hidden', for: textId, text: 'Your input' }),
    h('textarea', { id: textId, class: 'note', rows: '3', placeholder, 'aria-invalid': state.error ? 'true' : undefined, 'aria-describedby': state.error ? 'composer-error' : undefined, oninput: (event) => ctx.act.setComposer({ text: event.target.value }, false) }, state.text),
    state.error ? h('p', { class: 'field-error', id: 'composer-error' }, icon('alert'), h('span', { text: `Not added: ${state.error} Your text is kept.` })) : null,
    h('div', { class: 'btn-row' }, h('button', { type: 'submit', class: 'btn btn-primary', disabled: !state.text.trim(), dataset: { key: 'composer-submit' } }, icon('plus'), h('span', { text: { comment: 'Add comment', context: 'Add context', 'research-request': 'Add research request' }[state.kind] ?? 'Add' }))),
    h('p', { class: 'meta', text: 'What you add waits in Your feedback until you send or queue it with Review and send.' }));
}

/**
 * Content of the Review and send dialog: every loop's unsent items under their loop, each
 * with Go to, Edit, and Discard, then an optional message, the exact text, Send, Discard
 * all, and Close. With nothing waiting it explains how to add something instead.
 *
 * @param {any} ctx
 */
export function reviewSheet(ctx) {
    const groups = sessionPending(ctx);
    const pending = groups.flatMap((group) => group.items);
    const send = ctx.ui.send;
    const handle = ctx.data.canvas?.handle;
    const rpi = ctx.data.session.source?.kind === 'rpi';
    const head = h('div', { class: 'dialog-head' },
        h('h2', { id: 'sendSheetTitle', tabindex: '-1' }, icon('send'), 'Review and send'),
        h('button', { type: 'button', class: 'icon-btn', 'data-close': '', dataset: { key: 'send-close' } }, icon('x'), sr('Close')));
    const from = handle ? ['Canvas ', h('code', { class: 'canvas-handle', text: handle })] : ['This canvas'];
    if (!pending.length) {
        return [head,
            h('p', { class: 'send-intro' }, ...from, ' has nothing waiting to send.'),
            h('p', { text: 'Add something first, then review and send it all here:' }),
            h('ul', { class: 'send-howto' },
                h('li', { text: 'Answer a decision the agent asks you, or override one it made.' }),
                h('li', { text: 'Comment on a row, or suggest an edit to its text.' }),
                h('li', { text: 'Add context or a research request under Add input.' })),
            h('div', { class: 'btn-row' }, button('Close', { attrs: { 'data-close': '', 'data-key': 'send-cancel' } }))];
    }
    const noun = plural(pending.length, 'item');
    const loops = groups.length;
    const fresh = pending.filter((item) => !queuedForAgent(item)).length;
    const busy = send.sending ? send.busy ?? 'send' : null;
    const them = (count) => (count === 1 ? 'it' : 'them');
    return [head,
        h('p', { class: 'send-intro' }, ...from, ` has ${pending.length === 1 ? 'this item' : `these ${pending.length} items`}${loops > 1 ? ` from ${loops} loops of this session` : ''} for the agent. Check each one: go to it, change its words, or discard it. The agent ${rpi ? (loops > 1 ? "changes each loop's files" : "changes the task's files") : 'makes the changes'} and reads back how it understood each item.`),
        ...groups.map((group) => reviewGroup(ctx, group)),
        h('label', { class: 'field-label', for: 'send-note', text: 'Message to the agent (optional)' }),
        h('textarea', { id: 'send-note', class: 'note', rows: '3', 'aria-describedby': 'send-note-hint', oninput: (event) => ctx.act.setSendNote(event.target.value) }, send.note),
        h('p', { class: 'meta', id: 'send-note-hint', text: 'With Send now, it shows in the chat above the line that names this canvas. With Queue, it waits with your items as context.' }),
        h('details', { class: 'send-exact' },
            h('summary', { text: 'Exact message Send now delivers' }),
            h('pre', { class: 'preview-text', id: 'send-preview', tabindex: '0', text: send.preview?.prompt ?? 'Preparing the message…' })),
        send.error ? h('div', { class: 'notice tone-danger', role: 'alert', id: 'send-error' }, h('p', { class: 'notice-title' }, icon('alert'), send.error)) : null,
        h('ul', { class: 'send-modes', id: 'send-modes' },
            h('li', null, icon('send'), h('span', null, h('strong', { text: 'Send now' }), ` gives ${them(pending.length)} to the agent at its next step, even mid-task, as one chat message that starts with “RPI canvas${handle ? ` ${handle}` : ''}”.`)),
            h('li', null, icon('clock'), h('span', null, h('strong', { text: 'Queue' }), fresh
                ? ` keeps ${fresh === pending.length ? them(fresh) : `the ${plural(fresh, 'item')} not queued yet`} here until the agent's next checkpoint: when it changes phase, finishes a task, asks you something, or ends its turn. You can take ${them(fresh)} back until then.`
                : ' is done: everything here waits for the agent\'s next checkpoint. Send now gives it to the agent sooner.'))),
        h('div', { class: 'btn-row send-actions' },
            button(busy === 'send' ? 'Sending' : 'Send now', { kind: 'primary', iconName: 'send', disabled: send.sending || !send.preview, attrs: { 'data-key': 'send-confirm', id: 'send-confirm', 'aria-describedby': 'send-modes' }, onClick: () => ctx.act.send('send') }),
            fresh ? button(busy === 'queue' ? 'Queueing' : 'Queue', { iconName: 'clock', disabled: send.sending || !send.preview, attrs: { 'data-key': 'send-queue', id: 'send-queue', 'aria-describedby': 'send-modes' }, onClick: () => ctx.act.send('queue') }) : null,
            confirmButton(ctx, { key: 'send-discard-all', label: 'Discard all', armedLabel: loops > 1 ? `Discard all ${noun} from ${loops} loops?` : `Discard all ${noun}?`, onConfirm: () => ctx.act.discardAll() }),
            button('Close', { attrs: { 'data-close': '', 'data-key': 'send-cancel' } }))].filter(Boolean);
}

/** One loop's items in Review and send, headed by the loop's title, status, and ID. */
function reviewGroup(ctx, group) {
    const headingId = `send-group-${group.taskId}`;
    return h('section', { class: 'send-group', 'aria-labelledby': headingId },
        h('h3', { class: 'send-group-title', id: headingId, tabindex: '-1' },
            h('span', { class: 'send-group-name', text: group.title }),
            group.shown ? h('span', { class: 'badge tone-accent' }, icon('eye'), 'Shown') : null,
            badge(known(TASK_STATUS, group.status))),
        h('p', { class: 'meta send-group-meta' }, h('code', { text: group.taskId }), group.status === 'completed' ? ' · This loop is completed, so these items go to the agent as follow-up work for the session.' : ''),
        h('ul', { class: 'send-list', 'aria-label': `Items for ${group.title}` }, group.items.map((item) => reviewRow(ctx, group, item))));
}

/** One unsent item: its ID, kind, what it is about, its words, and Go to, Edit, and Discard. */
function reviewRow(ctx, group, item) {
    const kind = FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment;
    const editing = editingHere(ctx, 'dialog', group.taskId, item);
    const about = group.shown ? feedbackTarget(ctx, item) : item.about ? h('span', null, ` about ${item.about}`) : null;
    const lines = item.kind === 'edit' && Number.isFinite(item.section?.added) ? `${plural(item.section.added, 'line')} added, ${item.section.removed} removed` : null;
    return h('li', { class: 'send-item', dataset: { reviewItem: `${group.taskId}:${item.id}` } },
        icon(kind.icon, { className: 'send-item-icon' }),
        h('div', { class: 'send-item-text' },
            h('p', { class: 'send-item-kind' }, h('span', { class: 'id-chip', text: item.id }), ' ', kind.label, about, queuedForAgent(item) ? [' ', badge(QUEUED)] : null),
            item.optionLabel ? h('p', { class: 'send-item-option' }, h('strong', { text: item.optionLabel })) : null,
            editing ? feedbackEditor(ctx, 'dialog', group.taskId, item) : item.text ? h('p', { class: 'send-item-words', text: item.text }) : null,
            lines ? h('p', { class: 'meta', text: lines }) : null),
        editing ? null : h('div', { class: 'send-item-actions' }, feedbackActions(ctx, 'dialog', group, item)));
}

/**
 * File preview sheet content with a symbol-marked diff and file actions.
 *
 * @param {any} ctx
 * @param {any} change
 * @param {any} file
 */
export function filePreview(ctx, change, file) {
    const real = ctx.data.session.source?.kind === 'rpi';
    const editor = real ? ctx.data.editor ?? null : null;
    const kindTone = { added: 'success', modified: 'accent', deleted: 'danger', renamed: 'muted' }[file.kind] ?? 'muted';
    const counted = Number.isFinite(file.additions) && Number.isFinite(file.deletions);
    const diff = diffView(file.diff, `Changes in ${file.path}`)
        ?? h('p', { class: 'empty', text: counted ? 'No diff was recorded for this file. The changes record lists it with its line counts.' : real ? 'No diff was recorded for this file. Show the file to see its current content.' : 'No diff was recorded for this file.' });
    return [
        h('div', { class: 'dialog-head' },
            h('h2', { id: 'fileSheetTitle', class: 'sheet-title' }, icon('file'), h('code', { text: file.path })),
            h('button', { type: 'button', class: 'icon-btn', 'data-close': '' }, icon('x'), sr('Close'))),
        h('p', { class: 'sheet-meta' }, h('span', { class: ['badge', `tone-${kindTone}`], text: file.kind }), counted ? ` +${file.additions} −${file.deletions}` : '', ' · ', h('span', { class: 'id-chip', text: change.id }), ` ${change.title}`, change.taskId ? [' · ', h('span', { class: 'id-chip', text: change.taskId })] : null),
        diff,
        h('div', { class: 'btn-row' },
            button('Copy path', { iconName: 'copy', onClick: () => ctx.act.copy(file.path) }),
            button('Ask the agent about this change', { iconName: 'message', onClick: () => ctx.act.anchorComposer(change.id, 'comment', true) }),
            real && file.kind !== 'deleted' ? button('Show the file', { iconName: 'file', onClick: () => ctx.act.openSource(file.path, null) }) : null,
            editor && file.kind !== 'deleted' && !/\.code-workspace$/i.test(file.path) ? button(`Open in ${editor.name}`, { iconName: 'file-code', onClick: () => ctx.act.openInEditor(file.path, null) }) : null),
    ];
}

/** Status of a task in the session tree, in words and with an icon. */
export const TASK_STATUS = Object.freeze({
    completed: { icon: 'check-circle', label: 'Completed', tone: 'success' },
    running: { icon: 'active', label: 'Running', tone: 'accent' },
    stopped: { icon: 'pause', label: 'Stopped', tone: 'muted' },
});

/**
 * The session's tasks as nested lists, parent first, in the order the reader built them.
 * The shown task is marked; other tasks, and a parent in another session, offer Show when
 * the canvas reads real tracking files.
 *
 * @param {any} ctx
 * @param {{ label: string, keyPrefix: string, onShow?: (task: any) => void }} options
 */
export function sessionTree(ctx, options) {
    const { tree } = ctx.data.session.followUps;
    const switchable = ctx.data.session.source?.kind === 'rpi';
    const root = h('ol', { class: 'session-tree', 'aria-label': options.label });
    const stack = [root];
    let last = null;
    const show = (task) => (options.onShow ? options.onShow(task) : ctx.act.showTask({ statePath: task.statePath }));
    const agentPath = ctx.data.follow?.agent?.statePath ?? null;
    for (const task of tree.tasks) {
        const depth = Math.max(0, Math.min(task.depth, stack.length));
        while (stack.length > depth + 1) stack.pop();
        if (depth === stack.length && last) {
            const nested = h('ol', { class: 'session-tree-level' });
            last.append(nested);
            stack.push(nested);
        }
        const status = known(TASK_STATUS, task.status) ?? { icon: 'info', label: task.status ?? 'Unknown', tone: 'muted' };
        last = h('li', { class: ['tree-task', task.shown ? 'is-shown' : null], dataset: { task: task.id } },
            task.continues ? h('p', { class: 'tree-continues meta' }, `Continues ${task.continues.title} from another session `,
                switchable ? button('Show', { iconName: 'arrow-right', attrs: { 'aria-label': `Show ${task.continues.title}, from another session`, 'data-key': `${options.keyPrefix}-continues-${task.id}` }, onClick: () => show(task.continues) }) : null) : null,
            h('div', { class: 'tree-card' },
                badge(status),
                h('strong', { class: 'tree-title', text: task.title }),
                h('code', { class: 'tree-id', text: task.id }),
                task.statePath && task.statePath === agentPath ? h('span', { class: 'badge tone-agent tree-agent', title: 'Where the agent works; Follow agent goes here' }, icon('sparkle'), 'Agent') : null,
                task.shown
                    ? h('span', { class: 'badge tone-accent tree-shown' }, icon('eye'), 'Shown')
                    : switchable && task.statePath
                        ? button('Show', { iconName: 'arrow-right', attrs: { 'aria-label': `Show ${task.title}`, 'data-key': `${options.keyPrefix}-show-${task.id}` }, onClick: () => show(task) })
                        : null));
        stack[stack.length - 1].append(last);
    }
    return root;
}
