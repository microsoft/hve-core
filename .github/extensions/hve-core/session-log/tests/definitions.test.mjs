// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { agentListing, boundedJson, createLiveDefinitionProvider, DEFINITION_KINDS, LIVE_DEFINITION_KINDS, mcpServerSummaries, projectDefinition, subagentCatalog } from '../lib/definitions.mjs';
import { redactProse } from '../lib/inventory.mjs';

const SECRET = 'ghp_SECRETVALUE1234567890';

const TASK_DESCRIPTION = [
    'Launch specialized agents.',
    '',
    '- **explore**: Read-only exploration.',
    '',
    '- **RPI Plan Critic**: Assesses one lens of a plan.',
    '  Use during critique.',
    '',
    '- **task**: Runs commands.',
].join('\n');

function fakeSession(overrides = {}) {
    const calls = { tools: 0, agents: 0 };
    const rpc = {
        tools: {
            getCurrentMetadata: async () => {
                calls.tools += 1;
                return {
                    tools: [
                        { name: 'bash', description: `Runs a command. Example token budget, auth ${SECRET}.`, input_schema: { type: 'object', properties: { command: { type: 'string', description: 'Command' } }, required: ['command'] } },
                        { name: 'github-get_file', namespacedName: 'github/get_file', mcpServerName: 'github', mcpToolName: 'get_file', description: 'Reads a file', input_schema: { type: 'object' }, deferLoading: true },
                        { name: 'task', description: TASK_DESCRIPTION, input_schema: { type: 'object' } },
                    ],
                };
            },
        },
        agent: {
            list: async (params) => {
                calls.agents += 1;
                assert.deepEqual(params, { includeBuiltInAgents: true, includePrompt: true });
                return {
                    agents: [{
                        name: 'rpi-plan-critic',
                        id: 'hve-core:rpi-plan-critic',
                        displayName: 'RPI Plan Critic',
                        description: 'Assesses one lens',
                        source: { type: 'plugin' },
                        tools: ['view', 'grep'],
                        model: 'small-model',
                        prompt: `# Critic\nKeep the token budget small. Never print ${SECRET}.`,
                        mcpServers: {
                            remote: { type: 'http', url: `https://user:${SECRET}@example.com/mcp?key=${SECRET}`, headers: { Authorization: `Bearer ${SECRET}` } },
                            local: { command: 'node', args: ['--token', SECRET], env: { TOKEN: SECRET } },
                        },
                    }],
                };
            },
        },
        skills: { list: async () => ({ skills: [{ name: 'demo-skill', commandName: 'demo', description: 'Demo', source: 'project', enabled: true, userInvocable: true, path: '/repo/.github/skills/demo/SKILL.md', argumentHint: '[topic]' }] }) },
        instructions: { getSources: async () => ({ sources: [{ id: '1', label: 'Markdown', sourcePath: '.github/instructions/markdown.instructions.md', content: `# Markdown\nUse ${SECRET} nowhere.`, type: 'file', location: 'repo', applyTo: ['**/*.md'] }] }) },
        ...overrides,
    };
    return { session: { rpc }, calls };
}

test('prose redaction removes credentials and keeps ordinary words', () => {
    assert.equal(redactProse(`token budget ${SECRET} and https://u:p@example.com/x`), 'token budget [redacted] and https://[redacted]@example.com/x');
    assert.equal(redactProse('password: hunter2'), 'password: hunter2');
    assert.equal(redactProse(42), 42);
    assert.equal(redactProse('abcdef', 3), 'abc');
});

test('tool projection keeps the model-facing definition and source', () => {
    const tool = projectDefinition.tool({ name: 'bash', description: `d ${SECRET}`, input_schema: { type: 'object', properties: { a: { type: 'string', description: SECRET } } }, extra: SECRET });
    assert.deepEqual(Object.keys(tool.definition), ['name', 'description', 'input_schema']);
    assert.equal(JSON.stringify(tool).includes(SECRET), false);
    assert.equal(tool.definition.input_schema.properties.a.type, 'string');
    assert.equal(tool.schemaTooLarge, false);
    const huge = projectDefinition.tool({ name: 'big', description: '', input_schema: { enum: Array.from({ length: 400 }, () => 'x'.repeat(1000)) } });
    assert.equal(huge.schemaTooLarge, true);
    assert.equal(huge.definition.input_schema, null);
});

