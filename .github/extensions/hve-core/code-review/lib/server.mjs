// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import http from 'node:http';
import fs from 'node:fs/promises';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { check, object } from '../../../../skills/coding-standards/code-review-core/scripts/lib/model.mjs';
import { editFeedback, evidenceFor, markTarget, queueFeedback, refresh, reportFor, sendFeedback, signature } from './model.mjs';

export const MAX_BODY = 64 * 1024;
export const CSP = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'";
const ASSETS = new Map([
    ['/', ['index.html', 'text/html; charset=utf-8']],
    ['/app.mjs', ['app.mjs', 'text/javascript; charset=utf-8']],
    ['/dom.mjs', ['dom.mjs', 'text/javascript; charset=utf-8']],
    ['/views.mjs', ['views.mjs', 'text/javascript; charset=utf-8']],
    ['/map.mjs', ['map.mjs', 'text/javascript; charset=utf-8']],
    ['/diagram.mjs', ['diagram.mjs', 'text/javascript; charset=utf-8']],
    ['/styles.css', ['styles.css', 'text/css; charset=utf-8']],
]);
const THEMES = new Set(['system', 'light', 'dark']);
const CONTRASTS = new Set(['standard', 'more']);
// Appearance is a personal preference shared by every panel this extension process serves.
const preferences = { theme: 'system', contrast: 'standard' };
const statusFor = { unauthorized: 401, forbidden: 403, not_found: 404, invalid_input: 400, invalid_record: 400, invalid_transition: 409, revision_conflict: 409, stale_target: 409, payload_too_large: 413, storage_busy: 409, delivery_unavailable: 503 };

/** Validates an appearance patch from the page. */
export function preferencesPatch(patch) {
    object(patch, [], 'appearance', ['theme', 'contrast']);
    if (patch.theme !== undefined) check(THEMES.has(patch.theme), 'theme must be system, light, or dark.', 'invalid_input');
    if (patch.contrast !== undefined) check(CONTRASTS.has(patch.contrast), 'contrast must be standard or more.', 'invalid_input');
    return patch;
}

/** Writes the current appearance and instance token into the page shell before first paint. */
export function renderShell(html, secret, appearance = preferences) {
    return html.replace('data-theme="__THEME__"', `data-theme="${THEMES.has(appearance.theme) ? appearance.theme : 'system'}"`)
        .replace('data-contrast="__CONTRAST__"', `data-contrast="${CONTRASTS.has(appearance.contrast) ? appearance.contrast : 'standard'}"`)
        .replace('__INSTANCE_TOKEN__', secret);
}

