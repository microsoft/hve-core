// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { formatRelativeDate, formatTime, formatTokens, percent } from './format.mjs';
import { el, filterContextItems, icon, ioBox, renderAgentHeader, renderCompactions, renderContextSections, renderDefinitionPage, renderDetailsPanel, renderEntry, renderPromptVersions, STATUS_TEXT } from './render.mjs';
import { advanceCursor, retryDelay } from './sync.mjs';

const POLL_MS = 2000;
const SESSIONS_MS = 15000;
const ERROR_MS = 10000;
const SUMMARY_MIN_MS = 3000;
const OUTLINE_MIN_MS = 4000;
/** Context counts refresh at most this often while the Context view is shown and the log grows. */
const CONTEXT_COUNTS_MS = 5000;
/** Context lists, which include live host lists, reload at most this often. */
const CONTEXT_LISTS_MS = 30000;
const DEFINITION_STACK_MAX = 6;
const PAGE = 200;
const MAX_RENDERED = 400;
const ROOT = 'root';

const $ = (id) => /** @type {HTMLElement} */ (document.getElementById(id));

const dom = {
    topbar: $('topbar'),
    mainWrap: $('mainWrap'),
    title: $('sessionTitle'),
    meta: $('sessionMeta'),
    liveStatus: $('liveStatus'),
    liveStatusText: $('liveStatusText'),
    refreshText: $('refreshText'),
    useCurrent: /** @type {HTMLButtonElement} */ ($('useCurrent')),
    followToggle: $('followToggle'),
    shortcutsButton: $('shortcutsButton'),
    shortcutsDialog: /** @type {HTMLDialogElement} */ ($('shortcutsDialog')),
    shortcutsClose: $('shortcutsClose'),
    shortcutsEnabled: /** @type {HTMLInputElement} */ ($('shortcutsEnabled')),
    sidebarToggle: $('sidebarToggle'),
    sidebarToggleText: $('sidebarToggleText'),
    sidebarWidth: $('sidebarWidth'),
    sidebarWidthText: $('sidebarWidthText'),
    inspectorToggle: $('inspectorToggle'),
    inspectorToggleText: $('inspectorToggleText'),
    inspectorWidth: $('inspectorWidth'),
    inspectorWidthText: $('inspectorWidthText'),
    sidebar: $('sidebar'),
    inspector: $('inspector'),
    inspectorHead: $('inspectorHead'),
    scrim: $('scrim'),
    sidebarSplitter: $('sidebarSplitter'),
    inspectorSplitter: $('inspectorSplitter'),
    agentCount: $('agentCount'),
    promptCount: $('promptCount'),
    promptVersionCount: $('promptVersionCount'),
    promptVersionList: $('promptVersionList'),
    showSystemPromptButton: /** @type {HTMLButtonElement} */ ($('showSystemPrompt')),
    compactionCount: $('compactionCount'),
    instructionsSection: $('instructionsSection'),
    agentInstructions: $('agentInstructions'),
    showInstructionsPrompt: /** @type {HTMLButtonElement} */ ($('showInstructionsPrompt')),
    compactionList: $('compactionList'),
    toolHeadingCount: $('toolHeadingCount'),
    tabs: [...document.querySelectorAll('#sidebar [role="tab"]')],
    inspectorTabs: [...document.querySelectorAll('#inspector [role="tab"]')],
    inspectorActivity: $('inspectorActivity'),
    inspectorContext: $('inspectorContext'),
    contextHome: $('contextHome'),
    contextFilter: /** @type {HTMLInputElement} */ ($('contextFilter')),
    contextStatus: $('contextStatus'),
    contextSections: $('contextSections'),
    contextDetail: $('contextDetail'),
    sessionFilter: /** @type {HTMLInputElement} */ ($('sessionFilter')),
    sessionCount: $('sessionCount'),
    sessionList: $('sessionList'),
    agentTree: $('agentTree'),
    interactionList: $('interactionList'),
    toolFilter: /** @type {HTMLInputElement} */ ($('toolFilter')),
    toolCount: $('toolCount'),
    toolSort: /** @type {HTMLButtonElement} */ ($('toolSort')),
    toolSortText: $('toolSortText'),
    prevTool: $('prevTool'),
    nextTool: $('nextTool'),
    toolIndex: $('toolIndex'),
    detailsContent: $('detailsContent'),
    main: $('main'),
    breadcrumb: $('breadcrumb'),
    agentHeader: $('agentHeader'),
    feedNotice: $('feedNotice'),
    loadEarlier: /** @type {HTMLButtonElement} */ ($('loadEarlier')),
    feed: $('feed'),
    scrollTopButton: $('scrollTop'),
    scrollBottomButton: $('scrollBottom'),
    newerBadge: $('newerBadge'),
    pinnedPrompt: /** @type {HTMLButtonElement} */ ($('pinnedPrompt')),
    pinnedPromptTime: $('pinnedPromptTime'),
    pinnedPromptText: $('pinnedPromptText'),
    statusRegion: $('statusRegion'),
};

const view = {
    stateVersion: 0,
    currentSessionId: null,
    selectedSessionId: null,
    followsCurrent: true,
    root: null,
    sessionId: null,
    session: null,
    agent: ROOT,
    /** @type {HTMLElement | null} Last log entry that held focus, for step controls. */
    lastEntry: null,
    epoch: 0,
    version: -1,
    total: 0,
    windowFrom: 0,
    entries: [],
    elements: new Map(),
    summary: null,
    summaryAt: 0,
    agents: new Map(),
    inventory: null,
    inventoryKey: null,
    inventoryVersion: -1,
    outlineKey: null,
    outlineAt: 0,
    outlineVersion: -1,
    sessions: [],
    sessionsAt: 0,
    follow: true,
    failures: 0,
    focusNonce: 0,
    details: new Map(),
    /** @type {Map<string, boolean>} Per-entry expand and collapse choices that survive re-rendering. */
    ui: new Map(),
    /** @type {Array<{ seq: number, ts: string, summary: string }>} Prompts of the shown agent, oldest first. */
    prompts: [],
    /** @type {'asc' | 'desc'} Order of the Tools list. */
    toolSort: 'asc',
    /** @type {Map<string, { stamp: number, value: object }>} Loaded definitions, most recently used last. */
    definitions: new Map(),
    /** @type {Map<string, Promise<object>>} Definition requests in flight. */
    definitionRequests: new Map(),
    /** @type {Array<object>} Last outline tool and compaction rows, oldest first. */
    toolRows: [],
    /** @type {'activity' | 'context'} The inspector view. */
    inspectorTab: 'activity',
    /** Context view data and choices that survive refreshes. */
    context: {
        key: null,
        sections: null,
        inventoryVersion: -1,
        listsAt: 0,
        countsAt: 0,
        countsVersion: -1,
        loading: null,
        error: null,
        state: { collapsed: new Set(['skills', 'agents', 'subagents', 'canvases', 'instructions', 'mcp', 'hooks', 'plugins', 'extensions']), filterCollapsed: new Set(), sort: new Map() },
        /** @type {Array<{ sectionId: string, key: string, def: object | null, error: string | null, scrollTop: number, refreshedAt: number }>} Open definition pages, newest last. */
        stack: [],
        listScroll: 0,
    },
    loading: false,
    generation: 0,
    /** @type {{ sessionId: string, anchor: object, attempt: number, at: number } | null} A failed session load the poll loop retries. */
    initRetry: null,
    /** The user paused live updates; nothing refreshes on its own until they resume. */
    paused: false,
};

class ApiError extends Error {}

async function api(path, params = {}, init = {}) {
    const url = new URL(path, window.location.origin);
    for (const [key, value] of Object.entries(params)) {
        if (value !== undefined && value !== null && value !== '') {
            url.searchParams.set(key, String(value));
        }
    }
    const response = await fetch(url, { cache: 'no-store', credentials: 'same-origin', ...init, headers: { Accept: 'application/json', ...(init.headers ?? {}) } });
    const body = await response.json().catch(() => null);
    if (!response.ok) {
        const error = new ApiError(body?.error?.message ?? `Request failed with status ${response.status}`);
        error.code = body?.error?.code ?? 'request_failed';
        error.status = response.status;
        throw error;
    }
    return body;
}

function announce(message) {
    dom.statusRegion.textContent = '';
    window.setTimeout(() => {
        dom.statusRegion.textContent = message;
    }, 50);
}

let liveAnnouncement = { text: null, sessionId: null, ready: false };

/**
 * Updates the status chip and announces meaningful transitions once: refresh failing,
 * refresh recovered, and the shown session starting or ending.
 */
function setLiveStatus(state, text) {
    dom.liveStatus.dataset.state = state;
    dom.liveStatusText.textContent = text;
    const previous = liveAnnouncement;
    liveAnnouncement = { text, sessionId: view.sessionId, ready: Boolean(view.session) };
    if (text === previous.text || text === 'Paused' || text === 'Retrying' || previous.text === 'Paused' || previous.text === null) {
        return;
    }
    if (text === 'Stale') {
        announce('Refresh is failing. The log shows the last data received.');
    } else if (previous.text === 'Stale' || previous.text === 'Retrying') {
        announce('Refresh recovered.');
    } else if (previous.ready && previous.sessionId === view.sessionId && text === 'Live') {
        announce('Session is live.');
    } else if (previous.ready && previous.sessionId === view.sessionId && previous.text === 'Live' && text === 'Up to date') {
        announce('Session is no longer active.');
    }
}

function updateLiveStatus() {
    if (view.paused || document.hidden) {
        setLiveStatus('paused', 'Paused');
    } else if (view.failures >= 3) {
        setLiveStatus('stale', 'Stale');
    } else if (view.failures > 0) {
        setLiveStatus('stale', 'Retrying');
    } else if (!view.sessionId) {
        setLiveStatus('idle', 'No session');
    } else if (view.session?.active) {
        setLiveStatus('live', 'Live');
    } else {
        setLiveStatus('idle', 'Up to date');
    }
}

function agentTitle(agent) {
    if (!agent) {
        return 'Agent';
    }
    if (agent.key === ROOT) {
        return agent.customAgent?.displayName ? `${agent.customAgent.displayName}` : 'Main agent';
    }
    return agent.displayName || agent.name || 'Subagent';
}

// Header

function renderHeader() {
    const session = view.session;
    if (!session) {
        dom.title.textContent = 'Session Log';
        dom.title.removeAttribute('title');
        dom.meta.textContent = view.sessionId ? 'No recorded events yet' : 'No session selected';
        document.title = 'Session Log';
    } else {
        dom.title.textContent = session.title;
        dom.title.title = session.title;
        dom.meta.textContent = [session.repository, session.branch, session.clientLabel ?? session.client, session.isCurrent ? 'current session' : null]
            .filter(Boolean)
            .join(' · ');
        document.title = `Session Log: ${session.title}`;
    }
    const canUseCurrent = Boolean(view.currentSessionId) && view.sessionId !== view.currentSessionId;
    dom.useCurrent.disabled = !canUseCurrent;
    dom.useCurrent.title = view.currentSessionId ? '' : 'The session that opened the canvas is not known';
    updateLiveStatus();
}

function setFollow(value) {
    view.follow = value;
    dom.followToggle.setAttribute('aria-pressed', String(value));
}

// Breadcrumb and agent tree

function ancestry(agentKey) {
    const chain = [];
    let key = agentKey;
    const guard = new Set();
    while (key && !guard.has(key)) {
        guard.add(key);
        const agent = view.agents.get(key);
        chain.unshift(agent ?? { key, name: key === ROOT ? 'Main agent' : 'Subagent' });
        key = agent?.parentKey ?? (key === ROOT ? null : ROOT);
    }
    return chain;
}

function renderBreadcrumb() {
    const chain = ancestry(view.agent);
    const list = el('ol');
    chain.forEach((agent, position) => {
        const isLast = position === chain.length - 1;
        const label = position === 0 ? 'Session' : agentTitle(agent);
        if (isLast) {
            list.append(el('li', null, el('span', { 'aria-current': 'page' }, label)));
        } else {
            const child = chain[position + 1];
            const button = el('button', { class: 'link-button', type: 'button' }, label);
            button.addEventListener('click', () => openAgent(agent.key, { anchorTool: child.spawnToolCallId ?? undefined }));
            list.append(el('li', null, button));
        }
    });
    dom.breadcrumb.replaceChildren(list);
}

