// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Live, model-facing definitions of what the session offers the model (tools, agents, skills,
// instructions, canvases, MCP servers, plugins, and extensions), one item at a time, plus short
// catalogs for the inspector's Context lists.

import { agentNameKey, oneLine } from './indexer.mjs';
import { redactCredentials, redactProse, timed } from './inventory.mjs';

/** Kinds the definition route accepts. */
export const DEFINITION_KINDS = Object.freeze(['tool', 'agent', 'skill', 'instruction', 'canvas', 'mcp', 'hook', 'plugin', 'extension']);

/** Kinds with a live source; hooks are known only from their recorded runs. */
export const LIVE_DEFINITION_KINDS = Object.freeze(['tool', 'agent', 'skill', 'instruction', 'canvas', 'mcp', 'plugin', 'extension']);

const TEXT_MAX = 256 * 1024;
const SHORT_TEXT_MAX = 8 * 1024;
const SCHEMA_MAX = 128 * 1024;
const SCHEMA_STRING_MAX = 16 * 1024;
const SCHEMA_DEPTH_MAX = 32;
const SCHEMA_ITEMS_MAX = 500;
const LIST_MAX = 2000;
const LISTING_MAX = 4 * 1024;

function str(value, max = 400) {
    return typeof value === 'string' && value.length > 0 ? value.slice(0, max) : null;
}

function bool(value) {
    return typeof value === 'boolean' ? value : null;
}

function strings(value, max = 500) {
    return Array.isArray(value) ? value.filter((item) => typeof item === 'string').slice(0, max).map((item) => item.slice(0, 400)) : null;
}

function label(value) {
    if (typeof value === 'string') {
        return str(value, 80);
    }
    if (value && typeof value === 'object') {
        return str(value.type ?? value.kind ?? value.name ?? null, 80);
    }
    return null;
}

function longText(value, max = TEXT_MAX) {
    if (typeof value !== 'string') {
        return { text: null, chars: 0, truncated: false };
    }
    return { text: redactProse(value, max), chars: value.length, truncated: value.length > max };
}

/**
 * Copies a JSON value with bounded depth, breadth, and string length, redacting tokens in strings.
 *
 * @param {unknown} value
 * @param {number} [depth]
 * @returns {unknown}
 */
export function boundedJson(value, depth = 0) {
    if (typeof value === 'string') {
        return redactProse(value, SCHEMA_STRING_MAX);
    }
    if (value === null || typeof value === 'number' || typeof value === 'boolean') {
        return value;
    }
    if (typeof value !== 'object') {
        return null;
    }
    if (depth >= SCHEMA_DEPTH_MAX) {
        return '[nested too deeply]';
    }
    if (Array.isArray(value)) {
        return value.slice(0, SCHEMA_ITEMS_MAX).map((item) => boundedJson(item, depth + 1));
    }
    const out = {};
    for (const key of Object.keys(value).slice(0, SCHEMA_ITEMS_MAX)) {
        out[key] = boundedJson(value[key], depth + 1);
    }
    return out;
}

