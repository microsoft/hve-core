// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash, randomInt } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { performance } from 'node:perf_hooks';

export const ROOT_AGENT = 'root';

/** Epochs are unique across index instances and resets, so a cursor from an evicted or reset index never matches its replacement. */
let lastEpoch = randomInt(1, 2 ** 31);

function nextEpoch() {
    lastEpoch += 1;
    return lastEpoch;
}

/**
 * Event types the indexer reads, kept equal to the case labels in `SessionIndex#apply` by a test.
 * Any other type is counted as unknown and rendered generically.
 */
export const HANDLED_EVENT_TYPES = Object.freeze([
    'session.start', 'session.resume', 'session.shutdown', 'session.permissions_changed', 'system.message', 'user.message',
    'assistant.turn_start', 'assistant.turn_end', 'session.usage_record', 'assistant.message', 'tool.execution_start',
    'tool.execution_complete', 'external_tool.requested', 'external_tool.completed', 'subagent.started', 'subagent.configured',
    'subagent.selected', 'subagent.deselected', 'subagent.completed', 'subagent.failed', 'session.model_change', 'skill.invoked',
    'skill.invoked_ref', 'skill.context_delivered', 'skill.context_delivered_ref', 'session.compaction_start',
    'session.compaction_complete', 'system.notification', 'permission.requested', 'permission.completed', 'session.info',
    'session.warning', 'session.error', 'abort', 'hook.start', 'hook.end', 'session.usage_checkpoint', 'session.binary_asset',
    'session.workspace_file_changed', 'session.canvas.recorded', 'session.canvas.removed', 'tool_search.activated',
]);

/** Event type prefixes the indexer counts as model debug events; compactions also read `model.messages_snapshot`. */
export const HANDLED_EVENT_PREFIXES = Object.freeze(['model.']);

const DEFAULTS = Object.freeze({
    chunkSize: 1 << 20,
    maxLineBytes: 8 << 20,
    summaryMax: 240,
    pageChars: 128 * 1024,
    bodyChars: 8 * 1024,
    previewChars: 4 * 1024,
    maxHookRuns: 200,
    maxUpdates: 5000,
});

const DROPPED_DETAIL_KEYS = new Set(['reasoningOpaque', 'reasoningBlocks', 'signature', 'encryptedContent']);
const ARG_SUMMARY_KEYS = ['command', 'path', 'pattern', 'query', 'url', 'prompt', 'description', 'title', 'name', 'file_path', 'filePath', 'skill'];
const FIELD_SEGMENT_RE = /^[A-Za-z0-9_$-]{1,64}$/;
const HEAD_BYTES = 256;
const PRE_TURN_HOOKS = new Set(['sessionStart', 'userPromptSubmitted', 'userPromptTransformed']);
const SECTION_DIFF_MAX = 8;
const MAX_PROMPT_VERSIONS = 500;
const MAX_SNAPSHOT_CANDIDATES = 8;
const MAX_TOOL_HASHES = 2000;
const MAX_AGENT_RUNS = 50;
const MAX_SKILL_REFS = 500;
const MAX_COMPACTION_RECORDS = 200;
const MAX_PROMPT_CANVASES = 200;
const MAX_CANVASES = 200;
const MAX_CANVAS_INSTANCES = 500;
const MAX_PENDING_CANVAS_CALLS = 500;
const MAX_FILE_READS = 2000;
const MAX_DISCOVERED_INSTRUCTIONS = 200;
const MAX_MCP_TOOLS = 2000;
const MAX_ACTIVATED_TOOLS = 2000;
const MAX_SELECTIONS = 200;
const MAX_HOOK_SOURCES = 50;
/** Tools that take or return canvas identities. */
const CANVAS_TOOLS = new Set(['open_canvas', 'invoke_canvas_action', 'list_canvas_capabilities']);
/** Tools whose `path` argument reads a file into context, used to count instruction reads. */
const READ_TOOLS = new Set(['view', 'read_file']);
/** Caps for definition text re-read from the log. */
const DEFINITION_TEXT_MAX = 200 * 1024;
const PROMPT_ENTRY_MAX = 16 * 1024;
const CALL_TEXT_MAX = 32 * 1024;
/** Agent descriptions are kept whole up to this length; longer ones end with an ellipsis. */
const DESCRIPTION_MAX = 2000;

/**
 * @param {unknown} input Hook input.
 * @returns {string | null} The tool or tools a hook ran for, when recorded.
 */
function hookToolName(input) {
    if (!input || typeof input !== 'object') {
        return null;
    }
    const value = /** @type {Record<string, unknown>} */ (input);
    if (typeof value.toolName === 'string') {
        return oneLine(typeof value.serverName === 'string' ? `${value.serverName}/${value.toolName}` : value.toolName, 120);
    }
    if (Array.isArray(value.toolCalls)) {
        const names = value.toolCalls.slice(0, 4).map((call) => (call && typeof call === 'object' ? call.toolName ?? call.name : null)).filter((name) => typeof name === 'string');
        if (names.length > 0) {
            return oneLine(names.join(', ') + (value.toolCalls.length > 4 ? ', …' : ''), 120);
        }
    }
    return null;
}

/**
 * Collapses whitespace and caps text for one-line summaries.
 *
 * @param {unknown} value
 * @param {number} max
 * @returns {string}
 */
export function oneLine(value, max = DEFAULTS.summaryMax) {
    if (typeof value !== 'string') {
        return '';
    }
    const text = value.replace(/\s+/g, ' ').trim();
    return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/**
 * Produces a one-line summary from Markdown, dropping heading, emphasis, code, and list markers.
 *
 * @param {unknown} value
 * @param {number} max
 * @returns {string}
 */
export function plainSummary(value, max = DEFAULTS.summaryMax) {
    if (typeof value !== 'string') {
        return '';
    }
    const text = value
        .slice(0, max * 4)
        .replace(/```[\s\S]*?(```|$)/g, ' ')
        .replace(/^\s{0,3}(#{1,6}|>|[*+-]|\d{1,9}[.)])\s+/gm, '')
        .replace(/(\*\*|__|~~|`)/g, '')
        .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');
    return oneLine(text, max);
}

/**
 * Summarizes tool arguments with the most descriptive scalar field.
 *
 * @param {unknown} args
 * @returns {string}
 */
export function summarizeArguments(args) {
    if (typeof args === 'string') {
        return oneLine(args, 160);
    }
    if (!args || typeof args !== 'object') {
        return '';
    }
    for (const key of ARG_SUMMARY_KEYS) {
        const value = /** @type {Record<string, unknown>} */ (args)[key];
        if (typeof value === 'string' && value.trim().length > 0) {
            return oneLine(value, 160);
        }
    }
    for (const value of Object.values(args)) {
        if (typeof value === 'string' && value.trim().length > 0) {
            return oneLine(value, 160);
        }
    }
    return '';
}

const ENTITY_MAP = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };

function decodeEntities(text) {
    return text.replace(/&(amp|lt|gt|quot|apos);/g, (_, name) => ENTITY_MAP[name]);
}

/**
 * Extracts navigable structure from a system prompt without retaining its text.
 *
 * @param {string} content System prompt text.
 * @param {Array<{ content?: string, isStatic?: boolean }>} [blocks] Prompt content blocks.
 */
export function analyzeSystemPrompt(content, blocks) {
    const text = typeof content === 'string' ? content : '';
    const sections = [];
    const openRe = /^<([a-z][a-z0-9_-]*)>/gm;
    let cursor = 0;
    let looseChars = 0;
    let match;
    while ((match = openRe.exec(text)) !== null) {
        if (match.index < cursor) {
            continue;
        }
        const name = match[1];
        const closeTag = `</${name}>`;
        const closeAt = text.indexOf(closeTag, match.index + match[0].length);
        looseChars += text.slice(cursor, match.index).trim().length;
        if (closeAt < 0) {
            sections.push({ name, chars: text.length - match.index, start: match.index });
            cursor = text.length;
            break;
        }
        const end = closeAt + closeTag.length;
        sections.push({ name, chars: end - match.index, start: match.index });
        cursor = end;
        openRe.lastIndex = end;
    }
    looseChars += text.slice(cursor).trim().length;
    if (looseChars > 0) {
        sections.unshift({ name: '(untagged text)', chars: looseChars });
    }

    const skills = [];
    const skillRe = /<skill>\s*<name>([^<]{1,200})<\/name>\s*<description>([\s\S]*?)<\/description>/g;
    while ((match = skillRe.exec(text)) !== null) {
        skills.push({ name: decodeEntities(match[1].trim()), description: oneLine(decodeEntities(match[2]), 200) });
    }
    const extra = /Additional skills available \(invoke by name\):\s*([^\n]+)/.exec(text);
    if (extra) {
        for (const name of extra[1].split(',')) {
            const trimmed = name.trim();
            if (trimmed && !skills.some((skill) => skill.name === trimmed)) {
                skills.push({ name: trimmed, description: '' });
            }
        }
    }

    const instructions = [];
    const seenPaths = new Set();
    const rowRe = /^\| (.+?) \| '(.+?)' \| (.*?) \|\s*$/gm;
    while ((match = rowRe.exec(text)) !== null) {
        const instructionPath = match[2].trim();
        if (seenPaths.has(instructionPath)) {
            continue;
        }
        seenPaths.add(instructionPath);
        instructions.push({ applyTo: oneLine(match[1], 200), path: instructionPath, description: oneLine(match[3], 200) });
    }

    const canvases = [];
    const canvasRe = /<canvas>([\s\S]{0,4000}?)<\/canvas>/g;
    while ((match = canvasRe.exec(text)) !== null && canvases.length < MAX_PROMPT_CANVASES) {
        const id = /<id>([^<]{1,200})<\/id>/.exec(match[1]);
        if (!id) {
            continue;
        }
        const name = /<name>([^<]{0,200})<\/name>/.exec(match[1]);
        const description = /<description>([\s\S]*?)<\/description>/.exec(match[1]);
        canvases.push({
            id: decodeEntities(id[1].trim()),
            name: name ? decodeEntities(name[1].trim()) : '',
            description: description ? oneLine(decodeEntities(description[1]), 300) : '',
        });
    }

    let agentInstructions = null;
    const agentStart = text.indexOf('<agent_instructions>');
    if (agentStart >= 0) {
        const heading = /^#\s+(.+)$/m.exec(text.slice(agentStart, agentStart + 4000));
        agentInstructions = { title: heading ? oneLine(heading[1], 120) : null };
    }

    let staticChars = 0;
    let blockCount = 0;
    if (Array.isArray(blocks)) {
        for (const block of blocks) {
            blockCount += 1;
            if (block && block.isStatic === true && typeof block.content === 'string') {
                staticChars += block.content.length;
            }
        }
    }

    return {
        chars: text.length,
        sections,
        skills,
        instructions,
        canvases,
        agentInstructions,
        staticChars,
        blockCount,
    };
}

/**
 * Finds the exact text that lists a skill in a system prompt: its `<skill>` XML entry, or the
 * "Additional skills available" line for skills listed by name only.
 *
 * @param {string} text System prompt text.
 * @param {string} name Skill name.
 * @returns {{ form: 'xml' | 'listed', text: string } | null}
 */
export function skillPromptEntry(text, name) {
    const blockRe = /<skill>\s*<name>([^<]{1,200})<\/name>[\s\S]*?<\/skill>/g;
    let match;
    while ((match = blockRe.exec(text)) !== null) {
        if (decodeEntities(match[1].trim()) === name) {
            return { form: 'xml', text: match[0].slice(0, PROMPT_ENTRY_MAX) };
        }
    }
    const extra = /Additional skills available \(invoke by name\):\s*([^\n]+)/.exec(text);
    if (extra && extra[1].split(',').some((item) => item.trim() === name)) {
        return { form: 'listed', text: extra[0].slice(0, PROMPT_ENTRY_MAX) };
    }
    return null;
}

/**
 * Finds the instruction table row for a file path in a system prompt, with the table header.
 * Paths match exactly or by a trailing path segment, because hosts list some paths relative to
 * the repository and others as absolute paths.
 *
 * @param {string} text System prompt text.
 * @param {string} instructionPath
 * @returns {{ form: 'row', text: string, applyTo: string, description: string } | null}
 */
export function instructionPromptEntry(text, instructionPath) {
    const target = instructionPath.trim();
    if (!target) {
        return null;
    }
    const rowRe = /^\| (.+?) \| '(.+?)' \| (.*?) \|\s*$/gm;
    let match;
    while ((match = rowRe.exec(text)) !== null) {
        const rowPath = match[2].trim();
        if (rowPath !== target && !rowPath.endsWith(`/${target}`) && !target.endsWith(`/${rowPath}`)) {
            continue;
        }
        const headerAt = text.lastIndexOf('\n| Pattern |', match.index);
        const header = headerAt >= 0 ? text.slice(headerAt + 1).split('\n', 2).join('\n') : '';
        const row = match[0].trim();
        return {
            form: 'row',
            text: `${header && header !== row ? `${header}\n` : ''}${row}`.slice(0, PROMPT_ENTRY_MAX),
            applyTo: oneLine(match[1], 400),
            description: oneLine(match[3], 1000),
        };
    }
    return null;
}

/**
 * Finds the `<canvas>` entry that lists a canvas in a system prompt.
 *
 * @param {string} text System prompt text.
 * @param {string} canvasId
 * @returns {{ form: 'xml', text: string } | null}
 */
export function canvasPromptEntry(text, canvasId) {
    const blockRe = /<canvas>[\s\S]{0,4000}?<\/canvas>/g;
    let match;
    while ((match = blockRe.exec(text)) !== null) {
        const id = /<id>([^<]{1,200})<\/id>/.exec(match[0]);
        if (id && decodeEntities(id[1].trim()) === canvasId) {
            return { form: 'xml', text: match[0].slice(0, PROMPT_ENTRY_MAX) };
        }
    }
    return null;
}

/**
 * Returns the instructions a selected custom agent contributes to the main system prompt: the
 * `<agent_instructions>` block, tags included.
 *
 * @param {string} text System prompt text.
 * @param {number} [max]
 * @returns {{ text: string, chars: number, truncated: boolean } | null}
 */
export function agentInstructionsBlock(text, max = DEFINITION_TEXT_MAX) {
    const start = text.indexOf('<agent_instructions>');
    if (start < 0) {
        return null;
    }
    const close = text.indexOf('</agent_instructions>', start);
    const end = close < 0 ? text.length : close + '</agent_instructions>'.length;
    const block = text.slice(start, end);
    return { text: block.slice(0, max), chars: block.length, truncated: block.length > max };
}

/**
 * Returns the text before a system prompt's first top-level section tag. A subagent's prompt
 * opens with its agent definition there.
 *
 * @param {string} text System prompt text.
 * @param {number} [max]
 * @returns {{ text: string, chars: number, truncated: boolean } | null}
 */
export function leadingPromptText(text, max = DEFINITION_TEXT_MAX) {
    // Same rule as the section parser: a section starts at a line-leading tag that is closed later.
    const openRe = /^<([a-z][a-z0-9_-]*)>/gm;
    let end = text.length;
    let match;
    while ((match = openRe.exec(text)) !== null) {
        if (text.indexOf(`</${match[1]}>`, match.index + match[0].length) >= 0) {
            end = match.index;
            break;
        }
    }
    const lead = text.slice(0, end).trim();
    if (!lead) {
        return null;
    }
    return { text: lead.slice(0, max), chars: lead.length, truncated: lead.length > max };
}

/**
 * Normalizes an agent name, ID, display name, or type for matching: drops a `plugin:` prefix,
 * case, and punctuation, so `hve-core:rpi-plan-critic` matches `RPI Plan Critic`.
 *
 * @param {unknown} value
 * @returns {string}
 */
export function agentNameKey(value) {
    if (typeof value !== 'string') {
        return '';
    }
    return value.slice(value.lastIndexOf(':') + 1).toLowerCase().replace(/[^a-z0-9]/g, '');
}

/**
 * Compares two section lists by name and occurrence.
 *
 * @param {Array<{ name: string, chars: number }>} before
 * @param {Array<{ name: string, chars: number }>} after
 * @returns {{ added: string[], removed: string[], resized: Array<{ name: string, delta: number }>, addedCount: number, removedCount: number, resizedCount: number }}
 */
export function diffSections(before, after) {
    const keyed = (list) => {
        const seen = new Map();
        const out = new Map();
        for (const section of list) {
            const n = seen.get(section.name) ?? 0;
            seen.set(section.name, n + 1);
            out.set(`${section.name}#${n}`, section);
        }
        return out;
    };
    const a = keyed(before);
    const b = keyed(after);
    const added = [];
    const removed = [];
    const resized = [];
    for (const [key, section] of b) {
        const old = a.get(key);
        if (!old) {
            added.push(section.name);
        } else if (old.chars !== section.chars) {
            resized.push({ name: section.name, delta: section.chars - old.chars });
        }
    }
    for (const [key, section] of a) {
        if (!b.has(key)) {
            removed.push(section.name);
        }
    }
    resized.sort((x, y) => Math.abs(y.delta) - Math.abs(x.delta));
    return {
        added: added.slice(0, SECTION_DIFF_MAX),
        removed: removed.slice(0, SECTION_DIFF_MAX),
        resized: resized.slice(0, SECTION_DIFF_MAX),
        addedCount: added.length,
        removedCount: removed.length,
        resizedCount: resized.length,
    };
}

/**
 * @param {unknown} text Skill context text or its prefix.
 * @returns {string | null} The skill name from a leading `<skill-context name="...">` tag.
 */
function skillContextName(text) {
    return typeof text === 'string' ? /<skill-context name="([^"]{1,200})"/.exec(text.slice(0, 1024))?.[1] ?? null : null;
}

