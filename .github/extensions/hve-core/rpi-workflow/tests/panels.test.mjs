// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { CANVAS_ID, createPanelOpener, panelInstanceId, providerOf } from '../lib/panels.mjs';

const SESSION = '7b2e8f10-3c4d-4e5f-8a6b-1c2d3e4f5a6b';
const STATE = '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/map-api-state.json';
const PROVIDER = 'project:rpi-workflow';

/** The host's canvas API as a fake that records each open. `listed` is what it reports open. */
function fakeRpc({ listed = { openCanvases: [] }, listError = null, openError = null } = {}) {
    const opens = [];
    return {
        opens,
        canvas: {
            listOpen: async () => {
                if (listError) throw listError;
                return listed;
            },
            open: async (params) => {
                opens.push(params);
                if (openError) throw openError;
                return { instanceId: params.instanceId, extensionId: params.extensionId, canvasId: params.canvasId };
            },
        },
    };
}

describe('child panel instance IDs', () => {
    it('is rpi, the first eight characters of the session ID, and the task ID, in lowercase letters, digits, and hyphens', () => {
        assert.equal(panelInstanceId(SESSION.toUpperCase(), 'map-api'), 'rpi-7b2e8f10-map-api');
        assert.equal(panelInstanceId(SESSION, 'Map.API_v2'), 'rpi-7b2e8f10-map-api-v2');
    });

    it('is at most 80 characters, so a long task ID is cut', () => {
        const id = panelInstanceId(SESSION, 'a'.repeat(120));
        assert.equal(id.length, 80);
        assert.match(id, /^[a-z0-9-]+$/);
    });
});

describe('opening a child panel through the host', () => {
    it('captures the provider from the open request, and passes it on when the host opens a panel', async () => {
        assert.equal(providerOf({ sessionId: SESSION, extensionId: PROVIDER, canvasId: CANVAS_ID }), PROVIDER);
        assert.equal(providerOf({ extensionId: '' }), null, 'an empty provider is not a provider');
        assert.equal(providerOf({}), null);
        assert.equal(providerOf(undefined), null);
        const rpc = fakeRpc();
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => providerOf({ extensionId: PROVIDER }), canvasId: CANVAS_ID });
        await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' });
        assert.equal(rpc.opens[0].extensionId, PROVIDER);
    });

    it('opens the instance through the provider that opened the canvas, with the canvas ID and the child\'s input', async () => {
        const rpc = fakeRpc();
        const record = { extensionId: PROVIDER };
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => record.extensionId, canvasId: CANVAS_ID });
        assert.deepEqual(await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' }), { outcome: 'opened', instanceId: 'rpi-7b2e8f10-map-api' });
        assert.deepEqual(rpc.opens, [{ extensionId: PROVIDER, canvasId: 'hve-core-rpi-workflow', instanceId: 'rpi-7b2e8f10-map-api', input: { session: SESSION, state: STATE } }]);
    });

    it('reads the provider at each open, so a reopen through another provider uses that one', async () => {
        const rpc = fakeRpc();
        const record = { extensionId: PROVIDER };
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => record.extensionId, canvasId: CANVAS_ID });
        await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' });
        record.extensionId = 'plugin:rpi-workflow';
        await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' });
        assert.deepEqual(rpc.opens.map((params) => params.extensionId), [PROVIDER, 'plugin:rpi-workflow']);
    });

    it('reports focused when the host already lists that instance open, and still opens it', async () => {
        const rpc = fakeRpc({ listed: { openCanvases: [{ instanceId: 'rpi-7b2e8f10-map-api', extensionId: PROVIDER, canvasId: CANVAS_ID }] } });
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.deepEqual(await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' }), { outcome: 'focused', instanceId: 'rpi-7b2e8f10-map-api' });
        assert.equal(rpc.opens.length, 1);
    });

    it('does not mistake another instance for the one it opens', async () => {
        const rpc = fakeRpc({ listed: { openCanvases: [{ instanceId: 'rpi-7b2e8f10-map-tiles', extensionId: PROVIDER, canvasId: CANVAS_ID }] } });
        const openPanel = createPanelOpener({ rpc: () => rpc, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await openPanel({ session: SESSION, statePath: STATE, taskId: 'map-api' })).outcome, 'opened');
    });

    it('treats a host that cannot list its canvases, or lists them without openCanvases, as none open', async () => {
        const failing = createPanelOpener({ rpc: () => fakeRpc({ listError: new Error('Listing is not available.') }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await failing({ session: SESSION, statePath: STATE, taskId: 'map-api' })).outcome, 'opened');
        const bare = createPanelOpener({ rpc: () => fakeRpc({ listed: [{ instanceId: 'rpi-7b2e8f10-map-api' }] }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        assert.equal((await bare({ session: SESSION, statePath: STATE, taskId: 'map-api' })).outcome, 'opened');
    });

    it('throws when the host has no canvas API, when no provider is known, or when the host refuses the open', async () => {
        const request = { session: SESSION, statePath: STATE, taskId: 'map-api' };
        const noApi = createPanelOpener({ rpc: () => ({}), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(noApi(request), /cannot open canvas panels/);
        const noRpc = createPanelOpener({ rpc: () => undefined, extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(noRpc(request), /cannot open canvas panels/);
        const unknown = createPanelOpener({ rpc: () => fakeRpc(), extensionId: () => null, canvasId: CANVAS_ID });
        await assert.rejects(unknown(request), /does not know its provider/);
        const refused = createPanelOpener({ rpc: () => fakeRpc({ openError: new Error('Canvases cannot open from this session.') }), extensionId: () => PROVIDER, canvasId: CANVAS_ID });
        await assert.rejects(refused(request), /cannot open from this session/);
    });
});