/** Field allowlists for live definitions. */
export const projectDefinition = Object.freeze({
    tool(meta) {
        const schema = meta?.input_schema && typeof meta.input_schema === 'object' ? boundedJson(meta.input_schema) : null;
        const schemaTooLarge = schema !== null && JSON.stringify(schema).length > SCHEMA_MAX;
        return {
            name: str(meta?.name, 200),
            namespacedName: str(meta?.namespacedName, 200),
            mcpServerName: str(meta?.mcpServerName, 200),
            mcpToolName: str(meta?.mcpToolName, 200),
            deferLoading: bool(meta?.deferLoading),
            schemaTooLarge,
            definition: {
                name: str(meta?.name, 200),
                description: redactProse(typeof meta?.description === 'string' ? meta.description : '', TEXT_MAX),
                input_schema: schemaTooLarge ? null : schema,
            },
        };
    },
    agent(info) {
        const prompt = longText(info?.prompt);
        return {
            id: str(info?.id, 200),
            name: str(info?.name, 200),
            displayName: str(info?.displayName, 200),
            description: redactProse(str(info?.description, SHORT_TEXT_MAX), SHORT_TEXT_MAX),
            path: str(info?.path, 1000),
            source: label(info?.source),
            userInvocable: bool(info?.userInvocable),
            disableModelInvocation: bool(info?.disableModelInvocation),
            tools: strings(info?.tools),
            model: str(info?.model, 120),
            models: strings(info?.models, 20),
            modelPolicy: label(info?.modelPolicy),
            reasoningEffort: str(info?.reasoningEffort, 40),
            skills: strings(info?.skills),
            mcpServers: mcpServerSummaries(info?.mcpServers),
            prompt: prompt.text,
            promptChars: prompt.chars,
            promptTruncated: prompt.truncated,
        };
    },
    skill(skill) {
        return {
            name: str(skill?.name, 200),
            commandName: str(skill?.commandName, 200),
            description: redactProse(str(skill?.description, SHORT_TEXT_MAX), SHORT_TEXT_MAX),
            source: label(skill?.source),
            pluginName: str(skill?.pluginName, 200),
            path: str(skill?.path, 1000),
            argumentHint: str(skill?.argumentHint, 400),
            enabled: bool(skill?.enabled),
            userInvocable: bool(skill?.userInvocable),
        };
    },
    instruction(source) {
        const content = longText(source?.content);
        return {
            label: str(source?.label, 200),
            sourcePath: str(source?.sourcePath, 1000),
            type: label(source?.type),
            location: label(source?.location),
            applyTo: strings(source?.applyTo, 20) ?? [],
            description: redactProse(str(source?.description, SHORT_TEXT_MAX), SHORT_TEXT_MAX),
            defaultDisabled: bool(source?.defaultDisabled),
            content: content.text,
            contentChars: content.chars,
            contentTruncated: content.truncated,
        };
    },
    canvas(canvas) {
        const schema = (value) => (value && typeof value === 'object' ? boundedJson(value) : null);
        return {
            canvasId: str(canvas?.canvasId, 200),
            displayName: str(canvas?.displayName, 200),
            description: redactProse(str(canvas?.description, SHORT_TEXT_MAX), SHORT_TEXT_MAX),
            extensionId: str(canvas?.extensionId, 200),
            extensionName: str(canvas?.extensionName, 200),
            inputSchema: schema(canvas?.inputSchema),
            actions: Array.isArray(canvas?.actions)
                ? canvas.actions.slice(0, 100).map((action) => ({
                    name: str(action?.name, 200),
                    description: redactProse(str(action?.description, SHORT_TEXT_MAX), SHORT_TEXT_MAX),
                    inputSchema: schema(action?.inputSchema),
                }))
                : [],
        };
    },
    mcp(server) {
        const metadata = server?.serverMetadata && typeof server.serverMetadata === 'object' ? server.serverMetadata : {};
        const instructions = longText(metadata.instructions, 64 * 1024);
        return {
            name: str(server?.name, 200),
            displayName: str(server?.displayName, 200),
            status: label(server?.status),
            source: label(server?.source),
            sourcePlugin: str(server?.sourcePlugin, 200),
            sourcePluginVersion: str(server?.sourcePluginVersion, 80),
            url: typeof server?.url === 'string' ? safeUrl(server.url) : null,
            error: typeof server?.error === 'string' ? redactCredentials(server.error.slice(0, 2000)) : null,
            instructions: instructions.text,
            instructionsChars: instructions.chars,
            instructionsTruncated: instructions.truncated,
        };
    },
    plugin(plugin) {
        return {
            name: str(plugin?.name, 200),
            marketplace: str(plugin?.marketplace, 200),
            version: str(plugin?.version, 80),
            enabled: bool(plugin?.enabled),
            source: label(plugin?.source),
            installedFrom: typeof plugin?.installedFrom === 'string' ? safeUrl(plugin.installedFrom) : null,
            managed: bool(plugin?.managed),
            installed: bool(plugin?.installed),
        };
    },
    extension(extension) {
        return {
            id: str(extension?.id, 200),
            name: str(extension?.name, 200),
            source: label(extension?.source),
            status: label(extension?.status),
        };
    },
});

