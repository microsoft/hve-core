// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
    claimDelivery,
    composeDelivery,
    createFeedback,
    deriveView,
    markChecklist,
    markDelivered,
    releaseDelivery,
    ModelError,
    suggestEdit,
    transitionFeedback,
} from './model.mjs';
import { preferencesPatch } from './store.mjs';

const UI_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'ui');

const UI_MODULES = ['app.mjs', 'dom.mjs', 'markdown.mjs', 'diagram.mjs', 'components.mjs', 'view-research.mjs', 'view-plan.mjs', 'view-implement.mjs', 'view-review.mjs', 'view-followup.mjs'];

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
const USER_TRANSITIONS = Object.freeze({ draft: ['queued', 'dismissed'], queued: ['dismissed'], interpreted: ['applied', 'corrected'] });

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
});

/** Error that maps to a JSON error response. */
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
        reportedAt: new Date().toISOString(),
    };
}

/**
 * One page server per canvas instance. Reads and writes go through the shared store;
 * changes from any process reach the page through the event stream.
 *
 * @param {{
 *   store: ReturnType<import('./store.mjs').createStore>,
 *   getSessionId: () => string,
 *   getCanvas?: () => { handle: string, instanceId: string } | null,
 *   deliver?: (request: { prompt: string, displayPrompt: string, ids: string[] }) => Promise<void>,
 *   log?: (message: string, level?: string) => void,
 *   now?: () => string,
 *   getSource?: () => { follower?: { start: () => void, stop: () => void } } | undefined,
 *   switchTask?: (taskId: string) => Promise<{ sessionId: string }>,
 * }} deps
 */
