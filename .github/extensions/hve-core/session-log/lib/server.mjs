// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildContextSections, contextCounts } from './context.mjs';
import { DEFINITION_KINDS, LIVE_DEFINITION_KINDS } from './definitions.mjs';
import { mergeInventory } from './inventory.mjs';
import { IndexCache, parseFieldPath, publicEntry, ROOT_AGENT } from './indexer.mjs';
import { AGENT_KEY_RE, isSessionId, sessionFolder } from './paths.mjs';
import { SessionCatalog } from './sessions.mjs';

const UI_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'ui');

/** Static files the page may load; nothing outside this map is ever served. */
const STATIC_FILES = Object.freeze({
    '/': { file: 'index.html', type: 'text/html; charset=utf-8' },
    '/index.html': { file: 'index.html', type: 'text/html; charset=utf-8' },
    '/ui/styles.css': { file: 'styles.css', type: 'text/css; charset=utf-8' },
    '/ui/app.mjs': { file: 'app.mjs', type: 'text/javascript; charset=utf-8' },
    '/ui/render.mjs': { file: 'render.mjs', type: 'text/javascript; charset=utf-8' },
    '/ui/markdown.mjs': { file: 'markdown.mjs', type: 'text/javascript; charset=utf-8' },
    '/ui/format.mjs': { file: 'format.mjs', type: 'text/javascript; charset=utf-8' },
    '/ui/highlight.mjs': { file: 'highlight.mjs', type: 'text/javascript; charset=utf-8' },
    '/ui/sync.mjs': { file: 'sync.mjs', type: 'text/javascript; charset=utf-8' },
});

export const CONTENT_SECURITY_POLICY = [
    "default-src 'none'",
    "script-src 'self'",
    "style-src 'self'",
    "img-src 'self' data:",
    "connect-src 'self'",
    "font-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
].join('; ');

const BASE_HEADERS = Object.freeze({
    'Content-Security-Policy': CONTENT_SECURITY_POLICY,
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'Cross-Origin-Resource-Policy': 'same-origin',
});

const TOOL_CALL_ID_RE = /^[A-Za-z0-9_.:-]{1,200}$/;
const MAX_BODY_BYTES = 4096;
const DEFINITION_NAME_RE = /^[^\u0000-\u001f\u007f]{1,400}$/;
/** Kinds whose live definition may stand in, clearly labeled, for a session other than the live one. */
/** Kinds whose live definition is worth showing, labeled, for a session other than the live one. */
const FALLBACK_KINDS = new Set(['tool', 'agent', 'canvas']);
const CATALOG_KINDS = Object.freeze({ tools: 'tool', canvases: 'canvas', subagents: 'subagent' });

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

function parseIntParam(params, name, { min = 0, max = Number.MAX_SAFE_INTEGER, fallback } = {}) {
    const raw = params.get(name);
    if (raw === null || raw === '') {
        if (fallback !== undefined) {
            return fallback;
        }
        throw new HttpError(400, 'invalid_input', `Missing parameter: ${name}`);
    }
    if (!/^-?\d{1,15}$/.test(raw)) {
        throw new HttpError(400, 'invalid_input', `Parameter ${name} must be an integer`);
    }
    const value = Number(raw);
    if (value < min || value > max) {
        throw new HttpError(400, 'invalid_input', `Parameter ${name} is out of range`);
    }
    return value;
}

/**
 * Shared per-root resources: one catalog and one index cache per session-state root.
 */
const sharedByRoot = new Map();

/**
 * Returns the shared catalog and index cache for a session-state root.
 *
 * @param {string} root
 */
export function sharedResources(root) {
    let shared = sharedByRoot.get(root);
    if (!shared) {
        shared = {
            catalog: new SessionCatalog(root),
            indexes: new IndexCache((sessionId) => path.join(sessionFolder(root, sessionId), 'events.jsonl')),
        };
        sharedByRoot.set(root, shared);
    }
    return shared;
}

/**
 * Creates the canvas HTTP server for one canvas instance. Has no SDK dependency.
 *
 * @param {object} options
 * @param {string} options.root Session-state root.
 * @param {string} [options.rootSource] How the root was resolved.
 * @param {() => string | null} options.getCurrentSessionId Session that opened the canvas.
 * @param {(() => Promise<object>) | null} [options.liveInventory] Live inventory for the current session.
 * @param {{ sessionId: () => string | null, lookup: (kind: string, name: string) => Promise<object | null> } | null} [options.liveDefinitions]
 *   Live definitions from the session the extension joined.
 * @param {string | null} [options.initialSessionId] Session to select first.
 * @param {(message: string, level?: 'info' | 'warning' | 'error') => void} [options.log] Diagnostics sink.
 * @param {string} [options.uiDir] Folder holding UI assets.
 * @param {{ catalog: SessionCatalog, indexes: IndexCache }} [options.shared] Injected shared resources.
 */
