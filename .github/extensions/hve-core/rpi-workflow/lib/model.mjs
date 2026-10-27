// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Session model for the RPI Workflow canvas: shape validation, mutations shared by the
 * page and agent actions, delivery text composition, and the derived view the UI renders.
 * Every mutation returns a new session object and never mutates its input.
 */

import { createHash } from 'node:crypto';

import { VERDICTS, verdictOf } from './checklists.mjs';
import { unifiedDiff } from './textdiff.mjs';

export const SESSION_FORMAT = 'hve-core-rpi-workflow.session';
export const SESSION_VERSION = 1;
export const PHASES = Object.freeze(['research', 'plan', 'implement', 'review', 'followup']);
export const PHASE_LABELS = Object.freeze({ research: 'Research', plan: 'Plan', implement: 'Implement', review: 'Review', followup: 'Follow-up' });
export const PHASE_STATUSES = Object.freeze(['done', 'active', 'upcoming', 'paused', 'blocked', 'skipped']);
export const TASK_STATUSES = Object.freeze(['todo', 'in-progress', 'paused', 'done', 'blocked']);
export const DECISION_STATUSES = Object.freeze(['needs-input', 'answered', 'decided', 'override-pending', 'resolved']);
export const FEEDBACK_KINDS = Object.freeze(['answer', 'override', 'comment', 'context', 'research-request', 'edit', 'checklist', 'correction', 'task-request']);
export const FEEDBACK_STATES = Object.freeze(['draft', 'queued', 'sent', 'interpreted', 'applied', 'corrected', 'dismissed']);
export const DELIVERY_MODES = Object.freeze(['queue', 'attach', 'send']);
export const DISCOVERY_KINDS = Object.freeze(['local', 'annotation', 'follow-up', 'plan-change']);
export const VALIDATION_STATUSES = Object.freeze(['passed', 'failed', 'skipped', 'unavailable']);
export const SEVERITIES = Object.freeze(['critical', 'high', 'medium', 'low']);

/** Allowed feedback transitions; anything else is rejected with `invalid_transition`. */
export const FEEDBACK_TRANSITIONS = Object.freeze({
    draft: Object.freeze(['queued', 'dismissed']),
    queued: Object.freeze(['sent', 'dismissed']),
    sent: Object.freeze(['interpreted', 'applied']),
    interpreted: Object.freeze(['applied', 'corrected']),
    corrected: Object.freeze([]),
    applied: Object.freeze([]),
    dismissed: Object.freeze([]),
});

export const LIMITS = Object.freeze({
    title: 200,
    text: 4000,
    markdown: 60000,
    feedbackItems: 500,
    activity: 200,
    listItems: 400,
});

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$/;
const SECTION_ID_RE = /^[a-z0-9][a-z0-9._-]{0,79}$/;

/** Error with a stable code that the server and actions map to responses. */
export class ModelError extends Error {
    /**
     * @param {string} code
     * @param {string} message
     */
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}

const fail = (code, message) => {
    throw new ModelError(code, message);
};

const own = (object, key) => object !== null && typeof object === 'object' && Object.prototype.hasOwnProperty.call(object, key);

/**
 * Returns a trimmed string within bounds or throws `invalid_input`.
 *
 * @param {unknown} value
 * @param {string} field
 * @param {{ max?: number, optional?: boolean, allowEmpty?: boolean }} [options]
 * @returns {string | undefined}
 */
export function text(value, field, options = {}) {
    const { max = LIMITS.text, optional = false, allowEmpty = false } = options;
    if (value === undefined || value === null) {
        if (optional) {
            return undefined;
        }
        fail('invalid_input', `${field} is required.`);
    }
    if (typeof value !== 'string') {
        fail('invalid_input', `${field} must be a string.`);
    }
    const trimmed = value.trim();
    if (!allowEmpty && trimmed.length === 0) {
        if (optional) {
            return undefined;
        }
        fail('invalid_input', `${field} must not be empty.`);
    }
    if (trimmed.length > max) {
        fail('invalid_input', `${field} must be at most ${max} characters.`);
    }
    return trimmed;
}

/**
 * @param {unknown} value
 * @param {string} field
 * @returns {string}
 */
export function identifier(value, field) {
    if (typeof value !== 'string' || !ID_RE.test(value)) {
        fail('invalid_input', `${field} must be an ID such as D2 or P02-T01.`);
    }
    return value;
}

/**
 * @template {string} T
 * @param {unknown} value
 * @param {readonly T[]} allowed
 * @param {string} field
 * @returns {T}
 */
export function oneOf(value, allowed, field) {
    if (typeof value !== 'string' || !allowed.includes(/** @type {T} */ (value))) {
        fail('invalid_input', `${field} must be one of: ${allowed.join(', ')}.`);
    }
    return /** @type {T} */ (value);
}

const clone = (value) => structuredClone(value);

/**
 * Validates the stored shape. Returns the session or throws `storage_corrupt` or
 * `storage_unsupported` so callers can report the file instead of overwriting it.
 *
 * @param {unknown} doc
 * @returns {any}
 */
export function validateSession(doc) {
    if (!doc || typeof doc !== 'object' || Array.isArray(doc)) {
        fail('storage_corrupt', 'Session data is not an object.');
    }
    if (doc.format !== SESSION_FORMAT) {
        fail('storage_corrupt', 'Session data has an unrecognized format marker.');
    }
    if (doc.version !== SESSION_VERSION) {
        fail('storage_unsupported', `Session data version ${String(doc.version)} is not supported.`);
    }
    if (typeof doc.id !== 'string' || !ID_RE.test(doc.id) || !Number.isInteger(doc.revision) || doc.revision < 0) {
        fail('storage_corrupt', 'Session data is missing its ID or revision.');
    }
    for (const key of ['task', 'session', 'phases', 'sections', 'research', 'plan', 'implementation', 'review', 'followUps', 'checklists']) {
        if (!doc[key] || typeof doc[key] !== 'object' || Array.isArray(doc[key])) {
            fail('storage_corrupt', `Session data is missing ${key}.`);
        }
    }
    for (const key of ['decisions', 'feedback', 'links']) {
        if (!Array.isArray(doc[key])) {
            fail('storage_corrupt', `Session data is missing ${key}.`);
        }
    }
    for (const phase of PHASES) {
        if (!own(doc.phases, phase)) {
            fail('storage_corrupt', `Session data is missing the ${phase} phase.`);
        }
    }
    return doc;
}

/**
 * Applies a mutation to a copy, bumps the revision, and stamps the time.
 *
 * @param {any} session
 * @param {string} now ISO timestamp
 * @param {(draft: any) => unknown} change
 * @returns {{ session: any, result: unknown }}
 */
export function mutate(session, now, change) {
    const draft = clone(session);
    const result = change(draft);
    draft.revision = session.revision + 1;
    draft.updatedAt = now;
    return { session: draft, result };
}

function nextPlainId(items, prefix) {
    let max = 0;
    for (const item of items) {
        const match = typeof item?.id === 'string' ? item.id.match(new RegExp(`^${prefix}(\\d+)$`)) : null;
        if (match) {
            max = Math.max(max, Number(match[1]));
        }
    }
    return `${prefix}${max + 1}`;
}

function nextId(items, prefix, width = 3) {
    let max = 0;
    for (const item of items) {
        const match = typeof item?.id === 'string' ? item.id.match(new RegExp(`^${prefix}-(\\d+)$`)) : null;
        if (match) {
            max = Math.max(max, Number(match[1]));
        }
    }
    return `${prefix}-${String(max + 1).padStart(width, '0')}`;
}

/**
 * Finds an item with a matching ID in a list without trusting prototype keys.
 *
 * @param {any[]} list
 * @param {string} id
 */
function byId(list, id) {
    return Array.isArray(list) ? list.find((item) => item && typeof item === 'object' && item.id === id) : undefined;
}

/** The Decisions row of a phase, which comments can anchor to. */
export const DECISIONS_ROWS = Object.freeze({ 'research-decisions': 'research', 'plan-decisions': 'plan' });