test('bounded JSON limits depth and breadth', () => {
    let deep = { leaf: true };
    for (let i = 0; i < 40; i += 1) {
        deep = { deep };
    }
    assert.ok(JSON.stringify(boundedJson(deep)).includes('[nested too deeply]'));
    assert.equal(boundedJson(Array.from({ length: 900 }, (_, i) => i)).length, 500);
    assert.equal(boundedJson(() => 1), null);
});

test('MCP server summaries drop arguments, environment, headers, and URL credentials', () => {
    const summaries = mcpServerSummaries({ remote: { url: `https://user:${SECRET}@example.com/mcp?key=${SECRET}`, headers: { a: SECRET } }, local: { command: 'node', args: [SECRET], env: { TOKEN: SECRET } }, odd: null });
    assert.equal(JSON.stringify(summaries).includes(SECRET), false);
    assert.deepEqual(summaries[0], { name: 'remote', type: 'http', command: null, url: 'https://example.com/mcp' });
    assert.deepEqual(summaries[1], { name: 'local', type: 'stdio', command: 'node', url: null });
    assert.equal(summaries[2].type, null);
    assert.deepEqual(mcpServerSummaries(['x']), []);
});

test('agent listing returns the task tool lines for one agent', () => {
    assert.equal(agentListing(TASK_DESCRIPTION, ['hve-core:rpi-plan-critic']), '- **RPI Plan Critic**: Assesses one lens of a plan.\n  Use during critique.');
    assert.equal(agentListing(TASK_DESCRIPTION, ['explore']), '- **explore**: Read-only exploration.');
    assert.equal(agentListing(TASK_DESCRIPTION, ['missing']), null);
    assert.equal(agentListing(null, ['explore']), null);
});

test('live lookups project each kind without leaking credentials', async () => {
    const { session } = fakeSession();
    const provider = createLiveDefinitionProvider(session);

    const bash = await provider.lookup('tool', 'bash');
    assert.equal(bash.status, 'live');
    assert.equal(bash.item.definition.input_schema.required[0], 'command');
    assert.ok(bash.item.definition.description.includes('token budget'));
    const mcp = await provider.lookup('tool', 'github/get_file');
    assert.equal(mcp.item.mcpServerName, 'github');
    assert.equal(mcp.item.deferLoading, true);
    assert.equal((await provider.lookup('tool', 'nope')).status, 'not-offered');

    const agent = await provider.lookup('agent', 'RPI Plan Critic');
    assert.equal(agent.status, 'live');
    assert.equal(agent.item.id, 'hve-core:rpi-plan-critic');
    assert.equal(agent.item.source, 'plugin');
    assert.ok(agent.item.prompt.includes('token budget'));
    assert.match(agent.listing, /^- \*\*RPI Plan Critic\*\*/);
    assert.deepEqual(agent.item.mcpServers.map((server) => server.name), ['remote', 'local']);
    assert.equal((await provider.lookup('agent', 'rpi_plan_critic')).item.name, 'rpi-plan-critic');
    assert.equal((await provider.lookup('agent', 'missing')).item, null);

    const skill = await provider.lookup('skill', 'demo');
    assert.equal(skill.item.name, 'demo-skill');
    assert.equal(skill.item.argumentHint, '[topic]');

    const instruction = await provider.lookup('instruction', '/repo/.github/instructions/markdown.instructions.md');
    assert.equal(instruction.item.label, 'Markdown');
    assert.equal(instruction.item.contentTruncated, false);

    const all = JSON.stringify([bash, mcp, agent, skill, instruction]);
    assert.equal(all.includes(SECRET), false);
    assert.equal((await provider.lookup('other', 'x')).status, 'unavailable');
});

