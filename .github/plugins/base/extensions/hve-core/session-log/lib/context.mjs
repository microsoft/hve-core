// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Builds the inspector's Context sections: what the model is given, how often each item was used,
// and where each list comes from. Pure functions over recorded and live inventories.

import { agentNameKey } from './indexer.mjs';

/** Section order and titles. */
export const CONTEXT_SECTIONS = Object.freeze([
    { id: 'tools', title: 'Tools' },
    { id: 'skills', title: 'Skills' },
    { id: 'agents', title: 'Agents' },
    { id: 'subagents', title: 'Subagents' },
    { id: 'canvases', title: 'Canvases' },
    { id: 'instructions', title: 'Instructions' },
    { id: 'mcp', title: 'MCP servers' },
    { id: 'hooks', title: 'Hooks' },
    { id: 'plugins', title: 'Plugins' },
    { id: 'extensions', title: 'Extensions' },
]);

/** What each hook type does, for hooks known only from their runs. */
export const HOOK_DESCRIPTIONS = Object.freeze({
    sessionStart: 'Runs when the session starts.',
    sessionEnd: 'Runs when the session ends.',
    userPromptSubmitted: 'Runs when a prompt is submitted; may add context for the model.',
    userPromptTransformed: 'Runs after the prompt is transformed for the model.',
    preToolUse: 'Runs before each tool call; may block it.',
    preMcpToolCall: 'Runs before each MCP tool call.',
    postToolUse: 'Runs after each successful tool call.',
    postToolUseFailure: 'Runs after each failed tool call.',
    postResult: 'Runs after the agent returns a result.',
    prePRDescription: 'Runs before a pull request description is written.',
    errorOccurred: 'Runs when an error occurs.',
    agentStop: 'Runs when the agent finishes a turn.',
    subagentStart: 'Runs when a subagent starts.',
    subagentStop: 'Runs when a subagent finishes.',
    preCompact: 'Runs before the context is compacted.',
    permissionRequest: 'Runs when a permission is requested.',
    notification: 'Runs when the session sends a notification.',
});

const ITEM_MAX = 2000;

function plural(count, one, many = `${one}s`) {
    return `${count.toLocaleString('en-US')} ${count === 1 ? one : many}`;
}

function pathMatches(a, b) {
    return typeof a === 'string' && typeof b === 'string' && a.length > 0 && b.length > 0 && (a === b || a.endsWith(`/${b}`) || b.endsWith(`/${a}`));
}

/**
 * Assigns each recorded run type to one entry: the first whose name matches exactly, else the
 * first whose normalized name matches, so an agent listed under two names is counted once.
 */
function assignRuns(entries, namesOf, types) {
    const exact = new Map();
    const byKey = new Map();
    entries.forEach((entry, index) => {
        for (const name of namesOf(entry)) {
            if (name && !exact.has(name)) {
                exact.set(name, index);
            }
            const key = agentNameKey(name);
            if (key && !byKey.has(key)) {
                byKey.set(key, index);
            }
        }
    });
    const assigned = new Map();
    const unplaced = [];
    for (const type of types) {
        const index = exact.get(type.type) ?? byKey.get(agentNameKey(type.type));
        if (index === undefined) {
            unplaced.push(type);
            continue;
        }
        const total = assigned.get(index) ?? { count: 0, failed: 0, running: 0, description: null };
        total.count += type.count;
        total.failed += type.failed ?? 0;
        total.running += type.running ?? 0;
        total.description = total.description ?? type.description ?? null;
        assigned.set(index, total);
    }
    return { assigned, unplaced };
}

function section(id, status, note, items) {
    const spec = CONTEXT_SECTIONS.find((item) => item.id === id);
    return { id, title: spec.title, status, note, items: items.slice(0, ITEM_MAX), total: items.length };
}

function item(fields) {
    return {
        key: fields.key,
        name: fields.name,
        description: fields.description || null,
        count: fields.count ?? 0,
        failed: fields.failed ?? 0,
        countText: fields.countText ?? '',
        badges: (fields.badges ?? []).filter((badge) => badge && badge.text),
        mono: Boolean(fields.mono),
        owner: fields.owner ?? null,
        definition: fields.definition ?? null,
    };
}