function newAgent(key) {
    return {
        key,
        agentId: key === ROOT_AGENT ? null : key,
        parentKey: null,
        spawnToolCallId: null,
        name: key === ROOT_AGENT ? 'Main agent' : 'Subagent',
        displayName: null,
        description: null,
        agentType: null,
        executionMode: null,
        model: null,
        reasoningEffort: null,
        contextTier: null,
        models: [],
        status: key === ROOT_AGENT ? null : 'running',
        startTs: null,
        endTs: null,
        durationMs: null,
        totalToolCalls: null,
        totalTokens: null,
        error: null,
        customAgent: null,
        systemPrompt: null,
        /** The newest recorded system prompt versions, oldest first. */
        systemPrompts: [],
        /** Every system prompt version recorded, including any no longer kept in `systemPrompts`. */
        systemPromptTotal: 0,
        /** Events seen since the latest system prompt, which explain why the next one was rebuilt. */
        sinceSystem: new Set(),
        /** The compaction in progress, with snapshot candidates for its model call. */
        activeCompaction: null,
        usage: { requests: 0, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0, reasoningTokens: 0, durationMs: 0, cost: 0 },
        context: { current: null, limit: null, peak: null, source: null },
        compactions: [],
        compactionTotal: 0,
        toolCounts: new Map(),
        skillsInvoked: new Map(),
        hooks: { count: 0, failed: 0 },
        /** Hook runs grouped by hook type, with failures by owning plugin and injected context. */
        hookTypes: new Map(),
        /** Files read into context by path, to count instruction reads. */
        fileReads: new Map(),
        /** Instruction files the runtime discovered while the agent worked. */
        discoveredInstructions: new Map(),
        /** MCP server name per tool name, from call attribution. */
        mcpTools: new Map(),
        /** Deferred tools that tool search loaded. */
        activatedTools: new Set(),
        /** Main-agent selections by agent name (main agent only). */
        selections: new Map(),
        /** The latest system prompt carrying each selected custom agent's instructions, by agent name. */
        agentPromptSeqs: new Map(),
        counts: { user: 0, assistant: 0, turns: 0, tools: 0 },
        children: [],
        entries: [],
        interactions: [],
        currentTurn: null,
        turnsById: new Map(),
        /** Hook runs waiting for the next turn, such as prompt hooks. */
        pendingHooks: [],
    };
}

/**
 * Incrementally indexes one session's `events.jsonl`.
 *
 * The index keeps compact per-agent entries with byte offsets and never holds
 * full message, prompt, argument, or result text; details are re-read on demand.
 */
export class SessionIndex {
    /**
     * @param {string} file Absolute path to `events.jsonl`.
     * @param {Partial<typeof DEFAULTS>} [options]
     */
    constructor(file, options = {}) {
        this.file = file;
        this.options = { ...DEFAULTS, ...options };
        this.#reset();
        this.epoch = nextEpoch();
        /** @type {Promise<object> | null} */
        this.refreshing = null;
    }