/**
 * Lists the agent types the `task` tool lets the model launch, with the line the model reads for
 * each. Built-in types are listed before the "User-provided custom agents" heading.
 *
 * @param {{ description?: unknown, input_schema?: any } | null | undefined} meta Task tool metadata.
 * @returns {Array<{ name: string, description: string, builtIn: boolean | null }>}
 */
export function subagentCatalog(meta) {
    const description = typeof meta?.description === 'string' ? meta.description : '';
    const customAt = description.indexOf('User-provided custom agents');
    const listed = new Map();
    const bullet = /^\s*[-*]\s+\*\*(.+?)\*\*\s*:[ \t]*(.*)$/gm;
    let match;
    while ((match = bullet.exec(description)) !== null && listed.size < LIST_MAX) {
        const name = match[1].trim();
        if (!listed.has(name)) {
            listed.set(name, { summary: match[2], builtIn: customAt < 0 ? null : match.index < customAt });
        }
    }
    const values = meta?.input_schema?.properties?.agent_type?.enum;
    const names = Array.isArray(values) ? [...new Set(values.filter((value) => typeof value === 'string' && value))] : [...listed.keys()];
    const byKey = new Map([...listed].map(([name, info]) => [agentNameKey(name), info]));
    return names.slice(0, LIST_MAX).map((name) => {
        const info = listed.get(name) ?? byKey.get(agentNameKey(name)) ?? null;
        return { name: name.slice(0, 200), description: redactProse(oneLine(info?.summary ?? '', 300), 300), builtIn: info ? info.builtIn : null };
    });
}

/**
 * Reduces an agent's MCP server configurations to names, transports, and credential-free
 * locations. Arguments, environment variables, and headers never leave the extension.
 *
 * @param {unknown} servers
 * @returns {Array<{ name: string, type: string | null, command: string | null, url: string | null }>}
 */
export function mcpServerSummaries(servers) {
    if (!servers || typeof servers !== 'object' || Array.isArray(servers)) {
        return [];
    }
    return Object.entries(servers).slice(0, 50).map(([name, config]) => {
        const cfg = config && typeof config === 'object' ? config : {};
        return {
            name: name.slice(0, 200),
            type: label(cfg.type) ?? (typeof cfg.url === 'string' ? 'http' : typeof cfg.command === 'string' ? 'stdio' : null),
            command: typeof cfg.command === 'string' ? redactCredentials(cfg.command.slice(0, 400)) : null,
            url: typeof cfg.url === 'string' ? safeUrl(cfg.url) : null,
        };
    });
}

/** Keeps a URL's scheme, host, and path; drops credentials and the query; redacts tokens in the path. */
function safeUrl(value) {
    try {
        const url = new URL(value);
        let pathname = url.pathname;
        try {
            pathname = decodeURIComponent(pathname);
        } catch {
            // Keep the encoded path when it does not decode.
        }
        return redactProse(`${url.protocol}//${url.host}${pathname}`, 400);
    } catch {
        return redactCredentials(value.slice(0, 400));
    }
}

/**
 * Returns the lines of the `task` tool description that list one agent type to the model.
 *
 * @param {string} description Task tool description.
 * @param {string[]} names Agent identifiers to match.
 * @returns {string | null}
 */
export function agentListing(description, names) {
    if (typeof description !== 'string') {
        return null;
    }
    const wanted = new Set(names.map(agentNameKey).filter(Boolean));
    const lines = description.split('\n');
    const bullet = /^\s*[-*]\s+\*\*(.+?)\*\*\s*:/;
    for (let i = 0; i < lines.length; i += 1) {
        const match = bullet.exec(lines[i]);
        if (!match || !wanted.has(agentNameKey(match[1]))) {
            continue;
        }
        const out = [lines[i]];
        for (let j = i + 1; j < lines.length && !bullet.test(lines[j]) && lines[j].trim() !== ''; j += 1) {
            out.push(lines[j]);
        }
        return redactProse(out.join('\n'), LISTING_MAX);
    }
    return null;
}