function toolsSection(recorded, catalog, mainAgent) {
    const calls = new Map((recorded?.tools?.calls ?? []).map((call) => [call.name, call]));
    const servers = new Map((recorded?.tools?.mcpServers ?? []).map((entry) => [entry.tool, entry.server]));
    const activated = new Set(recorded?.tools?.activated ?? []);
    const build = (name, extra = {}) => {
        const call = calls.get(name);
        const server = extra.mcpServerName ?? servers.get(name) ?? null;
        return item({
            key: name,
            name,
            description: extra.description,
            count: call?.count ?? 0,
            failed: call?.failed ?? 0,
            countText: call?.count ? plural(call.count, 'call') : 'Not called',
            mono: true,
            owner: server ? `mcp:${server}` : null,
            badges: [
                server ? { text: `MCP · ${server}` } : null,
                extra.deferLoading ? { text: 'On demand' } : null,
                activated.has(name) ? { text: 'Loaded by search' } : null,
            ],
            definition: { kind: 'tool', name },
        });
    };
    if (mainAgent && catalog?.status === 'live') {
        const offered = new Set();
        const items = catalog.items.map((tool) => {
            offered.add(tool.name);
            return build(tool.name, tool);
        });
        for (const name of calls.keys()) {
            if (!offered.has(name)) {
                items.push(build(name, { description: 'Called earlier; not offered now.' }));
            }
        }
        const onDemand = catalog.items.filter((tool) => tool.deferLoading).length;
        return section('tools', 'live', `Live: ${catalog.items.length.toLocaleString('en-US')} offered${onDemand ? `, ${onDemand.toLocaleString('en-US')} on demand` : ''}. Calls from the log.`, items);
    }
    const names = new Set([...(recorded?.tools?.names ?? []), ...calls.keys()]);
    const items = [...names].map((name) => build(name));
    const declared = recorded?.tools?.declaredCount;
    if (!recorded) {
        return section('tools', 'not-recorded', 'No tools are recorded for this agent.', []);
    }
    if (recorded.agentKey !== 'root') {
        return items.length
            ? section('tools', 'partial', 'Tools this subagent called; its tool set is not recorded.', items)
            : section('tools', 'not-recorded', 'This subagent called no tools; its tool set is not recorded.', items);
    }
    if (Number.isFinite(declared) && declared > items.length) {
        return section('tools', 'partial', `The log names ${items.length.toLocaleString('en-US')} of ${plural(declared, 'offered tool')}. Definitions show only for the live session.`, items);
    }
    return section('tools', items.length ? 'reconstructed' : 'not-recorded', 'From the session log. Definitions show only for the live session.', items);
}

function skillsSection(recorded, live, mainLive) {
    const uses = new Map((recorded?.skillsInvoked ?? []).map((skill) => [skill.name, skill]));
    const promptSkills = new Map((recorded?.skills ?? []).map((skill) => [skill.name, skill]));
    const build = (skill) => {
        const invoked = uses.get(skill.name);
        const plugin = skill.pluginName ?? invoked?.pluginName ?? null;
        return item({
            key: skill.name,
            name: skill.name,
            description: skill.description || promptSkills.get(skill.name)?.description,
            count: invoked?.count ?? 0,
            countText: invoked?.count ? `Loaded ${invoked.count.toLocaleString('en-US')}×` : 'Not loaded',
            owner: plugin ? `plugin:${plugin}` : null,
            badges: [
                plugin ? { text: `plugin ${plugin}` } : null,
                skill.enabled === false ? { text: 'Disabled' } : null,
                skill.userInvocable === false ? { text: 'Model only' } : null,
            ],
            definition: { kind: 'skill', name: skill.name },
        });
    };
    const liveSkills = mainLive && live?.skills?.status === 'live' ? live.skills.items : null;
    const base = liveSkills ?? [...promptSkills.values()];
    const known = new Set(base.map((skill) => skill.name));
    const items = base.filter((skill) => skill.name).map(build);
    for (const invoked of uses.values()) {
        if (!known.has(invoked.name)) {
            items.push(build({ name: invoked.name, pluginName: invoked.pluginName }));
        }
    }
    if (liveSkills) {
        return section('skills', 'live', 'Live, with loads from the log.', items);
    }
    return section('skills', items.length ? 'reconstructed' : 'not-recorded', items.length ? 'From the system prompt and recorded loads.' : 'No skills are listed in this agent\'s system prompt.', items);
}