    /**
     * Stats the log without following a symlinked session folder or file.
     *
     * @returns {Promise<import('node:fs').Stats>}
     */
    async #statFile() {
        const folder = await fs.lstat(path.dirname(this.file));
        const stat = await fs.lstat(this.file);
        if (!folder.isDirectory() || !stat.isFile()) {
            throw Object.assign(new Error('Session log is not a regular file'), { code: 'ENOENT' });
        }
        return stat;
    }

    async #openFile() {
        await this.#statFile();
        return fs.open(this.file, 'r');
    }

    /**
     * Places a hook run on the current turn, or holds prompt and pre-turn hooks for the next turn.
     */
    #placeHookRun(agentKey, agent, run) {
        if (run.id) {
            this.hookRunsById.set(run.id, run);
        }
        const turn = PRE_TURN_HOOKS.has(run.type) ? null : agent.currentTurn;
        if (turn) {
            this.#attachHookRun(agentKey, turn, run);
        } else if (agent.pendingHooks.length < this.options.maxHookRuns) {
            agent.pendingHooks.push(run);
        }
    }

    #attachHookRun(agentKey, turn, run) {
        turn.hooks += 1;
        const bucket = turn.hookTypes[run.type] ?? { count: 0, failed: 0 };
        bucket.count += 1;
        if (run.status === 'failed') {
            bucket.failed += 1;
            turn.hooksFailed += 1;
        }
        turn.hookTypes[run.type] = bucket;
        if (turn.hookRuns.length < this.options.maxHookRuns) {
            turn.hookRuns.push(run);
            this.hookTurns.set(run, turn);
        } else {
            turn.hookRunsDropped += 1;
        }
        this.#touch(agentKey, turn);
    }

    #reset() {
        this.fileSize = -1;
        this.mtimeMs = -1;
        /** File identity, so a replaced or rotated log is reindexed. */
        this.ino = null;
        this.dev = null;
        this.readPos = 0;
        this.lineStart = 0;
        /** @type {Buffer[]} */
        this.partial = [];
        this.partialBytes = 0;
        this.discarding = false;
        this.head = null;
        this.tail = null;
        this.seq = 0;
        this.version = 0;
        this.inventoryVersion = 0;
        /** @type {Map<string, ReturnType<typeof newAgent>>} */
        this.agents = new Map([[ROOT_AGENT, newAgent(ROOT_AGENT)]]);
        /** @type {Map<string, { agent: string, index: number }>} */
        this.tools = new Map();
        this.intents = new Map();
        this.pendingSpawn = new Map();
        /** @type {Map<string, object>} */
        this.hookRunsById = new Map();
        this.hookTurns = new WeakMap();
        this.externalRequests = new Map();
        this.permissions = new Map();
        this.compactionsById = new Map();
        /** Skill text by content ID, so repeat loads recorded as references resolve to the full text. */
        this.skillContents = new Map();
        /** The latest skill context delivery per receiving agent and skill name. */
        this.skillDeliveries = new Map();
        /** Reference deliveries per receiving agent and content ID, to pair each with the load it wraps. */
        this.skillDeliveriesByContent = new Map();
        /** @type {Map<string, [number, number]>} Byte range of each compaction's request snapshot, keyed by `agent:seq`. */
        this.compactionRequests = new Map();
        /** Canvas activity by canvas ID, across agents. */
        this.canvases = new Map();
        /** Canvas instances by instance ID. */
        this.canvasInstances = new Map();
        /** Canvas tool calls awaiting completion, by tool call ID. */
        this.canvasCalls = new Map();
        this.updates = [];
        this.updatesFloor = 0;
        this.session = {
            start: null,
            resumes: 0,
            shutdown: null,
            checkpoint: null,
            permissionsChanged: 0,
        };
        this.counts = { events: 0, malformed: 0, debugEvents: 0, binaryAssets: 0, contextRefs: 0, workspaceFileChanges: 0 };
        this.unknownTypes = new Map();
        this.dirtyVersion = 0;
    }

    /**
     * Reads any appended complete lines and updates the index.
     *
     * @returns {Promise<{ bytesRead: number, indexMs: number, changed: boolean, reset: boolean, missing?: boolean }>}
     */
    refresh() {
        if (!this.refreshing) {
            this.refreshing = this.#refresh().finally(() => {
                this.refreshing = null;
            });
        }
        return this.refreshing;
    }

    async #refresh() {
        const started = performance.now();
        let bytesRead = 0;
        let reset = false;
        let stat;
        try {
            stat = await this.#statFile();
        } catch (error) {
            if (!isMissing(error)) {
                throw error;
            }
            const hadData = this.fileSize > 0;
            if (hadData) {
                this.#reset();
                this.epoch = nextEpoch();
            }
            return { bytesRead, indexMs: performance.now() - started, changed: hadData, reset: hadData, missing: true };
        }
        const replaced = this.fileSize >= 0 && (stat.ino !== this.ino || stat.dev !== this.dev);
        if (!replaced && stat.size === this.fileSize && stat.mtimeMs === this.mtimeMs) {
            return { bytesRead, indexMs: performance.now() - started, changed: false, reset: false };
        }
        const handle = await this.#openFile();
        try {
            // Logs only grow by appending: a replaced file, a shorter one, or one changed without growing is reindexed.
            if (replaced || stat.size < this.readPos || stat.size === this.fileSize) {
                reset = true;
            } else if (this.head && stat.size > 0) {
                const probe = Buffer.alloc(Math.min(HEAD_BYTES, stat.size));
                const { bytesRead: n } = await handle.read(probe, 0, probe.length, 0);
                bytesRead += n;
                const compared = Math.min(n, this.head.length);
                if (!probe.subarray(0, compared).equals(this.head.subarray(0, compared))) {
                    reset = true;
                }
                if (!reset && this.tail && this.tail.length > 0) {
                    const tailProbe = Buffer.alloc(this.tail.length);
                    const { bytesRead: m } = await handle.read(tailProbe, 0, tailProbe.length, this.readPos - this.tail.length);
                    bytesRead += m;
                    if (m !== this.tail.length || !tailProbe.equals(this.tail)) {
                        reset = true;
                    }
                }
            }
            if (reset) {
                this.#reset();
                this.epoch = nextEpoch();
            }
            const before = this.version;
            this.version += 1;
            const versionForThisRefresh = this.version;
            const buffer = Buffer.allocUnsafe(this.options.chunkSize);
            let position = this.readPos;
            let rolling = this.tail ?? Buffer.alloc(0);
            try {
                while (position < stat.size) {
                    const length = Math.min(buffer.length, stat.size - position);
                    const { bytesRead: n } = await handle.read(buffer, 0, length, position);
                    if (n <= 0) {
                        break;
                    }
                    bytesRead += n;
                    if (!this.head && position === 0) {
                        this.head = Buffer.from(buffer.subarray(0, Math.min(HEAD_BYTES, n)));
                    }
                    this.#consume(buffer.subarray(0, n), position);
                    const recent = Buffer.concat([rolling, buffer.subarray(Math.max(0, n - HEAD_BYTES), n)]);
                    rolling = recent.subarray(Math.max(0, recent.length - HEAD_BYTES));
                    position += n;
                }
            } catch (error) {
                // Entries from this read are already applied; start over rather than re-ingest them.
                this.#reset();
                this.epoch = nextEpoch();
                throw error;
            }
            this.tail = Buffer.from(rolling);
            this.readPos = position;
            this.fileSize = stat.size;
            this.mtimeMs = stat.mtimeMs;
            this.ino = stat.ino;
            this.dev = stat.dev;
            const changed = this.dirtyVersion === versionForThisRefresh || reset;
            if (!changed) {
                this.version = before;
            }
            return { bytesRead, indexMs: performance.now() - started, changed, reset };
        } finally {
            await handle.close();
        }
    }

    #consume(chunk, chunkOffset) {
        let start = 0;
        while (start < chunk.length) {
            const newline = chunk.indexOf(0x0a, start);
            if (newline < 0) {
                const rest = chunk.subarray(start);
                if (!this.discarding) {
                    if (this.partialBytes + rest.length > this.options.maxLineBytes) {
                        this.partial = [];
                        this.partialBytes = 0;
                        this.discarding = true;
                        this.counts.malformed += 1;
                    } else {
                        this.partial.push(Buffer.from(rest));
                        this.partialBytes += rest.length;
                    }
                }
                return;
            }
            const piece = chunk.subarray(start, newline);
            const lineOffset = this.lineStart;
            let line;
            if (this.discarding) {
                this.discarding = false;
                line = null;
            } else if (this.partialBytes > 0) {
                line = Buffer.concat([...this.partial, piece]);
                this.partial = [];
                this.partialBytes = 0;
            } else {
                line = piece;
            }
            const nextLineStart = chunkOffset + newline + 1;
            if (line && line.length > 0) {
                const length = line[line.length - 1] === 0x0d ? line.length - 1 : line.length;
                this.#ingest(line.subarray(0, length), lineOffset, length);
            }
            this.lineStart = nextLineStart;
            start = newline + 1;
        }
    }

    #ingest(lineBuffer, offset, length) {
        let event;
        try {
            event = JSON.parse(lineBuffer.toString('utf8'));
        } catch {
            this.counts.malformed += 1;
            return;
        }
        if (!event || typeof event !== 'object' || typeof event.type !== 'string') {
            this.counts.malformed += 1;
            return;
        }
        this.counts.events += 1;
        this.dirtyVersion = this.version;
        const seq = this.seq;
        this.seq += 1;
        try {
            this.#apply(event, seq, offset, length);
        } catch {
            this.counts.malformed += 1;
        }
    }

    #agent(key) {
        let agent = this.agents.get(key);
        if (!agent) {
            agent = newAgent(key);
            this.agents.set(key, agent);
        }
        return agent;
    }

    /** Sets a bounded map entry: existing keys always update, new keys only below the cap. */
    #remember(map, key, value) {
        if (map.has(key) || map.size < MAX_SKILL_REFS) {
            map.set(key, value);
        }
    }

    #add(agent, kind, event, seq, offset, length, fields = {}) {
        const entry = {
            seq,
            index: agent.entries.length,
            kind,
            ts: typeof event.timestamp === 'string' ? event.timestamp : null,
            v: this.version,
            parts: offset >= 0 ? [[offset, length]] : [],
            ...fields,
        };
        agent.entries.push(entry);
        return entry;
    }

    #touch(agentKey, entry) {
        if (entry.v === this.version) {
            return;
        }
        entry.v = this.version;
        this.updates.push({ agent: agentKey, index: entry.index, v: this.version });
        if (this.updates.length > this.options.maxUpdates) {
            const dropped = this.updates.splice(0, this.updates.length - this.options.maxUpdates);
            this.updatesFloor = dropped[dropped.length - 1].v;
        }
    }

    #apply(event, seq, offset, length) {
        const data = event.data && typeof event.data === 'object' ? event.data : {};
        const agentKey = typeof event.agentId === 'string' && event.agentId.length > 0 ? event.agentId : ROOT_AGENT;
        const agent = this.#agent(agentKey);
        const ts = typeof event.timestamp === 'string' ? event.timestamp : null;
        if (!agent.startTs && ts) {
            agent.startTs = ts;
        }

        switch (event.type) {
            case 'session.start': {
                const context = data.context && typeof data.context === 'object' ? data.context : {};
                this.session.start = {
                    sessionId: data.sessionId ?? null,
                    copilotVersion: data.copilotVersion ?? null,
                    producer: data.producer ?? null,
                    startTime: data.startTime ?? ts,
                    cwd: context.cwd ?? null,
                    repository: context.repository ?? null,
                    branch: context.branch ?? null,
                    headCommit: context.headCommit ?? null,
                };
                agent.model = data.selectedModel ?? agent.model;
                agent.reasoningEffort = data.reasoningEffort ?? agent.reasoningEffort;
                agent.contextTier = data.contextTier ?? agent.contextTier;
                if (agent.model) {
                    agent.models.push({ model: agent.model, reasoningEffort: agent.reasoningEffort, contextTier: agent.contextTier, source: 'session.start', ts });
                }
                this.inventoryVersion += 1;
                this.#add(agent, 'session', event, seq, offset, length, {
                    label: 'Session started',
                    summary: oneLine([data.selectedModel, data.reasoningEffort, data.copilotVersion ? `Copilot ${data.copilotVersion}` : null].filter(Boolean).join(' · ')),
                });
                return;
            }
            case 'session.resume': {
                this.session.resumes += 1;
                if (agentKey === ROOT_AGENT) {
                    // The session runs again; its earlier shutdown stays in the log as an entry.
                    this.session.shutdown = null;
                    agent.endTs = null;
                    agent.durationMs = null;
                }
                agent.sinceSystem.add('session resumed');
                this.#add(agent, 'session', event, seq, offset, length, { label: 'Session resumed', summary: '' });
                return;
            }
            case 'session.shutdown': {
                this.session.shutdown = {
                    shutdownType: data.shutdownType ?? null,
                    totalPremiumRequests: numberOrNull(data.totalPremiumRequests),
                    totalApiDurationMs: numberOrNull(data.totalApiDurationMs),
                    currentTokens: numberOrNull(data.currentTokens),
                    currentModel: data.currentModel ?? null,
                };
                if (agentKey === ROOT_AGENT && ts) {
                    agent.endTs = ts;
                    agent.durationMs = elapsed(agent.startTs, ts);
                }
                this.#add(agent, 'session', event, seq, offset, length, { label: 'Session ended', summary: oneLine(data.shutdownType ?? '') });
                return;
            }
            case 'session.permissions_changed': {
                this.session.permissionsChanged += 1;
                this.#add(agent, 'info', event, seq, offset, length, {
                    label: 'Permissions changed',
                    summary: data.allowAllPermissions === true ? 'Allow all permissions on' : data.allowAllPermissions === false ? 'Allow all permissions off' : '',
                });
                return;
            }
            case 'system.message': {
                const previous = agent.systemPrompt;
                const analysis = analyzeSystemPrompt(data.content, data.contentBlocks);
                agent.systemPromptTotal += 1;
                const version = agent.systemPromptTotal;
                const delta = previous ? analysis.chars - previous.chars : null;
                const reasons = previous ? [...agent.sinceSystem] : [];
                agent.sinceSystem.clear();
                agent.systemPrompt = { seq, ...analysis, promptVersion: data.metadata?.promptVersion ?? null };
                if (analysis.agentInstructions && agent.customAgent && (agent.agentPromptSeqs.size < MAX_SELECTIONS || agent.agentPromptSeqs.has(agent.customAgent.name))) {
                    agent.agentPromptSeqs.set(agent.customAgent.name || agent.customAgent.displayName, seq);
                }
                const changed = previous ? diffSections(previous.sections, analysis.sections) : null;
                agent.systemPrompts.push({
                    seq,
                    ts,
                    version,
                    chars: analysis.chars,
                    delta,
                    reasons,
                    sectionCount: analysis.sections.length,
                    changes: changed ? { added: changed.addedCount, removed: changed.removedCount, resized: changed.resizedCount } : null,
                });
                if (agent.systemPrompts.length > MAX_PROMPT_VERSIONS) {
                    agent.systemPrompts.shift();
                }
                this.inventoryVersion += 1;
                this.#add(agent, 'system', event, seq, offset, length, {
                    label: previous ? 'System prompt rebuilt' : 'System prompt',
                    version,
                    chars: agent.systemPrompt.chars,
                    sectionCount: agent.systemPrompt.sections.length,
                    staticChars: agent.systemPrompt.staticChars,
                    delta,
                    reasons,
                    changed,
                });
                return;
            }
            case 'user.message': {
                agent.counts.user += 1;
                agent.sinceSystem.add('new prompt');
                const content = typeof data.content === 'string' ? data.content : '';
                const transformed = typeof data.transformedContent === 'string' ? data.transformedContent : '';
                const attachments = Array.isArray(data.attachments)
                    ? data.attachments.slice(0, 20).map((attachment) => ({
                        type: typeof attachment?.type === 'string' ? attachment.type : 'unknown',
                        name: oneLine(attachment?.displayName ?? attachment?.path ?? attachment?.name ?? '', 120),
                    }))
                    : [];
                const entry = this.#add(agent, 'user', event, seq, offset, length, {
                    label: 'User',
                    summary: plainSummary(content),
                    chars: content.length,
                    injectedChars: transformed && transformed !== content ? transformed.length : 0,
                    attachments,
                    source: typeof data.source === 'string' ? oneLine(data.source, 80) : null,
                });
                agent.interactions.push(entry.index);
                return;
            }
            case 'assistant.turn_start': {
                agent.counts.turns += 1;
                const entry = this.#add(agent, 'turn', event, seq, offset, length, {
                    label: `Turn ${agent.counts.turns}`,
                    number: agent.counts.turns,
                    turnId: data.turnId ?? null,
                    durationMs: null,
                    ended: false,
                    inputTokens: null,
                    outputTokens: null,
                    maxPromptTokens: null,
                    requests: 0,
                    hooks: 0,
                    hooksFailed: 0,
                    hookTypes: Object.create(null),
                    hookRuns: [],
                    hookRunsDropped: 0,
                });
                agent.currentTurn = entry;
                for (const run of agent.pendingHooks.splice(0)) {
                    this.#attachHookRun(agentKey, entry, run);
                }
                if (entry.turnId !== null) {
                    agent.turnsById.set(String(entry.turnId), entry);
                }
                return;
            }
            case 'assistant.turn_end': {
                const entry = agent.turnsById.get(String(data.turnId)) ?? agent.currentTurn;
                if (entry) {
                    entry.ended = true;
                    entry.durationMs = elapsed(entry.ts, ts);
                    entry.parts.push([offset, length]);
                    this.#touch(agentKey, entry);
                }
                return;
            }
            case 'session.usage_record': {
                const usage = data.usage && typeof data.usage === 'object' ? data.usage : {};
                const totals = agent.usage;
                totals.requests += 1;
                totals.inputTokens += num(usage.inputTokens);
                totals.outputTokens += num(usage.outputTokens);
                totals.cacheReadTokens += num(usage.cacheReadTokens);
                totals.cacheWriteTokens += num(usage.cacheWriteTokens);
                totals.reasoningTokens += num(usage.reasoningTokens);
                totals.durationMs += num(usage.duration);
                totals.cost += num(usage.cost);
                if (Number.isFinite(usage.inputTokens)) {
                    this.#context(agent, usage.inputTokens, numberOrNull(usage.maxPromptTokens), 'usage');
                }
                const turn = agent.currentTurn;
                if (turn) {
                    turn.requests += 1;
                    turn.inputTokens = numberOrNull(usage.inputTokens) ?? turn.inputTokens;
                    turn.outputTokens = (turn.outputTokens ?? 0) + num(usage.outputTokens);
                    turn.maxPromptTokens = numberOrNull(usage.maxPromptTokens) ?? turn.maxPromptTokens;
                    turn.model = usage.model ?? turn.model ?? null;
                    this.#touch(agentKey, turn);
                }
                return;
            }
            case 'assistant.message': {
                agent.counts.assistant += 1;
                const content = typeof data.content === 'string' ? data.content : '';
                const requests = Array.isArray(data.toolRequests) ? data.toolRequests : [];
                for (const request of requests) {
                    if (request && typeof request.toolCallId === 'string' && typeof request.intentionSummary === 'string') {
                        this.intents.set(request.toolCallId, oneLine(request.intentionSummary, 160));
                    }
                }
                this.#add(agent, 'assistant', event, seq, offset, length, {
                    label: 'Assistant',
                    summary: plainSummary(content),
                    chars: content.length,
                    reasoningChars: typeof data.reasoningText === 'string' ? data.reasoningText.length : 0,
                    model: data.model ?? null,
                    toolRequests: requests.slice(0, 50).map((request) => ({
                        id: typeof request?.toolCallId === 'string' ? request.toolCallId : null,
                        name: typeof request?.name === 'string' ? request.name : null,
                    })),
                });
                return;
            }
            case 'tool.execution_start': {
                const id = typeof data.toolCallId === 'string' ? data.toolCallId : null;
                const existing = id ? this.#toolEntry(id) : null;
                if (existing) {
                    existing.entry.parts.push([offset, length]);
                    existing.entry.name = data.toolName ?? existing.entry.name;
                    this.#noteMcp(this.agents.get(existing.agent) ?? agent, existing.entry.name, data);
                    this.#touch(existing.agent, existing.entry);
                    return;
                }
                const name = typeof data.toolName === 'string' ? data.toolName : 'tool';
                agent.counts.tools += 1;
                const count = agent.toolCounts.get(name) ?? { count: 0, failed: 0, lastCallId: null };
                count.count += 1;
                count.lastCallId = id ?? count.lastCallId;
                agent.toolCounts.set(name, count);
                this.#noteToolCall(agent, name, id, data, seq);
                const entry = this.#add(agent, 'tool', event, seq, offset, length, {
                    label: 'Tool',
                    name,
                    toolCallId: id,
                    title: oneLine(data.toolTitle ?? '', 120),
                    summary: (id && this.intents.get(id)) || summarizeArguments(data.arguments),
                    status: 'running',
                    durationMs: null,
                    result: '',
                    subagent: null,
                });
                if (id) {
                    this.intents.delete(id);
                    this.tools.set(id, { agent: agentKey, index: entry.index });
                    const child = this.pendingSpawn.get(id);
                    if (child) {
                        this.pendingSpawn.delete(id);
                        this.#linkSubagent(child, agentKey, entry);
                    }
                }
                return;
            }
            case 'tool.execution_complete': {
                const id = typeof data.toolCallId === 'string' ? data.toolCallId : null;
                let found = id ? this.#toolEntry(id) : null;
                if (!found) {
                    const name = 'tool';
                    agent.counts.tools += 1;
                    const entry = this.#add(agent, 'tool', event, seq, offset, length, {
                        label: 'Tool', name, toolCallId: id, title: '', summary: '', status: 'running', durationMs: null, result: '', subagent: null,
                    });
                    if (id) {
                        this.tools.set(id, { agent: agentKey, index: entry.index });
                    }
                    found = { agent: agentKey, entry };
                } else {
                    found.entry.parts.push([offset, length]);
                }
                const entry = found.entry;
                const failed = data.success === false || Boolean(data.error);
                entry.status = failed ? 'failed' : 'succeeded';
                entry.durationMs = elapsed(entry.ts, ts);
                const result = data.result && typeof data.result === 'object' ? data.result : null;
                const errorMessage = data.error && typeof data.error === 'object' ? data.error.message : typeof data.error === 'string' ? data.error : null;
                entry.result = oneLine(errorMessage ?? (typeof result?.content === 'string' ? result.content : ''), 160);
                if (failed) {
                    const owner = this.agents.get(found.agent);
                    const count = owner?.toolCounts.get(entry.name);
                    if (count) {
                        count.failed += 1;
                    }
                }
                if (id && this.canvasCalls.has(id)) {
                    this.#completeCanvasCall(id, failed, offset, length);
                }
                const metrics = data.toolTelemetry?.metrics;
                if (metrics && Number.isFinite(metrics.context_current_tokens)) {
                    this.#context(this.agents.get(found.agent) ?? agent, metrics.context_current_tokens, numberOrNull(metrics.context_token_limit), 'tool');
                }
                this.#touch(found.agent, entry);
                return;
            }
            case 'external_tool.requested': {
                const id = typeof data.toolCallId === 'string' ? data.toolCallId : null;
                if (typeof data.requestId === 'string' && id) {
                    this.externalRequests.set(data.requestId, id);
                }
                const found = id ? this.#toolEntry(id) : null;
                if (found) {
                    found.entry.parts.push([offset, length]);
                    found.entry.external = true;
                    this.#touch(found.agent, found.entry);
                    return;
                }
                const name = typeof data.toolName === 'string' ? data.toolName : 'tool';
                agent.counts.tools += 1;
                const count = agent.toolCounts.get(name) ?? { count: 0, failed: 0, lastCallId: null };
                count.count += 1;
                count.lastCallId = id ?? count.lastCallId;
                agent.toolCounts.set(name, count);
                this.#noteToolCall(agent, name, id, data, seq);
                const entry = this.#add(agent, 'tool', event, seq, offset, length, {
                    label: 'Tool', name, toolCallId: id, title: '', summary: summarizeArguments(data.arguments), status: 'running', durationMs: null, result: '', subagent: null, external: true,
                });
                if (id) {
                    this.tools.set(id, { agent: agentKey, index: entry.index });
                }
                return;
            }
            case 'external_tool.completed': {
                const id = typeof data.requestId === 'string' ? this.externalRequests.get(data.requestId) : null;
                const found = id ? this.#toolEntry(id) : null;
                if (found) {
                    found.entry.parts.push([offset, length]);
                    this.#touch(found.agent, found.entry);
                }
                return;
            }
            case 'subagent.started': {
                if (agentKey === ROOT_AGENT) {
                    return;
                }
                agent.name = oneLine(data.agentName ?? agent.name, 120);
                agent.displayName = oneLine(data.agentDisplayName ?? '', 120) || null;
                agent.description = oneLine(data.agentDescription ?? '', DESCRIPTION_MAX) || null;
                agent.agentType = oneLine(data.agentType ?? '', 120) || null;
                agent.executionMode = data.executionMode ?? null;
                agent.model = data.model ?? agent.model;
                agent.status = 'running';
                agent.startTs = ts ?? agent.startTs;
                const spawn = typeof data.toolCallId === 'string' ? data.toolCallId : null;
                agent.spawnToolCallId = spawn;
                const found = spawn ? this.#toolEntry(spawn) : null;
                if (found) {
                    this.#linkSubagent(agentKey, found.agent, found.entry);
                } else if (spawn) {
                    this.pendingSpawn.set(spawn, agentKey);
                    if (!agent.parentKey) {
                        agent.parentKey = ROOT_AGENT;
                        this.#agent(ROOT_AGENT).children.push(agentKey);
                    }
                }
                return;
            }
            case 'subagent.configured': {
                agent.model = data.model ?? agent.model;
                agent.reasoningEffort = data.reasoningEffort ?? agent.reasoningEffort;
                agent.contextTier = data.contextTier ?? agent.contextTier;
                return;
            }
            case 'subagent.selected': {
                if (agentKey === ROOT_AGENT) {
                    agent.customAgent = {
                        name: oneLine(data.agentName ?? '', 120),
                        displayName: oneLine(data.agentDisplayName ?? data.agentName ?? '', 120),
                        toolCount: Array.isArray(data.tools) ? data.tools.length : null,
                    };
                    agent.name = agent.customAgent.displayName || agent.name;
                    const key = agent.customAgent.name || agent.customAgent.displayName;
                    const selection = agent.selections.get(key);
                    if (selection || agent.selections.size < MAX_SELECTIONS) {
                        agent.selections.set(key, {
                            name: agent.customAgent.name,
                            displayName: agent.customAgent.displayName,
                            count: (selection?.count ?? 0) + 1,
                            lastSeq: seq,
                            lastTs: ts,
                        });
                    }
                    this.inventoryVersion += 1;
                    this.#add(agent, 'agent', event, seq, offset, length, { label: 'Agent selected', summary: agent.customAgent.displayName });
                }
                return;
            }
            case 'subagent.deselected': {
                if (agentKey === ROOT_AGENT) {
                    agent.customAgent = null;
                    agent.name = 'Main agent';
                    this.inventoryVersion += 1;
                    this.#add(agent, 'agent', event, seq, offset, length, { label: 'Agent deselected', summary: '' });
                }
                return;
            }
            case 'subagent.completed':
            case 'subagent.failed': {
                if (agentKey === ROOT_AGENT) {
                    return;
                }
                agent.status = event.type === 'subagent.failed' ? 'failed' : 'completed';
                agent.endTs = ts;
                agent.durationMs = numberOrNull(data.durationMs) ?? elapsed(agent.startTs, ts);
                agent.totalToolCalls = numberOrNull(data.totalToolCalls);
                agent.totalTokens = numberOrNull(data.totalTokens);
                agent.model = data.model ?? agent.model;
                const errorMessage = data.error && typeof data.error === 'object' ? data.error.message : data.error;
                agent.error = typeof errorMessage === 'string' ? oneLine(errorMessage, 240) : null;
                const found = agent.spawnToolCallId ? this.#toolEntry(agent.spawnToolCallId) : null;
                if (found) {
                    this.#touch(found.agent, found.entry);
                }
                return;
            }
            case 'session.model_change': {
                agent.sinceSystem.add('model changed');
                agent.model = data.newModel ?? agent.model;
                agent.reasoningEffort = data.reasoningEffort ?? agent.reasoningEffort;
                agent.contextTier = data.contextTier ?? agent.contextTier;
                agent.models.push({ model: agent.model, reasoningEffort: agent.reasoningEffort, contextTier: agent.contextTier, source: data.source ?? null, ts });
                this.#add(agent, 'model', event, seq, offset, length, {
                    label: 'Model changed',
                    summary: oneLine([data.newModel, data.reasoningEffort].filter(Boolean).join(' · ')),
                });
                return;
            }
            case 'skill.invoked':
            case 'skill.invoked_ref': {
                const name = oneLine(data.name ?? data.skillName ?? '', 120) || 'skill';
                const existing = agent.skillsInvoked.get(name);
                agent.skillsInvoked.set(name, {
                    name,
                    source: data.source ?? existing?.source ?? null,
                    pluginName: data.pluginName ?? existing?.pluginName ?? null,
                    trigger: data.trigger ?? existing?.trigger ?? null,
                    count: (existing?.count ?? 0) + 1,
                    lastSeq: seq,
                });
                if (typeof data.content === 'string' && offset >= 0 && this.skillContents.size < MAX_SKILL_REFS) {
                    this.skillContents.set(`sha256:${createHash('sha256').update(data.content, 'utf8').digest('hex')}`, [offset, length]);
                }
                this.inventoryVersion += 1;
                this.#add(agent, 'skill', event, seq, offset, length, {
                    label: 'Skill loaded',
                    name,
                    summary: oneLine([data.pluginName ? `plugin ${data.pluginName}` : data.source, data.trigger].filter(Boolean).join(' · ')),
                });
                return;
            }
            case 'skill.context_delivered':
            case 'skill.context_delivered_ref': {
                this.counts.contextRefs += 1;
                const full = typeof data.content === 'string' ? data.content : null;
                const sourceName = typeof data.source === 'string' && data.source.startsWith('skill-') ? data.source.slice(6) : null;
                const name = skillContextName(data.prefix) ?? skillContextName(full) ?? sourceName;
                if (!name || offset < 0) {
                    return;
                }
                const delivery = { ref: [offset, length], contentId: typeof data.contentId === 'string' ? data.contentId : null, full: full !== null };
                // A delivery belongs to the agent that received it, so another agent's load never stands in for it.
                this.#remember(this.skillDeliveries, `${agentKey}\n${name}`, delivery);
                if (delivery.contentId) {
                    this.#remember(this.skillDeliveriesByContent, `${agentKey}\n${delivery.contentId}`, delivery);
                }
                return;
            }
            case 'session.compaction_start': {
                const entry = this.#add(agent, 'compaction', event, seq, offset, length, {
                    label: 'Compacting context',
                    phase: 'single',
                    status: 'running',
                    before: numberOrNull(data.currentTokens),
                    after: null,
                    limit: numberOrNull(data.tokenLimit),
                    removed: null,
                    split: { before: tokenSplit(data), after: null },
                    trigger: typeof data.trigger === 'string' ? oneLine(data.trigger, 40) : null,
                    model: typeof data.model === 'string' ? oneLine(data.model, 80) : null,
                    startSeq: null,
                    resultSeq: null,
                });
                if (typeof data.compactionAttemptId === 'string') {
                    this.compactionsById.set(data.compactionAttemptId, { agent: agentKey, entry });
                }
                agent.activeCompaction = { entry, candidates: [], attemptId: typeof data.compactionAttemptId === 'string' ? data.compactionAttemptId : null };
                if (entry.before !== null) {
                    this.#context(agent, entry.before, entry.limit, 'compaction');
                }
                return;
            }
            case 'session.compaction_complete': {
                const attemptId = typeof data.compactionAttemptId === 'string' ? data.compactionAttemptId : null;
                let pending = attemptId ? this.compactionsById.get(attemptId) : null;
                const active = agent.activeCompaction;
                if (!pending && active && (!attemptId || !active.attemptId)) {
                    // The attempt ID is optional; without a match, the agent's running compaction is the one completing.
                    pending = { agent: agentKey, entry: active.entry };
                }
                if (pending) {
                    this.compactionsById.delete(attemptId ?? active?.attemptId);
                }
                const ownerKey = pending?.agent ?? agentKey;
                const owner = this.agents.get(ownerKey) ?? agent;
                const start = pending?.entry ?? null;
                const used = data.compactionTokensUsed && typeof data.compactionTokensUsed === 'object' ? data.compactionTokensUsed : {};
                const summaryChars = typeof data.summaryContent === 'string' ? data.summaryContent.length : null;
                const failed = data.success === false;
                const fields = {
                    label: failed ? 'Compaction failed' : 'Context compacted',
                    status: failed ? 'failed' : 'succeeded',
                    before: numberOrNull(data.preCompactionTokens) ?? start?.before ?? null,
                    after: numberOrNull(data.postCompactionTokens),
                    limit: numberOrNull(data.tokenLimit) ?? start?.limit ?? null,
                    removed: numberOrNull(data.messagesRemoved),
                    messagesBefore: numberOrNull(data.preCompactionMessagesLength),
                    split: { before: start?.split?.before ?? null, after: tokenSplit(data) },
                    trigger: start?.trigger ?? (typeof data.trigger === 'string' ? oneLine(data.trigger, 40) : null),
                    model: start?.model ?? (typeof used.model === 'string' ? oneLine(used.model, 80) : null),
                    inputTokens: numberOrNull(used.inputTokens),
                    outputTokens: numberOrNull(used.outputTokens),
                    durationMs: numberOrNull(used.duration),
                    summaryChars,
                    checkpointNumber: numberOrNull(data.checkpointNumber),
                    checkpointName: typeof data.checkpointPath === 'string' ? oneLine(path.basename(data.checkpointPath), 120) : null,
                    error: failed ? oneLine(typeof data.error === 'string' ? data.error : data.error?.message ?? '', 240) || null : null,
                    requestChars: null,
                    requestMessages: null,
                };
                let entry;
                if (start && owner.entries[owner.entries.length - 1] === start) {
                    entry = start;
                    Object.assign(entry, fields);
                    entry.parts.push([offset, length]);
                    this.#touch(ownerKey, entry);
                } else if (start) {
                    entry = this.#add(owner, 'compaction', event, seq, offset, length, { ...fields, phase: 'result', startSeq: start.seq, resultSeq: null });
                    entry.parts.unshift(start.parts[0]);
                    Object.assign(start, { phase: 'start', status: fields.status, resultSeq: seq, label: 'Compaction started' });
                    this.#touch(ownerKey, start);
                } else {
                    entry = this.#add(owner, 'compaction', event, seq, offset, length, { ...fields, phase: 'single', startSeq: null, resultSeq: null });
                }
                const request = pickCompactionRequest(owner.activeCompaction?.entry === start ? owner.activeCompaction.candidates : [], summaryChars);
                if (request) {
                    this.compactionRequests.set(`${ownerKey}:${entry.seq}`, [request.offset, request.length]);
                    entry.requestChars = request.requestChars;
                    entry.requestMessages = request.messages;
                }
                if (!start || owner.activeCompaction?.entry === start) {
                    owner.activeCompaction = null;
                }
                owner.sinceSystem.add('context compacted');
                owner.compactions.push({
                    seq: entry.seq,
                    startSeq: entry.startSeq ?? null,
                    ts: entry.ts ?? start?.ts ?? null,
                    startTs: start?.ts ?? null,
                    status: entry.status,
                    before: entry.before,
                    after: entry.after,
                    limit: entry.limit,
                    removed: entry.removed,
                    trigger: entry.trigger,
                    model: entry.model,
                    durationMs: entry.durationMs,
                    checkpointNumber: entry.checkpointNumber,
                    checkpointName: entry.checkpointName,
                    error: entry.error,
                });
                owner.compactionTotal += 1;
                if (owner.compactions.length > MAX_COMPACTION_RECORDS) {
                    owner.compactions.splice(0, owner.compactions.length - MAX_COMPACTION_RECORDS);
                }
                if (entry.after !== null) {
                    this.#context(owner, entry.after, entry.limit ?? null, 'compaction');
                }
                return;
            }
            case 'system.notification': {
                agent.sinceSystem.add('notification');
                const kind = data.kind && typeof data.kind === 'object' ? data.kind : {};
                const content = typeof data.content === 'string' ? data.content.replace(/<\/?system_notification>/g, '') : '';
                if (kind.type === 'instruction_discovered' && typeof kind.sourcePath === 'string' && kind.sourcePath) {
                    const sourcePath = oneLine(kind.sourcePath, 400);
                    const known = agent.discoveredInstructions.get(sourcePath);
                    if (known || agent.discoveredInstructions.size < MAX_DISCOVERED_INSTRUCTIONS) {
                        agent.discoveredInstructions.set(sourcePath, {
                            sourcePath,
                            triggerFile: typeof kind.triggerFile === 'string' ? oneLine(kind.triggerFile, 400) : known?.triggerFile ?? null,
                            description: typeof kind.description === 'string' ? oneLine(kind.description, 240) : known?.description ?? null,
                            count: (known?.count ?? 0) + 1,
                            seq,
                        });
                        this.inventoryVersion += 1;
                    }
                }
                this.#add(agent, 'notification', event, seq, offset, length, {
                    label: notificationLabel(kind.type),
                    summary: oneLine(content),
                    ref: typeof kind.agentId === 'string' ? kind.agentId : null,
                });
                return;
            }
            case 'permission.requested': {
                const request = data.permissionRequest ?? data.request ?? {};
                const entry = this.#add(agent, 'permission', event, seq, offset, length, {
                    label: 'Permission requested',
                    summary: oneLine(request.kind ?? request.toolName ?? data.kind ?? data.toolName ?? '', 160),
                    status: 'running',
                });
                const id = data.requestId ?? data.id;
                if (typeof id === 'string') {
                    this.permissions.set(id, { agent: agentKey, entry });
                }
                return;
            }
            case 'permission.completed': {
                const id = data.requestId ?? data.id;
                const found = typeof id === 'string' ? this.permissions.get(id) : null;
                if (found) {
                    found.entry.parts.push([offset, length]);
                    const outcome = data.result?.kind ?? data.outcome ?? data.decision ?? null;
                    found.entry.status = typeof outcome === 'string' && /deny|denied|reject/i.test(outcome) ? 'failed' : 'succeeded';
                    found.entry.outcome = typeof outcome === 'string' ? oneLine(outcome, 80) : null;
                    found.entry.label = 'Permission';
                    this.#touch(found.agent, found.entry);
                }
                return;
            }
            case 'session.info':
            case 'session.warning':
            case 'session.error': {
                const kind = event.type.slice('session.'.length);
                this.#add(agent, kind, event, seq, offset, length, {
                    label: kind === 'info' ? 'Info' : kind === 'warning' ? 'Warning' : 'Error',
                    summary: oneLine(data.message ?? data.infoType ?? data.warningType ?? data.errorType ?? ''),
                });
                return;
            }
            case 'abort': {
                this.#add(agent, 'abort', event, seq, offset, length, { label: 'Aborted', summary: oneLine(data.reason ?? '') });
                return;
            }
            case 'hook.start': {
                agent.hooks.count += 1;
                const run = {
                    id: typeof data.hookInvocationId === 'string' ? data.hookInvocationId : null,
                    type: typeof data.hookType === 'string' ? oneLine(data.hookType, 80) : 'hook',
                    ts,
                    status: 'running',
                    durationMs: null,
                    tool: hookToolName(data.input),
                    error: null,
                    parts: [[offset, length]],
                };
                this.#hookBucket(agent, run.type, true).lastRun = run;
                this.#placeHookRun(agentKey, agent, run);
                return;
            }
            case 'hook.end': {
                let run = typeof data.hookInvocationId === 'string' ? this.hookRunsById.get(data.hookInvocationId) : undefined;
                if (!run) {
                    agent.hooks.count += 1;
                    run = {
                        id: typeof data.hookInvocationId === 'string' ? data.hookInvocationId : null,
                        type: typeof data.hookType === 'string' ? oneLine(data.hookType, 80) : 'hook',
                        ts,
                        status: 'running',
                        durationMs: null,
                        tool: null,
                        error: null,
                        parts: [],
                    };
                    this.#hookBucket(agent, run.type, true).lastRun = run;
                    this.#placeHookRun(agentKey, agent, run);
                }
                if (run.parts.length < 4) {
                    run.parts.push([offset, length]);
                }
                run.status = data.success === false ? 'failed' : 'succeeded';
                run.durationMs = elapsed(run.ts, ts);
                const message = data.error && typeof data.error === 'object' ? data.error.message : typeof data.error === 'string' ? data.error : null;
                run.error = message ? oneLine(message, 240) : null;
                const bucket = this.#hookBucket(agent, run.type, false);
                if (run.status === 'failed') {
                    bucket.failed += 1;
                    bucket.lastFailure = { ref: [offset, length], ts };
                    const source = data.error && typeof data.error === 'object' && typeof data.error.source === 'string' ? oneLine(data.error.source, 120) : '';
                    const known = bucket.sources.get(source);
                    if (known || bucket.sources.size < MAX_HOOK_SOURCES) {
                        bucket.sources.set(source, { failed: (known?.failed ?? 0) + 1, error: run.error, ts });
                    }
                }
                const output = data.output && typeof data.output === 'object' ? data.output : null;
                if (typeof output?.additionalContext === 'string' && output.additionalContext.length > 0) {
                    bucket.contextCount += 1;
                    bucket.lastContext = { ref: [offset, length], ts };
                }
                if (run.id) {
                    this.hookRunsById.delete(run.id);
                }
                if (run.status === 'failed') {
                    agent.hooks.failed += 1;
                }
                const turn = this.hookTurns.get(run);
                if (turn) {
                    if (run.status === 'failed') {
                        turn.hooksFailed += 1;
                        const bucket = turn.hookTypes[run.type];
                        if (bucket) {
                            bucket.failed += 1;
                        }
                    }
                    this.#touch(agentKey, turn);
                }
                return;
            }
            case 'session.usage_checkpoint': {
                const states = Array.isArray(data.promptCacheBreakState) ? data.promptCacheBreakState : [];
                const toolNames = new Set();
                const toolHashes = new Map();
                let toolCount = null;
                let truncated = 0;
                for (const state of states) {
                    const models = state?.models && typeof state.models === 'object' ? Object.values(state.models) : [];
                    for (const model of models) {
                        if (Number.isFinite(model?.tool_count)) {
                            toolCount = Math.max(toolCount ?? 0, model.tool_count);
                        }
                        if (Number.isFinite(model?.tools_truncated)) {
                            truncated = Math.max(truncated, model.tools_truncated);
                        }
                        for (const tool of Array.isArray(model?.tools) ? model.tools : []) {
                            if (typeof tool?.name === 'string') {
                                toolNames.add(tool.name);
                                if (typeof tool.schema_hash === 'string' && toolHashes.size < MAX_TOOL_HASHES) {
                                    toolHashes.set(tool.name, tool.schema_hash.slice(0, 64));
                                }
                            }
                        }
                    }
                }
                const previous = this.session.checkpoint;
                this.session.checkpoint = {
                    totalPremiumRequests: numberOrNull(data.totalPremiumRequests) ?? previous?.totalPremiumRequests ?? null,
                    toolCount: toolCount ?? previous?.toolCount ?? null,
                    toolsTruncated: toolNames.size > 0 ? truncated : previous?.toolsTruncated ?? 0,
                    toolNames: toolNames.size > 0 ? [...toolNames].sort() : previous?.toolNames ?? [],
                    toolHashes: toolHashes.size > 0 ? toolHashes : previous?.toolHashes ?? new Map(),
                };
                this.inventoryVersion += 1;
                return;
            }
            case 'session.binary_asset': {
                this.counts.binaryAssets += 1;
                return;
            }
            case 'session.workspace_file_changed': {
                this.counts.workspaceFileChanges += 1;
                return;
            }
            case 'session.canvas.recorded':
            case 'session.canvas.removed': {
                const instanceId = typeof data.instanceId === 'string' ? oneLine(data.instanceId, 200) : null;
                const canvasId = typeof data.canvasId === 'string' ? oneLine(data.canvasId, 200) : null;
                if (!instanceId || !canvasId) {
                    return;
                }
                const canvas = this.#canvas(canvasId);
                if (canvas && typeof data.extensionId === 'string') {
                    canvas.extensionId = oneLine(data.extensionId, 200);
                }
                const known = this.canvasInstances.get(instanceId);
                if (!known && this.canvasInstances.size >= MAX_CANVAS_INSTANCES) {
                    return;
                }
                const removed = event.type === 'session.canvas.removed';
                this.canvasInstances.set(instanceId, {
                    instanceId,
                    canvasId,
                    title: typeof data.title === 'string' ? oneLine(data.title, 160) : known?.title ?? null,
                    ts: known?.ts ?? ts,
                    removed,
                    removedTs: removed ? ts : null,
                });
                if (canvas && !removed) {
                    canvas.instances.add(instanceId);
                }
                this.inventoryVersion += 1;
                return;
            }
            case 'tool_search.activated': {
                const names = Array.isArray(data.toolNames) ? data.toolNames.filter((name) => typeof name === 'string').map((name) => oneLine(name, 200)) : [];
                for (const name of names) {
                    if (agent.activatedTools.size >= MAX_ACTIVATED_TOOLS) {
                        break;
                    }
                    agent.activatedTools.add(name);
                }
                this.inventoryVersion += 1;
                this.#add(agent, 'info', event, seq, offset, length, {
                    label: 'Tools loaded by search',
                    summary: oneLine(names.join(', ')),
                });
                return;
            }
            default: {
                if (event.type.startsWith('model.')) {
                    this.counts.debugEvents += 1;
                    if (event.type === 'model.messages_snapshot' && agent.activeCompaction && Array.isArray(data.messages)) {
                        const candidate = snapshotCandidate(data.messages, offset, length);
                        if (candidate && agent.activeCompaction.candidates.length < MAX_SNAPSHOT_CANDIDATES) {
                            agent.activeCompaction.candidates.push(candidate);
                        }
                    }
                    return;
                }
                this.unknownTypes.set(event.type, (this.unknownTypes.get(event.type) ?? 0) + 1);
                this.#add(agent, 'unknown', event, seq, offset, length, { label: oneLine(event.type, 80), summary: '' });
            }
        }
    }

    /** Records what one tool call says about inventories: canvases, MCP servers, and file reads. */
    #noteToolCall(agent, name, toolCallId, data, seq) {
        this.#noteMcp(agent, name, data);
        const args = data.arguments && typeof data.arguments === 'object' ? data.arguments : {};
        if (READ_TOOLS.has(name) && typeof args.path === 'string' && args.path) {
            const filePath = args.path.slice(0, 1000);
            const read = agent.fileReads.get(filePath);
            if (read) {
                read.count += 1;
                read.lastSeq = seq;
            } else if (agent.fileReads.size < MAX_FILE_READS) {
                agent.fileReads.set(filePath, { count: 1, lastSeq: seq });
            }
        }
        if (!CANVAS_TOOLS.has(name)) {
            return;
        }
        const instanceId = typeof args.instanceId === 'string' ? oneLine(args.instanceId, 200) : null;
        let canvasId = typeof args.canvasId === 'string' ? oneLine(args.canvasId, 200) : null;
        if (!canvasId && instanceId) {
            canvasId = this.canvasInstances.get(instanceId)?.canvasId ?? null;
        }
        const canvas = canvasId ? this.#canvas(canvasId) : null;
        if (!canvas) {
            return;
        }
        canvas.calls += 1;
        canvas.lastCallId = toolCallId ?? canvas.lastCallId;
        if (name === 'open_canvas') {
            canvas.opens += 1;
            if (instanceId && (this.canvasInstances.has(instanceId) || this.canvasInstances.size < MAX_CANVAS_INSTANCES)) {
                const known = this.canvasInstances.get(instanceId);
                this.canvasInstances.set(instanceId, { instanceId, canvasId, title: known?.title ?? null, ts: known?.ts ?? null, removed: false, removedTs: null });
                canvas.instances.add(instanceId);
            }
        } else if (name === 'invoke_canvas_action') {
            canvas.actionCalls += 1;
            const action = typeof args.actionName === 'string' ? oneLine(args.actionName, 120) : '';
            if (action && (canvas.actions.has(action) || canvas.actions.size < 100)) {
                canvas.actions.set(action, (canvas.actions.get(action) ?? 0) + 1);
            }
        } else {
            canvas.capabilityCalls += 1;
        }
        if (toolCallId && this.canvasCalls.size < MAX_PENDING_CANVAS_CALLS) {
            this.canvasCalls.set(toolCallId, { canvasId, tool: name });
        }
        this.inventoryVersion += 1;
    }

    #noteMcp(agent, name, data) {
        if (typeof data.mcpServerName === 'string' && data.mcpServerName && (agent.mcpTools.has(name) || agent.mcpTools.size < MAX_MCP_TOOLS)) {
            agent.mcpTools.set(name, oneLine(data.mcpServerName, 120));
        }
    }

    /** Returns the activity record for a canvas, creating it while under the cap. */
    #canvas(canvasId) {
        let canvas = this.canvases.get(canvasId);
        if (!canvas && this.canvases.size < MAX_CANVASES) {
            canvas = { canvasId, extensionId: null, calls: 0, opens: 0, actionCalls: 0, capabilityCalls: 0, failed: 0, actions: new Map(), instances: new Set(), lastCallId: null, capabilities: null };
            this.canvases.set(canvasId, canvas);
        }
        return canvas ?? null;
    }

    #completeCanvasCall(toolCallId, failed, offset, length) {
        const call = this.canvasCalls.get(toolCallId);
        this.canvasCalls.delete(toolCallId);
        const canvas = this.canvases.get(call.canvasId);
        if (!canvas) {
            return;
        }
        if (failed) {
            canvas.failed += 1;
        } else if (call.tool === 'list_canvas_capabilities' && offset >= 0) {
            canvas.capabilities = { ref: [offset, length], toolCallId };
        }
    }

    /** Returns the per-type hook record, counting a run when `isRun` is set. */
    #hookBucket(agent, type, isRun) {
        let bucket = agent.hookTypes.get(type);
        if (!bucket) {
            bucket = { type, count: 0, failed: 0, sources: new Map(), lastRun: null, lastFailure: null, contextCount: 0, lastContext: null };
            if (agent.hookTypes.size < 100) {
                agent.hookTypes.set(type, bucket);
            }
        }
        if (isRun) {
            bucket.count += 1;
        }
        return bucket;
    }

    #toolEntry(toolCallId) {
        const ref = this.tools.get(toolCallId);
        if (!ref) {
            return null;
        }
        const owner = this.agents.get(ref.agent);
        const entry = owner?.entries[ref.index];
        return entry ? { agent: ref.agent, entry } : null;
    }

    #linkSubagent(childKey, parentKey, toolEntry) {
        const child = this.#agent(childKey);
        if (child.parentKey && child.parentKey !== parentKey) {
            const previous = this.agents.get(child.parentKey);
            if (previous) {
                previous.children = previous.children.filter((key) => key !== childKey);
            }
        }
        if (child.parentKey !== parentKey) {
            child.parentKey = parentKey;
            this.#agent(parentKey).children.push(childKey);
        }
        toolEntry.subagent = childKey;
        this.#touch(parentKey, toolEntry);
    }

    #context(agent, current, limit, source) {
        agent.context.current = current;
        if (Number.isFinite(limit) && limit > 0) {
            agent.context.limit = limit;
        }
        agent.context.peak = Math.max(agent.context.peak ?? 0, current);
        agent.context.source = source;
    }

    /**
     * Returns compact metadata for the session and every agent.
     */
    getSummary() {
        const agents = [...this.agents.values()].map((agent) => ({
            key: agent.key,
            agentId: agent.agentId,
            parentKey: agent.parentKey,
            spawnToolCallId: agent.spawnToolCallId,
            name: agent.name,
            displayName: agent.displayName,
            description: agent.description,
            agentType: agent.agentType,
            executionMode: agent.executionMode,
            model: agent.model,
            reasoningEffort: agent.reasoningEffort,
            contextTier: agent.contextTier,
            models: agent.models.slice(-20),
            status: agent.status,
            startTs: agent.startTs,
            endTs: agent.endTs,
            durationMs: agent.durationMs,
            totalToolCalls: agent.totalToolCalls,
            totalTokens: agent.totalTokens,
            error: agent.error,
            customAgent: agent.customAgent,
            usage: { ...agent.usage },
            context: { ...agent.context },
            compactions: agent.compactions.slice(-50),
            compactionTotal: agent.compactionTotal,
            activeCompaction: agent.activeCompaction
                ? {
                    seq: agent.activeCompaction.entry.seq,
                    ts: agent.activeCompaction.entry.ts,
                    status: 'running',
                    before: agent.activeCompaction.entry.before,
                    limit: agent.activeCompaction.entry.limit,
                    trigger: agent.activeCompaction.entry.trigger,
                    model: agent.activeCompaction.entry.model,
                }
                : null,
            hooks: { ...agent.hooks },
            counts: { ...agent.counts, entries: agent.entries.length },
            tools: [...agent.toolCounts.entries()].map(([name, value]) => ({ name, ...value })).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name)),
            skillsInvoked: [...agent.skillsInvoked.values()],
            systemPrompt: agent.systemPrompt
                ? {
                    seq: agent.systemPrompt.seq,
                    chars: agent.systemPrompt.chars,
                    sectionCount: agent.systemPrompt.sections.length,
                    skillCount: agent.systemPrompt.skills.length,
                    instructionCount: agent.systemPrompt.instructions.length,
                    agentInstructions: agent.systemPrompt.agentInstructions,
                    promptVersion: agent.systemPrompt.promptVersion,
                }
                : null,
            systemPromptVersions: agent.systemPrompts.slice(-100).map((item) => ({ ...item, reasons: [...item.reasons] })),
            systemPromptCount: agent.systemPromptTotal,
            children: [...agent.children],
            interactions: agent.interactions.length,
        }));
        return {
            version: this.version,
            epoch: this.epoch,
            inventoryVersion: this.inventoryVersion,
            fileBytes: Math.max(this.fileSize, 0),
            session: {
                ...this.session,
                checkpoint: this.session.checkpoint
                    ? { totalPremiumRequests: this.session.checkpoint.totalPremiumRequests, toolCount: this.session.checkpoint.toolCount }
                    : null,
            },
            counts: { ...this.counts, unknownTypes: [...this.unknownTypes.entries()].map(([type, count]) => ({ type, count })) },
            agents,
        };
    }

    /**
     * Returns the reconstructed inventory recorded in the log for one agent.
     *
     * @param {string} agentKey
     */
    getRecordedInventory(agentKey = ROOT_AGENT) {
        const agent = this.agents.get(agentKey);
        if (!agent) {
            return null;
        }
        const observedTools = [...agent.toolCounts.keys()];
        const checkpointTools = agentKey === ROOT_AGENT ? this.session.checkpoint?.toolNames ?? [] : [];
        const toolNames = [...new Set([...checkpointTools, ...observedTools])].sort((a, b) => a.localeCompare(b));
        const subagentTypes = new Map();
        for (const candidate of this.agents.values()) {
            const type = candidate.key === ROOT_AGENT ? null : candidate.agentType || candidate.name;
            if (!type) {
                continue;
            }
            const known = subagentTypes.get(type) ?? { type, displayName: candidate.displayName, description: candidate.description, count: 0, failed: 0, running: 0, lastStartTs: null };
            known.count += 1;
            known.failed += candidate.status === 'failed' ? 1 : 0;
            known.running += candidate.status === 'running' ? 1 : 0;
            if (candidate.startTs && (!known.lastStartTs || candidate.startTs > known.lastStartTs)) {
                known.lastStartTs = candidate.startTs;
            }
            subagentTypes.set(type, known);
        }
        const promptOwner = agent.systemPrompt ? agent : this.agents.get(ROOT_AGENT);
        const root = this.agents.get(ROOT_AGENT);
        return {
            inventoryVersion: this.inventoryVersion,
            agentKey,
            customAgent: agent.customAgent,
            systemPrompt: agent.systemPrompt
                ? {
                    chars: agent.systemPrompt.chars,
                    staticChars: agent.systemPrompt.staticChars,
                    sections: agent.systemPrompt.sections,
                    agentInstructions: agent.systemPrompt.agentInstructions,
                }
                : null,
            skills: agent.systemPrompt?.skills ?? [],
            skillsInvoked: [...agent.skillsInvoked.values()],
            instructions: agent.systemPrompt?.instructions ?? [],
            discoveredInstructions: [...agent.discoveredInstructions.values()],
            tools: {
                names: toolNames,
                declaredCount: agentKey === ROOT_AGENT ? this.session.checkpoint?.toolCount ?? null : null,
                listTruncated: agentKey === ROOT_AGENT ? this.session.checkpoint?.toolsTruncated ?? 0 : 0,
                calls: [...agent.toolCounts].map(([name, count]) => ({ name, count: count.count, failed: count.failed })),
                mcpServers: [...agent.mcpTools].map(([tool, server]) => ({ tool, server })),
                activated: [...agent.activatedTools],
            },
            subagentTypes: [...subagentTypes.values()],
            selections: [...(root?.selections.values() ?? [])],
            canvases: {
                prompt: promptOwner?.systemPrompt?.canvases ?? [],
                activity: [...this.canvases.values()].map((canvas) => ({
                    canvasId: canvas.canvasId,
                    extensionId: canvas.extensionId,
                    calls: canvas.calls,
                    opens: canvas.opens,
                    actionCalls: canvas.actionCalls,
                    capabilityCalls: canvas.capabilityCalls,
                    failed: canvas.failed,
                    instances: canvas.instances.size,
                    open: [...canvas.instances].filter((id) => this.canvasInstances.get(id)?.removed === false).length,
                    hasCapabilities: Boolean(canvas.capabilities),
                })),
            },
            hooks: [...agent.hookTypes.values()].map((bucket) => ({
                type: bucket.type,
                count: bucket.count,
                failed: bucket.failed,
                contextCount: bucket.contextCount,
                sources: [...bucket.sources].map(([source, info]) => ({ source, failed: info.failed })),
                lastTs: bucket.lastRun?.ts ?? null,
            })),
        };
    }

    /**
     * Counts how often each path was read into context by a file-viewing tool. Paths match exactly
     * or by trailing path segments, as instruction listings mix relative and absolute paths.
     *
     * @param {string} agentKey
     * @param {string[]} paths
     * @returns {Map<string, number>}
     */
    getReadCounts(agentKey, paths) {
        const counts = new Map();
        const agent = this.agents.get(agentKey);
        if (!agent || agent.fileReads.size === 0) {
            return counts;
        }
        const byBase = new Map();
        for (const [readPath, read] of agent.fileReads) {
            const base = readPath.slice(readPath.lastIndexOf('/') + 1);
            const list = byBase.get(base) ?? [];
            list.push([readPath, read.count]);
            byBase.set(base, list);
        }
        for (const wanted of paths) {
            if (typeof wanted !== 'string' || !wanted) {
                continue;
            }
            const base = wanted.slice(wanted.lastIndexOf('/') + 1);
            let total = 0;
            for (const [readPath, count] of byBase.get(base) ?? []) {
                if (readPath === wanted || readPath.endsWith(`/${wanted}`) || wanted.endsWith(`/${readPath}`)) {
                    total += count;
                }
            }
            if (total > 0) {
                counts.set(wanted, total);
            }
        }
        return counts;
    }

    /**
     * Returns a page of entries for one agent.
     *
     * @param {string} agentKey
     * @param {{ from?: number, limit?: number }} [range]
     */
    getEntries(agentKey, range = {}) {
        const agent = this.agents.get(agentKey);
        if (!agent) {
            return null;
        }
        const total = agent.entries.length;
        const limit = clamp(range.limit ?? 200, 1, 500);
        const from = clamp(range.from ?? Math.max(0, total - limit), 0, total);
        return { total, from, entries: agent.entries.slice(from, from + limit) };
    }

    /**
     * Returns entries appended after `since` and entries updated after `sinceVersion`.
     *
     * @param {string} agentKey
     * @param {number} since Count of entries the client already has.
     * @param {number} sinceVersion Index version the client last saw.
     * @param {number} [limit]
     */
    getChanges(agentKey, since, sinceVersion, limit = 200) {
        const agent = this.agents.get(agentKey);
        if (!agent) {
            return null;
        }
        const total = agent.entries.length;
        const resync = sinceVersion < this.updatesFloor || since > total;
        const start = clamp(since, 0, total);
        const added = agent.entries.slice(start, start + clamp(limit, 1, 500));
        const updatedIndexes = new Set();
        if (!resync) {
            for (let i = this.updates.length - 1; i >= 0; i -= 1) {
                const update = this.updates[i];
                if (update.v <= sinceVersion) {
                    break;
                }
                if (update.agent === agentKey && update.index < start) {
                    updatedIndexes.add(update.index);
                }
            }
        }
        const updated = [...updatedIndexes].sort((a, b) => a - b).map((index) => agent.entries[index]);
        const next = start + added.length;
        return { total, added, updated, resync, next, more: next < total };
    }

    /**
     * Returns prompt and tool navigation lists for one agent.
     *
     * @param {string} agentKey
     * @param {{ query?: string, status?: 'all' | 'failed' | 'running', limit?: number }} [options]
     */
    getOutline(agentKey, options = {}) {
        const agent = this.agents.get(agentKey);
        if (!agent) {
            return null;
        }
        const limit = clamp(options.limit ?? 300, 1, 1000);
        const query = typeof options.query === 'string' ? options.query.trim().toLowerCase() : '';
        const status = options.status ?? 'all';
        const interactions = agent.interactions.slice(-limit).map((index) => {
            const entry = agent.entries[index];
            return { seq: entry.seq, index, ts: entry.ts, summary: oneLine(entry.summary, 120) };
        });
        const tools = [];
        let toolMatches = 0;
        let compactionMatches = 0;
        const compactionQuery = !query || 'context compaction compacted'.includes(query);
        for (let index = agent.entries.length - 1; index >= 0; index -= 1) {
            const entry = agent.entries[index];
            if (entry.kind === 'compaction') {
                if (entry.phase === 'start' || !compactionQuery || (status !== 'all' && entry.status !== status)) {
                    continue;
                }
                compactionMatches += 1;
                if (tools.length < limit) {
                    tools.push({ kind: 'compaction', seq: entry.seq, index, ts: entry.ts, name: entry.label, status: entry.status, before: entry.before, after: entry.after, removed: entry.removed });
                }
                continue;
            }
            if (entry.kind !== 'tool') {
                continue;
            }
            if (status === 'failed' && entry.status !== 'failed') {
                continue;
            }
            if (status === 'running' && entry.status !== 'running') {
                continue;
            }
            if (query && !entry.name.toLowerCase().includes(query) && !entry.summary.toLowerCase().includes(query)) {
                continue;
            }
            toolMatches += 1;
            if (tools.length < limit) {
                tools.push({ kind: 'tool', seq: entry.seq, index, ts: entry.ts, name: entry.name, summary: oneLine(entry.summary, 100), status: entry.status, subagent: entry.subagent });
            }
        }
        tools.reverse();
        return { interactionTotal: agent.interactions.length, interactions, toolTotal: agent.counts.tools, toolMatches, compactionTotal: agent.compactionTotal + (agent.activeCompaction ? 1 : 0), compactionMatches, tools };
    }

    /**
     * Returns the analyzed system prompt of an agent: sections with offsets, skills, and instruction files.
     * The latest version comes from memory; an earlier version is re-read and analyzed on demand.
     *
     * @param {string} agentKey
     * @param {number} [seq] Sequence number of a specific version; the latest when omitted.
     */
    async getSystemPrompt(agentKey, seq) {
        const agent = this.agents.get(agentKey);
        const latest = agent?.systemPrompt;
        if (!latest) {
            return null;
        }
        const versions = agent.systemPrompts;
        let meta = Number.isInteger(seq) ? versions.find((item) => item.seq === seq) : versions[versions.length - 1];
        if (Number.isInteger(seq) && !meta) {
            // A version older than the kept metadata still resolves from its own log entry.
            const located = this.findEntry(agentKey, { seq });
            const entry = located ? agent.entries[located.index] : null;
            if (entry?.kind !== 'system') {
                return null;
            }
            meta = { seq, version: entry.version ?? null };
        }
        let prompt = latest;
        if (meta && meta.seq !== latest.seq) {
            const located = this.findEntry(agentKey, { seq: meta.seq });
            const ref = located ? this.agents.get(located.agent).entries[located.index].parts[0] : null;
            if (!ref) {
                return null;
            }
            const handle = await this.#openFile();
            let event;
            try {
                event = await readEvent(handle, ref[0], ref[1]);
            } finally {
                await handle.close();
            }
            if (event?.type !== 'system.message') {
                return null;
            }
            prompt = { seq: meta.seq, ...analyzeSystemPrompt(event.data?.content, event.data?.contentBlocks), promptVersion: event.data?.metadata?.promptVersion ?? null };
        }
        return {
            seq: prompt.seq,
            version: meta?.version ?? null,
            versionCount: agent.systemPromptTotal,
            chars: prompt.chars,
            staticChars: prompt.staticChars,
            promptVersion: prompt.promptVersion,
            sections: prompt.sections,
            skills: prompt.skills,
            instructions: prompt.instructions,
            agentInstructions: prompt.agentInstructions,
        };
    }

    /**
     * Reads one page of a compaction's request (the instruction sent with the conversation) or its
     * summary response. The request snapshot can be megabytes, so it is read only when asked for.
     *
     * @param {string} agentKey
     * @param {number} seq Sequence number of the compaction entry.
     * @param {'request' | 'summary'} which
     * @param {number} start Character offset.
     */
    async readCompactionText(agentKey, seq, which, start) {
        const located = this.findEntry(agentKey, { seq });
        if (!located) {
            return null;
        }
        const entry = this.agents.get(located.agent).entries[located.index];
        if (entry.kind !== 'compaction') {
            return null;
        }
        const refs = which === 'request' ? [this.compactionRequests.get(`${located.agent}:${entry.seq}`)].filter(Boolean) : entry.parts;
        if (refs.length === 0) {
            return null;
        }
        let value = null;
        const handle = await this.#openFile();
        try {
            for (const [offset, length] of refs) {
                const event = await readEvent(handle, offset, length);
                if (which === 'request' && event?.type === 'model.messages_snapshot' && Array.isArray(event.data?.messages)) {
                    const messages = event.data.messages;
                    for (let i = messages.length - 1; i >= 0; i -= 1) {
                        if (messages[i]?.role === 'user') {
                            value = messageText(messages[i]);
                            break;
                        }
                    }
                } else if (which === 'summary' && event?.type === 'session.compaction_complete' && typeof event.data?.summaryContent === 'string') {
                    value = event.data.summaryContent;
                }
                if (value !== null) {
                    break;
                }
            }
        } finally {
            await handle.close();
        }
        if (value === null) {
            return null;
        }
        const from = clamp(start, 0, value.length);
        const text = value.slice(from, from + this.options.pageChars);
        return { text, start: from, length: value.length, next: from + text.length < value.length ? from + text.length : null };
    }

    /**
     * Returns the agent-specific instructions an agent received, from its own latest system
     * prompt: a subagent's prompt opens with its agent definition, and the main agent's prompt
     * carries the selected custom agent's `<agent_instructions>` block.
     *
     * @param {string} agentKey
     * @returns {Promise<{ agent: string, form: 'subagent' | 'main', text: string, chars: number, truncated: boolean, seq: number, title: string | null } | null>}
     */
    async getAgentInstructions(agentKey) {
        const agent = this.agents.get(agentKey);
        const seq = agent?.systemPrompt?.seq;
        if (!Number.isInteger(seq)) {
            return null;
        }
        const isRoot = agentKey === ROOT_AGENT;
        if (isRoot && !agent.systemPrompt.agentInstructions) {
            return null;
        }
        const event = await this.#readEntryEvent(agentKey, seq);
        const content = typeof event?.data?.content === 'string' ? event.data.content : null;
        const block = content === null ? null : isRoot ? agentInstructionsBlock(content) : leadingPromptText(content);
        if (!block) {
            return null;
        }
        return {
            agent: agentKey,
            form: isRoot ? 'main' : 'subagent',
            ...block,
            seq,
            title: isRoot ? agent.systemPrompt.agentInstructions?.title ?? agent.customAgent?.displayName ?? null : agent.displayName ?? agent.name ?? null,
        };
    }

    /**
     * Returns what the log recorded about one item the model was given. Tools carry call
     * statistics and the latest call; skills, instructions, and canvases carry their system prompt
     * entries; agents carry runs, main-agent selections, and the prompt the agent received;
     * canvases add activity and the latest capabilities result; hooks carry runs by type. Text is
     * re-read from the log on demand.
     *
     * @param {string} agentKey
     * @param {'tool' | 'skill' | 'instruction' | 'agent' | 'canvas' | 'mcp' | 'hook' | 'plugin' | 'extension'} kind
     * @param {string} name Tool, skill, canvas, MCP server, hook type, plugin, or extension name; instruction path; or agent name.
     * @param {string[]} [aliases] Other names for an agent, such as its ID or display name.
     * @returns {Promise<object | null>} Null when the agent is not recorded.
     */
    async getDefinition(agentKey, kind, name, aliases = []) {
        const agent = this.agents.get(agentKey);
        if (!agent) {
            return null;
        }
        switch (kind) {
            case 'tool': {
                const count = agent.toolCounts.get(name);
                const checkpoint = this.session.checkpoint;
                let otherAgentCalls = 0;
                for (const other of this.agents.values()) {
                    if (other !== agent) {
                        otherAgentCalls += other.toolCounts.get(name)?.count ?? 0;
                    }
                }
                return {
                    calls: { count: count?.count ?? 0, failed: count?.failed ?? 0, lastCallId: count?.lastCallId ?? null },
                    otherAgentCalls,
                    schemaHash: checkpoint?.toolHashes?.get(name) ?? null,
                    offered: checkpoint && checkpoint.toolNames.length > 0 ? checkpoint.toolNames.includes(name) : null,
                    mcpServer: agent.mcpTools.get(name) ?? null,
                    activatedBySearch: agent.activatedTools.has(name),
                    latestCall: count?.lastCallId ? await this.#toolCall(count.lastCallId) : null,
                };
            }
            case 'agent':
                return this.#agentDefinition([name, ...aliases]);
            case 'skill': {
                const prompt = await this.#promptText(agentKey);
                const invoked = agent.skillsInvoked.get(name) ?? null;
                return {
                    promptEntry: prompt ? skillPromptEntry(prompt.text, name) : null,
                    promptSeq: prompt?.seq ?? null,
                    promptAgent: prompt?.agentKey ?? null,
                    invocations: invoked ? { count: invoked.count, latest: await this.#skillInvocation(agentKey, invoked.lastSeq, name) } : { count: 0, latest: null },
                };
            }
            case 'instruction': {
                const prompt = await this.#promptText(agentKey);
                const discovered = [...agent.discoveredInstructions.values()].find((item) => item.sourcePath === name || item.sourcePath.endsWith(`/${name}`) || name.endsWith(`/${item.sourcePath}`)) ?? null;
                return {
                    promptEntry: prompt ? instructionPromptEntry(prompt.text, name) : null,
                    promptSeq: prompt?.seq ?? null,
                    promptAgent: prompt?.agentKey ?? null,
                    reads: this.getReadCounts(agentKey, [name]).get(name) ?? 0,
                    discovered,
                };
            }
            case 'canvas':
                return this.#canvasDefinition(agentKey, name);
            case 'mcp': {
                const tools = [];
                for (const [tool, server] of agent.mcpTools) {
                    if (server === name) {
                        const count = agent.toolCounts.get(tool);
                        tools.push({ name: tool, count: count?.count ?? 0, failed: count?.failed ?? 0, lastCallId: count?.lastCallId ?? null });
                    }
                }
                return { tools, calls: tools.reduce((sum, tool) => sum + tool.count, 0), failed: tools.reduce((sum, tool) => sum + tool.failed, 0) };
            }
            case 'hook':
                return this.#hookDefinition(agent, name);
            case 'plugin':
            case 'extension':
                return {};
            default:
                return null;
        }
    }

    /** Reads one tool call's arguments and result, bounded. */
    async #toolCall(toolCallId) {
        const found = this.#toolEntry(toolCallId);
        if (!found) {
            return null;
        }
        const entry = found.entry;
        let args;
        let result = null;
        let error = null;
        const handle = await this.#openFile();
        try {
            for (const [offset, length] of entry.parts.slice(0, 6)) {
                const event = await readEvent(handle, offset, length);
                const data = event?.data && typeof event.data === 'object' ? event.data : null;
                if (!data) {
                    continue;
                }
                if ((event.type === 'tool.execution_start' || event.type === 'external_tool.requested') && args === undefined && data.arguments !== undefined) {
                    args = data.arguments;
                } else if (event.type === 'tool.execution_complete') {
                    const content = data.result && typeof data.result === 'object' ? data.result.content : data.result;
                    result = typeof content === 'string' ? content : result;
                    const message = data.error && typeof data.error === 'object' ? data.error.message : data.error;
                    error = typeof message === 'string' ? message : error;
                }
            }
        } finally {
            await handle.close();
        }
        const argText = args === undefined ? null : typeof args === 'string' ? args : JSON.stringify(args, null, 2);
        const bounded = (text) => (typeof text === 'string' ? { text: text.slice(0, CALL_TEXT_MAX), chars: text.length } : null);
        return {
            toolCallId,
            agent: found.agent,
            seq: entry.seq,
            ts: entry.ts,
            status: entry.status,
            durationMs: entry.durationMs,
            arguments: bounded(argText),
            result: bounded(result),
            error: bounded(error),
        };
    }

    /** Runs, main-agent selections, and the prompt an agent received, matched by any of its names. */
    async #agentDefinition(names) {
        const candidates = this.#matchingRuns(names);
        // The newest runs are listed; the delivered prompt comes from the newest run of all.
        const runs = candidates.slice(-MAX_AGENT_RUNS).map((candidate) => this.#agentRun(candidate));
        const wanted = new Set(names.map(agentNameKey).filter(Boolean));
        const root = this.agents.get(ROOT_AGENT);
        const matches = (value) => wanted.has(agentNameKey(value));
        const selections = [...root.selections.values()].filter((item) => matches(item.name) || matches(item.displayName));
        const current = Boolean(root.customAgent && (matches(root.customAgent.name) || matches(root.customAgent.displayName)));
        let delivered = null;
        const latestRun = candidates.filter((candidate) => Number.isInteger(candidate.systemPrompt?.seq))
            .sort((a, b) => String(b.startTs ?? '').localeCompare(String(a.startTs ?? '')))[0];
        if (latestRun) {
            const seq = latestRun.systemPrompt.seq;
            const event = await this.#readEntryEvent(latestRun.key, seq);
            const lead = typeof event?.data?.content === 'string' ? leadingPromptText(event.data.content) : null;
            if (lead) {
                delivered = { ...lead, form: 'subagent', agentKey: latestRun.key, seq };
            }
        }
        if (!delivered) {
            for (const [agentName, seq] of root.agentPromptSeqs) {
                if (!matches(agentName)) {
                    continue;
                }
                const event = await this.#readEntryEvent(ROOT_AGENT, seq);
                const block = typeof event?.data?.content === 'string' ? agentInstructionsBlock(event.data.content) : null;
                if (block) {
                    delivered = { ...block, form: 'main', agentKey: ROOT_AGENT, seq };
                }
                break;
            }
        }
        return { runs, runTotal: candidates.length, selections, current, delivered };
    }

    async #canvasDefinition(agentKey, canvasId) {
        const canvas = this.canvases.get(canvasId) ?? null;
        const prompt = await this.#promptText(agentKey);
        let capabilities = null;
        if (canvas?.capabilities) {
            const event = await this.#readAt(canvas.capabilities.ref);
            const content = event?.data?.result && typeof event.data.result === 'object' ? event.data.result.content : null;
            if (typeof content === 'string') {
                capabilities = {
                    text: content.slice(0, DEFINITION_TEXT_MAX),
                    chars: content.length,
                    toolCallId: canvas.capabilities.toolCallId,
                    ts: typeof event.timestamp === 'string' ? event.timestamp : null,
                };
            }
        }
        const instances = [];
        for (const instance of this.canvasInstances.values()) {
            if (instance.canvasId === canvasId) {
                instances.push({ instanceId: instance.instanceId, title: instance.title, ts: instance.ts, removed: instance.removed, removedTs: instance.removedTs });
            }
        }
        return {
            promptEntry: prompt ? canvasPromptEntry(prompt.text, canvasId) : null,
            promptSeq: prompt?.seq ?? null,
            promptAgent: prompt?.agentKey ?? null,
            activity: canvas
                ? {
                    extensionId: canvas.extensionId,
                    calls: canvas.calls,
                    opens: canvas.opens,
                    actionCalls: canvas.actionCalls,
                    capabilityCalls: canvas.capabilityCalls,
                    failed: canvas.failed,
                    actions: [...canvas.actions].map(([action, count]) => ({ name: action, count })),
                    lastCallId: canvas.lastCallId,
                }
                : null,
            instances: instances.slice(-50),
            capabilities,
        };
    }

    async #hookDefinition(agent, type) {
        const bucket = agent.hookTypes.get(type);
        if (!bucket) {
            return { type, count: 0, failed: 0, contextCount: 0, sources: [], lastRun: null, latestFailure: null, latestContext: null };
        }
        const run = bucket.lastRun;
        let latestFailure = null;
        if (bucket.lastFailure) {
            const data = (await this.#readAt(bucket.lastFailure.ref))?.data;
            const error = data?.error;
            const message = error && typeof error === 'object' ? error.message : error;
            latestFailure = {
                ts: bucket.lastFailure.ts,
                source: error && typeof error === 'object' && typeof error.source === 'string' ? error.source : null,
                message: typeof message === 'string' ? message.slice(0, PROMPT_ENTRY_MAX) : null,
            };
        }
        let latestContext = null;
        if (bucket.lastContext) {
            const text = (await this.#readAt(bucket.lastContext.ref))?.data?.output?.additionalContext;
            if (typeof text === 'string') {
                latestContext = { ts: bucket.lastContext.ts, text: text.slice(0, DEFINITION_TEXT_MAX), chars: text.length };
            }
        }
        return {
            type,
            count: bucket.count,
            failed: bucket.failed,
            contextCount: bucket.contextCount,
            sources: [...bucket.sources].map(([source, info]) => ({ source, failed: info.failed, error: info.error, ts: info.ts })),
            lastRun: run ? { ts: run.ts, status: run.status, durationMs: run.durationMs, error: run.error, tool: run.tool, seq: this.hookTurns.get(run)?.seq ?? null } : null,
            latestFailure,
            latestContext,
        };
    }

    /** Subagents that ran as any of the given agent names, oldest first. */
    #matchingRuns(names) {
        const wanted = new Set(names.map(agentNameKey).filter(Boolean));
        if (wanted.size === 0) {
            return [];
        }
        return [...this.agents.values()].filter((candidate) => candidate.key !== ROOT_AGENT
            && [candidate.agentType, candidate.name, candidate.displayName].map(agentNameKey).some((key) => key && wanted.has(key)));
    }

    #agentRun(candidate) {
        return {
            key: candidate.key,
            name: candidate.name,
            displayName: candidate.displayName,
            agentType: candidate.agentType,
            description: candidate.description,
            executionMode: candidate.executionMode,
            model: candidate.model,
            status: candidate.status,
            startTs: candidate.startTs,
            endTs: candidate.endTs,
            durationMs: candidate.durationMs,
            totalToolCalls: candidate.totalToolCalls,
            totalTokens: candidate.totalTokens,
            usage: { inputTokens: candidate.usage.inputTokens, outputTokens: candidate.usage.outputTokens },
            systemPromptSeq: candidate.systemPrompt?.seq ?? null,
        };
    }

    /** Re-reads the latest system prompt of an agent, or of the main agent when it has none. */
    async #promptText(agentKey) {
        const owner = this.agents.get(agentKey)?.systemPrompt ? agentKey : ROOT_AGENT;
        const seq = this.agents.get(owner)?.systemPrompt?.seq;
        const event = Number.isInteger(seq) ? await this.#readEntryEvent(owner, seq) : null;
        if (event?.type !== 'system.message' || typeof event.data?.content !== 'string') {
            return null;
        }
        return { agentKey: owner, seq, text: event.data.content };
    }

    async #skillInvocation(agentKey, seq, name) {
        const event = Number.isInteger(seq) ? await this.#readEntryEvent(agentKey, seq) : null;
        if (!event || !String(event.type).startsWith('skill.invoked')) {
            return null;
        }
        const data = event.data && typeof event.data === 'object' ? event.data : {};
        let content = typeof data.content === 'string' ? data.content : null;
        let resolvedFrom = null;
        if (content === null && typeof data.contentId === 'string') {
            const ref = this.skillContents.get(data.contentId);
            const original = ref ? await this.#readAt(ref) : null;
            if (typeof original?.data?.content === 'string') {
                content = original.data.content;
                resolvedFrom = 'earlier load';
            }
        }
        const contentId = typeof data.contentId === 'string'
            ? data.contentId
            : content !== null ? `sha256:${createHash('sha256').update(content, 'utf8').digest('hex')}` : null;
        const delivery = this.#skillDelivery(agentKey, name, contentId);
        const wrapper = delivery ? (await this.#readAt(delivery.ref))?.data : null;
        let delivered = null;
        let wrapped = false;
        if (delivery?.full && typeof wrapper?.content === 'string') {
            // The complete text the agent received, wrapper included.
            delivered = wrapper.content;
            wrapped = true;
        } else if (content !== null) {
            const prefix = typeof wrapper?.prefix === 'string' ? wrapper.prefix.slice(0, PROMPT_ENTRY_MAX) : '';
            const suffix = typeof wrapper?.suffix === 'string' ? wrapper.suffix.slice(0, PROMPT_ENTRY_MAX) : '';
            delivered = `${prefix}${content}${suffix}`;
            wrapped = Boolean(prefix || suffix);
        }
        return {
            seq,
            ts: typeof event.timestamp === 'string' ? event.timestamp : null,
            trigger: typeof data.trigger === 'string' ? data.trigger : null,
            invokedAtTurn: numberOrNull(data.invokedAtTurn),
            path: typeof data.path === 'string' ? data.path : null,
            source: typeof data.source === 'string' ? data.source : null,
            pluginName: typeof data.pluginName === 'string' ? data.pluginName : null,
            description: typeof data.description === 'string' ? oneLine(data.description, 1000) : null,
            allowedTools: Array.isArray(data.allowedTools) ? data.allowedTools.filter((item) => typeof item === 'string').slice(0, 100) : [],
            content: delivered === null ? null : delivered.slice(0, DEFINITION_TEXT_MAX),
            contentChars: delivered?.length ?? numberOrNull(data.contentLength) ?? 0,
            truncated: delivered !== null && delivered.length > DEFINITION_TEXT_MAX,
            wrapped,
            resolvedFrom,
        };
    }

    /**
     * Finds the context delivery an agent received for a skill load: the reference delivery that wraps
     * the same content, else the agent's latest delivery of that skill unless it wraps other content.
     */
    #skillDelivery(agentKey, name, contentId) {
        const matched = contentId ? this.skillDeliveriesByContent.get(`${agentKey}\n${contentId}`) : null;
        if (matched) {
            return matched;
        }
        const latest = this.skillDeliveries.get(`${agentKey}\n${name}`) ?? null;
        return latest && latest.contentId && contentId && latest.contentId !== contentId ? null : latest;
    }

    async #readAt(ref) {
        const handle = await this.#openFile();
        try {
            return await readEvent(handle, ref[0], ref[1]);
        } finally {
            await handle.close();
        }
    }

    async #readEntryEvent(agentKey, seq) {
        const located = this.findEntry(agentKey, { seq });
        const ref = located ? this.agents.get(located.agent).entries[located.index].parts[0] : null;
        return ref ? this.#readAt(ref) : null;
    }

    /**
     * Finds the entry index for a sequence number or tool call.
     *
     * @param {string} agentKey
     * @param {{ seq?: number, toolCallId?: string }} anchor
     */
    findEntry(agentKey, anchor) {
        if (typeof anchor.toolCallId === 'string') {
            const ref = this.tools.get(anchor.toolCallId);
            return ref ? { agent: ref.agent, index: ref.index } : null;
        }
        const agent = this.agents.get(agentKey);
        if (!agent || !Number.isInteger(anchor.seq)) {
            return null;
        }
        const index = binarySearchSeq(agent.entries, anchor.seq);
        return index >= 0 ? { agent: agentKey, index } : null;
    }

    /**
     * Adds capped message bodies to user and assistant entries, and argument and output previews
     * to tool entries, by re-reading their events.
     *
     * @param {Array<object>} entries Entries from this index.
     * @returns {Promise<Array<object>>} Shallow copies with `body`, or `preview` for tools, where available.
     */
    async withBodies(entries) {
        const targets = entries.filter((entry) => (entry.kind === 'user' || entry.kind === 'assistant' || entry.kind === 'tool') && entry.parts.length > 0);
        if (targets.length === 0) {
            return entries;
        }
        const extra = new Map();
        const handle = await this.#openFile();
        try {
            for (const entry of targets) {
                if (entry.kind === 'tool') {
                    extra.set(entry, { preview: await this.#toolPreview(handle, entry) });
                    continue;
                }
                const [offset, length] = entry.parts[0];
                const event = await readEvent(handle, offset, length);
                const content = typeof event?.data?.content === 'string' ? event.data.content : '';
                extra.set(entry, { body: content.length > this.options.bodyChars ? content.slice(0, this.options.bodyChars) : content });
            }
        } finally {
            await handle.close();
        }
        return entries.map((entry) => (extra.has(entry) ? { ...entry, ...extra.get(entry) } : entry));
    }

    /**
     * Builds the start of a tool's arguments and the end of its output or error.
     *
     * @param {import('node:fs/promises').FileHandle} handle
     * @param {object} entry Tool entry.
     */
    async #toolPreview(handle, entry) {
        const max = this.options.previewChars;
        const preview = { args: null, argsChars: 0, argsJson: false, output: null, outputChars: 0, outputPart: null, outputPath: null, error: null, errorChars: 0 };
        for (let part = 0; part < Math.min(entry.parts.length, 6); part += 1) {
            const [offset, length] = entry.parts[part];
            const event = await readEvent(handle, offset, length);
            const data = event?.data && typeof event.data === 'object' ? event.data : null;
            if (!data) {
                continue;
            }
            if ((event.type === 'tool.execution_start' || event.type === 'external_tool.requested') && data.arguments !== undefined && preview.args === null) {
                const text = typeof data.arguments === 'string' ? data.arguments : JSON.stringify(data.arguments, null, 2) ?? '';
                preview.args = text.slice(0, max);
                preview.argsChars = text.length;
                preview.argsJson = typeof data.arguments === 'object' && data.arguments !== null;
            } else if (event.type === 'tool.execution_complete') {
                const error = typeof data.error === 'string' ? data.error : data.error && typeof data.error === 'object' ? [data.error.message, data.error.code ? `(${data.error.code})` : null].filter(Boolean).join(' ') : '';
                if (error) {
                    preview.error = error.length > max ? error.slice(-max) : error;
                    preview.errorChars = error.length;
                }
                const result = data.result && typeof data.result === 'object' ? data.result : {};
                const path = typeof result.content === 'string' && result.content.length > 0 ? 'content' : typeof result.detailedContent === 'string' && result.detailedContent.length > 0 ? 'detailedContent' : null;
                if (path) {
                    const text = result[path];
                    preview.output = text.length > max ? text.slice(-max) : text;
                    preview.outputChars = text.length;
                    preview.outputPart = part;
                    preview.outputPath = `data.result.${path}`;
                }
            }
        }
        return preview;
    }

    /**
     * Reads the recorded events behind an entry, with long strings returned in pages.
     *
     * @param {string} agentKey
     * @param {number} seq
     */
    async readDetail(agentKey, seq, hook = null) {
        const located = this.findEntry(agentKey, { seq });
        if (!located) {
            return null;
        }
        const entry = this.agents.get(located.agent).entries[located.index];
        const parts = partsFor(entry, hook);
        if (!parts) {
            return null;
        }
        const truncated = [];
        const events = [];
        const handle = await this.#openFile();
        try {
            for (let part = 0; part < parts.length; part += 1) {
                const [offset, length] = parts[part];
                const event = await readEvent(handle, offset, length);
                if (!event) {
                    continue;
                }
                const projected = projectDetail(event, part, this.options.pageChars, truncated);
                events.push(projected);
            }
        } finally {
            await handle.close();
        }
        return { entry, events, truncated, pageChars: this.options.pageChars };
    }

    /**
     * Reads one page of a long string field from an entry's event.
     *
     * @param {string} agentKey
     * @param {number} seq
     * @param {number} part Event index within the entry.
     * @param {string} fieldPath Dot-separated path such as `data.content`.
     * @param {number} start Character offset.
     */
    async readField(agentKey, seq, part, fieldPath, start, hook = null) {
        const located = this.findEntry(agentKey, { seq });
        if (!located) {
            return null;
        }
        const entry = this.agents.get(located.agent).entries[located.index];
        const ref = partsFor(entry, hook)?.[part];
        if (!ref) {
            return null;
        }
        const segments = parseFieldPath(fieldPath);
        if (!segments) {
            return null;
        }
        const handle = await this.#openFile();
        let event;
        try {
            event = await readEvent(handle, ref[0], ref[1]);
        } finally {
            await handle.close();
        }
        let value = event;
        for (const segment of segments) {
            if (value === null || typeof value !== 'object' || !Object.hasOwn(value, segment)) {
                return null;
            }
            value = value[segment];
        }
        if (typeof value !== 'string') {
            return null;
        }
        const from = clamp(start, 0, value.length);
        const text = value.slice(from, from + this.options.pageChars);
        const next = from + text.length < value.length ? from + text.length : null;
        return { text, start: from, length: value.length, next };
    }
}

