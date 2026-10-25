// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { agentInstructionsBlock, agentNameKey, analyzeSystemPrompt, canvasPromptEntry, diffSections, HANDLED_EVENT_TYPES, IndexCache, instructionPromptEntry, leadingPromptText, messageText, parseFieldPath, plainSummary, ROOT_AGENT, SessionIndex, skillPromptEntry, summarizeArguments } from '../lib/indexer.mjs';
import { AGENT_BODY, buildCompactionEvents, buildEvents, buildInventoryEvents, CANVAS_CAPABILITIES, COMPACTION_REQUEST, COMPACTION_SUMMARY, NESTED_ID, SESSION_ID, SUBAGENT_ID, toJsonl } from './fixtures.mjs';
import { symlinkOrSkip } from './helpers.mjs';

async function indexFor(t, content, options) {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-index-'));
    t.after(() => fs.rm(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'events.jsonl');
    await fs.writeFile(file, content);
    return { file, index: new SessionIndex(file, options) };
}

test('extracts session and per-agent metadata', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    const result = await index.refresh();
    assert.equal(result.changed, true);
    assert.ok(result.bytesRead > 0);
    const summary = index.getSummary();
    assert.equal(summary.session.start.copilotVersion, '9.9.9');
    assert.equal(summary.session.start.repository, 'octo/demo');
    assert.equal(summary.session.checkpoint.totalPremiumRequests, 3);
    assert.equal(summary.counts.debugEvents, 1);
    assert.deepEqual(summary.counts.unknownTypes, [{ type: 'custom.future_event', count: 1 }]);

    const root = summary.agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.model, 'demo-model-2');
    assert.equal(root.reasoningEffort, 'medium');
    assert.equal(root.models.length, 2);
    assert.equal(root.customAgent.displayName, 'Demo Agent');
    assert.deepEqual(root.skillsInvoked.map((skill) => skill.name), ['demo-skill']);
    assert.equal(root.usage.inputTokens, 12000);
    assert.equal(root.context.current, 20000);
    assert.equal(root.context.limit, 100000);
    assert.equal(root.context.peak, 90000);
    assert.equal(root.compactions.length, 1);
    assert.equal(root.hooks.count, 2);
    assert.equal(root.hooks.failed, 1);
    assert.deepEqual(root.tools.find((tool) => tool.name === 'bash'), { name: 'bash', count: 1, failed: 1, lastCallId: 'call-bash' });
    assert.equal(root.systemPrompt.skillCount, 4);
    assert.equal(root.systemPrompt.instructionCount, 2);
    assert.equal(root.systemPrompt.agentInstructions.title, 'Demo Agent');

    const sub = summary.agents.find((agent) => agent.key === SUBAGENT_ID);
    assert.equal(sub.parentKey, ROOT_AGENT);
    assert.equal(sub.spawnToolCallId, 'call-task');
    assert.equal(sub.displayName, 'docs-lane');
    assert.equal(sub.agentType, 'researcher');
    assert.equal(sub.model, 'small-model');
    assert.equal(sub.reasoningEffort, 'max');
    assert.equal(sub.status, 'completed');
    assert.equal(sub.durationMs, 4200);
    assert.equal(sub.totalToolCalls, 2);
    assert.equal(sub.context.limit, 50000);
    assert.equal(sub.systemPrompt.sectionCount, 2);

    const nested = summary.agents.find((agent) => agent.key === NESTED_ID);
    assert.equal(nested.parentKey, SUBAGENT_ID);
    assert.deepEqual(sub.children, [NESTED_ID]);
});

test('pairs tool calls, links subagents, and aggregates hooks into turns', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();
    const entries = index.agents.get(ROOT_AGENT).entries;
    const kinds = entries.map((entry) => entry.kind);
    assert.ok(!kinds.includes('hook'));
    const tools = entries.filter((entry) => entry.kind === 'tool');
    assert.deepEqual(tools.map((tool) => [tool.name, tool.status]), [['view', 'succeeded'], ['bash', 'failed'], ['task', 'succeeded'], ['grep', 'running']]);
    assert.equal(tools[0].summary, 'view README.md');
    assert.equal(tools[0].parts.length, 2);
    assert.equal(tools[1].result, 'Permission denied');
    assert.equal(tools[2].subagent, SUBAGENT_ID);
    const turn = entries.find((entry) => entry.kind === 'turn');
    assert.equal(turn.hooks, 2);
    assert.equal(turn.hooksFailed, 1);
    assert.deepEqual(turn.hookTypes.preToolUse, { count: 1, failed: 1 });
    assert.deepEqual(turn.hookRuns.map((run) => [run.type, run.status, run.error]), [['sessionStart', 'succeeded', null], ['preToolUse', 'failed', 'hook failed']]);
    assert.equal(turn.inputTokens, 12000);
    assert.equal(turn.ended, true);
    assert.ok(kinds.includes('unknown'));
    assert.ok(kinds.includes('compaction'));
    const nestedTool = index.agents.get(SUBAGENT_ID).entries.find((entry) => entry.toolCallId === 'call-nested');
    assert.equal(nestedTool.subagent, NESTED_ID);
    const user = entries.find((entry) => entry.kind === 'user');
    assert.equal(user.attachments[0].name, 'README.md');
    assert.ok(user.injectedChars > 0);
    assert.ok(!user.summary.includes('**'));
});

test('tolerates missing fields, malformed lines, and blank lines', async (t) => {
    const content = [
        '{"type":"user.message"}',
        'not json',
        '',
        '{"data":{}}',
        '{"type":"tool.execution_complete","data":{"toolCallId":"orphan","success":true}}',
        '{"type":"subagent.completed","agentId":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","data":{}}',
        '{"type":"assistant.message","data":{"content":5,"toolRequests":"nope"}}',
    ].join('\n') + '\n';
    const { index } = await indexFor(t, content);
    await index.refresh();
    const summary = index.getSummary();
    assert.equal(summary.counts.malformed, 2);
    assert.equal(summary.counts.events, 4);
    const entries = index.agents.get(ROOT_AGENT).entries;
    assert.deepEqual(entries.map((entry) => entry.kind), ['user', 'tool', 'assistant']);
    assert.equal(entries[1].status, 'succeeded');
});