function agentsSection(recorded, live) {
    const selections = recorded?.selections ?? [];
    const current = recorded?.customAgent ?? null;
    const types = recorded?.subagentTypes ?? [];
    const selectionsByKey = new Map();
    for (const selection of selections) {
        for (const key of new Set([agentNameKey(selection.name), agentNameKey(selection.displayName)])) {
            if (key) {
                selectionsByKey.set(key, selection);
            }
        }
    }
    const namesOf = (agent) => [agent.id, agent.name, agent.displayName].filter(Boolean);
    const isCurrent = (names) => Boolean(current && names.some((name) => [current.name, current.displayName].some((value) => agentNameKey(value) === agentNameKey(name))));
    const build = (agent, run) => {
        const names = namesOf(agent);
        const selection = [...new Set(names.map(agentNameKey).filter(Boolean))].map((key) => selectionsByKey.get(key)).find(Boolean);
        const runs = run?.count ?? 0;
        const selected = selection?.count ?? 0;
        const parts = [selected ? `Selected ${selected.toLocaleString('en-US')}×` : null, runs ? plural(runs, 'run') : null].filter(Boolean);
        return item({
            key: agent.id || agent.name || agent.displayName,
            name: agent.displayName || agent.name || agent.id,
            description: agent.description,
            count: selected + runs,
            failed: run?.failed ?? 0,
            countText: parts.join(', ') || 'Not used',
            badges: [
                isCurrent(names) ? { text: 'Current', tone: 'accent' } : null,
                agent.disableModelInvocation === true ? { text: 'User only' } : null,
                agent.userInvocable === false ? { text: 'Subagent only' } : null,
                agent.source ? { text: agent.source } : null,
            ],
            definition: { kind: 'agent', name: agent.id || agent.name || agent.displayName },
        });
    };
    if (live?.agents?.status === 'live') {
        // Agents selected earlier but no longer loaded still count, after the loaded ones.
        const loadedKeys = new Set(live.agents.items.flatMap((agent) => namesOf(agent).map(agentNameKey)));
        const earlier = selections
            .filter((selection) => !loadedKeys.has(agentNameKey(selection.name)) && !loadedKeys.has(agentNameKey(selection.displayName)))
            .map((selection) => ({ name: selection.name, displayName: selection.displayName, description: 'Selected earlier; not loaded now.' }));
        const agents = [...live.agents.items, ...earlier];
        const { assigned } = assignRuns(agents, namesOf, types);
        return section('agents', 'live', 'Loaded custom agents. Most can also run as subagents.', agents.map((agent, index) => build(agent, assigned.get(index))));
    }
    const agents = selections.map((selection) => ({ name: selection.name, displayName: selection.displayName }));
    const { assigned } = assignRuns(agents, namesOf, types);
    const items = agents.map((agent, index) => build(agent, assigned.get(index)));
    return section('agents', items.length ? 'partial' : 'not-recorded', items.length ? 'Agents selected in this session. The full list shows only for the live session.' : 'No custom agent was selected. The full list shows only for the live session.', items);
}

function subagentsSection(recorded, catalog) {
    const types = recorded?.subagentTypes ?? [];
    const build = (name, run, extra = {}) => item({
        key: name,
        name,
        description: extra.description || run?.description,
        count: run?.count ?? 0,
        failed: run?.failed ?? 0,
        countText: run?.count ? plural(run.count, 'run') : 'Not run',
        badges: [
            extra.builtIn === true ? { text: 'Built-in' } : null,
            run?.running ? { text: 'Running', tone: 'live' } : null,
        ],
        definition: { kind: 'agent', name },
    });
    if (catalog?.status === 'live') {
        const { assigned, unplaced } = assignRuns(catalog.items, (entry) => [entry.name], types);
        const items = catalog.items.map((entry, index) => build(entry.name, assigned.get(index), entry));
        for (const type of unplaced) {
            items.push(build(type.type, type));
        }
        return section('subagents', 'live', 'Agent types the task tool can launch. Runs from the log.', items);
    }
    const items = types.map((type) => build(type.type, type));
    return section('subagents', items.length ? 'partial' : 'not-recorded', items.length ? 'Types that ran in this session. The launchable list shows only for the live session.' : 'No subagents ran. The launchable list shows only for the live session.', items);
}