/** Locates any addressable item by ID across the session. */
export function findItem(session, id) {
    if (Object.prototype.hasOwnProperty.call(DECISIONS_ROWS, id)) {
        const phase = DECISIONS_ROWS[id];
        return { type: 'decisions-row', item: { id, title: `${PHASE_LABELS[phase]} decisions`, phase } };
    }
    const pools = [
        ['question', session.research.questions],
        ['finding', session.research.findings],
        ['evidence', session.research.evidence],
        ['lane', session.research.lanes],
        ['decision', session.decisions],
        ['requirement', session.plan.requirements],
        ['critique', session.plan.critique?.findings],
        ['change', session.implementation.changes],
        ['discovery', session.implementation.discoveries],
        ['alignment', session.implementation.alignment],
        ['review-finding', session.review.findings],
        ['review-event', session.review.history],
        ['follow-up', session.followUps.items],
        ['feedback', session.feedback],
    ];
    for (const [type, list] of pools) {
        const found = byId(list, id);
        if (found) {
            return { type, item: found };
        }
    }
    for (const phase of session.plan.phases ?? []) {
        if (phase.id === id) {
            return { type: 'plan-phase', item: phase };
        }
        const task = byId(phase.tasks, id);
        if (task) {
            return { type: 'task', item: task, phase };
        }
    }
    if (own(session.sections, id)) {
        return { type: 'section', item: session.sections[id] };
    }
    return null;
}

/** Phase that owns an item, used for navigation and needs-you counts. */
export function phaseOf(session, id) {
    const found = findItem(session, id);
    if (!found) {
        return null;
    }
    switch (found.type) {
        case 'question':
        case 'finding':
        case 'evidence':
        case 'lane':
            return 'research';
        case 'requirement':
        case 'critique':
        case 'plan-phase':
            return 'plan';
        case 'task':
            return session.session.activePhase === 'implement' || found.item.status !== 'todo' ? 'implement' : 'plan';
        case 'change':
        case 'discovery':
        case 'alignment':
            return 'implement';
        case 'review-finding':
        case 'review-event':
            return 'review';
        case 'follow-up':
            return 'followup';
        case 'decision':
            return found.item.phase;
        case 'decisions-row':
            return found.item.phase;
        case 'section':
            return found.item.doc;
        default:
            return null;
    }
}

function targetFor(session, input) {
    if (input === undefined || input === null) {
        return null;
    }
    if (typeof input !== 'object' || Array.isArray(input)) {
        fail('invalid_input', 'target must be an object.');
    }
    const id = identifier(input.id, 'target.id');
    const found = findItem(session, id);
    if (!found) {
        fail('not_found', `No item ${id} exists in this session.`);
    }
    return { id, type: found.type, phase: phaseOf(session, id) };
}

function pushHistory(item, state, by, now) {
    item.history = Array.isArray(item.history) ? item.history : [];
    item.history.push({ state, by, at: now });
}

function capFeedback(draft) {
    if (draft.feedback.length >= LIMITS.feedbackItems) {
        fail('limit_reached', `A session holds at most ${LIMITS.feedbackItems} feedback items.`);
    }
}

/**
 * Creates a feedback item from the page or an action.
 *
 * @param {any} session
 * @param {{ kind: string, text?: string, target?: { id: string }, optionId?: string, state?: string, correctionOf?: string }} input
 * @param {string} now
 */
export function createFeedback(session, input, now) {
    if (!input || typeof input !== 'object') {
        fail('invalid_input', 'Feedback input must be an object.');
    }
    const kind = oneOf(input.kind, FEEDBACK_KINDS, 'kind');
    const state = input.state === undefined ? 'queued' : oneOf(input.state, ['draft', 'queued'], 'state');
    const target = targetFor(session, input.target);
    const needsText = !['answer', 'override', 'checklist'].includes(kind);
    const body = text(input.text, 'text', { optional: !needsText });
    return mutate(session, now, (draft) => {
        capFeedback(draft);
        const item = { id: nextId(draft.feedback, 'FB'), kind, state, target, text: body ?? '', createdAt: now, updatedAt: now, history: [] };
        if (kind === 'answer' || kind === 'override') {
            if (!target || target.type !== 'decision') {
                fail('invalid_input', `${kind} feedback must target a decision.`);
            }
            const decision = byId(draft.decisions, target.id);
            if (kind === 'answer' && decision.owner !== 'user') {
                fail('invalid_state', `Decision ${decision.id} is owned by the agent; use an override.`);
            }
            if (kind === 'override' && decision.chosen !== undefined) {
                // Kept so withdrawing the override restores the agent's choice.
                item.previousChosen = decision.chosen;
            }
            if (input.optionId === undefined || input.optionId === null) {
                // In the user's words, whether or not the decision lists options.
                if (!body) {
                    fail('invalid_input', kind === 'answer' ? 'An answer without an option needs text.' : 'An override needs an option or text that says what to do instead.');
                }
                delete decision.chosen;
            } else {
                const optionId = identifier(input.optionId, 'optionId');
                const option = byId(decision.options, optionId);
                if (!option) {
                    fail('not_found', `Decision ${decision.id} has no option ${optionId}.`);
                }
                item.optionId = optionId;
                item.optionLabel = option.label;
                decision.chosen = optionId;
            }
            decision.status = kind === 'answer' ? 'answered' : 'override-pending';
            decision.feedbackId = item.id;
        }
        if (input.correctionOf !== undefined) {
            item.correctionOf = identifier(input.correctionOf, 'correctionOf');
        }
        pushHistory(item, state, 'user', now);
        draft.feedback.push(item);
        return item;
    });
}

/**
 * Moves a feedback item along the lifecycle.
 *
 * @param {any} session
 * @param {string} feedbackId
 * @param {string} to
 * @param {{ by?: 'user' | 'agent', interpretation?: { text: string, effect?: string }, correction?: string, delivery?: string }} [extra]
 * @param {string} now
 */
export function transitionFeedback(session, feedbackId, to, extra = {}, now = new Date().toISOString()) {
    const id = identifier(feedbackId, 'feedbackId');
    const target = oneOf(to, FEEDBACK_STATES, 'state');
    const existing = byId(session.feedback, id);
    if (!existing) {
        fail('not_found', `No feedback item ${id} exists.`);
    }
    const allowed = FEEDBACK_TRANSITIONS[existing.state] ?? [];
    if (!allowed.includes(target)) {
        fail('invalid_transition', `Feedback ${id} cannot move from ${existing.state} to ${target}.`);
    }
    const correction = target === 'corrected' ? text(extra.correction ?? existing.text, 'correction', { optional: existing.kind === 'answer' || existing.kind === 'override' }) : undefined;
    const interpretationText = target === 'interpreted' ? text(extra.interpretation?.text, 'interpretation.text') : undefined;
    const effect = target === 'interpreted' ? text(extra.interpretation?.effect, 'interpretation.effect', { optional: true, max: LIMITS.title * 2 }) : undefined;
    return mutate(session, now, (draft) => {
        const item = byId(draft.feedback, id);
        item.state = target;
        item.updatedAt = now;
        if (target === 'sent') {
            item.sentAt = now;
            item.delivery = extra.delivery ? oneOf(extra.delivery, DELIVERY_MODES, 'delivery') : 'queue';
        }
        if (target === 'interpreted') {
            item.interpretation = { text: interpretationText, effect: effect ?? '', at: now };
        }
        pushHistory(item, target, extra.by ?? 'user', now);
        const decision = item.target?.type === 'decision' ? byId(draft.decisions, item.target.id) : undefined;
        if (target === 'applied' && decision && decision.feedbackId === item.id) {
            decision.status = 'resolved';
            if (item.kind === 'override') {
                decision.owner = 'agent';
            }
        }
        if (target === 'dismissed' && decision && decision.feedbackId === item.id) {
            // A correction reopens what it corrects: an answer reopens the decision; an override restores the agent's choice.
            const origin = item.kind === 'correction' ? byId(draft.feedback, item.correctionOf) : item;
            const reopen = origin?.kind !== 'override';
            decision.status = reopen ? 'needs-input' : 'decided';
            delete decision.feedbackId;
            if (reopen) {
                delete decision.chosen;
            } else if (origin?.previousChosen !== undefined) {
                decision.chosen = origin.previousChosen;
            }
        }
        if (target === 'corrected') {
            capFeedback(draft);
            const follow = {
                id: nextId(draft.feedback, 'FB'),
                kind: 'correction',
                state: 'queued',
                target: item.target,
                text: correction ?? '',
                correctionOf: item.id,
                createdAt: now,
                updatedAt: now,
                history: [],
            };
            pushHistory(follow, 'queued', 'user', now);
            draft.feedback.push(follow);
            if (decision && decision.feedbackId === item.id) {
                decision.status = item.kind === 'override' ? 'override-pending' : 'answered';
                decision.feedbackId = follow.id;
            }
            return follow;
        }
        return item;
    });
}

