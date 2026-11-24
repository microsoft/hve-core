// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createRegistry } from '../lib/lifecycle.mjs';

describe('canvas panel lifecycle', () => {
    it('shares simultaneous opens and keeps different panel IDs independent', async () => {
        const registry = createRegistry();
        let created = 0;
        let stopped = 0;
        const factory = async () => {
            created++;
            return { server: { start: async () => {}, stop: async () => { stopped++; } } };
        };
        const [first, second] = await Promise.all([registry.open('one', factory), registry.open('one', factory)]);
        assert.equal(first, second);
        assert.equal(created, 1);
        await registry.open('two', factory);
        await registry.close('one');
        assert.equal(registry.size, 1);
        await registry.closeAll();
        assert.equal(stopped, 2);
    });

    it('cleans up a close during preparation and permits a later retry', async () => {
        const registry = createRegistry();
        let finish;
        let started = 0;
        let stopped = 0;
        const opening = registry.open('one', () => new Promise((resolve) => { finish = resolve; }));
        await registry.close('one');
        finish({ server: { start: async () => { started++; }, stop: async () => { stopped++; } } });
        await assert.rejects(opening, /closed while opening/);
        assert.equal(started, 0);
        assert.equal(stopped, 1);
        assert.equal(registry.size, 0);
        await registry.open('one', async () => ({ server: { start: async () => { started++; }, stop: async () => {} } }));
        assert.equal(started, 1);
        await registry.closeAll();
    });

    it('stops a server that finishes starting after close', async () => {
        const registry = createRegistry();
        let finish;
        let stopped = 0;
        const opening = registry.open('one', async () => ({
            server: { start: () => new Promise((resolve) => { finish = resolve; }), stop: async () => { stopped++; } },
        }));
        await new Promise((resolve) => setImmediate(resolve));
        await registry.close('one');
        finish();
        await assert.rejects(opening, /closed while opening/);
        assert.equal(stopped, 1);
        assert.equal(registry.size, 0);
    });
});
