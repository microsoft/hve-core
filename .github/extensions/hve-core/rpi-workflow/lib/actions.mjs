// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import {
    agentEditSection,
    deriveView,
    ModelError,
    PHASES,
    recordActivity,
    recordChange,
    recordDiscovery,
    recordInterpretation,
    requireSection,
    takeFeedback,
    trackResearchLane,
    updateFinding,
    updateSession,
    updateTask,
    upsertDecision,
} from './model.mjs';
import { buildScenario, SCENARIO_ID, STAGES } from './scenario.mjs';

const str = (description, extra = {}) => ({ type: 'string', description, ...extra });
const ids = (description) => ({ type: 'array', items: { type: 'string' }, description });
const PHASE = { type: 'string', enum: [...PHASES], description: 'research, plan, implement, review, or followup' };

/** Agent-facing action declarations. Handlers live in createActionHandlers. */
export const ACTION_DEFINITIONS = Object.freeze([
    {
        name: 'get_state',
        description: 'Summarize the RPI session shown in this canvas: phase, decisions needing the user, agent decisions, queued and interpreted feedback, progress, appearance, and what the page reported about its environment.',
        inputSchema: { type: 'object', properties: { detail: { type: 'string', enum: ['summary', 'full'], description: 'summary (default) or full session data' } }, additionalProperties: false },
    },
    {
        name: 'load_scenario',
        description: 'Load the sample RPI session at a stage. Refuses to overwrite changes the user made unless replace is true; a replaced session with user changes is kept as a backup until the next such replace.',
        inputSchema: { type: 'object', properties: { stage: { type: 'string', enum: [...STAGES] }, replace: { type: 'boolean' } }, required: ['stage'], additionalProperties: false },
    },
    {
        name: 'update_session',
        description: 'Update session-level state: the phase the agent is working in, task and session status, mode, next action, or individual phase statuses.',
        inputSchema: {
            type: 'object',
            properties: {
                activePhase: PHASE,
                status: { type: 'string', enum: ['active', 'blocked', 'completed'] },
                sessionStatus: { type: 'string', enum: ['running', 'stopped'] },
                mode: { type: 'string', enum: ['automatic', 'manual'] },
                nextAction: str('Plain-language next action'),
                phaseStatus: { type: 'object', additionalProperties: { type: 'string', enum: ['done', 'active', 'upcoming', 'paused', 'blocked', 'skipped'] } },
            },
            additionalProperties: false,
        },
    },
    {
        name: 'upsert_decision',
        description: 'Ask the user for a decision (owner user) or record a decision the agent made that the user can override (owner agent). Updates the decision when id exists. The card appears beside its anchor row when that row is a research finding (F1), plan phase or task (P02, P02-T03), implement discovery (DS-004), or review finding (RV-001) in a phase that has started; otherwise it appears as a full card in the steering panel.',
        inputSchema: {
            type: 'object',
            properties: {
                id: str('Existing decision ID such as D2; omit to create'),
                owner: { type: 'string', enum: ['user', 'agent'] },
                phase: PHASE,
                title: str('Short decision title'),
                question: str('The question the user answers'),
                context: str('Why it matters now and what the evidence says'),
                impact: str('What the answer changes, such as P02-T03'),
                rationale: str('For agent decisions, why this option'),
                options: { type: 'array', items: { type: 'object', properties: { id: str('Option ID'), label: str('Option label'), consequence: str('What happens if chosen'), recommended: { type: 'boolean' }, why: str('Why it is recommended') }, required: ['label'], additionalProperties: false } },
                chosen: str('Chosen option ID; required for agent decisions'),
                evidence: ids('Evidence IDs such as C5 or W2'),
                anchor: { type: 'object', properties: { rowId: str('Row the decision sits beside: a finding (F3), plan phase or task (P02-T03), discovery (DS-004), or review finding (RV-001)') }, required: ['rowId'], additionalProperties: false },
                status: { type: 'string', enum: ['needs-input', 'answered', 'decided', 'override-pending', 'resolved'] },
            },
            additionalProperties: false,
        },
    },
    {
        name: 'take_feedback',
        description: 'Collect every feedback item the user queued (answers, overrides, comments, context, research requests, edits, checklist reviews, corrections) and mark them sent. Items the user is delivering right now are skipped. Edit items include the section as the user saved it (section.markdown, up to 8,000 characters; section.truncated is true when longer, and get_state detail full returns the rest). Read back each one with record_interpretation.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    },
    {
        name: 'record_interpretation',
        description: 'Tell the user how you understood a sent feedback item and what it changes. Set applied true to mark it applied without waiting for the user to confirm.',
        inputSchema: { type: 'object', properties: { feedbackId: str('Feedback ID such as FB-004'), text: str('Your interpretation in plain language'), effect: str('What changed, such as P02-T03 updated'), applied: { type: 'boolean' } }, required: ['feedbackId'], additionalProperties: false },
    },
    {
        name: 'update_task',
        description: 'Change a plan task status (todo, in-progress, paused, done, blocked), add a guidance note, or link the decision that paused it.',
        inputSchema: { type: 'object', properties: { taskId: str('Task ID such as P02-T02'), status: { type: 'string', enum: ['todo', 'in-progress', 'paused', 'done', 'blocked'] }, note: str('Guidance for the task'), decisionId: { type: ['string', 'null'], description: 'Decision that paused the task, or null to clear' } }, required: ['taskId'], additionalProperties: false },
    },
    {
        name: 'record_change',
        description: 'Record completed work for a task: what now behaves differently, the files, and validation results.',
        inputSchema: {
            type: 'object',
            properties: {
                taskId: str('Task ID'),
                title: str('Descriptive heading'),
                behavior: str('What now behaves differently and why'),
                files: { type: 'array', items: { type: 'object', properties: { path: str('Workspace-relative path'), kind: { type: 'string', enum: ['added', 'modified', 'deleted', 'renamed'] }, additions: { type: 'integer' }, deletions: { type: 'integer' }, diff: str('Unified diff, optional') }, required: ['path', 'kind'], additionalProperties: false } },
                validation: { type: 'array', items: { type: 'object', properties: { check: str('Check or command'), status: { type: 'string', enum: ['passed', 'failed', 'skipped', 'unavailable'] }, summary: str('Result summary') }, required: ['check', 'status'], additionalProperties: false } },
            },
            required: ['taskId', 'title', 'behavior'],
            additionalProperties: false,
        },
    },
    {
        name: 'record_discovery',
        description: 'Record something learned during implementation: local judgment, an implementation note, follow-up work, or a plan change (optionally with before and after plan text and the decision it needs).',
        inputSchema: {
            type: 'object',
            properties: {
                kind: { type: 'string', enum: ['local', 'annotation', 'follow-up', 'plan-change'] },
                title: str('Short title'),
                detail: str('What was found and why it matters'),
                taskId: str('Related task ID'),
                decisionId: str('Decision the discovery needs'),
                planUpdate: { type: 'object', properties: { area: str('Plan area such as P03-T01 Requirements'), before: str('Text before'), after: str('Text after') }, required: ['area', 'before', 'after'], additionalProperties: false },
            },
            required: ['kind', 'title', 'detail'],
            additionalProperties: false,
        },
    },
    {
        name: 'record_activity',
        description: 'Add a line to the Implement view Now banner describing what the agent is doing.',
        inputSchema: { type: 'object', properties: { text: str('What the agent is doing'), kind: { type: 'string', enum: ['read', 'edit', 'run', 'test', 'think', 'note'] } }, required: ['text'], additionalProperties: false },
    },
    {
        name: 'update_finding',
        description: 'Create or update a review finding (RV-xxx): severity, expected and observed behavior, resolution condition, route, and decision.',
        inputSchema: {
            type: 'object',
            properties: {
                id: str('Finding ID such as RV-003'),
                severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
                title: str('Finding title'), summary: str('Plain summary'), expected: str('Expected behavior'), observed: str('Observed behavior and evidence'),
                impact: str('Impact'), resolution: str('Resolution condition'),
                route: { type: 'string', enum: ['rpi-implement', 'rpi-plan', 'rpi-research', 'follow-up', 'none'] },
                decision: { type: 'string', enum: ['proposed', 'accepted', 'rejected', 'deferred', 'resolved'] },
                rationale: str('Why, recorded in the decision history'),
                related: ids('Related IDs'),
            },
            required: ['id'],
            additionalProperties: false,
        },
    },
    {
        name: 'update_section',
        description: 'Replace the Markdown of one document section as the agent. A user editing the same section then sees a conflict notice when saving.',
        inputSchema: { type: 'object', properties: { sectionId: str('Section ID such as research-summary or finding-f3'), markdown: str('New Markdown'), title: str('New title, optional') }, required: ['sectionId', 'markdown'], additionalProperties: false },
    },
    {
        name: 'track_research_lane',
        description: 'Show a research subagent lane in the Research view: queued, running, done, or cancelled, with its question, origin feedback item, and summary.',
        inputSchema: { type: 'object', properties: { id: str('Lane ID such as L3; omit to create'), question: str('The lane question'), status: { type: 'string', enum: ['queued', 'running', 'done', 'cancelled'] }, summary: str('What the lane found'), origin: str('Feedback ID that requested it'), findingId: str('Finding it informs'), effort: { type: 'string', enum: ['low', 'medium', 'high', 'max'] } }, required: ['status'], additionalProperties: false },
    },
    {
        name: 'focus_item',
        description: 'Point the user at an item: switch the canvas to its phase, scroll to it, and highlight it once.',
        inputSchema: { type: 'object', properties: { itemId: str('Item ID such as D6 or RV-001'), phase: PHASE }, additionalProperties: false },
    },
    {
        name: 'set_appearance',
        description: 'Set the canvas appearance: theme system, light, or dark, and contrast standard or more.',
        inputSchema: { type: 'object', properties: { theme: { type: 'string', enum: ['system', 'light', 'dark'] }, contrast: { type: 'string', enum: ['standard', 'more'] } }, additionalProperties: false },
    },
]);

/** Groups used by validation to exercise every area of the action vocabulary. */
export const ACTION_GROUPS = Object.freeze({
    state: ['get_state', 'load_scenario'],
    session: ['update_session'],
    decisionsAndFeedback: ['upsert_decision', 'take_feedback', 'record_interpretation'],
    implementation: ['update_task', 'record_change', 'record_discovery', 'record_activity'],
    reviewAndDocuments: ['update_finding', 'update_section', 'track_research_lane'],
    navigationAndAppearance: ['focus_item', 'set_appearance'],
});

/**
 * Summarizes a session for the agent without dumping every document.
 *
 * @param {any} session
 */
export function summarize(session) {
    const view = deriveView(session);
    const byState = (state) => session.feedback.filter((item) => item.state === state).map((item) => ({ id: item.id, kind: item.kind, target: item.target?.id ?? null }));
    return {
        scenario: session.scenario,
        revision: session.revision,
        task: { id: session.task.id, title: session.task.title },
        mode: session.session.mode,
        activePhase: session.session.activePhase,
        status: session.session.status,
        sessionStatus: session.session.sessionStatus,
        nextAction: session.session.nextAction,
        phases: Object.fromEntries(PHASES.map((phase) => [phase, session.phases[phase].status])),
        needsUserInput: view.needsYou,
        decidedByAgent: view.decidedByAgent,
        queuedFeedback: byState('queued'),
        awaitingInterpretation: byState('sent'),
        awaitingUserConfirmation: byState('interpreted'),
        progress: view.progress,
        currentTask: session.implementation.current?.taskId ?? null,
    };
}

/**
 * @param {{
 *   getInstance: (instanceId: string) => { server: any, sessionId: string } | undefined,
 *   store: ReturnType<import('./store.mjs').createStore>,
 *   makeError: (code: string, message: string) => Error,
 *   now?: () => number,
 * }} deps
 */
export function createActionHandlers(deps) {
    const { getInstance, store, makeError } = deps;
    const nowMs = deps.now ?? (() => Date.now());
    const iso = () => new Date(nowMs()).toISOString();

    function instanceOf(ctx) {
        const instance = getInstance(ctx?.instanceId);
        if (!instance) {
            throw makeError('instance_not_found', 'This canvas instance is not open. Open the RPI Workflow canvas first.');
        }
        return instance;
    }

    function inputOf(ctx) {
        const input = ctx?.input;
        if (input === undefined || input === null) {
            return {};
        }
        if (typeof input !== 'object' || Array.isArray(input)) {
            throw makeError('invalid_input', 'Action input must be an object.');
        }
        return input;
    }

    async function guard(run) {
        try {
            return await run();
        } catch (error) {
            if (error instanceof ModelError) {
                throw makeError(error.code, error.message);
            }
            throw error;
        }
    }

    const agentUpdate = (instance, change) => store.update(instance.sessionId, change, { by: 'agent' });

    const mutation = (apply, shape) => (ctx) => guard(async () => {
        const instance = instanceOf(ctx);
        const input = inputOf(ctx);
        const { session, result } = await agentUpdate(instance, (current) => apply(current, input, iso()));
        return shape ? shape(result, session) : { revision: session.revision, result };
    });

    return {
        get_state: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            const session = await store.load(instance.sessionId);
            if (!session) {
                throw makeError('not_found', 'No session is loaded. Call load_scenario.');
            }
            const base = { url: instance.server.url, preferences: await store.loadPreferences(), clientInfo: instance.server.clientInfo, pageConnected: instance.server.streamClients > 0 };
            return input.detail === 'full' ? { ...base, session } : { ...base, ...summarize(session) };
        }),

        load_scenario: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            if (!STAGES.includes(input.stage)) {
                throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
            }
            const session = await store.create(buildScenario(input.stage, nowMs()), { replace: input.replace === true });
            instance.server.notifyReload?.();
            return summarize(session);
        }),

        update_session: mutation((s, input, now) => updateSession(s, input, now), (_r, s) => summarize(s)),
        upsert_decision: mutation((s, input, now) => upsertDecision(s, input, now), (decision, s) => ({ revision: s.revision, decision })),

        take_feedback: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const { session, result } = await agentUpdate(instance, (current) => takeFeedback(current, iso()));
            return {
                revision: session.revision,
                items: result.map((item) => ({ id: item.id, kind: item.kind, target: item.target, optionId: item.optionId ?? null, optionLabel: item.optionLabel ?? null, text: item.text, correctionOf: item.correctionOf ?? null, ...(item.kind === 'edit' && item.section ? { section: item.section } : {}) })),
                note: result.length === 0 ? 'No queued feedback.' : 'Read back each item with record_interpretation.',
            };
        }),

        record_interpretation: mutation((s, input, now) => recordInterpretation(s, input, now), (item, s) => ({ revision: s.revision, id: item.id, state: item.state })),
        update_task: mutation((s, input, now) => updateTask(s, input, now), (task, s) => ({ revision: s.revision, task: { id: task.id, status: task.status } })),
        record_change: mutation((s, input, now) => recordChange(s, input, now), (change, s) => ({ revision: s.revision, id: change.id })),
        record_discovery: mutation((s, input, now) => recordDiscovery(s, input, now), (discovery, s) => ({ revision: s.revision, id: discovery.id })),
        record_activity: mutation((s, input, now) => recordActivity(s, input, now), (_line, s) => ({ revision: s.revision })),
        update_finding: mutation((s, input, now) => updateFinding(s, input, now), (finding, s) => ({ revision: s.revision, finding: { id: finding.id, decision: finding.decision } })),
        update_section: mutation((s, input, now) => {
            requireSection(s, input.sectionId);
            return agentEditSection(s, input, now);
        }, (section, s) => ({ revision: s.revision, section: { id: section.id, revision: section.revision } })),
        track_research_lane: mutation((s, input, now) => trackResearchLane(s, input, now), (lane, s) => ({ revision: s.revision, lane: { id: lane.id, status: lane.status } })),

        focus_item: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            if (input.phase !== undefined && !PHASES.includes(input.phase)) {
                throw makeError('invalid_input', `phase must be one of: ${PHASES.join(', ')}.`);
            }
            if (input.itemId !== undefined && (typeof input.itemId !== 'string' || input.itemId.length > 80)) {
                throw makeError('invalid_input', 'itemId must be an ID such as D6.');
            }
            return instance.server.focus({ phase: input.phase, itemId: input.itemId });
        }),

        set_appearance: (ctx) => guard(async () => {
            instanceOf(ctx);
            return { preferences: await store.savePreferences(inputOf(ctx)) };
        }),
    };
}

export { SCENARIO_ID };
