// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { buildContextSections, CONTEXT_SECTIONS, contextCounts, HOOK_DESCRIPTIONS } from '../lib/context.mjs';
import { ROOT_AGENT, SessionIndex } from '../lib/indexer.mjs';
import { buildInventoryEvents, SUBAGENT_ID, toJsonl } from './fixtures.mjs';

async function recordedFor(t, agentKey = ROOT_AGENT) {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-context-'));
    t.after(() => fs.rm(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'events.jsonl');
    await fs.writeFile(file, toJsonl(buildInventoryEvents()));
    const index = new SessionIndex(file);
    await index.refresh();
    return { index, recorded: index.getRecordedInventory(agentKey) };
}

const byId = (sections) => Object.fromEntries(sections.map((section) => [section.id, section]));
const row = (section, key) => section.items.find((item) => item.key === key);

test('recorded sections describe what a past session gave the model, with honest sources', async (t) => {
    const { index, recorded } = await recordedFor(t);
    const sections = buildContextSections({ recorded, live: null, catalogs: {}, mainAgent: true, readCounts: (paths) => index.getReadCounts(ROOT_AGENT, paths) });
    assert.deepEqual(sections.map((section) => section.id), CONTEXT_SECTIONS.map((section) => section.id));
    const s = byId(sections);

    assert.equal(s.tools.status, 'reconstructed');
    const navigate = row(s.tools, 'browser-navigate');
    assert.deepEqual(navigate.badges.map((badge) => badge.text), ['MCP · browser', 'Loaded by search']);
    assert.equal(navigate.countText, '1 call');
    assert.deepEqual([row(s.tools, 'invoke_canvas_action').count, row(s.tools, 'invoke_canvas_action').failed], [2, 1]);

    assert.equal(s.canvases.status, 'reconstructed');
    assert.deepEqual(s.canvases.items.map((item) => [item.key, item.name, item.countText]), [['demo-board', 'Demo Board', '4 calls'], ['notes', 'Notes', 'Not used']]);
    assert.equal(row(s.canvases, 'demo-board').description, 'Cards & lanes for planning.');

    assert.equal(s.hooks.status, 'reconstructed');
    const post = row(s.hooks, 'postToolUse');
    assert.equal(post.description, HOOK_DESCRIPTIONS.postToolUse);
    assert.deepEqual(post.badges, [{ text: 'lint-plugin: 1 failed', tone: 'danger' }]);
    assert.deepEqual(row(s.hooks, 'userPromptSubmitted').badges.map((badge) => badge.text), ['Adds context']);

    assert.equal(s.agents.status, 'partial');
    assert.deepEqual(s.agents.items.map((item) => [item.name, item.countText, item.badges.map((badge) => badge.text)]), [['Planner', 'Selected 1×', ['Current']]]);
    assert.equal(s.subagents.status, 'partial');
    assert.deepEqual(s.subagents.items.map((item) => [item.name, item.countText]), [['reviewer', '1 run']]);

    assert.equal(s.instructions.status, 'reconstructed');
    assert.deepEqual(s.instructions.items.map((item) => [item.key, item.countText, item.badges.map((badge) => badge.text)]), [
        ['.github/instructions/markdown.instructions.md', 'Read 1×', []],
        ['packages/api/AGENTS.md', 'Not read', ['Discovered']],
    ]);

    assert.equal(s.mcp.status, 'partial');
    assert.deepEqual(s.mcp.items.map((item) => [item.key, item.countText]), [['browser', '1 call']]);
    assert.equal(s.plugins.status, 'not-recorded');
    assert.equal(s.extensions.status, 'partial');
    assert.deepEqual(s.extensions.items.map((item) => [item.key, item.countText]), [['project:demo-board', '4 canvas calls']]);
});

test('subagent views list only what the subagent did and keep session-level live lists', async (t) => {
    const { recorded } = await recordedFor(t, SUBAGENT_ID);
    const live = { agents: { status: 'live', items: [{ name: 'reviewer', displayName: 'Reviewer' }] }, skills: { status: 'live', items: [{ name: 'live-skill' }] } };
    const s = byId(buildContextSections({ recorded, live, catalogs: {}, mainAgent: false }));
    assert.equal(s.tools.status, 'not-recorded');
    assert.equal(s.agents.status, 'live');
    assert.equal(s.skills.status, 'not-recorded');
});

test('live sections merge catalogs and lists with recorded counts and count each run once', async (t) => {
    const { index, recorded } = await recordedFor(t);
    const live = {
        agents: { status: 'live', items: [
            { id: 'Planner', name: 'Planner', displayName: 'Planner', disableModelInvocation: true, source: 'plugin' },
            { id: 'Reviewer', name: 'Reviewer', displayName: 'Reviewer' },
            { id: 'demo:reviewer', name: 'demo:reviewer', displayName: 'demo:reviewer' },
        ] },
        skills: { status: 'live', items: [{ name: 'planning', description: 'Plans', pluginName: 'demo-plugin', enabled: true }] },
        instructions: { status: 'live', items: [{ label: 'Markdown', sourcePath: '/workspace/demo/.github/instructions/markdown.instructions.md', location: 'repository', applyTo: ['**/*.md'] }] },
        mcpServers: { status: 'live', items: [{ name: 'browser', status: 'connected', sourcePlugin: 'demo-plugin' }, { name: 'remote', status: 'failed', error: 'unreachable' }] },
        plugins: { status: 'live', items: [{ name: 'demo-plugin', version: '1.0.0', marketplace: 'demo', enabled: true }] },
        extensions: { status: 'live', items: [{ id: 'project:demo-board', name: 'demo-board', source: 'project', status: 'running' }] },
    };
    const catalogs = {
        tools: { status: 'live', items: [{ name: 'browser-navigate', description: 'Navigates', mcpServerName: 'browser', deferLoading: true }, { name: 'bash', description: 'Runs commands', mcpServerName: null, deferLoading: false }] },
        canvases: { status: 'live', items: [{ canvasId: 'demo-board', displayName: 'Demo Board', description: 'Cards', extensionId: 'project:demo-board', extensionName: 'demo-board', actions: ['add_card', 'clear'] }] },
        subagents: { status: 'live', items: [{ name: 'explore', description: 'Explores', builtIn: true }, { name: 'Reviewer', description: 'Reviews', builtIn: false }, { name: 'demo:reviewer', description: 'Reviews', builtIn: false }] },
    };
    const s = byId(buildContextSections({ recorded, live, catalogs, mainAgent: true, readCounts: (paths) => index.getReadCounts(ROOT_AGENT, paths) }));

    assert.equal(s.tools.status, 'live');
    assert.equal(s.tools.note, 'Live: 2 offered, 1 on demand. Calls from the log.');
    assert.deepEqual(row(s.tools, 'browser-navigate').badges.map((badge) => badge.text), ['MCP · browser', 'On demand', 'Loaded by search']);
    assert.equal(row(s.tools, 'list_canvas_capabilities').description, 'Called earlier; not offered now.');

    assert.deepEqual(s.agents.items.map((item) => [item.name, item.countText]), [['Planner', 'Selected 1×'], ['Reviewer', '1 run'], ['demo:reviewer', 'Not used']]);
    assert.deepEqual(row(s.agents, 'Planner').badges.map((badge) => badge.text), ['Current', 'User only', 'plugin']);
    assert.deepEqual(s.subagents.items.map((item) => [item.name, item.countText, item.badges.map((badge) => badge.text)]), [['explore', 'Not run', ['Built-in']], ['Reviewer', '1 run', []], ['demo:reviewer', 'Not run', []]]);

    assert.deepEqual(row(s.canvases, 'demo-board').badges.map((badge) => badge.text), ['2 actions']);
    assert.equal(row(s.instructions, '/workspace/demo/.github/instructions/markdown.instructions.md').countText, 'Read 1×');
    assert.deepEqual(s.mcp.items.map((item) => [item.key, item.countText, item.badges[0].tone]), [['browser', '1 call', 'success'], ['remote', 'Not called', 'danger']]);
    assert.deepEqual(row(s.plugins, 'demo-plugin').badges.map((badge) => badge.text), ['1 skill', '1 MCP server']);
    assert.equal(row(s.extensions, 'project:demo-board').description, 'Provides Demo Board');
    assert.equal(row(s.extensions, 'project:demo-board').countText, '4 canvas calls');
});

test('counts reduce sections to key, count, failures, and text', async (t) => {
    const { recorded } = await recordedFor(t);
    const counts = contextCounts(buildContextSections({ recorded, live: null, catalogs: {}, mainAgent: true }));
    assert.deepEqual(Object.keys(counts), CONTEXT_SECTIONS.map((section) => section.id));
    assert.deepEqual(counts.canvases[0], ['demo-board', 4, 1, '4 calls']);
});
