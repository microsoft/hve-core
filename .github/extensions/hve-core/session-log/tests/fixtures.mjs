// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

export const SESSION_ID = '11111111-2222-4333-8444-555555555555';
export const OTHER_SESSION_ID = '66666666-7777-4888-9999-aaaaaaaaaaaa';
export const SUBAGENT_ID = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff';
export const NESTED_ID = 'cccccccc-dddd-4eee-8fff-000000000000';

const SKILL_CONTENT_ID = `sha256:${createHash('sha256').update('skill body', 'utf8').digest('hex')}`;

const SYSTEM_PROMPT = [
    'You are a helpful coding assistant.',
    '<code_change_instructions>',
    'Make precise changes.',
    '</code_change_instructions>',
    '<available_skills>',
    '<skill>',
    '<name>demo-skill</name>',
    '<description>Demonstrates skill parsing &amp; listing.</description>',
    '<location>project</location>',
    '</skill>',
    '<skill>',
    '<name>second-skill</name>',
    '<description>Another skill.</description>',
    '<location>plugin</location>',
    '</skill>',
    '</available_skills>',
    'Additional skills available (invoke by name): extra-one, extra-two',
    '<custom_instruction>',
    '| Pattern | File Path | Description |',
    '| ------- | --------- | ----------- |',
    "| **/*.md | 'docs/markdown.instructions.md' | Markdown rules |",
    "| **/*.ts | 'docs/ts.instructions.md' | TypeScript rules |",
    '</custom_instruction>',
    '<agent_instructions>',
    '# Demo Agent',
    'Follow the demo flow.',
    '</agent_instructions>',
    '<environment_context>',
    'Working directory: /workspace/demo',
    '</environment_context>',
].join('\n');

/**
 * Builds a synthetic event stream covering every entry kind the canvas renders.
 *
 * @param {{ start?: number }} [options]
 * @returns {object[]} Events in file order.
 */
