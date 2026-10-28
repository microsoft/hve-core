// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { randomBytes, timingSafeEqual } from 'node:crypto';
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
    claimDelivery,
    composeSessionDelivery,
    createFeedback,
    deriveView,
    discardFeedback,
    editFeedback,
    feedbackOverview,
    LIMITS,
    markDelivered,
    releaseDelivery,
    ModelError,
    queueForAgent,
    suggestEdit,
    takeBackFeedback,
    transitionFeedback,
} from './model.mjs';
import { loadSessionDocs } from './session-docs.mjs';
import { agentTask } from './source/tree.mjs';
import { preferencesPatch } from './store.mjs';
import { EditorError } from './editor.mjs';
import { FileError, readWorkspaceFile } from './workspace-files.mjs';

const UI_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'ui');

const UI_MODULES = ['anchors.mjs', 'app.mjs', 'board.mjs', 'connect-view.mjs', 'context-menu.mjs', 'dom.mjs', 'highlight.mjs', 'history.mjs', 'ids.mjs', 'legend.mjs', 'markdown.mjs', 'preview-content.mjs', 'preview-state.mjs', 'previews.mjs', 'source-view.mjs', 'diagram.mjs', 'flowchart.mjs', 'components.mjs', 'view-research.mjs', 'view-plan.mjs', 'view-implement.mjs', 'view-review.mjs', 'view-followup.mjs', 'tooltips.mjs'];

/** Static files the page may load; nothing outside this map is ever served. */
export const STATIC_FILES = Object.freeze({
    '/': { file: 'index.html', type: 'text/html; charset=utf-8', template: true },
    '/index.html': { file: 'index.html', type: 'text/html; charset=utf-8', template: true },
    '/ui/styles.css': { file: 'styles.css', type: 'text/css; charset=utf-8' },
    ...Object.fromEntries(UI_MODULES.map((name) => [`/ui/${name}`, { file: name, type: 'text/javascript; charset=utf-8' }])),
});

export const CONTENT_SECURITY_POLICY = [
    "default-src 'none'",
    "script-src 'self'",
    "style-src 'self'",
    "img-src 'self' data:",
    "connect-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
].join('; ');

const BASE_HEADERS = Object.freeze({
    'Content-Security-Policy': CONTENT_SECURITY_POLICY,
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'Cross-Origin-Resource-Policy': 'same-origin',
});

export const MAX_SECTION_BODY = 64 * 1024;
export const MAX_BODY = 16 * 1024;
const HEARTBEAT_MS = 15000;
const THEMES = new Set(['system', 'light', 'dark']);
const CONTRASTS = new Set(['standard', 'more']);
const USER_TRANSITIONS = Object.freeze({ draft: ['queued', 'dismissed'], queued: ['dismissed'], interpreted: ['corrected'], applied: ['corrected'] });
const MARK_ATTEMPTS = 3;
/** The pause before the first retry of recording a send; each later retry waits one step longer. */
const MARK_RETRY_MS = 50;
const TASK_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;

const STATUS_FOR = Object.freeze({
    invalid_input: 400,
    invalid_transition: 409,
    invalid_state: 409,
    conflict: 409,
    scenario_exists: 409,
    not_found: 404,
    limit_reached: 413,
    payload_too_large: 413,
    unsupported_media_type: 415,
    storage_busy: 503,
    delivery_unavailable: 503,
    delivery_failed: 502,
    source_unavailable: 404,
    source_not_found: 404,
    source_invalid: 400,
    source_outside: 403,
    source_too_large: 413,
    source_managed: 409,
    not_connected: 409,
    too_soon: 429,
});

/** The Not connected screen's Ask the agent sends at most once in this interval. */
export const CONNECT_REQUEST_INTERVAL_MS = 30000;

/**
 * The request a canvas that shows no session asks the agent, as the chat shows it. The page
 * shows and copies the same text; the server alone sends it.
 *
 * @param {string | null | undefined} handle
 */
export function connectRequestText(handle) {
    return `${handle ? `RPI canvas ${handle}` : 'RPI canvas'}: connect this canvas to this conversation's RPI session.`;
}

/** Error that maps to a JSON error response. */
const FILE_STATUS = Object.freeze({
    source_invalid: 400,
    source_outside: 403,
    source_blocked: 403,
    source_not_found: 404,
    source_too_large: 413,
    source_binary: 415,
    editor_invalid: 400,
    editor_busy: 409,
    editor_failed: 502,
});
const fileHttpError = (error) => (error instanceof FileError || error instanceof EditorError ? new HttpError(FILE_STATUS[error.code] ?? 400, error.code, error.message) : error);

export class HttpError extends Error {
    /**
     * @param {number} status
     * @param {string} code
     * @param {string} message
     */
    constructor(status, code, message) {
        super(message);
        this.status = status;
        this.code = code;
    }
}

