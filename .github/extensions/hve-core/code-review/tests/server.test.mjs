// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { captureReview } from '../../../../skills/coding-standards/code-review-core/scripts/lib/snapshot.mjs';
import { schedule } from '../../../../skills/coding-standards/code-review-core/scripts/lib/operations.mjs';
import { openReview } from '../lib/model.mjs';
import { createCanvasServer } from '../lib/server.mjs';
import { createRegistry } from '../lib/lifecycle.mjs';
import { invokeAction } from '../lib/actions.mjs';

async function fixture(t) {
    const repository = await fs.mkdtemp(path.join(os.tmpdir(), 'hve-review-server-'));
    const capture = await captureReview(repository, { kind: 'selected', selection: [{ path: 'example.js', startLine: 1, endLine: 1, text: '<em>literal text</em>' }] });
    const source = await openReview(repository, { state: `${capture.relative}/review-state.json` });
    const record = { source, focus: null, server: null };
    record.server = createCanvasServer(record, { pollMs: 20, log: () => {} });
    await record.server.start();
    t.after(async () => {
        await record.server.stop();
        await fs.rm(repository, { recursive: true, force: true });
    });
    const response = await fetch(record.server.url);
    const html = await response.text();
    const token = /name="review-token" content="([^"]+)"/.exec(html)[1];
    return { record, capture, response, html, headers: { 'X-Review-Token': token } };
}

describe('contained canvas transport', () => {
    it('requires an instance token, rejects foreign origins/methods, and serves only declared assets', async (t) => {
        const { record, response, headers } = await fixture(t);
        const url = record.server.url;
        assert.match(response.headers.get('content-security-policy'), /style-src 'self'/);
        assert.equal(new URL(url).search, '');
        assert.equal((await fetch(`${url}api/state`)).status, 401);
        assert.equal((await fetch(`${url}api/state`, { headers: { ...headers, Origin: 'https://example.invalid' } })).status, 403);
        assert.equal((await fetch(`${url}api/state`, { headers, method: 'DELETE' })).status, 405);
        assert.equal((await fetch(`${url}outside.json`, { headers })).status, 404);
        assert.equal((await fetch(`${url}api/evidence?file=missing&snapshot=${record.source.state.snapshotId}`, { headers })).status, 404);
        assert.equal(record.server.polling, false);
    });

    it('validates appearance changes and renders them into the next page shell', async (t) => {
        const { record, headers, html } = await fixture(t);
        const post = (body) => fetch(`${record.server.url}api/preferences`, { method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        assert.match(html, /data-theme="(system|light|dark)" data-contrast="(standard|more)"/);
        assert.equal((await post({ theme: 'sepia' })).status, 400);
        assert.equal((await post({ theme: 'dark', font: 'large' })).status, 400);
        assert.deepEqual(await (await post({ theme: 'dark', contrast: 'more' })).json(), { theme: 'dark', contrast: 'more' });
        const next = await (await fetch(record.server.url)).text();
        assert.match(next, /data-theme="dark" data-contrast="more"/);
        assert.equal((await post({ theme: 'system', contrast: 'standard' })).status, 200);
    });

    it('retains benign markup as source text and does not expose a publication action', async (t) => {
        const { record, headers, html } = await fixture(t);
        assert.equal(html.includes('<em>literal text</em>'), false);
        const response = await fetch(`${record.server.url}api/evidence?file=file-1&snapshot=${record.source.state.snapshotId}`, { headers });
        assert.equal((await response.json()).lines[0].text, '<em>literal text</em>');
        const forbidden = await fetch(`${record.server.url}api/feedback`, {
            method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'publish', input: {} }),
        });
        assert.equal(forbidden.status, 400);
        const malformed = await fetch(`${record.server.url}api/feedback`, {
            method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: '{',
        });
        assert.equal(malformed.status, 400);
    });

    it('polls only with a subscriber and reports a corrupt source as stale without an outcome', async (t) => {
        const { record, headers, capture } = await fixture(t);
        const controller = new AbortController();
        t.after(() => controller.abort());
        const events = await fetch(`${record.server.url}api/events`, { headers, signal: controller.signal });
        const reader = events.body.getReader();
        await reader.read();
        assert.equal(record.server.polling, true);
        await schedule(capture, 0, { perspectives: ['functional'], scope: { profile: 'basic', depth: 'basic', mode: 'sweep', rationale: 'Fixture review' } });
        await reader.read();
        const updated = await (await fetch(`${record.server.url}api/state`, { headers })).json();
        assert.equal(updated.revision, 1);
        await fs.writeFile(path.join(capture.root, 'review-state.json'), JSON.stringify({ ...record.source.state, schemaVersion: 99 }));
        const stale = await (await fetch(`${record.server.url}api/state`, { headers })).json();
        assert.equal(stale.stale, true);
        assert.equal(stale.outcome, null);
        assert.equal(stale.warning.code, 'unsupported_schema');
        await reader.cancel();
        controller.abort();
        await record.server.stop();
        assert.equal(record.server.polling, false);
        assert.equal(record.server.listening, false);
    });

    it('validates actions, preserves the current source on a bad reconnect, and keeps drafts private', async (t) => {
        const { record } = await fixture(t);
        const registry = createRegistry();
        await registry.open('test-panel', async () => record);
        t.after(() => registry.closeAll());
        const call = (actionName, input) => invokeAction(registry, { instanceId: 'test-panel', actionName, input });
        const before = await call('get_state', {});
        await call('focus_item', { kind: 'file', id: 'file-1' });
        const after = await call('get_state', {});
        assert.deepEqual(after.areas, before.areas);
        assert.equal(after.focus.id, 'file-1');
        await assert.rejects(call('show_review', { state: '../outside/review-state.json' }), /uniquely identified/);
        assert.equal((await call('get_state', {})).reviewId, before.reviewId);
        await assert.rejects(call('get_state', { hidden: true }), /unsupported field/);
        assert.equal(Object.hasOwn(after.feedback, 'items'), false);
    });
});
