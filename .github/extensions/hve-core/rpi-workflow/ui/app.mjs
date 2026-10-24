// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, clear, decisionAlias, h, icon, PHASE_META, PHASE_STATUS, plural, relTime, sr } from './dom.mjs';
import { disclosure, filePreview, hasMarginHome, steerPanel, workspaceEditorUri } from './components.mjs';
import * as followupView from './view-followup.mjs';
import * as implementView from './view-implement.mjs';
import * as planView from './view-plan.mjs';
import * as researchView from './view-research.mjs';
import * as reviewView from './view-review.mjs';

/** RPI Workflow page: data sync, navigation, user actions, and shell rendering. */

const PHASES = ['research', 'plan', 'implement', 'review', 'followup'];
const VIEWS = { research: researchView, plan: planView, implement: implementView, review: reviewView, followup: followupView };
const $ = (id) => document.getElementById(id);

const state = {
    data: null,
    error: null,
    live: 'connecting',
    stream: null,
    pollTimer: null,
    ui: {
        phase: null,
        highlight: null,
        editing: null,
        expanded: new Set(),
        openEvidence: new Set(),
        deliveryMode: 'queue',
        deliveryPreview: null,
        delivering: false,
        composer: { kind: 'comment', text: '', anchor: null },
        decisionDrafts: new Map(),
        corrections: new Map(),
        overrides: new Set(),
        revealed: new Set(),
        selectedTask: null,
        diagramView: 'after',
        diagramPhase: null,
        recordOpen: false,
        openDetails: new Set(),
        navFilter: '',
        shortcuts: true,
        navOpen: true,
        steerOpen: true,
        drawer: null,
    },
};

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