/** Line changes of a suggested edit included in delivered text, in characters. */
export const EDIT_EXCERPT_MAX = 8000;

/** Line changes kept on a suggested edit, in characters. */
export const SUGGESTION_DIFF_MAX = 20000;

/** A delivery in progress holds its items for this long before they become available again. */
export const CLAIM_STALE_MS = 10 * 60 * 1000;

/**
 * True while a delivery holds a queued item, so takes and other deliveries skip it.
 *
 * @param {any} item
 * @param {string} now ISO time
 */
export function isClaimed(item, now) {
    if (!item?.deliveringSince) return false;
    const age = Date.parse(now) - Date.parse(item.deliveringSince);
    return Number.isFinite(age) && age < CLAIM_STALE_MS;
}

/**
 * Marks every pending item as sent through the queue and returns them for the agent.
 *
 * @param {any} session
 * @param {string} now
 */
export function takeFeedback(session, now) {
    const queued = session.feedback.filter((item) => item.state === 'queued' && !isClaimed(item, now));
    if (queued.length === 0) {
        return { session, result: [] };
    }
    return mutate(session, now, (draft) => {
        const taken = [];
        for (const item of draft.feedback) {
            if (item.state === 'queued' && !isClaimed(item, now)) {
                item.state = 'sent';
                item.sentAt = now;
                item.updatedAt = now;
                item.delivery = 'queue';
                pushHistory(item, 'sent', 'agent', now);
                taken.push(item);
            }
        }
        return taken;
    });
}

/**
 * Marks specific pending items as sent in a message from the canvas. `tasks` is how many
 * tasks the message named; above one, the agent must name the task with each read-back.
 *
 * @param {any} session
 * @param {string[]} ids
 * @param {'send'} mode
 * @param {string} now
 * @param {{ tasks?: number }} [extra]
 */
export function markDelivered(session, ids, mode, now, extra = {}) {
    const delivery = oneOf(mode, ['send'], 'mode');
    const wanted = new Set(ids.map((id) => identifier(id, 'ids[]')));
    return mutate(session, now, (draft) => {
        const done = [];
        for (const item of draft.feedback) {
            if (wanted.has(item.id) && item.state === 'queued') {
                delete item.deliveringSince;
                item.state = 'sent';
                item.sentAt = now;
                item.updatedAt = now;
                item.delivery = delivery;
                if (Number.isInteger(extra.tasks) && extra.tasks > 1) item.deliveredWith = extra.tasks;
                pushHistory(item, 'sent', 'user', now);
                done.push(item.id);
            }
        }
        return done;
    });
}

/**
 * Holds queued items for one delivery so a concurrent take or delivery cannot send them too.
 *
 * @param {any} session
 * @param {string[]} ids
 * @param {string} now
 */
export function claimDelivery(session, ids, now) {
    const wanted = ids.map((id) => identifier(id, 'ids[]'));
    for (const id of wanted) {
        const item = byId(session.feedback, id);
        if (!item || item.state !== 'queued') {
            fail('invalid_state', `Feedback ${id} is no longer queued.`);
        }
        if (isClaimed(item, now)) {
            fail('invalid_state', `Feedback ${id} is already being delivered.`);
        }
    }
    return mutate(session, now, (draft) => {
        for (const id of wanted) {
            byId(draft.feedback, id).deliveringSince = now;
        }
        return wanted;
    });
}

/** Releases a claim after a failed delivery; the items stay queued. */
export function releaseDelivery(session, ids, now) {
    const wanted = new Set(ids);
    if (!session.feedback.some((item) => wanted.has(item.id) && item.deliveringSince)) {
        return { session, result: [] };
    }
    return mutate(session, now, (draft) => {
        const released = [];
        for (const item of draft.feedback) {
            if (wanted.has(item.id) && item.deliveringSince) {
                delete item.deliveringSince;
                released.push(item.id);
            }
        }
        return released;
    });
}

const KIND_LABELS = Object.freeze({
    answer: ['Answer to', 'answer', 'answers'],
    override: ['Override of', 'override', 'overrides'],
    comment: ['Comment on', 'comment', 'comments'],
    context: ['Context for', 'context note', 'context notes'],
    'research-request': ['Research request about', 'research request', 'research requests'],
    edit: ['Suggested edit to', 'suggested edit', 'suggested edits'],
    checklist: ['Review checklist for', 'review checklist', 'review checklists'],
    correction: ['Correction about', 'correction', 'corrections'],
    'task-request': ['Task request for', 'task request', 'task requests'],
});

const ARTIFACT_OF_PHASE = Object.freeze({ research: 'research', plan: 'plan', implement: 'changes', review: 'review' });
const FILE_LABELS = Object.freeze([['statePath', 'State'], ['research', 'Research'], ['plan', 'Plan'], ['critique', 'Plan critique'], ['changes', 'Changes'], ['review', 'Review']]);

/**
 * The workspace-relative file that holds a phase's content in a session read from RPI
 * files: the phase's artifact, or the state file when the phase has none. Null for the
 * sample, which has no files.
 *
 * @param {any} session
 * @param {string | null | undefined} phase
 * @returns {string | null}
 */
export function artifactFor(session, phase) {
    const source = session?.source;
    if (source?.kind !== 'rpi') return null;
    const key = phase ? ARTIFACT_OF_PHASE[phase] : undefined;
    return (key ? source.artifacts?.[key] : null) ?? source.statePath ?? null;
}

const listOf = (parts) => (parts.length < 3 ? parts.join(' and ') : `${parts.slice(0, -1).join(', ')}, and ${parts.at(-1)}`);
const indent = (text) => String(text).split('\n').map((line) => `   ${line}`);

/**
 * Composes the exact message that Send to agent delivers for one task's items. See
 * `composeSessionDelivery`.
 *
 * @param {any} session
 * @param {string[]} ids
 * @param {string} [now]
 * @param {{ canvas?: { handle?: string | null, instanceId?: string | null } | null, note?: string }} [options]
 * @returns {{ prompt: string, displayPrompt: string, ids: string[], digest: string, parts: { taskId: string, ids: string[] }[] }}
 */
export function composeDelivery(session, ids, now = new Date().toISOString(), options = {}) {
    return composeSessionDelivery([{ session, ids }], now, options);
}

/** The unsent items a send names, in order; refuses items that are missing, sent, or held. */
function sendableItems(session, ids, now) {
    const items = [];
    for (const raw of ids) {
        const id = identifier(raw, 'ids[]');
        const item = byId(session.feedback, id);
        if (!item) {
            fail('not_found', `No feedback item ${id} exists${session.task?.id ? ` in task ${session.task.id}` : ''}.`);
        }
        if (item.state !== 'queued') {
            fail('invalid_state', `Feedback ${id} is ${item.state}; only items not yet sent can be sent.`);
        }
        if (isClaimed(item, now)) {
            fail('invalid_state', `Feedback ${id} is already being sent.`);
        }
        items.push(item);
    }
    return items;
}