test('live lookups cache each list, share in-flight calls, and expire', async () => {
    let now = 0;
    const { session, calls } = fakeSession();
    const provider = createLiveDefinitionProvider(session, { ttlMs: 1000, now: () => now });
    await Promise.all([provider.lookup('tool', 'bash'), provider.lookup('tool', 'task'), provider.lookup('agent', 'RPI Plan Critic')]);
    assert.equal(calls.tools, 1);
    assert.equal(calls.agents, 1);
    now = 2000;
    await provider.lookup('tool', 'bash');
    assert.equal(calls.tools, 2);
});

test('live lookups report unavailable, failing, and uninitialized sources', async () => {
    const { session } = fakeSession({
        tools: { getCurrentMetadata: async () => ({ tools: null }) },
        agent: { list: async () => { throw new Error('boom'); } },
        skills: undefined,
    });
    const provider = createLiveDefinitionProvider(session, { timeoutMs: 50 });
    assert.deepEqual(await provider.lookup('tool', 'bash'), { status: 'not-initialized', item: null });
    assert.deepEqual(await provider.lookup('agent', 'x'), { status: 'unavailable', item: null });
    assert.deepEqual(await provider.lookup('skill', 'x'), { status: 'unavailable', item: null });
    assert.deepEqual(await createLiveDefinitionProvider(null).lookup('instruction', 'x'), { status: 'unavailable', item: null });
});

const CANVASES = [{
    canvasId: 'demo-board',
    displayName: 'Demo Board',
    description: 'Cards and lanes.',
    extensionId: 'project:demo-board',
    extensionName: 'demo-board',
    inputSchema: { type: 'object', properties: { boardId: { type: 'string' } } },
    actions: [{ name: 'add_card', description: `Adds a card. Never print ${SECRET}.`, inputSchema: { type: 'object' } }, { name: 'clear' }],
}];

function inventorySession() {
    return fakeSession({
        canvas: { list: async () => ({ canvases: CANVASES }) },
        mcp: {
            list: async () => ({
                servers: [{
                    name: 'remote',
                    displayName: 'Remote MCP',
                    status: 'failed',
                    source: 'workspace',
                    sourcePlugin: 'demo-plugin',
                    url: `https://user:${SECRET}@example.com/mcp?key=${SECRET}`,
                    error: `401 for token=${SECRET}`,
                    serverMetadata: { instructions: `Use the remote tools. Key ${SECRET}.` },
                }],
            }),
        },
        plugins: { list: async () => ({ plugins: [{ name: 'demo-plugin', marketplace: 'demo', version: '1.2.3', enabled: true, installedFrom: `https://user:${SECRET}@example.com/repo.git?ref=${SECRET}`, managed: false }] }) },
        extensions: { list: async () => ({ extensions: [{ id: 'project:demo-board', name: 'demo-board', source: 'project', status: 'running', pid: 4242 }] }) },
    });
}

test('definition kinds include hooks without a live source', () => {
    assert.deepEqual([...DEFINITION_KINDS].sort(), ['agent', 'canvas', 'extension', 'hook', 'instruction', 'mcp', 'plugin', 'skill', 'tool']);
    assert.equal(LIVE_DEFINITION_KINDS.includes('hook'), false);
});