test('reads only appended complete lines and holds partial lines', async (t) => {
    const events = buildEvents();
    const { file, index } = await indexFor(t, toJsonl(events.slice(0, 5)));
    await index.refresh();
    const versionBefore = index.version;
    const unchanged = await index.refresh();
    assert.equal(unchanged.bytesRead, 0);
    assert.equal(unchanged.changed, false);

    const line = JSON.stringify(events[5]);
    await fs.appendFile(file, line.slice(0, 20));
    const partial = await index.refresh();
    assert.equal(partial.changed, false);
    assert.equal(index.version, versionBefore);
    assert.equal(index.agents.get(ROOT_AGENT).counts.user, 0);

    await fs.appendFile(file, `${line.slice(20)}\n`);
    const completed = await index.refresh();
    assert.equal(completed.changed, true);
    assert.equal(index.agents.get(ROOT_AGENT).counts.user, 1);
    assert.ok(index.version > versionBefore);
});

test('discards an unterminated line longer than the cap', async (t) => {
    const big = `{"type":"user.message","data":{"content":"${'x'.repeat(4096)}"}}`;
    const { file, index } = await indexFor(t, `${big}`, { maxLineBytes: 1024, chunkSize: 512 });
    await index.refresh();
    await fs.appendFile(file, '\n{"type":"abort","data":{"reason":"after"}}\n');
    await index.refresh();
    const summary = index.getSummary();
    assert.equal(summary.counts.malformed, 1);
    assert.deepEqual(index.agents.get(ROOT_AGENT).entries.map((entry) => entry.kind), ['abort']);
});

test('reindexes from the start when the file shrinks or is rewritten', async (t) => {
    const events = buildEvents();
    const { file, index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const epoch = index.epoch;
    await fs.writeFile(file, toJsonl(events.slice(0, 3)));
    const result = await index.refresh();
    assert.equal(result.reset, true);
    assert.notEqual(index.epoch, epoch);
    assert.equal(index.getSummary().counts.events, 3);

    const rewritten = events.slice(0, 3).map((event) => ({ ...event, id: `${event.id}-x` }));
    await fs.writeFile(file, toJsonl([...rewritten, ...events.slice(3, 10)]));
    const second = await index.refresh();
    assert.equal(second.reset, true);
    assert.equal(index.getSummary().counts.events, 10);
});

test('does not reset on ordinary appends that span many small chunks', async (t) => {
    const events = buildEvents();
    const { file, index } = await indexFor(t, toJsonl(events.slice(0, 10)), { chunkSize: 64 });
    await index.refresh();
    const epoch = index.epoch;
    for (let start = 10; start < events.length; start += 7) {
        await fs.appendFile(file, toJsonl(events.slice(start, start + 7)));
        const result = await index.refresh();
        assert.equal(result.reset, false, `append at ${start}`);
    }
    assert.equal(index.getSummary().counts.events, events.length);
    assert.equal(index.epoch, epoch);
});

test('reports added and updated entries for incremental refresh', async (t) => {
    const events = buildEvents();
    const { file, index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const total = index.agents.get(ROOT_AGENT).entries.length;
    const version = index.version;
    await fs.appendFile(file, toJsonl([
        { type: 'tool.execution_complete', data: { toolCallId: 'call-running', success: true, result: { content: 'done' } }, timestamp: '2026-01-15T10:10:00.000Z' },
        { type: 'assistant.message', data: { content: 'Finished.' }, timestamp: '2026-01-15T10:10:01.000Z' },
    ]));
    await index.refresh();
    const changes = index.getChanges(ROOT_AGENT, total, version);
    assert.equal(changes.resync, false);
    assert.deepEqual(changes.added.map((entry) => entry.kind), ['assistant']);
    assert.deepEqual(changes.updated.map((entry) => entry.name), ['grep']);
    assert.equal(changes.updated[0].status, 'succeeded');
    assert.equal(index.getChanges(ROOT_AGENT, total, -1).resync, true);
});

test('pages long fields and drops opaque reasoning payloads in details', async (t) => {
    const events = buildEvents();
    const { index } = await indexFor(t, toJsonl(events), { pageChars: 100 });
    await index.refresh();
    const system = index.agents.get(ROOT_AGENT).entries.find((entry) => entry.kind === 'system');
    const detail = await index.readDetail(ROOT_AGENT, system.seq);
    assert.equal(detail.events[0].data.content.length, 100);
    const truncated = detail.truncated.find((item) => item.path === 'data.content');
    assert.ok(truncated.length > 100);
    assert.deepEqual(Object.keys(detail.events[0].data.contentBlocks[0]).sort(), ['cacheBreakpoint', 'chars', 'isStatic']);

    let text = detail.events[0].data.content;
    let next = truncated.next;
    while (next !== null) {
        const page = await index.readField(ROOT_AGENT, system.seq, truncated.part, truncated.path, next);
        text += page.text;
        next = page.next;
    }
    assert.equal(text, events.find((event) => event.type === 'system.message').data.content);

    const assistant = index.agents.get(ROOT_AGENT).entries.find((entry) => entry.kind === 'assistant');
    const assistantDetail = await index.readDetail(ROOT_AGENT, assistant.seq);
    assert.equal('reasoningOpaque' in assistantDetail.events[0].data, false);
    assert.equal(await index.readField(ROOT_AGENT, system.seq, 0, 'data.__proto__', 0), null);
    assert.equal(await index.readField(ROOT_AGENT, system.seq, 0, 'data.metadata', 0), null);
    assert.equal(await index.readDetail(ROOT_AGENT, 99999), null);
});

test('attaches capped bodies to user and assistant entries', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()), { bodyChars: 10 });
    await index.refresh();
    const page = index.getEntries(ROOT_AGENT, { from: 0, limit: 500 });
    const withBodies = await index.withBodies(page.entries);
    const user = withBodies.find((entry) => entry.kind === 'user');
    assert.equal(user.body.length, 10);
    assert.ok(!('body' in withBodies.find((entry) => entry.kind === 'tool')));
});

test('finds entries by sequence or tool call across agents', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();
    const located = index.findEntry(ROOT_AGENT, { toolCallId: 'call-sub-view' });
    assert.equal(located.agent, SUBAGENT_ID);
    const entry = index.agents.get(ROOT_AGENT).entries[3];
    assert.deepEqual(index.findEntry(ROOT_AGENT, { seq: entry.seq }), { agent: ROOT_AGENT, index: 3 });
    assert.equal(index.findEntry(ROOT_AGENT, { seq: -5 }), null);
});

test('outline filters tool calls by status and query', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();
    const failed = index.getOutline(ROOT_AGENT, { status: 'failed' });
    assert.deepEqual(failed.tools.map((tool) => tool.name), ['bash']);
    assert.equal(failed.toolTotal, 4);
    const running = index.getOutline(ROOT_AGENT, { status: 'running' });
    assert.deepEqual(running.tools.map((tool) => tool.name), ['grep']);
    const query = index.getOutline(ROOT_AGENT, { query: 'readme' });
    assert.deepEqual(query.tools.map((tool) => tool.name), ['view']);
    assert.equal(query.interactions.length, 1);
});