/**
 * Keeps a bounded number of session indexes in memory.
 */
export class IndexCache {
    /**
     * @param {(sessionId: string) => string} fileFor Maps a session ID to its `events.jsonl` path.
     * @param {{ max?: number, indexOptions?: object }} [options]
     */
    constructor(fileFor, options = {}) {
        this.fileFor = fileFor;
        this.max = options.max ?? 3;
        this.indexOptions = options.indexOptions ?? {};
        /** @type {Map<string, SessionIndex>} */
        this.indexes = new Map();
    }

    /**
     * @param {string} sessionId
     * @returns {SessionIndex}
     */
    get(sessionId) {
        let index = this.indexes.get(sessionId);
        if (index) {
            this.indexes.delete(sessionId);
            this.indexes.set(sessionId, index);
            return index;
        }
        index = new SessionIndex(this.fileFor(sessionId), this.indexOptions);
        this.indexes.set(sessionId, index);
        while (this.indexes.size > this.max) {
            const oldest = this.indexes.keys().next().value;
            this.indexes.delete(oldest);
        }
        return index;
    }

    has(sessionId) {
        return this.indexes.has(sessionId);
    }
}

async function readEvent(handle, offset, length) {
    const buffer = Buffer.allocUnsafe(length);
    const { bytesRead } = await handle.read(buffer, 0, length, offset);
    try {
        return JSON.parse(buffer.subarray(0, bytesRead).toString('utf8'));
    } catch {
        return null;
    }
}