/**
 * Renders the stored appearance into the page shell so the first paint is correct.
 *
 * @param {string} html
 * @param {{ theme: string, contrast: string }} preferences
 */
export function renderShell(html, preferences) {
    const theme = THEMES.has(preferences?.theme) ? preferences.theme : 'system';
    const contrast = CONTRASTS.has(preferences?.contrast) ? preferences.contrast : 'standard';
    return html.replace('data-theme="__THEME__"', `data-theme="${theme}"`).replace('data-contrast="__CONTRAST__"', `data-contrast="${contrast}"`);
}

/**
 * Validates the diagnostic environment report from the page. Only booleans, short
 * enums, and numbers are kept; nothing is persisted.
 *
 * @param {unknown} body
 */
export function clientInfoFrom(body) {
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
        throw new HttpError(400, 'invalid_input', 'Client info must be an object.');
    }
    const bool = (value) => value === true;
    const num = (value) => (Number.isFinite(value) && value >= 0 && value < 100000 ? Math.round(value) : null);
    return {
        scheme: body.scheme === 'dark' ? 'dark' : 'light',
        moreContrast: bool(body.moreContrast),
        forcedColors: bool(body.forcedColors),
        reducedMotion: bool(body.reducedMotion),
        lightDark: bool(body.lightDark),
        hostTokens: bool(body.hostTokens),
        width: num(body.width),
        height: num(body.height),
        renderError: typeof body.renderError === 'string' && body.renderError.trim() ? body.renderError.trim().slice(0, 300) : null,
        reportedAt: new Date().toISOString(),
    };
}

/**
 * One page server per canvas instance. Reads and writes go through the shared store;
 * changes from any process reach the page through the event stream. For a canvas that
 * follows RPI files, the page sees the documents of every task in the shown task's
 * session: their unsent feedback, their changes, and one Send for all of them.
 *
 * @param {{
 *   store: ReturnType<import('./store.mjs').createStore>,
 *   getSessionId: () => string,
 *   getCanvas?: () => { handle: string, instanceId: string } | null,
 *   deliver?: (request: { prompt: string, displayPrompt: string, ids: string[] }) => Promise<void>,
 *   log?: (message: string, level?: string) => void,
 *   now?: () => string,
 *   getSource?: () => { kind?: string, reason?: string, detail?: string | null, follow?: { paused: boolean }, follower?: { start: () => void, stop: () => void } } | undefined,
 *   switchTask?: (ref: { taskId?: string, statePath?: string }, options?: { paused?: boolean }) => Promise<{ sessionId: string }>,
 *   switchSession?: (key: string, options?: { paused?: boolean }) => Promise<{ sessionId: string }>,
 *   resumeFollowing?: () => Promise<{ sessionId: string }>,
 *   pauseFollowing?: () => Promise<{ sessionId: string }>,
 *   listSessions?: () => Promise<{ sessions: any[], skipped: string[] }>,
 *   showSample?: () => Promise<{ sessionId: string }>,
 *   markRetryMs?: number,
 * }} deps
 */