/**
 * @param {object} agent Summary agent.
 * @returns {string} Start and end times, tokens, and context use.
 */
function agentNodeMeta(agent) {
    const parts = [];
    const start = agent.startTs ? formatTime(agent.startTs) : null;
    const running = agent.key === ROOT ? !agent.endTs && view.session?.active : agent.status === 'running';
    const end = agent.endTs ? formatTime(agent.endTs) : running ? 'running' : null;
    if (start) {
        parts.push(end ? `${start} to ${end}` : start);
    }
    const usage = agent.usage ?? {};
    if (usage.inputTokens || usage.outputTokens) {
        parts.push(`${formatTokens(usage.inputTokens ?? 0)} in, ${formatTokens(usage.outputTokens ?? 0)} out`);
    } else if (Number.isFinite(agent.totalTokens)) {
        parts.push(`${formatTokens(agent.totalTokens)} tokens`);
    }
    const pct = percent(agent.context?.current, agent.context?.limit);
    if (pct !== null) {
        parts.push(`context ${Math.round(pct)}%`);
    }
    return parts.join(' · ');
}

function renderAgentTree() {
    const build = (key, depth) => {
        const agent = view.agents.get(key);
        if (!agent || depth > 12) {
            return null;
        }
        const statusIcon = agent.key !== ROOT && agent.status ? icon(agent.status === 'failed' ? 'i-x-circle' : agent.status === 'running' ? 'i-clock' : 'i-check', `icon status-icon-${agent.status === 'completed' ? 'succeeded' : agent.status}`) : null;
        const button = el('button', { class: 'agent-node', type: 'button', 'data-row': key, 'aria-current': key === view.agent ? 'true' : null },
            icon('i-agent'),
            el('span', { class: 'nav-item-text' }, key === ROOT ? `Main agent${agent.customAgent?.displayName ? `: ${agent.customAgent.displayName}` : ''}` : agentTitle(agent)),
            statusIcon,
            statusIcon ? el('span', { class: 'visually-hidden' }, `, ${STATUS_TEXT[agent.status] ?? agent.status}`) : null);
        if (statusIcon) {
            button.title = `${agentTitle(agent)}: ${STATUS_TEXT[agent.status] ?? agent.status}`;
        }
        const meta = agentNodeMeta(agent);
        if (meta) {
            button.append(el('span', { class: 'agent-node-meta' }, meta));
        }
        button.addEventListener('click', () => openAgent(key));
        const li = el('li', null, button);
        if (agent.children?.length) {
            const ul = el('ul');
            for (const child of agent.children) {
                const node = build(child, depth + 1);
                if (node) {
                    ul.append(node);
                }
            }
            li.append(ul);
        }
        return li;
    };
    const root = build(ROOT, 0);
    keepFocus(dom.agentTree, () => dom.agentTree.replaceChildren(...(root ? [root] : [])));
    dom.agentCount.textContent = view.agents.size > 1 ? String(view.agents.size) : '';
}

// Feed

function renderContext() {
    const agent = view.agents.get(view.agent);
    return {
        agentKey: view.agent,
        total: view.total,
        agents: view.agents,
        agentModel: agent?.model ?? null,
        session: view.session,
        getSystemSections: () => (view.inventory?.agent === view.agent ? view.inventory?.recorded?.systemPrompt?.sections ?? null : null),
        onOpenAgent: (key) => openAgent(key),
        onRevealTool: (toolCallId) => revealTool(toolCallId),
        onRevealSeq: (seq) => revealSeq(seq, 'start'),
        loadSystemPrompt: (seq) => api('/api/system-prompt', { session: view.sessionId, agent: view.agent, seq }),
        loadPromptText: (seq, start, chars) => loadPromptText(view.agent, seq, start, chars),
        loadCompaction: (entry, which) => loadCompactionText(view.agent, entry.seq, which),
        ui: { get: (key) => view.ui.get(key) === true, set: (key, value) => view.ui.set(key, value) },
        loadDetail,
        loadField,
        loadHook,
    };
}

function headerContext() {
    return {
        session: view.session,
        sessionId: view.sessionId,
        ui: { get: (key) => view.ui.get(key) === true, set: (key, value) => view.ui.set(key, value) },
        onShowSystemPrompt: (key, seq) => showSystemPrompt(key, seq),
        onRevealSeq: (seq) => {
            closeOverlays();
            revealSeq(seq, 'start');
        },
    };
}

/**
 * Re-renders a list and returns keyboard focus to the same row, matched by its `data-row` key, or to
 * the control now at the same position when that row is gone.
 *
 * @param {HTMLElement} region
 * @param {() => void} render
 */
function keepFocus(region, render) {
    const active = document.activeElement;
    const controls = () => [...region.querySelectorAll('button, summary')];
    const inside = active instanceof HTMLElement && active !== region && region.contains(active);
    const row = inside ? active.closest('[data-row]')?.getAttribute('data-row') ?? null : null;
    const position = inside ? controls().indexOf(active) : -1;
    render();
    if (!inside || active.isConnected) {
        return;
    }
    const after = controls();
    const same = row === null ? null : after.find((control) => control.getAttribute('data-row') === row);
    (same ?? (position >= 0 ? after[Math.min(position, after.length - 1)] : null))?.focus({ preventScroll: true });
}

/**
 * Re-renders a region and keeps keyboard focus on the same control and the list scrolled where it was.
 * A list rendered for a different agent scrolls to its newest row.
 *
 * @param {HTMLElement} region
 * @param {() => void} render
 * @param {string} key Identity of the rendered content, such as session and agent.
 */
function rerender(region, render, key = null) {
    const sameKey = region.dataset.key === key;
    const atEnd = region.scrollHeight - region.scrollTop - region.clientHeight < 8;
    const scrollTop = region.scrollTop;
    keepFocus(region, render);
    if (key !== null) {
        region.dataset.key = key;
        region.scrollTop = !sameKey || atEnd ? region.scrollHeight : scrollTop;
    }
}

let agentCardStamp = '';

/**
 * Renders the inspector's agent overview, system prompt versions, and compactions when their data
 * changed, keeping focus and scroll position.
 */
function renderAgentCard(force = false) {
    const agent = view.agents.get(view.agent);
    const stamp = JSON.stringify([view.sessionId, view.agent, agent ?? null, view.session?.active ?? null]);
    if (!force && stamp === agentCardStamp) {
        return;
    }
    agentCardStamp = stamp;
    const ctx = headerContext();
    // Restore focus only within the regions re-rendered here, so controls below them keep focus.
    rerender(dom.agentHeader, () => renderAgentHeader({ head: dom.inspectorHead, body: dom.agentHeader }, agent, ctx));
    rerender(dom.promptVersionList, () => renderPromptVersions(dom.promptVersionList, dom.promptVersionCount, agent, ctx));
    rerender(dom.compactionList, () => renderCompactions(dom.compactionList, dom.compactionCount, agent, ctx));
    dom.showSystemPromptButton.disabled = !agent?.systemPrompt;
    renderInstructions(agent);
}

let instructionsKey = '';
let instructionsSeq = null;

/**
 * Shows the shown agent's own instructions: a subagent's agent definition, or the selected custom
 * agent's instructions in the main prompt. Loads once per agent and prompt version.
 *
 * @param {object | undefined} agent Summary agent.
 */
async function renderInstructions(agent) {
    const seq = agent?.systemPrompt?.seq;
    const available = Number.isInteger(seq) && (agent.key !== ROOT || Boolean(agent.systemPrompt.agentInstructions));
    if (!available) {
        instructionsKey = '';
        instructionsSeq = null;
        dom.instructionsSection.hidden = true;
        dom.agentInstructions.replaceChildren();
        return;
    }
    const key = `${view.sessionId}:${agent.key}:${seq}`;
    if (key === instructionsKey) {
        return;
    }
    instructionsKey = key;
    // Until this load succeeds, In prompt falls back to the agent's latest prompt.
    instructionsSeq = null;
    dom.instructionsSection.hidden = false;
    dom.agentInstructions.replaceChildren(el('p', { class: 'meta' }, 'Loading the agent instructions'));
    try {
        const data = await api('/api/agent-instructions', { session: view.sessionId, agent: agent.key });
        if (instructionsKey !== key) {
            return;
        }
        instructionsSeq = data.seq;
        // The box head shows the size, including "first N of M" when the server shortened the text.
        dom.agentInstructions.replaceChildren(ioBox({
            title: data.form === 'main' ? `${data.title || 'Selected agent'} instructions` : 'Agent definition',
            text: data.text,
            chars: data.chars,
            mode: 'markdown',
            anchor: 'start',
            state: { get: (stateKey) => view.ui.get(stateKey) === true, set: (stateKey, value) => view.ui.set(stateKey, value) },
            stateKey: `instructions:${key}`,
            watchSize: true,
        }));
    } catch (error) {
        if (instructionsKey !== key) {
            return;
        }
        if (error.code === 'entry_not_found') {
            dom.instructionsSection.hidden = true;
            return;
        }
        instructionsKey = '';
        dom.agentInstructions.replaceChildren(el('p', { class: 'meta' }, `Could not load the agent instructions: ${error.message}`));
    }
}

const PROMPT_TEXT_MAX = 4 * 1024 * 1024;

/**
 * Loads a compaction's request or summary text in pages.
 */
async function loadCompactionText(agent, seq, which) {
    let text = '';
    let cursor = 0;
    while (cursor !== null && text.length < PROMPT_TEXT_MAX) {
        const page = await api('/api/compaction', { session: view.sessionId, agent, seq, which, start: cursor });
        text += page.text;
        cursor = page.next;
    }
    return text;
}

/**
 * Loads a slice of an agent's system prompt in field pages.
 */
async function loadPromptText(agent, seq, start, chars) {
    const end = start + Math.min(chars, PROMPT_TEXT_MAX);
    let text = '';
    let cursor = start;
    while (cursor !== null && cursor < end) {
        const page = await api('/api/field', { session: view.sessionId, agent, seq, part: 0, path: 'data.content', start: cursor });
        text += page.text;
        cursor = page.next;
    }
    return text.slice(0, end - start);
}

function loadHook(entry, hook) {
    return api('/api/detail', { session: view.sessionId, agent: view.agent, seq: entry.seq, hook });
}

function loadDetail(entry) {
    // The epoch is part of the key: a rebuilt index can reuse a sequence number and version for other content.
    const key = `${view.sessionId}:${view.epoch}:${view.agent}:${entry.seq}:${entry.v}`;
    if (!view.details.has(key)) {
        const promise = (async () => {
            if (entry.kind === 'system') {
                await ensureInventory().catch(() => {});
            }
            return api('/api/detail', { session: view.sessionId, agent: view.agent, seq: entry.seq });
        })();
        promise.catch(() => view.details.delete(key));
        view.details.set(key, promise);
    }
    return view.details.get(key);
}

function loadField(entry, part, path, start) {
    return api('/api/field', { session: view.sessionId, agent: view.agent, seq: entry.seq, part, path, start });
}

function showFeedNotice(content, tone = 'info') {
    if (!content) {
        dom.feedNotice.hidden = true;
        dom.feedNotice.replaceChildren();
        return;
    }
    dom.feedNotice.dataset.tone = tone;
    dom.feedNotice.replaceChildren(content);
    dom.feedNotice.hidden = false;
}

function emptyState(title, message, action) {
    return el('div', { class: 'empty-state' }, el('h2', null, title), el('p', null, message), action ?? null);
}

function skeleton() {
    return el('div', { class: 'skeleton', 'aria-hidden': 'true' },
        el('div', { class: 'skeleton-row mid' }), el('div', { class: 'skeleton-row' }), el('div', { class: 'skeleton-row short' }),
        el('div', { class: 'skeleton-row mid' }), el('div', { class: 'skeleton-row short' }));
}

function renderFeed() {
    const ctx = renderContext();
    view.elements.clear();
    const nodes = view.entries.map((entry) => {
        const node = renderEntry(entry, ctx);
        view.elements.set(entry.seq, node);
        return node;
    });
    dom.feed.replaceChildren(...nodes);
    schedulePinned();
    if (view.entries.length === 0) {
        dom.feed.append(emptyState('No entries yet', view.agent === ROOT ? 'This session has no recorded events yet. New events appear here as they are written.' : 'This agent has no recorded events yet.'));
    }
    updateWindowControls();
}

