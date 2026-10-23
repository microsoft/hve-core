// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { createLiveInventoryProvider, mergeInventory, redactCredentials, timed } from '../lib/inventory.mjs';

const SECRET = 'ghp_SECRETVALUE1234567890';

function fakeSession(overrides = {}) {
    let calls = 0;
    const rpc = {
        agent: {
            list: async (params) => {
                calls += 1;
                assert.deepEqual(params, { includeBuiltInAgents: true, includePrompt: false });
                return { agents: [{ name: 'a', displayName: 'Agent A', description: 'd', source: 'plugin', tools: ['x', 'y'], prompt: SECRET, userInvocable: true }] };
            },
            getCurrent: async () => ({ agent: { name: 'a', displayName: 'Agent A', prompt: SECRET } }),
        },
        skills: {
            list: async () => ({ skills: [{ name: 's', description: 'skill', source: { type: 'plugin' }, enabled: true, userInvocable: true, path: '/x', content: SECRET }] }),
            getInvoked: async () => ({ skills: [{ name: 's', path: '/x', content: SECRET }] }),
        },
        instructions: { getSources: async () => ({ sources: [{ id: '1', label: 'rules', sourcePath: '/r.md', content: SECRET, type: 'file', location: 'repo', applyTo: ['**/*.md'] }] }) },
        mcp: { list: async () => ({ servers: [{ name: 'm', status: 'connected', error: `connect https://user:${SECRET}@host failed; token=${SECRET}`, url: `https://user:${SECRET}@host`, env: { TOKEN: SECRET }, args: ['--token', SECRET] }] }) },
        plugins: { list: async () => ({ plugins: [{ name: 'p', marketplace: 'mk', version: '1', enabled: true, installedFrom: SECRET }] }) },
        extensions: { list: async () => ({ extensions: [{ id: 'e', name: 'ext', source: 'project', status: 'running', pid: 4 }] }) },
        model: { getCurrent: async () => ({ modelId: 'model-x', reasoningEffort: 'high', contextTier: 'long', providerId: SECRET }) },
        ...overrides,
    };
    return { session: { rpc }, calls: () => calls };
}

test('live inventory projects allowlisted fields only', async () => {
    const { session } = fakeSession();
    const inventory = await createLiveInventoryProvider(session)();
    assert.equal(JSON.stringify(inventory).includes(SECRET), false);
    assert.equal(inventory.agents.status, 'live');
    assert.deepEqual(inventory.agents.items[0], { id: null, name: 'a', displayName: 'Agent A', description: 'd', source: 'plugin', model: null, toolCount: 2, userInvocable: true, disableModelInvocation: null });
    assert.equal(inventory.skills.items[0].source, 'plugin');
    assert.equal(inventory.mcpServers.items[0].status, 'connected');
    assert.deepEqual(inventory.model.item, { modelId: 'model-x', reasoningEffort: 'high', contextTier: 'long' });
    assert.equal(inventory.extensions.items[0].name, 'ext');
});

test('live inventory marks missing or failing calls unavailable and caches results', async () => {
    let now = 0;
    const { session, calls } = fakeSession({ mcp: undefined, plugins: { list: async () => { throw new Error('boom'); } } });
    const provider = createLiveInventoryProvider(session, { ttlMs: 1000, now: () => now });
    const first = await provider();
    assert.equal(first.mcpServers.status, 'unavailable');
    assert.equal(first.plugins.status, 'unavailable');
    assert.equal(first.agents.status, 'live');
    await provider();
    assert.equal(calls(), 1);
    now = 2000;
    await provider();
    assert.equal(calls(), 2);
});

test('timed resolves a timeout as a failed call', async () => {
    const result = await timed(() => new Promise(() => {}), 20);
    assert.deepEqual(result, { ok: false, error: 'timeout' });
    assert.deepEqual(await timed(async () => 5, 50), { ok: true, value: 5 });
});

test('merge falls back to recorded data and labels each list', () => {
    const recorded = {
        customAgent: { displayName: 'Recorded Agent' },
        skills: [{ name: 'r', description: 'recorded' }],
        skillsInvoked: [{ name: 'r' }],
        instructions: [{ path: 'docs/a.md', applyTo: '**/*.md', description: 'A' }],
        tools: { names: ['bash'], declaredCount: 3, listTruncated: 0 },
        subagentTypes: [{ type: 'explore', count: 1 }],
    };
    const offline = mergeInventory(recorded, null);
    assert.equal(offline.isLive, false);
    assert.equal(offline.skills.status, 'reconstructed');
    assert.equal(offline.instructions.items[0].sourcePath, 'docs/a.md');
    assert.equal(offline.agents.status, 'not-recorded');
    assert.equal(offline.currentAgent.status, 'reconstructed');

    const live = { agents: { status: 'live', items: [] }, skills: { status: 'unavailable', items: [] }, instructions: { status: 'live', items: [{ label: 'x' }] }, mcpServers: { status: 'unavailable', items: [] }, plugins: { status: 'live', items: [] }, extensions: { status: 'live', items: [] }, invokedSkills: { status: 'unavailable', items: [] }, currentAgent: { status: 'unavailable', item: null }, model: { status: 'live', item: { modelId: 'm' } } };
    const merged = mergeInventory(recorded, live);
    assert.equal(merged.skills.status, 'reconstructed');
    assert.equal(merged.instructions.status, 'live');
    assert.equal(merged.mcpServers.status, 'unavailable');
    assert.equal(merged.invokedSkills.status, 'reconstructed');
    assert.equal(merged.model.item.modelId, 'm');
});

test('redaction removes URL credentials, token formats, and secret pairs', () => {
    assert.equal(redactCredentials('fetch https://alice:pa55@example.com/x failed'), 'fetch https://[redacted]@example.com/x failed');
    assert.equal(redactCredentials(`auth ${SECRET} rejected`), 'auth [redacted] rejected');
    assert.equal(redactCredentials('api_key=abc123 password: hunter2'), 'api_key=[redacted] password: [redacted]');
    assert.equal(redactCredentials('server exited with code 1'), 'server exited with code 1');
    assert.equal(redactCredentials(null), null);
});