function canvasesSection(recorded, catalog) {
    const activity = new Map((recorded?.canvases?.activity ?? []).map((canvas) => [canvas.canvasId, canvas]));
    const prompt = new Map((recorded?.canvases?.prompt ?? []).map((canvas) => [canvas.id, canvas]));
    const build = (canvasId, extra = {}) => {
        const used = activity.get(canvasId);
        return item({
            key: canvasId,
            name: extra.displayName || prompt.get(canvasId)?.name || canvasId,
            description: extra.description || prompt.get(canvasId)?.description,
            count: used?.calls ?? 0,
            failed: used?.failed ?? 0,
            countText: used?.calls ? plural(used.calls, 'call') : 'Not used',
            owner: extra.extensionId || used?.extensionId ? `extension:${extra.extensionId || used.extensionId}` : null,
            badges: [
                used?.open ? { text: 'Open', tone: 'live' } : null,
                extra.actions?.length ? { text: plural(extra.actions.length, 'action') } : null,
            ],
            definition: { kind: 'canvas', name: canvasId },
        });
    };
    const seen = new Set();
    const items = [];
    if (catalog?.status === 'live') {
        for (const canvas of catalog.items) {
            seen.add(canvas.canvasId);
            items.push(build(canvas.canvasId, canvas));
        }
    }
    for (const canvasId of [...prompt.keys(), ...activity.keys()]) {
        if (!seen.has(canvasId)) {
            seen.add(canvasId);
            items.push(build(canvasId));
        }
    }
    if (catalog?.status === 'live') {
        return section('canvases', 'live', 'Declared to this session. Calls from the log.', items);
    }
    return section('canvases', items.length ? 'reconstructed' : 'not-recorded', items.length ? 'From the system prompt and recorded calls.' : 'No canvases are listed in this agent\'s system prompt.', items);
}

function instructionsSection(recorded, live, mainLive, readCounts) {
    const fromPrompt = (recorded?.instructions ?? []).map((entry) => ({ sourcePath: entry.path, label: null, applyTo: entry.applyTo ? [entry.applyTo] : [], description: entry.description }));
    const base = mainLive && live?.instructions?.status === 'live' ? live.instructions.items : fromPrompt;
    const discovered = recorded?.discoveredInstructions ?? [];
    const merged = [...base];
    for (const entry of discovered) {
        if (!merged.some((known) => pathMatches(known.sourcePath, entry.sourcePath))) {
            merged.push({ sourcePath: entry.sourcePath, label: null, applyTo: [], description: entry.description, discovered: true });
        }
    }
    const reads = readCounts(merged.map((entry) => entry.sourcePath).filter(Boolean));
    const items = merged.map((entry) => {
        const key = entry.sourcePath || entry.label;
        const count = reads.get(entry.sourcePath) ?? 0;
        const found = entry.discovered || discovered.some((known) => pathMatches(known.sourcePath, entry.sourcePath));
        return item({
            key,
            name: entry.label || entry.sourcePath,
            description: entry.description || (entry.applyTo?.length ? `Applies to ${entry.applyTo.join(', ')}` : null),
            count,
            countText: count ? `Read ${count.toLocaleString('en-US')}×` : 'Not read',
            badges: [found ? { text: 'Discovered' } : null, entry.location ? { text: entry.location } : null],
            definition: key ? { kind: 'instruction', name: key } : null,
        });
    }).filter((entry) => entry.key);
    if (mainLive && live?.instructions?.status === 'live') {
        return section('instructions', 'live', 'Live. Reads count file views.', items);
    }
    return section('instructions', items.length ? 'reconstructed' : 'not-recorded', items.length ? 'From the system prompt and discovered files.' : 'No instructions are listed in this agent\'s system prompt.', items);
}