/** One task's files, as message lines. */
function fileLines(session) {
    const files = FILE_LABELS.map(([key, label]) => [label, key === 'statePath' ? session.source.statePath : session.source.artifacts?.[key]]).filter(([, path]) => typeof path === 'string' && path);
    return files.length ? ['Task files:', ...files.map(([label, path]) => `- ${label}: ${path}`)] : [];
}

/** One task's items, as message lines numbered from `start`. */
function itemLines(session, items, start) {
    const rpi = session.source?.kind === 'rpi';
    const lines = [];
    items.forEach((item, index) => {
        const [lead] = KIND_LABELS[item.kind];
        const subject = item.kind === 'checklist'
            ? `${lead} ${PHASE_LABELS[item.phase] ?? 'the session'}`
            : `${lead} ${item.target ? describeTarget(session, item.target) : 'the session'}`;
        lines.push(`${start + index}. ${item.id}: ${subject}`);
        const decision = item.target?.type === 'decision' ? byId(session.decisions, item.target.id) : null;
        const file = rpi && (item.kind === 'edit' || decision || item.target?.type === 'decisions-row') ? artifactFor(session, item.target?.phase) : null;
        if (file) lines.push(`   File: ${file}`);
        if (item.optionLabel) {
            lines.push(`   Chose: ${item.optionLabel}`);
        }
        if (item.text && item.kind !== 'edit') {
            const prefix = item.optionLabel ? '' : item.kind === 'override' ? 'Do instead: ' : item.kind === 'answer' ? 'Answer: ' : '';
            item.text.split('\n').forEach((line, at) => lines.push(`   ${at === 0 ? prefix : ''}${line}`));
        }
        if (item.correctionOf) {
            lines.push(`   Corrects ${item.correctionOf}.`);
        }
        if (item.kind === 'edit' && item.section) {
            lines.push(...editLines(session, item));
        }
    });
    return lines;
}

const isCompleted = (session) => session.session?.status === 'completed';

/**
 * Composes the exact message that Send to agent delivers, from unsent items in one or more
 * tasks of a session, the shown task first. The preview and the sent message both come
 * from this function. `displayPrompt` is what the chat shows: the user's message, then a
 * line naming the canvas. `prompt` is what the agent reads: the canvas handle and instance
 * ID, how to handle the items, and for each task its files and items with what they
 * target. A message that spans tasks groups items by task and asks for the task ID with
 * every read-back, because feedback IDs repeat across tasks. Items for a completed task
 * are follow-up work. `digest` covers everything except the user's message, so typing one
 * does not make a preview stale.
 *
 * @param {{ session: any, ids: string[] }[]} parts
 * @param {string} [now]
 * @param {{ canvas?: { handle?: string | null, instanceId?: string | null } | null, note?: string, sessionName?: string | null }} [options]
 * @returns {{ prompt: string, displayPrompt: string, ids: string[], digest: string, parts: { taskId: string, ids: string[] }[] }}
 */
export function composeSessionDelivery(parts, now = new Date().toISOString(), options = {}) {
    const groups = (Array.isArray(parts) ? parts : []).filter((part) => Array.isArray(part?.ids) && part.ids.length > 0);
    const total = groups.reduce((sum, part) => sum + part.ids.length, 0);
    if (total === 0 || total > 50) {
        fail('invalid_input', 'ids must list 1 to 50 feedback items.');
    }
    const note = text(options.note, 'note', { optional: true });
    const sections = groups.map((part) => ({ session: part.session, items: sendableItems(part.session, part.ids, now) }));
    const all = sections.flatMap((section) => section.items);
    const handle = typeof options.canvas?.handle === 'string' && options.canvas.handle ? options.canvas.handle : null;
    const instanceId = typeof options.canvas?.instanceId === 'string' && options.canvas.instanceId ? options.canvas.instanceId : null;
    const name = handle ? `RPI canvas ${handle}` : 'RPI canvas';
    const counts = new Map();
    for (const item of all) counts.set(item.kind, (counts.get(item.kind) ?? 0) + 1);
    const tally = listOf([...counts].map(([kind, count]) => `${count} ${KIND_LABELS[kind][count === 1 ? 1 : 2]}`));
    const sent = `${all.length} ${all.length === 1 ? 'item' : 'items'}`;
    const rpi = sections[0].session.source?.kind === 'rpi';
    const multi = sections.length > 1;
    const phaseOfTask = (session) => PHASE_LABELS[session.session?.activePhase];

    const head = [];
    if (multi) {
        const sessionName = typeof options.sessionName === 'string' && options.sessionName.trim() ? ` "${options.sessionName.trim()}"` : '';
        head.push(`${name} sent ${sent} from the user about ${sections.length} tasks in session${sessionName}: ${listOf(sections.map((section) => `${section.items.length} for ${section.session.task.id}`))}.`);
    } else {
        const phase = phaseOfTask(sections[0].session);
        head.push(`${name} sent ${sent} from the user about task ${sections[0].session.task.id}${phase ? ` (current phase: ${phase})` : ''}.`);
    }
    if (instanceId) head.push(`Canvas instance ID: ${instanceId}. Pass it as instanceId to invoke_canvas_action to act on this canvas.`);
    const rest = ['', 'How to handle these items:'];
    if (rpi) {
        rest.push(multi
            ? "- The canvas does not change the tasks' files. Make each change yourself in the file named for it; the canvas shows the change once the file is saved."
            : "- The canvas does not change the task's files. Make each change yourself in the file named for it; the canvas shows the change once the file is saved.");
    } else {
        rest.push('- This canvas shows its sample session, which has no files. Make each change with canvas actions on this instance, such as update_section for a suggested edit or upsert_decision for a decision.');
    }
    rest.push(multi
        ? '- Then call record_interpretation on this canvas for each item: taskId and feedbackId as listed (feedback IDs repeat across tasks), text saying how you understood it, and applied: true once the change is made.'
        : '- Then call record_interpretation on this canvas for each item: feedbackId, text saying how you understood it, and applied: true once the change is made.');
    if (rpi && sections.some((section) => isCompleted(section.session))) {
        rest.push(multi
            ? "- Items for a completed task are follow-up work for the session: plan them as new work rather than editing that task's finished files."
            : "- This task is completed, so these items are follow-up work for the session: plan them as new work rather than editing the task's finished files.");
    }
    if (multi) {
        let number = 1;
        for (const section of sections) {
            const { session } = section;
            const phase = phaseOfTask(session);
            const status = isCompleted(session) ? 'completed; follow-up work' : phase ? `current phase: ${phase}` : '';
            rest.push('', `Task ${session.task.id}: ${session.task.title}${status ? ` (${status})` : ''}`);
            if (rpi) rest.push(...fileLines(session));
            rest.push('Items:', ...itemLines(session, section.items, number));
            number += section.items.length;
        }
    } else {
        const { session } = sections[0];
        const files = rpi ? fileLines(session) : [];
        if (files.length) rest.push('', ...files);
        rest.push('', 'Items:', ...itemLines(session, sections[0].items, 1));
    }
    const digest = createHash('sha256').update([...head, ...rest].join('\n')).digest('hex').slice(0, 32);
    const prompt = [...head, ...(note ? ['', 'Message from the user:', ...indent(note)] : []), ...rest].join('\n');
    const label = `${name} sent ${sent}: ${tally}.`;
    return {
        prompt,
        displayPrompt: note ? `${note}\n\n${label}` : label,
        ids: all.map((item) => item.id),
        digest,
        parts: sections.map((section) => ({ taskId: section.session.task.id, ids: section.items.map((item) => item.id) })),
    };
}

/**
 * What the canvas shows of another task's feedback: its unsent items with what they
 * target, and how many sent items wait for the agent.
 *
 * @param {any} session
 * @param {string} now
 */
