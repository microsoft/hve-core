// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { canvasHandle } from '../lib/handle.mjs';
import { createInstanceRegistry } from '../lib/lifecycle.mjs';

const HANDLE_RE = /^[0-9A-HJKMNP-TV-Z]{4}$/;

describe('canvas handle', () => {
    it('is four readable characters and stable for an instance ID', () => {
        const first = canvasHandle('rpi-workflow-demo');
        assert.match(first, HANDLE_RE);
        assert.equal(canvasHandle('rpi-workflow-demo'), first);
        assert.notEqual(canvasHandle('rpi-workflow-other'), first);
    });

    it('grows when another instance holds the handle, then numbers it', () => {
        const id = '6f1c2a8e-91d4-4b67-a0f5-2c1e9b7d3a40';
        const held = [canvasHandle(id)];
        for (let length = 5; length <= 8; length += 1) {
            const next = canvasHandle(id, held);
            assert.equal(next.length, length);
            assert.ok(next.startsWith(held[0]));
            held.push(next);
        }
        assert.equal(canvasHandle(id, held), `${held[4]}-2`);
        assert.equal(canvasHandle(id, [...held, `${held[4]}-2`]), `${held[4]}-3`);
    });
});

describe('registry handles', () => {
    const makeError = (code, message) => Object.assign(new Error(message), { code });
    const server = () => {
        let listening = false;
        return {
            get listening() {
                return listening;
            },
            async start() {
                listening = true;
                return 'http://127.0.0.1:1/';
            },
            async stop() {
                listening = false;
            },
        };
    };

    it('gives each open instance its own handle and keeps it on reopen', async () => {
        const seen = [];
        const registry = createInstanceRegistry({ makeError, createServer: (record) => {
            seen.push(record.handle);
            return server();
        } });
        const a = await registry.open({ instanceId: 'a', sessionId: 's' });
        const b = await registry.open({ instanceId: 'b', sessionId: 's' });
        assert.match(a.handle, HANDLE_RE);
        assert.match(b.handle, HANDLE_RE);
        assert.notEqual(a.handle, b.handle);
        assert.equal(a.handle, canvasHandle('a'));
        await registry.close('a');
        const again = await registry.open({ instanceId: 'a', sessionId: 's' });
        assert.equal(again.handle, a.handle);
        assert.deepEqual(seen, [a.handle, b.handle, a.handle]);
    });
});
