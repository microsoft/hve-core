// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { analyzeSystemPrompt, diffSections, HANDLED_EVENT_TYPES, IndexCache, messageText, parseFieldPath, plainSummary, ROOT_AGENT, SessionIndex, summarizeArguments } from '../lib/indexer.mjs';
import { buildCompactionEvents, buildEvents, COMPACTION_REQUEST, COMPACTION_SUMMARY, NESTED_ID, SESSION_ID, SUBAGENT_ID, toJsonl } from './fixtures.mjs';

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
    assert.deepEqual(root.tools.find((tool) => tool.name === 'bash'), { name: 'bash', count: 1, failed: 1 });
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
    assert.equal(index.epoch, epoch + 1);
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
    for (let start = 10; start < events.length; start += 7) {
        await fs.appendFile(file, toJsonl(events.slice(start, start + 7)));
        const result = await index.refresh();
        assert.equal(result.reset, false, `append at ${start}`);
    }
    assert.equal(index.getSummary().counts.events, events.length);
    assert.equal(index.epoch, 0);
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
    await fs.symlink(outside, path.join(root, SESSION_ID), 'dir');
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
