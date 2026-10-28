// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, clear, decisionAlias, fullTime, h, icon, idTag, PHASE_META, PHASE_STATUS, plural, relTime, sr } from './dom.mjs';
import { confirmPress, disclosure, filePreview, hasMarginHome, reviewSheet, sendItems, sessionPending, sessionTree, steerPanel, waitingCount } from './components.mjs';
import { editorButton, sourceProblem, sourceSheet } from './source-view.mjs';
import { anchorAt, installAnchorHandle } from './anchors.mjs';
import { notConnectedView } from './connect-view.mjs';
import { composeDocument, DOCUMENT_NOUNS, documentChoices, documentLabel, documentsIn, earlierDocument, inEarlier, pairedPlanOf, scopedLookup } from './documents.mjs';
import { installContextMenu } from './context-menu.mjs';
import { legendContent } from './legend.mjs';
import { createHistory, placeLabel } from './history.mjs';
import { kindOf } from './ids.mjs';
import { installPreviews } from './previews.mjs';
import { mapPart } from './map-part.mjs';
import { installTooltips } from './tooltips.mjs';
import * as followupView from './view-followup.mjs';
import * as implementView from './view-implement.mjs';
import * as planView from './view-plan.mjs';
import * as researchView from './view-research.mjs';
import * as reviewView from './view-review.mjs';

/** RPI Workflow page: data sync, navigation, user actions, and shell rendering. */

const PHASES = ['research', 'plan', 'implement', 'review', 'followup'];
const VIEWS = { research: researchView, plan: planView, implement: implementView, review: reviewView, followup: followupView };
const $ = (id) => document.getElementById(id);

/** The Review and send dialog's state: the person's message, the previewed text, and progress. */
function freshSend() {
    return { note: '', preview: null, previewNote: null, sending: false, busy: null, error: null };
}

const state = {
    data: null,
    /** The state answer while the canvas shows no session, until the agent connects it. */
    notConnected: null,
    error: null,
    /** Why the last render failed, until a render succeeds; every environment report carries it. */
    renderError: null,
    live: 'connecting',
    /** Whether the canvas moves with the agent's loop and phase; null until the first load. */
    following: null,
    stream: null,
    pollTimer: null,
    /** Visible notes in the status area: failures and where following moved the canvas. */
    notes: [],
    /** Sessions in the workspace, loaded when the session menu opens. */
    sessions: { loading: false, error: null, list: null, skipped: [] },
    ui: {
        phase: null,
        highlight: null,
        editing: null,
        expanded: new Set(),
        openEvidence: new Set(),
        send: freshSend(),
        composer: { text: '', anchor: null, part: null, quote: null, title: null },
        decisionDrafts: new Map(),
        corrections: new Map(),
        overrides: new Set(),
        revealed: new Set(),
        docs: { research: null, plan: null, implement: null, review: null },
        diagramView: 'after',
        diagramPhase: null,
        recordOpen: false,
        openDetails: new Set(),
        navFilter: '',
        feedbackEdit: null,
        confirm: null,
        taskFilter: 'active',
        boardCollapsed: false,
        boardLane: null,
        mapPhase: undefined,
        /** The waiting item Needs you last moved to. */
        lastNeeds: null,
        shortcuts: true,
        navOpen: true,
        steerOpen: true,
        drawer: null,
        /** The Not connected screen: Ask the agent's progress and whether its help is open. */
        connect: { asking: false, askedAt: 0, retryAfterMs: 30000, error: null, helpOpen: false },
    },
};

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/** This canvas's key, from the address the host opened; every API call carries it. */
const KEY = new URLSearchParams(location.search).get('k') ?? '';

