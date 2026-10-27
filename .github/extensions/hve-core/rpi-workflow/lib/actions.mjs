// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import {
    agentEditSection,
    artifactFor,
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
import { loadSessionDocs } from './session-docs.mjs';
import { sourceSummary } from './sources.mjs';

const str = (description, extra = {}) => ({ type: 'string', description, ...extra });
const ids = (description) => ({ type: 'array', items: { type: 'string' }, description });
const PHASE = { type: 'string', enum: [...PHASES], description: 'research, plan, implement, review, or followup' };

/** What the agent does with a canvas that shows no RPI session. */
export const NOT_CONNECTED_NEXT_STEP = 'Connect the canvas with show_task, giving { "state": "<this conversation\'s RPI state file>" } or { "task": "current" }.';
/** Actions that work on a canvas that shows no session: they read it, connect it, or change its look. */
const WITHOUT_SESSION = new Set(['get_state', 'show_task', 'load_scenario', 'set_appearance']);

/** Agent-facing action declarations. Handlers live in createActionHandlers. */
export const ACTION_DEFINITIONS = Object.freeze([
    {
        name: 'get_state',
        description: 'Summarize the RPI session shown in this canvas: the canvas handle and instance ID that its messages name, phase, decisions needing the user, agent decisions, pending and interpreted feedback for the shown task and for the other tasks in its session (otherTasks), the session tree and whether the canvas follows its running loop, progress, appearance, and what the page reported about its environment.',
        inputSchema: { type: 'object', properties: { detail: { type: 'string', enum: ['summary', 'full'], description: 'summary (default) or full session data' } }, additionalProperties: false },
    },
    {
        name: 'load_scenario',
        description: 'Load the sample RPI session at a stage. Refuses to overwrite changes the user made unless replace is true; a replaced session with user changes is kept as a backup until the next such replace.',
        inputSchema: { type: 'object', properties: { stage: { type: 'string', enum: [...STAGES] }, replace: { type: 'boolean' } }, required: ['stage'], additionalProperties: false },
    },
    {
        name: 'show_task',
        description: 'Point this canvas at an RPI task read from the workspace .copilot-tracking folder, or back at the sample. Give state, the workspace-relative path of a state file in a session folder, or task: "current" (the most recently changed task whose session is running), a task ID from a state file, or "sample" with an optional stage. The canvas follows the session\'s files while the page is open and moves to its running loop; showing a task that is not running pauses that until the user resumes it. Your edits and the user\'s feedback stay in the canvas.',
        inputSchema: {
            type: 'object',
            properties: {
                state: str('State file path such as .copilot-tracking/rpi-sessions/2026-10-23/rpi-workflow-canvas/rpi-workflow-canvas-state.json'),
                task: str('"current", a task ID such as rpi-workflow-canvas, or "sample"'),
                stage: { type: 'string', enum: [...STAGES], description: 'Sample stage, when task is "sample"' },
            },
            additionalProperties: false,
        },
    },
    {
        name: 'update_session',
        description: 'Update session-level state: the phase the agent is working in, task and session status, mode, next action, or individual phase statuses. On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.',
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
        description: 'Ask the user for a decision (owner user) or record a decision the agent made that the user can override (owner agent). Updates the decision when id exists. The card appears beside its anchor row when that row is a research finding (F1), plan phase or task (P02, P02-T03), implement discovery (DS-004), or review finding (RV-001) in a phase that has started; otherwise it appears as a full card in the steering panel. Decisions read from RPI files cannot be edited here; new questions can be asked.',
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
        description: 'Collect every item the user has not sent yet, in every task of the shown session (answers, overrides, comments, context, research requests, suggested edits, checklist reviews, corrections), and mark them sent. Each item names its taskId; feedback IDs repeat across tasks. Use it when the user asks you to check the canvas; Review and send delivers the same items as a chat message. Items being sent right now are skipped. A suggested edit includes section.markdown (the full suggested text) and section.diff (its line changes against section.revision); a checklist review includes its phase. Make each change in that task\'s files, or with canvas actions on the sample, then read it back with record_interpretation. Items for a completed task are follow-up work for the session.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    },
    {
        name: 'record_interpretation',
        description: 'Tell the user how you understood a sent feedback item and what it changes. Set applied true once the change is made: in the task files for a canvas that follows RPI files, or with canvas actions on the sample. Without applied, the user confirms the read-back or corrects it. Pass taskId whenever the message or take_feedback named more than one task; it is required then, because feedback IDs repeat across tasks.',
        inputSchema: { type: 'object', properties: { taskId: str('Task the item belongs to, as the message or take_feedback named it'), feedbackId: str('Feedback ID such as FB-004'), text: str('Your interpretation in plain language'), effect: str('What changed, such as P02-T03 updated'), applied: { type: 'boolean' } }, required: ['feedbackId'], additionalProperties: false },
    },
    {
        name: 'update_task',
        description: 'Change a plan task status (todo, in-progress, paused, done, blocked), add a guidance note, or link the decision that paused it. On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.',
        inputSchema: { type: 'object', properties: { taskId: str('Task ID such as P02-T02'), status: { type: 'string', enum: ['todo', 'in-progress', 'paused', 'done', 'blocked'] }, note: str('Guidance for the task'), decisionId: { type: ['string', 'null'], description: 'Decision that paused the task, or null to clear' } }, required: ['taskId'], additionalProperties: false },
    },
    {
        name: 'record_change',
        description: 'Record completed work for a task: what now behaves differently, the files, and validation results. On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.',
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
        description: 'Record something learned during implementation: local judgment, an implementation note, follow-up work, or a plan change (optionally with before and after plan text and the decision it needs). On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.',
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
        description: 'Create or update a review finding (RV-xxx): severity, expected and observed behavior, resolution condition, route, and decision. On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.',
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
        description: "Replace the Markdown of one document section as the agent, for example to apply a user's suggested edit on the sample session. Suggestions made against an older revision then show that the section changed, and an open editor sees a conflict when saving. On a canvas that follows RPI files (show_task), this is refused with source_managed; update the file instead.",
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
    state: ['get_state', 'load_scenario', 'show_task'],
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
        pendingFeedback: byState('queued'),
        awaitingInterpretation: byState('sent'),
        awaitingUserConfirmation: byState('interpreted'),
        progress: view.progress,
        currentTask: session.implementation.current?.taskId ?? null,
    };
}

/**
 * @param {{
 *   getInstance: (instanceId: string) => { server: any, sessionId: string, instanceId?: string, handle?: string, source?: any } | undefined,
 *   store: ReturnType<import('./store.mjs').createStore>,
 *   makeError: (code: string, message: string) => Error,
 *   now?: () => number,
 *   switchSource?: (instance: any, request: { task?: string, stage?: string, replace?: boolean }, context: { workingDirectory?: string }) => Promise<{ session: any }>,
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

    /** The shown document and the documents of the other tasks in its session. */
    async function sessionDocsOf(instance) {
        const shown = await store.load(instance.sessionId);
        if (!shown) {
            throw makeError('not_found', `No session is loaded. ${NOT_CONNECTED_NEXT_STEP}`);
        }
        return loadSessionDocs(store, shown, instance.source);
    }

    const byState = (session, state) => session.feedback.filter((item) => item.state === state).map((item) => ({ id: item.id, kind: item.kind, target: item.target?.id ?? null }));

    /** Feedback waiting in the session's other tasks, for get_state. */
    async function otherTasksOf(instance) {
        const docs = await sessionDocsOf(instance);
        return docs.slice(1).map((doc) => ({
            taskId: doc.taskId,
            status: doc.task?.status ?? null,
            pendingFeedback: byState(doc.session, 'queued'),
            awaitingInterpretation: byState(doc.session, 'sent'),
            awaitingUserConfirmation: byState(doc.session, 'interpreted'),
        })).filter((task) => task.pendingFeedback.length || task.awaitingInterpretation.length || task.awaitingUserConfirmation.length);
    }

    /**
     * The task document a read-back belongs to: the named task, or the one task whose item
     * is waiting for it. Refuses to guess when the item went out in a message that named
     * several tasks or when several tasks have such an item.
     */
    async function interpretationDoc(instance, input) {
        const docs = await sessionDocsOf(instance);
        if (input.taskId !== undefined) {
            const doc = docs.find((item) => item.taskId === input.taskId);
            if (!doc) throw makeError('not_found', `Task ${String(input.taskId).slice(0, 80)} has no canvas items in this session.`);
            return doc;
        }
        const waiting = (item) => item && (item.state === 'sent' || (input.applied === true && item.state === 'interpreted'));
        const candidates = docs.filter((doc) => waiting(doc.session.feedback.find((item) => item.id === input.feedbackId)));
        const shared = candidates.some((doc) => doc.session.feedback.find((item) => item.id === input.feedbackId)?.deliveredWith > 1);
        if (candidates.length > 1 || shared) {
            throw makeError('invalid_input', `${String(input.feedbackId).slice(0, 80)} went out with items from more than one task; pass taskId with the task named for it.`);
        }
        return candidates[0] ?? docs[0];
    }

    /** The file an action would have to change on a canvas that follows RPI files. */
    async function managedFile(instance, action, input) {
        const session = await store.load(instance.sessionId);
        const source = session?.source ?? {};
        const artifacts = source.artifacts ?? {};
        switch (action) {
            case 'update_session': return source.statePath;
            case 'update_task': return artifacts.plan;
            case 'record_change':
            case 'record_discovery': return artifacts.changes;
            case 'update_finding': return artifacts.review;
            case 'update_section': return artifactFor(session, session?.sections?.[input.sectionId]?.doc) ?? source.statePath;
            case 'upsert_decision': {
                const decision = input.id === undefined ? null : session?.decisions?.find((item) => item.id === input.id);
                if (!decision || decision.origin !== 'artifact') return null;
                return artifactFor(session, decision.phase);
            }
            default: return null;
        }
    }

    /** Refuses document changes on a canvas that follows RPI files; the files stay the source of truth. */
    const managed = (action, handler) => (ctx) => guard(async () => {
        const instance = instanceOf(ctx);
        if (instance.source?.kind === 'rpi') {
            const file = await managedFile(instance, action, inputOf(ctx));
            if (file !== null || action !== 'upsert_decision') {
                throw makeError('source_managed', `This canvas follows the RPI files for ${instance.source.taskId}, so ${action} cannot change it. Update ${file ?? 'the task artifacts'} instead; the canvas refreshes when the file changes.`);
            }
        }
        return handler(ctx);
    });

    const mutation = (apply, shape) => (ctx) => guard(async () => {
        const instance = instanceOf(ctx);
        const input = inputOf(ctx);
        const { session, result } = await agentUpdate(instance, (current) => apply(current, input, iso()));
        return shape ? shape(result, session) : { revision: session.revision, result };
    });

    const handlers = {
        get_state: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            const common = { url: instance.server.address ?? null, editor: instance.server.editor ?? null, canvas: { handle: instance.handle ?? null, instanceId: instance.instanceId ?? ctx.instanceId }, preferences: await store.loadPreferences(), clientInfo: instance.server.clientInfo, pageConnected: instance.server.streamClients > 0 };
            if (instance.source?.kind === 'none') {
                return { ...common, connected: false, source: sourceSummary(instance, null), nextStep: NOT_CONNECTED_NEXT_STEP };
            }
            const session = await store.load(instance.sessionId);
            if (!session) {
                throw makeError('not_found', `No session is loaded. ${NOT_CONNECTED_NEXT_STEP}`);
            }
            const base = { ...common, source: sourceSummary(instance, session) };
            const otherTasks = await otherTasksOf(instance);
            return input.detail === 'full' ? { ...base, session, otherTasks } : { ...base, ...summarize(session), otherTasks };
        }),

        load_scenario: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            if (!STAGES.includes(input.stage)) {
                throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
            }
            if (instance.source?.kind !== 'sample' && deps.switchSource) {
                const prepared = await deps.switchSource(instance, { stage: input.stage, replace: input.replace === true }, { workingDirectory: ctx?.session?.workingDirectory });
                return summarize(prepared.session);
            }
            const session = await store.create(buildScenario(input.stage, nowMs()), { replace: input.replace === true });
            instance.server.notifyReload?.();
            return summarize(session);
        }),

        show_task: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            if (!deps.switchSource) {
                throw makeError('unavailable', 'This canvas cannot switch sources.');
            }
            if (input.task !== undefined && typeof input.task !== 'string') {
                throw makeError('invalid_input', 'task must be "current", a task ID, or "sample".');
            }
            if (input.state !== undefined && typeof input.state !== 'string') {
                throw makeError('invalid_input', 'state must be the path of a state file.');
            }
            if (input.state !== undefined && input.task !== undefined) {
                throw makeError('invalid_input', 'Give either state or task, not both.');
            }
            if (input.stage !== undefined && !STAGES.includes(input.stage)) {
                throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
            }
            if (input.task === undefined && input.state === undefined && input.stage === undefined) {
                throw makeError('invalid_input', 'Give state, task ("current", a task ID, or "sample"), or a sample stage.');
            }
            if (((input.task !== undefined && input.task !== 'sample') || input.state !== undefined) && input.stage !== undefined) {
                throw makeError('invalid_input', 'stage applies only to the sample.');
            }
            const request = input.state !== undefined ? { state: input.state } : input.task === 'sample' ? { task: 'sample', stage: input.stage } : input.task === undefined ? { stage: input.stage } : { task: input.task };
            const prepared = await deps.switchSource(instance, request, { workingDirectory: ctx?.session?.workingDirectory });
            return { ...summarize(prepared.session), source: sourceSummary(instance, prepared.session) };
        }),

        update_session: managed('update_session', mutation((s, input, now) => updateSession(s, input, now), (_r, s) => summarize(s))),
        upsert_decision: managed('upsert_decision', mutation((s, input, now) => upsertDecision(s, input, now), (decision, s) => ({ revision: s.revision, decision }))),

        take_feedback: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const docs = await sessionDocsOf(instance);
            const items = [];
            let revision = docs[0].session.revision;
            for (const doc of docs) {
                const { session, result } = await store.update(doc.id, (current) => takeFeedback(current, iso()), { by: 'agent' });
                if (doc.id === instance.sessionId) revision = session.revision;
                const followUp = session.session?.status === 'completed' && docs.length > 1;
                items.push(...result.map((item) => ({ taskId: doc.taskId, id: item.id, kind: item.kind, target: item.target, optionId: item.optionId ?? null, optionLabel: item.optionLabel ?? null, text: item.text, correctionOf: item.correctionOf ?? null, ...(followUp ? { followUp: true } : {}), ...(item.kind === 'edit' && item.section ? { section: item.section } : {}), ...(item.kind === 'checklist' ? { phase: item.phase ?? null } : {}) })));
            }
            const tasks = new Set(items.map((item) => item.taskId));
            return {
                revision,
                items,
                note: items.length === 0
                    ? 'Nothing is waiting to be sent.'
                    : tasks.size > 1
                        ? 'Make each change in its task\'s files, then read back each item with record_interpretation, passing its taskId. Items marked followUp belong to a completed task: plan them as follow-up work.'
                        : 'Make each change, then read back each item with record_interpretation.',
            };
        }),

        record_interpretation: (ctx) => guard(async () => {
            const instance = instanceOf(ctx);
            const input = inputOf(ctx);
            const doc = await interpretationDoc(instance, input);
            const { session, result } = await store.update(doc.id, (current) => recordInterpretation(current, input, iso()), { by: 'agent' });
            return { revision: session.revision, id: result.id, state: result.state, taskId: doc.taskId };
        }),
        update_task: managed('update_task', mutation((s, input, now) => updateTask(s, input, now), (task, s) => ({ revision: s.revision, task: { id: task.id, status: task.status } }))),
        record_change: managed('record_change', mutation((s, input, now) => recordChange(s, input, now), (change, s) => ({ revision: s.revision, id: change.id }))),
        record_discovery: managed('record_discovery', mutation((s, input, now) => recordDiscovery(s, input, now), (discovery, s) => ({ revision: s.revision, id: discovery.id }))),
        record_activity: mutation((s, input, now) => recordActivity(s, input, now), (_line, s) => ({ revision: s.revision })),
        update_finding: managed('update_finding', mutation((s, input, now) => updateFinding(s, input, now), (finding, s) => ({ revision: s.revision, finding: { id: finding.id, decision: finding.decision } }))),
        update_section: managed('update_section', mutation((s, input, now) => {
            requireSection(s, input.sectionId);
            return agentEditSection(s, input, now);
        }, (section, s) => ({ revision: s.revision, section: { id: section.id, revision: section.revision } }))),
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

    // A canvas that shows no session refuses everything that needs one, with the way to connect it.
    for (const [name, handler] of Object.entries(handlers)) {
        if (WITHOUT_SESSION.has(name)) continue;
        handlers[name] = (ctx) => (getInstance(ctx?.instanceId)?.source?.kind === 'none'
            ? Promise.reject(makeError('not_connected', `This canvas is not connected to an RPI session. ${NOT_CONNECTED_NEXT_STEP}`))
            : handler(ctx));
    }
    return handlers;
}

export { SCENARIO_ID };