export function createCanvasServer(deps) {
    const { store, getSessionId } = deps;
    const getCanvas = deps.getCanvas ?? (() => null);
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
    let unwatch = null;
    let heartbeat = null;
    let clientInfo = null;
    let pendingFocus = null;

    function broadcast(event, data) {
        const frame = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
        for (const res of clients) {
            res.write(frame);
        }
    }

    const onChange = (id, session) => {
        if (id === getSessionId()) {
            broadcast('revision', { revision: session.revision });
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

    async function stateResponse() {
        const id = getSessionId();
        const session = await store.load(id);
        if (!session) {
            throw new HttpError(404, 'not_found', 'No session is loaded yet. Ask the agent to load the sample scenario.');
        }
        return { revision: session.revision, session, view: deriveView(session), preferences: await store.loadPreferences(), canvas: getCanvas() };
    }

    const userUpdate = (change) => store.update(getSessionId(), change, { by: 'user' });

    const routes = {
        'GET /api/state': () => stateResponse(),

        'POST /api/feedback': async (body) => {
            const { session, result } = await userUpdate((current) => createFeedback(current, body, now()));
            return { revision: session.revision, item: result };
        },

        'POST /api/feedback/transition': async (body) => {
            const id = typeof body?.id === 'string' ? body.id : '';
            const to = typeof body?.to === 'string' ? body.to : '';
            const { session, result } = await userUpdate((current) => {
                const item = current.feedback.find((candidate) => candidate.id === id);
                if (!item) {
                    throw new ModelError('not_found', `No feedback item ${id} exists.`);
                }
                if (!(USER_TRANSITIONS[item.state] ?? []).includes(to)) {
                    throw new ModelError('invalid_transition', `You cannot move feedback from ${item.state} to ${to}.`);
                }
                return transitionFeedback(current, id, to, { by: 'user', correction: body?.correction }, now());
            });
            return { revision: session.revision, item: result };
        },

        'POST /api/suggestion': async (body) => {
            const { session, result } = await userUpdate((current) => suggestEdit(current, body, now()));
            if (result.conflict) {
                throw Object.assign(new HttpError(409, 'conflict', 'This section changed while you were editing.'), { detail: { section: result.section } });
            }
            return { revision: session.revision, feedbackId: result.feedbackId ?? null, withdrawn: result.withdrawn ?? null, unchanged: result.unchanged === true };
        },

        'POST /api/checklist': async (body) => {
            const { session, result } = await userUpdate((current) => markChecklist(current, body, now()));
            return { revision: session.revision, item: result };
        },

        'POST /api/preferences': async (body) => ({ preferences: await store.savePreferences(preferencesPatch(body)) }),

        'POST /api/delivery/preview': async (body) => {
            const session = await store.load(getSessionId());
            if (!session) {
                throw new HttpError(404, 'not_found', 'No session is loaded.');
            }
            return composeDelivery(session, body?.ids, now(), { canvas: getCanvas(), note: body?.note });
        },

        // Sends the items the user reviewed as one chat message, only when they still match the
        // preview (by digest), and holds them so a concurrent take or send cannot repeat them.
        'POST /api/delivery': async (body) => {
            if (body?.mode !== undefined && body.mode !== 'send') {
                throw new HttpError(400, 'invalid_input', 'The canvas sends items as a chat message; mode can only be send.');
            }
            const digest = typeof body?.digest === 'string' ? body.digest : '';
            const claimed = await userUpdate((current) => {
                const message = composeDelivery(current, body?.ids, now(), { canvas: getCanvas(), note: body?.note });
                if (message.digest !== digest) {
                    throw Object.assign(new HttpError(409, 'preview_stale', 'Your items changed since you opened this. Check the list, then send again.'), { detail: { preview: message } });
                }
                return { session: claimDelivery(current, message.ids, now()).session, result: message };
            });
            const message = claimed.result;
            try {
                await deliver({ prompt: message.prompt, displayPrompt: message.displayPrompt, ids: message.ids });
            } catch (error) {
                await userUpdate((current) => releaseDelivery(current, message.ids, now())).catch((releaseError) => log(`Could not release delivery claim: ${releaseError instanceof Error ? releaseError.message : 'error'}`, 'warning'));
                const code = error instanceof ModelError ? error.code : 'delivery_failed';
                log(`Send failed: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                throw new HttpError(STATUS_FOR[code] ?? 502, code, error instanceof Error ? error.message : 'Sending failed.');
            }
            try {
                const updated = await userUpdate((current) => markDelivered(current, message.ids, 'send', now()));
                return { revision: updated.session.revision, delivered: updated.result };
            } catch (error) {
                log(`Sent, but the canvas could not record it: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                return { revision: null, delivered: message.ids, warning: 'The message was sent, but the canvas could not record it yet. The items stay marked as sending, so they will not be sent again.' };
            }
        },

        'POST /api/task': async (body) => {
            if (!deps.switchTask) {
                throw new HttpError(404, 'not_found', 'This canvas cannot switch tasks.');
            }
            const taskId = typeof body?.taskId === 'string' ? body.taskId : '';
            const result = await deps.switchTask(taskId);
            return { sessionId: result.sessionId };
        },

        'POST /api/client-info': async (body) => {
            clientInfo = clientInfoFrom(body);
            return { ok: true };
        },
    };

    function openStream(req, res) {
        res.writeHead(200, {
            ...BASE_HEADERS,
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-store',
            Connection: 'keep-alive',
        });
        res.write('retry: 3000\n\n');
        clients.add(res);
        if (!unwatch) {
            unwatch = store.watch(getSessionId());
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
        store.load(getSessionId()).then((session) => {
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
                unwatch?.();
                unwatch = null;
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
        get url() {
            return port ? `http://127.0.0.1:${port}/` : null;
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
         * Follows a new session after the instance switched documents: rebinds the store
         * watcher and the source follower while a page is connected, then tells the page.
         */
        rebind() {
            if (clients.size > 0) {
                unwatch?.();
                unwatch = store.watch(getSessionId());
                deps.getSource?.()?.follower?.start();
            }
            broadcast('reload', { at: now() });
        },

        start() {
            if (server?.listening) {
                return Promise.resolve(`http://127.0.0.1:${port}/`);
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
                    resolve(`http://127.0.0.1:${port}/`);
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
            unwatch?.();
            unwatch = null;
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