export function buildEvents(options = {}) {
    let clock = options.start ?? Date.parse('2026-01-15T10:00:00.000Z');
    let id = 0;
    const ts = (step = 1000) => {
        clock += step;
        return new Date(clock).toISOString();
    };
    const ev = (type, data, extra = {}) => ({ type, data, id: `e${(id += 1)}`, timestamp: ts(), parentId: null, ...extra });
    const sub = (type, data, agentId = SUBAGENT_ID) => ev(type, data, { agentId });

    return [
        ev('session.start', {
            sessionId: SESSION_ID,
            version: 1,
            producer: 'copilot-agent',
            copilotVersion: '9.9.9',
            selectedModel: 'demo-model',
            reasoningEffort: 'high',
            contextTier: 'standard',
            context: { cwd: '/workspace/demo', repository: 'octo/demo', branch: 'main', headCommit: 'abc123' },
        }),
        ev('subagent.selected', { agentName: 'demo-agent', agentDisplayName: 'Demo Agent', tools: ['view', 'bash'] }),
        ev('session.permissions_changed', { allowAllPermissions: true }),
        ev('hook.start', { hookInvocationId: 'h0', hookType: 'sessionStart', input: {} }),
        ev('hook.end', { hookInvocationId: 'h0', hookType: 'sessionStart', success: true }),
        ev('user.message', {
            content: '# Task\n\nPlease **review** the `README.md` and list issues:\n\n* first item\n* second item\n\nSee https://example.com/docs for context.',
            transformedContent: '<current_datetime>2026-01-15</current_datetime>\n# Task\n\nPlease **review** the `README.md`.',
            attachments: [{ type: 'file', path: '/workspace/demo/README.md', displayName: 'README.md' }],
            source: 'user',
            delivery: 'idle',
            messageId: 'm1',
        }),
        ev('system.message', {
            role: 'system',
            content: SYSTEM_PROMPT,
            contentBlocks: [{ content: SYSTEM_PROMPT.slice(0, 200), isStatic: true }, { content: SYSTEM_PROMPT.slice(200), isStatic: false }],
            metadata: { promptVersion: 'test-v1' },
        }),
        ev('skill.invoked', { name: 'demo-skill', source: 'plugin', pluginName: 'demo-plugin', trigger: 'user-invoked', content: 'skill body', path: '/plugins/demo/skills/demo-skill/SKILL.md', allowedTools: ['view'], invokedAtTurn: 0 }),
        ev('assistant.turn_start', { turnId: '0', interactionId: 'i1' }),
        ev('hook.start', { hookInvocationId: 'h1', hookType: 'preToolUse', input: {} }),
        ev('hook.end', { hookInvocationId: 'h1', hookType: 'preToolUse', success: false, error: { message: 'hook failed' } }),
        ev('session.usage_record', { usage: { model: 'demo-model', inputTokens: 12000, outputTokens: 800, cacheReadTokens: 100, cacheWriteTokens: 50, reasoningTokens: 200, maxPromptTokens: 100000, duration: 2500, cost: 1 } }),
        ev('assistant.message', {
            messageId: 'a1',
            model: 'demo-model',
            content: "I'll inspect the repository.\n\n| File | Status |\n|------|--------|\n| README.md | ok |\n\n```js\nconsole.log('hi');\n```",
            reasoningText: 'Thinking about **which files** to read first.',
            reasoningOpaque: 'OPAQUE-BLOB',
            toolRequests: [
                { toolCallId: 'call-view', name: 'view', arguments: { path: 'README.md' }, intentionSummary: 'view README.md' },
                { toolCallId: 'call-bash', name: 'bash', arguments: { command: 'ls -la' } },
                { toolCallId: 'call-task', name: 'task', arguments: { description: 'Research docs' } },
            ],
        }),
        ev('tool.execution_start', { toolCallId: 'call-view', toolName: 'view', arguments: { path: 'README.md' }, toolTitle: 'Viewing file' }),
        ev('tool.execution_complete', { toolCallId: 'call-view', success: true, result: { content: '# Demo\nHello', detailedContent: '1. # Demo\n2. Hello' }, toolTelemetry: { metrics: { context_current_tokens: 13000, context_token_limit: 100000 } } }),
        ev('tool.execution_start', { toolCallId: 'call-bash', toolName: 'bash', arguments: { command: 'ls -la' } }),
        ev('tool.execution_complete', { toolCallId: 'call-bash', success: false, error: { message: 'Permission denied', code: 'failure' } }),
        ev('tool.execution_start', { toolCallId: 'call-task', toolName: 'task', arguments: { description: 'Research docs', agent_type: 'researcher' } }),
        sub('subagent.started', { toolCallId: 'call-task', agentName: 'researcher', agentDisplayName: 'docs-lane', agentDescription: 'Finds docs', model: 'small-model', agentType: 'researcher', executionMode: 'background' }),
        sub('subagent.configured', { model: 'small-model', reasoningEffort: 'max', contextTier: 'standard' }),
        sub('subagent.selected', { agentName: 'researcher', agentDisplayName: 'docs-lane', tools: ['view'] }),
        sub('session.model_change', { source: 'agent', newModel: 'small-model', reasoningEffort: 'max', contextTier: 'standard' }),
        sub('user.message', { content: 'Find the docs for the demo project.', source: `agent-${SESSION_ID}`, parentAgentTaskId: 't1' }),
        sub('system.message', { role: 'system', content: 'You are a research helper.\n<rules>\nRead only.\n</rules>', contentBlocks: [] }),
        sub('assistant.turn_start', { turnId: '0' }),
        sub('session.usage_record', { usage: { model: 'small-model', inputTokens: 3000, outputTokens: 100, maxPromptTokens: 50000 } }),
        sub('assistant.message', { content: 'Looking for docs.', toolRequests: [{ toolCallId: 'call-sub-view', name: 'view' }, { toolCallId: 'call-nested', name: 'task' }] }),
        sub('tool.execution_start', { toolCallId: 'call-sub-view', toolName: 'view', arguments: { path: 'docs/index.md' }, parentToolCallId: 'call-task' }),
        sub('tool.execution_complete', { toolCallId: 'call-sub-view', success: true, result: { content: 'docs content' }, parentToolCallId: 'call-task' }),
        sub('tool.execution_start', { toolCallId: 'call-nested', toolName: 'task', arguments: { description: 'Nested lookup' } }),
        sub('subagent.started', { toolCallId: 'call-nested', agentName: 'explorer', agentDisplayName: 'nested-lane', model: 'tiny-model', agentType: 'explore' }, NESTED_ID),
        sub('assistant.message', { content: 'Nested result.' }, NESTED_ID),
        sub('subagent.completed', { toolCallId: 'call-nested', agentName: 'explorer', durationMs: 900, totalToolCalls: 0, totalTokens: 500 }, NESTED_ID),
        sub('tool.execution_complete', { toolCallId: 'call-nested', success: true, result: { content: 'nested done' } }),
        sub('assistant.turn_end', { turnId: '0' }),
        sub('subagent.completed', { toolCallId: 'call-task', agentName: 'researcher', model: 'small-model', durationMs: 4200, totalToolCalls: 2, totalTokens: 3100 }),
        ev('tool.execution_complete', { toolCallId: 'call-task', success: true, result: { content: 'Research summary: docs live in docs/.' } }),
        ev('system.notification', { content: '<system_notification>\nAgent "docs-lane" finished.\n</system_notification>', kind: { type: 'agent_idle', agentId: SUBAGENT_ID } }),
        ev('assistant.turn_end', { turnId: '0' }),
        ev('session.compaction_start', { compactionAttemptId: 'c1', currentTokens: 90000, tokenLimit: 100000, systemTokens: 5000, conversationTokens: 80000, toolDefinitionsTokens: 5000, trigger: 'threshold' }),
        ev('session.compaction_complete', { compactionAttemptId: 'c1', success: true, preCompactionTokens: 90000, postCompactionTokens: 20000, messagesRemoved: 40, summaryContent: 'Summary of earlier work.' }),
        ev('session.model_change', { source: 'user', newModel: 'demo-model-2', reasoningEffort: 'medium' }),
        ev('session.warning', { message: 'Rate limit approaching' }),
        ev('session.error', { message: 'Transient failure' }),
        ev('abort', { reason: 'user cancelled' }),
        ev('session.usage_checkpoint', { totalPremiumRequests: 3, promptCacheBreakState: [{ models: { 'demo-model': { tool_count: 40, tools_truncated: 37, tools: [{ name: 'bash', schema_hash: 'c0170aaae50c', safe: true }, { name: 'view' }, { name: 'grep' }] } } }] }),
        ev('model.messages_snapshot', { kind: 'messages_snapshot', messages: [] }),
        ev('custom.future_event', { anything: 1 }),
        ev('skill.invoked_ref', { name: 'demo-skill', source: 'plugin', pluginName: 'demo-plugin', trigger: 'agent-invoked', path: '/plugins/demo/skills/demo-skill/SKILL.md', allowedTools: [], invokedAtTurn: 1, contentId: SKILL_CONTENT_ID, contentLength: 10 }),
        ev('skill.context_delivered_ref', { source: 'skill-demo-skill', contentId: SKILL_CONTENT_ID, prefix: '<skill-context name="demo-skill">\nBase directory for this skill: /plugins/demo/skills/demo-skill\n\n', suffix: '\n</skill-context>' }),
        ev('assistant.turn_start', { turnId: '1' }),
        ev('tool.execution_start', { toolCallId: 'call-running', toolName: 'grep', arguments: { pattern: 'TODO' } }),
    ];
}