export function createSessionLogServer(options) {
    const root = options.root;
    const shared = options.shared ?? sharedResources(root);
    const log = options.log ?? (() => {});
    const uiDir = options.uiDir ?? UI_DIR;
    const assets = new Map();
    for (const [route, spec] of Object.entries(STATIC_FILES)) {
        const filePath = path.join(uiDir, spec.file);
        if (fs.existsSync(filePath)) {
            assets.set(route, { body: fs.readFileSync(filePath), type: spec.type });
        }
    }

    const state = {
        selection: isSessionId(options.initialSessionId) ? options.initialSessionId.toLowerCase() : null,
        focus: null,
        version: 1,
    };

    let server = null;
    /** @type {Promise<string> | null} */
    let starting = null;
    let port = 0;

    function currentSessionId() {
        const value = options.getCurrentSessionId?.();
        return isSessionId(value) ? value.toLowerCase() : null;
    }

    function selectedSessionId() {
        return state.selection ?? currentSessionId();
    }

    /**
     * Applies a selection request: a session ID, `current`, or null to keep the selection.
     *
     * @param {string | null | undefined} requested
     * @returns {string | null} The selected session ID.
     */
    function select(requested) {
        if (requested === undefined || requested === null || requested === '') {
            return selectedSessionId();
        }
        if (requested === 'current') {
            if (state.selection !== null) {
                state.selection = null;
                state.version += 1;
            }
            return currentSessionId();
        }
        if (!isSessionId(requested)) {
            throw new HttpError(400, 'invalid_input', 'sessionId must be a session ID or "current"');
        }
        const normalized = requested.toLowerCase();
        if (state.selection !== normalized) {
            state.selection = normalized;
            state.focus = null;
            state.version += 1;
        }
        return normalized;
    }

    /**
     * Asks the page to reveal an agent log or tool call.
     *
     * @param {{ agentKey?: string, toolCallId?: string, seq?: number }} focus
     */
    function requestFocus(focus) {
        state.focus = { ...focus, nonce: state.version + 1 };
        state.version += 1;
    }

    function stateSnapshot() {
        return {
            stateVersion: state.version,
            currentSessionId: currentSessionId(),
            selectedSessionId: selectedSessionId(),
            followsCurrent: state.selection === null,
            focus: state.focus,
            root,
            rootSource: options.rootSource ?? null,
        };
    }

    async function requireSession(params) {
        const sessionId = params.get('session');
        if (!isSessionId(sessionId)) {
            throw new HttpError(400, 'invalid_input', 'Parameter session must be a session ID');
        }
        const normalized = sessionId.toLowerCase();
        const record = await shared.catalog.get(normalized);
        if (!record) {
            throw new HttpError(404, 'session_not_found', 'No recorded events were found for that session');
        }
        const index = shared.indexes.get(normalized);
        await index.refresh();
        return { sessionId: normalized, record, index };
    }

    function requireAgent(params, index) {
        const agent = params.get('agent') ?? ROOT_AGENT;
        if (!AGENT_KEY_RE.test(agent)) {
            throw new HttpError(400, 'invalid_input', 'Parameter agent is not a valid agent key');
        }
        const key = agent.toLowerCase() === ROOT_AGENT ? ROOT_AGENT : agent.toLowerCase();
        if (!index.agents.has(key)) {
            throw new HttpError(404, 'agent_not_found', 'That agent is not recorded in this session');
        }
        return key;
    }

    const routes = {
        'GET /api/state': async () => stateSnapshot(),

        'POST /api/select': async (_params, body) => {
            if (!body || typeof body !== 'object') {
                throw new HttpError(400, 'invalid_input', 'Body must be a JSON object');
            }
            select(body.sessionId);
            return stateSnapshot();
        },

        'GET /api/sessions': async () => {
            const current = currentSessionId();
            const sessions = await shared.catalog.list();
            return {
                root,
                rootSource: options.rootSource ?? null,
                sessions: sessions.map((session) => ({ ...session, isCurrent: session.sessionId === current })),
            };
        },

        'GET /api/summary': async (params) => {
            const { sessionId, record, index } = await requireSession(params);
            const summary = index.getSummary();
            return { ...summary, session: { ...summary.session, ...record, isCurrent: sessionId === currentSessionId() } };
        },

        'GET /api/system-prompt': async (params) => {
            const { index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const seq = params.has('seq') ? parseIntParam(params, 'seq', { min: 0 }) : undefined;
            const prompt = await index.getSystemPrompt(agent, seq);
            if (!prompt) {
                throw new HttpError(404, 'entry_not_found', 'No system prompt is recorded for that agent and version');
            }
            return prompt;
        },

        'GET /api/agent-instructions': async (params) => {
            const { index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const instructions = await index.getAgentInstructions(agent);
            if (!instructions) {
                throw new HttpError(404, 'entry_not_found', 'No agent instructions are recorded for that agent');
            }
            return instructions;
        },

        'GET /api/compaction': async (params) => {
            const { index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const seq = parseIntParam(params, 'seq', { min: 0 });
            const which = params.get('which');
            if (which !== 'request' && which !== 'summary') {
                throw new HttpError(400, 'invalid_input', 'Parameter which must be request or summary');
            }
            const start = parseIntParam(params, 'start', { min: 0, fallback: 0 });
            const page = await index.readCompactionText(agent, seq, which, start);
            if (!page) {
                throw new HttpError(404, 'field_not_found', which === 'request' ? 'No compaction request is recorded for that entry' : 'No compaction summary is recorded for that entry');
            }
            return page;
        },

        'GET /api/inventory': async (params) => {
            const { sessionId, index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const part = params.get('part');
            if (part !== null && part !== 'counts') {
                throw new HttpError(400, 'invalid_input', 'Parameter part must be counts when present');
            }
            const recorded = index.getRecordedInventory(agent);
            const sessionLive = sessionId === currentSessionId();
            let live = null;
            if (sessionLive && typeof options.liveInventory === 'function') {
                try {
                    live = await options.liveInventory();
                } catch (error) {
                    log(`Live inventory unavailable: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                }
            }
            const catalogs = {};
            const provider = options.liveDefinitions;
            if (sessionLive && typeof provider?.catalog === 'function' && provider.sessionId?.() === sessionId) {
                await Promise.all(Object.entries(CATALOG_KINDS).map(async ([key, kind]) => {
                    try {
                        catalogs[key] = await provider.catalog(kind);
                    } catch (error) {
                        log(`Live ${kind} catalog unavailable: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                    }
                }));
            }
            const sections = buildContextSections({
                recorded,
                live,
                catalogs,
                mainAgent: agent === ROOT_AGENT,
                readCounts: (paths) => index.getReadCounts(agent, paths),
            });
            if (part === 'counts') {
                return { sessionId, agent, inventoryVersion: index.inventoryVersion, counts: contextCounts(sections) };
            }
            // The page needs model facts and prompt sections besides the Context sections; the full
            // lists already live in the sections, so the merged lists are not repeated.
            const merged = mergeInventory(recorded, agent === ROOT_AGENT ? live : null);
            return {
                sessionId,
                agent,
                inventoryVersion: index.inventoryVersion,
                isLive: merged.isLive,
                model: merged.model,
                currentAgent: merged.currentAgent,
                recorded: recorded ? { agentKey: recorded.agentKey, customAgent: recorded.customAgent, systemPrompt: recorded.systemPrompt } : null,
                sections,
            };
        },

        'GET /api/definition': async (params) => {
            const { sessionId, index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const kind = params.get('kind');
            if (!DEFINITION_KINDS.includes(kind)) {
                throw new HttpError(400, 'invalid_input', `Parameter kind must be one of ${DEFINITION_KINDS.join(', ')}`);
            }
            const name = params.get('name') ?? '';
            if (!DEFINITION_NAME_RE.test(name)) {
                throw new HttpError(400, 'invalid_input', 'Parameter name must be 1 to 400 characters without control characters');
            }
            const provider = options.liveDefinitions ?? null;
            const liveSessionId = provider?.sessionId?.() ?? null;
            const sameSession = liveSessionId !== null && liveSessionId === sessionId;
            let live = null;
            if (provider && liveSessionId && LIVE_DEFINITION_KINDS.includes(kind) && (sameSession || FALLBACK_KINDS.has(kind))) {
                try {
                    live = await provider.lookup(kind, name);
                } catch (error) {
                    log(`Live definition unavailable: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                    live = { status: 'unavailable', item: null };
                }
            }
            const aliases = kind === 'agent' && live?.item ? [live.item.id, live.item.name, live.item.displayName].filter((value) => typeof value === 'string') : [];
            const recorded = await index.getDefinition(agent, kind, name, aliases);
            return {
                sessionId,
                agent,
                kind,
                name,
                inventoryVersion: index.inventoryVersion,
                recorded,
                live: live
                    ? { ...live, scope: sameSession ? 'this-session' : 'live-session' }
                    : { status: provider && liveSessionId ? 'not-applicable' : 'unavailable', item: null, scope: null },
            };
        },

        'GET /api/entries': async (params) => {
            const { sessionId, index } = await requireSession(params);
            let agent = requireAgent(params, index);
            const limit = parseIntParam(params, 'limit', { min: 1, max: 500, fallback: 200 });
            let from = params.has('from') ? parseIntParam(params, 'from', { min: 0 }) : undefined;
            let anchor = null;
            if (params.has('anchorTool')) {
                const toolCallId = params.get('anchorTool');
                if (!TOOL_CALL_ID_RE.test(toolCallId)) {
                    throw new HttpError(400, 'invalid_input', 'Parameter anchorTool is not a valid tool call ID');
                }
                anchor = index.findEntry(agent, { toolCallId });
            } else if (params.has('anchorSeq')) {
                anchor = index.findEntry(agent, { seq: parseIntParam(params, 'anchorSeq', { min: 0 }) });
            }
            if (anchor) {
                agent = anchor.agent;
                from = Math.max(0, anchor.index - Math.floor(limit / 4));
            }
            const version = index.version;
            const epoch = index.epoch;
            const page = index.getEntries(agent, { from, limit });
            const entries = await index.withBodies(page.entries);
            return { sessionId, agent, version, epoch, total: page.total, from: page.from, anchorIndex: anchor?.index ?? null, entries: entries.map(publicEntry) };
        },

        'GET /api/poll': async (params) => {
            const sv = parseIntParam(params, 'sv', { min: 0, fallback: 0 });
            const result = { state: sv === state.version ? null : stateSnapshot() };
            if (!params.has('session')) {
                return result;
            }
            const { sessionId, record, index } = await requireSession(params);
            const agentParam = params.get('agent') ?? ROOT_AGENT;
            if (!AGENT_KEY_RE.test(agentParam)) {
                throw new HttpError(400, 'invalid_input', 'Parameter agent is not a valid agent key');
            }
            const agent = agentParam.toLowerCase() === ROOT_AGENT ? ROOT_AGENT : agentParam.toLowerCase();
            const epoch = parseIntParam(params, 'epoch', { min: 0, fallback: index.epoch });
            const sinceVersion = parseIntParam(params, 'v', { min: 0, fallback: 0 });
            const since = parseIntParam(params, 'since', { min: 0, fallback: 0 });
            const version = index.version;
            // Activity comes from the session's lock files, not its log, so every answer carries it.
            const active = record.active;
            if (epoch !== index.epoch) {
                return { ...result, sessionId, active, reset: true, epoch: index.epoch, version };
            }
            if (!index.agents.has(agent)) {
                return { ...result, sessionId, active, agentMissing: true, epoch: index.epoch, version };
            }
            if (sinceVersion === version) {
                return { ...result, sessionId, active, unchanged: true, epoch: index.epoch, version, inventoryVersion: index.inventoryVersion };
            }
            const changes = index.getChanges(agent, since, sinceVersion);
            const added = await index.withBodies(changes.added);
            // Updated entries need previews too, for example a tool that finished since the last poll.
            const updated = await index.withBodies(changes.updated);
            return {
                ...result,
                sessionId,
                active,
                agent,
                epoch: index.epoch,
                version,
                inventoryVersion: index.inventoryVersion,
                total: changes.total,
                resync: changes.resync,
                next: changes.next,
                more: changes.more,
                added: added.map(publicEntry),
                updated: updated.map(publicEntry),
            };
        },

        'GET /api/outline': async (params) => {
            const { sessionId, index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const status = params.get('status') ?? 'all';
            if (!['all', 'failed', 'running'].includes(status)) {
                throw new HttpError(400, 'invalid_input', 'Parameter status must be all, failed, or running');
            }
            const query = params.get('q') ?? '';
            if (query.length > 200) {
                throw new HttpError(400, 'invalid_input', 'Parameter q is too long');
            }
            const limit = parseIntParam(params, 'limit', { min: 1, max: 1000, fallback: 300 });
            return { sessionId, agent, version: index.version, ...index.getOutline(agent, { query, status, limit }) };
        },

        'GET /api/detail': async (params) => {
            const { index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const seq = parseIntParam(params, 'seq', { min: 0 });
            const hook = params.has('hook') ? parseIntParam(params, 'hook', { min: 0, max: 10000 }) : null;
            const detail = await index.readDetail(agent, seq, hook);
            if (!detail) {
                throw new HttpError(404, 'entry_not_found', 'That entry is not in this agent log');
            }
            return { ...detail, entry: publicEntry(detail.entry) };
        },

        'GET /api/field': async (params) => {
            const { index } = await requireSession(params);
            const agent = requireAgent(params, index);
            const seq = parseIntParam(params, 'seq', { min: 0 });
            const part = parseIntParam(params, 'part', { min: 0, max: 16 });
            const start = parseIntParam(params, 'start', { min: 0 });
            const fieldPath = params.get('path') ?? '';
            if (!parseFieldPath(fieldPath)) {
                throw new HttpError(400, 'invalid_input', 'path must be a field path such as data.content');
            }
            const hook = params.has('hook') ? parseIntParam(params, 'hook', { min: 0, max: 10000 }) : null;
            const field = await index.readField(agent, seq, part, fieldPath, start, hook);
            if (!field) {
                throw new HttpError(404, 'field_not_found', 'That field is not available');
            }
            return field;
        },
    };

    function send(res, status, body, headers) {
        res.writeHead(status, { ...BASE_HEADERS, ...headers });
        res.end(body);
    }

    function sendJson(res, status, value) {
        send(res, status, JSON.stringify(value), {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-store',
        });
    }

    function readJsonBody(req) {
        return new Promise((resolve, reject) => {
            const type = String(req.headers['content-type'] ?? '').split(';')[0].trim().toLowerCase();
            if (type !== 'application/json') {
                reject(new HttpError(415, 'unsupported_media_type', 'Content-Type must be application/json'));
                req.resume();
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
                if (size > MAX_BODY_BYTES) {
                    rejected = true;
                    chunks.length = 0;
                    reject(new HttpError(413, 'payload_too_large', 'Request body is too large'));
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
                    reject(new HttpError(400, 'invalid_input', 'Body is not valid JSON'));
                }
            });
            req.on('error', reject);
        });
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
        const isApi = url.pathname.startsWith('/api/');
        if (isApi) {
            const site = req.headers['sec-fetch-site'];
            if (site !== undefined && site !== 'same-origin' && site !== 'none') {
                sendJson(res, 403, { error: { code: 'cross_site', message: 'Cross-site requests are not allowed' } });
                return;
            }
            const handler = routes[`${method === 'HEAD' ? 'GET' : method} ${url.pathname}`];
            if (!handler) {
                const known = Object.keys(routes).some((key) => key.endsWith(` ${url.pathname}`));
                sendJson(res, known ? 405 : 404, { error: { code: known ? 'method_not_allowed' : 'not_found', message: known ? 'Method not allowed' : 'Not found' } });
                return;
            }
            try {
                const body = method === 'POST' ? await readJsonBody(req) : undefined;
                const result = await handler(url.searchParams, body);
                sendJson(res, 200, result);
            } catch (error) {
                if (error instanceof HttpError) {
                    sendJson(res, error.status, { error: { code: error.code, message: error.message } });
                } else {
                    log(`Request failed: ${error instanceof Error ? error.message : 'error'}`, 'error');
                    sendJson(res, 500, { error: { code: 'internal_error', message: 'The canvas could not read session data. Try again.' } });
                }
            }
            return;
        }
        if (method !== 'GET' && method !== 'HEAD') {
            send(res, 405, 'Method not allowed', { 'Content-Type': 'text/plain; charset=utf-8', Allow: 'GET, HEAD' });
            return;
        }
        const asset = assets.get(url.pathname);
        if (!asset) {
            send(res, 404, 'Not found', { 'Content-Type': 'text/plain; charset=utf-8' });
            return;
        }
        send(res, 200, method === 'HEAD' ? undefined : asset.body, { 'Content-Type': asset.type, 'Cache-Control': 'no-cache' });
    }

    return {
        select,
        requestFocus,
        stateSnapshot,
        selectedSessionId,
        currentSessionId,
        shared,
        get url() {
            return port ? `http://127.0.0.1:${port}/` : null;
        },
        get listening() {
            return Boolean(server?.listening);
        },
        /**
         * Starts listening on an ephemeral loopback port.
         *
         * @returns {Promise<string>} The page URL.
         */
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
                    // stop() ran while listen was pending; never leave this listener open.
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
        /** Stops the server and closes idle connections, including a start still in progress. */
        stop() {
            starting = null;
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
