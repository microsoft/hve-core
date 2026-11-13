// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { CANVAS_ID, createPanelOpener, panelInstanceId, providerOf } from '../lib/panels.mjs';
import { hostCanvas } from './helpers/host-canvas.mjs';

const SESSION = '7b2e8f10-3c4d-4e5f-8a6b-1c2d3e4f5a6b';
const PROVIDER = 'project:rpi-workflow';

describe('session panel instance IDs', () => {
    it('is rpi and the first eight characters of the session ID, in lowercase', () => {
        assert.equal(panelInstanceId(SESSION.toUpperCase()), 'rpi-7b2e8f10');
        assert.equal(panelInstanceId(SESSION), 'rpi-7b2e8f10');
    });
});

describe('opening a session panel through the host', () => {
    it('captures the provider from the open request, and passes it on when the host opens a panel', async () => {
        assert.equal(providerOf({ sessionId: SESSION, extensionId: PROVIDER, canvasId: CANVAS_ID }), PROVIDER);
        assert.equal(providerOf({ extensionId: '' }), null, 'an empty provider is not a provider');
        assert.equal(providerOf({}), null);
        assert.equal(providerOf(undefined), null);
        const rpc = hostCanvas();
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => providerOf({ extensionId: PROVIDER }), canvasId: CANVAS_ID });
        await openPanel({ session: SESSION });
        assert.equal(rpc.opens[0].extensionId, PROVIDER);
    });

    it('opens the instance through the provider that opened the canvas, with the canvas ID and the session\'s input', async () => {
        const rpc = hostCanvas();
        const record = { extensionId: PROVIDER };
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => record.extensionId, canvasId: CANVAS_ID });
        assert.deepEqual(await openPanel({ session: SESSION }), { outcome: 'opened', instanceId: 'rpi-7b2e8f10' });
        assert.deepEqual(rpc.opens, [{ extensionId: PROVIDER, canvasId: 'hve-core-rpi-workflow', instanceId: 'rpi-7b2e8f10', input: { session: SESSION } }]);
    });

    it('reads the provider at each open, so a reopen through another provider uses that one', async () => {
        const rpc = hostCanvas();
        const record = { extensionId: PROVIDER };
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => record.extensionId, canvasId: CANVAS_ID });
        await openPanel({ session: SESSION });
        record.extensionId = 'plugin:rpi-workflow';
        await openPanel({ session: SESSION });
        assert.deepEqual(rpc.opens.map((params) => params.extensionId), [PROVIDER, 'plugin:rpi-workflow']);
    });

    it('reports focused when the host already lists that instance open, and still opens it', async () => {
        const rpc = hostCanvas({ listed: [{ instanceId: 'rpi-7b2e8f10', extensionId: PROVIDER, canvasId: CANVAS_ID }] });
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.deepEqual(await openPanel({ session: SESSION }), { outcome: 'focused', instanceId: 'rpi-7b2e8f10' });
        assert.equal(rpc.opens.length, 1);
    });

    it('does not mistake another session\'s instance for the one it opens', async () => {
        const rpc = hostCanvas({ listed: [{ instanceId: 'rpi-1a2b3c4d', extensionId: PROVIDER, canvasId: CANVAS_ID }] });
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await openPanel({ session: SESSION })).outcome, 'opened');
    });

    it('treats a host that cannot list its canvases, or lists them without openCanvases, as none open', async () => {
        const failing = createPanelOpener({ rpc: () => hostCanvas({ listError: new Error('Listing is not available.') }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await failing({ session: SESSION })).outcome, 'opened');
        const bare = createPanelOpener({ rpc: () => hostCanvas({ listing: [{ instanceId: 'rpi-7b2e8f10' }] }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await bare({ session: SESSION })).outcome, 'opened');
    });

    it('throws when the host has no canvas API, when no provider is known, or when the host refuses the open', async () => {
        const request = { session: SESSION };
        const noApi = createPanelOpener({ rpc: () => ({}), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(noApi(request), /cannot open canvas panels/);
        const noRpc = createPanelOpener({ rpc: () => undefined, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(noRpc(request), /cannot open canvas panels/);
        const unknown = createPanelOpener({ rpc: () => hostCanvas(), extensionId: () => null, canvasId: CANVAS_ID });
        await assert.rejects(unknown(request), /does not know its provider/);
        const refused = createPanelOpener({ rpc: () => hostCanvas({ openError: new Error('Canvases cannot open from this session.') }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(refused(request), /cannot open from this session/);
    });
});
