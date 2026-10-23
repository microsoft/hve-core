// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

const TEXT_MAX = 240;

const URL_USERINFO_RE = /\b([a-z][a-z0-9+.-]{0,30}:\/\/)[^\s/@]{1,500}@/gi;
const TOKEN_RE = /\b(?:gh[pousr]_[A-Za-z0-9]{20,255}|github_pat_[A-Za-z0-9_]{20,255}|sk-[A-Za-z0-9_-]{20,255}|xox[abpr]-[A-Za-z0-9-]{10,255}|eyJ[A-Za-z0-9_-]{10,2000}\.[A-Za-z0-9_-]{10,2000}\.[A-Za-z0-9_-]{0,2000})/g;
const SECRET_PAIR_RE = /\b(token|api[_-]?key|secret|password|passwd|authorization|bearer)(\s*[=:]\s*|\s+)[^\s,;&"']{1,500}/gi;

/**
 * Removes URL credentials, well-known token formats, and secret-looking key/value pairs.
 *
 * @param {unknown} value
 * @returns {unknown} The redacted string, or the value unchanged when it is not a string.
 */
export function redactCredentials(value) {
    if (typeof value !== 'string') {
        return value;
    }
    return value
        .slice(0, 4000)
        .replace(URL_USERINFO_RE, '$1[redacted]@')
        .replace(TOKEN_RE, '[redacted]')
        .replace(SECRET_PAIR_RE, '$1$2[redacted]');
}

/**
 * Removes URL credentials and well-known token formats from prose such as prompts and skill
 * text. Unlike {@link redactCredentials}, ordinary phrases such as "token budget" stay intact.
 *
 * @param {unknown} value
 * @param {number} [max] Maximum characters kept.
 * @returns {unknown} The redacted string, or the value unchanged when it is not a string.
 */
export function redactProse(value, max = 256 * 1024) {
    if (typeof value !== 'string') {
        return value;
    }
    return value
        .slice(0, max)
        .replace(URL_USERINFO_RE, '$1[redacted]@')
        .replace(TOKEN_RE, '[redacted]');
}

function text(value, max = TEXT_MAX) {
    if (typeof value !== 'string') {
        return null;
    }
    const collapsed = value.replace(/\s+/g, ' ').trim();
    if (collapsed.length === 0) {
        return null;
    }
    return collapsed.length > max ? `${collapsed.slice(0, max - 1)}…` : collapsed;
}

function bool(value) {
    return typeof value === 'boolean' ? value : null;
}

function sourceLabel(value) {
    if (typeof value === 'string') {
        return text(value, 80);
    }
    if (value && typeof value === 'object') {
        return text(value.type ?? value.kind ?? value.name ?? null, 80);
    }
    return null;
}

/** Field allowlists: only these properties ever leave the extension process. */
export const project = Object.freeze({
    agent(agent) {
        return {
            id: text(agent?.id, 200),
            name: text(agent?.name, 120),
            displayName: text(agent?.displayName, 120),
            description: text(agent?.description),
            source: sourceLabel(agent?.source),
            model: text(agent?.model, 80),
            toolCount: Array.isArray(agent?.tools) ? agent.tools.length : null,
            userInvocable: bool(agent?.userInvocable),
            disableModelInvocation: bool(agent?.disableModelInvocation),
        };
    },
    skill(skill) {
        return {
            name: text(skill?.name, 120),
            description: text(skill?.description),
            source: sourceLabel(skill?.source),
            enabled: bool(skill?.enabled),
            pluginName: text(skill?.pluginName, 120),
            userInvocable: bool(skill?.userInvocable),
        };
    },
    invokedSkill(skill) {
        return { name: text(skill?.name, 120) };
    },
    instruction(source) {
        return {
            label: text(source?.label, 160),
            sourcePath: text(source?.sourcePath, 400),
            type: text(source?.type, 60),
            location: text(source?.location, 60),
            applyTo: Array.isArray(source?.applyTo) ? source.applyTo.slice(0, 20).map((item) => text(item, 200)).filter(Boolean) : [],
            description: text(source?.description),
        };
    },
    mcpServer(server) {
        return {
            name: text(server?.name, 120),
            displayName: text(server?.displayName, 120),
            status: text(typeof server?.status === 'string' ? server.status : server?.status?.kind ?? server?.status?.type ?? null, 60),
            source: sourceLabel(server?.source),
            sourcePlugin: text(server?.sourcePlugin, 120),
            error: text(redactCredentials(server?.error)),
        };
    },
    plugin(plugin) {
        return {
            name: text(plugin?.name, 120),
            marketplace: text(plugin?.marketplace, 120),
            version: text(plugin?.version, 40),
            enabled: bool(plugin?.enabled),
        };
    },
    extension(extension) {
        return {
            id: text(extension?.id, 200),
            name: text(extension?.name, 120),
            source: sourceLabel(extension?.source),
            status: sourceLabel(extension?.status),
        };
    },
    model(model) {
        return {
            modelId: text(model?.modelId, 80),
            reasoningEffort: text(model?.reasoningEffort, 40),
            contextTier: text(model?.contextTier, 40),
        };
    },
});

/**
 * Runs a promise-returning call with a timeout; resolves to `{ ok, value | error }`.
 *
 * @template T
 * @param {() => Promise<T>} call
 * @param {number} timeoutMs
 */
export async function timed(call, timeoutMs) {
    let timer;
    try {
        const value = await Promise.race([
            Promise.resolve().then(call),
            new Promise((_, reject) => {
                timer = setTimeout(() => reject(new Error('timeout')), timeoutMs);
            }),
        ]);
        return { ok: true, value };
    } catch (error) {
        return { ok: false, error: error instanceof Error ? error.message : 'error' };
    } finally {
        clearTimeout(timer);
    }
}

/**
 * Creates a cached provider for the joined session's live inventory.
 *
 * @param {{ rpc?: any } | null | undefined} session Joined Copilot session.
 * @param {{ timeoutMs?: number, ttlMs?: number, now?: () => number }} [options]
 * @returns {() => Promise<object>}
 */
export function createLiveInventoryProvider(session, options = {}) {
    const timeoutMs = options.timeoutMs ?? 2500;
    const ttlMs = options.ttlMs ?? 30000;
    const now = options.now ?? Date.now;
    let cached = null;
    let cachedAt = 0;
    let inflight = null;

    async function load() {
        const rpc = session?.rpc;
        const call = (namespace, method, params) => timed(() => {
            const target = rpc?.[namespace]?.[method];
            if (typeof target !== 'function') {
                throw new Error('unavailable');
            }
            return params === undefined ? target.call(rpc[namespace]) : target.call(rpc[namespace], params);
        }, timeoutMs);

        const [agents, current, skills, invoked, instructions, mcp, plugins, extensions, model] = await Promise.all([
            call('agent', 'list', { includeBuiltInAgents: true, includePrompt: false }),
            call('agent', 'getCurrent'),
            call('skills', 'list'),
            call('skills', 'getInvoked'),
            call('instructions', 'getSources'),
            call('mcp', 'list'),
            call('plugins', 'list'),
            call('extensions', 'list'),
            call('model', 'getCurrent'),
        ]);

        const listOf = (result, key, projector) => (result.ok && Array.isArray(result.value?.[key])
            ? { status: 'live', items: result.value[key].slice(0, 500).map(projector) }
            : { status: 'unavailable', items: [] });

        return {
            source: 'live',
            agents: listOf(agents, 'agents', project.agent),
            currentAgent: current.ok ? { status: 'live', item: current.value?.agent ? project.agent(current.value.agent) : null } : { status: 'unavailable', item: null },
            skills: listOf(skills, 'skills', project.skill),
            invokedSkills: listOf(invoked, 'skills', project.invokedSkill),
            instructions: listOf(instructions, 'sources', project.instruction),
            mcpServers: listOf(mcp, 'servers', project.mcpServer),
            plugins: listOf(plugins, 'plugins', project.plugin),
            extensions: listOf(extensions, 'extensions', project.extension),
            model: model.ok && model.value ? { status: 'live', item: project.model(model.value) } : { status: 'unavailable', item: null },
        };
    }

    return async function getLiveInventory() {
        if (cached && now() - cachedAt < ttlMs) {
            return cached;
        }
        if (!inflight) {
            inflight = load()
                .then((value) => {
                    cached = value;
                    cachedAt = now();
                    return value;
                })
                .finally(() => {
                    inflight = null;
                });
        }
        return inflight;
    };
}

/**
 * Combines the recorded inventory with live lists, falling back to recorded data
 * for any live list that is unavailable.
 *
 * @param {object | null} recorded Inventory from `SessionIndex.getRecordedInventory`.
 * @param {object | null} live Inventory from the live provider, or null for non-current sessions.
 */
export function mergeInventory(recorded, live) {
    const recordedSkills = (recorded?.skills ?? []).map((skill) => ({ name: skill.name, description: skill.description || null, source: null, enabled: null, pluginName: null, userInvocable: null }));
    const recordedInstructions = (recorded?.instructions ?? []).map((item) => ({
        label: null,
        sourcePath: item.path,
        type: null,
        location: null,
        applyTo: item.applyTo ? [item.applyTo] : [],
        description: item.description || null,
    }));
    const pick = (liveList, fallbackItems) => {
        if (liveList && liveList.status === 'live') {
            return liveList;
        }
        if (fallbackItems.length > 0) {
            return { status: 'reconstructed', items: fallbackItems };
        }
        return { status: live ? 'unavailable' : 'not-recorded', items: [] };
    };
    const notRecorded = { status: 'not-recorded', items: [] };
    return {
        isLive: Boolean(live),
        recorded,
        agents: live ? pick(live.agents, []) : notRecorded,
        currentAgent: live?.currentAgent?.status === 'live'
            ? live.currentAgent
            : { status: recorded?.customAgent ? 'reconstructed' : 'not-recorded', item: recorded?.customAgent ?? null },
        skills: pick(live?.skills, recordedSkills),
        invokedSkills: live?.invokedSkills?.status === 'live'
            ? live.invokedSkills
            : pick(null, (recorded?.skillsInvoked ?? []).map((skill) => ({ name: skill.name }))),
        instructions: pick(live?.instructions, recordedInstructions),
        mcpServers: live ? pick(live.mcpServers, []) : notRecorded,
        plugins: live ? pick(live.plugins, []) : notRecorded,
        extensions: live ? pick(live.extensions, []) : notRecorded,
        model: live?.model?.status === 'live' ? live.model : { status: 'not-recorded', item: null },
        tools: recorded?.tools ?? { names: [], declaredCount: null, listTruncated: 0 },
        subagentTypes: recorded?.subagentTypes ?? [],
    };
}