async function api(path, body) {
    const init = body === undefined ? { headers: { accept: 'application/json' } } : { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json' }, body: JSON.stringify(body) };
    const res = await fetch(path, init);
    const json = await res.json().catch(() => null);
    if (!res.ok) {
        const error = new Error(json?.error?.message ?? `Request failed (${res.status}).`);
        error.code = json?.error?.code;
        error.detail = json?.error;
        throw error;
    }
    return json;
}

function announce(text) {
    const region = $('announcer');
    region.textContent = '';
    window.setTimeout(() => {
        region.textContent = text;
    }, 40);
}

// Lookup and navigation

/** The ID a reference means in the viewed phase: a bare `D#` names that phase's decision first. */
const aliasOf = (id) => decisionAlias(state.data?.session, id, state.ui.phase);

function find(ref) {
    const session = state.data?.session;
    if (!session || typeof ref !== 'string') return null;
    const id = aliasOf(ref);
    const pools = [session.research.questions, session.research.findings, session.research.evidence, session.research.lanes, session.decisions, session.plan.requirements, session.plan.critique?.findings ?? [], session.implementation.changes, session.implementation.discoveries, session.implementation.alignment, session.review.findings, session.review.history, session.followUps.items, session.feedback];
    for (const pool of pools) {
        const found = pool.find((item) => item?.id === id);
        if (found) return found;
    }
    for (const phase of session.plan.phases) {
        if (phase.id === id) return phase;
        const task = phase.tasks.find((t) => t.id === id);
        if (task) return task;
    }
    return Object.prototype.hasOwnProperty.call(session.sections, id) ? session.sections[id] : null;
}

function resolve(ref) {
    const item = find(ref);
    if (!item) return null;
    const id = aliasOf(ref);
    if (/^[QFCWL]\d{1,2}$/.test(id)) return { phase: 'research' };
    if (/^(?:plan\.)?D\d{1,3}$/.test(id)) return hasMarginHome(context(), item) ? { phase: item.anchor.phase } : { phase: state.ui.phase };
    if (/^P\d{2}(-T\d{2})?$/.test(id)) return { phase: state.ui.phase === 'implement' && /-T/.test(id) ? 'implement' : 'plan' };
    if (/^(FR|NFR|PC)-\d{3}$/.test(id)) return { phase: 'plan' };
    if (/^(CH|DS|AL)-\d{3}$/.test(id)) return { phase: 'implement' };
    if (/^(RV|RD)-\d{3}$/.test(id)) return { phase: 'review' };
    if (/^FU-\d+$/.test(id)) return { phase: 'followup' };
    if (/^FB-\d{3}$/.test(id)) return item.target ? resolve(item.target.id) : null;
    if (item.doc) return { phase: item.doc };
    return null;
}

function setHash() {
    history.replaceState(null, '', `#phase=${state.ui.phase}`);
}

function phaseFromHash() {
    const match = /phase=([a-z]+)/.exec(location.hash);
    return match && PHASES.includes(match[1]) ? match[1] : null;
}

function setPhase(phase) {
    if (!PHASES.includes(phase)) return;
    state.ui.phase = phase;
    state.ui.highlight = null;
    state.ui.navFilter = '';
    $('navFilter').value = '';
    setHash();
    render();
    $('document').scrollTop = 0;
}

/** True when the open editor's draft differs from the stored section. */
function editChanged(editing) {
    return Boolean(editing) && editing.draft !== (state.data?.session.sections[editing.sectionId]?.markdown ?? editing.draft);
}

/** Shows and focuses the open editor, switching to its phase when needed. */
function focusEditor(sectionId) {
    const section = state.data.session.sections[sectionId];
    if (section?.doc && PHASES.includes(section.doc) && state.ui.phase !== section.doc) setPhase(section.doc);
    window.requestAnimationFrame(() => {
        const area = $(`edit-${sectionId}`);
        area?.scrollIntoView({ block: 'center', behavior: reducedMotion() ? 'auto' : 'smooth' });
        area?.focus({ preventScroll: true });
    });
}

function targetElement(id) {
    const escaped = CSS.escape(id);
    return document.querySelector(`[data-item="${escaped}"]`) ?? document.querySelector(`[data-row="${escaped}"]`);
}

function navigate(ref, phaseOverride, options = {}) {
    const id = aliasOf(ref);
    const target = resolve(id);
    const phase = phaseOverride ?? target?.phase ?? state.ui.phase;
    if (/^[CW]\d{1,2}$/.test(id)) state.ui.recordOpen = true;
    if (/^P\d{2}-T\d{2}$/.test(id)) {
        if (phase === 'plan') state.ui.expanded.add(id);
        if (phase === 'implement') state.ui.selectedTask = id;
    }
    closeDrawer(false);
    state.ui.phase = phase;
    state.ui.highlight = id;
    setHash();
    render();
    window.requestAnimationFrame(() => {
        const element = targetElement(id);
        if (!element) {
            announce(`${ref} is not shown in ${PHASE_META[phase].label}.`);
            return;
        }
        if ($('steer').contains(element) && $('steer').inert) openSteer();
        const tall = element.getBoundingClientRect().height > $('document').clientHeight * 0.5;
        element.scrollIntoView({ block: tall ? 'start' : 'center', behavior: reducedMotion() ? 'auto' : 'smooth' });
        element.focus({ preventScroll: true });
        element.classList.add('is-highlight');
        window.setTimeout(() => {
            element.classList.remove('is-highlight');
            if (state.ui.highlight === id) state.ui.highlight = null;
        }, 1200);
        if (options.agent) announce(`The agent pointed you to ${ref}${find(id)?.title ? `, ${find(id).title}` : ''}.`);
    });
}

// Data sync

function announceChanges(previous, next) {
    if (!previous) return;
    const messages = [];
    const before = new Set(previous.view.needsYou.map((item) => item.id));
    for (const item of next.view.needsYou) {
        if (!before.has(item.id)) messages.push(`${item.id} needs your input: ${item.title}.`);
    }
    const interpreted = new Set(previous.view.interpretations);
    for (const id of next.view.interpretations) {
        if (!interpreted.has(id)) {
            state.ui.revealed.add(id);
            messages.push(`The agent read back ${id}. Check that it understood you.`);
        }
    }
    if (previous.session.session.activePhase !== next.session.session.activePhase) {
        messages.push(`The agent moved to ${PHASE_META[next.session.session.activePhase].label}.`);
    }
    if (messages.length) announce(messages.join(' '));
}

/** Page state that belongs to one task, with its starting values. Appearance and panels are page-wide. */
const taskUi = () => ({
    phase: null,
    highlight: null,
    editing: null,
    expanded: new Set(),
    openEvidence: new Set(),
    deliveryPreview: null,
    composer: { kind: 'comment', text: '', anchor: null },
    decisionDrafts: new Map(),
    corrections: new Map(),
    overrides: new Set(),
    revealed: new Set(),
    selectedTask: null,
    diagramView: 'after',
    diagramPhase: null,
    recordOpen: false,
    openDetails: new Set(),
    navFilter: '',
});
const taskStash = new Map();

/**
 * Keeps the current task's drafts, open editor, and scroll position, and restores the next
 * task's. Returns the document scroll position to apply after rendering.
 */
function switchTaskUi(previousId, next) {
    taskStash.set(previousId, { ui: Object.fromEntries(Object.keys(taskUi()).map((key) => [key, state.ui[key]])), scroll: $('document').scrollTop });
    const restored = taskStash.get(next.session.id);
    taskStash.delete(next.session.id);
    Object.assign(state.ui, restored?.ui ?? taskUi(), { highlight: null, revealed: new Set(), navFilter: '' });
    state.ui.phase ??= next.session.session.activePhase;
    $('navFilter').value = '';
    return restored?.scroll ?? 0;
}

async function refresh() {
    try {
        const next = await api('/api/state');
        const previous = state.data;
        const switched = Boolean(previous) && previous.session.id !== next.session.id;
        const scroll = switched ? switchTaskUi(previous.session.id, next) : null;
        state.data = next;
        state.error = null;
        state.ui.phase ??= phaseFromHash() ?? next.session.session.activePhase;
        if (switched) setHash();
        if (state.ui.editing) {
            const section = next.session.sections[state.ui.editing.sectionId];
            if (!section) state.ui.editing = null;
        }
        applyPreferences(next.preferences);
        if (switched) announce(`Showing ${next.session.task.title}, ${PHASE_META[state.ui.phase].label}.`);
        else announceChanges(previous, next);
        render();
        if (switched) $('document').scrollTop = scroll;
        if (state.ui.revealed.size) window.setTimeout(() => state.ui.revealed.clear(), 900);
    } catch (error) {
        state.error = error;
        render();
    }
}

function setLive(live) {
    state.live = live;
    const chip = $('liveChip');
    chip.dataset.state = live;
    $('liveLabel').textContent = { live: 'Live', reconnecting: 'Reconnecting', paused: 'Paused', connecting: 'Connecting' }[live] ?? live;
}

function stopPolling() {
    window.clearInterval(state.pollTimer);
    state.pollTimer = null;
}

function connect() {
    state.stream?.close();
    if (document.visibilityState !== 'visible') {
        setLive('paused');
        return;
    }
    const stream = new EventSource('/api/events');
    state.stream = stream;
    stream.addEventListener('open', () => {
        const wasReconnecting = state.live === 'reconnecting';
        setLive('live');
        stopPolling();
        if (wasReconnecting) announce('Live updates reconnected.');
    });
    stream.addEventListener('revision', (event) => {
        const { revision } = JSON.parse(event.data);
        if (!state.data || revision !== state.data.revision) refresh();
    });
    stream.addEventListener('reload', () => refresh());
    stream.addEventListener('preferences', (event) => applyPreferences(JSON.parse(event.data)));
    stream.addEventListener('focus', (event) => {
        const data = JSON.parse(event.data);
        if (data.itemId) navigate(data.itemId, data.phase ?? undefined, { agent: true });
        else if (data.phase) setPhase(data.phase);
    });
    stream.addEventListener('error', () => {
        if (state.live !== 'reconnecting') {
            setLive('reconnecting');
            announce('Live updates paused; reconnecting.');
        }
        if (!state.pollTimer) state.pollTimer = window.setInterval(refresh, 5000);
    });
}

// User actions

const act = {
    navigate,
    setPhase,
    async answer(decisionId, kind, draft) {
        try {
            await api('/api/feedback', { kind, target: { id: decisionId }, optionId: draft.optionId ?? undefined, text: draft.note?.trim() || undefined });
            state.ui.decisionDrafts.delete(decisionId);
            state.ui.overrides.delete(decisionId);
            announce(`${kind === 'answer' ? 'Answer' : 'Override'} for ${decisionId} queued for the agent.`);
            await refresh();
            targetElement(decisionId)?.focus({ preventScroll: true });
        } catch (error) {
            announce(error.message);
        }
    },
    async transition(id, to, extra = {}) {
        try {
            await api('/api/feedback/transition', { id, to, ...extra });
            state.ui.corrections.delete(id);
            announce(to === 'applied' ? 'Marked as understood.' : to === 'corrected' ? 'Correction queued for the agent.' : to === 'dismissed' ? 'Removed from the queue.' : 'Updated.');
            await refresh();
        } catch (error) {
            announce(error.message);
        }
    },
    /** Takes back a queued answer, override, or correction and reopens it prefilled. */
    async editAnswer(decisionId, feedback, origin) {
        const source = origin ?? feedback;
        state.ui.decisionDrafts.set(decisionId, { optionId: feedback.optionId ?? source.optionId ?? null, note: feedback.text ?? '' });
        if (source.kind === 'override') state.ui.overrides.add(decisionId);
        await act.transition(feedback.id, 'dismissed');
        targetElement(decisionId)?.querySelector('input:checked, textarea')?.focus();
    },
    setDecisionDraft(id, draft) {
        const previous = state.ui.decisionDrafts.get(id);
        state.ui.decisionDrafts.set(id, draft);
        if (previous?.optionId !== draft.optionId) {
            render();
            return;
        }
        // An answer or override in the user's words is ready once it has text.
        const submit = document.querySelector(`[data-key="submit-${CSS.escape(id)}"][data-needs-text="true"]`);
        if (submit) submit.disabled = !draft.note?.trim();
    },
    /** Shows another task of this RPI session: its parent or one of its child loops. */
    async showTask(taskId) {
        const before = state.data?.session.id;
        try {
            await api('/api/task', { taskId });
            await refresh();
            if (state.data.session.id !== before) focusQuietly($('taskTitle'));
        } catch (error) {
            announce(error.message);
        }
    },
    toggleOverride(id) {
        if (state.ui.overrides.has(id)) state.ui.overrides.delete(id);
        else state.ui.overrides.add(id);
        render();
    },
    /** Opens (or closes, with null) the prefilled correction field where the user asked for it. */
    toggleCorrection(id, text, where = 'card') {
        if (text === null) state.ui.corrections.delete(id);
        else state.ui.corrections.set(id, { text: text ?? '', where });
        render();
        if (text !== null) window.requestAnimationFrame(() => $(`${where === 'row' ? 'steer-correct' : 'correct'}-${id}`)?.focus());
    },
    setCorrection(id, text) {
        const open = state.ui.corrections.get(id);
        state.ui.corrections.set(id, { text, where: open?.where ?? 'card' });
    },
    /** Not what I meant on a decision's feedback row corrects it on the decision card. */
    openDecisionCorrection(item) {
        state.ui.corrections.set(item.id, { text: item.text ?? '', where: 'card' });
        navigate(item.target.id);
        window.setTimeout(() => $(`correct-${item.id}`)?.focus(), 60);
    },
    startEdit(sectionId) {
        const section = state.data.session.sections[sectionId];
        if (!section) return;
        const open = state.ui.editing;
        if (open && open.sectionId !== sectionId && editChanged(open)) {
            announce(`Finish or cancel your edit of ${state.data.session.sections[open.sectionId]?.title ?? 'the open section'} first. Your changes are kept.`);
            focusEditor(open.sectionId);
            return;
        }
        state.ui.editing = { sectionId, draft: section.markdown, baseRevision: section.revision, mode: 'write', conflict: null, compare: false, saving: false };
        render();
        window.requestAnimationFrame(() => $(`edit-${sectionId}`)?.focus());
    },
    setDraft(text) {
        state.ui.editing.draft = text;
    },
    setEditMode(mode) {
        state.ui.editing.mode = mode;
        render();
        window.requestAnimationFrame(() => document.querySelector('.edit-tab[aria-selected="true"]')?.focus());
    },
    async saveEdit() {
        const editing = state.ui.editing;
        editing.saving = true;
        render();
        try {
            await api('/api/section', { sectionId: editing.sectionId, markdown: editing.draft, baseRevision: editing.baseRevision });
            state.ui.editing = null;
            announce('Saved. Your edit is queued so the agent sees it.');
            await refresh();
            targetElement(state.data.session.sections[editing.sectionId]?.id)?.focus({ preventScroll: true });
        } catch (error) {
            editing.saving = false;
            if (error.code === 'conflict') {
                editing.conflict = error.detail.section;
                render();
                announce('The agent changed this section while you were editing. Choose which version to keep.');
                window.requestAnimationFrame(() => $(`conflict-${editing.sectionId}`)?.focus());
            } else {
                render();
                announce(error.message);
            }
        }
    },
    keepMine() {
        const editing = state.ui.editing;
        editing.baseRevision = editing.conflict.revision;
        editing.conflict = null;
        editing.compare = false;
        act.saveEdit();
    },
    useTheirs() {
        state.ui.editing = null;
        announce("Kept the agent's version.");
        refresh();
    },
    toggleCompare() {
        state.ui.editing.compare = !state.ui.editing.compare;
        render();
    },
    cancelEdit() {
        const sectionId = state.ui.editing?.sectionId;
        state.ui.editing = null;
        render();
        if (sectionId) targetElement(sectionId)?.focus({ preventScroll: true });
    },
    /** Cancel and Escape ask before discarding typed changes. */
    requestCancelEdit() {
        if (!state.ui.editing) return;
        if (!editChanged(state.ui.editing)) {
            act.cancelEdit();
            return;
        }
        state.ui.editing.confirmDiscard = true;
        render();
        window.requestAnimationFrame(() => document.querySelector('[data-key="keep-editing"]')?.focus());
    },
    keepEditing() {
        if (!state.ui.editing) return;
        state.ui.editing.confirmDiscard = false;
        render();
        focusEditor(state.ui.editing.sectionId);
    },
    toggleEvidence(rowKey, id) {
        const key = `${rowKey}:${id}`;
        if (state.ui.openEvidence.has(key)) state.ui.openEvidence.delete(key);
        else state.ui.openEvidence.add(key);
        render();
    },
    toggleExpanded(id) {
        if (state.ui.expanded.has(id)) state.ui.expanded.delete(id);
        else state.ui.expanded.add(id);
        render();
    },
    selectTask(id) {
        state.ui.selectedTask = state.ui.selectedTask === id ? null : id;
        render();
    },
    setDiagram(patch) {
        if (patch.view) state.ui.diagramView = patch.view;
        if ('phase' in patch) state.ui.diagramPhase = patch.phase;
        render();
    },
    setRecordOpen(open) {
        state.ui.recordOpen = open;
    },
    setDetailsOpen(key, open) {
        if (open) state.ui.openDetails.add(key);
        else state.ui.openDetails.delete(key);
    },
    anchorComposer(rowId, kind, closeSheet = false) {
        if (closeSheet) $('fileSheet').close();
        state.ui.composer = { kind, text: state.ui.composer.text, anchor: rowId };
        openSteer();
        render();
        window.requestAnimationFrame(() => $('composer-text')?.focus());
    },
    setComposer(patch, rerender = true) {
        Object.assign(state.ui.composer, patch);
        if (rerender) render();
        else {
            const submit = document.querySelector('.composer button[type="submit"]');
            if (submit) submit.disabled = !state.ui.composer.text.trim();
        }
    },
    async submitComposer() {
        const composer = state.ui.composer;
        try {
            await api('/api/feedback', { kind: composer.kind, text: composer.text, target: composer.anchor ? { id: composer.anchor } : undefined });
            announce(composer.kind === 'research-request' ? 'Research request queued. A lane starts when the agent takes it.' : 'Added to your feedback, queued for the agent.');
            state.ui.composer = { kind: composer.kind, text: '', anchor: null };
            await refresh();
            window.requestAnimationFrame(() => $('composer-text')?.focus());
        } catch (error) {
            announce(error.message);
        }
    },
    async requestTask(id, text) {
        try {
            await api('/api/feedback', { kind: 'task-request', text, target: { id } });
            announce('Request queued for the agent.');
            await refresh();
        } catch (error) {
            announce(error.message);
        }
    },
    async toggleChecklist(phase, itemId, checked) {
        try {
            await api('/api/checklist', { phase, itemId, checked });
            await refresh();
        } catch (error) {
            announce(error.message);
        }
    },
    async shareChecklist(phase) {
        try {
            await api('/api/checklist/share', { phase });
            announce('Your review was queued for the agent.');
            await refresh();
        } catch (error) {
            announce(error.message);
        }
    },
    setDeliveryMode(mode) {
        state.ui.deliveryMode = mode;
        state.ui.deliveryPreview = null;
        render();
    },
    async preview(ids) {
        try {
            state.ui.deliveryPreview = await api('/api/delivery/preview', { ids });
            render();
            window.requestAnimationFrame(() => document.querySelector('.preview-text')?.focus());
        } catch (error) {
            announce(error.message);
        }
    },
    async deliver(ids) {
        state.ui.delivering = true;
        render();
        let stale = false;
        try {
            const result = await api('/api/delivery', { ids, mode: state.ui.deliveryMode, digest: state.ui.deliveryPreview?.digest ?? '' });
            announce(result.warning ?? `Delivered ${plural(result.delivered.length, 'item')} ${result.mode === 'attach' ? 'as an attachment to your next message' : 'as a message to the agent'}.`);
        } catch (error) {
            stale = error.code === 'preview_stale' && Boolean(error.detail?.preview);
            if (stale) {
                state.ui.deliveryPreview = error.detail.preview;
                announce('The text changed since your preview. Review the new text, then deliver again.');
            } else {
                announce(`Not delivered: ${error.message}`);
            }
        } finally {
            state.ui.delivering = false;
            if (!stale) state.ui.deliveryPreview = null;
            await refresh();
            if (stale) window.requestAnimationFrame(() => document.querySelector('.preview-text')?.focus());
        }
    },
    openFile(changeId, path) {
        const change = state.data.session.implementation.changes.find((item) => item.id === changeId);
        const file = change?.files.find((item) => item.path === path);
        if (!file) return;
        const sheet = $('fileSheet');
        sheet.replaceChildren(...filePreview(context(), change, file));
        sheet.showModal();
    },
    async copy(text) {
        try {
            await navigator.clipboard.writeText(text);
            announce('Path copied.');
        } catch {
            announce('Copy is not available here; select the path to copy it.');
        }
    },
};

/** Context passed to every component and view. */
function context() {
    return { data: state.data, ui: state.ui, act, find, resolve, now: Date.parse(state.data.session.updatedAt) > Date.now() ? Date.parse(state.data.session.updatedAt) : Date.now() };
}

// Shell rendering

function renderHeader() {
    const { session, view } = state.data;
    const { task, source } = session;
    const rpi = source?.kind === 'rpi';
    $('taskTitle').textContent = task.title;
    document.title = `RPI Workflow: ${task.title}`;
    const where = [task.repository, task.branch].filter(Boolean).join(' · ');
    const parent = rpi && task.parent ? session.followUps.lineage.find((item) => item.id === task.parent) ?? { id: task.parent, title: task.parent } : null;
    clear($('taskMeta')).append(...[
        rpi ? h('span', { class: 'badge tone-muted session-badge', title: `Read from ${source.statePath}` }, icon('file'), 'RPI session') : null,
        rpi ? h('code', { class: 'task-id', title: `Task ID: ${task.id}`, text: task.id }) : null,
        where ? h('span', { class: 'task-where', title: where, text: where }) : null,
        parent ? h('span', { class: 'task-parent' }, 'Child of ', h('button', { type: 'button', class: 'link-btn', title: `Show the parent task: ${parent.title}`, dataset: { key: 'header-parent' }, 'aria-label': `Child of ${parent.title}: show the parent task`, onclick: () => act.showTask(parent.id) }, parent.title)) : null,
        session.scenario?.sample ? h('span', { class: 'badge tone-muted sample-badge', title: 'Mock data for the canvas preview' }, icon('info'), 'Sample session') : null,
    ].filter(Boolean));
    $('liveChip').title = rpi ? "The canvas follows this task's files while it is open." : 'The canvas shows changes as they happen.';
    const count = view.attentionCount;
    const needs = $('needsBtn');
    needs.classList.toggle('has-items', count > 0);
    $('needsCount').textContent = String(count);
    $('needsLabel').textContent = count ? 'Needs you' : 'All clear';
    needs.setAttribute('aria-label', count ? `${plural(count, 'item')} ${count === 1 ? 'needs' : 'need'} you` : 'Nothing needs you');
}

function renderRail() {
    const { session, view } = state.data;
    const rail = $('phaseRail');
    const focused = rail.contains(document.activeElement) ? document.activeElement.dataset.phase : null;
    clear(rail);
    PHASES.forEach((phase, index) => {
        const status = session.phases[phase].status;
        const meta = PHASE_STATUS[status] ?? PHASE_STATUS.upcoming;
        const active = session.session.activePhase === phase;
        const selected = state.ui.phase === phase;
        const needs = view.needsYouByPhase[phase] ?? 0;
        const label = [PHASE_META[phase].label, meta.label, active ? 'agent is here' : null, needs ? `${plural(needs, 'item')} ${needs === 1 ? 'needs' : 'need'} you` : null].filter(Boolean).join(', ');
        if (index > 0) rail.append(h('span', { class: ['rail-seg', session.phases[PHASES[index - 1]].status === 'done' ? 'is-done' : null], 'aria-hidden': 'true' }));
        rail.append(h('button', {
            type: 'button', role: 'tab', class: ['rail-tab', `is-${status}`, active ? 'is-agent' : null], 'aria-selected': String(selected), tabindex: selected ? '0' : '-1',
            'aria-label': label, 'aria-controls': 'document', 'aria-keyshortcuts': state.ui.shortcuts ? PHASE_META[phase].key : undefined, dataset: { phase },
            title: state.ui.shortcuts ? `${label} (${PHASE_META[phase].key})` : label,
            onclick: () => setPhase(phase),
            onkeydown: (event) => {
                const moves = { ArrowRight: 1, ArrowLeft: -1, Home: -99, End: 99 };
                if (!(event.key in moves)) return;
                event.preventDefault();
                const next = PHASES[Math.max(0, Math.min(PHASES.length - 1, index + moves[event.key]))];
                setPhase(next);
                rail.querySelector(`[data-phase="${next}"]`)?.focus();
            },
        },
        icon(meta.icon, { className: `rail-status tone-${meta.tone}-fg` }),
        h('span', { class: 'rail-label', text: PHASE_META[phase].label }),
        active ? h('span', { class: 'rail-agent' }, icon('sparkle'), h('span', { class: 'rail-agent-text', text: 'Agent' })) : null,
        needs ? h('span', { class: 'rail-count', text: String(needs) }) : null));
    });
    if (focused) rail.querySelector(`[data-phase="${focused}"]`)?.focus();
}

function renderNavigator() {
    const ctx = context();
    const items = phaseReached(state.ui.phase) ? VIEWS[state.ui.phase].outline(ctx) : [];
    const filter = state.ui.navFilter.trim().toLowerCase();
    const shown = items.filter((item) => !filter || `${item.prefix ?? ''} ${item.label}`.toLowerCase().includes(filter));
    clear($('navBody')).append(
        h('h2', { class: 'nav-title', text: `${PHASE_META[state.ui.phase].label} outline` }),
        shown.length ? h('ul', { class: 'nav-list' }, shown.map((item) => h('li', null, h('button', { type: 'button', class: 'nav-item', onclick: () => navigate(item.id, state.ui.phase) },
            item.prefix ? h('span', { class: 'id-chip', text: item.prefix }) : null,
            h('span', { class: 'nav-label', text: item.label }),
            item.meta ? icon(item.meta.icon, { className: `tone-${item.meta.tone}-fg`, label: item.meta.label }) : null,
            item.count !== undefined ? h('span', { class: 'count', text: String(item.count) }) : null))))
            : h('p', { class: 'empty', text: filter ? 'Nothing in this phase matches.' : 'This phase has no content yet.' }));
}

function phaseReached(phase) {
    const status = state.data.session.phases[phase].status;
    return status !== 'upcoming' && status !== 'skipped';
}

function renderContextBar() {
    const { session } = state.data;
    const phase = state.ui.phase;
    const record = session.phases[phase];
    const meta = PHASE_STATUS[record.status] ?? PHASE_STATUS.upcoming;
    const active = session.session.activePhase;
    const editorLink = record.artifact ? workspaceEditorUri(context(), record.artifact) : null;
    let side = null;
    if (active === phase) {
        side = session.session.nextAction ? h('p', { class: 'next-action' }, icon('arrow-right'), h('span', { text: session.session.nextAction })) : null;
    } else if (phaseReached(phase)) {
        side = button(`Go to ${PHASE_META[active].label}, where the agent is`, { iconName: 'sparkle', onClick: () => setPhase(active) });
    }
    clear($('contextBar')).append(
        h('div', { class: 'context-main' },
            h('h2', { class: 'context-title' }, icon(PHASE_META[phase].icon), PHASE_META[phase].label),
            badge(meta),
            record.artifact ? h('span', { class: 'context-artifact' },
                h('code', { class: 'context-path', title: record.artifact, text: record.artifact }),
                button('Copy artifact path', { iconName: 'copy', hideLabel: true, onClick: () => act.copy(record.artifact) }),
                editorLink ? h('a', { class: 'btn btn-icon', href: editorLink, title: 'Open in editor', dataset: { key: 'open-artifact' } }, icon('external'), sr('Open in editor')) : null) : null,
            record.updatedAt ? h('span', { class: 'meta', title: session.source?.kind === 'rpi' ? `The file last changed ${new Date(record.updatedAt).toLocaleString()}. The canvas reads it again whenever it changes.` : undefined }, 'Updated ', relTime(record.updatedAt, context().now)) : null),
        side ? h('div', { class: 'context-side' }, side) : null);
}

function renderDocument() {
    const body = $('docBody');
    clear(body);
    if (state.error) {
        body.append(h('div', { class: 'notice tone-danger', role: 'alert' }, h('p', { class: 'notice-title' }, icon('alert'), state.error.message), h('div', { class: 'btn-row' }, button('Retry', { iconName: 'loop', onClick: refresh }))));
        if (!state.data) return;
    }
    const warnings = state.data.session.source?.warnings ?? [];
    if (warnings.length) {
        body.append(disclosure(context(), 'source-warnings', 'notice tone-attention source-warnings', `${plural(warnings.length, 'problem')} reading this task's files`,
            h('ul', { class: 'source-warning-list' }, warnings.map((text) => h('li', { text })))));
    }
    const phase = state.ui.phase;
    if (!phaseReached(phase)) {
        const previous = PHASES[PHASES.indexOf(phase) - 1];
        body.append(h('div', { class: 'empty-state' },
            icon(PHASE_META[phase].icon, { className: 'empty-icon' }),
            h('h3', { text: `${PHASE_META[phase].label} has not started` }),
            h('p', { text: `It appears here when ${previous ? PHASE_META[previous].label : 'the session'} is ready. The agent writes it and asks you about anything it cannot decide from evidence.` }),
            button(`Go to ${PHASE_META[state.data.session.session.activePhase].label}`, { kind: 'primary', iconName: 'arrow-right', onClick: () => setPhase(state.data.session.session.activePhase) })));
        return;
    }
    body.append(...VIEWS[phase].renderView(context()));
}

function renderSteer() {
    clear($('steerBody')).append(...steerPanel(context()));
}

/** Describes the focused control so a re-render can find it, or a sensible neighbor when it is gone. */
function focusKey() {
    const element = document.activeElement;
    if (!element || element === document.body || !$('workspace').contains(element)) return null;
    const selection = typeof element.selectionStart === 'number' ? [element.selectionStart, element.selectionEnd] : null;
    const holder = element.closest('[data-item], [data-row]');
    const fallback = {
        holder: holder ? (holder.dataset.item ? ['item', holder.dataset.item] : ['row', holder.dataset.row]) : null,
        heading: element.closest('.steer-section')?.getAttribute('aria-labelledby') ?? null,
    };
    if (element.id) return { id: element.id, selection, ...fallback };
    if (element.dataset.key) return { dataKey: element.dataset.key, selection, ...fallback };
    return { container: holder?.dataset.item ?? holder?.dataset.row ?? null, tag: element.tagName, label: element.getAttribute('aria-label') ?? element.textContent.trim().slice(0, 80), selection, ...fallback };
}

// checkVisibility also rejects content inside a closed details element, which still reports rects.
const usable = (element) => Boolean(element) && !element.disabled && !element.closest('[inert]')
    && (typeof element.checkVisibility === 'function' ? element.checkVisibility() : element.getClientRects().length > 0);

/** Focuses an element, making it programmatically focusable when needed; true when focus landed. */
function focusQuietly(element) {
    if (!usable(element)) return false;
    if (!element.hasAttribute('tabindex') && !element.matches('a[href], button, input, select, textarea, summary')) element.setAttribute('tabindex', '-1');
    element.focus({ preventScroll: true });
    return document.activeElement === element;
}

function restoreFocus(key) {
    if (!key) return;
    let element = key.id ? $(key.id) : key.dataKey ? document.querySelector(`[data-key="${CSS.escape(key.dataKey)}"]`) : null;
    if (!element && key.container) {
        const container = targetElement(key.container);
        element = [...(container?.querySelectorAll(key.tag) ?? [])].find((candidate) => (candidate.getAttribute('aria-label') ?? candidate.textContent.trim().slice(0, 80)) === key.label) ?? null;
    }
    if (element && (document.activeElement === element || focusQuietly(element))) {
        if (key.selection && typeof element.setSelectionRange === 'function') element.setSelectionRange(key.selection[0], key.selection[1]);
        return;
    }
    // The control went away: move to its card or row, then to its steering section heading.
    const holder = key.holder ? document.querySelector(`[data-${key.holder[0]}="${CSS.escape(key.holder[1])}"]`) : null;
    if (holder && focusQuietly(holder)) return;
    const heading = key.heading ? $(key.heading) : null;
    if (heading) focusQuietly(heading);
}

function render() {
    if (!state.data) {
        renderDocument();
        return;
    }
    const key = focusKey();
    const doc = $('document');
    const scroll = doc.scrollTop;
    const steerScroll = $('steer').scrollTop;
    renderHeader();
    renderRail();
    renderNavigator();
    renderContextBar();
    renderDocument();
    renderSteer();
    doc.scrollTop = scroll;
    $('steer').scrollTop = steerScroll;
    restoreFocus(key);
    applyPanels();
}

// Panels and drawers

const navDocks = () => window.matchMedia('(min-width: 1024px)').matches;
const steerDocks = () => window.matchMedia('(min-width: 1360px)').matches;

function applyPanels() {
    const workspace = $('workspace');
    const navVisible = navDocks() ? state.ui.navOpen : state.ui.drawer === 'nav';
    const steerVisible = steerDocks() ? state.ui.steerOpen : state.ui.drawer === 'steer';
    workspace.classList.toggle('nav-docked', navDocks());
    workspace.classList.toggle('steer-docked', steerDocks());
    workspace.classList.toggle('nav-hidden', !navVisible);
    workspace.classList.toggle('steer-hidden', !steerVisible);
    workspace.classList.toggle('drawer-nav', state.ui.drawer === 'nav');
    workspace.classList.toggle('drawer-steer', state.ui.drawer === 'steer');
    $('navigator').inert = !navVisible;
    $('steer').inert = !steerVisible;
    const modal = state.ui.drawer !== null;
    $('scrim').hidden = !modal;
    $('document').inert = modal;
    document.querySelector('.topbar').inert = modal;
    if (modal) {
        (state.ui.drawer === 'nav' ? $('steer') : $('navigator')).inert = true;
    }
    const navToggle = $('navToggle');
    navToggle.setAttribute('aria-expanded', String(navVisible));
    navToggle.querySelector('.visually-hidden').textContent = `${navVisible ? 'Hide' : 'Show'} navigator${state.ui.shortcuts ? ' (b)' : ''}`;
    const steerToggle = $('steerToggle');
    steerToggle.setAttribute('aria-expanded', String(steerVisible));
    steerToggle.querySelector('.visually-hidden').textContent = `${steerVisible ? 'Hide' : 'Show'} steering panel${state.ui.shortcuts ? ' (s)' : ''}`;
    $('steerClose').hidden = steerDocks();
    $('navClose').hidden = navDocks();
}

function openSteer() {
    if (steerDocks()) state.ui.steerOpen = true;
    else state.ui.drawer = 'steer';
    applyPanels();
}

function togglePanel(which) {
    const docks = which === 'nav' ? navDocks() : steerDocks();
    if (docks) {
        state.ui[which === 'nav' ? 'navOpen' : 'steerOpen'] = !state.ui[which === 'nav' ? 'navOpen' : 'steerOpen'];
        applyPanels();
        return;
    }
    if (state.ui.drawer === which) {
        closeDrawer(true);
        return;
    }
    state.ui.drawer = which;
    applyPanels();
    window.requestAnimationFrame(() => (which === 'nav' ? $('navFilter') : $('steerBody').querySelector('button, input, textarea'))?.focus());
}

function closeDrawer(returnFocus) {
    if (!state.ui.drawer) return;
    const which = state.ui.drawer;
    state.ui.drawer = null;
    applyPanels();
    if (returnFocus) $(which === 'nav' ? 'navToggle' : 'steerToggle').focus();
}

// Appearance

function applyPreferences(preferences) {
    if (!preferences) return;
    const root = document.documentElement;
    root.dataset.theme = preferences.theme;
    root.dataset.contrast = preferences.contrast;
    for (const input of document.querySelectorAll('input[name="theme"]')) input.checked = input.value === preferences.theme;
    $('contrastSwitch').checked = preferences.contrast === 'more';
    $('appearanceNote').textContent = preferences.theme === 'system' ? 'System follows your editor or operating system.' : `${preferences.theme === 'light' ? 'Light' : 'Dark'} overrides your editor theme for this canvas.`;
    const useIcon = $('appearanceBtn').querySelector('use');
    useIcon.setAttribute('href', preferences.theme === 'light' ? '#i-sun' : preferences.theme === 'dark' ? '#i-moon' : '#i-contrast');
    $('appearanceBtn').querySelector('.visually-hidden').textContent = `Appearance: ${preferences.theme}${preferences.contrast === 'more' ? ', more contrast' : ''}`;
}

async function savePreferences(patch) {
    const next = { ...state.data?.preferences, ...patch };
    applyPreferences(next);
    if (state.data) state.data.preferences = next;
    try {
        await api('/api/preferences', patch);
        announce(`Appearance set to ${next.theme}${next.contrast === 'more' ? ' with more contrast' : ''}.`);
    } catch (error) {
        announce(error.message);
    }
}

function toggleAppearance(open) {
    const menu = $('appearanceMenu');
    const show = open ?? menu.hidden;
    menu.hidden = !show;
    $('appearanceBtn').setAttribute('aria-expanded', String(show));
    if (show) menu.querySelector('input[name="theme"]:checked')?.focus();
}

// Keyboard

const SHORTCUTS = [
    ['1 to 5', 'View Research, Plan, Implement, Review, or Follow-up'],
    ['n', 'Move to the next item that needs you'],
    ['[ and ]', 'Previous and next row'],
    ['e', "Edit the focused row's section"],
    ['c', 'Comment on the focused row'],
    ['/', 'Open the navigator and filter it'],
    ['b', 'Show or hide the navigator'],
    ['s', 'Show or hide the steering panel'],
    ['?', 'Show this list'],
    ['Escape', 'Close a menu, drawer, or dialog, or leave the section editor'],
];

/** The document row that holds focus, if any; row shortcuts never guess. */
function focusedRow() {
    return document.activeElement?.closest('#docBody .row') ?? null;
}

/** Single-key shortcut hints follow the shortcut switch. */
function applyShortcutHints() {
    const hints = [[$('shortcutsBtn'), '?'], [$('navFilter'), '/']];
    for (const [element, key] of hints) {
        if (state.ui.shortcuts) element.setAttribute('aria-keyshortcuts', key);
        else element.removeAttribute('aria-keyshortcuts');
    }
}

function moveRow(step) {
    const rows = [...document.querySelectorAll('#docBody .row')];
    if (!rows.length) return;
    const index = rows.indexOf(document.activeElement?.closest('.row'));
    const next = rows[Math.max(0, Math.min(rows.length - 1, index < 0 ? 0 : index + step))];
    next.scrollIntoView({ block: 'start', behavior: reducedMotion() ? 'auto' : 'smooth' });
    next.focus({ preventScroll: true });
}

function onKeydown(event) {
    if (event.key === 'Escape') {
        // Input methods use Escape to cancel composition, and open dialogs close themselves.
        if (event.isComposing || event.keyCode === 229 || document.querySelector('dialog[open]')) return;
        if (!$('appearanceMenu').hidden) {
            toggleAppearance(false);
            $('appearanceBtn').focus();
        } else if (state.ui.drawer) {
            closeDrawer(true);
        } else if (state.ui.editing && document.activeElement?.closest('.editor')) {
            act.requestCancelEdit();
        }
        return;
    }
    const typing = event.target.closest?.('input, textarea, select, [contenteditable="true"]');
    if (typing || event.metaKey || event.ctrlKey || event.altKey || !state.ui.shortcuts || !state.data || document.querySelector('dialog[open]')) return;
    const key = event.key;
    if (key >= '1' && key <= '5') {
        setPhase(PHASES[Number(key) - 1]);
        $('phaseRail').querySelector('[aria-selected="true"]')?.focus();
    } else if (key === 'n') {
        const items = [...state.data.view.needsYou.map((item) => item.id), ...state.data.view.interpretations.map((id) => find(id)?.target?.id ?? id)];
        if (!items.length) {
            announce('Nothing needs you right now.');
            return;
        }
        const index = items.indexOf(state.ui.lastNeeds);
        state.ui.lastNeeds = items[(index + 1) % items.length];
        navigate(state.ui.lastNeeds);
    } else if (key === '[' || key === ']') {
        moveRow(key === ']' ? 1 : -1);
    } else if (key === 'e' || key === 'c') {
        const row = focusedRow();
        if (!row) {
            announce('Move to a row first, for example with ] or by selecting it.');
        } else if (key === 'c') {
            act.anchorComposer(row.dataset.row, 'comment');
        } else {
            const editButton = row.querySelector(`[data-key="edit-section-${CSS.escape(row.dataset.row)}"]`);
            if (editButton) editButton.click();
            else announce('This row has no section to edit. Use c to comment on it.');
        }
    } else if (key === '/') {
        if (navDocks()) {
            state.ui.navOpen = true;
        } else {
            state.ui.drawer = 'nav';
        }
        applyPanels();
        window.requestAnimationFrame(() => $('navFilter').focus());
    } else if (key === 'b') {
        togglePanel('nav');
    } else if (key === 's') {
        togglePanel('steer');
    } else if (key === '?') {
        $('shortcutsDialog').showModal();
    } else {
        return;
    }
    event.preventDefault();
}

// Boot

function wire() {
    clear($('shortcutList')).append(...SHORTCUTS.flatMap(([keys, text]) => [h('dt', null, h('kbd', { text: keys })), h('dd', { text })]));
    applyShortcutHints();
    $('shortcutSwitch').addEventListener('change', (event) => {
        state.ui.shortcuts = event.target.checked;
        applyShortcutHints();
        announce(`Single-key shortcuts ${state.ui.shortcuts ? 'on' : 'off'}.`);
        if (state.data) render();
    });
    for (const dialog of document.querySelectorAll('dialog')) {
        dialog.addEventListener('click', (event) => {
            if (event.target.closest('[data-close]') || event.target === dialog) dialog.close();
        });
    }
    $('navToggle').addEventListener('click', () => togglePanel('nav'));
    $('steerToggle').addEventListener('click', () => togglePanel('steer'));
    $('steerClose').addEventListener('click', () => closeDrawer(true));
    $('navClose').addEventListener('click', () => closeDrawer(true));
    $('scrim').addEventListener('click', () => closeDrawer(true));
    $('shortcutsBtn').addEventListener('click', () => $('shortcutsDialog').showModal());
    $('needsBtn').addEventListener('click', () => {
        openSteer();
        window.requestAnimationFrame(() => {
            const heading = $('steer-needs');
            heading?.setAttribute('tabindex', '-1');
            heading?.focus();
        });
    });
    $('appearanceBtn').addEventListener('click', () => toggleAppearance());
    for (const input of document.querySelectorAll('input[name="theme"]')) {
        input.addEventListener('change', () => savePreferences({ theme: input.value }));
    }
    $('contrastSwitch').addEventListener('change', (event) => savePreferences({ contrast: event.target.checked ? 'more' : 'standard' }));
    document.addEventListener('click', (event) => {
        if (!$('appearanceMenu').hidden && !event.target.closest('#appearanceMenu, #appearanceBtn')) toggleAppearance(false);
    });
    $('navFilter').addEventListener('input', (event) => {
        state.ui.navFilter = event.target.value;
        if (state.data) {
            renderNavigator();
            const count = $('navBody').querySelectorAll('.nav-item').length;
            announce(count ? `${plural(count, 'match', 'matches')}.` : 'No matches.');
        }
    });
    document.addEventListener('keydown', onKeydown);
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') {
            connect();
            refresh();
        } else {
            state.stream?.close();
            stopPolling();
            setLive('paused');
        }
    });
    window.matchMedia('(min-width: 1024px)').addEventListener('change', () => {
        state.ui.drawer = null;
        applyPanels();
    });
    window.matchMedia('(min-width: 1360px)').addEventListener('change', () => {
        state.ui.drawer = null;
        applyPanels();
    });
    applyPreferences({ theme: document.documentElement.dataset.theme, contrast: document.documentElement.dataset.contrast });
}