function updateWindowControls() {
    dom.loadEarlier.hidden = view.windowFrom === 0;
    const newer = view.total - (view.windowFrom + view.entries.length);
    dom.newerBadge.hidden = newer <= 0;
    dom.newerBadge.textContent = newer > 999 ? '999+' : String(newer);
    dom.scrollBottomButton.title = newer > 0 ? `Scroll to latest (${newer} newer entries)` : 'Scroll to latest';
    dom.feed.setAttribute('aria-busy', String(view.loading));
}

let suppressScroll = false;

function scrollToBottom() {
    suppressScroll = true;
    dom.main.scrollTop = dom.main.scrollHeight;
    window.requestAnimationFrame(() => {
        suppressScroll = false;
    });
}

/**
 * Scrolls only the log column so a node is visible; the document itself never scrolls.
 *
 * @param {HTMLElement} node
 * @param {'start' | 'center' | 'nearest'} block
 */
function scrollToNode(node, block) {
    const container = dom.main.getBoundingClientRect();
    const rect = node.getBoundingClientRect();
    const offset = 12;
    let delta = 0;
    if (block === 'start') {
        delta = rect.top - container.top - offset;
    } else if (block === 'center') {
        delta = rect.top - container.top - Math.max(offset, (container.height - rect.height) / 2);
    } else if (rect.top < container.top + offset) {
        delta = rect.top - container.top - offset;
    } else if (rect.bottom > container.bottom - offset) {
        delta = Math.min(rect.bottom - container.bottom + offset, rect.top - container.top - offset);
    }
    if (delta !== 0) {
        dom.main.scrollTop += delta;
    }
}

function isAtTail() {
    return view.windowFrom + view.entries.length >= view.total;
}

function appendEntries(added) {
    if (added.length === 0) {
        return;
    }
    const ctx = renderContext();
    if (view.entries.length === 0) {
        dom.feed.replaceChildren();
    }
    for (const entry of added) {
        if (entry.index < view.windowFrom + view.entries.length) {
            continue;
        }
        const node = renderEntry(entry, ctx);
        node.classList.add('is-new');
        view.entries.push(entry);
        view.elements.set(entry.seq, node);
        dom.feed.append(node);
    }
    while (view.entries.length > MAX_RENDERED) {
        const removed = view.entries.shift();
        view.windowFrom += 1;
        view.elements.get(removed.seq)?.remove();
        view.elements.delete(removed.seq);
    }
    for (const node of view.elements.values()) {
        node.setAttribute('aria-setsize', String(view.total));
    }
}

function patchEntries(updated) {
    if (updated.length === 0) {
        return;
    }
    const ctx = renderContext();
    for (const entry of updated) {
        const position = entry.index - view.windowFrom;
        if (position < 0 || position >= view.entries.length) {
            continue;
        }
        view.entries[position] = entry;
        const old = view.elements.get(entry.seq);
        if (!old) {
            continue;
        }
        const wasOpen = old.querySelector(':scope > .entry-content > details.disclosure[open]') !== null;
        const hadFocus = old.contains(document.activeElement);
        const node = renderEntry(entry, ctx);
        old.replaceWith(node);
        view.elements.set(entry.seq, node);
        if (wasOpen) {
            const details = node.querySelector(':scope > .entry-content > details.disclosure');
            if (details) {
                details.open = true;
            }
        }
        if (hadFocus) {
            node.focus({ preventScroll: true });
        }
    }
}

async function loadAgent(agentKey, anchor = {}) {
    const generation = ++view.generation;
    view.loading = true;
    view.agent = agentKey;
    view.entries = [];
    view.elements.clear();
    view.windowFrom = 0;
    dom.feed.replaceChildren(skeleton());
    updateWindowControls();
    renderBreadcrumb();
    renderAgentTree();
    renderAgentCard(true);
    const params = { session: view.sessionId, agent: agentKey, limit: PAGE };
    if (anchor.anchorTool) {
        params.anchorTool = anchor.anchorTool;
    } else if (Number.isInteger(anchor.anchorSeq)) {
        params.anchorSeq = anchor.anchorSeq;
    } else if (anchor.fromStart) {
        params.from = 0;
    }
    let page;
    try {
        page = await api('/api/entries', params);
    } catch (error) {
        if (generation !== view.generation) {
            return;
        }
        view.loading = false;
        if (error.code === 'agent_not_found' && agentKey !== ROOT) {
            return loadAgent(ROOT);
        }
        dom.feed.replaceChildren();
        showFeedNotice(retryNotice(`Could not load this log: ${error.message}`, () => loadAgent(agentKey, anchor)), 'error');
        updateWindowControls();
        return;
    }
    if (generation !== view.generation) {
        return;
    }
    showFeedNotice(null);
    view.agent = page.agent;
    view.version = page.version;
    view.epoch = page.epoch;
    view.total = page.total;
    view.windowFrom = page.from;
    view.entries = page.entries;
    view.loading = false;
    renderBreadcrumb();
    renderAgentTree();
    renderAgentCard(true);
    renderFeed();
    writeHash();
    refreshSidePanels(true);
    const target = anchor.anchorTool
        ? view.entries.find((entry) => entry.toolCallId === anchor.anchorTool)
        : Number.isInteger(anchor.anchorSeq) ? view.entries.find((entry) => entry.seq === anchor.anchorSeq) : null;
    if (target) {
        setFollow(false);
        focusEntry(target.seq, { expand: Boolean(anchor.expand), block: anchor.block });
    } else if (view.follow && !anchor.fromStart) {
        scrollToBottom();
    } else {
        dom.main.scrollTop = 0;
    }
}

function retryNotice(message, retry) {
    const button = el('button', { class: 'btn btn-small', type: 'button' }, icon('i-refresh'), 'Retry');
    button.addEventListener('click', () => {
        showFeedNotice(null);
        retry();
    });
    return el('div', { class: 'detail-actions' }, el('span', null, message), button);
}

function focusEntry(seq, options = {}) {
    const node = view.elements.get(seq);
    if (!node) {
        return false;
    }
    scrollToNode(node, options.block ?? 'center');
    node.focus({ preventScroll: true });
    if (options.expand) {
        const details = node.querySelector(':scope > .entry-content > details.disclosure');
        if (details) {
            details.open = true;
        }
    }
    writeHash(seq);
    return true;
}

function revealTool(toolCallId) {
    const entry = view.entries.find((item) => item.toolCallId === toolCallId);
    if (entry) {
        setFollow(false);
        focusEntry(entry.seq, { expand: true });
        return;
    }
    loadAgent(view.agent, { anchorTool: toolCallId, expand: true });
}

function revealSeq(seq, block = 'center') {
    if (view.elements.has(seq)) {
        setFollow(false);
        focusEntry(seq, { block });
        return;
    }
    loadAgent(view.agent, { anchorSeq: seq, block });
}

/**
 * Reveals a system prompt entry in the log, the latest version unless one is named, and opens
 * its structure.
 *
 * @param {string} agentKey
 * @param {number | null} [seq] Sequence number of a specific version.
 */
async function showSystemPrompt(agentKey, seq = null) {
    const target = Number.isInteger(seq) ? seq : view.agents.get(agentKey)?.systemPrompt?.seq;
    if (!Number.isInteger(target) || !view.agents.has(agentKey)) {
        return;
    }
    closeOverlays();
    setFollow(false);
    // A definition can point at another agent's prompt, such as a subagent run's.
    if (agentKey !== view.agent || !view.elements.has(target)) {
        await loadAgent(agentKey, { anchorSeq: target, block: 'start' });
    }
    if (agentKey !== view.agent) {
        return;
    }
    const node = view.elements.get(target);
    if (!node) {
        return;
    }
    const panel = node.querySelector('details.sp-panel');
    if (panel) {
        panel.open = true;
    }
    focusEntry(target, { block: 'start' });
}

async function scrollToTop() {
    setFollow(false);
    if (view.windowFrom > 0) {
        await loadAgent(view.agent, { fromStart: true });
    }
    dom.main.scrollTop = 0;
    const first = view.entries[0];
    if (first) {
        view.elements.get(first.seq)?.focus({ preventScroll: true });
    }
}

// Pinned prompt: the prompt that starts the section at the top of the log stays visible until reached.

let pinFrame = 0;
let pinnedSeq = null;

function schedulePinned() {
    if (!pinFrame) {
        pinFrame = window.requestAnimationFrame(updatePinned);
    }
}

function firstVisibleSeq(top) {
    let low = 0;
    let high = view.entries.length - 1;
    let found = null;
    while (low <= high) {
        const middle = (low + high) >> 1;
        const node = view.elements.get(view.entries[middle].seq);
        if (!node) {
            return null;
        }
        if (node.getBoundingClientRect().bottom > top) {
            found = view.entries[middle].seq;
            high = middle - 1;
        } else {
            low = middle + 1;
        }
    }
    return found;
}

function updatePinned() {
    pinFrame = 0;
    if (view.prompts.length === 0 || view.entries.length === 0) {
        pinnedSeq = null;
        dom.pinnedPrompt.hidden = true;
        return;
    }
    dom.pinnedPrompt.hidden = false;
    if (view.loading) {
        return;
    }
    const top = dom.main.getBoundingClientRect().top;
    const seq = firstVisibleSeq(top + 1);
    // The previous prompt is the latest one that starts above the top of the log viewport.
    let previous = null;
    for (let index = view.prompts.length - 1; index >= 0; index -= 1) {
        const prompt = view.prompts[index];
        if (seq !== null && prompt.seq > seq) {
            continue;
        }
        if (seq !== null && prompt.seq === seq) {
            const node = view.elements.get(prompt.seq);
            if (!node || node.getBoundingClientRect().top >= top - 1) {
                continue;
            }
        }
        previous = prompt;
        break;
    }
    if (!previous) {
        pinnedSeq = null;
        dom.pinnedPrompt.disabled = true;
        dom.pinnedPromptTime.textContent = '';
        dom.pinnedPromptText.textContent = 'No earlier prompt in this log';
        dom.pinnedPrompt.title = '';
        return;
    }
    dom.pinnedPrompt.disabled = false;
    if (pinnedSeq !== previous.seq) {
        pinnedSeq = previous.seq;
        dom.pinnedPromptTime.textContent = formatTime(previous.ts);
        dom.pinnedPromptText.textContent = previous.summary || 'Empty prompt';
        dom.pinnedPrompt.title = `Scroll to the previous prompt: ${previous.summary}`;
    }
}

async function loadEarlier() {
    if (view.windowFrom === 0 || view.loading) {
        return;
    }
    const from = Math.max(0, view.windowFrom - PAGE);
    const limit = view.windowFrom - from;
    dom.loadEarlier.setAttribute('aria-busy', 'true');
    const generation = view.generation;
    const sessionId = view.sessionId;
    const agent = view.agent;
    const stale = () => generation !== view.generation || sessionId !== view.sessionId || agent !== view.agent;
    try {
        const page = await api('/api/entries', { session: sessionId, agent, from, limit });
        if (stale()) {
            return;
        }
        const ctx = renderContext();
        const before = dom.main.scrollHeight;
        const nodes = page.entries.map((entry) => {
            const node = renderEntry(entry, ctx);
            view.elements.set(entry.seq, node);
            return node;
        });
        dom.feed.prepend(...nodes);
        view.entries = [...page.entries, ...view.entries];
        view.windowFrom = page.from;
        while (view.entries.length > MAX_RENDERED) {
            const removed = view.entries.pop();
            view.elements.get(removed.seq)?.remove();
            view.elements.delete(removed.seq);
            setFollow(false);
        }
        suppressScroll = true;
        dom.main.scrollTop += dom.main.scrollHeight - before;
        window.requestAnimationFrame(() => {
            suppressScroll = false;
        });
        updateWindowControls();
        nodes[nodes.length - 1]?.focus({ preventScroll: true });
    } catch (error) {
        if (stale()) {
            return;
        }
        showFeedNotice(retryNotice(`Could not load earlier entries: ${error.message}`, loadEarlier), 'error');
    } finally {
        dom.loadEarlier.removeAttribute('aria-busy');
    }
}

async function jumpToLatest() {
    setFollow(true);
    if (!isAtTail()) {
        await loadAgent(view.agent);
    }
    scrollToBottom();
    const last = view.entries[view.entries.length - 1];
    if (last) {
        view.elements.get(last.seq)?.focus({ preventScroll: true });
    }
}

// Sessions