/**
 * Projects a recorded event for display: drops opaque reasoning payloads,
 * summarizes system-prompt blocks, and pages long strings.
 */
export function projectDetail(event, part, pageChars, truncated) {
    const data = event.data && typeof event.data === 'object' ? { ...event.data } : event.data;
    if (event.type === 'system.message' && data && Array.isArray(data.contentBlocks)) {
        data.contentBlocks = data.contentBlocks.map((block) => ({
            chars: typeof block?.content === 'string' ? block.content.length : 0,
            isStatic: block?.isStatic === true,
            cacheBreakpoint: block?.cacheBreakpoint === true,
        }));
    }
    const projected = {
        type: event.type,
        timestamp: event.timestamp ?? null,
        agentId: event.agentId ?? null,
        data: trimValue(data, ['data'], part, pageChars, truncated, 0),
    };
    return projected;
}

function trimValue(value, pathSegments, part, pageChars, truncated, depth) {
    if (typeof value === 'string') {
        if (value.length > pageChars) {
            truncated.push({ part, path: pathSegments.join('.'), length: value.length, next: pageChars });
            return value.slice(0, pageChars);
        }
        return value;
    }
    if (depth > 12 || value === null || typeof value !== 'object') {
        return value;
    }
    if (Array.isArray(value)) {
        return value.map((item, index) => trimValue(item, [...pathSegments, String(index)], part, pageChars, truncated, depth + 1));
    }
    const out = {};
    for (const [key, item] of Object.entries(value)) {
        if (DROPPED_DETAIL_KEYS.has(key)) {
            continue;
        }
        out[key] = trimValue(item, [...pathSegments, key], part, pageChars, truncated, depth + 1);
    }
    return out;
}

