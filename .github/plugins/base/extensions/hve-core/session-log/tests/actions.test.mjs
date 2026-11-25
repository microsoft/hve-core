// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { ACTION_DEFINITIONS, createActionHandlers } from '../lib/actions.mjs';
import { createSessionLogServer } from '../lib/server.mjs';
import { OTHER_SESSION_ID, SESSION_ID, SUBAGENT_ID, writeSession } from './fixtures.mjs';

class TestCanvasError extends Error {
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}

async function setup(t) {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-actions-'));
    t.after(() => fs.rm(root, { recursive: true, force: true }));
    await writeSession(root, SESSION_ID);
    await writeSession(root, OTHER_SESSION_ID, { yaml: `name: ${'Long title '.repeat(30)}` });
    const server = createSessionLogServer({ root, getCurrentSessionId: () => SESSION_ID });
    const instances = new Map([['panel-1', { server }]]);
    const handlers = createActionHandlers({ getInstance: (id) => instances.get(id), makeError: (code, message) => new TestCanvasError(code, message) });
    const invoke = (name, input, instanceId = 'panel-1') => handlers[name]({ instanceId, input, sessionId: SESSION_ID });
    return { server, invoke };
}

async function rejectsWith(promise, code) {
    await assert.rejects(promise, (error) => {
        assert.ok(error instanceof TestCanvasError);
        assert.equal(error.code, code);
        return true;
    });
}

test('declares four actions with schemas and no reserved names', () => {
    assert.deepEqual(ACTION_DEFINITIONS.map((action) => action.name), ['list_sessions', 'select_session', 'get_session_summary', 'focus_entry']);
    for (const action of ACTION_DEFINITIONS) {
        assert.equal(action.name.startsWith('canvas.'), false);
        assert.equal(action.inputSchema.type, 'object');
        assert.equal(action.inputSchema.additionalProperties, false);
    }
});

test('list_sessions returns metadata with capped titles', async (t) => {
    const { invoke } = await setup(t);
    const result = await invoke('list_sessions', { limit: 5 });
    assert.equal(result.total, 2);
    const current = result.sessions.find((session) => session.sessionId === SESSION_ID);
    assert.equal(current.isCurrent, true);
    const other = result.sessions.find((session) => session.sessionId === OTHER_SESSION_ID);
    assert.ok(other.title.length <= 120);
    assert.deepEqual(Object.keys(current).sort(), ['active', 'branch', 'host', 'isCurrent', 'repository', 'sessionId', 'title', 'updatedAt']);
    await rejectsWith(invoke('list_sessions', { limit: 0 }), 'invalid_input');
    await rejectsWith(invoke('list_sessions', { extra: true }), 'invalid_input');
    await rejectsWith(invoke('list_sessions', 'nope'), 'invalid_input');
});

test('select_session switches sessions and returns to the current session', async (t) => {
    const { invoke, server } = await setup(t);
    const selected = await invoke('select_session', { sessionId: OTHER_SESSION_ID });
    assert.equal(selected.sessionId, OTHER_SESSION_ID);
    assert.equal(selected.isCurrent, false);
    assert.equal(server.selectedSessionId(), OTHER_SESSION_ID);
    const back = await invoke('select_session', { sessionId: 'current' });
    assert.equal(back.sessionId, SESSION_ID);
    assert.equal(server.stateSnapshot().followsCurrent, true);
    await rejectsWith(invoke('select_session', {}), 'invalid_input');
    await rejectsWith(invoke('select_session', { sessionId: '../x' }), 'invalid_input');
    await rejectsWith(invoke('select_session', { sessionId: '99999999-2222-4333-8444-555555555555' }), 'session_not_found');
});

test('get_session_summary returns metadata without session content', async (t) => {
    const { invoke } = await setup(t);
    const summary = await invoke('get_session_summary', {});
    assert.equal(summary.sessionId, SESSION_ID);
    assert.equal(summary.model, 'demo-model-2');
    assert.equal(summary.customAgent, 'Demo Agent');
    assert.equal(summary.counts.subagents, 2);
    assert.equal(summary.premiumRequests, 3);
    assert.equal(summary.subagents.find((agent) => agent.agentId === SUBAGENT_ID).status, 'completed');
    assert.deepEqual(summary.eventHealth, { unknownTypes: [{ type: 'custom.future_event', count: 1 }], debugEvents: 1, unreadableLines: 0 });
    const text = JSON.stringify(summary);
    for (const content of ['Please **review**', 'Research summary', 'Permission denied', 'You are a helpful coding assistant']) {
        assert.equal(text.includes(content), false, content);
    }
});

test('focus_entry requests focus for tool calls and agents', async (t) => {
    const { invoke, server } = await setup(t);
    const tool = await invoke('focus_entry', { toolCallId: 'call-sub-view' });
    assert.deepEqual(tool, { focused: 'tool', id: 'call-sub-view', agentId: SUBAGENT_ID });
    assert.equal(server.stateSnapshot().focus.toolCallId, 'call-sub-view');
    const agent = await invoke('focus_entry', { agentId: SUBAGENT_ID });
    assert.deepEqual(agent, { focused: 'agent', id: SUBAGENT_ID });
    await rejectsWith(invoke('focus_entry', {}), 'invalid_input');
    await rejectsWith(invoke('focus_entry', { toolCallId: 'a', agentId: 'root' }), 'invalid_input');
    await rejectsWith(invoke('focus_entry', { toolCallId: 'missing-call' }), 'entry_not_found');
    await rejectsWith(invoke('focus_entry', { agentId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' }), 'entry_not_found');
});

test('actions require an open canvas instance', async (t) => {
    const { invoke } = await setup(t);
    await rejectsWith(invoke('list_sessions', {}, 'closed-panel'), 'instance_not_open');
});

test('unexpected storage failures map to storage_unavailable without local paths', async (t) => {
    const { server, invoke } = await setup(t);
    server.shared.catalog.get = async () => {
        throw Object.assign(new Error('EACCES: permission denied, open /home/user/.copilot/session-state/x/events.jsonl'), { code: 'EACCES' });
    };
    await assert.rejects(invoke('get_session_summary', {}), (error) => {
        assert.ok(error instanceof TestCanvasError);
        assert.equal(error.code, 'storage_unavailable');
        assert.equal(error.message.includes('/home/user'), false);
        return true;
    });
    await rejectsWith(invoke('select_session', { sessionId: 'nope' }), 'invalid_input');
});

test('every action that returns session-derived strings carries the untrusted note', () => {
    for (const action of ACTION_DEFINITIONS) {
        assert.match(action.description, /untrusted/, action.name);
    }
});