async function openSession(sessionId, anchor = {}) {
    const generation = ++view.generation;
    // The new generation supersedes any log load in flight, which then returns without clearing the flag.
    view.loading = false;
    view.initRetry = null;
    view.sessionId = sessionId;
    view.session = null;
    view.summary = null;
    view.agents = new Map();
    view.inventory = null;
    view.inventoryKey = null;
    view.outlineKey = null;
    resetContext();
    view.details.clear();
    view.ui.clear();
    view.prompts = [];
    view.version = -1;
    view.total = 0;
    view.windowFrom = 0;
    view.entries = [];
    view.elements.clear();
    updateWindowControls();
    setFollow(!Number.isInteger(anchor.anchorSeq));
    renderHeader();
    for (const region of [dom.inspectorHead, dom.agentHeader, dom.promptVersionList, dom.compactionList]) {
        region.replaceChildren();
    }
    for (const count of [dom.promptVersionCount, dom.compactionCount, dom.promptCount, dom.toolHeadingCount]) {
        count.textContent = '';
    }
    agentCardStamp = '';
    instructionsKey = '';
    instructionsSeq = null;
    dom.instructionsSection.hidden = true;
    dom.breadcrumb.replaceChildren();
    showFeedNotice(null);
    if (!sessionId) {
        dom.feed.replaceChildren(emptyState('No session selected', 'Choose a session from the Sessions panel, or use the current session when it is known.', openSessionsButton()));
        dom.agentTree.replaceChildren();
        dom.interactionList.replaceChildren();
        dom.toolIndex.replaceChildren();
        renderDetailsPanel(dom.detailsContent, {});
        renderSessionList();
        updateLiveStatus();
        return;
    }
    dom.feed.replaceChildren(skeleton());
    await initSession(sessionId, anchor, generation, 1);
}

/**
 * Loads a session's summary and first log page. A failure shows why and leaves a retry for the poll
 * loop, which tries again with backoff while the session stays selected.
 *
 * @param {string} sessionId
 * @param {object} anchor
 * @param {number} generation Navigation generation this load belongs to.
 * @param {number} attempt
 */
async function initSession(sessionId, anchor, generation, attempt) {
    const superseded = () => generation !== view.generation || sessionId !== view.sessionId;
    try {
        await refreshSummary(true);
    } catch (error) {
        if (superseded()) {
            return;
        }
        view.initRetry = { sessionId, anchor, attempt, at: Date.now() + retryDelay(attempt) };
        if (error.code === 'session_not_found') {
            dom.feed.replaceChildren(emptyState('No recorded events yet', `Session ${sessionId} has no recorded events. They appear here once the session writes its first event.`, openSessionsButton()));
        } else {
            dom.feed.replaceChildren();
            showFeedNotice(retryNotice(`Could not read this session: ${error.message}. Retrying automatically.`, () => openSession(sessionId, anchor)), 'error');
        }
        renderHeader();
        renderSessionList();
        return;
    }
    if (superseded()) {
        return;
    }
    renderSessionList();
    const agentKey = anchor.agent && view.agents.has(anchor.agent) ? anchor.agent : ROOT;
    await loadAgent(agentKey, anchor);
}

/** Retries a failed session load once its backoff has passed. */
async function retryInit() {
    const pending = view.initRetry;
    if (!pending || pending.sessionId !== view.sessionId || view.loading || Date.now() < pending.at) {
        return;
    }
    view.initRetry = null;
    await initSession(pending.sessionId, pending.anchor, view.generation, pending.attempt + 1);
}

function openSessionsButton() {
    const button = el('button', { class: 'btn', type: 'button' }, icon('i-list'), 'Show sessions');
    button.addEventListener('click', () => {
        selectTab('tab-sessions');
        setPanel('left', true, { focus: true });
    });
    return button;
}

async function refreshSummary(force = false) {
    if (!view.sessionId) {
        return;
    }
    if (!force && Date.now() - view.summaryAt < SUMMARY_MIN_MS) {
        return;
    }
    const sessionId = view.sessionId;
    const summary = await api('/api/summary', { session: sessionId });
    if (sessionId !== view.sessionId) {
        return;
    }
    const signature = (agent) => agent ? [agent.status, agent.durationMs, agent.totalToolCalls, agent.totalTokens, agent.counts?.tools, agent.model, agent.error].join('|') : '';
    const previous = view.agents;
    view.summary = summary;
    view.summaryAt = Date.now();
    view.session = summary.session;
    view.agents = new Map(summary.agents.map((agent) => [agent.key, agent]));
    renderHeader();
    renderAgentCard();
    renderAgentTree();
    renderBreadcrumb();
    const changed = [];
    for (const card of dom.feed.querySelectorAll('.entry[data-subagent]')) {
        const key = card.dataset.subagent;
        if (signature(previous.get(key)) === signature(view.agents.get(key))) {
            continue;
        }
        const entry = view.entries.find((item) => String(item.seq) === card.dataset.seq);
        if (entry) {
            changed.push(entry);
        }
    }
    patchEntries(changed);
}

async function loadSessions() {
    try {
        const result = await api('/api/sessions');
        view.sessions = result.sessions;
        view.root = result.root;
        view.sessionsAt = Date.now();
        renderSessionList();
    } catch (error) {
        dom.sessionList.replaceChildren(el('li', null, el('p', { class: 'meta' }, `Could not list sessions: ${error.message}`)));
    }
}

/**
 * @param {string} value Absolute folder path.
 * @returns {string} The last two path segments, prefixed with an ellipsis when shortened.
 */
function shortPath(value) {
    const segments = value.split(/[\\/]+/).filter(Boolean);
    return segments.length > 2 ? `…/${segments.slice(-2).join('/')}` : value;
}

function renderSessionList() {
    const query = dom.sessionFilter.value.trim().toLowerCase();
    const sessions = view.sessions.filter((session) => !query || [session.title, session.repository, session.branch, session.cwd, session.clientLabel, session.sessionId]
        .some((value) => typeof value === 'string' && value.toLowerCase().includes(query)));
    dom.sessionCount.textContent = view.sessions.length === 0
        ? ''
        : query ? `${sessions.length} of ${view.sessions.length} sessions` : `${view.sessions.length} sessions`;
    if (view.sessions.length === 0) {
        dom.sessionList.replaceChildren(el('li', null, emptyState('No recorded sessions', `No sessions with recorded events were found in ${view.root ?? 'the session-state folder'}. Sessions are read from the session-state folder under COPILOT_HOME, or under .copilot in your home folder when COPILOT_HOME is not set.`)));
        return 0;
    }
    const items = sessions.slice(0, 300).map((session) => {
        const button = el('button', { class: 'session-item', type: 'button', 'data-row': session.sessionId, 'aria-current': session.sessionId === view.sessionId ? 'true' : null },
            el('span', { class: 'session-item-title' }, session.title),
            el('span', { class: 'meta' }, [session.repository, session.branch, session.clientLabel].filter(Boolean).join(' · ')),
            session.cwd ? el('span', { class: 'meta session-item-cwd', title: session.cwd }, el('span', { class: 'visually-hidden' }, 'Folder: '), shortPath(session.cwd)) : null,
            el('span', { class: 'session-item-badges' },
                el('span', { class: 'meta', title: session.updatedAt }, formatRelativeDate(session.updatedAt)),
                session.sessionId === view.currentSessionId ? el('span', { class: 'badge badge-current' }, 'Current') : null,
                session.active ? el('span', { class: 'badge badge-live' }, icon('i-dot'), 'Active') : null));
        button.addEventListener('click', () => selectSession(session.sessionId));
        return el('li', null, button);
    });
    if (sessions.length > 300) {
        items.push(el('li', null, el('p', { class: 'meta' }, `${sessions.length - 300} more; refine the filter to find them.`)));
    }
    if (sessions.length === 0) {
        items.push(el('li', null, el('p', { class: 'meta' }, 'No sessions match the filter.')));
    }
    keepFocus(dom.sessionList, () => dom.sessionList.replaceChildren(...items));
    return sessions.length;
}

async function selectSession(sessionId) {
    try {
        const state = await api('/api/select', {}, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sessionId }) });
        closeOverlays();
        await applyState(state, true);
    } catch (error) {
        showFeedNotice(retryNotice(`Could not switch sessions: ${error.message}`, () => selectSession(sessionId)), 'error');
    }
}

async function applyState(state, force = false) {
    // A delayed answer can carry an older selection; applying it would undo a newer choice.
    if (!state || state.stateVersion < view.stateVersion) {
        return;
    }
    const previousSelected = view.sessionId;
    view.stateVersion = state.stateVersion;
    view.currentSessionId = state.currentSessionId;
    view.selectedSessionId = state.selectedSessionId;
    view.followsCurrent = state.followsCurrent;
    view.root = state.root ?? view.root;
    const focus = state.focus;
    if (state.selectedSessionId !== previousSelected || force && state.selectedSessionId !== view.sessionId) {
        const anchor = focus && focus.nonce > view.focusNonce ? { agent: focus.agentKey, anchorTool: focus.toolCallId, expand: true } : {};
        if (focus) {
            view.focusNonce = Math.max(view.focusNonce, focus.nonce);
        }
        await openSession(state.selectedSessionId, anchor);
        announce(view.session ? `Showing ${view.session.title}` : 'Session changed');
        return;
    }
    renderHeader();
    if (focus && focus.nonce > view.focusNonce) {
        view.focusNonce = focus.nonce;
        if (focus.toolCallId) {
            if (focus.agentKey && focus.agentKey !== view.agent) {
                await loadAgent(focus.agentKey, { anchorTool: focus.toolCallId, expand: true });
            } else {
                revealTool(focus.toolCallId);
            }
        } else if (focus.agentKey) {
            await openAgent(focus.agentKey);
        }
    }
}

async function openAgent(agentKey, anchor = {}) {
    if (!view.sessionId) {
        return;
    }
    closeOverlays();
    if (agentKey === view.agent && !anchor.anchorTool && !Number.isInteger(anchor.anchorSeq)) {
        dom.feed.focus({ preventScroll: true });
        return;
    }
    setFollow(!anchor.anchorTool && !Number.isInteger(anchor.anchorSeq));
    await loadAgent(agentKey, anchor);
    const agent = view.agents.get(view.agent);
    announce(`Showing ${agent?.key === ROOT ? 'main agent' : agentTitle(agent)} log`);
    if (!anchor.anchorTool && !Number.isInteger(anchor.anchorSeq)) {
        dom.feed.focus({ preventScroll: true });
    }
}

function goToParent() {
    if (view.agent === ROOT) {
        return;
    }
    const agent = view.agents.get(view.agent);
    openAgent(agent?.parentKey ?? ROOT, { anchorTool: agent?.spawnToolCallId ?? undefined });
}

// Side panels

function activeTabId() {
    return dom.tabs.find((tab) => tab.getAttribute('aria-selected') === 'true')?.id ?? 'tab-outline';
}

function selectTab(tabId, focus = false) {
    for (const tab of dom.tabs) {
        const selected = tab.id === tabId;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        document.getElementById(tab.getAttribute('aria-controls')).hidden = !selected;
        if (selected && focus) {
            tab.focus();
        }
    }
    refreshSidePanels(true);
}

function panelsVisible() {
    return panelShown('left');
}

async function ensureInventory(force = false) {
    if (!view.sessionId) {
        return null;
    }
    const key = `${view.sessionId}:${view.agent}`;
    const inventoryVersion = view.summary?.inventoryVersion ?? -1;
    if (!force && view.inventory && view.inventoryKey === key && view.inventoryVersion === inventoryVersion) {
        return view.inventory;
    }
    const sessionId = view.sessionId;
    const agent = view.agent;
    const epoch = view.epoch;
    const inventory = await api('/api/inventory', { session: sessionId, agent });
    if (sessionId !== view.sessionId || agent !== view.agent || epoch !== view.epoch) {
        return null;
    }
    view.inventory = inventory;
    view.inventoryKey = key;
    view.inventoryVersion = inventoryVersion;
    return inventory;
}

/**
 * Loads the prompt and tool navigation lists.
 *
 * @returns {Promise<object | null>} The outline applied, or null when nothing was loaded or it arrived stale.
 */