/**
 * @param {unknown} error
 * @returns {boolean} True when the error means the file or folder does not exist.
 */
function isMissing(error) {
    const code = /** @type {NodeJS.ErrnoException} */ (error)?.code;
    return code === 'ENOENT' || code === 'ENOTDIR';
}

/**
 * Validates a dot-separated field path into segments.
 *
 * @param {unknown} fieldPath
 * @returns {string[] | null}
 */
export function parseFieldPath(fieldPath) {
    if (typeof fieldPath !== 'string' || fieldPath.length === 0 || fieldPath.length > 512) {
        return null;
    }
    const segments = fieldPath.split('.');
    if (segments.length > 16 || segments.some((segment) => !FIELD_SEGMENT_RE.test(segment) || segment === '__proto__' || segment === 'constructor' || segment === 'prototype')) {
        return null;
    }
    return segments;
}

function binarySearchSeq(entries, seq) {
    let low = 0;
    let high = entries.length - 1;
    while (low <= high) {
        const mid = (low + high) >> 1;
        const value = entries[mid].seq;
        if (value === seq) {
            return mid;
        }
        if (value < seq) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return -1;
}

function notificationLabel(type) {
    switch (type) {
        case 'agent_idle':
            return 'Agent idle';
        case 'agent_completed':
            return 'Agent completed';
        case 'shell_completed':
        case 'shell_detached_completed':
            return 'Shell completed';
        case 'instruction_discovered':
            return 'Instructions discovered';
        case 'new_inbox_message':
            return 'New message';
        case 'workflow_completed':
            return 'Workflow completed';
        default:
            return 'Notification';
    }
}

/**
 * @param {object} data Compaction event data.
 * @returns {{ system: number | null, conversation: number | null, tools: number | null } | null}
 */
function tokenSplit(data) {
    const split = { system: numberOrNull(data.systemTokens), conversation: numberOrNull(data.conversationTokens), tools: numberOrNull(data.toolDefinitionsTokens) };
    return split.system === null && split.conversation === null && split.tools === null ? null : split;
}

/**
 * Returns the text of a chat message whose content is a string or a list of parts.
 *
 * @param {unknown} message
 * @returns {string}
 */
export function messageText(message) {
    const content = message && typeof message === 'object' ? /** @type {{ content?: unknown }} */ (message).content : undefined;
    if (typeof content === 'string') {
        return content;
    }
    if (Array.isArray(content)) {
        return content.map((part) => (part && typeof part === 'object' && typeof part.text === 'string' ? part.text : '')).filter(Boolean).join('\n');
    }
    return '';
}

/**
 * Summarizes a messages snapshot by size only: its last user message is the request, and a
 * final assistant message is the response.
 */
function snapshotCandidate(messages, offset, length) {
    let requestChars = 0;
    for (let i = messages.length - 1; i >= 0; i -= 1) {
        if (messages[i]?.role === 'user') {
            requestChars = messageText(messages[i]).length;
            break;
        }
    }
    if (requestChars === 0) {
        return null;
    }
    const last = messages[messages.length - 1];
    return { offset, length, requestChars, responseChars: last?.role === 'assistant' ? messageText(last).length : null, messages: messages.length };
}

/**
 * Picks the snapshot of the compaction call: the one whose final assistant message matches the
 * recorded summary length. Unmatched snapshots belong to other model calls and are ignored.
 */
function pickCompactionRequest(candidates, summaryChars) {
    if (!Number.isInteger(summaryChars) || summaryChars <= 0) {
        return null;
    }
    for (let i = candidates.length - 1; i >= 0; i -= 1) {
        if (candidates[i].responseChars === summaryChars) {
            return candidates[i];
        }
    }
    return null;
}

/**
 * @param {object} entry
 * @param {number | null} hook Hook run index on a turn entry, or null for the entry itself.
 * @returns {Array<[number, number]> | null}
 */
function partsFor(entry, hook) {
    if (hook === null || hook === undefined) {
        return entry.parts;
    }
    return entry.kind === 'turn' && Array.isArray(entry.hookRuns) ? entry.hookRuns[hook]?.parts ?? null : null;
}

function withoutParts(value) {
    const copy = { ...value };
    delete copy.parts;
    return copy;
}

/**
 * Copies an index entry for an API response without the byte offsets of its events or hook runs.
 * Recorded payloads are never passed through here, so their own `parts` fields stay intact.
 *
 * @param {object} entry Entry from this index, or a shallow copy of one.
 * @returns {object}
 */
export function publicEntry(entry) {
    const copy = withoutParts(entry);
    if (Array.isArray(copy.hookRuns)) {
        copy.hookRuns = copy.hookRuns.map(withoutParts);
    }
    return copy;
}

function elapsed(fromIso, toIso) {
    const from = typeof fromIso === 'string' ? Date.parse(fromIso) : NaN;
    const to = typeof toIso === 'string' ? Date.parse(toIso) : NaN;
    return Number.isFinite(from) && Number.isFinite(to) && to >= from ? to - from : null;
}

function num(value) {
    return Number.isFinite(value) ? value : 0;
}

function numberOrNull(value) {
    return Number.isFinite(value) ? value : null;
}

function clamp(value, min, max) {
    const number = Number.isFinite(value) ? Math.trunc(value) : min;
    return Math.min(Math.max(number, min), max);
}