export function feedbackOverview(session, now) {
    const pending = session.feedback
        .filter((item) => item.state === 'queued' && !isClaimed(item, now))
        .map((item) => {
            const about = item.kind === 'checklist' ? PHASE_LABELS[item.phase] ?? 'the session' : item.target ? describeTarget(session, item.target) : 'the session';
            return {
                id: item.id,
                kind: item.kind,
                about,
                label: `${KIND_LABELS[item.kind][0]} ${about}`,
                text: item.kind === 'edit' ? '' : String(item.optionLabel ?? item.text ?? '').slice(0, 280),
                phase: item.target?.phase ?? item.phase ?? null,
            };
        });
    return { pending, awaiting: session.feedback.filter((item) => item.state === 'sent').length };
}

/** A suggested edit in delivered text: its base, then its line changes or, for edits saved before suggestions, its text. */
function editLines(session, item) {
    const { section } = item;
    const current = session.sections?.[section.id];
    const lines = [];
    if (typeof section.diff === 'string') {
        const changed = current && current.revision !== section.revision ? '; the section has changed since' : '';
        lines.push(`   Made against revision ${section.revision} of the section${changed}. Change these lines:`, '   ~~~diff');
        const cut = section.diff.lastIndexOf('\n', EDIT_EXCERPT_MAX);
        const shown = section.diff.length > EDIT_EXCERPT_MAX ? section.diff.slice(0, cut > 0 ? cut : EDIT_EXCERPT_MAX) : section.diff;
        lines.push(...indent(shown), '   ~~~');
        if (shown.length < section.diff.length || section.diffTruncated) {
            lines.push(`   (The change continues. get_state with detail "full" returns feedback item ${item.id} with the whole suggested text in section.markdown.)`);
        }
        return lines;
    }
    lines.push("   The user's version of the section:", '   ~~~markdown', ...indent(section.markdown ?? ''), '   ~~~');
    if (section.truncated) {
        lines.push(`   (First ${EDIT_EXCERPT_MAX} characters.)`);
    }
    return lines;
}

function describeTarget(session, target) {
    const found = findItem(session, target.id);
    const title = found?.item?.title ?? found?.item?.text ?? '';
    const phase = target.phase ? PHASE_LABELS[target.phase] : null;
    const name = title ? `${target.id} "${title.length > 80 ? `${title.slice(0, 79)}...` : title}"` : target.id;
    return phase ? `${name} (${phase})` : name;
}

/**
 * Records the agent's read-back for a sent item, or applies it directly.
 *
 * @param {any} session
 * @param {{ feedbackId: string, text?: string, effect?: string, applied?: boolean }} input
 * @param {string} now
 */
export function recordInterpretation(session, input, now) {
    if (!input || typeof input !== 'object') {
        fail('invalid_input', 'Interpretation input must be an object.');
    }
    if (input.applied === true) {
        const interpreted = input.text ? transitionFeedback(session, input.feedbackId, 'interpreted', { by: 'agent', interpretation: { text: input.text, effect: input.effect } }, now).session : session;
        return transitionFeedback(interpreted, input.feedbackId, 'applied', { by: 'agent' }, now);
    }
    return transitionFeedback(session, input.feedbackId, 'interpreted', { by: 'agent', interpretation: { text: input.text, effect: input.effect } }, now);
}

/**
 * Records the user's suggested edit to one section. The section keeps its text: the
 * suggestion is a pending feedback item, one per section, holding the suggested Markdown
 * and its line changes against the revision the user saw, until the agent applies it.
 * Suggesting the current text withdraws a pending suggestion.
 *
 * @param {any} session
 * @param {{ sectionId: string, markdown: string, baseRevision: number }} input
 * @param {string} now
 * @returns {{ session: any, result: { conflict: boolean, section?: any, feedbackId?: string, withdrawn?: string, unchanged?: boolean } }}
 */
export function suggestEdit(session, input, now) {
    const sectionId = requireSection(session, input?.sectionId);
    const markdown = text(input?.markdown, 'markdown', { max: LIMITS.markdown, allowEmpty: true });
    if (!Number.isInteger(input?.baseRevision) || input.baseRevision < 0) {
        fail('invalid_input', 'baseRevision must be a non-negative integer.');
    }
    const current = session.sections[sectionId];
    if (current.revision !== input.baseRevision) {
        return { session, result: { conflict: true, section: clone(current) } };
    }
    const pending = pendingSuggestion(session, sectionId);
    if (pending && isClaimed(pending, now)) {
        fail('invalid_state', 'This suggestion is being sent. Change it after it reaches the agent.');
    }
    if (current.markdown === markdown) {
        if (!pending) {
            return { session, result: { conflict: false, unchanged: true } };
        }
        const withdrawn = transitionFeedback(session, pending.id, 'dismissed', { by: 'user' }, now);
        return { session: withdrawn.session, result: { conflict: false, withdrawn: pending.id } };
    }
    const diff = unifiedDiff(current.markdown, markdown);
    const cut = diff.text.length > SUGGESTION_DIFF_MAX ? diff.text.lastIndexOf('\n', SUGGESTION_DIFF_MAX) : -1;
    const suggestion = {
        id: sectionId,
        title: current.title,
        revision: current.revision,
        markdown,
        diff: diff.text.length > SUGGESTION_DIFF_MAX ? diff.text.slice(0, cut > 0 ? cut : SUGGESTION_DIFF_MAX) : diff.text,
        diffTruncated: diff.text.length > SUGGESTION_DIFF_MAX,
        added: diff.added,
        removed: diff.removed,
    };
    const summary = `Suggested edit to "${current.title}": ${diff.added} ${diff.added === 1 ? 'line' : 'lines'} added, ${diff.removed} removed.`;
    return mutate(session, now, (draft) => {
        let item = pending ? byId(draft.feedback, pending.id) : null;
        if (item) {
            item.section = suggestion;
            item.text = summary;
            item.updatedAt = now;
        } else {
            capFeedback(draft);
            item = {
                id: nextId(draft.feedback, 'FB'),
                kind: 'edit',
                state: 'queued',
                target: { id: sectionId, type: 'section', phase: current.doc },
                text: summary,
                section: suggestion,
                createdAt: now,
                updatedAt: now,
                history: [],
            };
            pushHistory(item, 'queued', 'user', now);
            draft.feedback.push(item);
        }
        return { conflict: false, feedbackId: item.id };
    });
}

/** The section's suggestion that has not been sent, if any. */
export function pendingSuggestion(session, sectionId) {
    return session.feedback.find((item) => item.kind === 'edit' && item.state === 'queued' && item.target?.id === sectionId) ?? null;
}

/**
 * Agent edit of a section, such as applying a suggestion on the sample. Bumps the
 * revision, so an open editor sees a conflict and older suggestions show the change.
 *
 * @param {any} session
 * @param {{ sectionId: string, markdown: string, title?: string }} input
 * @param {string} now
 */
export function agentEditSection(session, input, now) {
    const sectionId = sectionKey(input?.sectionId);
    const markdown = text(input?.markdown, 'markdown', { max: LIMITS.markdown, allowEmpty: true });
    const title = text(input?.title, 'title', { max: LIMITS.title, optional: true });
    return mutate(session, now, (draft) => {
        const section = draft.sections[sectionId];
        section.markdown = markdown;
        if (title) {
            section.title = title;
        }
        section.revision += 1;
        section.editedBy = 'agent';
        section.updatedAt = now;
        return clone(section);
    });
}

function sectionKey(value) {
    if (typeof value !== 'string' || !SECTION_ID_RE.test(value)) {
        fail('invalid_input', 'sectionId must be a section ID such as research-summary.');
    }
    return value;
}

/** Ensures a section ID exists before an edit. */
export function requireSection(session, sectionId) {
    const key = sectionKey(sectionId);
    if (!own(session.sections, key)) {
        fail('not_found', `No section ${key} exists.`);
    }
    return key;
}

/**
 * Marks one checklist item Looks good (`ok`) or Needs work, with an optional note for
 * Needs work, or clears it with a `null` verdict. The phase's pending review follows.
 *
 * @param {any} session
 * @param {{ phase: string, itemId: string, verdict: 'ok' | 'needs-work' | null, note?: string }} input
 * @param {string} now
 */