async function api(path, body) {
    const init = body === undefined ? { headers: { accept: 'application/json', 'x-rw-key': KEY } } : { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json', 'x-rw-key': KEY }, body: JSON.stringify(body) };
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

let noteSeq = 0;
/** ID previews; set once the page is wired. */
let previews = null;
/** Tooltips, the hover comment button, and the canvas menu; set once the page is wired. */
let tooltips = null;
let anchors = null;
let contextMenu = null;
/** Places the reader moved through, across phases and tasks. */
const places = createHistory();
/** True while Back or Forward moves the view, so that move is not recorded. */
let restoringPlace = false;
/** A remembered place in another task, shown once that task loads. */
let pendingPlace = null;
const MAX_NOTES = 3;

/** Shows a failure in the status area until dismissed, and announces it; focus stays where it is. */
function reportFailure(text) {
    state.notes = [...state.notes.filter((note) => note.text !== text), { id: `note-${++noteSeq}`, tone: 'danger', icon: 'alert', text }].slice(-MAX_NOTES);
    renderStatus();
    announce(text);
}

/** Says where following moved the canvas; replaces the previous move note. */
function noteMoved(moved) {
    const text = `Moved to ${moved.title}, the loop the agent works in. The canvas moves with the agent while the top of the canvas shows Live.`;
    state.notes = [...state.notes.filter((note) => note.kind !== 'moved'), { id: `note-${++noteSeq}`, kind: 'moved', tone: 'accent', icon: 'arrow-right', text }].slice(-MAX_NOTES);
    renderStatus();
    announce(`Moved to ${moved.title}, the loop the agent works in.`);
}

function dismissNote(id) {
    const area = $('statusArea');
    const hadFocus = area.contains(document.activeElement);
    const index = state.notes.findIndex((note) => note.id === id);
    state.notes = state.notes.filter((note) => note.id !== id);
    renderStatus();
    if (!hadFocus) return;
    const next = state.notes[Math.min(index, state.notes.length - 1)];
    const button = next ? area.querySelector(`[data-key="dismiss-${CSS.escape(next.id)}"]`) : null;
    if (button) button.focus({ preventScroll: true });
    else focusQuietly($('document'));
}

function renderStatus() {
    const area = $('statusArea');
    area.hidden = state.notes.length === 0;
    area.replaceChildren(...state.notes.map((note) => h('div', { class: ['status-note', 'notice', `tone-${note.tone}`], dataset: { note: note.id } },
        icon(note.icon, { className: 'status-note-icon' }),
        h('p', { class: 'status-note-text', text: note.text }),
        button('Dismiss', { iconName: 'x', hideLabel: true, title: 'Dismiss this note', attrs: { 'data-key': `dismiss-${note.id}` }, onClick: () => dismissNote(note.id) }))));
}

// Lookup and navigation

/** The ID a reference means in the viewed phase: a bare `D#` names that phase's decision first. */
const aliasOf = (id) => decisionAlias(state.data?.session, id, state.ui.phase);

/** A phase's documents in the order the session made them; `current` marks the current work's. */
const documentsOf = (phase) => documentsIn(state.data?.session, phase);

/** The earlier document of a phase the reader chose, or null while the current work's shows. */
const shownEarlier = (phase) => earlierDocument(state.data?.session, phase, state.ui.docs?.[phase]);

/**
 * Sets the document a phase shows: an earlier one by number, or the current work's with null. A
 * changes record shows all its tasks when it is an earlier one, since none is in progress there,
 * and what is in progress when it is the current one.
 *
 * @param {string} phase
 * @param {number | null} n
 */
function setShownDocument(phase, n) {
    const next = n ?? null;
    if ((state.ui.docs[phase] ?? null) === next) return;
    state.ui.docs[phase] = next;
    if (phase === 'implement') state.ui.taskFilter = next ? 'all' : 'active';
}

/** The shown earlier document of a phase as a lookup scope, or null while the current work's shows. */
function scopeOf(phase) {
    const doc = DOCUMENT_NOUNS[phase] ? shownEarlier(phase) : null;
    return doc ? { phase, doc } : null;
}

/** An item by ID: in the current work's documents and the canvas's own data first, then in earlier documents. A `part:` ID is a part of the current plan's change map. */
function find(ref) {
    const session = state.data?.session;
    if (!session || typeof ref !== 'string') return null;
    if (ref.startsWith('part:')) return mapPart(session, ref);
    const id = aliasOf(ref);
    return findCurrent(session, id) ?? inEarlier(session, id)?.item ?? null;
}

/** The ID a reference means inside an earlier document: a bare `D#` names that document's decision first. */
const scopedAlias = (scope, ref) => decisionAlias(composeDocument(state.data.session, scope.phase, scope.doc), ref, scope.phase);

/** An item by ID inside an earlier document: in it, then in its work's other documents, then as `find` does. A `part:` ID is a part of that document's plan's change map. */
function scopedFind(scope, ref) {
    if (!state.data || typeof ref !== 'string') return null;
    if (ref.startsWith('part:')) return mapPart(composeDocument(state.data.session, scope.phase, scope.doc), ref);
    return scopedLookup(state.data.session, scope, scopedAlias(scope, ref))?.item ?? find(ref);
}

/** Where an ID inside an earlier document leads: the document of its own work that holds it, then as `resolve` does. */
function scopedResolve(scope, ref) {
    if (!state.data || typeof ref !== 'string') return null;
    const hit = scopedLookup(state.data.session, scope, scopedAlias(scope, ref));
    return hit ? { phase: hit.phase, doc: hit.doc } : resolve(ref);
}

/** An item in the current work's documents and the canvas's own data. */
function findCurrent(session, id) {
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
    // An ID only an earlier document holds lives in that document, in its kind's phase.
    const earlier = findCurrent(state.data.session, id) ? null : inEarlier(state.data.session, id);
    if (earlier) return { phase: earlier.phase, doc: earlier.doc.n };
    if (/^[QFCWL]\d{1,3}$/.test(id)) return { phase: 'research' };
    if (/^(?:plan\.)?D\d{1,3}$/.test(id)) return hasMarginHome(context(), item) ? { phase: item.anchor.phase } : { phase: state.ui.phase };
    if (/^P\d{2}(-T\d{2})?$/.test(id)) return { phase: state.ui.phase === 'implement' ? 'implement' : 'plan' };
    if (/^(FR|NFR|PC)-\d{3}$/.test(id)) return { phase: 'plan' };
    if (/^(CH|DS|AL)-\d{3}$/.test(id)) return { phase: 'implement' };
    if (/^(RV|RD)-\d{3}$/.test(id)) return { phase: 'review' };
    if (/^FU-\d+$/.test(id)) return { phase: 'followup' };
    if (/^FB-\d{3}$/.test(id)) return item.target ? resolve(item.target.id) : null;
    if (item.doc) return { phase: item.doc };
    return null;
}

/** Where the reader is: the task, phase, the earlier document shown there, the item last moved to, and the scroll position. */
function here() {
    const session = state.data?.session;
    if (!session || !state.ui.phase) return null;
    return placeAt({ taskId: session.task.id, taskTitle: session.task.title, scroll: $('document').scrollTop }, state.ui.phase, state.ui.place?.id ?? null, state.ui.place?.label);
}

/** A place in a phase of the shown task, with the earlier document that phase shows, if any. */
function placeAt(from, phase, id, label) {
    const doc = DOCUMENT_NOUNS[phase] ? shownEarlier(phase) : null;
    return { ...from, phase, id, label, doc: doc?.n ?? null, docLabel: doc ? documentLabel(doc) : undefined };
}

/** Records a move in the history unless Back or Forward is making it. */
function remember(from, to) {
    if (!restoringPlace && from && to) places.move(from, to);
}

function setHash() {
    history.replaceState(null, '', `#phase=${state.ui.phase}${state.following === false ? '&follow=off' : ''}`);
}

function phaseFromHash() {
    const match = /phase=([a-z]+)/.exec(location.hash);
    return match && PHASES.includes(match[1]) ? match[1] : null;
}

/** The phase the agent works in, or null before the first load. */
const agentPhase = () => state.data?.session.session.activePhase ?? null;

/**
 * Shows a phase. A phase the reader chose away from the agent's stops following; the agent's
 * own moves (`agent: true`) keep it.
 *
 * @param {string} phase
 * @param {{ agent?: boolean }} [options]
 */
function setPhase(phase, options = {}) {
    if (!PHASES.includes(phase)) return;
    if (!options.agent && phase !== agentPhase()) stopFollowing();
    previews?.closeAll();
    if (phase !== state.ui.phase) {
        const from = here();
        remember(from, from && placeAt(from, phase, null));
    }
    state.ui.place = null;
    state.ui.phase = phase;
    state.ui.highlight = null;
    state.ui.boardLane = null;
    state.ui.navFilter = '';
    $('navFilter').value = '';
    setHash();
    render();
    $('document').scrollTop = 0;
}

/** True when the open editor's draft differs from the text it started from. */
function editChanged(editing) {
    return Boolean(editing) && editing.draft !== (editing.start ?? state.data?.session.sections[editing.sectionId]?.markdown ?? editing.draft);
}

/** The section's suggestion that has not been sent, if any. */
const pendingSuggestionFor = (sectionId) => state.data?.session.feedback.find((item) => item.kind === 'edit' && item.state === 'queued' && item.target?.id === sectionId) ?? null;

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

/**
 * Goes to an ID: shows its phase, and the document there that holds it, and moves to it. With a
 * `scope`, the ID is looked up inside that earlier document and its work first; `keepDocument`
 * stays in the document the phase shows.
 *
 * @param {string} ref
 * @param {string} [phaseOverride]
 * @param {{ agent?: boolean, keepDocument?: boolean, scope?: { phase: string, doc: any } | null }} [options]
 */
function navigate(ref, phaseOverride, options = {}) {
    previews?.closeAll();
    contextMenu?.close();
    const { scope } = options;
    const id = scope ? scopedAlias(scope, ref) : aliasOf(ref);
    const target = scope ? scopedResolve(scope, id) : resolve(id);
    const phase = phaseOverride ?? target?.phase ?? state.ui.phase;
    const from = here();
    if (!options.agent && phase !== agentPhase()) stopFollowing();
    // An ID an earlier document holds shows that document; any other ID shows the current
    // work's, unless the reader goes to an ID inside the earlier document already shown.
    const doc = options.keepDocument ? state.ui.docs[phase] ?? null : target?.doc ?? null;
    if (DOCUMENT_NOUNS[phase] && doc !== (state.ui.docs[phase] ?? null)) {
        if (doc) {
            if (!options.agent) stopFollowing();
            const earlier = documentsOf(phase).find((entry) => entry.n === doc);
            announce(`${ref} is in the earlier ${DOCUMENT_NOUNS[phase]} "${earlier ? documentLabel(earlier) : doc}"; showing it.`);
        }
        setShownDocument(phase, doc);
    }
    const found = scope ? scopedFind(scope, id) : find(id);
    const label = kindOf(id) ? found?.ref ?? ref : found?.title ?? ref;
    remember(from, from && placeAt(from, phase, id, label));
    if (/^[CW]\d{1,3}$/.test(id)) state.ui.recordOpen = true;
    if (/^P\d{2}-T\d{2}$/.test(id) && (phase === 'plan' || phase === 'implement')) state.ui.expanded.add(id);
    // A phase or task lands in Phases and tasks, which shows all tasks when its filter would hide it.
    const widened = /^P\d{2}(?:-T\d{2})?$/.test(id) && phase === 'implement' && Boolean(state.data) && !implementView.filterShows(viewContext('implement').data.session, state.ui.taskFilter, id);
    if (widened) state.ui.taskFilter = 'all';
    state.ui.boardLane = null;
    closeDrawer(false);
    state.ui.phase = phase;
    state.ui.highlight = id;
    state.ui.place = { id, label };
    setHash();
    render();
    window.requestAnimationFrame(() => {
        const element = targetElement(id);
        if (!element) {
            announce(`${ref} is not shown in ${PHASE_META[phase].label}.`);
            return;
        }
        if ($('steer').contains(element) && $('steer').inert) openSteer();
        if (widened) announce(`Showing all tasks to reach ${ref}.`);
        // The pinned board is always in view; scrolling to it would move the page under it.
        const dock = element.closest('.board-dock');
        if (!(dock && window.getComputedStyle(dock).position === 'sticky')) {
            const tall = element.getBoundingClientRect().height > $('document').clientHeight * 0.5;
            element.scrollIntoView({ block: tall ? 'start' : 'center', behavior: reducedMotion() ? 'auto' : 'smooth' });
        }
        element.focus({ preventScroll: true });
        element.classList.add('is-highlight');
        window.setTimeout(() => {
            element.classList.remove('is-highlight');
            if (state.ui.highlight === id) state.ui.highlight = null;
        }, 1200);
        if (options.agent) announce(`The agent pointed you to ${ref}${found?.title ? `, ${found.title}` : ''}.`);
    });
}

/** Shows a remembered place without recording the move, in the earlier document it was in when that can still show. */
function applyPlace(place) {
    restoringPlace = true;
    try {
        if (DOCUMENT_NOUNS[place.phase]) {
            const doc = earlierDocument(state.data.session, place.phase, place.doc);
            if (doc) stopFollowing();
            setShownDocument(place.phase, doc?.n ?? null);
        }
        const scope = scopeOf(place.phase);
        if (place.id && (scope ? scopedFind(scope, place.id) : find(place.id))) {
            navigate(place.id, place.phase, { keepDocument: true, scope });
        } else {
            setPhase(place.phase);
            if (place.id) announce(`${place.label ?? place.id} is no longer in ${PHASE_META[place.phase]?.label ?? place.phase}.`);
            else $('document').scrollTop = place.scroll;
        }
    } finally {
        restoringPlace = false;
    }
}

/** Moves Back or Forward through the history, showing the place's task first when it is another one. */
async function travel(direction) {
    const current = here();
    if (!current) return;
    const place = direction === 'back' ? places.back(current) : places.forward(current);
    if (!place) {
        announce(direction === 'back' ? 'There is no earlier place to go back to.' : 'There is no later place to go forward to.');
        return;
    }
    stopFollowing();
    if (place.taskId === current.taskId) {
        applyPlace(place);
        return;
    }
    pendingPlace = place;
    try {
        await api('/api/task', { taskId: place.taskId, follow: false });
        await refresh();
    } catch (error) {
        pendingPlace = null;
        places.drop(place);
        reportFailure(`${place.taskTitle} is no longer available: ${error.message}`);
        render();
    }
}

// Data sync

/** IDs as a short list for announcements: "FB-001", "FB-001 and FB-002", or the first three and how many more. */
function listIds(ids) {
    if (ids.length <= 2) return ids.join(' and ');
    if (ids.length === 3) return `${ids[0]}, ${ids[1]}, and ${ids[2]}`;
    return `${ids.slice(0, 3).join(', ')}, and ${ids.length - 3} more`;
}

function announceChanges(previous, next, moved = false) {
    if (!previous) return;
    const messages = [];
    const before = new Set(previous.view.needsYou.map((item) => item.id));
    for (const item of next.view.needsYou) {
        if (!before.has(item.id)) messages.push(`${item.id} needs your input: ${item.title}.`);
    }
    // Where sent items are, said politely: the agent picking them up, then reading them back.
    const hadIt = new Set(previous.session.feedback.filter((item) => item.pickedUpAt).map((item) => item.id));
    const picked = next.session.feedback.filter((item) => item.pickedUpAt && item.state === 'sent' && !hadIt.has(item.id)).map((item) => item.id);
    if (picked.length) messages.push(`The agent has ${listIds(picked)}.`);
    const readBefore = new Set(previous.view.readBacks ?? []);
    const read = (next.view.readBacks ?? []).filter((id) => !readBefore.has(id));
    for (const id of read) state.ui.revealed.add(id);
    if (read.length) messages.push(`The agent read back ${listIds(read)}. ${read.length === 1 ? 'It is' : 'They are'} in Your feedback, where you can correct ${read.length === 1 ? 'it' : 'them'}.`);
    if (previous.session.session.activePhase !== next.session.session.activePhase) {
        messages.push(`The agent moved to ${PHASE_META[next.session.session.activePhase].label}${moved ? '; the canvas moved with it' : ''}.`);
    }
    // The critique starting and finishing are announced; each lens is not, to keep the page quiet.
    const critiqueBefore = previous.session.plan.critique?.run ?? null;
    const critique = next.session.plan.critique;
    if (critique?.run === 'running' && critiqueBefore !== 'running') messages.push('The agent started the plan critique; its findings appear under Critique as each lens finishes.');
    if (critiqueBefore === 'running' && !critique?.run && critique?.verdict) messages.push(`The plan critique finished: ${critique.verdict}, ${plural(critique.findings.length, 'finding')}.`);
    if (messages.length) announce(messages.join(' '));
}

/** Page state that belongs to one task, with its starting values. Appearance and panels are page-wide. */
const taskUi = () => ({
    phase: null,
    highlight: null,
    editing: null,
    expanded: new Set(),
    openEvidence: new Set(),
    send: freshSend(),
    composer: { text: '', anchor: null, part: null, quote: null, title: null },
    decisionDrafts: new Map(),
    corrections: new Map(),
    overrides: new Set(),
    revealed: new Set(),
    // The earlier document each phase shows instead of the current work's, by number; null shows the current work's.
    docs: { research: null, plan: null, implement: null, review: null },
    place: null,
    diagramView: 'after',
    diagramPhase: null,
    recordOpen: false,
    openDetails: new Set(),
    navFilter: '',
    feedbackEdit: null,
    confirm: null,
    // Implement: which tasks Phases and tasks shows, whether the board is collapsed, its open lane, and the map's phase (undefined: the one in progress).
    taskFilter: 'active',
    boardCollapsed: false,
    boardLane: null,
    mapPhase: undefined,
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
    // A task you return to keeps its page, but never reopens a lane's dropdown on its own.
    Object.assign(state.ui, restored?.ui ?? taskUi(), { highlight: null, revealed: new Set(), navFilter: '', boardLane: null });
    state.ui.phase ??= next.session.session.activePhase;
    $('navFilter').value = '';
    return restored?.scroll ?? 0;
}

async function refresh() {
    try {
        const next = await api('/api/state');
        if (next.connected === false) {
            showNotConnected(next);
            return;
        }
        if (state.notConnected) leaveNotConnected();
        const previous = state.data;
        const switched = Boolean(previous) && previous.session.id !== next.session.id;
        const leaving = switched ? here() : null;
        syncFollowing(next);
        const agentNow = next.session.session.activePhase;
        const scroll = switched ? switchTaskUi(previous.session.id, next) : null;
        state.data = next;
        state.error = null;
        state.ui.phase ??= state.following ? agentNow : phaseFromHash() ?? agentNow;
        // While following, the canvas moves with the agent whenever its loop or phase changes.
        const withAgent = Boolean(state.following && previous && (switched || previous.session.session.activePhase !== agentNow) && state.ui.phase !== agentNow);
        if (withAgent) {
            const from = switched ? null : here();
            if (from) remember(from, placeAt(from, agentNow, null));
            Object.assign(state.ui, { phase: agentNow, place: null, highlight: null, boardLane: null });
        }
        if (switched || withAgent) setHash();
        if (state.ui.editing) {
            const section = next.session.sections[state.ui.editing.sectionId];
            if (!section) state.ui.editing = null;
        }
        applyPreferences(next.preferences);
        if (switched) announce(`Showing ${next.session.task.title}, ${PHASE_META[state.ui.phase].label}.`);
        else announceChanges(previous, next, withAgent);
        render();
        if (!switched && withAgent) $('document').scrollTop = 0;
        if (switched) {
            $('document').scrollTop = withAgent ? 0 : scroll;
            const pending = pendingPlace;
            pendingPlace = null;
            if (pending?.taskId === next.session.task.id) {
                applyPlace(pending);
                // A move you chose, such as Go to in Review and send, joins Back and Forward.
                if (pending.record) remember(leaving, here());
            } else {
                remember(leaving, here());
            }
        }
        if (state.ui.revealed.size) window.setTimeout(() => state.ui.revealed.clear(), 900);
    } catch (error) {
        state.error = error;
        render();
    }
}

function setLive(live) {
    state.live = live;
    renderLive();
}

/**
 * The Live control: Live while the canvas follows the agent, Follow agent otherwise, and the
 * connection state while the canvas is connecting or reconnecting.
 */
function renderLive() {
    const btn = $('liveBtn');
    const following = state.following !== false;
    btn.dataset.state = state.live;
    btn.dataset.follow = following ? 'on' : 'off';
    btn.querySelector('use')?.setAttribute('href', `#i-${following ? 'live' : 'live-off'}`);
    $('liveLabel').textContent = state.live === 'reconnecting' ? 'Reconnecting' : state.live === 'connecting' ? 'Connecting' : following ? 'Live' : 'Follow agent';
    // Names the loop Follow agent goes to when it is not the one shown.
    const agent = state.data?.follow?.agent;
    const elsewhere = agent && agent.statePath !== state.data?.session.source?.statePath ? agent.title : null;
    $('liveHint').textContent = following ? ': following the agent. Press to stop following.' : elsewhere ? `: not following. Press to go to ${elsewhere} and follow the agent.` : ": not following. Press to follow the agent's loop and phase.";
    btn.setAttribute('data-tip', following
        ? 'Following the agent: the canvas moves to the loop and phase the agent works in. Press to stop following.'
        : elsewhere ? `Follow the agent: go to ${elsewhere} and move with it.` : 'Follow the agent: go to the loop and phase the agent works in, and move with it.');
    if (state.ui.shortcuts) btn.setAttribute('aria-keyshortcuts', 'f');
    else btn.removeAttribute('aria-keyshortcuts');
}

/** A follow change the page asked the server for; until it settles, the page's own value stands. */
let followRequest = null;

/** Takes the server's follow state for a task that follows RPI files, or the page's own for the sample. */
function syncFollowing(next) {
    if (next.session.source?.kind === 'rpi' && next.follow) {
        if (!followRequest) state.following = !next.follow.paused;
    } else if (state.following === null) {
        state.following = !/(?:^|[#&])follow=off(?:&|$)/.test(location.hash);
    }
    renderLive();
}

function requestFollow(follow) {
    if (state.data?.session.source?.kind !== 'rpi') return Promise.resolve();
    const request = api('/api/follow', { follow }).finally(() => {
        if (followRequest === request) followRequest = null;
    });
    followRequest = request;
    return request;
}

/** Stops following, as any move of the reader's own does; the canvas stays where it is. */
function stopFollowing() {
    if (state.following === false) return;
    state.following = false;
    renderLive();
    if (state.ui.phase) setHash();
    requestFollow(false).catch((error) => reportFailure(`Could not stop following the agent: ${error.message}`));
}

/** Follows the agent again: its running loop, then the phase it works in. */
async function startFollowing() {
    state.following = true;
    for (const phase of Object.keys(DOCUMENT_NOUNS)) setShownDocument(phase, null);
    renderLive();
    if (state.ui.phase) setHash();
    try {
        await requestFollow(true);
    } catch (error) {
        reportFailure(`Could not follow the agent: ${error.message}`);
    }
    await refresh();
    const phase = agentPhase();
    if (phase && phase !== state.ui.phase) setPhase(phase, { agent: true });
    announce(`Following the agent. Showing ${state.data.session.task.title}, ${PHASE_META[state.ui.phase].label}.`);
}

function toggleFollowing() {
    if (state.following === false) {
        startFollowing();
        return;
    }
    stopFollowing();
    announce('Stopped following the agent. The canvas stays here until you follow it again.');
}

/** Stops following once you start adding input, and says how to catch up. */
function pauseForInput() {
    if (state.following !== true) return;
    stopFollowing();
    announce('Stopped following the agent while you add input. Press Follow agent to catch up.');
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
    const stream = new EventSource(`/api/events?k=${encodeURIComponent(KEY)}`);
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
    stream.addEventListener('reload', (event) => {
        const data = event.data ? JSON.parse(event.data) : {};
        if (data.moved) noteMoved(data.moved);
        refresh();
    });
    stream.addEventListener('preferences', (event) => applyPreferences(JSON.parse(event.data)));
    stream.addEventListener('focus', (event) => {
        if (!state.data) return;
        const data = JSON.parse(event.data);
        if (data.itemId) navigate(data.itemId, data.phase ?? undefined, { agent: true });
        else if (data.phase) setPhase(data.phase, { agent: true });
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
            announce(`${kind === 'answer' ? 'Answer' : 'Override'} for ${state.data.session.decisions.find((decision) => decision.id === decisionId)?.ref ?? decisionId} saved. It waits in Review and send.`);
            await refresh();
            targetElement(decisionId)?.focus({ preventScroll: true });
        } catch (error) {
            reportFailure(`Not saved: ${error.message}`);
        }
    },
    async transition(id, to, extra = {}) {
        try {
            await api('/api/feedback/transition', { id, to, ...extra });
            state.ui.corrections.delete(id);
            announce(to === 'applied' ? 'Marked as understood.' : to === 'corrected' ? 'Correction saved. It waits in Review and send.' : to === 'dismissed' ? 'Removed. It will not be sent.' : 'Updated.');
            await refresh();
            return true;
        } catch (error) {
            reportFailure(`Not updated: ${error.message}`);
            return false;
        }
    },
    /** Takes an item back from the agent's queue, so it waits for you again in Not sent yet. */
    async takeBack(taskId, item) {
        try {
            await api('/api/feedback/take-back', { taskId, ids: [item.id] });
            announce(`${item.id} is back in Not sent yet. It waits until you send or queue it.`);
            await refresh();
            window.requestAnimationFrame(() => document.querySelector(`[data-key="fb-edit-${CSS.escape(item.id)}"]`)?.focus());
        } catch (error) {
            reportFailure(`Not taken back: ${error.message}`);
            await refresh();
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
    /**
     * Shows a phase's document by its place in the list: an earlier one read-only, or with 0 or the
     * current one's place, the current work's. Choosing an earlier one stops following. An earlier
     * changes record shows all its tasks, since none is in progress; the current one shows what is.
     */
    showDocument(kind, n) {
        const docs = documentsOf(kind);
        const current = docs.find((entry) => entry.current) ?? null;
        const doc = n ? docs.find((entry) => entry.n === n) : current;
        if (n && !doc) return;
        const noun = DOCUMENT_NOUNS[kind];
        if (doc && !doc.current && !doc.snapshot) {
            reportFailure(`The ${noun} "${documentLabel(doc)}" could not be read; the problems list says why.`);
            return;
        }
        const earlier = doc && !doc.current ? doc : null;
        if (earlier) stopFollowing();
        previews?.closeAll();
        setShownDocument(kind, earlier?.n ?? null);
        state.ui.highlight = null;
        state.ui.place = null;
        if (state.ui.phase !== kind) setPhase(kind);
        else render();
        $('document').scrollTop = 0;
        announce(earlier
            ? `Showing the earlier ${noun} "${documentLabel(earlier)}". It is read-only here.`
            : current ? `Showing the current ${noun}, "${documentLabel(current)}".` : `Showing the current work, which has no ${noun} yet.`);
    },
    /** Shows another task of this RPI session, by task ID or `{ statePath }`. */
    async showTask(ref) {
        const before = state.data?.session.id;
        stopFollowing();
        try {
            await api('/api/task', { ...(typeof ref === 'string' ? { taskId: ref } : { statePath: ref.statePath }), follow: false });
            await refresh();
            if (state.data.session.id !== before) focusQuietly($('taskTitle'));
        } catch (error) {
            reportFailure(`Could not show that task: ${error.message}`);
        }
    },
    /** Shows another session: its running loop, or its most recently changed one. */
    async switchSession(key) {
        toggleSessionMenu(false);
        stopFollowing();
        try {
            await api('/api/session', { key, follow: false });
            await refresh();
            focusQuietly($('taskTitle'));
        } catch (error) {
            reportFailure(`Could not show that session: ${error.message}`);
        }
    },
    /** Follows the agent again: its running loop and the phase it works in. */
    resumeFollowing: () => startFollowing(),
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
    /** Correct this on a decision's feedback row corrects it on the decision card. */
    openDecisionCorrection(item) {
        state.ui.corrections.set(item.id, { text: item.text ?? '', where: 'card' });
        navigate(item.target.id);
        window.setTimeout(() => $(`correct-${item.id}`)?.focus(), 60);
    },
    /** Opens the editor on the section's pending suggestion when it has one, otherwise on the section text. */
    startEdit(sectionId) {
        const section = state.data.session.sections[sectionId];
        if (!section) return;
        const open = state.ui.editing;
        if (open && open.sectionId !== sectionId && editChanged(open)) {
            announce(`Finish or cancel your suggestion for ${state.data.session.sections[open.sectionId]?.title ?? 'the open section'} first. Your changes are kept.`);
            focusEditor(open.sectionId);
            return;
        }
        const suggestion = pendingSuggestionFor(sectionId);
        const draft = typeof suggestion?.section?.markdown === 'string' ? suggestion.section.markdown : section.markdown;
        const baseRevision = Number.isInteger(suggestion?.section?.revision) && typeof suggestion.section.diff === 'string' ? suggestion.section.revision : section.revision;
        state.ui.editing = { sectionId, draft, start: draft, baseRevision, suggestionId: suggestion?.id ?? null, mode: 'write', conflict: null, compare: false, saving: false };
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
            const result = await api('/api/suggestion', { sectionId: editing.sectionId, markdown: editing.draft, baseRevision: editing.baseRevision });
            state.ui.editing = null;
            announce(result.withdrawn ? 'Your suggestion matched the current text, so it was removed.' : result.unchanged ? 'Nothing changed, so there is nothing to suggest.' : `Suggestion ${editing.suggestionId ? 'updated' : 'added'}. It waits in Review and send, and the text changes when the agent applies it.`);
            await refresh();
            targetElement(state.data.session.sections[editing.sectionId]?.id)?.focus({ preventScroll: true });
        } catch (error) {
            editing.saving = false;
            if (error.code === 'conflict') {
                editing.conflict = error.detail.section;
                render();
                announce('This section changed while you were editing. Compare, then keep your suggestion or start from the new text.');
                window.requestAnimationFrame(() => $(`conflict-${editing.sectionId}`)?.focus());
            } else {
                render();
                reportFailure(`Suggestion not saved: ${error.message} Your text is still in the editor.`);
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
    /** Restarts the open suggestion from the section's new text, keeping the editor open. */
    useTheirs() {
        const editing = state.ui.editing;
        Object.assign(editing, { draft: editing.conflict.markdown, start: editing.conflict.markdown, baseRevision: editing.conflict.revision, conflict: null, compare: false, mode: 'write' });
        render();
        announce('The editor now holds the new text. Make your change again, or cancel.');
        window.requestAnimationFrame(() => $(`edit-${editing.sectionId}`)?.focus());
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
    setDiagram(patch) {
        if (patch.view) state.ui.diagramView = patch.view;
        if ('phase' in patch) state.ui.diagramPhase = patch.phase;
        render();
    },
    toggleBoard() {
        state.ui.boardCollapsed = !state.ui.boardCollapsed;
        state.ui.boardLane = null;
        render();
        announce(state.ui.boardCollapsed ? 'Task board collapsed.' : 'Task board expanded.');
    },
    /** Opens a lane's dropdown, closing any other, or closes it when it is open. */
    toggleLane(id) {
        state.ui.boardLane = state.ui.boardLane === id ? null : id;
        render();
    },
    setTaskFilter(id) {
        state.ui.taskFilter = id;
        render();
        if (id === 'all') window.requestAnimationFrame(() => $('task-filter-all')?.focus({ preventScroll: true }));
    },
    setMapPhase(phase) {
        state.ui.mapPhase = phase;
        render();
    },
    setRecordOpen(open) {
        state.ui.recordOpen = open;
    },
    setDetailsOpen(key, open) {
        if (open) state.ui.openDetails.add(key);
        else state.ui.openDetails.delete(key);
    },
    /** Opens the composer anchored to a row, or to a part of it with `detail` from the hover button or menu. */
    anchorComposer(rowId, closeSheet = false, detail = {}) {
        if (closeSheet) $('fileSheet').close();
        state.ui.composer = { text: state.ui.composer.text, anchor: rowId, part: detail.part ?? null, quote: detail.quote ?? null, title: detail.rowTitle ?? null };
        openSteer();
        render();
        window.requestAnimationFrame(() => $('composer-text')?.focus());
    },
    setComposer(patch, rerender = true) {
        const hadError = Boolean(state.ui.composer.error);
        Object.assign(state.ui.composer, patch, { error: null });
        if ('anchor' in patch && !patch.anchor) Object.assign(state.ui.composer, { part: null, quote: null, title: null });
        if (rerender || hadError) render();
        else {
            const submit = document.querySelector('.composer button[type="submit"]');
            if (submit) submit.disabled = !state.ui.composer.text.trim();
        }
    },
    async submitComposer() {
        const composer = state.ui.composer;
        try {
            const target = composer.anchor ? { id: composer.anchor, ...(composer.part ? { part: composer.part } : {}), ...(composer.quote ? { quote: composer.quote } : {}) } : undefined;
            await api('/api/feedback', { kind: 'comment', text: composer.text, target });
            announce('Comment added. It waits in Your feedback until you send or queue it.');
            state.ui.composer = { text: '', anchor: null, part: null, quote: null, title: null };
            await refresh();
            window.requestAnimationFrame(() => $('composer-text')?.focus());
        } catch (error) {
            state.ui.composer.error = error.message;
            render();
            announce(`Not added: ${error.message} Your text is kept.`);
        }
    },
    async requestTask(id, text) {
        try {
            await api('/api/feedback', { kind: 'task-request', text, target: { id } });
            announce('Request added. It waits in Review and send.');
            await refresh();
        } catch (error) {
            reportFailure(`Request not added: ${error.message}`);
        }
    },
    /** Opens Review and send from the header and prepares the exact text. */
    openSend() {
        const sheet = $('sendSheet');
        if (!state.data || sheet.open) return;
        state.ui.send.error = null;
        sendOpener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
        renderSendSheet();
        sheet.showModal();
        focusQuietly($('sendSheetTitle'));
        refreshSendPreview();
    },
    setSendNote(text) {
        state.ui.send.note = text;
        window.clearTimeout(sendNoteTimer);
        sendNoteTimer = window.setTimeout(refreshSendPreview, 400);
    },
    /**
     * Sends the listed items now as one chat message, or queues them for the agent's next
     * checkpoint, after checking the list still matches the text prepared for it.
     *
     * @param {'send' | 'queue'} [mode]
     */
    async send(mode = 'send') {
        const send = state.ui.send;
        const items = sendItems(context());
        if (!send.preview || previewKey(send.preview) !== itemsKey(items) || send.previewNote !== send.note) {
            const listChanged = Boolean(send.preview) && previewKey(send.preview) !== itemsKey(items);
            await refreshSendPreview();
            if (listChanged || !send.preview) {
                announce('The list changed. Check it, then send.');
                return;
            }
        }
        send.sending = true;
        send.busy = mode;
        send.error = null;
        renderSendSheet();
        try {
            const result = await api('/api/delivery', { items, digest: send.preview.digest, mode, ...(send.note.trim() ? { note: send.note } : {}) });
            const handle = state.data.canvas?.handle;
            Object.assign(state.ui.send, freshSend());
            $('sendSheet').close();
            announce(mode === 'queue'
                ? `Queued ${plural(result.queued.length, 'item')} for the agent. It collects them at its next checkpoint; until then, you can take them back from Your feedback.`
                : result.warning ?? `Sent ${plural(result.delivered.length, 'item')} to the agent. Look for “RPI canvas${handle ? ` ${handle}` : ''} sent” in the chat.`);
            await refresh();
        } catch (error) {
            send.sending = false;
            send.busy = null;
            if (error.code === 'preview_stale' && error.detail?.preview) {
                send.preview = error.detail.preview;
                send.previewNote = send.note;
                announce(`Your items changed since this opened. Check the list, then ${mode === 'queue' ? 'queue' : 'send'} again.`);
            } else {
                send.error = `${mode === 'queue' ? 'Not queued' : 'Not sent'}: ${error.message}`;
                announce(send.error);
            }
            renderSendSheet();
        }
    },
    /** Goes to what an item is about, showing its loop first when it is another one, and closes Review and send. */
    async goToFeedback(taskId, item) {
        const sheet = $('sendSheet');
        if (sheet.open) {
            keepFocusOnClose = true;
            sheet.close();
        }
        if (!taskId || taskId === state.data.session.task.id) {
            if (item.target?.id) navigate(item.target.id);
            return;
        }
        stopFollowing();
        const id = item.target?.id ?? null;
        pendingPlace = { taskId, taskTitle: taskId, phase: item.target?.phase ?? item.phase ?? null, id, label: id ?? undefined, scroll: 0, record: true };
        try {
            await api('/api/task', { taskId, follow: false });
            await refresh();
        } catch (error) {
            pendingPlace = null;
            reportFailure(`Could not go to ${item.id}: ${error.message}`);
        }
    },
    /** Edits an item where it was made: a suggested edit in its section's editor. */
    async editInPlace(taskId, item) {
        if (item.kind === 'edit' && item.target?.id && (!taskId || taskId === state.data.session.task.id)) {
            const sheet = $('sendSheet');
            if (sheet.open) {
                keepFocusOnClose = true;
                sheet.close();
            }
            navigate(item.target.id);
            act.startEdit(item.target.id);
            return;
        }
        await act.goToFeedback(taskId, item);
    },
    /** Arms a second-press button, or runs it when the second press is deliberate. */
    pressConfirm(key, onConfirm, armedLabel) {
        // A double click or a quick repeat lands inside the guard; only a deliberate press counts.
        const step = confirmPress(state.ui.confirm, key, Date.now());
        if (step === 'ignore') return;
        if (step === 'confirm') {
            clearConfirm();
            onConfirm();
            return;
        }
        clearConfirm(false);
        state.ui.confirm = { key, at: Date.now() };
        confirmTimer = window.setTimeout(() => {
            if (state.ui.confirm?.key !== key) return;
            clearConfirm();
            announce('Nothing was discarded.');
        }, CONFIRM_TIMEOUT_MS);
        render();
        announce(`${armedLabel} Press again to confirm, or wait and nothing is discarded.`);
    },
    disarmConfirm(key) {
        if (state.ui.confirm?.key !== key) return;
        clearConfirm();
        announce('Nothing was discarded.');
    },
    /** Disarms once focus has really left the button, not when a re-render replaced it with its twin. */
    confirmBlurred(key) {
        window.setTimeout(() => {
            if (state.ui.confirm?.key === key && document.activeElement?.dataset?.key !== key) clearConfirm();
        }, 0);
    },
    startFeedbackEdit(where, taskId, item) {
        clearConfirm(false);
        state.ui.feedbackEdit = { where, taskId, id: item.id, text: item.text ?? '', saving: false, error: null };
        render();
        window.requestAnimationFrame(() => {
            const field = $(`${feedbackEditBase(state.ui.feedbackEdit)}-text`);
            if (!field) return;
            field.focus();
            field.setSelectionRange(field.value.length, field.value.length);
        });
    },
    setFeedbackDraft(text) {
        if (state.ui.feedbackEdit) state.ui.feedbackEdit.text = text;
    },
    /** Saves an item's new words; in Review and send, the exact message is prepared again. */
    async saveFeedbackEdit() {
        const edit = state.ui.feedbackEdit;
        if (!edit || edit.saving) return;
        edit.saving = true;
        edit.error = null;
        render();
        try {
            feedbackBusy = true;
            await api('/api/feedback/edit', { taskId: edit.taskId, id: edit.id, text: edit.text });
            state.ui.feedbackEdit = null;
            await refresh();
            feedbackBusy = false;
            if ($('sendSheet').open) refreshSendPreview();
            announce(`Saved the new words of ${edit.id}.`);
            focusQuietly(document.querySelector(`[data-key="${CSS.escape(`${feedbackEditBase(edit, 'key')}`)}"]`));
        } catch (error) {
            feedbackBusy = false;
            edit.saving = false;
            edit.error = error.message;
            render();
            $(`${feedbackEditBase(edit)}-text`)?.focus();
        }
    },
    cancelFeedbackEdit() {
        const edit = state.ui.feedbackEdit;
        state.ui.feedbackEdit = null;
        render();
        if (edit) focusQuietly(document.querySelector(`[data-key="${CSS.escape(feedbackEditBase(edit, 'key'))}"]`));
    },
    /** Discards unsent items in any loop; Review and send closes when nothing is left in it. */
    async discardFeedback(items) {
        const sheet = $('sendSheet');
        const before = sendItems(context()).map((item) => `${item.taskId}:${item.id}`);
        let result;
        feedbackBusy = true;
        try {
            result = await api('/api/feedback/discard', { items });
            await refresh();
        } catch (error) {
            reportFailure(`Not discarded: ${error.message}`);
            return;
        } finally {
            feedbackBusy = false;
        }
        const told = discardMessage(result);
        const left = sendItems(context());
        if (sheet.open && !left.length) {
            sheet.close();
            announce(`${told} Nothing is waiting to send.`);
            return;
        }
        announce(told);
        if (!sheet.open) return;
        renderSendSheet();
        refreshSendPreview();
        // Focus moves to the item that took the discarded one's place, or the one before it.
        const index = before.indexOf(`${items[0].taskId}:${items[0].id}`);
        const keys = left.map((item) => `${item.taskId}:${item.id}`);
        const next = keys.find((key) => before.indexOf(key) > index) ?? keys.findLast((key) => before.indexOf(key) < index);
        const [taskId, id] = next ? [next.slice(0, next.lastIndexOf(':')), next.slice(next.lastIndexOf(':') + 1)] : [];
        focusQuietly((next && sheet.querySelector(`[data-key="${CSS.escape(`review-discard-${taskId}-${id}`)}"]`)) || $('sendSheetTitle'));
    },
    /** Discards everything Review and send lists, then closes it. */
    async discardAll() {
        const items = sendItems(context());
        if (!items.length) return;
        let result;
        feedbackBusy = true;
        try {
            result = await api('/api/feedback/discard', { items });
        } catch (error) {
            reportFailure(`Not discarded: ${error.message}`);
            return;
        } finally {
            feedbackBusy = false;
        }
        $('sendSheet').close();
        await refresh();
        announce(discardMessage(result));
    },
    /** Opens a change's file in the sheet, from the changes record Implement shows, which may be an earlier, read-only one. */
    openFile(changeId, path) {
        const ctx = viewContext('implement');
        const change = ctx.data.session.implementation.changes.find((item) => item.id === changeId);
        const file = change?.files.find((item) => item.path === path);
        if (!file) return;
        const sheet = $('fileSheet');
        sheet.classList.remove('is-source');
        sheet.replaceChildren(...filePreview(ctx, change, file));
        sheet.showModal();
    },
    /** Shows a workspace file in the sheet at the cited place, or why it cannot be shown. */
    async openSource(path, anchor) {
        const sheet = $('fileSheet');
        try {
            const result = await api('/api/source', { path, ...(anchor ? { anchor } : {}) });
            sheet.replaceChildren(...sourceSheet(context(), result));
        } catch (error) {
            sheet.replaceChildren(...sourceProblem(context(), path, error.message));
        }
        sheet.classList.add('is-source');
        if (!sheet.open) sheet.showModal();
        // Only the file pane scrolls, so the cited line is centered in it rather than in the dialog.
        window.requestAnimationFrame(() => {
            const view = sheet.querySelector('.source-view');
            const cited = view?.querySelector('.source-line.is-cited');
            if (view && cited) view.scrollTop = Math.max(0, cited.offsetTop - (view.clientHeight - cited.offsetHeight) / 2);
        });
    },
    /** Opens a workspace file in the editor at the cited place and says where it opened. */
    async openInEditor(path, anchor) {
        try {
            const result = await api('/api/open', { path, ...(anchor ? { anchor } : {}) });
            announce(`Opened ${result.path} at line ${result.line} in ${state.data?.editor?.name ?? 'your editor'}.`);
        } catch (error) {
            reportFailure(`${path} did not open: ${error.message}`);
        }
    },
    async copy(text, what = 'Path') {
        try {
            await navigator.clipboard.writeText(text);
            announce(`${what} copied.`);
        } catch {
            announce(`Copy is not available here; select the ${what.toLowerCase()} to copy it.`);
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
    const parent = rpi && task.parent ? session.followUps.tree.tasks.find((item) => item.id === task.parent) ?? { id: task.parent, title: task.parent } : null;
    const handle = state.data.canvas?.handle ?? null;
    const named = handle ? ` Messages this canvas sends to the agent start with “RPI canvas ${handle}”.` : '';
    // The badge names the canvas the way its chat messages do; it has its own slot, so it is never clipped.
    const badge = rpi ? h('span', { class: 'badge tone-muted session-badge', title: `RPI canvas${handle ? ` ${handle}` : ''}: shows the RPI files from ${source.statePath}.${named}` }, icon('message'), handle ? [sr('RPI canvas '), h('code', { class: 'canvas-handle', text: handle })] : 'RPI session') : handle ? h('span', { class: 'canvas-chip', title: named.trim() }, 'Canvas ', h('code', { class: 'canvas-handle', text: handle })) : null;
    const slot = $('canvasBadge');
    slot.hidden = !badge;
    clear(slot).append(...(badge ? [badge] : []));
    clear($('taskMeta')).append(...[
        rpi ? h('code', { class: 'task-id', title: `Task ID: ${task.id}`, text: task.id }) : null,
        where ? h('span', { class: 'task-where', title: where, text: where }) : null,
        parent ? h('span', { class: 'task-parent' }, 'Child of ', h('button', { type: 'button', class: 'link-btn', title: `Show the parent task: ${parent.title}`, dataset: { key: 'header-parent' }, 'aria-label': `Child of ${parent.title}: show the parent task`, onclick: () => act.showTask(parent.statePath ? { statePath: parent.statePath } : parent.id) }, parent.title)) : null,
        session.scenario?.sample ? h('span', { class: 'badge tone-muted sample-badge', title: 'Mock data for the canvas preview' }, icon('info'), 'Sample session') : null,
    ].filter(Boolean));
    renderSessionControls();
    const count = view.attentionCount;
    const needs = $('needsBtn');
    needs.classList.toggle('has-items', count > 0);
    $('needsCount').textContent = String(count);
    $('needsLabel').textContent = count ? 'Needs you' : 'All clear';
    needs.setAttribute('aria-label', count ? `${plural(count, 'item')} ${count === 1 ? 'needs' : 'need'} you` : 'Nothing needs you');
}

/** The session button: the session's name and how many loops it has. */
function renderSessionControls() {
    const { session } = state.data;
    const tree = session.followUps.tree;
    const name = tree.name ?? session.task.title;
    const loops = tree.tasks.length;
    const btn = $('sessionBtn');
    btn.hidden = false;
    $('sessionLabel').textContent = `${name} · ${plural(loops, 'loop')}`;
    btn.setAttribute('aria-label', `Session ${name}, ${plural(loops, 'loop')}. Show its loops${session.source?.kind === 'rpi' ? ' and other sessions' : ''}.`);
    btn.title = `Session “${name}”: ${plural(loops, 'loop')}${tree.key ? ` in ${tree.key}` : ''}`;
}

/** Opens or closes the session menu: this session's loops, then the workspace's other sessions. */
function toggleSessionMenu(open) {
    const menu = $('sessionMenu');
    const show = open ?? menu.hidden;
    if (show && !state.data) return;
    menu.hidden = !show;
    $('sessionBtn').setAttribute('aria-expanded', String(show));
    if (!show) return;
    renderSessionMenu();
    focusQuietly($('sessionMenuTitle'));
    if (state.data.session.source?.kind === 'rpi') loadSessions();
}

async function loadSessions() {
    state.sessions = { ...state.sessions, loading: true, error: null };
    renderSessionList();
    try {
        const result = await api('/api/sessions');
        state.sessions = { loading: false, error: null, list: result.sessions, skipped: result.skipped ?? [] };
    } catch (error) {
        state.sessions = { ...state.sessions, loading: false, error: error.message };
    }
    renderSessionList();
}

function renderSessionMenu() {
    const menu = $('sessionMenu');
    const { session } = state.data;
    const tree = session.followUps.tree;
    const rpi = session.source?.kind === 'rpi';
    const where = [tree.key, rpi ? (state.following === false ? 'not following the agent' : 'following the agent') : 'sample session'].filter(Boolean).join(' · ');
    const keepFocus = menu.contains(document.activeElement) ? document.activeElement.dataset.key ?? null : null;
    menu.replaceChildren(
        h('h2', { class: 'menu-title session-menu-title', id: 'sessionMenuTitle', tabindex: '-1' }, icon('nodes'), tree.name ? `Session: ${tree.name}` : 'This session'),
        h('p', { class: 'meta session-menu-where', text: where }),
        h('h3', { class: 'menu-subtitle', text: 'Loops in this session' }),
        sessionTree(context(), {
            label: `Loops in ${tree.name ?? 'this session'}, parent first`,
            keyPrefix: 'menu',
            onShow: (task) => {
                toggleSessionMenu(false);
                act.showTask({ statePath: task.statePath });
            },
        }),
        ...(rpi ? [h('h3', { class: 'menu-subtitle', text: 'Other sessions' }), h('div', { id: 'sessionList' })] : []),
        h('p', { class: 'menu-note', text: rpi ? 'Choosing a loop or session stops following the agent; choose Follow agent at the top to catch up with it.' : 'The sample has no other loops or sessions to show.' }));
    if (rpi) renderSessionList();
    if (keepFocus) menu.querySelector(`[data-key="${CSS.escape(keepFocus)}"]`)?.focus({ preventScroll: true });
}

function renderSessionList() {
    const holder = $('sessionList');
    if (!holder || !state.data) return;
    const current = state.data.session.followUps.tree.key;
    const { loading, error, list, skipped } = state.sessions;
    const others = (list ?? []).filter((item) => item.key !== current);
    holder.replaceChildren(...[
        error ? h('p', { class: 'field-error' }, icon('alert'), h('span', { text: `Sessions could not be listed: ${error}` })) : null,
        !error && loading && !list ? h('p', { class: 'meta', text: 'Loading sessions…' }) : null,
        list && !others.length ? h('p', { class: 'meta', text: 'No other sessions in this workspace.' }) : null,
        others.length ? h('ul', { class: 'session-list', 'aria-label': 'Other sessions, most recent first' }, others.map((item) => h('li', null,
            h('button', { type: 'button', class: 'session-pick', dataset: { key: `session-${item.key}` }, onclick: () => act.switchSession(item.key) },
                h('span', { class: 'session-pick-name', text: item.name }),
                h('span', { class: 'meta session-pick-meta', text: [item.date, plural(item.tasks, 'loop'), item.running ? `running: ${item.running.title}` : 'nothing running'].join(' · ') }))))) : null,
        skipped.length ? h('p', { class: 'meta', text: `${plural(skipped.length, 'state file')} outside a session folder ${skipped.length === 1 ? 'is' : 'are'} not shown; the problems notice lists ${skipped.length === 1 ? 'it' : 'them'}.` }) : null,
    ].filter(Boolean));
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
                // Alt with an arrow is Back or Forward, handled by the page.
                if (!(event.key in moves) || event.altKey || event.ctrlKey || event.metaKey) return;
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
    const phase = state.ui.phase;
    // The outline lists the shown document, which may be an earlier one, and stays inside it.
    const scope = scopeOf(phase);
    const earlier = scope?.doc ?? null;
    const ctx = viewContext(phase);
    const items = phaseReached(phase) || earlier ? VIEWS[phase].outline(ctx) : [];
    const filter = state.ui.navFilter.trim().toLowerCase();
    const shown = items.filter((item) => !filter || `${item.prefix ?? ''} ${item.label}`.toLowerCase().includes(filter));
    clear($('navBody')).append(
        h('h2', { class: 'nav-title', text: `${PHASE_META[phase].label} outline` }),
        shown.length ? h('ul', { class: 'nav-list' }, shown.map((item) => h('li', null, h('button', { type: 'button', class: 'nav-item', onclick: () => navigate(item.id, phase, { keepDocument: Boolean(earlier), scope }) },
            item.prefix ? idTag(item.prefix, 'go-to') : null,
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
    // The file and time are the shown document's, which may be an earlier one.
    const record = viewContext(phase).data.session.phases[phase];
    const meta = PHASE_STATUS[record.status] ?? PHASE_STATUS.upcoming;
    // The agent's next step shows where it works; the Live control follows it from anywhere.
    const side = session.session.activePhase === phase && session.session.nextAction
        ? h('p', { class: 'next-action' }, icon('arrow-right'), h('span', { text: session.session.nextAction }))
        : null;
    const { back, forward } = places.peek();
    const phaseLabel = (key) => PHASE_META[key]?.label ?? key;
    const travelButton = (direction, place) => {
        const label = place ? placeLabel(direction, place, session.task.id, phaseLabel) : direction === 'back' ? 'Back: no earlier place yet' : 'Forward: no later place';
        return button(label, {
            iconName: direction === 'back' ? 'arrow-left' : 'arrow-right',
            hideLabel: true,
            disabled: !place,
            title: `${label} (Alt+${direction === 'back' ? 'Left' : 'Right'})`,
            attrs: { 'data-key': `history-${direction}`, 'aria-keyshortcuts': direction === 'back' ? 'Alt+ArrowLeft' : 'Alt+ArrowRight' },
            onClick: () => travel(direction),
        });
    };
    // Native append writes null as text, so the side panel is added only when there is one.
    clear($('contextBar')).append(...[
        h('div', { class: 'context-main' },
            h('span', { class: 'history-nav', role: 'group', 'aria-label': 'Back and forward' }, travelButton('back', back), travelButton('forward', forward)),
            h('h2', { class: 'context-title' }, icon(PHASE_META[phase].icon), PHASE_META[phase].label),
            badge(meta),
            documentSwitcher(phase),
            record.artifact ? h('span', { class: 'context-artifact' },
                h('code', { class: 'context-path', title: record.artifact, text: record.artifact }),
                button('Copy artifact path', { iconName: 'copy', hideLabel: true, onClick: () => act.copy(record.artifact) }),
                editorButton(context(), record.artifact, null, 'open-artifact')) : null,
            record.updatedAt ? h('span', { class: 'meta', title: session.source?.kind === 'rpi' ? `The file last changed ${fullTime(record.updatedAt)}. The canvas reads it again whenever it changes.` : fullTime(record.updatedAt) }, 'Updated ', relTime(record.updatedAt, context().now)) : null),
        side ? h('div', { class: 'context-side' }, side) : null,
    ].filter(Boolean));
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
    const earlier = DOCUMENT_NOUNS[phase] ? shownEarlier(phase) : null;
    if (!phaseReached(phase) && !earlier) {
        const previous = PHASES[PHASES.indexOf(phase) - 1];
        const others = DOCUMENT_NOUNS[phase] && documentsOf(phase).some((doc) => !doc.current && doc.snapshot);
        body.append(h('div', { class: 'empty-state' },
            icon(PHASE_META[phase].icon, { className: 'empty-icon' }),
            h('h3', { text: `${PHASE_META[phase].label} has not started` }),
            h('p', { text: `It appears here when ${previous ? PHASE_META[previous].label : 'the session'} is ready. The agent writes it and asks you about anything it cannot decide from evidence.` }),
            others ? h('p', { text: `Earlier ${DOCUMENT_NOUNS[phase]}s from this session are in the Document list above.` }) : null,
            button(`Go to ${PHASE_META[state.data.session.session.activePhase].label}`, { kind: 'primary', iconName: 'arrow-right', onClick: () => setPhase(state.data.session.session.activePhase) })));
        return;
    }
    if (earlier) body.append(earlierNotice(phase, earlier));
    body.toggleAttribute('data-readonly', false);
    if (earlier) body.dataset.readonly = 'true';
    body.append(...VIEWS[phase].renderView(viewContext(phase)));
}

/**
 * The context the shown phase renders with: when the reader chose an earlier document, that
 * document in place of the current work's, read-only, with its own traces, and with lookups
 * and moves that start inside it and its work.
 *
 * @param {string} phase
 */
function viewContext(phase) {
    const ctx = context();
    const scope = scopeOf(phase);
    if (!scope) return ctx;
    return {
        ...ctx,
        data: { ...ctx.data, session: composeDocument(ctx.data.session, phase, scope.doc), view: { ...ctx.data.view, traces: scope.doc.snapshot.traces ?? {} } },
        readOnly: true,
        find: (ref) => scopedFind(scope, ref),
        resolve: (ref) => scopedResolve(scope, ref),
        act: { ...act, navigate: (ref, phaseOverride, options = {}) => navigate(ref, phaseOverride, { ...options, scope }) },
    };
}

/** Says an earlier document shows, names the current work's, and offers it. */
function earlierNotice(phase, earlier) {
    const current = documentsOf(phase).find((doc) => doc.current) ?? null;
    const noun = DOCUMENT_NOUNS[phase];
    const planless = phase === 'implement' && pairedPlanOf(state.data.session, earlier).missing;
    return h('div', { class: 'notice tone-accent doc-notice', role: 'note' },
        h('p', { class: 'notice-title' }, icon('file'), h('span', { text: `You are reading an earlier ${noun}: ${documentLabel(earlier)}.` })),
        h('p', { text: current
            ? `The agent works from the current ${noun}, ${documentLabel(current)}. This one is read-only here: to change something, comment on the current ${noun} or ask the agent.`
            : `The current work has no ${noun} yet. This one is read-only here: to change something, ask the agent.` }),
        planless ? h('p', { text: "Its plan is not in this session's Plan list, so its tasks do not show." }) : null,
        h('div', { class: 'btn-row' }, button(current ? `Show the current ${noun}` : 'Back to the current work', { kind: 'primary', iconName: 'arrow-right', attrs: { 'data-key': `doc-current-${phase}` }, onClick: () => act.showDocument(phase, 0) })));
}

/** The switcher between a phase's documents, by name and time, when the phase has an earlier one; Review groups them by work. */
function documentSwitcher(phase) {
    const now = context().now;
    const choices = documentChoices(state.data.session, phase, state.ui.docs?.[phase], (doc) => relTime(doc.updatedAt, now));
    if (!choices) return null;
    const option = (item) => h('option', { value: String(item.value), selected: item.value === choices.selected, disabled: item.disabled, title: item.title ?? undefined, text: item.text });
    return h('label', { class: 'doc-switch' },
        h('span', { class: 'doc-switch-label', text: 'Document' }),
        h('select', { class: 'doc-select', dataset: { key: `doc-switch-${phase}` }, onchange: (event) => act.showDocument(phase, Number(event.target.value)) },
            choices.groups.map((group) => (group.label ? h('optgroup', { label: group.label }, group.options.map(option)) : group.options.map(option)))));
}

function renderSteer() {
    const ctx = context();
    clear($('steerBody')).append(...steerPanel(ctx));
}

// Review and send

/** The control that opened Review and send, so closing returns focus there. */
let sendOpener = null;

/** True while a discard or edit is in flight, when a re-render must not prepare a message from half-changed loops. */
let feedbackBusy = false;

/** An armed second-press button goes back after this long. */
const CONFIRM_TIMEOUT_MS = 4000;
let confirmTimer = 0;

/** Disarms the second-press button, re-rendering unless the caller is about to. */
function clearConfirm(rerender = true) {
    window.clearTimeout(confirmTimer);
    if (!state.ui.confirm) return;
    state.ui.confirm = null;
    if (rerender) render();
}

/** The ID base of an item's inline editor, or its Edit button's key with `key`. */
function feedbackEditBase(edit, part = 'base') {
    if (part === 'key') return edit.where === 'dialog' ? `review-edit-${edit.taskId}-${edit.id}` : `fb-edit-${edit.id}`;
    return `${edit.where === 'dialog' ? 'review' : 'fb'}-edit-${edit.taskId}-${edit.id}`;
}

/** What a discard did, in words. */
function discardMessage(result) {
    const done = result.discarded.length;
    const skipped = result.skipped.length;
    return `${done === 1 ? `Discarded ${result.discarded[0].id}.` : `Discarded ${plural(done, 'item')}.`}${skipped ? ` ${plural(skipped, 'item')} could not be discarded because ${skipped === 1 ? 'it was' : 'they were'} sent or being sent.` : ''}`;
}
let sendNoteTimer = 0;
let previewRequest = 0;
let keepFocusOnClose = false;

const itemsKey = (items) => items.map((item) => `${item.taskId}:${item.id}`).join();
const previewKey = (preview) => (preview?.parts ?? []).flatMap((part) => part.ids.map((id) => `${part.taskId}:${id}`)).join();

/** Fetches the exact text for the current list and message, then shows it in the open dialog. */
async function refreshSendPreview() {
    const send = state.ui.send;
    const items = state.data ? sendItems(context()) : [];
    const request = ++previewRequest;
    if (!items.length) {
        send.preview = null;
        renderSendSheet();
        return;
    }
    const note = send.note;
    try {
        const preview = await api('/api/delivery/preview', { items, ...(note.trim() ? { note } : {}) });
        if (request !== previewRequest) return;
        send.preview = preview;
        send.previewNote = note;
        send.error = null;
    } catch (error) {
        if (request !== previewRequest) return;
        send.preview = null;
        send.error = error.message;
    }
    updateSendPreview();
}

/** Updates the exact text and Send in place, so typing a message is never interrupted. */
function updateSendPreview() {
    const sheet = $('sendSheet');
    if (!sheet.open) return;
    const pre = $('send-preview');
    const confirm = sheet.querySelector('[data-key="send-confirm"]');
    const error = $('send-error');
    if (!pre || !confirm || Boolean(error) !== Boolean(state.ui.send.error)) {
        renderSendSheet();
        return;
    }
    pre.textContent = state.ui.send.preview?.prompt ?? 'Preparing the message…';
    confirm.disabled = state.ui.send.sending || !state.ui.send.preview;
    const queue = sheet.querySelector('[data-key="send-queue"]');
    if (queue) queue.disabled = confirm.disabled;
}

/** Rebuilds the open dialog, keeping focus, selection, and the exact-text disclosure where they were. */
function renderSendSheet() {
    const sheet = $('sendSheet');
    if (!state.data) return;
    const active = sheet.contains(document.activeElement) ? document.activeElement : null;
    const key = active ? { id: active.id || null, dataKey: active.dataset?.key ?? null, selection: typeof active.selectionStart === 'number' ? [active.selectionStart, active.selectionEnd] : null } : null;
    const exactOpen = sheet.querySelector('details.send-exact')?.open ?? false;
    sheet.replaceChildren(...reviewSheet(context()));
    const details = sheet.querySelector('details.send-exact');
    if (details) details.open = exactOpen;
    if (!key) return;
    const target = (key.id && $(key.id)) || (key.dataKey && sheet.querySelector(`[data-key="${CSS.escape(key.dataKey)}"]`));
    if (target && !target.disabled) {
        target.focus({ preventScroll: true });
        if (key.selection && typeof target.setSelectionRange === 'function') target.setSelectionRange(key.selection[0], key.selection[1]);
    } else {
        focusQuietly($('sendSheetTitle'));
    }
}

function onSendClose() {
    window.clearTimeout(sendNoteTimer);
    if (state.ui.feedbackEdit?.where === 'dialog') state.ui.feedbackEdit = null;
    clearConfirm(false);
    const opener = sendOpener;
    sendOpener = null;
    if (keepFocusOnClose) {
        keepFocusOnClose = false;
        return;
    }
    if (opener?.isConnected && usable(opener)) opener.focus({ preventScroll: true });
    else $('sendBtn').focus({ preventScroll: true });
}

/** The header button counts what waits for you; items you queued for the agent only show in its words. */
function renderSendButton() {
    const ctx = context();
    const waiting = waitingCount(ctx);
    const queued = sendItems(ctx).length - waiting;
    const sendBtn = $('sendBtn');
    sendBtn.classList.toggle('has-items', waiting > 0);
    $('sendCount').textContent = String(waiting);
    const inQueue = queued ? `${plural(queued, 'item')} queued for the agent` : '';
    sendBtn.setAttribute('aria-label', `Review and send, ${waiting ? `${plural(waiting, 'item')} waiting` : 'nothing waiting'}${inQueue ? `, ${inQueue}` : ''}`);
    sendBtn.title = waiting
        ? `Review and send ${plural(waiting, 'item')} to the agent${inQueue ? `; ${inQueue}` : ''}`
        : inQueue ? `${inQueue}. Open to send ${queued === 1 ? 'it' : 'them'} now.` : 'Nothing to send yet. Answer, comment, or suggest an edit first.';
}

/** The CSS selector for a board lane. */
const laneSelector = (lane) => `[data-lane="${CSS.escape(lane)}"]`;

/** Closes the open lane's dropdown, moving focus to its button when asked. */
function closeLane(returnFocus) {
    const lane = state.ui.boardLane;
    if (!lane) return;
    state.ui.boardLane = null;
    render();
    if (returnFocus) document.querySelector(`[data-key="board-lane-${CSS.escape(lane)}"]`)?.focus({ preventScroll: true });
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

// Not connected

/** Shows the Not connected screen: the canvas has no session until the agent connects it. */
function showNotConnected(next) {
    const entering = !state.notConnected;
    state.notConnected = next;
    state.data = null;
    state.error = null;
    applyPreferences(next.preferences);
    render();
    if (entering) announce('This canvas is not connected to an RPI session. Ask the agent to connect it.');
}

/** Leaves the screen once the agent connects the canvas; the next render shows the workspace. */
function leaveNotConnected() {
    state.notConnected = null;
    state.ui.connect = { asking: false, askedAt: 0, retryAfterMs: 30000, error: null, helpOpen: false };
    document.body.classList.remove('is-not-connected');
    $('workspace').hidden = false;
    $('document').hidden = false;
    clear($('connectView')).hidden = true;
}

/** The screen's actions: ask the agent, copy the request or the details, or show the sample. */
const connectScreen = {
    async ask() {
        const { asking, askedAt, retryAfterMs: wait } = state.ui.connect;
        if (asking || (askedAt > 0 && Date.now() - askedAt < wait)) return;
        state.ui.connect = { ...state.ui.connect, asking: true, error: null };
        render();
        try {
            const result = await api('/api/connect-request', {});
            const retryAfterMs = result.retryAfterMs ?? 30000;
            state.ui.connect = { ...state.ui.connect, asking: false, askedAt: Date.now(), retryAfterMs };
            announce('Asked the agent to connect this canvas. This page changes once it does.');
            window.setTimeout(() => {
                if (state.notConnected) render();
            }, retryAfterMs + 50);
        } catch (error) {
            const message = error.code === 'too_soon'
                ? 'The agent was just asked. Give it a moment, or copy the request and paste it in the chat.'
                : `The request was not sent: ${error.message.replace(/\.$/, '')}. Copy it and paste it in the chat instead.`;
            state.ui.connect = { ...state.ui.connect, asking: false, error: message };
        }
        render();
    },
    copyRequest() {
        act.copy(state.notConnected?.notConnected.request ?? '', 'Request');
    },
    copyDetails(text) {
        act.copy(text, 'Details');
    },
    async showSample() {
        try {
            await api('/api/sample', {});
            announce('Showing the sample session, which uses made-up data.');
            await refresh();
        } catch (error) {
            state.ui.connect = { ...state.ui.connect, error: `The sample could not open: ${error.message}` };
            render();
        }
    },
    toggleHelp(open) {
        state.ui.connect.helpOpen = open;
    },
};

/** Renders the screen in place of the workspace; the header keeps the title, the canvas handle, and Appearance. */
function renderNotConnected() {
    const answer = state.notConnected;
    const focused = document.activeElement?.closest?.('#connectView [data-key]')?.dataset.key ?? null;
    document.body.classList.add('is-not-connected');
    $('workspace').hidden = true;
    // A page may have only one main element without the hidden attribute.
    $('document').hidden = true;
    $('taskTitle').textContent = 'RPI Workflow';
    document.title = 'RPI Workflow: not connected';
    const handle = answer.canvas?.handle ?? null;
    const slot = $('canvasBadge');
    slot.hidden = !handle;
    clear(slot).append(...(handle ? [h('span', { class: 'canvas-chip', title: `Messages this canvas sends to the agent start with “RPI canvas ${handle}”.` }, 'Canvas ', h('code', { class: 'canvas-handle', text: handle }))] : []));
    clear($('taskMeta')).append(h('span', { class: 'badge tone-attention' }, icon('plug'), 'Not connected'));
    $('sessionBtn').hidden = true;
    const view = $('connectView');
    view.hidden = false;
    clear(view).append(notConnectedView({ ...answer.notConnected, handle, editor: answer.editor?.name ?? null, now: Date.now(), ui: state.ui.connect }, connectScreen));
    if (focused) view.querySelector(`[data-key="${CSS.escape(focused)}"]`)?.focus({ preventScroll: true });
}

/** Renders the page; a failure shows its reason with Retry instead of leaving the page blank. */
function render() {
    try {
        renderPage();
    } catch (error) {
        showRenderFailure(error);
        return;
    }
    if (state.renderError) {
        state.renderError = null;
        reportEnvironment();
    }
}

/** Says why the page could not render and reports it, so the agent sees it in `get_state`. */
function showRenderFailure(error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('The RPI Workflow canvas could not render this task.', error);
    state.renderError = message;
    clear($('docBody')).append(h('div', { class: 'notice tone-danger', role: 'alert' },
        h('p', { class: 'notice-title' }, icon('alert'), 'The canvas could not show this task.'),
        h('p', { text: `${message.replace(/\.$/, '')}. Retry, or reopen the canvas; the agent can see this problem too.` }),
        h('div', { class: 'btn-row' }, button('Retry', { iconName: 'loop', onClick: refresh }))));
    reportEnvironment();
}

/** Keeps the document's scroll offsets equal to what is pinned at its top: the context bar and, on Implement, the task board. */
const offsets = typeof ResizeObserver === 'function' ? new ResizeObserver(() => syncOffsets()) : null;

function syncOffsets() {
    const doc = $('document');
    const dock = doc.querySelector('.board-dock');
    const pinned = dock && window.getComputedStyle(dock).position === 'sticky';
    doc.style.setProperty('--rw-context-h', `${$('contextBar').offsetHeight}px`);
    doc.style.setProperty('--rw-dock-h', `${pinned ? dock.offsetHeight : 0}px`);
}

function watchOffsets() {
    if (!offsets) return;
    offsets.disconnect();
    offsets.observe($('document'));
    offsets.observe($('contextBar'));
    const dock = $('document').querySelector('.board-dock');
    if (dock) offsets.observe(dock);
    syncOffsets();
}

function renderPage() {
    if (state.notConnected) {
        renderNotConnected();
        return;
    }
    if (!state.data) {
        renderDocument();
        return;
    }
    const key = focusKey();
    const doc = $('document');
    const scroll = doc.scrollTop;
    const steerScroll = $('steer').scrollTop;
    const lane = state.ui.boardLane;
    const laneScroll = lane ? $(`board-drop-${lane}`)?.scrollTop ?? 0 : 0;
    renderHeader();
    renderSendButton();
    renderRail();
    renderNavigator();
    renderContextBar();
    renderDocument();
    renderSteer();
    watchOffsets();
    doc.scrollTop = scroll;
    $('steer').scrollTop = steerScroll;
    if (lane && $(`board-drop-${lane}`)) $(`board-drop-${lane}`).scrollTop = laneScroll;
    restoreFocus(key);
    applyPanels();
    if ($('sendSheet').open) {
        renderSendSheet();
        // While a discard or edit is in flight, its own refresh prepares the message once it lands.
        if (!feedbackBusy && itemsKey(sendItems(context())) !== previewKey(state.ui.send.preview)) refreshSendPreview();
    }
    if (!$('sessionMenu').hidden) renderSessionMenu();
    previews?.refresh();
    tooltips?.refresh();
    anchors?.hide();
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
        reportFailure(`Appearance not saved: ${error.message}`);
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
    ['n', 'Go to the first item that needs you, then the next'],
    ['f', 'Follow the agent, or stop following'],
    ['[ and ]', 'Previous and next row'],
    ['e', "Suggest an edit to the focused row's section"],
    ['c', 'Comment on the focused row'],
    ['/', 'Open the navigator and filter it'],
    ['b', 'Show or hide the navigator'],
    ['s', 'Show or hide the steering panel'],
    ['Alt+Left and Alt+Right', 'Go back and forward through the places you moved to'],
    ['l', 'Show what the IDs and icons mean'],
    ['Shift+F10', 'Open the canvas menu for the focused item; Shift with a right-click opens the host menu'],
    ['?', 'Show this list'],
    ['Escape', 'Close a menu, drawer, or dialog, or leave the section editor'],
];

/** Opens the legend, building it on first use; closing returns focus to where it was. */
function openLegend() {
    const dialog = $('legendDialog');
    if (!dialog.childElementCount) dialog.append(...legendContent());
    dialog.showModal();
}

/** The document row that holds focus, if any; row shortcuts never guess. */
function focusedRow() {
    return document.activeElement?.closest('#docBody .row') ?? null;
}

/** Single-key shortcut hints follow the shortcut switch. */
function applyShortcutHints() {
    const hints = [[$('shortcutsBtn'), '?'], [$('legendBtn'), 'l'], [$('navFilter'), '/']];
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
        } else if (!$('sessionMenu').hidden) {
            toggleSessionMenu(false);
            $('sessionBtn').focus();
        } else if (state.ui.boardLane) {
            const active = document.activeElement;
            closeLane(!active || active === document.body || Boolean(active.closest('[data-lane]')));
        } else if (state.ui.drawer) {
            closeDrawer(true);
        } else if (state.ui.editing && document.activeElement?.closest('.editor')) {
            act.requestCancelEdit();
        }
        return;
    }
    const typing = event.target.closest?.('input, textarea, select, [contenteditable="true"]');
    if (event.altKey && !event.ctrlKey && !event.metaKey && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')) {
        if (!typing && state.data && !document.querySelector('dialog[open]')) {
            event.preventDefault();
            travel(event.key === 'ArrowLeft' ? 'back' : 'forward');
        }
        return;
    }
    if (typing || event.metaKey || event.ctrlKey || event.altKey || !state.ui.shortcuts || !state.data || document.querySelector('dialog[open]')) return;
    const key = event.key;
    if (key >= '1' && key <= '5') {
        setPhase(PHASES[Number(key) - 1]);
        $('phaseRail').querySelector('[aria-selected="true"]')?.focus();
    } else if (key === 'n') {
        nextAttention();
    } else if (key === 'f') {
        toggleFollowing();
    } else if (key === '[' || key === ']') {
        moveRow(key === ']' ? 1 : -1);
    } else if (key === 'e' || key === 'c') {
        const row = focusedRow();
        if (!row) {
            announce('Move to a row first, for example with ] or by selecting it.');
        } else if (row.closest('[data-readonly="true"]')) {
            announce('This document is read-only here. Show the current one to comment or suggest an edit.');
        } else if (key === 'c') {
            act.anchorComposer(row.dataset.row);
        } else {
            const editButton = row.querySelector(`[data-key="edit-section-${CSS.escape(row.dataset.row)}"]`);
            if (editButton) editButton.click();
            else announce('This row has no section to suggest an edit to. Use c to comment on it.');
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
    } else if (key === 'l') {
        openLegend();
    } else if (key === '?') {
        $('shortcutsDialog').showModal();
    } else {
        return;
    }
    event.preventDefault();
}

/** Decisions waiting for you in phase order, then in the files' order. */
function attentionItems() {
    const { view } = state.data;
    const order = (phase) => (PHASES.includes(phase) ? PHASES.indexOf(phase) : PHASES.length);
    return view.needsYou.map((item, index) => ({ id: item.id, phase: item.phase, index }))
        .sort((a, b) => order(a.phase) - order(b.phase) || a.index - b.index).map((item) => item.id);
}

/**
 * Needs you: goes to the first waiting item, or to the next one when the reader is still on
 * the item it went to last. Answering an item removes it, so the next press finds the new first.
 */
function nextAttention() {
    if (!state.data) return;
    const items = attentionItems();
    if (!items.length) {
        openSteer();
        window.requestAnimationFrame(() => focusQuietly($('steer-needs')));
        announce('Nothing needs you right now.');
        return;
    }
    const still = state.ui.lastNeeds && state.ui.place?.id === state.ui.lastNeeds ? items.indexOf(state.ui.lastNeeds) : -1;
    const next = items[still >= 0 ? (still + 1) % items.length : 0];
    state.ui.lastNeeds = next;
    navigate(next);
    if (items.length > 1) announce(`${items.indexOf(next) + 1} of ${items.length} waiting for you.`);
}

/**
 * What the canvas menu offers for what was right-clicked or focused: comments and edits for
 * the row, the ID, file, or link under it, then copy, Back, Forward, and the legend.
 *
 * @param {Element} target
 */
function menuItemsFor(target) {
    const items = [];
    const selected = window.getSelection?.()?.toString().trim() ?? '';
    if (selected) items.push({ label: 'Copy', icon: 'copy', onSelect: () => act.copy(selected, 'Text') });
    const ready = Boolean(state.data);
    const part = ready ? anchorAt(target) : null;
    // An earlier document is read-only, so its rows offer no comments or edits.
    const row = ready && $('docBody').contains(target) && !target.closest('[data-readonly="true"]') ? target.closest('[data-row]') : null;
    if (part) items.push({ label: `Comment on ${part.part}`, icon: 'message', onSelect: () => act.anchorComposer(part.rowId, false, part) });
    if (row?.dataset.row) {
        const rowId = row.dataset.row;
        const rowTitle = row.querySelector('.row-title')?.textContent?.trim() ?? rowId;
        items.push({ label: 'Comment on this section', icon: 'message', shortcut: state.ui.shortcuts ? 'c' : undefined, onSelect: () => act.anchorComposer(rowId, false, { rowTitle }) });
        const edit = row.querySelector(`[data-key="edit-section-${CSS.escape(rowId)}"]`);
        if (edit) items.push({ label: 'Suggest an edit to this section', icon: 'pencil', shortcut: state.ui.shortcuts ? 'e' : undefined, onSelect: () => edit.click() });
    }
    const chip = target.closest('[data-preview]');
    // A chip inside an earlier document means that document's item first.
    const scope = chip && ($('docBody').contains(chip) || $('navBody').contains(chip)) ? scopeOf(state.ui.phase) : null;
    const item = ready && chip?.dataset.preview ? (scope ? scopedFind(scope, chip.dataset.preview) : find(chip.dataset.preview)) : null;
    // A change-map part has no place to go to and no ID to copy.
    if (item && item.kind !== 'part') {
        const id = chip.dataset.preview;
        const label = item.ref ?? id;
        items.push({ separatorBefore: true, label: `Go to ${label}`, icon: 'go-to', onSelect: () => navigate(id, undefined, { scope }) }, { label: `Copy ${label}`, icon: 'copy', onSelect: () => act.copy(label, 'ID') });
    }
    const source = target.closest('.source-item[data-path]');
    if (source) {
        const show = source.querySelector('.source-chip');
        const open = source.querySelector('.source-editor');
        items.push(
            ...(show ? [{ separatorBefore: true, label: 'Show the file here', icon: 'file', onSelect: () => show.click() }] : []),
            ...(open ? [{ label: open.getAttribute('data-tip') ?? open.getAttribute('title') ?? 'Open in your editor', icon: 'file-code', onSelect: () => open.click() }] : []),
            { separatorBefore: !show && !open, label: 'Copy path', icon: 'copy', onSelect: () => act.copy(source.dataset.path) });
    }
    const link = target.closest('a.ext-link[href]');
    if (link) {
        items.push({ separatorBefore: true, label: 'Open the link', icon: 'globe', onSelect: () => link.click() }, { label: 'Copy the link', icon: 'copy', onSelect: () => act.copy(link.href, 'Link') });
    }
    if (state.notConnected) {
        items.push({ separatorBefore: items.length > 0, label: 'Copy the request', icon: 'copy', onSelect: connectScreen.copyRequest },
            { label: 'Show the sample session', icon: 'eye', onSelect: connectScreen.showSample });
        return items;
    }
    if (ready) {
        const { back, forward } = places.peek();
        items.push(
            { separatorBefore: true, label: 'Back', icon: 'arrow-left', disabled: !back, shortcut: 'Alt+Left', onSelect: () => travel('back') },
            { label: 'Forward', icon: 'arrow-right', disabled: !forward, shortcut: 'Alt+Right', onSelect: () => travel('forward') },
            { label: state.following === false ? 'Follow the agent' : 'Stop following the agent', icon: state.following === false ? 'live' : 'live-off', shortcut: state.ui.shortcuts ? 'f' : undefined, onSelect: toggleFollowing });
    }
    items.push({ separatorBefore: !ready, label: 'What IDs and icons mean', icon: 'legend', shortcut: state.ui.shortcuts ? 'l' : undefined, onSelect: openLegend });
    return items;
}

// Boot

function wire() {
    // A preview from inside the shown document reads that document, which may be an earlier one.
    previews = installPreviews({ context: (inDocument) => (inDocument && state.ui.phase ? viewContext(state.ui.phase) : context()), revision: () => state.data?.revision ?? 0 });
    tooltips = installTooltips();
    anchors = installAnchorHandle({ scroller: $('document'), onComment: (anchor) => act.anchorComposer(anchor.rowId, false, anchor) });
    contextMenu = installContextMenu({
        itemsFor: menuItemsFor,
        onOpen: () => {
            previews?.closeAll();
            tooltips?.hide();
            anchors?.hide();
        },
    });
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
    $('legendBtn').addEventListener('click', openLegend);
    $('sendBtn').addEventListener('click', () => act.openSend());
    $('sendSheet').addEventListener('close', onSendClose);
    $('needsBtn').addEventListener('click', nextAttention);
    $('appearanceBtn').addEventListener('click', () => toggleAppearance());
    for (const input of document.querySelectorAll('input[name="theme"]')) {
        input.addEventListener('change', () => savePreferences({ theme: input.value }));
    }
    $('contrastSwitch').addEventListener('change', (event) => savePreferences({ contrast: event.target.checked ? 'more' : 'standard' }));
    document.addEventListener('click', (event) => {
        if (!$('appearanceMenu').hidden && !event.target.closest('#appearanceMenu, #appearanceBtn')) toggleAppearance(false);
        if (!$('sessionMenu').hidden && event.target.isConnected && !event.target.closest('#sessionMenu, #sessionBtn')) toggleSessionMenu(false);
        if (state.ui.boardLane && event.target.isConnected && !event.target.closest(`${laneSelector(state.ui.boardLane)}, .preview`)) closeLane(false);
    });
    // Focus leaving the open lane for anything but a card's preview closes it, once focus has landed.
    document.addEventListener('focusout', (event) => {
        const lane = state.ui.boardLane;
        if (!lane || !event.target.closest?.(laneSelector(lane))) return;
        const next = event.relatedTarget;
        if (!(next instanceof Element) || next.closest(`${laneSelector(lane)}, .preview`)) return;
        window.setTimeout(() => {
            if (state.ui.boardLane !== lane || document.activeElement?.closest?.(`${laneSelector(lane)}, .preview`)) return;
            closeLane(false);
        }, 0);
    });
    $('sessionBtn').addEventListener('click', () => toggleSessionMenu());
    $('sessionMenu').addEventListener('focusout', (event) => {
        const next = event.relatedTarget;
        if (next instanceof Node && !$('sessionMenu').contains(next) && next !== $('sessionBtn')) toggleSessionMenu(false);
    });
    $('liveBtn').addEventListener('click', toggleFollowing);
    // Starting to write or choose an answer stops following, so an agent move never takes the page away.
    $('workspace').addEventListener('focusin', (event) => {
        if (event.target.matches?.('textarea, .options input, .composer input')) pauseForInput();
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

/** Tells the server about the page's environment and any render failure, for `get_state`. */
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
        renderError: state.renderError,
    }).catch(() => {});
}

wire();
applyPanels();
await refresh();
connect();
reportEnvironment();