test('recorded inventory reconstructs skills, instructions, and tools', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();
    const inventory = index.getRecordedInventory(ROOT_AGENT);
    assert.deepEqual(inventory.skills.map((skill) => skill.name), ['demo-skill', 'second-skill', 'extra-one', 'extra-two']);
    assert.equal(inventory.skills[0].description, 'Demonstrates skill parsing & listing.');
    assert.deepEqual(inventory.instructions.map((item) => item.path), ['docs/markdown.instructions.md', 'docs/ts.instructions.md']);
    assert.deepEqual(inventory.tools.names, ['bash', 'grep', 'task', 'view']);
    assert.equal(inventory.tools.declaredCount, 40);
    assert.deepEqual(inventory.subagentTypes.map((item) => item.type).sort(), ['explore', 'researcher']);
});

test('index cache evicts the least recently used session', () => {
    const cache = new IndexCache((id) => `/tmp/${id}/events.jsonl`, { max: 2 });
    const a = cache.get('a');
    cache.get('b');
    assert.equal(cache.get('a'), a);
    cache.get('c');
    assert.equal(cache.has('b'), false);
    assert.equal(cache.has('a'), true);
    assert.equal(cache.has('c'), true);
});

test('helpers summarize arguments, strip Markdown, and validate field paths', () => {
    assert.equal(summarizeArguments({ command: 'ls -la', other: 'x' }), 'ls -la');
    assert.equal(summarizeArguments({ unknown: 'value' }), 'value');
    assert.equal(summarizeArguments('raw'), 'raw');
    assert.equal(summarizeArguments(null), '');
    assert.equal(plainSummary('# Title\n\n* **bold** `code` [link](https://x.test)'), 'Title bold code link');
    assert.deepEqual(parseFieldPath('data.result.content'), ['data', 'result', 'content']);
    assert.equal(parseFieldPath('data..x'), null);
    assert.equal(parseFieldPath('data.constructor'), null);
    const analysis = analyzeSystemPrompt('intro\n<a>\nx\n</a>\n<b>\n<c>\n</c>\n</b>\ntrailing', []);
    assert.deepEqual(analysis.sections.map((section) => section.name), ['(untagged text)', 'a', 'b']);
    assert.equal(SESSION_ID.length, 36);
});

test('a read failure mid-refresh resets instead of re-ingesting entries', async (t) => {
    const events = buildEvents();
    const { index } = await indexFor(t, toJsonl(events), { chunkSize: 256 });
    const realOpen = fs.open;
    let reads = 0;
    const openMock = t.mock.method(fs, 'open', async (...args) => {
        const handle = await realOpen(...args);
        return {
            read: (...readArgs) => {
                reads += 1;
                return reads === 3 ? Promise.reject(Object.assign(new Error('read failed'), { code: 'EIO' })) : handle.read(...readArgs);
            },
            close: () => handle.close(),
        };
    });
    await assert.rejects(index.refresh(), { code: 'EIO' });
    openMock.mock.restore();
    await index.refresh();
    const reference = new SessionIndex(index.file);
    await reference.refresh();
    const seqs = index.agents.get(ROOT_AGENT).entries.map((entry) => entry.seq);
    assert.equal(new Set(seqs).size, seqs.length);
    assert.equal(index.agents.get(ROOT_AGENT).entries.length, reference.agents.get(ROOT_AGENT).entries.length);
    assert.equal(index.counts.events, reference.counts.events);
});

test('event strings never reach object prototypes', async (t) => {
    const events = buildEvents().map((event) => (event.type.startsWith('hook.') && event.data.hookType === 'preToolUse'
        ? { ...event, data: { ...event.data, hookType: '__proto__' } }
        : event));
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const turn = index.agents.get(ROOT_AGENT).entries.find((entry) => entry.kind === 'turn');
    assert.deepEqual({ ...Object.getOwnPropertyDescriptor(turn.hookTypes, '__proto__')?.value }, { count: 1, failed: 1 });
    assert.equal(({}).count, undefined);
    assert.equal(JSON.parse(JSON.stringify(turn.hookTypes)).__proto__.count, 1);
});

test('a symlinked session folder or log is treated as missing', async (t) => {
    const outside = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-outside-'));
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-root-'));
    t.after(async () => {
        await fs.rm(outside, { recursive: true, force: true });
        await fs.rm(root, { recursive: true, force: true });
    });
    await fs.writeFile(path.join(outside, 'events.jsonl'), toJsonl(buildEvents()));
    if (!(await symlinkOrSkip(t, outside, path.join(root, SESSION_ID), 'dir'))) {
        return;
    }
    const linkedFolder = new SessionIndex(path.join(root, SESSION_ID, 'events.jsonl'));
    assert.equal((await linkedFolder.refresh()).missing, true);
    assert.equal(linkedFolder.counts.events, 0);

    const folder = path.join(root, NESTED_ID);
    await fs.mkdir(folder);
    await fs.symlink(path.join(outside, 'events.jsonl'), path.join(folder, 'events.jsonl'));
    const linkedFile = new SessionIndex(path.join(folder, 'events.jsonl'));
    assert.equal((await linkedFile.refresh()).missing, true);
    assert.equal(linkedFile.counts.events, 0);
});

test('tool previews carry the head of arguments and the tail of output or errors', async (t) => {
    const big = `${'start '.repeat(2000)}END`;
    const events = buildEvents().map((event) => {
        if (event.type === 'tool.execution_start' && event.data.toolName === 'view') {
            return { ...event, data: { ...event.data, arguments: { path: 'README.md', content: big } } };
        }
        if (event.type === 'tool.execution_complete' && event.data.toolCallId === 'call-view') {
            return { ...event, data: { ...event.data, result: { content: `HEAD ${'x'.repeat(9000)} TAIL` } } };
        }
        return event;
    });
    const { index } = await indexFor(t, toJsonl(events), { previewChars: 1024 });
    await index.refresh();
    const page = await index.withBodies(index.getEntries(ROOT_AGENT, { from: 0, limit: 200 }).entries);
    const view = page.find((entry) => entry.kind === 'tool' && entry.name === 'view');
    assert.equal(view.preview.argsJson, true);
    assert.ok(view.preview.args.startsWith('{\n  "path": "README.md"'));
    assert.equal(view.preview.args.length, 1024);
    assert.ok(view.preview.argsChars > 12000);
    assert.ok(view.preview.output.endsWith(' TAIL'));
    assert.equal(view.preview.output.length, 1024);
    assert.equal(view.preview.outputPath, 'data.result.content');
    const bash = page.find((entry) => entry.kind === 'tool' && entry.name === 'bash');
    assert.equal(bash.preview.error, 'Permission denied (failure)');
    const running = page.find((entry) => entry.kind === 'tool' && entry.status === 'running');
    assert.equal(running.preview.output, null);
});