async function refreshOutline(force = false) {
    if (!view.sessionId) {
        return null;
    }
    const status = document.querySelector('input[name="toolStatus"]:checked')?.value ?? 'all';
    const query = dom.toolFilter.value.trim();
    const key = `${view.sessionId}:${view.agent}:${status}:${query}`;
    if (!force && view.outlineKey === key && (view.outlineVersion === view.version || Date.now() - view.outlineAt < OUTLINE_MIN_MS)) {
        return null;
    }
    const sessionId = view.sessionId;
    const agent = view.agent;
    const epoch = view.epoch;
    const outline = await api('/api/outline', { session: sessionId, agent, status, q: query, limit: 300 });
    if (sessionId !== view.sessionId || agent !== view.agent || epoch !== view.epoch) {
        return null;
    }
    view.outlineKey = key;
    view.outlineAt = Date.now();
    view.outlineVersion = outline.version;
    view.prompts = outline.interactions.map((item) => ({ seq: item.seq, ts: item.ts, summary: item.summary }));
    schedulePinned();
    const interactions = outline.interactions.map((item) => {
        const button = el('button', { class: 'nav-item', type: 'button', 'data-row': String(item.seq) },
            el('span', { class: 'nav-item-time' }, formatTime(item.ts)),
            el('span', { class: 'nav-item-text' }, item.summary || 'Empty prompt'));
        button.title = item.summary;
        button.addEventListener('click', () => {
            closeOverlays();
            revealSeq(item.seq);
        });
        return el('li', null, button);
    });
    rerender(dom.interactionList, () => {
        dom.interactionList.replaceChildren(...(interactions.length ? interactions : [el('li', { class: 'list-empty' }, 'No prompts recorded for this agent.')]));
    }, `${sessionId}:${agent}`);
    dom.promptCount.textContent = outline.interactionTotal > 0 ? String(outline.interactionTotal) : '';
    dom.toolHeadingCount.textContent = outline.toolTotal > 0 ? outline.toolTotal.toLocaleString() : '';
    const countText = outline.toolMatches === outline.toolTotal
        ? `${outline.toolTotal} tool ${outline.toolTotal === 1 ? 'call' : 'calls'}`
        : `${outline.toolMatches} of ${outline.toolTotal} tool calls`;
    const compactionText = outline.compactionMatches > 0 ? `, ${outline.compactionMatches} ${outline.compactionMatches === 1 ? 'compaction' : 'compactions'}` : '';
    dom.toolCount.textContent = `${countText}${compactionText}${outline.tools.length < outline.toolMatches + outline.compactionMatches ? `, latest ${outline.tools.length} shown` : ''}`;
    view.toolRows = outline.tools;
    renderToolRows();
    return outline;
}

/**
 * Renders the Tools list in the chosen order. Oldest-first keeps the newest row in view while
 * the list is scrolled to its end.
 */
function renderToolRows() {
    const list = dom.toolIndex;
    const listKey = `${view.sessionId}:${view.agent}`;
    const atEnd = list.scrollHeight - list.scrollTop - list.clientHeight < 8;
    const firstRender = list.dataset.key !== listKey;
    list.dataset.key = listKey;
    const rows = view.toolSort === 'desc' ? [...view.toolRows].reverse() : view.toolRows;
    const items = rows.map((item) => {
        if (item.kind === 'compaction') {
            const kept = percent(item.after, item.before);
            const detail = Number.isFinite(item.before) && Number.isFinite(item.after)
                ? `${formatTokens(item.before)} to ${formatTokens(item.after)}${kept !== null ? ` (−${Math.round(100 - kept)}%)` : ''}`
                : Number.isFinite(item.before) ? `${formatTokens(item.before)} tokens` : '';
            const button = el('button', { class: 'nav-item nav-item-compaction', type: 'button', 'data-row': String(item.seq) },
                icon('i-compress', 'icon compaction-icon'),
                el('span', { class: 'visually-hidden' }, `${STATUS_TEXT[item.status] ?? item.status}: `),
                el('span', { class: 'nav-item-text' }, el('span', { class: 'nav-item-name' }, item.status === 'running' ? 'Compacting' : item.status === 'failed' ? 'Compaction failed' : 'Compacted'), detail ? ` ${detail}` : ''),
                el('span', { class: 'nav-item-time' }, formatTime(item.ts)));
            button.title = `${item.name}${detail ? `: ${detail} tokens` : ''}`;
            button.addEventListener('click', () => {
                closeOverlays();
                revealSeq(item.seq, 'start');
            });
            return el('li', null, button);
        }
        const statusIcon = icon(item.status === 'failed' ? 'i-x-circle' : item.status === 'running' ? 'i-clock' : 'i-check', `icon status-icon-${item.status}`);
        const button = el('button', { class: 'nav-item', type: 'button', 'data-row': String(item.seq) },
            statusIcon,
            el('span', { class: 'visually-hidden' }, `${STATUS_TEXT[item.status] ?? item.status}: `),
            el('span', { class: 'nav-item-text' }, el('span', { class: 'nav-item-name' }, item.subagent ? `${item.name} (subagent)` : item.name), item.summary ? ` ${item.summary}` : ''),
            el('span', { class: 'nav-item-time' }, formatTime(item.ts)));
        button.title = `${item.name}: ${item.status}${item.summary ? `, ${item.summary}` : ''}`;
        button.addEventListener('click', () => {
            closeOverlays();
            revealSeq(item.seq);
            window.setTimeout(() => {
                const node = view.elements.get(item.seq);
                const details = node?.querySelector(':scope > .entry-content > details.disclosure');
                if (details) {
                    details.open = true;
                }
            }, 0);
        });
        return el('li', null, button);
    });
    keepFocus(list, () => list.replaceChildren(...(items.length ? items : [el('li', null, el('p', { class: 'meta' }, 'No tool calls match.'))])));
    if (view.toolSort === 'asc' && (atEnd || firstRender)) {
        list.scrollTop = list.scrollHeight;
    }
}

function setToolSort(order) {
    view.toolSort = order;
    const asc = order === 'asc';
    dom.toolSort.dataset.order = order;
    dom.toolSortText.textContent = asc ? 'Oldest first' : 'Newest first';
    dom.toolSort.title = asc ? 'Showing oldest first. Select to show newest first.' : 'Showing newest first. Select to show oldest first.';
    renderToolRows();
    dom.toolIndex.scrollTop = asc ? dom.toolIndex.scrollHeight : 0;
}

const DEFINITION_CACHE_MAX = 40;

function definitionKey(kind, name) {
    return `${view.sessionId}:${view.epoch}:${view.agent}:${kind}:${name}`;
}

/**
 * Returns a loaded definition and whether it reflects the current inventory version.
 *
 * @param {string} kind
 * @param {string} name
 * @returns {{ value: object, fresh: boolean } | null}
 */
function peekDefinition(kind, name) {
    const key = definitionKey(kind, name);
    const hit = view.definitions.get(key);
    if (!hit) {
        return null;
    }
    view.definitions.delete(key);
    view.definitions.set(key, hit);
    return { value: hit.value, fresh: hit.stamp === (view.summary?.inventoryVersion ?? -1) };
}

/**
 * Loads one definition, sharing a request already in flight and keeping a bounded cache.
 *
 * @param {string} kind
 * @param {string} name
 * @returns {Promise<object>}
 */
function loadDefinition(kind, name) {
    const key = definitionKey(kind, name);
    let request = view.definitionRequests.get(key);
    if (!request) {
        const stamp = view.summary?.inventoryVersion ?? -1;
        request = api('/api/definition', { session: view.sessionId, agent: view.agent, kind, name })
            .then((value) => {
                view.definitions.delete(key);
                view.definitions.set(key, { stamp, value });
                while (view.definitions.size > DEFINITION_CACHE_MAX) {
                    view.definitions.delete(view.definitions.keys().next().value);
                }
                return value;
            })
            .finally(() => view.definitionRequests.delete(key));
        view.definitionRequests.set(key, request);
    }
    return request;
}

function detailsContext() {
    return {
        onOpenContext: () => {
            selectInspectorTab('tab-context');
            setPanel('right', true, { focus: true });
        },
    };
}

async function refreshDetailsPanel(force = false) {
    if (!view.sessionId) {
        renderDetailsPanel(dom.detailsContent, {});
        return;
    }
    const agent = view.agents.get(view.agent);
    const key = `${view.sessionId}:${view.agent}`;
    const ctx = detailsContext();
    if (view.inventoryKey !== key || !view.inventory) {
        renderDetailsPanel(dom.detailsContent, { summary: view.summary, inventory: null, agent, session: view.session, ctx });
    }
    const inventory = await ensureInventory(force);
    if (inventory) {
        renderDetailsPanel(dom.detailsContent, { summary: view.summary, inventory, agent, session: view.session, ctx });
    }
}

let lastDetailsRender = '';

function refreshSidePanels(force = false) {
    // The outline also feeds the pinned prompt, so it refreshes even while panels are hidden.
    refreshOutline(force).catch(() => {});
    refreshContext().catch(() => {});
    if (!panelsVisible() && !force) {
        return;
    }
    const tab = activeTabId();
    if (tab === 'tab-details') {
        const stamp = `${view.sessionId}:${view.agent}:${view.summary?.inventoryVersion}`;
        if (force || stamp !== lastDetailsRender) {
            lastDetailsRender = stamp;
            refreshDetailsPanel(force).catch((error) => {
                dom.detailsContent.replaceChildren(el('p', { class: 'meta' }, `Could not load details: ${error.message}`));
            });
        }
    } else if (tab === 'tab-sessions' && (force || Date.now() - view.sessionsAt > SESSIONS_MS)) {
        loadSessions();
    }
}

// Context view: what the model is given, with use counts and definition pages.

function contextKey() {
    return `${view.sessionId}:${view.agent}`;
}

function showContextHome() {
    dom.contextDetail.hidden = true;
    dom.contextDetail.replaceChildren();
    dom.contextHome.hidden = false;
    detailSignature = '';
}

function showContextDetail() {
    dom.contextHome.hidden = true;
    dom.contextDetail.hidden = false;
}

function resetContext() {
    const context = view.context;
    Object.assign(context, { key: null, sections: null, inventoryVersion: -1, listsAt: 0, countsAt: 0, countsVersion: -1, error: null, stack: [], listScroll: 0 });
    dom.contextSections.replaceChildren();
    dom.contextStatus.textContent = '';
    showContextHome();
}

function contextVisible() {
    return panelShown('right') && view.inspectorTab === 'context' && !document.hidden;
}

/**
 * Switches the inspector between Activity and Context.
 *
 * @param {string} tabId
 * @param {boolean} [focus]
 */
function selectInspectorTab(tabId, focus = false) {
    view.inspectorTab = tabId === 'tab-context' ? 'context' : 'activity';
    for (const tab of dom.inspectorTabs) {
        const selected = tab.id === tabId;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        document.getElementById(tab.getAttribute('aria-controls')).hidden = !selected;
        if (selected && focus) {
            tab.focus();
        }
    }
    if (view.inspectorTab === 'context') {
        renderContextView();
        refreshContext(true).catch(() => {});
    }
}

function applyContextCounts(counts) {
    for (const section of view.context.sections ?? []) {
        const rows = counts?.[section.id];
        if (!Array.isArray(rows)) {
            continue;
        }
        const byKey = new Map(rows.map((row) => [row[0], row]));
        for (const item of section.items) {
            const row = byKey.get(item.key);
            if (row) {
                [, item.count, item.failed, item.countText] = row;
            }
        }
    }
}

/**
 * Loads the Context view while it is shown: full lists when the session, agent, or inventory
 * changed or the lists aged; otherwise only counts, and only after the log grew.
 *
 * @param {boolean} [force] Reload lists that are older than the counts interval.
 */