function equalToken(value, secret) {
    if (typeof value !== 'string') return false;
    const supplied = Buffer.from(value);
    const expected = Buffer.from(secret);
    return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

async function bodyOf(request) {
    check(request.headers['content-type']?.split(';')[0] === 'application/json', 'Use application/json.', 'invalid_input');
    check(!request.headers['content-length'] || Number(request.headers['content-length']) <= MAX_BODY, 'Request exceeds the body limit.', 'payload_too_large');
    let size = 0;
    const chunks = [];
    for await (const chunk of request) {
        size += chunk.length;
        check(size <= MAX_BODY, 'Request exceeds the body limit.', 'payload_too_large');
        chunks.push(chunk);
    }
    try {
        return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch {
        check(false, 'Request must contain valid JSON.', 'invalid_input');
    }
}

export function createCanvasServer(record, { deliver, log = (message) => process.stderr.write(`${message}\n`), pollMs = 750 } = {}) {
    const secret = randomBytes(32).toString('hex');
    const clients = new Set();
    let server;
    let url;
    let timer;
    let polling = false;
    let lastSignature;
    let current;
    let warning = null;
    let stopped = false;

    async function state() {
        try {
            current = await refresh(record.source);
            warning = null;
        } catch (error) {
            const next = { code: error.code ?? 'source_failed', message: error.message };
            if (JSON.stringify(next) !== JSON.stringify(warning)) log(`Code Review source error: ${next.code}: ${next.message}`);
            warning = next;
            if (!current) throw error;
        }
        return { ...current, outcome: warning ? null : current.outcome, stale: Boolean(warning), warning, focus: record.focus ?? null, focusRevision: record.focusRevision ?? 0 };
    }

    function notify() {
        for (const response of clients) response.write('event: change\ndata: {}\n\n');
    }

    function subscribe(response) {
        clients.add(response);
        response.write('event: change\ndata: {}\n\n');
        if (!timer) {
            timer = setInterval(async () => {
                if (polling || stopped) return;
                polling = true;
                try {
                    const next = await signature(record.source);
                    if (next !== lastSignature) {
                        lastSignature = next;
                        await state();
                        notify();
                    }
                } catch (error) {
                    warning = { code: error.code ?? 'source_failed', message: error.message };
                    log(`Code Review watcher error: ${warning.code}: ${warning.message}`);
                    notify();
                } finally {
                    polling = false;
                }
            }, pollMs);
            timer.unref();
        }
        response.on('close', () => {
            clients.delete(response);
            if (!clients.size) {
                clearInterval(timer);
                timer = null;
            }
        });
    }

    function authorize(request, api) {
        const origin = new URL(url).origin;
        check(request.headers.host === new URL(url).host, 'Unexpected Host.', 'forbidden');
        check(!request.headers.origin || request.headers.origin === origin, 'Cross-origin requests are refused.', 'forbidden');
        check(!request.headers['sec-fetch-site'] || ['same-origin', 'none'].includes(request.headers['sec-fetch-site']), 'Cross-site requests are refused.', 'forbidden');
        if (api) {
            const header = request.headers['x-review-token'];
            check(equalToken(header, secret), 'An instance token is required.', 'unauthorized');
        }
    }

    async function handle(request, response) {
        for (const [name, value] of Object.entries({
            'Content-Security-Policy': CSP, 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer',
            'Cross-Origin-Resource-Policy': 'same-origin', 'Cache-Control': 'no-store',
        })) response.setHeader(name, value);
        try {
            const target = new URL(request.url, url);
            authorize(request, target.pathname.startsWith('/api/'));
            if (!['GET', 'POST'].includes(request.method)) {
                response.writeHead(405, { Allow: 'GET, POST' });
                response.end('Method not allowed.');
                return;
            }
            const asset = ASSETS.get(target.pathname);
            if (asset && request.method === 'GET') {
                let content = await fs.readFile(new URL(`../ui/${asset[0]}`, import.meta.url), 'utf8');
                if (target.pathname === '/') content = renderShell(content, secret);
                response.writeHead(200, { 'Content-Type': asset[1] });
                response.end(content);
                return;
            }
            if (target.pathname === '/api/events' && request.method === 'GET') {
                response.writeHead(200, { 'Content-Type': 'text/event-stream', Connection: 'keep-alive' });
                subscribe(response);
                return;
            }
            let result;
            if (target.pathname === '/api/state' && request.method === 'GET') result = await state();
            else if (target.pathname === '/api/report' && request.method === 'GET') result = await reportFor(record.source);
            else if (target.pathname === '/api/preferences' && request.method === 'POST') {
                Object.assign(preferences, preferencesPatch(await bodyOf(request)));
                result = { ...preferences };
            } else if (target.pathname === '/api/evidence' && request.method === 'GET') {
                const snapshotId = target.searchParams.get('snapshot');
                check(snapshotId, 'Supply the selected snapshot.', 'invalid_input');
                result = await evidenceFor(record.source, target.searchParams.get('file'), snapshotId);
            } else if (target.pathname === '/api/feedback' && request.method === 'POST') {
                const body = await bodyOf(request);
                object(body, ['action', 'input'], 'feedback command');
                if (body.action === 'save') result = await editFeedback(record.source, body.input);
                else if (body.action === 'queue') result = await queueFeedback(record.source, body.input);
                else if (body.action === 'mark') result = await markTarget(record.source, body.input);
                else if (body.action === 'send') {
                    object(body.input, ['revision'], 'send request');
                    result = await sendFeedback(record.source, body.input.revision, deliver);
                } else check(false, 'Unknown feedback operation.', 'invalid_input');
                notify();
            } else check(false, 'Unknown route or method.', 'not_found');
            response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
            response.end(JSON.stringify(result));
        } catch (error) {
            const code = error.code ?? 'operation_failed';
            response.writeHead(statusFor[code] ?? 422, { 'Content-Type': 'application/json; charset=utf-8' });
            response.end(JSON.stringify({ error: code, message: error.message }));
        }
    }

    return {
        get url() { return url; },
        get listening() { return Boolean(server?.listening); },
        get subscriberCount() { return clients.size; },
        get polling() { return Boolean(timer); },
        state,
        notify,
        async reset() {
            current = null;
            warning = null;
            lastSignature = null;
            await state();
            notify();
        },
        async start() {
            if (server?.listening) return url;
            stopped = false;
            await state();
            lastSignature = await signature(record.source);
            server = http.createServer((request, response) => {
                handle(request, response).catch((error) => {
                    log(`Code Review request failed: ${error.message}`);
                    response.destroy(error);
                });
            });
            server.requestTimeout = 10000;
            server.headersTimeout = 10000;
            await new Promise((resolve, reject) => {
                server.once('error', reject);
                server.listen(0, '127.0.0.1', resolve);
            });
            url = `http://127.0.0.1:${server.address().port}/`;
            return url;
        },
        async stop() {
            stopped = true;
            clearInterval(timer);
            timer = null;
            for (const response of clients) response.end();
            clients.clear();
            if (server?.listening) {
                const closing = new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
                server.closeAllConnections();
                await closing;
            }
        },
    };
}