export const COMPACTION_SUMMARY = '<overview>\nRefactored module two.\n</overview>';
export const COMPACTION_REQUEST = 'Please create a detailed summary of the conversation so far.';

/**
 * Appends rebuilt system prompts and two compactions to the base stream: one that runs in the
 * background across a tool call, and one whose model call records its request snapshot next to
 * an unrelated classifier snapshot.
 *
 * @returns {object[]} Events in file order.
 */
export function buildCompactionEvents() {
    const events = buildEvents();
    const base = events.find((event) => event.type === 'system.message' && !event.agentId);
    let clock = Date.parse('2026-01-15T10:30:00.000Z');
    let id = 500;
    const ev = (type, data) => ({ type, data, id: `k${(id += 1)}`, timestamp: new Date((clock += 1000)).toISOString(), parentId: null });
    events.push(
        ev('session.resume', {}),
        ev('user.message', { content: 'Continue with module two.' }),
        ev('system.message', { role: 'system', content: `${base.data.content}\n<canvases>\nSession Log.\n</canvases>`, contentBlocks: [] }),
        ev('session.compaction_start', { compactionAttemptId: 'bg', model: 'demo-model-2', currentTokens: 95000, tokenLimit: 100000, systemTokens: 5000, conversationTokens: 85000, toolDefinitionsTokens: 5000, trigger: 'threshold' }),
        ev('tool.execution_start', { toolCallId: 'call-bg', toolName: 'view', arguments: { path: 'src/two.ts' } }),
        ev('tool.execution_complete', { toolCallId: 'call-bg', success: true, result: { content: 'two' } }),
        ev('session.compaction_complete', { compactionAttemptId: 'bg', success: true, preCompactionTokens: 90000, postCompactionTokens: 12000, messagesRemoved: 30, preCompactionMessagesLength: 34, summaryContent: 'Background summary.', compactionTokensUsed: { inputTokens: 88000, outputTokens: 900, duration: 15000, model: 'demo-model-2' }, checkpointNumber: 1, checkpointPath: '/workspace/.copilot/session-state/s/checkpoints/001-two.md' }),
        ev('session.compaction_start', { compactionAttemptId: 'late', model: 'demo-model-2', currentTokens: 60000, tokenLimit: 100000 }),
        ev('model.turn_started', { kind: 'turn_started', model: 'demo-model-2' }),
        ev('model.messages_snapshot', { kind: 'messages_snapshot', messages: [{ role: 'system', content: 'classifier' }, { role: 'user', content: 'Detect frustration' }, { role: 'assistant', content: '{}' }] }),
        ev('model.messages_snapshot', { kind: 'messages_snapshot', messages: [{ role: 'user', content: 'Continue.' }, { role: 'assistant', content: 'Done.' }, { role: 'user', content: [{ type: 'text', text: COMPACTION_REQUEST }] }, { role: 'assistant', content: COMPACTION_SUMMARY }] }),
        ev('session.compaction_complete', { compactionAttemptId: 'late', success: true, preCompactionTokens: 60000, postCompactionTokens: 8000, messagesRemoved: 20, summaryContent: COMPACTION_SUMMARY, checkpointNumber: 2 }),
        ev('user.message', { content: 'Now module three.' }),
        ev('system.message', { role: 'system', content: `${base.data.content}\n<canvases>\nSession Log canvas.\n</canvases>`, contentBlocks: [] }),
    );
    return events;
}