function mcpSection(recorded, live) {
    const calls = new Map((recorded?.tools?.calls ?? []).map((call) => [call.name, call]));
    const totals = new Map();
    for (const { tool, server } of recorded?.tools?.mcpServers ?? []) {
        const total = totals.get(server) ?? { calls: 0, failed: 0, tools: 0 };
        total.calls += calls.get(tool)?.count ?? 0;
        total.failed += calls.get(tool)?.failed ?? 0;
        total.tools += 1;
        totals.set(server, total);
    }
    const build = (server) => {
        const total = totals.get(server.name) ?? totals.get(server.displayName) ?? null;
        const status = server.status ?? null;
        return item({
            key: server.name,
            name: server.displayName || server.name,
            description: server.error || null,
            count: total?.calls ?? 0,
            failed: total?.failed ?? 0,
            countText: total?.calls ? plural(total.calls, 'call') : 'Not called',
            owner: server.sourcePlugin ? `plugin:${server.sourcePlugin}` : null,
            badges: [
                status ? { text: status, tone: status === 'failed' ? 'danger' : status === 'needs-auth' ? 'warning' : status === 'connected' ? 'success' : null } : null,
                server.sourcePlugin ? { text: `plugin ${server.sourcePlugin}` } : server.source ? { text: server.source } : null,
            ],
            definition: { kind: 'mcp', name: server.name },
        });
    };
    if (live?.mcpServers?.status === 'live') {
        const items = live.mcpServers.items.filter((server) => server.name).map(build);
        for (const name of totals.keys()) {
            if (!live.mcpServers.items.some((server) => server.name === name || server.displayName === name)) {
                items.push(build({ name }));
            }
        }
        return section('mcp', 'live', 'Live, with calls from the log.', items);
    }
    const items = [...totals.keys()].map((name) => build({ name }));
    return section('mcp', items.length ? 'partial' : 'not-recorded', items.length ? 'Servers seen in recorded calls. Status shows only for the live session.' : 'No MCP calls recorded. Servers show only for the live session.', items);
}

function hooksSection(recorded) {
    const items = (recorded?.hooks ?? []).map((hook) => item({
        key: hook.type,
        name: hook.type,
        description: HOOK_DESCRIPTIONS[hook.type] ?? null,
        count: hook.count,
        failed: hook.failed,
        countText: plural(hook.count, 'run'),
        mono: true,
        badges: [
            ...hook.sources.filter((source) => source.failed > 0).slice(0, 3).map((source) => ({ text: source.source ? `${source.source}: ${source.failed.toLocaleString('en-US')} failed` : `${source.failed.toLocaleString('en-US')} failed`, tone: 'danger' })),
            hook.contextCount ? { text: 'Adds context' } : null,
        ],
        definition: { kind: 'hook', name: hook.type },
    }));
    return section('hooks', items.length ? 'reconstructed' : 'not-recorded', items.length ? 'From recorded runs. Successful runs do not name their plugin.' : 'No hooks ran for this agent.', items);
}

function pluginsSection(recorded, live) {
    const loads = new Map();
    for (const skill of recorded?.skillsInvoked ?? []) {
        if (skill.pluginName) {
            loads.set(skill.pluginName, (loads.get(skill.pluginName) ?? 0) + skill.count);
        }
    }
    if (live?.plugins?.status === 'live') {
        const skills = live.skills?.status === 'live' ? live.skills.items : [];
        const servers = live.mcpServers?.status === 'live' ? live.mcpServers.items : [];
        const items = live.plugins.items.filter((plugin) => plugin.name).map((plugin) => {
            const ownSkills = skills.filter((skill) => skill.pluginName === plugin.name).length;
            const ownServers = servers.filter((server) => server.sourcePlugin === plugin.name).length;
            const used = loads.get(plugin.name) ?? 0;
            return item({
                key: plugin.name,
                name: plugin.name,
                description: [plugin.version ? `Version ${plugin.version}` : null, plugin.marketplace ? `from ${plugin.marketplace}` : null].filter(Boolean).join(' ') || null,
                count: used,
                countText: used ? `Skills loaded ${used.toLocaleString('en-US')}×` : 'No skill loads',
                badges: [
                    plugin.enabled === false ? { text: 'Disabled' } : null,
                    ownSkills ? { text: plural(ownSkills, 'skill') } : null,
                    ownServers ? { text: plural(ownServers, 'MCP server') } : null,
                ],
                definition: { kind: 'plugin', name: plugin.name },
            });
        });
        return section('plugins', 'live', 'Live. Uses count skill loads.', items);
    }
    const items = [...loads].map(([name, used]) => item({ key: name, name, count: used, countText: `Skills loaded ${used.toLocaleString('en-US')}×`, definition: { kind: 'plugin', name } }));
    return section('plugins', items.length ? 'partial' : 'not-recorded', items.length ? 'Named by recorded skill loads. The installed list shows only for the live session.' : 'The installed list shows only for the live session.', items);
}