async function refreshContext(force = false) {
    if (!view.sessionId || !contextVisible()) {
        return;
    }
    const context = view.context;
    const key = contextKey();
    if (context.key !== key) {
        resetContext();
        context.key = key;
    }
    if (context.loading) {
        return context.loading;
    }
    const now = Date.now();
    const inventoryVersion = view.summary?.inventoryVersion ?? -1;
    const needLists = !context.sections || inventoryVersion !== context.inventoryVersion || now - context.listsAt > CONTEXT_LISTS_MS || (force && now - context.listsAt > CONTEXT_COUNTS_MS);
    const needCounts = !needLists && view.version !== context.countsVersion && now - context.countsAt > CONTEXT_COUNTS_MS;
    if (!needLists && !needCounts) {
        refreshDefinitionPage();
        return;
    }
    const sessionId = view.sessionId;
    const agent = view.agent;
    const version = view.version;
    const epoch = view.epoch;
    const current = () => contextKey() === key && epoch === view.epoch;
    if (!context.sections) {
        renderContextView();
    }
    context.loading = (async () => {
        try {
            if (needLists) {
                const inventory = await api('/api/inventory', { session: sessionId, agent });
                if (!current()) {
                    return;
                }
                context.sections = inventory.sections ?? [];
                context.inventoryVersion = inventoryVersion;
                context.listsAt = Date.now();
                // The Details tab reads the same payload.
                view.inventory = inventory;
                view.inventoryKey = key;
                view.inventoryVersion = inventoryVersion;
            } else {
                const result = await api('/api/inventory', { session: sessionId, agent, part: 'counts' });
                if (!current() || !context.sections) {
                    return;
                }
                applyContextCounts(result.counts);
            }
            context.countsAt = Date.now();
            context.countsVersion = version;
            context.error = null;
        } catch (error) {
            if (current()) {
                context.error = error.message;
            }
        } finally {
            context.loading = null;
        }
        if (current()) {
            renderContextView();
            refreshDefinitionPage();
        }
    })();
    return context.loading;
}

function contextCtx() {
    const { state } = view.context;
    return {
        state,
        onToggleSection: (id, expand, filtering) => {
            const set = filtering ? state.filterCollapsed : state.collapsed;
            if (expand) {
                set.delete(id);
            } else {
                set.add(id);
            }
            renderContextView();
        },
        onSort: (id, sort) => {
            state.sort.set(id, sort);
            renderContextView();
        },
        onOpenItem: (sectionId, key) => openContextItem(sectionId, key),
    };
}

function renderContextView() {
    const context = view.context;
    if (!context.sections) {
        dom.contextStatus.textContent = context.error
            ? `Could not load what the model is given: ${context.error}`
            : view.sessionId ? 'Loading what the model is given' : 'Select a session to see what its model was given.';
        return;
    }
    const query = dom.contextFilter.value;
    renderContextSections(dom.contextSections, { sections: context.sections, query, ctx: contextCtx() });
    const live = context.sections.some((section) => section.status === 'live');
    const matches = query.trim() ? context.sections.reduce((sum, section) => sum + filterContextItems(section.items, query).length, 0) : null;
    const base = matches !== null
        ? `${matches.toLocaleString()} ${matches === 1 ? 'match' : 'matches'}`
        : live ? 'What the model is given, live from this session.' : 'What the model was given, from the session log.';
    dom.contextStatus.textContent = context.error ? `${base} Refresh failed: ${context.error}` : base;
}

function findContextItem(sectionId, key) {
    const section = view.context.sections?.find((candidate) => candidate.id === sectionId);
    const item = section?.items.find((candidate) => candidate.key === key);
    return section && item ? { section, item } : null;
}

function currentPage() {
    const { stack } = view.context;
    return stack[stack.length - 1] ?? null;
}

function openContextItem(sectionId, key) {
    const found = findContextItem(sectionId, key);
    if (!found?.item.definition) {
        return;
    }
    const context = view.context;
    const page = currentPage();
    if (page) {
        page.scrollTop = dom.inspectorContext.scrollTop;
    } else {
        context.listScroll = dom.inspectorContext.scrollTop;
    }
    if (context.stack.length >= DEFINITION_STACK_MAX) {
        context.stack.shift();
    }
    context.stack.push({ sectionId, key, def: null, error: null, scrollTop: 0, version: -1, refreshedAt: 0 });
    showContextDetail();
    loadContextDefinition({ focus: true });
}

/**
 * Loads the open definition page, showing a cached copy first.
 *
 * @param {{ focus?: boolean, reload?: boolean, scrollTop?: number }} [options]
 */
async function loadContextDefinition(options = {}) {
    const page = currentPage();
    if (!page) {
        return;
    }
    const found = findContextItem(page.sectionId, page.key);
    if (!found) {
        contextBack();
        return;
    }
    const { kind, name } = found.item.definition;
    const cached = options.reload ? null : peekDefinition(kind, name);
    if (cached) {
        page.def = cached.value;
    }
    renderContextDetail(options);
    if (cached?.fresh) {
        return;
    }
    const version = view.version;
    try {
        const def = await loadDefinition(kind, name);
        if (currentPage() !== page) {
            return;
        }
        page.def = def;
        page.error = null;
    } catch (error) {
        if (currentPage() !== page) {
            return;
        }
        page.error = page.def ? null : error.message;
    }
    page.version = version;
    page.refreshedAt = Date.now();
    renderContextDetail();
}

/** Reloads the open definition page after the log grew, at most every few seconds. */
function refreshDefinitionPage() {
    const page = currentPage();
    if (page && page.def && page.version !== view.version && Date.now() - page.refreshedAt > CONTEXT_COUNTS_MS) {
        loadContextDefinition({ reload: true });
    } else if (page) {
        renderContextDetail();
    }
}

function definitionCtx() {
    return {
        ui: { get: (key) => view.ui.get(key) === true, set: (key, value) => view.ui.set(key, value) },
        onRevealTool: (toolCallId) => {
            closeOverlays();
            revealTool(toolCallId);
        },
        onRevealSeq: (seq) => {
            closeOverlays();
            revealSeq(seq, 'start');
        },
        onOpenAgent: (key) => openAgent(key),
        onShowSystemPrompt: (key, seq) => {
            closeOverlays();
            showSystemPrompt(key, seq);
        },
        onOpenItem: (sectionId, key) => openContextItem(sectionId, key),
        findItems: (predicate) => (view.context.sections ?? []).flatMap((section) => section.items.filter((item) => predicate(section, item)).map((item) => ({ section, item }))),
        onBack: () => contextBack(),
        onRetry: () => loadContextDefinition({ reload: true }),
    };
}

let detailSignature = '';

/**
 * Renders the open definition page when its data changed, keeping focus and scroll.
 *
 * @param {{ focus?: boolean, scrollTop?: number }} [options]
 */
function renderContextDetail(options = {}) {
    const page = currentPage();
    const found = page ? findContextItem(page.sectionId, page.key) : null;
    if (!found) {
        return;
    }
    const { stack } = view.context;
    const previous = stack.length > 1 ? stack[stack.length - 2] : null;
    const backLabel = previous ? findContextItem(previous.sectionId, previous.key)?.item.name ?? 'Back' : 'Context';
    const signature = JSON.stringify([stack.length, page.sectionId, page.key, found.item.countText, found.item.failed, found.item.badges, page.def, page.error, backLabel]);
    if (!options.focus && options.scrollTop === undefined && signature === detailSignature) {
        return;
    }
    detailSignature = signature;
    const scrollTop = options.scrollTop ?? dom.inspectorContext.scrollTop;
    const titleFocused = document.activeElement?.id === 'contextDetailTitle';
    rerender(dom.contextDetail, () => renderDefinitionPage(dom.contextDetail, { section: found.section, item: found.item, def: page.def, error: page.error, backLabel, ctx: definitionCtx() }));
    if (titleFocused && !options.focus) {
        dom.contextDetail.querySelector('#contextDetailTitle')?.focus({ preventScroll: true });
    }
    if (options.focus) {
        dom.inspectorContext.scrollTop = 0;
        dom.contextDetail.querySelector('#contextDetailTitle')?.focus({ preventScroll: true });
    } else {
        dom.inspectorContext.scrollTop = scrollTop;
    }
}

/** Closes the open definition page, returning to the previous page or the Context lists. */
function contextBack() {
    const context = view.context;
    const closed = context.stack.pop();
    if (!closed) {
        return false;
    }
    const page = currentPage();
    if (page) {
        detailSignature = '';
        loadContextDefinition({ scrollTop: page.scrollTop });
        dom.contextDetail.querySelector('.def-back')?.focus({ preventScroll: true });
        return true;
    }
    showContextHome();
    renderContextView();
    dom.inspectorContext.scrollTop = context.listScroll;
    const row = dom.contextSections.querySelector(`[data-section="${CSS.escape(closed.sectionId)}"] .context-item[data-key="${CSS.escape(closed.key)}"]`);
    if (row) {
        row.focus({ preventScroll: true });
        row.scrollIntoView({ block: 'nearest' });
    } else {
        dom.contextFilter.focus({ preventScroll: true });
    }
    return true;
}

// Side panels dock beside the log when there is room and swing over it as drawers when there is not.
const DOCKED = { left: window.matchMedia('(min-width: 900px)'), right: window.matchMedia('(min-width: 1180px)') };
const PANEL_NAMES = { left: 'sidebar', right: 'inspector' };
/** Docked panels remember a collapse choice; drawers remember whether they are open. */
const panels = { left: { collapsed: false, open: false }, right: { collapsed: false, open: false } };

function isDocked(side) {
    return DOCKED[side].matches;
}

function panelShown(side) {
    return isDocked(side) ? !panels[side].collapsed : panels[side].open;
}

function panelElement(side) {
    return side === 'left' ? dom.sidebar : dom.inspector;
}

function panelToggle(side) {
    return side === 'left' ? dom.sidebarToggle : dom.inspectorToggle;
}

function applyPanels() {
    const body = document.body.classList;
    // An open drawer covers everything else behind its scrim, so the rest stays inert until it closes.
    const drawer = ['left', 'right'].find((side) => !isDocked(side) && panels[side].open) ?? null;
    for (const side of ['left', 'right']) {
        const name = PANEL_NAMES[side];
        const docked = isDocked(side);
        if (docked) {
            panels[side].open = false;
        }
        body.toggle(`${name}-collapsed`, docked && panels[side].collapsed);
        body.toggle(`${name}-open`, !docked && panels[side].open);
        const shown = panelShown(side);
        const element = panelElement(side);
        element.inert = !shown || (drawer !== null && drawer !== side);
        const toggle = panelToggle(side);
        const label = `${shown ? 'Hide' : 'Show'} ${name}`;
        toggle.setAttribute('aria-expanded', String(shown));
        toggle.title = singleKeyShortcuts ? `${label} (${side === 'left' ? 'b' : 'i'})` : label;
        (side === 'left' ? dom.sidebarToggleText : dom.inspectorToggleText).textContent = label;
    }
    for (const node of [dom.topbar, dom.mainWrap, dom.sidebarSplitter, dom.inspectorSplitter]) {
        node.inert = drawer !== null;
    }
    dom.scrim.hidden = drawer === null;
    setPanelWidth('left', panelWidths.left);
    setPanelWidth('right', panelWidths.right);
    body.toggle('drawer-open', drawer !== null);
}

/**
 * Applies a docking change from the viewport, such as a resize or zoom crossing a threshold. When
 * the change hides the panel that held focus, focus moves to that panel's toggle.
 *
 * @param {'left' | 'right'} side
 */
function applyDocking(side) {
    const hadFocus = panelElement(side).contains(document.activeElement) || splitterFor(side) === document.activeElement;
    applyPanels();
    if (hadFocus && !panelShown(side)) {
        panelToggle(side).focus({ preventScroll: true });
    }
}

/**
 * Shows or hides one side panel: collapses or expands it when docked, opens or closes its drawer otherwise.
 *
 * @param {'left' | 'right'} side
 * @param {boolean} show
 * @param {{ focus?: boolean }} [options] Move focus into the panel when it opens.
 */
function setPanel(side, show, options = {}) {
    const element = panelElement(side);
    // A panel's divider sits beside it and hides with it, so its focus counts as the panel's.
    const hadFocus = element.contains(document.activeElement) || splitterFor(side) === document.activeElement;
    if (isDocked(side)) {
        panels[side].collapsed = !show;
    } else {
        panels[side].open = show;
        if (show) {
            const other = side === 'left' ? 'right' : 'left';
            if (!isDocked(other)) {
                panels[other].open = false;
            }
        }
    }
    applyPanels();
    if (!show && hadFocus) {
        panelToggle(side).focus();
    } else if (show && options.focus) {
        const target = side === 'left' ? document.getElementById(activeTabId()) : document.getElementById(view.inspectorTab === 'context' ? 'tab-context' : 'tab-activity');
        target?.focus({ preventScroll: true });
    }
    if (show && side === 'left') {
        refreshSidePanels(true);
    }
    if (show && side === 'right') {
        refreshContext().catch(() => {});
    }
}

function togglePanel(side, options = {}) {
    setPanel(side, !panelShown(side), options);
}