test('hook runs read their own events through readDetail and readField', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();
    const turn = index.agents.get(ROOT_AGENT).entries.find((entry) => entry.kind === 'turn');
    const detail = await index.readDetail(ROOT_AGENT, turn.seq, 1);
    assert.deepEqual(detail.events.map((event) => event.type), ['hook.start', 'hook.end']);
    assert.equal(detail.events[1].data.error.message, 'hook failed');
    assert.equal(await index.readDetail(ROOT_AGENT, turn.seq, 99), null);
    const field = await index.readField(ROOT_AGENT, turn.seq, 1, 'data.error.message', 0, 1);
    assert.equal(field.text, 'hook failed');
});

test('the main agent reports its end time after shutdown', async (t) => {
    const events = buildEvents();
    events.push({ type: 'session.shutdown', data: { shutdownType: 'routine' }, id: 'end', timestamp: '2026-01-15T11:00:00.000Z', parentId: null });
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const root = index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.endTs, '2026-01-15T11:00:00.000Z');
    assert.ok(root.durationMs > 0);
});

test('system prompt versions record their reason, size change, and section changes', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildCompactionEvents()));
    await index.refresh();
    const prompts = index.agents.get(ROOT_AGENT).entries.filter((entry) => entry.kind === 'system');
    assert.deepEqual(prompts.map((entry) => [entry.label, entry.version]), [['System prompt', 1], ['System prompt rebuilt', 2], ['System prompt rebuilt', 3]]);
    assert.deepEqual(prompts[0].reasons, []);
    assert.equal(prompts[0].changed, null);
    assert.ok(prompts[1].reasons.includes('session resumed'));
    assert.ok(prompts[1].reasons.includes('new prompt'));
    assert.deepEqual(prompts[1].changed.added, ['canvases']);
    assert.ok(prompts[1].delta > 0);
    assert.deepEqual(prompts[2].reasons, ['context compacted', 'new prompt']);
    assert.deepEqual(prompts[2].changed.resized.map((item) => item.name), ['canvases']);

    const root = index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.systemPromptCount, 3);
    assert.deepEqual(root.systemPromptVersions.map((item) => item.seq), prompts.map((entry) => entry.seq));

    const first = await index.getSystemPrompt(ROOT_AGENT, prompts[0].seq);
    assert.equal(first.version, 1);
    assert.equal(first.versionCount, 3);
    assert.ok(!first.sections.some((section) => section.name === 'canvases'));
    const latest = await index.getSystemPrompt(ROOT_AGENT);
    assert.equal(latest.seq, prompts[2].seq);
    assert.ok(latest.sections.some((section) => section.name === 'canvases'));
    assert.equal(await index.getSystemPrompt(ROOT_AGENT, prompts[0].seq + 1), null);
});

test('compactions split around intervening entries and link only their own request snapshot', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildCompactionEvents()));
    await index.refresh();
    const compactions = index.agents.get(ROOT_AGENT).entries.filter((entry) => entry.kind === 'compaction');
    assert.deepEqual(compactions.map((entry) => entry.phase), ['single', 'start', 'result', 'single']);
    const [, start, result, late] = compactions;
    assert.equal(start.resultSeq, result.seq);
    assert.equal(result.startSeq, start.seq);
    assert.equal(start.label, 'Compaction started');
    assert.equal(result.label, 'Context compacted');
    assert.equal(result.parts.length, 2);
    assert.deepEqual(result.split.before, { system: 5000, conversation: 85000, tools: 5000 });
    assert.equal(result.inputTokens, 88000);
    assert.equal(result.checkpointName, '001-two.md');
    assert.equal(result.requestChars, null);
    assert.equal(late.requestChars, COMPACTION_REQUEST.length);
    assert.equal(late.requestMessages, 4);
    assert.equal(index.getSummary().counts.debugEvents, 4);

    assert.equal((await index.readCompactionText(ROOT_AGENT, late.seq, 'request', 0)).text, COMPACTION_REQUEST);
    assert.equal((await index.readCompactionText(ROOT_AGENT, late.seq, 'summary', 0)).text, COMPACTION_SUMMARY);
    const page = await index.readCompactionText(ROOT_AGENT, late.seq, 'summary', 5);
    assert.equal(page.start, 5);
    assert.equal(page.length, COMPACTION_SUMMARY.length);
    assert.equal(await index.readCompactionText(ROOT_AGENT, result.seq, 'request', 0), null);
    assert.equal(await index.readCompactionText(ROOT_AGENT, start.seq, 'summary', 0), null);
});

test('the outline lists compactions in order with tools and filters them', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildCompactionEvents()));
    await index.refresh();
    const all = index.getOutline(ROOT_AGENT);
    const rows = all.tools.filter((row) => row.kind === 'compaction');
    assert.equal(rows.length, 3);
    assert.equal(all.compactionMatches, 3);
    assert.deepEqual(all.tools.map((row) => row.seq), [...all.tools.map((row) => row.seq)].sort((a, b) => a - b));
    assert.deepEqual(index.getOutline(ROOT_AGENT, { query: 'compact' }).tools.map((row) => row.kind), ['compaction', 'compaction', 'compaction']);
    assert.equal(index.getOutline(ROOT_AGENT, { status: 'failed' }).compactionMatches, 0);
    assert.equal(index.getOutline(ROOT_AGENT, { query: 'readme' }).compactionMatches, 0);
});

test('section diffs and message text helpers', () => {
    const diff = diffSections([{ name: 'a', chars: 10 }, { name: 'b', chars: 5 }, { name: 'b', chars: 6 }], [{ name: 'a', chars: 12 }, { name: 'b', chars: 5 }, { name: 'c', chars: 1 }]);
    assert.deepEqual(diff.added, ['c']);
    assert.deepEqual(diff.removed, ['b']);
    assert.deepEqual(diff.resized, [{ name: 'a', delta: 2 }]);
    assert.equal(messageText({ content: 'plain' }), 'plain');
    assert.equal(messageText({ content: [{ type: 'text', text: 'one' }, { type: 'image' }, { type: 'text', text: 'two' }] }), 'one\ntwo');
    assert.equal(messageText(null), '');
});