export function markChecklist(session, input, now) {
    const phase = oneOf(input?.phase, PHASES, 'phase');
    const itemId = identifier(input?.itemId, 'itemId');
    const verdict = input?.verdict === null || input?.verdict === undefined ? null : oneOf(input.verdict, VERDICTS, 'verdict');
    const note = verdict === 'needs-work' ? text(input?.note, 'note', { optional: true }) : undefined;
    const list = own(session.checklists, phase) ? session.checklists[phase] : [];
    if (!byId(list, itemId)) {
        fail('not_found', `No checklist item ${itemId} exists for ${phase}.`);
    }
    return mutate(session, now, (draft) => {
        const item = byId(draft.checklists[phase], itemId);
        delete item.checked;
        if (verdict) item.verdict = verdict;
        else delete item.verdict;
        if (note) item.note = note;
        else delete item.note;
        syncChecklistReview(draft, phase, now);
        return clone(item);
    });
}

/**
 * What a phase checklist tells the agent, or null when it has nothing to send: the items
 * that need work with their notes, or that every item looks good. Partial Looks good marks
 * only track the person's progress.
 *
 * @param {any[]} list
 * @param {string} phase
 * @returns {{ text: string, digest: string } | null}
 */
export function checklistReview(list, phase) {
    const work = list.filter((item) => verdictOf(item) === 'needs-work');
    const good = list.filter((item) => verdictOf(item) === 'ok');
    if (list.length === 0 || (work.length === 0 && good.length < list.length)) {
        return null;
    }
    const label = PHASE_LABELS[phase] ?? phase;
    const lines = work.length === 0
        ? [`${label} review: all ${list.length} items look good.`]
        : [
            `${label} review: ${work.length} of ${list.length} items ${work.length === 1 ? 'needs' : 'need'} work${good.length ? `, and ${good.length} ${good.length === 1 ? 'looks' : 'look'} good` : ''}.`,
            ...work.map((item) => `Needs work: ${item.label}${item.note ? `. Note: ${item.note}` : ''}`),
            ...good.map((item) => `Looks good: ${item.label}`),
        ];
    const body = lines.join('\n');
    return { text: body, digest: createHash('sha256').update(body).digest('hex').slice(0, 16) };
}

/**
 * Keeps the phase's pending review item in step with its checklist: created or updated
 * while the checklist has something new to send, and removed, never having been sent,
 * when it has nothing. An item being delivered is left alone.
 */
function syncChecklistReview(draft, phase, now) {
    const review = checklistReview(draft.checklists[phase] ?? [], phase);
    const pending = draft.feedback.find((item) => item.kind === 'checklist' && item.phase === phase && item.state === 'queued');
    if (pending && isClaimed(pending, now)) {
        return;
    }
    const lastSent = draft.feedback.findLast((item) => item.kind === 'checklist' && item.phase === phase && ['sent', 'interpreted', 'applied', 'corrected'].includes(item.state));
    const wanted = review && review.digest !== lastSent?.digest ? review : null;
    if (!wanted) {
        if (pending) draft.feedback.splice(draft.feedback.indexOf(pending), 1);
        return;
    }
    if (pending) {
        pending.text = wanted.text;
        pending.digest = wanted.digest;
        pending.updatedAt = now;
        return;
    }
    capFeedback(draft);
    const item = { id: nextId(draft.feedback, 'FB'), kind: 'checklist', state: 'queued', target: null, phase, text: wanted.text, digest: wanted.digest, createdAt: now, updatedAt: now, history: [] };
    pushHistory(item, 'queued', 'user', now);
    draft.feedback.push(item);
}

/**
 * Creates or updates a decision. `owner: user` asks for input; `owner: agent` records an
 * agent decision the user may override.
 *
 * @param {any} session
 * @param {any} input
 * @param {string} now
 */
export function upsertDecision(session, input, now) {
    if (!input || typeof input !== 'object') {
        fail('invalid_input', 'Decision input must be an object.');
    }
    const existing = input.id !== undefined ? byId(session.decisions, identifier(input.id, 'id')) : undefined;
    const owner = input.owner !== undefined ? oneOf(input.owner, ['user', 'agent'], 'owner') : existing?.owner ?? fail('invalid_input', 'owner is required for a new decision.');
    const phase = input.phase !== undefined ? oneOf(input.phase, PHASES, 'phase') : existing?.phase ?? session.session.activePhase;
    const title = text(input.title, 'title', { max: LIMITS.title, optional: Boolean(existing) }) ?? existing.title;
    const question = text(input.question, 'question', { optional: Boolean(existing) || owner === 'agent' }) ?? existing?.question ?? '';
    const context = text(input.context, 'context', { optional: true }) ?? existing?.context ?? '';
    const impact = text(input.impact, 'impact', { max: LIMITS.title * 2, optional: true }) ?? existing?.impact ?? '';
    const rationale = text(input.rationale, 'rationale', { optional: true }) ?? existing?.rationale ?? '';
    let options = existing?.options ?? [];
    if (input.options !== undefined) {
        if (!Array.isArray(input.options) || input.options.length < 1 || input.options.length > 6) {
            fail('invalid_input', 'options must list 1 to 6 choices.');
        }
        options = input.options.map((option, index) => ({
            id: option?.id !== undefined ? identifier(option.id, `options[${index}].id`) : String.fromCharCode(97 + index),
            label: text(option?.label, `options[${index}].label`, { max: LIMITS.title }),
            consequence: text(option?.consequence, `options[${index}].consequence`, { optional: true }) ?? '',
            recommended: option?.recommended === true,
            why: text(option?.why, `options[${index}].why`, { optional: true }) ?? '',
        }));
    }
    if (options.length === 0) {
        fail('invalid_input', 'A decision needs at least one option.');
    }
    const chosen = input.chosen !== undefined ? identifier(input.chosen, 'chosen') : existing?.chosen;
    if (chosen !== undefined && !byId(options, chosen)) {
        fail('not_found', `chosen ${chosen} is not one of the options.`);
    }
    if (owner === 'agent' && chosen === undefined) {
        fail('invalid_input', 'An agent decision must name the chosen option.');
    }
    const evidence = input.evidence !== undefined ? idList(input.evidence, 'evidence') : existing?.evidence ?? [];
    const anchor = input.anchor !== undefined ? anchorFor(session, input.anchor) : existing?.anchor ?? null;
    return mutate(session, now, (draft) => {
        let decision = existing ? byId(draft.decisions, existing.id) : undefined;
        if (!decision) {
            decision = { id: input.id ?? nextPlainId(draft.decisions, 'D'), createdAt: now };
            draft.decisions.push(decision);
        }
        Object.assign(decision, { phase, owner, title, question, context, impact, rationale, options, evidence, anchor, updatedAt: now });
        if (chosen !== undefined) {
            decision.chosen = chosen;
        }
        decision.status = owner === 'agent' ? 'decided' : decision.status === 'answered' || decision.status === 'resolved' ? decision.status : 'needs-input';
        if (input.status !== undefined) {
            decision.status = oneOf(input.status, DECISION_STATUSES, 'status');
        }
        return decision;
    });
}

function idList(value, field) {
    if (!Array.isArray(value) || value.length > 40) {
        fail('invalid_input', `${field} must be a list of up to 40 IDs.`);
    }
    return value.map((id, index) => identifier(id, `${field}[${index}]`));
}

function anchorFor(session, input) {
    if (input === null) {
        return null;
    }
    const rowId = identifier(input?.rowId, 'anchor.rowId');
    if (!findItem(session, rowId)) {
        fail('not_found', `No row ${rowId} exists.`);
    }
    return { phase: phaseOf(session, rowId), rowId };
}

/**
 * Updates session-level state.
 *
 * @param {any} session
 * @param {{ activePhase?: string, status?: string, sessionStatus?: string, mode?: string, nextAction?: string, phaseStatus?: Record<string, string> }} patch
 * @param {string} now
 */