// Panel widths: each docked panel's divider drags or steps its width, keeping room for the log.

const PANEL_WIDTH = Object.freeze({
    left: { min: 248, initial: 280, variable: '--sl-sidebar-w', label: 'sidebar' },
    right: { min: 260, initial: 304, variable: '--sl-inspector-w', label: 'inspector' },
});
const PANEL_WIDTH_MAX = 760;
const LOG_MIN_WIDTH = 400;
const panelWidths = { left: PANEL_WIDTH.left.initial, right: PANEL_WIDTH.right.initial };

function splitterFor(side) {
    return side === 'left' ? dom.sidebarSplitter : dom.inspectorSplitter;
}

function maxPanelWidth(side) {
    const other = side === 'left' ? 'right' : 'left';
    const otherWidth = isDocked(other) && panelShown(other) ? panelWidths[other] : 0;
    return Math.max(PANEL_WIDTH[side].min, Math.min(PANEL_WIDTH_MAX, window.innerWidth - otherWidth - LOG_MIN_WIDTH));
}

/**
 * Sets a side panel's width within its minimum and the room the log needs.
 *
 * @param {'left' | 'right'} side
 * @param {number} value Width in CSS pixels.
 */
function setPanelWidth(side, value) {
    const spec = PANEL_WIDTH[side];
    const max = maxPanelWidth(side);
    const width = Math.round(Math.min(Math.max(value, spec.min), max));
    panelWidths[side] = width;
    document.documentElement.style.setProperty(spec.variable, `${width}px`);
    const splitter = splitterFor(side);
    splitter.setAttribute('aria-valuenow', String(width));
    splitter.setAttribute('aria-valuemin', String(spec.min));
    splitter.setAttribute('aria-valuemax', String(max));
    splitter.setAttribute('aria-valuetext', `${spec.label} ${width} pixels wide`);
    updateWidthButton(side);
}

/** Named widths the width buttons step through: a pointer alternative to dragging a divider. */
const WIDTH_STEPS = Object.freeze({
    left: Object.freeze([['narrow', 248], ['default', 280], ['wide', 380], ['widest', 520]]),
    right: Object.freeze([['narrow', 260], ['default', 304], ['wide', 440], ['widest', 600]]),
});

/** The width steps that fit beside the log now; steps past the room left collapse onto the widest that fits. */
function widthSteps(side) {
    const max = maxPanelWidth(side);
    return WIDTH_STEPS[side].map(([name, value]) => [name, Math.min(value, max)]);
}

/** The step after the current width, wrapping from the widest back to the narrowest. */
function nextWidthStep(side) {
    const steps = widthSteps(side);
    return steps.find(([, value]) => value > panelWidths[side] + 2) ?? steps[0];
}

function updateWidthButton(side) {
    const button = side === 'left' ? dom.sidebarWidth : dom.inspectorWidth;
    const text = side === 'left' ? dom.sidebarWidthText : dom.inspectorWidthText;
    const width = panelWidths[side];
    const current = widthSteps(side).find(([, value]) => Math.abs(value - width) <= 2)?.[0] ?? 'custom';
    const name = side === 'left' ? 'Sidebar' : 'Inspector';
    const next = nextWidthStep(side)[0];
    text.textContent = `${name} width: ${current}. Select for ${next}.`;
    button.title = `${name} width: ${current}, ${width} px. Select for ${next}.`;
}

function stepPanelWidth(side) {
    const [name, value] = nextWidthStep(side);
    setPanelWidth(side, value);
    schedulePinned();
    announce(`${side === 'left' ? 'Sidebar' : 'Inspector'} ${name}, ${panelWidths[side]} pixels wide.`);
}

function startPanelResize(side, event) {
    if (event.button !== 0) {
        return;
    }
    event.preventDefault();
    const splitter = splitterFor(side);
    const layout = splitter.parentElement.getBoundingClientRect();
    splitter.setPointerCapture?.(event.pointerId);
    splitter.classList.add('is-active');
    document.body.classList.add('is-resizing');
    const move = (moveEvent) => setPanelWidth(side, side === 'left' ? moveEvent.clientX - layout.left : layout.right - moveEvent.clientX);
    const end = () => {
        splitter.classList.remove('is-active');
        document.body.classList.remove('is-resizing');
        splitter.removeEventListener('pointermove', move);
        splitter.removeEventListener('pointerup', end);
        splitter.removeEventListener('pointercancel', end);
        schedulePinned();
    };
    splitter.addEventListener('pointermove', move);
    splitter.addEventListener('pointerup', end);
    splitter.addEventListener('pointercancel', end);
}

function panelResizeKey(side, event) {
    const step = event.shiftKey ? 64 : 16;
    // Arrow keys move the divider; the right panel grows as its divider moves left.
    const direction = side === 'left' ? 1 : -1;
    let next = null;
    if (event.key === 'ArrowRight') {
        next = panelWidths[side] + step * direction;
    } else if (event.key === 'ArrowLeft') {
        next = panelWidths[side] - step * direction;
    } else if (event.key === 'Home') {
        next = PANEL_WIDTH[side].min;
    } else if (event.key === 'End') {
        next = maxPanelWidth(side);
    } else if (event.key === 'Enter') {
        next = PANEL_WIDTH[side].initial;
    }
    if (next !== null) {
        event.preventDefault();
        event.stopPropagation();
        setPanelWidth(side, next);
    }
}

/** Closes any open drawer; docked panels stay as they are. */
function closeOverlays() {
    const open = ['left', 'right'].filter((side) => !isDocked(side) && panels[side].open);
    if (open.length === 0) {
        return false;
    }
    const focusInside = open.some((side) => panelElement(side).contains(document.activeElement));
    for (const side of open) {
        panels[side].open = false;
    }
    applyPanels();
    if (focusInside) {
        panelToggle(open[0]).focus();
    }
    return true;
}

// Polling

let pollTimer = 0;

function schedule(ms) {
    window.clearTimeout(pollTimer);
    if (document.hidden || view.paused) {
        updateLiveStatus();
        return;
    }
    pollTimer = window.setTimeout(runPoll, ms);
}

async function runPoll() {
    window.clearTimeout(pollTimer);
    if (document.hidden || view.paused) {
        updateLiveStatus();
        return;
    }
    let more = false;
    try {
        more = await poll();
        view.failures = 0;
        dom.refreshText.textContent = `Updated ${formatTime(new Date().toISOString())}`;
        updateLiveStatus();
        if (dom.feedNotice.dataset.tone === 'stale') {
            showFeedNotice(null);
        }
        schedule(more ? 50 : POLL_MS);
    } catch (error) {
        view.failures += 1;
        updateLiveStatus();
        if (view.failures === 3) {
            dom.feedNotice.dataset.tone = 'stale';
            showFeedNotice(retryNotice(`Refresh is failing: ${error.message}. The log shows the last data received.`, runPoll), 'stale');
        }
        schedule(ERROR_MS);
    }
}

/**
 * Pauses or resumes live updates. While paused nothing refreshes on its own; resuming polls at once
 * and catches the log up.
 *
 * @param {boolean} paused
 */
function setPaused(paused) {
    view.paused = paused;
    dom.liveStatus.setAttribute('aria-pressed', String(paused));
    dom.liveStatus.title = paused ? 'Resume live updates' : 'Pause live updates';
    if (paused) {
        window.clearTimeout(pollTimer);
        updateLiveStatus();
        announce('Live updates paused. The log stays as it is until you resume.');
    } else {
        announce('Live updates resumed.');
        runPoll();
    }
}

/**
 * Applies the session's activity from a poll answer. Activity comes from the session's lock files,
 * so it can change while the log stays the same, for example when the host exits.
 *
 * @param {unknown} active
 */
function applyActivity(active) {
    if (typeof active !== 'boolean' || !view.session || view.session.active === active) {
        return;
    }
    view.session.active = active;
    updateLiveStatus();
    renderAgentTree();
    renderAgentCard();
}

/**
 * Drops content cached from an index that was rebuilt; sequence numbers and versions can repeat in
 * the new index for other content. Open Context pages stay open and reload.
 */
function dropSessionContent() {
    view.details.clear();
    view.definitions.clear();
    view.definitionRequests.clear();
    view.inventory = null;
    view.inventoryKey = null;
    view.outlineKey = null;
    Object.assign(view.context, { inventoryVersion: -1, listsAt: 0, countsVersion: -1, countsAt: 0 });
    for (const page of view.context.stack) {
        page.version = -1;
        page.refreshedAt = 0;
    }
    instructionsKey = '';
    agentCardStamp = '';
}

async function poll() {
    const params = { sv: view.stateVersion };
    const pollSession = view.sessionId && !view.loading && view.version >= 0;
    if (pollSession) {
        Object.assign(params, { session: view.sessionId, agent: view.agent, since: view.total, v: view.version, epoch: view.epoch });
    }
    const generation = view.generation;
    const result = await api('/api/poll', params);
    if (result.state) {
        const before = view.sessionId;
        await applyState(result.state);
        if (view.sessionId !== before) {
            return false;
        }
    }
    if (!pollSession) {
        await retryInit();
    }
    if (!pollSession || generation !== view.generation || result.sessionId !== view.sessionId) {
        refreshSidePanels();
        return false;
    }
    applyActivity(result.active);
    if (result.reset || result.resync || result.agentMissing) {
        if (result.reset) {
            dropSessionContent();
            view.epoch = result.epoch;
        }
        await refreshSummary(true).catch(() => {});
        await loadAgent(result.agentMissing ? ROOT : view.agent);
        return false;
    }
    if (result.unchanged) {
        if (view.summary && result.inventoryVersion !== view.summary.inventoryVersion) {
            await refreshSummary(true).catch(() => {});
        }
        refreshSidePanels();
        return false;
    }
    const wasAtTail = isAtTail();
    const touchesSubagent = result.updated.some((entry) => entry.subagent) || result.added.some((entry) => entry.subagent);
    if (touchesSubagent || result.inventoryVersion !== view.summary?.inventoryVersion) {
        await refreshSummary(true).catch(() => {});
    } else {
        refreshSummary().catch(() => {});
    }
    if (generation !== view.generation) {
        return false;
    }
    const cursor = advanceCursor({ total: view.total, version: view.version }, result, wasAtTail);
    view.version = cursor.version;
    view.epoch = result.epoch;
    patchEntries(result.updated);
    const previousTotal = view.total;
    view.total = cursor.total;
    if (wasAtTail) {
        appendEntries(result.added);
    }
    updateWindowControls();
    const added = view.total - previousTotal;
    if (added > 0) {
        if (view.follow && wasAtTail) {
            scrollToBottom();
        }
        announce(`Updated ${formatTime(new Date().toISOString())}, ${added} new ${added === 1 ? 'entry' : 'entries'}`);
    }
    refreshSidePanels();
    return Boolean(result.more);
}

// Hash routing

function readHash() {
    const params = new URLSearchParams(window.location.hash.slice(1));
    const agent = params.get('agent');
    const entry = params.get('entry');
    return {
        agent: agent && /^(root|[0-9a-f-]{36})$/i.test(agent) ? agent.toLowerCase() : undefined,
        anchorSeq: entry && /^\d{1,12}$/.test(entry) ? Number(entry) : undefined,
    };
}

function writeHash(seq) {
    const params = new URLSearchParams();
    if (view.agent !== ROOT) {
        params.set('agent', view.agent);
    }
    if (Number.isInteger(seq)) {
        params.set('entry', String(seq));
    }
    const hash = params.toString();
    window.history.replaceState(null, '', hash ? `#${hash}` : window.location.pathname);
}

// Keyboard

const SHORTCUTS_KEY = 'hve-session-log:single-key-shortcuts';

/** Reads the saved shortcut choice; storage can be unavailable to an embedded canvas. */
function savedShortcutChoice() {
    try {
        return window.localStorage.getItem(SHORTCUTS_KEY) !== 'off';
    } catch {
        return true;
    }
}

/** Whether letter and symbol keys act as shortcuts; Escape, Home, and End always do. */
let singleKeyShortcuts = savedShortcutChoice();

/**
 * Turns single-key shortcuts on or off and keeps key hints in accessible names and tooltips in step.
 *
 * @param {boolean} enabled
 * @param {{ save?: boolean }} [options]
 */