test('HANDLED_EVENT_TYPES lists exactly the event types the indexer switch reads', async () => {
    const source = await fs.readFile(new URL('../lib/indexer.mjs', import.meta.url), 'utf8');
    const start = source.indexOf('    #apply(event, seq, offset, length) {');
    const end = source.indexOf('\n    #', start + 10);
    assert.ok(start > 0 && end > start);
    const cases = [...source.slice(start, end).matchAll(/case '([^']+)':/g)].map((match) => match[1]);
    assert.deepEqual([...cases].sort(), [...HANDLED_EVENT_TYPES].sort());
});

test('recorded definitions describe tools, skills, instructions, and agent runs', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildEvents()));
    await index.refresh();

    const tool = await index.getDefinition(ROOT_AGENT, 'tool', 'bash');
    const { latestCall, ...toolStats } = tool;
    assert.deepEqual(toolStats, { calls: { count: 1, failed: 1, lastCallId: 'call-bash' }, otherAgentCalls: 0, schemaHash: 'c0170aaae50c', offered: true, mcpServer: null, activatedBySearch: false });
    assert.equal(latestCall.toolCallId, 'call-bash');
    assert.equal(latestCall.status, 'failed');
    assert.equal(latestCall.error.text, 'Permission denied');
    assert.ok(latestCall.arguments.text.includes('"command"'));
    const unused = await index.getDefinition(ROOT_AGENT, 'tool', 'never-called');
    assert.deepEqual(unused, { calls: { count: 0, failed: 0, lastCallId: null }, otherAgentCalls: 0, schemaHash: null, offered: false, mcpServer: null, activatedBySearch: false, latestCall: null });

    const skill = await index.getDefinition(ROOT_AGENT, 'skill', 'demo-skill');
    assert.equal(skill.promptEntry.form, 'xml');
    assert.ok(skill.promptEntry.text.startsWith('<skill>\n<name>demo-skill</name>'));
    assert.ok(skill.promptEntry.text.endsWith('</skill>'));
    assert.equal(skill.promptAgent, ROOT_AGENT);
    assert.equal(skill.invocations.count, 2);
    const latest = skill.invocations.latest;
    assert.equal(latest.content, '<skill-context name="demo-skill">\nBase directory for this skill: /plugins/demo/skills/demo-skill\n\nskill body\n</skill-context>');
    assert.equal(latest.resolvedFrom, 'earlier load');
    assert.equal(latest.wrapped, true);
    assert.equal(latest.trigger, 'agent-invoked');
    assert.equal(latest.invokedAtTurn, 1);
    assert.equal(latest.truncated, false);
    const listed = await index.getDefinition(ROOT_AGENT, 'skill', 'extra-two');
    assert.equal(listed.promptEntry.form, 'listed');
    assert.deepEqual(listed.invocations, { count: 0, latest: null });
    assert.equal((await index.getDefinition(ROOT_AGENT, 'skill', 'absent')).promptEntry, null);

    const instruction = await index.getDefinition(ROOT_AGENT, 'instruction', '/workspace/demo/docs/ts.instructions.md');
    assert.equal(instruction.promptEntry.applyTo, '**/*.ts');
    assert.equal(instruction.promptEntry.text.split('\n').length, 3);

    const runs = (await index.getDefinition(ROOT_AGENT, 'agent', 'researcher')).runs;
    assert.deepEqual(runs.map((run) => run.key), [SUBAGENT_ID]);
    assert.equal(runs[0].displayName, 'docs-lane');
    assert.equal(runs[0].status, 'completed');
    const aliased = (await index.getDefinition(ROOT_AGENT, 'agent', 'unknown', ['plugin:Explore'])).runs;
    assert.deepEqual(aliased.map((run) => run.key), [NESTED_ID]);

    assert.equal(await index.getDefinition('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'tool', 'bash'), null);
    assert.equal(await index.getDefinition(ROOT_AGENT, 'other', 'bash'), null);
});

test('prompt entry helpers match exact entries and normalize agent names', () => {
    const prompt = '<available_skills>\n<skill>\n<name>a&amp;b</name>\n<description>x</description>\n</skill>\n</available_skills>\nAdditional skills available (invoke by name): c, d';
    assert.equal(skillPromptEntry(prompt, 'a&b').form, 'xml');
    assert.equal(skillPromptEntry(prompt, 'd').form, 'listed');
    assert.equal(skillPromptEntry(prompt, 'b'), null);
    const table = "| Pattern | File Path | Description |\n| --- | --- | --- |\n| **/*.md | '.github/x.instructions.md' | X rules |";
    assert.equal(instructionPromptEntry(table, '.github/x.instructions.md').description, 'X rules');
    assert.equal(instructionPromptEntry(table, 'x.instructions.md').applyTo, '**/*.md');
    assert.equal(instructionPromptEntry(table, 'y.instructions.md'), null);
    assert.equal(instructionPromptEntry(table, ' '), null);
    assert.equal(agentNameKey('hve-core:rpi-plan-critic'), agentNameKey('RPI Plan Critic'));
    assert.equal(agentNameKey(null), '');
});

test('a skill load recorded only as a reference reports its length without text', async (t) => {
    const events = [
        { type: 'session.start', data: { sessionId: SESSION_ID, copilotVersion: '9.9.9', startTime: '2026-01-15T10:00:00.000Z' }, id: 'a', timestamp: '2026-01-15T10:00:00.000Z', parentId: null },
        { type: 'skill.invoked_ref', data: { name: 'lost-skill', trigger: 'agent-invoked', contentId: 'sha256:00', contentLength: 4321 }, id: 'b', timestamp: '2026-01-15T10:00:01.000Z', parentId: null },
    ];
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const latest = (await index.getDefinition(ROOT_AGENT, 'skill', 'lost-skill')).invocations.latest;
    assert.equal(latest.content, null);
    assert.equal(latest.contentChars, 4321);
    assert.equal(latest.resolvedFrom, null);
});

test('summary compaction and prompt version records carry what the inspector shows', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildCompactionEvents()));
    await index.refresh();
    const root = index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.compactionTotal, root.compactions.length);
    const done = root.compactions.find((record) => record.status === 'succeeded');
    assert.ok(done);
    for (const field of ['seq', 'ts', 'before', 'after', 'removed', 'trigger', 'durationMs', 'checkpointNumber', 'checkpointName']) {
        assert.ok(Object.hasOwn(done, field), `missing ${field}`);
    }
    assert.ok(Number.isInteger(done.seq));
    assert.equal(root.activeCompaction, null);
    const versions = root.systemPromptVersions;
    assert.equal(versions[0].changes, null);
    assert.ok(versions.slice(1).every((version) => version.changes && Number.isInteger(version.changes.added) && Number.isInteger(version.sectionCount)));
});