export function updateSession(session, patch, now) {
    if (!patch || typeof patch !== 'object') {
        fail('invalid_input', 'Session patch must be an object.');
    }
    const next = {};
    if (patch.activePhase !== undefined) next.activePhase = oneOf(patch.activePhase, PHASES, 'activePhase');
    if (patch.status !== undefined) next.status = oneOf(patch.status, ['active', 'blocked', 'completed'], 'status');
    if (patch.sessionStatus !== undefined) next.sessionStatus = oneOf(patch.sessionStatus, ['running', 'stopped'], 'sessionStatus');
    if (patch.mode !== undefined) next.mode = oneOf(patch.mode, ['automatic', 'manual'], 'mode');
    if (patch.nextAction !== undefined) next.nextAction = text(patch.nextAction, 'nextAction', { max: LIMITS.title * 2 });
    const phaseStatus = {};
    if (patch.phaseStatus !== undefined) {
        if (!patch.phaseStatus || typeof patch.phaseStatus !== 'object') {
            fail('invalid_input', 'phaseStatus must map phases to statuses.');
        }
        for (const [phase, status] of Object.entries(patch.phaseStatus)) {
            phaseStatus[oneOf(phase, PHASES, 'phaseStatus key')] = oneOf(status, PHASE_STATUSES, `phaseStatus.${phase}`);
        }
    }
    return mutate(session, now, (draft) => {
        Object.assign(draft.session, next);
        for (const [phase, status] of Object.entries(phaseStatus)) {
            draft.phases[phase].status = status;
        }
        if (next.activePhase) {
            draft.phases[next.activePhase].status = phaseStatus[next.activePhase] ?? 'active';
        }
        return draft.session;
    });
}

/**
 * Updates a plan task's status and optional guidance note.
 *
 * @param {any} session
 * @param {{ taskId: string, status?: string, note?: string, decisionId?: string | null }} input
 * @param {string} now
 */
export function updateTask(session, input, now) {
    const taskId = identifier(input?.taskId, 'taskId');
    const found = findItem(session, taskId);
    if (!found || found.type !== 'task') {
        fail('not_found', `No task ${taskId} exists.`);
    }
    const status = input.status !== undefined ? oneOf(input.status, TASK_STATUSES, 'status') : undefined;
    const note = text(input.note, 'note', { optional: true });
    const decisionId = input.decisionId === null ? null : input.decisionId !== undefined ? identifier(input.decisionId, 'decisionId') : undefined;
    return mutate(session, now, (draft) => {
        const task = findItem(draft, taskId).item;
        if (status) {
            task.status = status;
            if (status === 'in-progress') {
                draft.implementation.current = { taskId, startedAt: now };
            } else if (draft.implementation.current?.taskId === taskId) {
                draft.implementation.current = null;
            }
        }
        if (note) {
            task.guidance = [...(task.guidance ?? []), note];
        }
        if (decisionId !== undefined) {
            if (decisionId === null) {
                delete task.decisionId;
            } else {
                task.decisionId = decisionId;
            }
        }
        const phase = draft.plan.phases.find((candidate) => candidate.tasks.some((t) => t.id === taskId));
        if (phase) {
            phase.status = phase.tasks.every((t) => t.status === 'done') ? 'done' : phase.tasks.some((t) => t.status !== 'todo') ? 'in-progress' : 'todo';
        }
        return task;
    });
}

function fileList(value) {
    if (!Array.isArray(value) || value.length > 60) {
        fail('invalid_input', 'files must be a list of up to 60 files.');
    }
    return value.map((file, index) => ({
        path: text(file?.path, `files[${index}].path`, { max: 400 }),
        kind: oneOf(file?.kind, ['added', 'modified', 'deleted', 'renamed'], `files[${index}].kind`),
        additions: Number.isInteger(file?.additions) && file.additions >= 0 ? file.additions : 0,
        deletions: Number.isInteger(file?.deletions) && file.deletions >= 0 ? file.deletions : 0,
        diff: text(file?.diff, `files[${index}].diff`, { max: LIMITS.markdown, optional: true, allowEmpty: true }) ?? '',
    }));
}

function validationList(value) {
    if (value === undefined) {
        return [];
    }
    if (!Array.isArray(value) || value.length > 40) {
        fail('invalid_input', 'validation must be a list of up to 40 checks.');
    }
    return value.map((check, index) => ({
        check: text(check?.check, `validation[${index}].check`, { max: LIMITS.title }),
        status: oneOf(check?.status, VALIDATION_STATUSES, `validation[${index}].status`),
        summary: text(check?.summary, `validation[${index}].summary`, { optional: true }) ?? '',
    }));
}

/** Records a completed-work entry tied to a plan task. */
export function recordChange(session, input, now) {
    const taskId = identifier(input?.taskId, 'taskId');
    if (findItem(session, taskId)?.type !== 'task') {
        fail('not_found', `No task ${taskId} exists.`);
    }
    const entry = {
        taskId,
        title: text(input.title, 'title', { max: LIMITS.title }),
        behavior: text(input.behavior, 'behavior'),
        files: fileList(input.files ?? []),
        validation: validationList(input.validation),
    };
    return mutate(session, now, (draft) => {
        const change = { id: nextId(draft.implementation.changes, 'CH'), ...entry, at: now };
        draft.implementation.changes.push(change);
        return change;
    });
}

/** Records an implementation discovery, optionally with a plan update. */
export function recordDiscovery(session, input, now) {
    const entry = {
        kind: oneOf(input?.kind, DISCOVERY_KINDS, 'kind'),
        title: text(input?.title, 'title', { max: LIMITS.title }),
        detail: text(input?.detail, 'detail'),
        taskId: input?.taskId !== undefined ? identifier(input.taskId, 'taskId') : null,
        decisionId: input?.decisionId !== undefined ? identifier(input.decisionId, 'decisionId') : null,
        planUpdate: null,
    };
    if (input?.planUpdate !== undefined) {
        entry.planUpdate = {
            area: text(input.planUpdate?.area, 'planUpdate.area', { max: LIMITS.title }),
            before: text(input.planUpdate?.before, 'planUpdate.before', { allowEmpty: true }),
            after: text(input.planUpdate?.after, 'planUpdate.after', { allowEmpty: true }),
        };
    }
    return mutate(session, now, (draft) => {
        const discovery = { id: nextId(draft.implementation.discoveries, 'DS'), ...entry, at: now };
        draft.implementation.discoveries.push(discovery);
        return discovery;
    });
}

/** Appends an activity line for the Now banner, keeping the newest entries. */
export function recordActivity(session, input, now) {
    const line = {
        text: text(input?.text, 'text', { max: LIMITS.title * 2 }),
        kind: input?.kind !== undefined ? oneOf(input.kind, ['read', 'edit', 'run', 'test', 'think', 'note'], 'kind') : 'note',
        at: now,
    };
    return mutate(session, now, (draft) => {
        draft.implementation.activity.push(line);
        if (draft.implementation.activity.length > LIMITS.activity) {
            draft.implementation.activity.splice(0, draft.implementation.activity.length - LIMITS.activity);
        }
        return line;
    });
}

/** Creates or updates a review finding and its decision state. */
export function updateFinding(session, input, now) {
    const id = identifier(input?.id, 'id');
    const existing = byId(session.review.findings, id);
    const fields = {};
    if (input.severity !== undefined || !existing) fields.severity = oneOf(input.severity, SEVERITIES, 'severity');
    for (const key of ['title', 'summary', 'expected', 'observed', 'impact', 'resolution']) {
        if (input[key] !== undefined || (!existing && key === 'title')) {
            fields[key] = text(input[key], key, { max: key === 'title' ? LIMITS.title : LIMITS.text });
        }
    }
    if (input.route !== undefined) fields.route = oneOf(input.route, ['rpi-implement', 'rpi-plan', 'rpi-research', 'follow-up', 'none'], 'route');
    if (input.decision !== undefined) fields.decision = oneOf(input.decision, ['proposed', 'accepted', 'rejected', 'deferred', 'resolved'], 'decision');
    if (input.related !== undefined) fields.related = idList(input.related, 'related');
    return mutate(session, now, (draft) => {
        let finding = byId(draft.review.findings, id);
        if (!finding) {
            finding = { id, summary: '', expected: '', observed: '', impact: '', resolution: '', route: 'rpi-implement', decision: 'proposed', related: [] };
            draft.review.findings.push(finding);
        }
        Object.assign(finding, fields, { updatedAt: now });
        if (fields.decision) {
            draft.review.history.push({ id: nextId(draft.review.history, 'RD'), subject: id, status: fields.decision, owner: 'agent', rationale: text(input.rationale, 'rationale', { optional: true }) ?? '', at: now });
        }
        return finding;
    });
}