function findAgent(agents, name) {
    const exact = agents.find((item) => item?.name === name || item?.id === name || item?.displayName === name);
    if (exact) {
        return exact;
    }
    const key = agentNameKey(name);
    return key ? agents.find((item) => [item?.name, item?.id, item?.displayName].some((value) => agentNameKey(value) === key)) ?? null : null;
}

function matchesPath(a, b) {
    return typeof a === 'string' && typeof b === 'string' && (a === b || a.endsWith(`/${b}`) || b.endsWith(`/${a}`));
}

/**
 * Creates a provider that looks up one live definition at a time from the joined session.
 * Each underlying list is fetched with a timeout, shared by concurrent lookups, cached briefly,
 * and released after the cache period so large prompt text is not held in memory.
 *
 * @param {{ rpc?: any } | null | undefined} session Joined Copilot session.
 * @param {{ timeoutMs?: number, ttlMs?: number, now?: () => number }} [options]
 */
export function createLiveDefinitionProvider(session, options = {}) {
    const timeoutMs = options.timeoutMs ?? 4000;
    const ttlMs = options.ttlMs ?? 30000;
    const now = options.now ?? Date.now;
    const values = new Map();
    const pending = new Map();

    function call(namespace, method, params) {
        return timed(() => {
            const rpc = session?.rpc;
            const target = rpc?.[namespace]?.[method];
            if (typeof target !== 'function') {
                throw new Error('unavailable');
            }
            return params === undefined ? target.call(rpc[namespace]) : target.call(rpc[namespace], params);
        }, timeoutMs);
    }

    function cached(key, load) {
        const hit = values.get(key);
        if (hit && now() - hit.at < ttlMs) {
            return Promise.resolve(hit.value);
        }
        let inflight = pending.get(key);
        if (!inflight) {
            inflight = load()
                .then((value) => {
                    values.set(key, { at: now(), value });
                    const timer = setTimeout(() => {
                        if (values.get(key)?.value === value) {
                            values.delete(key);
                        }
                    }, ttlMs);
                    timer.unref?.();
                    return value;
                })
                .finally(() => pending.delete(key));
            pending.set(key, inflight);
        }
        return inflight;
    }

    function list(kind, namespace, method, params, field) {
        return cached(kind, async () => {
            const result = await call(namespace, method, params);
            if (!result.ok) {
                return { status: 'unavailable', items: [] };
            }
            const items = result.value?.[field];
            if (items === null && kind === 'tool') {
                return { status: 'not-initialized', items: [] };
            }
            return Array.isArray(items) ? { status: 'live', items: items.slice(0, LIST_MAX) } : { status: 'unavailable', items: [] };
        });
    }

    const lists = {
        tool: () => list('tool', 'tools', 'getCurrentMetadata', undefined, 'tools'),
        agent: () => list('agent', 'agent', 'list', { includeBuiltInAgents: true, includePrompt: true }, 'agents'),
        skill: () => list('skill', 'skills', 'list', undefined, 'skills'),
        instruction: () => list('instruction', 'instructions', 'getSources', undefined, 'sources'),
        canvas: () => list('canvas', 'canvas', 'list', undefined, 'canvases'),
        mcp: () => list('mcp', 'mcp', 'list', undefined, 'servers'),
        plugin: () => list('plugin', 'plugins', 'list', undefined, 'plugins'),
        extension: () => list('extension', 'extensions', 'list', undefined, 'extensions'),
    };

    /**
     * Looks up one item by kind and name.
     *
     * @param {'tool' | 'agent' | 'skill' | 'instruction' | 'canvas' | 'mcp' | 'plugin' | 'extension'} kind
     * @param {string} name Tool, agent, skill, canvas, MCP server, plugin, or extension name, or instruction path.
     * @returns {Promise<{ status: string, item: object | null, listing?: string | null }>}
     */
    async function lookup(kind, name) {
        const source = lists[kind];
        if (!source) {
            return { status: 'unavailable', item: null };
        }
        const { status, items } = await source();
        if (status !== 'live') {
            return { status, item: null };
        }
        switch (kind) {
            case 'tool': {
                const meta = items.find((item) => item?.name === name) ?? items.find((item) => item?.namespacedName === name);
                return { status: meta ? 'live' : 'not-offered', item: meta ? projectDefinition.tool(meta) : null };
            }
            case 'agent': {
                const info = findAgent(items, name);
                const tools = await lists.tool();
                const task = tools.items.find((item) => item?.name === 'task');
                const names = info ? [name, info.name, info.id, info.displayName] : [name];
                return {
                    status: info ? 'live' : 'not-found',
                    item: info ? projectDefinition.agent(info) : null,
                    listing: agentListing(task?.description, names.filter((value) => typeof value === 'string')),
                };
            }
            case 'skill': {
                const skill = items.find((item) => item?.name === name) ?? items.find((item) => item?.commandName === name);
                return { status: skill ? 'live' : 'not-found', item: skill ? projectDefinition.skill(skill) : null };
            }
            case 'instruction': {
                const entry = items.find((item) => matchesPath(item?.sourcePath, name)) ?? items.find((item) => item?.label === name);
                return { status: entry ? 'live' : 'not-found', item: entry ? projectDefinition.instruction(entry) : null };
            }
            case 'canvas': {
                const canvas = items.find((item) => item?.canvasId === name);
                return { status: canvas ? 'live' : 'not-found', item: canvas ? projectDefinition.canvas(canvas) : null };
            }
            case 'mcp': {
                const server = items.find((item) => item?.name === name) ?? items.find((item) => item?.displayName === name);
                return { status: server ? 'live' : 'not-found', item: server ? projectDefinition.mcp(server) : null };
            }
            case 'plugin': {
                const plugin = items.find((item) => item?.name === name);
                return { status: plugin ? 'live' : 'not-found', item: plugin ? projectDefinition.plugin(plugin) : null };
            }
            default: {
                const extension = items.find((item) => item?.name === name) ?? items.find((item) => item?.id === name);
                return { status: extension ? 'live' : 'not-found', item: extension ? projectDefinition.extension(extension) : null };
            }
        }
    }

    /**
     * Returns a short list for the inspector's Context sections: offered tools, declared
     * canvases, or the agent types the task tool can launch.
     *
     * @param {'tool' | 'canvas' | 'subagent'} kind
     * @returns {Promise<{ status: string, items: object[] }>}
     */
    async function catalog(kind) {
        if (kind === 'canvas') {
            const { status, items } = await lists.canvas();
            return {
                status,
                items: items.map((canvas) => ({
                    canvasId: str(canvas?.canvasId, 200),
                    displayName: str(canvas?.displayName, 200),
                    description: redactProse(oneLine(typeof canvas?.description === 'string' ? canvas.description : '', 300), 300),
                    extensionId: str(canvas?.extensionId, 200),
                    extensionName: str(canvas?.extensionName, 200),
                    actions: Array.isArray(canvas?.actions) ? canvas.actions.slice(0, 50).map((action) => str(action?.name, 200)).filter(Boolean) : [],
                })).filter((canvas) => canvas.canvasId),
            };
        }
        const { status, items } = await lists.tool();
        if (status !== 'live') {
            return { status, items: [] };
        }
        if (kind === 'subagent') {
            const task = items.find((item) => item?.name === 'task');
            return task ? { status: 'live', items: subagentCatalog(task) } : { status: 'not-offered', items: [] };
        }
        return {
            status,
            items: items.map((meta) => ({
                name: str(meta?.name, 200),
                description: redactProse(oneLine(typeof meta?.description === 'string' ? meta.description.split('\n').find((line) => line.trim()) ?? '' : '', 200), 200),
                mcpServerName: str(meta?.mcpServerName, 200),
                deferLoading: bool(meta?.deferLoading),
            })).filter((meta) => meta.name),
        };
    }

    return { lookup, catalog };
}