test('recorded inventory covers canvases, hooks, MCP servers, reads, discoveries, tool search, and selections', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildInventoryEvents()));
    await index.refresh();
    const inventory = index.getRecordedInventory(ROOT_AGENT);

    assert.deepEqual(inventory.canvases.prompt.map((canvas) => [canvas.id, canvas.name, canvas.description]), [
        ['demo-board', 'Demo Board', 'Cards & lanes for planning.'],
        ['notes', 'Notes', 'Scratch notes.'],
    ]);
    const board = inventory.canvases.activity.find((canvas) => canvas.canvasId === 'demo-board');
    assert.deepEqual(board, { canvasId: 'demo-board', extensionId: 'project:demo-board', calls: 4, opens: 1, actionCalls: 2, capabilityCalls: 1, failed: 1, instances: 1, open: 0, hasCapabilities: true });

    const hooks = Object.fromEntries(inventory.hooks.map((hook) => [hook.type, hook]));
    assert.deepEqual(hooks.postToolUse, { type: 'postToolUse', count: 2, failed: 1, contextCount: 0, sources: [{ source: 'lint-plugin', failed: 1 }], lastTs: hooks.postToolUse.lastTs });
    assert.equal(hooks.userPromptSubmitted.contextCount, 1);

    assert.deepEqual(inventory.tools.mcpServers, [{ tool: 'browser-navigate', server: 'browser' }]);
    assert.deepEqual(inventory.tools.activated, ['browser-navigate', 'browser-click']);
    assert.ok(inventory.tools.calls.some((call) => call.name === 'invoke_canvas_action' && call.count === 2 && call.failed === 1));
    assert.deepEqual(inventory.discoveredInstructions.map((item) => [item.sourcePath, item.triggerFile]), [['packages/api/AGENTS.md', 'packages/api/src/index.ts']]);
    assert.deepEqual(inventory.selections.map((item) => [item.name, item.count]), [['planner', 1]]);
    assert.deepEqual(inventory.subagentTypes.map((item) => [item.type, item.count]), [['reviewer', 1]]);

    const reads = index.getReadCounts(ROOT_AGENT, ['.github/instructions/markdown.instructions.md', 'docs/other.md']);
    assert.deepEqual([...reads], [['.github/instructions/markdown.instructions.md', 1]]);
});

test('recorded definitions cover canvases, hooks, MCP servers, delivered agent prompts, and tool calls', async (t) => {
    const { index } = await indexFor(t, toJsonl(buildInventoryEvents()));
    await index.refresh();

    const canvas = await index.getDefinition(ROOT_AGENT, 'canvas', 'demo-board');
    assert.ok(canvas.promptEntry.text.startsWith('<canvas>') && canvas.promptEntry.text.includes('<id>demo-board</id>'));
    assert.deepEqual(JSON.parse(canvas.capabilities.text), CANVAS_CAPABILITIES);
    assert.equal(canvas.capabilities.toolCallId, 'c-caps');
    assert.deepEqual(canvas.activity.actions, [{ name: 'add_card', count: 2 }]);
    assert.deepEqual(canvas.instances.map((item) => [item.instanceId, item.title, item.removed]), [['board-1', 'Demo Board', true]]);
    const notes = await index.getDefinition(ROOT_AGENT, 'canvas', 'notes');
    assert.equal(notes.activity, null);
    assert.equal(notes.capabilities, null);

    const hook = await index.getDefinition(ROOT_AGENT, 'hook', 'postToolUse');
    assert.equal(hook.count, 2);
    assert.deepEqual(hook.latestFailure && [hook.latestFailure.source, hook.latestFailure.message], ['lint-plugin', 'Permission denied']);
    assert.equal(hook.lastRun.status, 'succeeded');
    assert.equal(typeof hook.lastRun.seq, 'number');
    const prompt = await index.getDefinition(ROOT_AGENT, 'hook', 'userPromptSubmitted');
    assert.equal(prompt.latestContext.text, 'Remember the style guide.');
    assert.deepEqual(await index.getDefinition(ROOT_AGENT, 'hook', 'sessionEnd'), { type: 'sessionEnd', count: 0, failed: 0, contextCount: 0, sources: [], lastRun: null, latestFailure: null, latestContext: null });

    const mcp = await index.getDefinition(ROOT_AGENT, 'mcp', 'browser');
    assert.deepEqual(mcp, { tools: [{ name: 'browser-navigate', count: 1, failed: 0, lastCallId: 'c-mcp' }], calls: 1, failed: 0 });

    const tool = await index.getDefinition(ROOT_AGENT, 'tool', 'browser-navigate');
    assert.equal(tool.mcpServer, 'browser');
    assert.equal(tool.activatedBySearch, true);
    assert.equal(tool.latestCall.result.text, '{"title":"Example","status":200}');
    assert.equal(JSON.parse(tool.latestCall.arguments.text).url, 'https://example.com');

    const reviewer = await index.getDefinition(ROOT_AGENT, 'agent', 'reviewer');
    assert.equal(reviewer.delivered.form, 'subagent');
    assert.equal(reviewer.delivered.text, AGENT_BODY);
    assert.equal(reviewer.runs.length, 1);
    const planner = await index.getDefinition(ROOT_AGENT, 'agent', 'Planner');
    assert.equal(planner.current, true);
    assert.deepEqual(planner.selections.map((item) => item.count), [1]);
    assert.equal(planner.delivered.form, 'main');
    assert.ok(planner.delivered.text.startsWith('<agent_instructions>') && planner.delivered.text.endsWith('</agent_instructions>'));

    const instruction = await index.getDefinition(ROOT_AGENT, 'instruction', '.github/instructions/markdown.instructions.md');
    assert.equal(instruction.reads, 1);
    assert.equal(instruction.discovered, null);
    const discovered = await index.getDefinition(ROOT_AGENT, 'instruction', 'packages/api/AGENTS.md');
    assert.equal(discovered.discovered.description, 'AGENTS.md from packages/api/');
});

test('prompt helpers extract canvas entries, agent instructions, and leading agent text', () => {
    const prompt = 'Lead text.\n<rules>\nx\n</rules>\n<agent_instructions>\n# A\n</agent_instructions>\n<canvases>\n<canvas>\n<id>a&amp;b</id>\n<name>A</name>\n<description>d</description>\n</canvas>\n</canvases>';
    assert.equal(canvasPromptEntry(prompt, 'a&b').text, '<canvas>\n<id>a&amp;b</id>\n<name>A</name>\n<description>d</description>\n</canvas>');
    assert.equal(canvasPromptEntry(prompt, 'missing'), null);
    assert.deepEqual(agentInstructionsBlock(prompt), { text: '<agent_instructions>\n# A\n</agent_instructions>', chars: 46, truncated: false });
    assert.equal(agentInstructionsBlock('none'), null);
    assert.deepEqual(leadingPromptText(prompt), { text: 'Lead text.', chars: 10, truncated: false });
    assert.equal(leadingPromptText('<rules>\nx\n</rules>'), null);
    assert.equal(leadingPromptText('Body\n<example>\nnever closed').text, 'Body\n<example>\nnever closed');
    assert.equal(leadingPromptText('x'.repeat(10), 4).truncated, true);
    assert.deepEqual(analyzeSystemPrompt(prompt).canvases, [{ id: 'a&b', name: 'A', description: 'd' }]);
});