function setSingleKeyShortcuts(enabled, options = {}) {
    singleKeyShortcuts = enabled;
    dom.shortcutsEnabled.checked = enabled;
    if (options.save) {
        try {
            window.localStorage.setItem(SHORTCUTS_KEY, enabled ? 'on' : 'off');
        } catch {
            // The choice still holds for this page.
        }
    }
    for (const node of document.querySelectorAll('[data-shortcut]')) {
        if (enabled) {
            node.setAttribute('aria-keyshortcuts', node.dataset.shortcut);
        } else {
            node.removeAttribute('aria-keyshortcuts');
        }
    }
    for (const node of document.querySelectorAll('[data-shortcut-title]')) {
        node.title = enabled ? node.dataset.shortcutTitle : node.dataset.shortcutTitle.replace(/ \([^)]+\)$/, '');
    }
    applyPanels();
}

function isTyping(target) {
    return target instanceof HTMLElement && (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName));
}

function entryNodes(kind) {
    const nodes = [...dom.feed.querySelectorAll(':scope > .entry')];
    return kind ? nodes.filter((node) => node.dataset.kind === kind) : nodes;
}

function moveFocus(step, kind) {
    const nodes = entryNodes(kind);
    if (nodes.length === 0) {
        return;
    }
    const active = document.activeElement?.closest?.('.feed > .entry');
    const current = active ?? (view.lastEntry?.isConnected ? view.lastEntry : null);
    let index;
    if (current) {
        const all = entryNodes();
        const currentIndex = all.indexOf(current);
        if (kind) {
            const candidates = step > 0 ? all.slice(currentIndex + 1) : all.slice(0, currentIndex).reverse();
            const next = candidates.find((node) => node.dataset.kind === kind);
            if (!next) {
                return;
            }
            index = nodes.indexOf(next);
        } else {
            index = Math.min(Math.max(currentIndex + step, 0), nodes.length - 1);
        }
    } else {
        index = step > 0 ? 0 : nodes.length - 1;
    }
    const node = nodes[index];
    if (node) {
        setFollow(false);
        scrollToNode(node, 'nearest');
        node.focus({ preventScroll: true });
        writeHash(Number(node.dataset.seq));
    }
}

document.addEventListener('keydown', (event) => {
    // Open dialogs own their keys, including Escape to close.
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || document.querySelector('dialog[open]')) {
        return;
    }
    if (event.key === 'Escape') {
        if (dom.shortcutsDialog.open) {
            return;
        }
        if (view.context.stack.length > 0 && dom.inspectorContext.contains(/** @type {Node} */ (event.target)) && contextBack()) {
            event.preventDefault();
            return;
        }
        if (closeOverlays()) {
            event.preventDefault();
            return;
        }
        if (!isTyping(event.target) && view.agent !== ROOT) {
            goToParent();
            event.preventDefault();
        }
        return;
    }
    if (isTyping(event.target) || dom.shortcutsDialog.open) {
        return;
    }
    if (!singleKeyShortcuts && event.key.length === 1) {
        return;
    }
    switch (event.key) {
        case 'j':
            moveFocus(1);
            break;
        case 'k':
            moveFocus(-1);
            break;
        case ']':
            moveFocus(1, 'tool');
            break;
        case '[':
            moveFocus(-1, 'tool');
            break;
        case 'o': {
            const subagent = document.activeElement?.closest?.('.entry[data-subagent]')?.dataset.subagent;
            if (subagent) {
                openAgent(subagent);
            }
            break;
        }
        case '/': {
            if (activeTabId() === 'tab-sessions' && panelShown('left')) {
                dom.sessionFilter.focus();
            } else {
                setPanel('right', true);
                if (view.inspectorTab === 'context') {
                    if (view.context.stack.length > 0) {
                        view.context.stack = [];
                        showContextHome();
                        renderContextView();
                    }
                    dom.contextFilter.focus();
                } else {
                    dom.toolFilter.focus();
                }
            }
            break;
        }
        case 'b':
            togglePanel('left', { focus: !isDocked('left') });
            break;
        case 'i':
            togglePanel('right', { focus: !isDocked('right') });
            break;
        case 'End':
            jumpToLatest();
            break;
        case 'Home':
            scrollToTop();
            break;
        case '?':
            dom.shortcutsDialog.showModal();
            break;
        default:
            return;
    }
    event.preventDefault();
});

// Wiring

for (const tab of dom.tabs) {
    tab.addEventListener('click', () => selectTab(tab.id));
    tab.addEventListener('keydown', (event) => {
        const index = dom.tabs.indexOf(tab);
        let next = null;
        if (event.key === 'ArrowRight') {
            next = dom.tabs[(index + 1) % dom.tabs.length];
        } else if (event.key === 'ArrowLeft') {
            next = dom.tabs[(index - 1 + dom.tabs.length) % dom.tabs.length];
        } else if (event.key === 'Home') {
            next = dom.tabs[0];
        } else if (event.key === 'End') {
            next = dom.tabs[dom.tabs.length - 1];
        }
        if (next) {
            event.preventDefault();
            event.stopPropagation();
            selectTab(next.id, true);
        }
    });
}

for (const tab of dom.inspectorTabs) {
    tab.addEventListener('click', () => selectInspectorTab(tab.id));
    tab.addEventListener('keydown', (event) => {
        if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft' && event.key !== 'Home' && event.key !== 'End') {
            return;
        }
        event.preventDefault();
        event.stopPropagation();
        const index = dom.inspectorTabs.indexOf(tab);
        const count = dom.inspectorTabs.length;
        const next = event.key === 'Home' ? 0 : event.key === 'End' ? count - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + count) % count;
        selectInspectorTab(dom.inspectorTabs[next].id, true);
    });
}

let contextFilterTimer = 0;
dom.contextFilter.addEventListener('input', () => {
    window.clearTimeout(contextFilterTimer);
    contextFilterTimer = window.setTimeout(() => {
        view.context.state.filterCollapsed.clear();
        renderContextView();
    }, 120);
});

let filterTimer = 0;
dom.sessionFilter.addEventListener('input', () => {
    window.clearTimeout(filterTimer);
    filterTimer = window.setTimeout(() => {
        const matches = renderSessionList();
        announce(matches === 0 && dom.sessionFilter.value.trim() ? 'No sessions match the filter.' : dom.sessionCount.textContent);
    }, 120);
});

/** Refreshes the Tool calls list for a new filter and announces the result without moving focus. */
async function filterTools() {
    const outline = await refreshOutline(true).catch(() => null);
    if (outline) {
        announce(outline.toolMatches + outline.compactionMatches === 0 ? 'No tool calls match.' : dom.toolCount.textContent);
    }
}

dom.toolFilter.addEventListener('input', () => {
    window.clearTimeout(filterTimer);
    filterTimer = window.setTimeout(filterTools, 250);
});
for (const radio of document.querySelectorAll('input[name="toolStatus"]')) {
    radio.addEventListener('change', filterTools);
}
dom.toolSort.addEventListener('click', () => setToolSort(view.toolSort === 'asc' ? 'desc' : 'asc'));

dom.useCurrent.addEventListener('click', () => selectSession('current'));
dom.liveStatus.addEventListener('click', () => setPaused(!view.paused));
dom.followToggle.addEventListener('click', () => {
    if (view.follow) {
        setFollow(false);
    } else {
        jumpToLatest();
    }
});
dom.feed.addEventListener('focusin', (event) => {
    const entry = /** @type {HTMLElement} */ (event.target).closest?.('.feed > .entry');
    if (entry) {
        view.lastEntry = entry;
    }
});
dom.prevTool.addEventListener('click', () => {
    closeOverlays();
    moveFocus(-1, 'tool');
});
dom.nextTool.addEventListener('click', () => {
    closeOverlays();
    moveFocus(1, 'tool');
});
dom.loadEarlier.addEventListener('click', loadEarlier);
dom.scrollBottomButton.addEventListener('click', jumpToLatest);
dom.scrollTopButton.addEventListener('click', scrollToTop);
dom.pinnedPrompt.addEventListener('click', () => {
    if (pinnedSeq !== null) {
        revealSeq(pinnedSeq, 'start');
    }
});
for (const dialog of [dom.shortcutsDialog]) {
    // Some embedding hosts swallow the native Escape cancel, so close explicitly as well.
    dialog.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            event.preventDefault();
            dialog.close();
        }
    });
}
dom.shortcutsButton.addEventListener('click', () => dom.shortcutsDialog.showModal());
dom.shortcutsClose.addEventListener('click', () => dom.shortcutsDialog.close());
dom.sidebarToggle.addEventListener('click', () => togglePanel('left', { focus: !isDocked('left') }));
dom.inspectorToggle.addEventListener('click', () => togglePanel('right', { focus: !isDocked('right') }));
dom.scrim.addEventListener('click', () => closeOverlays());
for (const side of ['left', 'right']) {
    DOCKED[side].addEventListener('change', () => applyDocking(side));
    const splitter = splitterFor(side);
    splitter.addEventListener('pointerdown', (event) => startPanelResize(side, event));
    splitter.addEventListener('keydown', (event) => panelResizeKey(side, event));
    splitter.addEventListener('dblclick', () => setPanelWidth(side, PANEL_WIDTH[side].initial));
    (side === 'left' ? dom.sidebarWidth : dom.inspectorWidth).addEventListener('click', () => stepPanelWidth(side));
}
let resizeFrame = 0;
window.addEventListener('resize', () => {
    window.cancelAnimationFrame(resizeFrame);
    resizeFrame = window.requestAnimationFrame(() => {
        setPanelWidth('left', panelWidths.left);
        setPanelWidth('right', panelWidths.right);
    });
});
dom.showSystemPromptButton.addEventListener('click', () => showSystemPrompt(view.agent, null));
dom.showInstructionsPrompt.addEventListener('click', () => showSystemPrompt(view.agent, instructionsSeq));
for (const toggle of document.querySelectorAll('.section-toggle')) {
    toggle.addEventListener('click', () => {
        const expanded = toggle.getAttribute('aria-expanded') !== 'true';
        toggle.setAttribute('aria-expanded', String(expanded));
        toggle.closest('section')?.classList.toggle('is-collapsed', !expanded);
    });
}
// Single-character shortcuts can be turned off, so their hints are kept to switch with them.
for (const node of document.querySelectorAll('[aria-keyshortcuts]')) {
    const keys = node.getAttribute('aria-keyshortcuts') ?? '';
    if (keys.length === 1) {
        node.dataset.shortcut = keys;
        if (node.title && !node.classList.contains('panel-toggle')) {
            node.dataset.shortcutTitle = node.title;
        }
    }
}
dom.shortcutsButton.dataset.shortcutTitle = dom.shortcutsButton.title;
dom.shortcutsEnabled.addEventListener('change', () => setSingleKeyShortcuts(dom.shortcutsEnabled.checked, { save: true }));
setSingleKeyShortcuts(singleKeyShortcuts);
applyPanels();
dom.main.addEventListener('scroll', () => {
    schedulePinned();
    if (suppressScroll || !view.follow) {
        return;
    }
    const distance = dom.main.scrollHeight - dom.main.scrollTop - dom.main.clientHeight;
    if (distance > 80) {
        setFollow(false);
    }
}, { passive: true });

document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        window.clearTimeout(pollTimer);
        updateLiveStatus();
    } else {
        runPoll();
    }
});

async function boot() {
    setLiveStatus('loading', 'Loading');
    try {
        const state = await api('/api/state');
        view.stateVersion = state.stateVersion;
        view.currentSessionId = state.currentSessionId;
        view.selectedSessionId = state.selectedSessionId;
        view.followsCurrent = state.followsCurrent;
        view.root = state.root;
        if (state.focus) {
            view.focusNonce = state.focus.nonce;
        }
        const hash = readHash();
        const focusAnchor = state.focus?.toolCallId ? { agent: state.focus.agentKey, anchorTool: state.focus.toolCallId, expand: true } : state.focus?.agentKey ? { agent: state.focus.agentKey } : null;
        loadSessions();
        await openSession(state.selectedSessionId, focusAnchor ?? hash);
        if (!state.selectedSessionId) {
            selectTab('tab-sessions');
        }
        schedule(POLL_MS);
    } catch (error) {
        setLiveStatus('error', 'Error');
        dom.feed.replaceChildren();
        showFeedNotice(retryNotice(`The Session Log could not start: ${error.message}`, () => {
            showFeedNotice(null);
            boot();
        }), 'error');
    }
}

boot();