export function createCanvasServer(deps) {
    const { store, getSessionId } = deps;
    const markRetryMs = Number.isFinite(deps.markRetryMs) ? deps.markRetryMs : MARK_RETRY_MS;
    const getCanvas = deps.getCanvas ?? (() => null);
    // Every API call must carry this key, which only the page the host opens knows, so other
    // local processes cannot read, change, or send through this canvas.
    const key = typeof deps.key === 'string' && deps.key ? deps.key : randomBytes(24).toString('base64url');
    const expectedKey = Buffer.from(key);
    const keyMatches = (given) => {
        if (typeof given !== 'string') return false;
        const candidate = Buffer.from(given);
        return candidate.length === expectedKey.length && timingSafeEqual(candidate, expectedKey);
    };
    const pageUrl = () => `http://127.0.0.1:${port}/?k=${key}`;
    /** The editor that opens workspace files, once found: `{ name, open(absolute, line) }`. */
    const getEditor = deps.getEditor ?? (() => null);
    const deliver = deps.deliver ?? (async () => {
        throw new ModelError('delivery_unavailable', 'This canvas is not connected to a Copilot session.');
    });
    const log = deps.log ?? (() => {});
    const now = deps.now ?? (() => new Date().toISOString());
    /** @type {http.Server | null} */
    let server = null;
    let port = 0;
    /** @type {Promise<string> | null} */
    let starting = null;
    /** @type {Set<http.ServerResponse>} */
    const clients = new Set();
    /** Store watchers for the session's documents while a page is connected, by document ID. */
    const watched = new Map();
    /** Documents of the other tasks in the shown task's session. */
    let others = new Set();
    /** When Ask the agent last sent, so a double press does not send twice. */
    let lastConnectRequest = 0;
    /** False while the canvas shows no session, until the agent connects it. */
    const connected = () => deps.getSource?.()?.kind !== 'none';
    const notConnectedError = () => new HttpError(409, 'not_connected', 'This canvas is not connected to an RPI session. Ask the agent to connect it.');
    let heartbeat = null;
    let clientInfo = null;
    let pendingFocus = null;

    function broadcast(event, data) {
        const frame = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
        for (const res of clients) {
            res.write(frame);
        }
    }

    /** Watches exactly `ids` while a page is connected. */
    function syncWatches(ids) {
        if (clients.size === 0) return;
        for (const [id, stop] of watched) {
            if (!ids.has(id)) {
                stop();
                watched.delete(id);
            }
        }
        for (const id of ids) if (id && !watched.has(id)) watched.set(id, store.watch(id));
    }

    function unwatchAll() {
        for (const stop of watched.values()) stop();
        watched.clear();
    }

    const onChange = (id, session) => {
        if (id === getSessionId()) {
            broadcast('revision', { revision: session.revision });
        } else if (others.has(id)) {
            broadcast('reload', { at: now() });
        }
    };
    const onPreferences = (preferences) => broadcast('preferences', preferences);
    store.events.on('change', onChange);
    store.events.on('preferences', onPreferences);

    function send(res, status, body, headers) {
        res.writeHead(status, { ...BASE_HEADERS, ...headers });
        res.end(body);
    }

    function sendJson(res, status, value) {
        send(res, status, JSON.stringify(value), { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    }

    function readJsonBody(req, limit) {
        return new Promise((resolve, reject) => {
            const type = String(req.headers['content-type'] ?? '').split(';')[0].trim().toLowerCase();
            if (type !== 'application/json') {
                req.resume();
                reject(new HttpError(415, 'unsupported_media_type', 'Content-Type must be application/json.'));
                return;
            }
            let size = 0;
            let rejected = false;
            const chunks = [];
            req.on('data', (chunk) => {
                if (rejected) {
                    return;
                }
                size += chunk.length;
                if (size > limit) {
                    rejected = true;
                    chunks.length = 0;
                    reject(new HttpError(413, 'payload_too_large', 'Request body is too large.'));
                    return;
                }
                chunks.push(chunk);
            });
            req.on('end', () => {
                if (rejected) {
                    return;
                }
                try {
                    resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || 'null'));
                } catch {
                    reject(new HttpError(400, 'invalid_input', 'Body is not valid JSON.'));
                }
            });
            req.on('error', reject);
        });
    }

    const sessionDocs = (shown) => loadSessionDocs(store, shown, deps.getSource?.());

    async function shownSession() {
        if (!connected()) throw notConnectedError();
        const session = await store.load(getSessionId());
        if (!session) {
            throw new HttpError(404, 'not_found', 'No session is loaded yet. Ask the agent to connect the canvas.');
        }
        return session;
    }

    /** The loop Follow agent goes to, for the page to name. */
    const agentLoop = (tasks) => {
        const task = agentTask(Array.isArray(tasks) ? tasks : []);
        return task ? { taskId: task.id, title: task.title, statePath: task.statePath, status: task.status } : null;
    };

    async function stateResponse() {
        if (!connected()) {
            const source = deps.getSource?.();
            others = new Set();
            unwatchAll();
            return {
                connected: false,
                revision: 0,
                canvas: getCanvas(),
                preferences: await store.loadPreferences(),
                editor: getEditor() ? { name: getEditor().name } : null,
                notConnected: { reason: source?.reason ?? 'no-input', detail: source?.detail ?? null, request: connectRequestText(getCanvas()?.handle), canAsk: Boolean(deps.deliver) },
            };
        }
        const session = await shownSession();
        const docs = await sessionDocs(session);
        others = new Set(docs.slice(1).map((doc) => doc.id));
        syncWatches(new Set(docs.map((doc) => doc.id)));
        const source = deps.getSource?.();
        const at = now();
        return {
            revision: session.revision,
            session,
            view: deriveView(session),
            preferences: await store.loadPreferences(),
            canvas: getCanvas(),
            editor: getEditor() && deps.getSource?.()?.kind === 'rpi' ? { name: getEditor().name } : null,
            follow: source?.kind === 'rpi' ? { paused: Boolean(source.follow?.paused), agent: agentLoop(source.tasks) } : null,
            otherTasks: docs.slice(1).map((doc) => ({ taskId: doc.taskId, title: doc.task?.title ?? doc.session.task.title, status: doc.task?.status ?? null, statePath: doc.task?.statePath ?? null, ...feedbackOverview(doc.session, at) })),
        };
    }

    /**
     * The store document for a task in the shown session: the shown one when `taskId` is
     * omitted or names it.
     *
     * @param {unknown} taskId
     */
    async function docFor(taskId) {
        const session = await shownSession();
        if (taskId === undefined || taskId === null || taskId === session.task.id) return { id: session.id, taskId: session.task.id, session };
        if (typeof taskId !== 'string' || !TASK_ID_RE.test(taskId)) throw new HttpError(400, 'invalid_input', 'taskId must be a task ID.');
        const doc = (await sessionDocs(session)).find((item) => item.taskId === taskId);
        if (!doc) throw new HttpError(404, 'not_found', `Task ${taskId} has no canvas items in this session.`);
        return doc;
    }

    /**
     * Groups the items a request names by task, the shown task first and the others in tree
     * order: `items` lists `{ taskId, id }`, or `ids` lists items of the shown task. A send
     * takes at most 50 items; a discard, every item a session can hold.
     *
     * @param {any} body
     * @param {number} [max]
     */
    async function deliveryGroups(body, max = 50) {
        const session = await shownSession();
        const docs = await sessionDocs(session);
        const wanted = new Map();
        if (Array.isArray(body?.items)) {
            if (body.items.length === 0 || body.items.length > max) throw new HttpError(400, 'invalid_input', `items must list 1 to ${max} feedback items.`);
            for (const entry of body.items) {
                const taskId = entry?.taskId ?? session.task.id;
                if (typeof entry?.id !== 'string' || typeof taskId !== 'string') throw new HttpError(400, 'invalid_input', 'Each item needs an id and a taskId.');
                if (!docs.some((doc) => doc.taskId === taskId)) throw new HttpError(404, 'not_found', `Task ${String(taskId).slice(0, 80)} has no canvas items in this session.`);
                if (!wanted.has(taskId)) wanted.set(taskId, []);
                wanted.get(taskId).push(entry.id);
            }
        } else {
            wanted.set(session.task.id, Array.isArray(body?.ids) ? body.ids : []);
        }
        return docs.filter((doc) => wanted.has(doc.taskId)).map((doc) => ({ ...doc, ids: wanted.get(doc.taskId) }));
    }

    const compose = (groups, body) => composeSessionDelivery(groups.map((group) => ({ session: group.session, ids: group.ids })), now(), {
        canvas: getCanvas(),
        note: body?.note,
        sessionName: groups[0]?.session.followUps?.tree?.name ?? null,
    });

    const sameItems = (a, b, ids) => ids.every((id) => JSON.stringify(a.feedback.find((item) => item.id === id)) === JSON.stringify(b.feedback.find((item) => item.id === id)));

    const userUpdate = (change) => (connected() ? store.update(getSessionId(), change, { by: 'user' }) : Promise.reject(notConnectedError()));

    // Queue: marks each task's reviewed items for the agent's next checkpoint. A note waits with
    // them as a context item in the shown task, so it is not lost without a message to carry it.
    const queueGroups = async (groups, body) => {
        const queued = [];
        let revision = null;
        try {
            for (const group of groups) {
                const { session, result } = await store.update(group.id, (current) => {
                    if (!sameItems(current, group.session, group.ids)) {
                        throw new HttpError(409, 'preview_stale', 'Your items changed since you opened this. Check the list, then queue again.');
                    }
                    return queueForAgent(current, group.ids, now());
                }, { by: 'user' });
                queued.push(...result.map((id) => ({ taskId: group.taskId, id })));
                if (group.id === getSessionId()) revision = session.revision;
            }
        } catch (error) {
            if (error instanceof ModelError && error.code === 'invalid_state') {
                throw new HttpError(409, 'preview_stale', 'Some of these items were sent or removed meanwhile. Check the list, then queue again.');
            }
            throw error;
        }
        const note = typeof body?.note === 'string' ? body.note.trim() : '';
        if (note) {
            const { session, result } = await userUpdate((current) => {
                const created = createFeedback(current, { kind: 'context', text: note }, now());
                return { session: queueForAgent(created.session, [created.result.id], now()).session, result: created.result };
            });
            queued.push({ taskId: session.task.id, id: result.id });
            revision = session.revision;
        }
        return { revision, queued };
    };

    const routes = {
        'GET /api/state': () => stateResponse(),

        'POST /api/feedback': async (body) => {
            const { session, result } = await userUpdate((current) => createFeedback(current, body, now()));
            return { revision: session.revision, item: result };
        },

        'POST /api/feedback/transition': async (body) => {
            const id = typeof body?.id === 'string' ? body.id : '';
            const to = typeof body?.to === 'string' ? body.to : '';
            const doc = await docFor(body?.taskId);
            const { session, result } = await store.update(doc.id, (current) => {
                const item = current.feedback.find((candidate) => candidate.id === id);
                if (!item) {
                    throw new ModelError('not_found', `No feedback item ${id} exists.`);
                }
                if (!(USER_TRANSITIONS[item.state] ?? []).includes(to)) {
                    throw new ModelError('invalid_transition', `You cannot move feedback from ${item.state} to ${to}.`);
                }
                return transitionFeedback(current, id, to, { by: 'user', correction: body?.correction }, now());
            }, { by: 'user' });
            return { revision: session.revision, item: result };
        },

        'POST /api/feedback/edit': async (body) => {
            const doc = await docFor(body?.taskId);
            const { session, result } = await store.update(doc.id, (current) => editFeedback(current, body?.id, body?.text, now()), { by: 'user' });
            return { revision: session.revision, item: result };
        },

        // Takes queued items back before the agent collects them; they wait for the user again.
        'POST /api/feedback/take-back': async (body) => {
            const doc = await docFor(body?.taskId);
            const ids = Array.isArray(body?.ids) ? body.ids.slice(0, LIMITS.feedbackItems) : [];
            if (!ids.length) throw new HttpError(400, 'invalid_input', 'ids must list the items to take back.');
            const { session, result } = await store.update(doc.id, (current) => takeBackFeedback(current, ids, now()), { by: 'user' });
            return { revision: session.revision, ids: result };
        },

        'POST /api/feedback/discard': async (body) => {
            const groups = await deliveryGroups(body, LIMITS.feedbackItems);
            const discarded = [];
            const skipped = [];
            for (const group of groups) {
                const { result } = await store.update(group.id, (current) => discardFeedback(current, group.ids, now()), { by: 'user' });
                discarded.push(...result.discarded.map((id) => ({ taskId: group.taskId, id })));
                skipped.push(...result.skipped.map((id) => ({ taskId: group.taskId, id })));
            }
            return { discarded, skipped };
        },

        'POST /api/suggestion': async (body) => {
            const { session, result } = await userUpdate((current) => suggestEdit(current, body, now()));
            if (result.conflict) {
                throw Object.assign(new HttpError(409, 'conflict', 'This section changed while you were editing.'), { detail: { section: result.section } });
            }
            return { revision: session.revision, feedbackId: result.feedbackId ?? null, withdrawn: result.withdrawn ?? null, unchanged: result.unchanged === true };
        },

        'POST /api/preferences': async (body) => ({ preferences: await store.savePreferences(preferencesPatch(body)) }),

        'POST /api/delivery/preview': async (body) => compose(await deliveryGroups(body), body),

        // Sends the items the user reviewed, only when they still match the preview (by digest).
        // Queue marks them for the agent's next checkpoint; they stay in the canvas, and an
        // optional note waits with them as context. Send now hands them to the chat as one
        // message the agent reads at its next step. Each task's items are held first so a
        // concurrent take or send cannot repeat them; any failure before the message is handed
        // to the chat releases every hold. Once it is handed over, the items are marked sent,
        // with the chat's message ID, and never released.
        'POST /api/delivery': async (body) => {
            const mode = body?.mode === undefined ? 'send' : body.mode;
            if (mode !== 'send' && mode !== 'queue') {
                throw new HttpError(400, 'invalid_input', "mode is send, which the chat delivers at the agent's next step, or queue, which waits in the canvas for the agent's next checkpoint.");
            }
            const digest = typeof body?.digest === 'string' ? body.digest : '';
            const groups = await deliveryGroups(body);
            const message = compose(groups, body);
            if (message.digest !== digest) {
                throw Object.assign(new HttpError(409, 'preview_stale', 'Your items changed since you opened this. Check the list, then send again.'), { detail: { preview: message } });
            }
            if (mode === 'queue') {
                return queueGroups(groups, body);
            }
            const held = [];
            const releaseAll = async () => {
                for (const group of held) {
                    await store.update(group.id, (current) => releaseDelivery(current, group.ids, now()), { by: 'user' })
                        .catch((releaseError) => log(`Could not release delivery claim: ${releaseError instanceof Error ? releaseError.message : 'error'}`, 'warning'));
                }
            };
            try {
                for (const group of groups) {
                    await store.update(group.id, (current) => {
                        if (!sameItems(current, group.session, group.ids)) {
                            throw new HttpError(409, 'preview_stale', 'Your items changed since you opened this. Check the list, then send again.');
                        }
                        return { session: claimDelivery(current, group.ids, now()).session, result: null };
                    }, { by: 'user' });
                    held.push(group);
                }
            } catch (error) {
                await releaseAll();
                if (error instanceof ModelError && error.code === 'invalid_state') {
                    throw new HttpError(409, 'preview_stale', 'Some of these items were sent or removed meanwhile. Check the list, then send again.');
                }
                throw error;
            }
            let sent = null;
            try {
                sent = await deliver({ prompt: message.prompt, displayPrompt: message.displayPrompt, ids: message.ids, mode: 'immediate' });
            } catch (error) {
                await releaseAll();
                const code = error instanceof ModelError ? error.code : 'delivery_failed';
                log(`Send failed: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                throw new HttpError(STATUS_FOR[code] ?? 502, code, error instanceof Error ? error.message : 'Sending failed.');
            }
            const messageId = typeof sent?.messageId === 'string' ? sent.messageId : null;
            const delivered = [];
            const unrecorded = [];
            let revision = null;
            for (const group of groups) {
                let marked = null;
                for (let attempt = 0; attempt < MARK_ATTEMPTS && !marked; attempt += 1) {
                    try {
                        marked = await store.update(group.id, (current) => markDelivered(current, group.ids, 'send', now(), { tasks: groups.length, messageId }), { by: 'user' });
                    } catch (error) {
                        log(`Sent, but the canvas could not record it for ${group.taskId} (attempt ${attempt + 1}): ${error instanceof Error ? error.message : 'error'}`, 'warning');
                        await new Promise((resolve) => setTimeout(resolve, markRetryMs * (attempt + 1)));
                    }
                }
                if (marked) {
                    delivered.push(...marked.result);
                    if (group.id === getSessionId()) revision = marked.session.revision;
                } else {
                    unrecorded.push(group.taskId);
                }
            }
            // The chat reports when the agent picks the message up; remember which items it carried.
            await deps.pickups?.remember(messageId, groups.filter((group) => !unrecorded.includes(group.taskId)).map((group) => ({ id: group.id, ids: group.ids })))
                .catch((error) => log(`Could not watch for the agent picking up the message: ${error instanceof Error ? error.message : 'error'}`, 'warning'));
            if (unrecorded.length) {
                return { revision, delivered, warning: `The message was sent, but the canvas could not record it for ${unrecorded.join(', ')} yet. Those items stay marked as sending, so they will not be sent again.` };
            }
            return { revision, delivered, parts: message.parts };
        },

        'POST /api/task': async (body) => {
            if (!deps.switchTask) {
                throw new HttpError(404, 'not_found', 'This canvas cannot switch tasks.');
            }
            const ref = typeof body?.statePath === 'string' ? { statePath: body.statePath } : { taskId: typeof body?.taskId === 'string' ? body.taskId : '' };
            // A switch the reader chose stops following when the page asks, even onto a running loop.
            const result = await deps.switchTask(ref, { paused: body?.follow === false });
            return { sessionId: result.sessionId };
        },

        'GET /api/sessions': async () => {
            if (!deps.listSessions) {
                throw new HttpError(404, 'not_found', 'This canvas shows the sample session, which has no other sessions.');
            }
            return deps.listSessions();
        },

        'POST /api/session': async (body) => {
            if (!deps.switchSession) {
                throw new HttpError(404, 'not_found', 'This canvas cannot switch sessions.');
            }
            const key = typeof body?.key === 'string' ? body.key : '';
            if (!/^\d{4}-\d{2}-\d{2}\/[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(key)) throw new HttpError(400, 'invalid_input', 'key must be a session such as 2026-01-15/trail-maps.');
            const result = await deps.switchSession(key, { paused: body?.follow === false });
            return { sessionId: result.sessionId };
        },

        // { follow: false } pauses following; anything else resumes it.
        'POST /api/follow': async (body) => {
            if (body?.follow === false) {
                if (!deps.pauseFollowing) {
                    throw new HttpError(404, 'not_found', 'This canvas does not follow a session.');
                }
                const paused = await deps.pauseFollowing();
                return { sessionId: paused.sessionId, following: false };
            }
            if (!deps.resumeFollowing) {
                throw new HttpError(404, 'not_found', 'This canvas does not follow a session.');
            }
            const result = await deps.resumeFollowing();
            return { sessionId: result.sessionId, following: true };
        },

        // The Not connected screen: show the sample, or ask the agent to connect the canvas with fixed text.
        'POST /api/sample': async () => {
            if (!deps.showSample) throw new HttpError(404, 'not_found', 'This canvas cannot show the sample.');
            const shown = await deps.showSample();
            return { sessionId: shown.sessionId };
        },

        'POST /api/connect-request': async () => {
            if (connected()) throw new HttpError(409, 'conflict', 'This canvas is already connected.');
            const at = Date.parse(now());
            if (lastConnectRequest && at - lastConnectRequest < CONNECT_REQUEST_INTERVAL_MS) {
                throw new HttpError(429, 'too_soon', 'The agent was just asked; give it a moment to connect the canvas.');
            }
            const canvas = getCanvas();
            const displayPrompt = connectRequestText(canvas?.handle);
            const prompt = `${displayPrompt}\n\nThe RPI Workflow canvas "${canvas?.instanceId ?? ''}" shows no RPI session. Call its show_task action with { "state": "<this conversation's RPI state file>" }, or { "task": "current" } for the most recently changed running session. If this conversation has no RPI session, tell the user instead.`;
            lastConnectRequest = at;
            try {
                await deliver({ prompt, displayPrompt, ids: [] });
            } catch (error) {
                lastConnectRequest = 0;
                throw error;
            }
            return { sent: true, retryAfterMs: CONNECT_REQUEST_INTERVAL_MS };
        },

        'POST /api/source': async (body) => {
            try {
                const { absolute: _absolute, ...shown } = await readWorkspaceFile(workspaceRoot(), body?.path, body?.anchor);
                return shown;
            } catch (error) {
                throw fileHttpError(error);
            }
        },

        'POST /api/open': async (body) => {
            const editor = getEditor();
            if (!editor) throw new HttpError(404, 'editor_unavailable', 'No editor is available to open files from this canvas. Use Copy path instead.');
            try {
                const file = await readWorkspaceFile(workspaceRoot(), body?.path, body?.anchor);
                await editor.open(file.absolute, file.line);
                return { opened: true, path: file.path, line: file.line, match: file.match };
            } catch (error) {
                throw fileHttpError(error);
            }
        },

        'POST /api/client-info': async (body) => {
            clientInfo = clientInfoFrom(body);
            return { ok: true };
        },
    };

    /** The workspace root of a canvas reading real RPI files; other canvases show no files. */
    function workspaceRoot() {
        const source = deps.getSource?.();
        const root = source?.kind === 'rpi' ? source.workspace?.root : null;
        if (!root) throw new HttpError(404, 'source_unavailable', 'This canvas is not reading workspace files, so it cannot show them.');
        return root;
    }

    function openStream(req, res) {
        res.writeHead(200, {
            ...BASE_HEADERS,
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-store',
            Connection: 'keep-alive',
        });
        res.write('retry: 3000\n\n');
        clients.add(res);
        if (clients.size === 1) {
            syncWatches(new Set([getSessionId(), ...others]));
            deps.getSource?.()?.follower?.start();
        }
        if (!heartbeat) {
            heartbeat = setInterval(() => {
                for (const client of clients) {
                    client.write(': ping\n\n');
                }
            }, HEARTBEAT_MS);
            heartbeat.unref?.();
        }
        // A canvas that shows no session has no document to read; its page still listens for the agent to connect it.
        (getSessionId() ? store.load(getSessionId()) : Promise.resolve(null)).then((session) => {
            res.write(`event: revision\ndata: ${JSON.stringify({ revision: session?.revision ?? 0 })}\n\n`);
            if (pendingFocus) {
                res.write(`event: focus\ndata: ${JSON.stringify(pendingFocus)}\n\n`);
                pendingFocus = null;
            }
        }).catch(() => {
            res.write(`event: error\ndata: ${JSON.stringify({ message: 'The session could not be read.' })}\n\n`);
        });
        req.on('close', () => {
            clients.delete(res);
            if (clients.size === 0) {
                unwatchAll();
                deps.getSource?.()?.follower?.stop();
                clearInterval(heartbeat);
                heartbeat = null;
            }
        });
    }

    async function serveStatic(res, asset, method) {
        let body;
        try {
            body = await fs.readFile(path.join(UI_DIR, asset.file), 'utf8');
        } catch {
            send(res, 404, 'Not found', { 'Content-Type': 'text/plain; charset=utf-8' });
            return;
        }
        if (asset.template) {
            body = renderShell(body, await store.loadPreferences().catch(() => ({ theme: 'system', contrast: 'standard' })));
        }
        send(res, 200, method === 'HEAD' ? undefined : body, { 'Content-Type': asset.type, 'Cache-Control': 'no-cache' });
    }

    async function handle(req, res) {
        const host = String(req.headers.host ?? '').toLowerCase();
        if (host !== `127.0.0.1:${port}` && host !== `localhost:${port}`) {
            sendJson(res, 421, { error: { code: 'invalid_host', message: 'Unexpected Host header' } });
            return;
        }
        let url;
        try {
            url = new URL(req.url ?? '/', `http://${host}`);
        } catch {
            sendJson(res, 400, { error: { code: 'invalid_input', message: 'Malformed URL' } });
            return;
        }
        const method = req.method ?? 'GET';
        if (url.pathname.startsWith('/api/')) {
            const site = req.headers['sec-fetch-site'];
            if (site !== undefined && site !== 'same-origin' && site !== 'none') {
                sendJson(res, 403, { error: { code: 'cross_site', message: 'Cross-site requests are not allowed' } });
                return;
            }
            // The event stream cannot send headers, so it carries the key in its address.
            const given = req.headers['x-rw-key'] ?? (url.pathname === '/api/events' ? url.searchParams.get('k') : null);
            if (!keyMatches(given)) {
                sendJson(res, 403, { error: { code: 'invalid_key', message: 'This request does not come from this canvas. Reopen the canvas.' } });
                return;
            }
            if (url.pathname === '/api/events' && method === 'GET') {
                openStream(req, res);
                return;
            }
            const handler = routes[`${method === 'HEAD' ? 'GET' : method} ${url.pathname}`];
            if (!handler) {
                const known = url.pathname === '/api/events' || Object.keys(routes).some((key) => key.endsWith(` ${url.pathname}`));
                sendJson(res, known ? 405 : 404, { error: { code: known ? 'method_not_allowed' : 'not_found', message: known ? 'Method not allowed' : 'Not found' } });
                return;
            }
            try {
                const body = method === 'POST' ? await readJsonBody(req, url.pathname === '/api/suggestion' ? MAX_SECTION_BODY : MAX_BODY) : undefined;
                sendJson(res, 200, await handler(body));
            } catch (error) {
                if (error instanceof HttpError) {
                    sendJson(res, error.status, { error: { code: error.code, message: error.message, ...(error.detail ?? {}) } });
                } else if (error instanceof ModelError) {
                    const status = STATUS_FOR[error.code] ?? (error.code.startsWith('storage_') ? 500 : 400);
                    sendJson(res, status, { error: { code: error.code, message: error.message } });
                } else {
                    log(`Request failed: ${error instanceof Error ? error.message : 'error'}`, 'error');
                    sendJson(res, 500, { error: { code: 'internal_error', message: 'The canvas could not complete that request. Try again.' } });
                }
            }
            return;
        }
        if (method !== 'GET' && method !== 'HEAD') {
            send(res, 405, 'Method not allowed', { 'Content-Type': 'text/plain; charset=utf-8', Allow: 'GET, HEAD' });
            return;
        }
        const asset = Object.prototype.hasOwnProperty.call(STATIC_FILES, url.pathname) ? STATIC_FILES[url.pathname] : null;
        if (!asset) {
            send(res, 404, 'Not found', { 'Content-Type': 'text/plain; charset=utf-8' });
            return;
        }
        await serveStatic(res, asset, method);
    }

    return {
        /** The page address the host opens, with this canvas's key. */
        get url() {
            return port ? pageUrl() : null;
        },
        /** The server's address without the key, safe to report. */
        get address() {
            return port ? `http://127.0.0.1:${port}/` : null;
        },
        /** The editor that opens workspace files from this canvas, by name, or null. */
        get editor() {
            const found = getEditor();
            return found ? { name: found.name } : null;
        },
        get listening() {
            return Boolean(server?.listening);
        },
        get clientInfo() {
            return clientInfo;
        },
        get streamClients() {
            return clients.size;
        },

        /** Points the open page at an item; delivered on connect when no page is open. */
        focus(request) {
            const data = { phase: request.phase ?? null, itemId: request.itemId ?? null, at: now() };
            if (clients.size === 0) {
                pendingFocus = data;
            } else {
                broadcast('focus', data);
            }
            return { delivered: clients.size > 0 };
        },

        /** Tells the page that the selected session changed. */
        notifyReload() {
            broadcast('reload', { at: now() });
        },

        /**
         * Follows a new session after the instance switched documents or its follow state
         * changed: rebinds the store watchers and the source follower while a page is
         * connected, then tells the page, including where following moved it.
         *
         * @param {{ moved?: { from: string, to: string, title: string } }} [detail]
         */
        rebind(detail = {}) {
            others = new Set();
            if (clients.size > 0) {
                unwatchAll();
                syncWatches(new Set([getSessionId()]));
                deps.getSource?.()?.follower?.start();
            }
            broadcast('reload', { at: now(), ...(detail.moved ? { moved: detail.moved } : {}) });
        },

        start() {
            if (server?.listening) {
                return Promise.resolve(pageUrl());
            }
            if (starting) {
                return starting;
            }
            const created = http.createServer((req, res) => {
                handle(req, res).catch(() => {
                    if (!res.headersSent) {
                        sendJson(res, 500, { error: { code: 'internal_error', message: 'Unexpected error' } });
                    } else {
                        res.destroy();
                    }
                });
            });
            created.keepAliveTimeout = 5000;
            created.requestTimeout = 30000;
            server = created;
            const pending = new Promise((resolve, reject) => {
                created.once('error', (error) => {
                    if (server === created) {
                        server = null;
                    }
                    reject(error);
                });
                created.listen(0, '127.0.0.1', () => {
                    created.removeAllListeners('error');
                    if (server !== created) {
                        created.close();
                        reject(new Error('The server was stopped before it started.'));
                        return;
                    }
                    port = /** @type {import('node:net').AddressInfo} */ (created.address()).port;
                    resolve(pageUrl());
                });
            });
            starting = pending;
            const settle = () => {
                if (starting === pending) {
                    starting = null;
                }
            };
            pending.then(settle, settle);
            return pending;
        },

        stop() {
            starting = null;
            for (const res of clients) {
                res.end();
            }
            clients.clear();
            unwatchAll();
            deps.getSource?.()?.follower?.stop();
            clearInterval(heartbeat);
            heartbeat = null;
            store.events.off('change', onChange);
            store.events.off('preferences', onPreferences);
            if (!server) {
                return Promise.resolve();
            }
            const closing = server;
            server = null;
            port = 0;
            if (!closing.listening) {
                return Promise.resolve();
            }
            return new Promise((resolve) => {
                closing.close(() => resolve());
                closing.closeAllConnections?.();
            });
        },
    };
}