function extensionsSection(recorded, live, catalog) {
    const activity = recorded?.canvases?.activity ?? [];
    const canvases = catalog?.status === 'live' ? catalog.items : [];
    const callsFor = (ids) => activity.filter((canvas) => ids.has(canvas.canvasId)).reduce((sum, canvas) => sum + canvas.calls, 0);
    if (live?.extensions?.status === 'live') {
        const items = live.extensions.items.filter((extension) => extension.name).map((extension) => {
            const owned = canvases.filter((canvas) => canvas.extensionId === extension.id || (canvas.extensionName && canvas.extensionName === extension.name));
            const used = callsFor(new Set(owned.map((canvas) => canvas.canvasId)));
            return item({
                key: extension.id || extension.name,
                name: extension.name,
                description: owned.length ? `Provides ${owned.map((canvas) => canvas.displayName || canvas.canvasId).join(', ')}` : null,
                count: used,
                countText: used ? plural(used, 'canvas call') : 'No canvas calls',
                badges: [
                    extension.status ? { text: extension.status, tone: extension.status === 'failed' ? 'danger' : extension.status === 'running' ? 'success' : null } : null,
                    extension.source ? { text: extension.source } : null,
                ],
                definition: { kind: 'extension', name: extension.id || extension.name },
            });
        });
        return section('extensions', 'live', 'Live, with canvas calls from the log.', items);
    }
    const byExtension = new Map();
    for (const canvas of activity) {
        if (canvas.extensionId) {
            byExtension.set(canvas.extensionId, (byExtension.get(canvas.extensionId) ?? 0) + canvas.calls);
        }
    }
    const items = [...byExtension].map(([id, used]) => item({ key: id, name: id, count: used, countText: plural(used, 'canvas call'), definition: { kind: 'extension', name: id } }));
    return section('extensions', items.length ? 'partial' : 'not-recorded', items.length ? 'Named by recorded canvases. The loaded list shows only for the live session.' : 'The loaded list shows only for the live session.', items);
}

/**
 * Builds the ten Context sections.
 *
 * @param {object} input
 * @param {object | null} input.recorded Inventory from `SessionIndex.getRecordedInventory`.
 * @param {object | null} input.live Live inventory lists, or null when the session is not live.
 * @param {{ tools?: object, canvases?: object, subagents?: object } | null} input.catalogs Live catalogs.
 * @param {boolean} input.mainAgent Whether the view is the main agent, whose tools, skills, and
 *   instructions the live lists describe.
 * @param {(paths: string[]) => Map<string, number>} [input.readCounts] Read counts by path.
 * @returns {object[]} Sections in display order.
 */
export function buildContextSections({ recorded, live, catalogs, mainAgent, readCounts = () => new Map() }) {
    const mainLive = Boolean(live) && mainAgent;
    return [
        toolsSection(recorded, catalogs?.tools ?? null, mainAgent),
        skillsSection(recorded, live, mainLive),
        agentsSection(recorded, live),
        subagentsSection(recorded, catalogs?.subagents ?? null),
        canvasesSection(recorded, catalogs?.canvases ?? null),
        instructionsSection(recorded, live, mainLive, readCounts),
        mcpSection(recorded, live),
        hooksSection(recorded),
        pluginsSection(recorded, live),
        extensionsSection(recorded, live, catalogs?.canvases ?? null),
    ];
}

/**
 * Reduces sections to the counts that change as the session runs.
 *
 * @param {object[]} sections
 * @returns {Record<string, Array<[string, number, number, string]>>}
 */
export function contextCounts(sections) {
    const counts = {};
    for (const entry of sections) {
        counts[entry.id] = entry.items.map((row) => [row.key, row.count, row.failed, row.countText]);
    }
    return counts;
}