/** Creates or updates a research lane (a research subagent run the agent is tracking). */
export function trackResearchLane(session, input, now) {
    const status = oneOf(input?.status, ['queued', 'running', 'done', 'cancelled'], 'status');
    const existing = input?.id !== undefined ? byId(session.research.lanes, identifier(input.id, 'id')) : undefined;
    const question = text(input?.question, 'question', { optional: Boolean(existing) }) ?? existing?.question;
    const summary = text(input?.summary, 'summary', { optional: true });
    const origin = input?.origin !== undefined ? identifier(input.origin, 'origin') : existing?.origin ?? null;
    const findingId = input?.findingId !== undefined ? identifier(input.findingId, 'findingId') : existing?.findingId ?? null;
    const effort = input?.effort !== undefined ? oneOf(input.effort, ['low', 'medium', 'high', 'max'], 'effort') : existing?.effort ?? 'max';
    return mutate(session, now, (draft) => {
        let lane = existing ? byId(draft.research.lanes, existing.id) : undefined;
        if (!lane) {
            lane = { id: input?.id ?? nextPlainId(draft.research.lanes, 'L'), createdAt: now };
            draft.research.lanes.push(lane);
        }
        Object.assign(lane, { question, status, origin, findingId, effort, updatedAt: now });
        if (summary !== undefined) {
            lane.summary = summary;
        }
        return lane;
    });
}

/**
 * Derives what the UI renders beyond raw data: needs-you and agent-decided lists,
 * feedback grouped by state, per-phase counts, progress, and the trace index.
 *
 * @param {any} session
 */
export function deriveView(session) {
    const needsYou = session.decisions
        .filter((decision) => decision.owner === 'user' && decision.status === 'needs-input')
        .map((decision) => ({ id: decision.id, phase: decision.phase, title: decision.title, anchor: decision.anchor }));
    const decidedByAgent = session.decisions
        .filter((decision) => decision.owner === 'agent' && (decision.status === 'decided' || decision.status === 'override-pending'))
        .map((decision) => ({ id: decision.id, phase: decision.phase, title: decision.title, status: decision.status }));
    const interpretations = session.feedback.filter((item) => item.state === 'interpreted').map((item) => item.id);
    const feedbackByState = Object.fromEntries(FEEDBACK_STATES.map((state) => [state, session.feedback.filter((item) => item.state === state).map((item) => item.id)]));
    const needsYouByPhase = Object.fromEntries(PHASES.map((phase) => [phase, 0]));
    for (const item of needsYou) {
        needsYouByPhase[item.phase] = (needsYouByPhase[item.phase] ?? 0) + 1;
    }
    for (const id of interpretations) {
        const item = byId(session.feedback, id);
        const phase = item?.target?.phase;
        if (phase && own(needsYouByPhase, phase)) {
            needsYouByPhase[phase] += 1;
        }
    }
    const tasks = (session.plan.phases ?? []).flatMap((phase) => phase.tasks ?? []);
    const progress = { done: tasks.filter((task) => task.status === 'done').length, total: tasks.length };
    return {
        needsYou,
        decidedByAgent,
        interpretations,
        feedbackByState,
        needsYouByPhase,
        attentionCount: needsYou.length + interpretations.length,
        progress,
        traces: buildTraces(session),
    };
}

// Rows whose anchored decision follows from them, and task rows a decision shapes.
const DECISION_SOURCE_ROW_RE = /^(?:Q\d{1,2}|F\d{1,2}|DS-\d{3}|RV-\d{3})$/;
const TASK_ROW_RE = /^P\d{2}-T\d{2}$/;

/**
 * Reference pairs read from the session's own fields: question to finding; a decision's
 * anchor (a question, finding, discovery, or review finding row leads to the decision, and
 * the decision leads to an anchored task); the decision a task waits on; task to change
 * and discovery, changes first because they are a task's main outcome; discovery to its
 * decision; and change to review finding (related). Decision evidence cites sources, not
 * trace items, so it adds no pairs.
 *
 * @param {any} session
 * @returns {[string, string][]}
 */
export function referenceLinks(session) {
    const pairs = [];
    for (const question of session.research?.questions ?? []) {
        for (const finding of question.findings ?? []) pairs.push([question.id, finding]);
    }
    for (const decision of session.decisions ?? []) {
        const row = decision.anchor?.rowId;
        if (row && DECISION_SOURCE_ROW_RE.test(row)) pairs.push([row, decision.id]);
        else if (row && TASK_ROW_RE.test(row)) pairs.push([decision.id, row]);
    }
    for (const phase of session.plan?.phases ?? []) {
        for (const task of phase.tasks) {
            if (task.decisionId) pairs.push([task.decisionId, task.id]);
        }
    }
    for (const change of session.implementation?.changes ?? []) {
        if (change.taskId) pairs.push([change.taskId, change.id]);
    }
    for (const discovery of session.implementation?.discoveries ?? []) {
        if (discovery.taskId) pairs.push([discovery.taskId, discovery.id]);
        if (discovery.decisionId) pairs.push([discovery.id, discovery.decisionId]);
    }
    for (const finding of session.review?.findings ?? []) {
        for (const related of finding.related ?? []) {
            if (/^CH-\d{3}$/.test(related)) pairs.push([related, finding.id]);
        }
    }
    return pairs;
}

/**
 * Builds a linear trace for every linked ID: walk back along first links to the earliest
 * ancestor, then forward along the child with the longest path onward, so a strip shows the
 * fullest lineage. Pairs come from reference fields, plus explicit `links` for connections no
 * field records; explicit pairs come first, so they win ties. Work the agent records joins its
 * task's trace through those fields.
 */
export function buildTraces(session) {
    const forward = new Map();
    const backward = new Map();
    const known = new Set();
    for (const link of [...(session.links ?? []), ...referenceLinks(session)]) {
        if (!Array.isArray(link) || link.length !== 2) {
            continue;
        }
        const [from, to] = link;
        if (known.has(`${from}>${to}`)) {
            continue;
        }
        known.add(`${from}>${to}`);
        if (!forward.has(from)) forward.set(from, []);
        if (!backward.has(to)) backward.set(to, []);
        forward.get(from).push(to);
        backward.get(to).push(from);
    }
    const depth = new Map();
    const depthOf = (id, visiting = new Set()) => {
        if (depth.has(id)) return depth.get(id);
        if (visiting.has(id)) return 0;
        visiting.add(id);
        let best = 0;
        for (const next of forward.get(id) ?? []) best = Math.max(best, 1 + depthOf(next, visiting));
        visiting.delete(id);
        depth.set(id, best);
        return best;
    };
    const traces = {};
    const ids = new Set([...forward.keys(), ...backward.keys()]);
    for (const id of ids) {
        const chain = [id];
        const seen = new Set(chain);
        let cursor = id;
        while (backward.has(cursor)) {
            const previous = backward.get(cursor)[0];
            if (seen.has(previous)) break;
            chain.unshift(previous);
            seen.add(previous);
            cursor = previous;
        }
        cursor = id;
        for (;;) {
            const options = (forward.get(cursor) ?? []).filter((candidate) => !seen.has(candidate));
            if (options.length === 0) break;
            const next = options.reduce((best, candidate) => (depthOf(candidate) > depthOf(best) ? candidate : best));
            chain.push(next);
            seen.add(next);
            cursor = next;
        }
        traces[id] = chain;
    }
    return traces;
}