export const CANVAS_CAPABILITIES = {
    extensionId: 'project:demo-board',
    canvasId: 'demo-board',
    displayName: 'Demo Board',
    inputSchema: { type: 'object', properties: { boardId: { type: 'string', description: 'Board to show.' } }, additionalProperties: false },
    actions: [
        { name: 'add_card', description: 'Add a card to the board.', inputSchema: { type: 'object', properties: { title: { type: 'string' } }, required: ['title'] } },
        { name: 'clear', description: 'Remove every card.' },
    ],
};

export const AGENT_BODY = '# Reviewer\n\nReview the change for defects.';

/**
 * Builds a stream that exercises every Context inventory: a system prompt listing canvases and
 * selected-agent instructions, canvas tool calls and instance records, hook runs with a failing
 * plugin and injected context, an MCP tool call, instruction reads and discoveries, tool search,
 * and a subagent whose prompt opens with its agent definition.
 *
 * @returns {object[]} Events in file order.
 */
export function buildInventoryEvents() {
    let clock = Date.parse('2026-02-01T09:00:00.000Z');
    let id = 0;
    const ev = (type, data, extra = {}) => ({ type, data, id: `n${(id += 1)}`, timestamp: new Date((clock += 1000)).toISOString(), parentId: null, ...extra });
    const sub = (type, data) => ev(type, data, { agentId: SUBAGENT_ID });
    const prompt = [
        'You are a helpful coding assistant.',
        '<custom_instruction>',
        '| Pattern | File Path | Description |',
        '| ------- | --------- | ----------- |',
        "| **/*.md | '.github/instructions/markdown.instructions.md' | Markdown rules |",
        '</custom_instruction>',
        '<agent_instructions>',
        'The following instructions come from the selected agent\'s configuration.',
        '# Planner',
        'Plan before acting.',
        '</agent_instructions>',
        '<canvases>',
        'Canvas guidance.',
        'Available canvases:',
        '<canvas>',
        '  <id>demo-board</id>',
        '  <name>Demo Board</name>',
        '  <description>Cards &amp; lanes for planning.</description>',
        '</canvas>',
        '<canvas>',
        '  <id>notes</id>',
        '  <name>Notes</name>',
        '  <description>Scratch notes.</description>',
        '</canvas>',
        '</canvases>',
    ].join('\n');
    return [
        ev('session.start', { sessionId: SESSION_ID, version: 1, producer: 'copilot-agent', copilotVersion: '9.9.9', selectedModel: 'demo-model', context: { cwd: '/workspace/demo' } }),
        ev('subagent.selected', { agentName: 'planner', agentDisplayName: 'Planner', tools: null }),
        ev('hook.start', { hookInvocationId: 'p1', hookType: 'userPromptSubmitted', input: { prompt: 'hi' } }),
        ev('hook.end', { hookInvocationId: 'p1', hookType: 'userPromptSubmitted', success: true, output: { additionalContext: 'Remember the style guide.' } }),
        ev('user.message', { content: 'Plan the board.' }),
        ev('system.message', { role: 'system', content: prompt, contentBlocks: [] }),
        ev('assistant.turn_start', { turnId: '0' }),
        ev('tool.execution_start', { toolCallId: 'c-caps', toolName: 'list_canvas_capabilities', arguments: { canvasId: 'demo-board' } }),
        ev('tool.execution_complete', { toolCallId: 'c-caps', success: true, result: { content: JSON.stringify(CANVAS_CAPABILITIES, null, 2) } }),
        ev('tool.execution_start', { toolCallId: 'c-open', toolName: 'open_canvas', arguments: { canvasId: 'demo-board', instanceId: 'board-1', input: { boardId: 'b1' } } }),
        ev('tool.execution_complete', { toolCallId: 'c-open', success: true, result: { content: 'Opened' } }),
        ev('session.canvas.recorded', { instanceId: 'board-1', extensionId: 'project:demo-board', canvasId: 'demo-board', title: 'Demo Board', input: { boardId: 'b1' } }),
        ev('tool.execution_start', { toolCallId: 'c-act', toolName: 'invoke_canvas_action', arguments: { instanceId: 'board-1', actionName: 'add_card', input: { title: 'One' } } }),
        ev('tool.execution_complete', { toolCallId: 'c-act', success: true, result: { content: '{"ok":true}' } }),
        ev('tool.execution_start', { toolCallId: 'c-act2', toolName: 'invoke_canvas_action', arguments: { instanceId: 'board-1', actionName: 'add_card', input: { title: 'Two' } } }),
        ev('tool.execution_complete', { toolCallId: 'c-act2', success: false, error: { message: 'Board is full' } }),
        ev('hook.start', { hookInvocationId: 'q1', hookType: 'postToolUse', input: {} }),
        ev('hook.end', { hookInvocationId: 'q1', hookType: 'postToolUse', success: false, error: { message: 'Permission denied', source: 'lint-plugin' } }),
        ev('hook.start', { hookInvocationId: 'q2', hookType: 'postToolUse', input: {} }),
        ev('hook.end', { hookInvocationId: 'q2', hookType: 'postToolUse', success: true }),
        ev('tool.execution_start', { toolCallId: 'c-mcp', toolName: 'browser-navigate', mcpServerName: 'browser', mcpToolName: 'navigate', arguments: { url: 'https://example.com' } }),
        ev('tool.execution_complete', { toolCallId: 'c-mcp', success: true, result: { content: '{"title":"Example","status":200}' } }),
        ev('tool.execution_start', { toolCallId: 'c-read', toolName: 'view', arguments: { path: '/workspace/demo/.github/instructions/markdown.instructions.md' } }),
        ev('tool.execution_complete', { toolCallId: 'c-read', success: true, result: { content: '# Markdown rules' } }),
        ev('system.notification', { content: 'Discovered instructions', kind: { type: 'instruction_discovered', sourcePath: 'packages/api/AGENTS.md', triggerFile: 'packages/api/src/index.ts', triggerTool: 'view', description: 'AGENTS.md from packages/api/' } }),
        ev('tool_search.activated', { strategy: 'regex', toolNames: ['browser-navigate', 'browser-click'] }),
        ev('tool.execution_start', { toolCallId: 'c-task', toolName: 'task', arguments: { agent_type: 'reviewer', description: 'Review' } }),
        sub('subagent.started', { toolCallId: 'c-task', agentName: 'reviewer', agentDisplayName: 'Reviewer', agentDescription: 'Reviews changes', agentType: 'reviewer' }),
        sub('system.message', { role: 'system', content: `${AGENT_BODY}\n<tools>\nUse tools.\n</tools>`, contentBlocks: [] }),
        sub('subagent.completed', { toolCallId: 'c-task', agentName: 'reviewer', agentDisplayName: 'Reviewer', totalToolCalls: 0, durationMs: 1500 }),
        ev('tool.execution_complete', { toolCallId: 'c-task', success: true, result: { content: 'Reviewed' } }),
        ev('session.canvas.removed', { instanceId: 'board-1', extensionId: 'project:demo-board', canvasId: 'demo-board' }),
        ev('assistant.turn_end', { turnId: '0' }),
    ];
}