/** Matches light-dark() to a host-themed background so role hues keep their contrast. */
function detectHostScheme() {
    const root = document.documentElement;
    const raw = getComputedStyle(root).getPropertyValue('--background-color-default').trim();
    if (!raw) {
        delete root.dataset.hostScheme;
        return false;
    }
    const probe = document.createElement('canvas').getContext('2d');
    probe.fillStyle = '#000001';
    probe.fillStyle = raw;
    const parsed = String(probe.fillStyle);
    const channels = parsed.startsWith('#') ? [1, 3, 5].map((index) => Number.parseInt(parsed.slice(index, index + 2), 16)) : (parsed.match(/[\d.]+/g) ?? []).slice(0, 3).map(Number);
    if (channels.length !== 3 || (parsed === '#000001' && raw.toLowerCase() !== '#000001')) {
        delete root.dataset.hostScheme;
        return true;
    }
    const [r, g, b] = channels.map((value) => {
        const c = value / 255;
        return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    root.dataset.hostScheme = 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.179 ? 'dark' : 'light';
    return true;
}

function reportEnvironment() {
    const style = getComputedStyle(document.documentElement);
    const hostTokens = detectHostScheme() || ['--text-color-default', '--vscode-editor-background'].some((name) => style.getPropertyValue(name).trim() !== '');
    api('/api/client-info', {
        scheme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
        moreContrast: window.matchMedia('(prefers-contrast: more)').matches,
        forcedColors: window.matchMedia('(forced-colors: active)').matches,
        reducedMotion: reducedMotion(),
        lightDark: CSS.supports('color', 'light-dark(#000, #fff)'),
        hostTokens,
        width: window.innerWidth,
        height: window.innerHeight,
    }).catch(() => {});
}

wire();
applyPanels();
await refresh();
connect();
reportEnvironment();