test('agent instructions come from each agent\'s own latest system prompt, and descriptions stay whole', async (t) => {
    const events = buildInventoryEvents();
    const longDescription = `Gathers candidate sources for one bounded research question. ${'Returns pointers and notes. '.repeat(12)}`.trim();
    events.find((event) => event.type === 'subagent.started').data.agentDescription = longDescription;
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();

    const sub = await index.getAgentInstructions(SUBAGENT_ID);
    assert.deepEqual({ ...sub, seq: typeof sub.seq }, { agent: SUBAGENT_ID, form: 'subagent', text: AGENT_BODY, chars: AGENT_BODY.length, truncated: false, seq: 'number', title: 'Reviewer' });
    const main = await index.getAgentInstructions(ROOT_AGENT);
    assert.equal(main.form, 'main');
    assert.ok(main.text.startsWith('<agent_instructions>') && main.text.includes('# Planner'));
    assert.equal(main.title, 'Planner');
    assert.equal(await index.getAgentInstructions('missing-agent'), null);
    assert.equal(index.getSummary().agents.find((agent) => agent.key === SUBAGENT_ID).description, longDescription);

    const plain = await indexFor(t, toJsonl(buildEvents()));
    await plain.index.refresh();
    assert.equal((await plain.index.getAgentInstructions(SUBAGENT_ID)).text, 'You are a research helper.');
});

/** Builds a small event stream with one-second timestamps. */
function stream(build) {
    let clock = Date.parse('2026-02-01T09:00:00.000Z');
    let id = 0;
    const ev = (type, data = {}, extra = {}) => {
        clock += 1000;
        return { type, data, id: `s${(id += 1)}`, timestamp: new Date(clock).toISOString(), parentId: null, ...extra };
    };
    return build(ev);
}

const contentId = (text) => `sha256:${createHash('sha256').update(text, 'utf8').digest('hex')}`;

test('a rebuilt index never reuses the cursor of the index it replaced', async (t) => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-epoch-'));
    t.after(() => fs.rm(dir, { recursive: true, force: true }));
    const fileFor = (id) => path.join(dir, `${id}.jsonl`);
    const events = buildEvents();
    await fs.writeFile(fileFor('a'), toJsonl(events.slice(0, 5)));
    await fs.writeFile(fileFor('b'), toJsonl(events.slice(0, 5)));
    const cache = new IndexCache(fileFor, { max: 1 });
    const first = cache.get('a');
    await first.refresh();
    const cursor = { epoch: first.epoch, version: first.version };

    await cache.get('b').refresh();
    assert.equal(cache.has('a'), false);
    await fs.appendFile(fileFor('a'), toJsonl(events.slice(5, 7)));
    const rebuilt = cache.get('a');
    await rebuilt.refresh();
    // The version matches the old cursor's, so only a new epoch tells the client to reload.
    assert.equal(rebuilt.version, cursor.version);
    assert.notEqual(rebuilt.epoch, cursor.epoch);
    assert.notEqual(new SessionIndex(fileFor('a')).epoch, rebuilt.epoch);
});

test('a same-size rewrite or a replaced log reindexes the session', async (t) => {
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ...Array.from({ length: 12 }, (_, i) => ev('user.message', { content: `message ${i === 6 ? 'alpha' : 'other'} ${String(i).padStart(2, '0')}` })),
    ]);
    const { file, index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const summaries = () => index.getEntries(ROOT_AGENT, { from: 0, limit: 50 }).entries.filter((entry) => entry.kind === 'user').map((entry) => entry.summary);
    assert.ok(summaries().includes('message alpha 06'));

    const original = await fs.readFile(file, 'utf8');
    const rewritten = original.replace('message alpha 06', 'message bravo 06');
    assert.equal(rewritten.length, original.length);
    assert.equal(rewritten.slice(0, 256), original.slice(0, 256), 'the head probe is unchanged');
    assert.equal(rewritten.slice(-256), original.slice(-256), 'the tail probe is unchanged');
    const epoch = index.epoch;
    await fs.writeFile(file, rewritten);
    const later = new Date(Date.now() + 5000);
    await fs.utimes(file, later, later);
    const result = await index.refresh();
    assert.equal(result.reset, true);
    assert.notEqual(index.epoch, epoch);
    assert.ok(summaries().includes('message bravo 06'));
    assert.equal(summaries().includes('message alpha 06'), false);

    // A replacement that starts and ends like an append is still a different file.
    const replacement = `${file}.next`;
    await fs.writeFile(replacement, rewritten + toJsonl(stream((ev) => [ev('user.message', { content: 'appended' })])));
    await fs.rename(replacement, file);
    assert.equal((await index.refresh()).reset, true);
    assert.ok(summaries().includes('appended'));
});

test('resuming a session clears its end time and shutdown totals but keeps the shutdown entry', async (t) => {
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ev('user.message', { content: 'first' }),
        ev('session.shutdown', { shutdownType: 'routine', totalPremiumRequests: 3 }),
        ev('session.resume', { resumeTime: '2026-02-01T10:00:00.000Z', eventCount: 3 }),
        ev('user.message', { content: 'again' }),
    ]);
    const { file, index } = await indexFor(t, toJsonl(events.slice(0, 3)));
    await index.refresh();
    const root = () => index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(index.getSummary().session.shutdown.totalPremiumRequests, 3);
    assert.ok(root().endTs);

    await fs.appendFile(file, toJsonl(events.slice(3)));
    await index.refresh();
    const summary = index.getSummary();
    assert.equal(summary.session.shutdown, null);
    assert.equal(summary.session.resumes, 1);
    assert.equal(root().endTs, null);
    assert.equal(root().durationMs, null);
    assert.ok(index.getEntries(ROOT_AGENT, { from: 0 }).entries.some((entry) => entry.label === 'Session ended'));
});