test('live lookups describe canvases, MCP servers, plugins, and extensions without secrets', async () => {
    const provider = createLiveDefinitionProvider(inventorySession().session);
    const canvas = await provider.lookup('canvas', 'demo-board');
    assert.equal(canvas.status, 'live');
    assert.deepEqual(canvas.item.inputSchema, CANVASES[0].inputSchema);
    assert.deepEqual(canvas.item.actions.map((action) => [action.name, action.inputSchema !== null]), [['add_card', true], ['clear', false]]);
    assert.ok(!JSON.stringify(canvas).includes(SECRET));
    assert.deepEqual(await provider.lookup('canvas', 'missing'), { status: 'not-found', item: null });

    const server = await provider.lookup('mcp', 'Remote MCP');
    assert.equal(server.item.url, 'https://example.com/mcp');
    assert.equal(server.item.status, 'failed');
    assert.ok(server.item.instructions.startsWith('Use the remote tools.'));
    assert.ok(!JSON.stringify(server).includes(SECRET));

    const plugin = await provider.lookup('plugin', 'demo-plugin');
    assert.equal(plugin.item.installedFrom, 'https://example.com/repo.git');
    assert.equal(plugin.item.version, '1.2.3');

    const extension = await provider.lookup('extension', 'project:demo-board');
    assert.deepEqual(extension.item, { id: 'project:demo-board', name: 'demo-board', source: 'project', status: 'running' });
    assert.deepEqual(await provider.lookup('hook', 'postToolUse'), { status: 'unavailable', item: null });
});

test('catalogs list offered tools, declared canvases, and launchable agent types', async () => {
    const provider = createLiveDefinitionProvider(inventorySession().session);
    const tools = await provider.catalog('tool');
    assert.equal(tools.status, 'live');
    assert.deepEqual(tools.items.find((item) => item.name === 'github-get_file'), { name: 'github-get_file', description: 'Reads a file', mcpServerName: 'github', deferLoading: true });
    assert.ok(!JSON.stringify(tools).includes(SECRET));
    const canvases = await provider.catalog('canvas');
    assert.deepEqual(canvases.items, [{ canvasId: 'demo-board', displayName: 'Demo Board', description: 'Cards and lanes.', extensionId: 'project:demo-board', extensionName: 'demo-board', actions: ['add_card', 'clear'] }]);
    const subagents = await provider.catalog('subagent');
    assert.deepEqual(subagents.items.map((item) => item.name), ['explore', 'RPI Plan Critic', 'task']);
    const unavailable = createLiveDefinitionProvider(fakeSession({ tools: { getCurrentMetadata: async () => ({ tools: null }) } }).session);
    assert.deepEqual(await unavailable.catalog('subagent'), { status: 'not-initialized', items: [] });
});

test('subagent catalog splits built-in and custom agent types and dedupes enum values', () => {
    const description = ['Launch agents.', '', 'Available agent types:', '- **explore**: Read-only exploration.', '', 'User-provided custom agents:', '- **RPI Plan Critic**: Assesses one lens.'].join('\n');
    const items = subagentCatalog({ description, input_schema: { properties: { agent_type: { enum: ['explore', 'RPI Plan Critic', 'RPI Plan Critic', 'hve-core:rpi-plan-critic', 'unlisted'] } } } });
    assert.deepEqual(items, [
        { name: 'explore', description: 'Read-only exploration.', builtIn: true },
        { name: 'RPI Plan Critic', description: 'Assesses one lens.', builtIn: false },
        { name: 'hve-core:rpi-plan-critic', description: 'Assesses one lens.', builtIn: false },
        { name: 'unlisted', description: '', builtIn: null },
    ]);
    assert.deepEqual(subagentCatalog(null), []);
});

test('URL projections redact tokens in the path as well as credentials and queries', () => {
    const [summary] = mcpServerSummaries({ zap: { type: 'http', url: `https://user:pw@mcp.example.com/api/${SECRET}/sse?key=hidden` } });
    assert.equal(summary.url, 'https://mcp.example.com/api/[redacted]/sse');
    const [encoded] = mcpServerSummaries({ zap: { url: `https://mcp.example.com/api/${encodeURIComponent(SECRET)}%2Fsse` } });
    assert.ok(!encoded.url.includes(SECRET));
    const plugin = projectDefinition.plugin({ name: 'p', installedFrom: `https://github.com/org/repo/${SECRET}` });
    assert.equal(plugin.installedFrom, 'https://github.com/org/repo/[redacted]');
});