/**
 * Serializes events as JSON Lines.
 *
 * @param {object[]} events
 * @returns {string}
 */
export function toJsonl(events) {
    return events.map((event) => JSON.stringify(event)).join('\n') + '\n';
}

/**
 * Writes a synthetic session folder.
 *
 * @param {string} root Session-state root.
 * @param {string} sessionId
 * @param {{ events?: object[], yaml?: string, lockPid?: number }} [options]
 * @returns {Promise<string>} The session folder.
 */
export async function writeSession(root, sessionId, options = {}) {
    const folder = path.join(root, sessionId);
    await fs.mkdir(folder, { recursive: true });
    const events = options.events ?? buildEvents();
    await fs.writeFile(path.join(folder, 'events.jsonl'), toJsonl(events));
    const yaml = options.yaml ?? [
        `id: ${sessionId}`,
        'cwd: /workspace/demo',
        'repository: octo/demo',
        'branch: main',
        'client_name: vscode-agent-host',
        'name: |-',
        '  Review the demo README',
        '  and list issues',
        'created_at: 2026-01-15T10:00:00.000Z',
        'updated_at: 2026-01-15T10:05:00.000Z',
    ].join('\n');
    await fs.writeFile(path.join(folder, 'workspace.yaml'), yaml);
    if (options.lockPid) {
        await fs.writeFile(path.join(folder, `inuse.${options.lockPid}.lock`), String(options.lockPid));
    }
    return folder;
}