test('system prompt versions past the kept metadata still number and resolve correctly', async (t) => {
    const count = 502;
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ...Array.from({ length: count }, (_, i) => ev('system.message', { role: 'system', content: `<rules>\nVersion ${i + 1}\n</rules>` })),
    ]);
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const root = index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.systemPromptCount, count);
    assert.equal(root.systemPromptVersions.at(-1).version, count);
    assert.equal(root.systemPromptVersions.at(-1).seq, root.systemPrompt.seq);

    const latest = await index.getSystemPrompt(ROOT_AGENT);
    assert.equal(latest.seq, root.systemPrompt.seq);
    assert.equal(latest.version, count);
    assert.equal(latest.versionCount, count);
    assert.equal((await index.getSystemPrompt(ROOT_AGENT, root.systemPrompt.seq)).version, count);

    const firstSeq = index.getEntries(ROOT_AGENT, { from: 0, limit: 5 }).entries.find((entry) => entry.kind === 'system').seq;
    const first = await index.getSystemPrompt(ROOT_AGENT, firstSeq);
    assert.equal(first.version, 1);
    assert.equal(first.seq, firstSeq);
    assert.equal(await index.getSystemPrompt(ROOT_AGENT, 0), null);
});

test('skill deliveries belong to the agent that received them and match the load they wrap', async (t) => {
    const wrap = (name, marker) => ({ prefix: `<skill-context name="${name}">\n${marker}\n\n`, suffix: '\n</skill-context>' });
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ev('skill.invoked', { name: 'shared', path: '/skills/shared/SKILL.md', content: 'shared body', trigger: 'agent-invoked' }),
        ev('skill.context_delivered_ref', { contentId: contentId('shared body'), source: 'skill-shared', ...wrap('shared', 'ROOT') }),
        ev('subagent.started', { toolCallId: 'call-sub', agentName: 'helper', agentType: 'helper' }, { agentId: SUBAGENT_ID }),
        ev('skill.invoked_ref', { name: 'shared', path: '/skills/shared/SKILL.md', contentId: contentId('shared body'), contentLength: 11 }, { agentId: SUBAGENT_ID }),
        ev('skill.context_delivered_ref', { contentId: contentId('shared body'), source: 'skill-shared', ...wrap('shared', 'SUB') }, { agentId: SUBAGENT_ID }),
        ev('skill.invoked', { name: 'whole', path: '/skills/whole/SKILL.md', content: 'whole body' }),
        ev('skill.context_delivered', { source: 'skill-whole', content: '<skill-context name="whole">\nBase directory: /skills/whole\n\nwhole body\n</skill-context>' }),
        ev('skill.invoked', { name: 'changed', path: '/skills/changed/SKILL.md', content: 'changed v1' }),
        ev('skill.context_delivered_ref', { contentId: contentId('changed v1'), source: 'skill-changed', ...wrap('changed', 'V1') }),
        ev('skill.invoked', { name: 'changed', path: '/skills/changed/SKILL.md', content: 'changed v2' }),
    ]);
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const latest = async (agent, name) => (await index.getDefinition(agent, 'skill', name)).invocations.latest;

    const main = await latest(ROOT_AGENT, 'shared');
    assert.equal(main.content, '<skill-context name="shared">\nROOT\n\nshared body\n</skill-context>');
    const sub = await latest(SUBAGENT_ID, 'shared');
    assert.equal(sub.content, '<skill-context name="shared">\nSUB\n\nshared body\n</skill-context>');
    assert.equal(sub.resolvedFrom, 'earlier load');

    const whole = await latest(ROOT_AGENT, 'whole');
    assert.equal(whole.content, '<skill-context name="whole">\nBase directory: /skills/whole\n\nwhole body\n</skill-context>');
    assert.equal(whole.wrapped, true);

    // The only delivery wraps the first version, so the second load shows its own text unwrapped.
    const changed = await latest(ROOT_AGENT, 'changed');
    assert.equal(changed.content, 'changed v2');
    assert.equal(changed.wrapped, false);
});

test('compactions without an attempt ID pair with the running compaction', async (t) => {
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ev('session.compaction_start', { currentTokens: 9000, tokenLimit: 10000, trigger: 'threshold' }),
        ev('session.compaction_complete', { success: true, preCompactionTokens: 9000, postCompactionTokens: 2000 }),
        ev('session.compaction_start', { currentTokens: 9500, tokenLimit: 10000, trigger: 'threshold' }),
        ev('user.message', { content: 'while compacting' }),
        ev('session.compaction_complete', { success: true, preCompactionTokens: 9500, postCompactionTokens: 2500 }),
        ev('session.compaction_start', { compactionAttemptId: 'attempt-3', currentTokens: 9800, tokenLimit: 10000, trigger: 'threshold' }),
        ev('user.message', { content: 'still compacting' }),
        ev('session.compaction_complete', { success: true, preCompactionTokens: 9800, postCompactionTokens: 3000 }),
    ]);
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const compactions = index.getEntries(ROOT_AGENT, { from: 0 }).entries.filter((entry) => entry.kind === 'compaction');
    assert.deepEqual(compactions.map((entry) => [entry.phase, entry.status]), [
        ['single', 'succeeded'],
        ['start', 'succeeded'], ['result', 'succeeded'],
        ['start', 'succeeded'], ['result', 'succeeded'],
    ]);
    assert.deepEqual(compactions.map((entry) => entry.after), [2000, null, 2500, null, 3000]);
    const root = index.getSummary().agents.find((agent) => agent.key === ROOT_AGENT);
    assert.equal(root.activeCompaction, null);
    assert.equal(root.compactionTotal, 3);
});

test('agent definitions list the newest runs and the newest delivered prompt', async (t) => {
    const runs = 51;
    const runId = (i) => `aaaaaaaa-bbbb-4ccc-8ddd-${String(i).padStart(12, '0')}`;
    const events = stream((ev) => [
        ev('session.start', { sessionId: SESSION_ID }),
        ...Array.from({ length: runs }, (_, i) => [
            ev('subagent.started', { toolCallId: `call-${i}`, agentName: 'helper', agentDisplayName: 'helper', agentType: 'helper' }, { agentId: runId(i) }),
            ev('system.message', { role: 'system', content: `You are helper run ${i + 1}.` }, { agentId: runId(i) }),
        ]).flat(),
    ]);
    const { index } = await indexFor(t, toJsonl(events));
    await index.refresh();
    const def = await index.getDefinition(ROOT_AGENT, 'agent', 'helper');
    assert.equal(def.runs.length, 50);
    assert.equal(def.runTotal, runs);
    assert.equal(def.runs[0].key, runId(1));
    assert.equal(def.runs.at(-1).key, runId(runs - 1));
    assert.equal(def.delivered.agentKey, runId(runs - 1));
    assert.ok(def.delivered.text.includes(`run ${runs}.`));
});
