// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { formatRelativeDate, formatSize, formatTime, formatTokens, percent } from './format.mjs';
import { el, icon, renderAgentHeader, renderDetailsPanel, renderEntry, STATUS_TEXT } from './render.mjs';

const POLL_MS = 2000;
const SESSIONS_MS = 15000;
const ERROR_MS = 10000;
const SUMMARY_MIN_MS = 3000;
const OUTLINE_MIN_MS = 4000;
const PAGE = 200;
const MAX_RENDERED = 400;
const ROOT = 'root';

const $ = (id) => /** @type {HTMLElement} */ (document.getElementById(id));

const dom = {
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
    panelsToggle: $('panelsToggle'),
    sidebar: $('sidebar'),
    tabs: [...document.querySelectorAll('[role="tab"]')],
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
    /** @type {Array<object>} Last outline tool and compaction rows, oldest first. */
    toolRows: [],
    loading: false,
    generation: 0,
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
    if (document.hidden) {
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
        const button = el('button', { class: 'agent-node', type: 'button', 'aria-current': key === view.agent ? 'true' : null },
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
    dom.agentTree.replaceChildren(...(root ? [root] : []));
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
        onShowSystemPrompt: (key, seq) => showSystemPrompt(key, seq),
        ui: { get: (key) => view.ui.get(key) === true, set: (key, value) => view.ui.set(key, value) },
    };
}

let agentCardStamp = '';

/**
 * Renders the agent card in the Outline panel when its data changed, keeping keyboard focus on
 * the same control.
 */
function renderAgentCard(force = false) {
    const agent = view.agents.get(view.agent);
    const session = view.summary?.session;
    const stamp = JSON.stringify([view.sessionId, view.agent, agent ?? null, view.session?.active ?? null, session?.start?.copilotVersion ?? null, session?.shutdown?.totalPremiumRequests ?? null, session?.checkpoint?.totalPremiumRequests ?? null]);
    if (!force && stamp === agentCardStamp) {
        return;
    }
    agentCardStamp = stamp;
    const controls = () => [...dom.agentHeader.querySelectorAll('button, summary')];
    const focused = dom.agentHeader.contains(document.activeElement) ? controls().indexOf(/** @type {HTMLElement} */ (document.activeElement)) : -1;
    renderAgentHeader(dom.agentHeader, agent, view.summary, headerContext());
    if (focused >= 0) {
        controls()[focused]?.focus({ preventScroll: true });
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
    const key = `${view.sessionId}:${view.agent}:${entry.seq}:${entry.v}`;
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
    if (!Number.isInteger(target) || agentKey !== view.agent) {
        return;
    }
    openPanels(false);
    setFollow(false);
    if (!view.elements.has(target)) {
        await loadAgent(view.agent, { anchorSeq: target, block: 'start' });
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
    view.generation += 1;
    view.sessionId = sessionId;
    view.session = null;
    view.summary = null;
    view.agents = new Map();
    view.inventory = null;
    view.inventoryKey = null;
    view.outlineKey = null;
    view.details.clear();
    view.ui.clear();
    view.prompts = [];
    view.version = -1;
    view.total = 0;
    view.entries = [];
    view.elements.clear();
    setFollow(!Number.isInteger(anchor.anchorSeq));
    renderHeader();
    dom.agentHeader.replaceChildren();
    agentCardStamp = '';
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
    try {
        await refreshSummary(true);
    } catch (error) {
        if (error.code === 'session_not_found') {
            dom.feed.replaceChildren(emptyState('No recorded events yet', `Session ${sessionId} has no recorded events. They appear here once the session writes its first event.`, openSessionsButton()));
        } else {
            dom.feed.replaceChildren();
            showFeedNotice(retryNotice(`Could not read this session: ${error.message}`, () => openSession(sessionId, anchor)), 'error');
        }
        renderHeader();
        renderSessionList();
        return;
    }
    renderSessionList();
    const agentKey = anchor.agent && view.agents.has(anchor.agent) ? anchor.agent : ROOT;
    await loadAgent(agentKey, anchor);
}

function openSessionsButton() {
    const button = el('button', { class: 'btn', type: 'button' }, icon('i-list'), 'Show sessions');
    button.addEventListener('click', () => {
        selectTab('tab-sessions', true);
        openPanels(true);
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
        return;
    }
    const items = sessions.slice(0, 300).map((session) => {
        const button = el('button', { class: 'session-item', type: 'button', 'aria-current': session.sessionId === view.sessionId ? 'true' : null },
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
    dom.sessionList.replaceChildren(...items);
}

async function selectSession(sessionId) {
    try {
        const state = await api('/api/select', {}, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sessionId }) });
        openPanels(false);
        await applyState(state, true);
    } catch (error) {
        showFeedNotice(retryNotice(`Could not switch sessions: ${error.message}`, () => selectSession(sessionId)), 'error');
    }
}

async function applyState(state, force = false) {
    if (!state) {
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
    openPanels(false);
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
    return window.getComputedStyle(dom.sidebar).visibility !== 'hidden';
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
    const inventory = await api('/api/inventory', { session: sessionId, agent });
    if (sessionId !== view.sessionId || agent !== view.agent) {
        return null;
    }
    view.inventory = inventory;
    view.inventoryKey = key;
    view.inventoryVersion = inventoryVersion;
    return inventory;
}

async function refreshOutline(force = false) {
    if (!view.sessionId) {
        return;
    }
    const status = document.querySelector('input[name="toolStatus"]:checked')?.value ?? 'all';
    const query = dom.toolFilter.value.trim();
    const key = `${view.sessionId}:${view.agent}:${status}:${query}`;
    if (!force && view.outlineKey === key && (view.outlineVersion === view.version || Date.now() - view.outlineAt < OUTLINE_MIN_MS)) {
        return;
    }
    const sessionId = view.sessionId;
    const agent = view.agent;
    const outline = await api('/api/outline', { session: sessionId, agent, status, q: query, limit: 300 });
    if (sessionId !== view.sessionId || agent !== view.agent) {
        return;
    }
    view.outlineKey = key;
    view.outlineAt = Date.now();
    view.outlineVersion = outline.version;
    view.prompts = outline.interactions.map((item) => ({ seq: item.seq, ts: item.ts, summary: item.summary }));
    schedulePinned();
    const interactions = outline.interactions.map((item) => {
        const button = el('button', { class: 'nav-item', type: 'button' },
            el('span', { class: 'nav-item-time' }, formatTime(item.ts)),
            el('span', { class: 'nav-item-text' }, item.summary || 'Empty prompt'));
        button.title = item.summary;
        button.addEventListener('click', () => {
            openPanels(false);
            revealSeq(item.seq);
        });
        return el('li', null, button);
    });
    dom.interactionList.replaceChildren(...(interactions.length ? interactions : [el('li', null, el('p', { class: 'meta' }, 'No prompts recorded for this agent.'))]));
    const countText = outline.toolMatches === outline.toolTotal
        ? `${outline.toolTotal} tool ${outline.toolTotal === 1 ? 'call' : 'calls'}`
        : `${outline.toolMatches} of ${outline.toolTotal} tool calls`;
    const compactionText = outline.compactionMatches > 0 ? `, ${outline.compactionMatches} ${outline.compactionMatches === 1 ? 'compaction' : 'compactions'}` : '';
    dom.toolCount.textContent = `${countText}${compactionText}${outline.tools.length < outline.toolMatches + outline.compactionMatches ? `, latest ${outline.tools.length} shown` : ''}`;
    view.toolRows = outline.tools;
    renderToolRows();
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
            const button = el('button', { class: 'nav-item nav-item-compaction', type: 'button' },
                icon('i-compress', 'icon compaction-icon'),
                el('span', { class: 'visually-hidden' }, `${STATUS_TEXT[item.status] ?? item.status}: `),
                el('span', { class: 'nav-item-text' }, el('span', { class: 'nav-item-name' }, item.status === 'running' ? 'Compacting' : item.status === 'failed' ? 'Compaction failed' : 'Compacted'), detail ? ` ${detail}` : ''),
                el('span', { class: 'nav-item-time' }, formatTime(item.ts)));
            button.title = `${item.name}${detail ? `: ${detail} tokens` : ''}`;
            button.addEventListener('click', () => {
                openPanels(false);
                revealSeq(item.seq, 'start');
            });
            return el('li', null, button);
        }
        const statusIcon = icon(item.status === 'failed' ? 'i-x-circle' : item.status === 'running' ? 'i-clock' : 'i-check', `icon status-icon-${item.status}`);
        const button = el('button', { class: 'nav-item', type: 'button' },
            statusIcon,
            el('span', { class: 'visually-hidden' }, `${STATUS_TEXT[item.status] ?? item.status}: `),
            el('span', { class: 'nav-item-text' }, el('span', { class: 'nav-item-name' }, item.subagent ? `${item.name} (subagent)` : item.name), item.summary ? ` ${item.summary}` : ''),
            el('span', { class: 'nav-item-time' }, formatTime(item.ts)));
        button.title = `${item.name}: ${item.status}${item.summary ? `, ${item.summary}` : ''}`;
        button.addEventListener('click', () => {
            openPanels(false);
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
    list.replaceChildren(...(items.length ? items : [el('li', null, el('p', { class: 'meta' }, 'No tool calls match.'))]));
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

async function refreshDetailsPanel(force = false) {
    if (!view.sessionId) {
        renderDetailsPanel(dom.detailsContent, {});
        return;
    }
    const agent = view.agents.get(view.agent);
    const key = `${view.sessionId}:${view.agent}`;
    if (force || view.inventoryKey !== key) {
        renderDetailsPanel(dom.detailsContent, { summary: view.summary, inventory: null, agent, session: view.session });
    }
    const inventory = await ensureInventory(force);
    if (inventory) {
        renderDetailsPanel(dom.detailsContent, { summary: view.summary, inventory, agent, session: view.session });
    }
}

let lastDetailsRender = '';

function refreshSidePanels(force = false) {
    // The outline also feeds the pinned prompt, so it refreshes even while panels are hidden.
    refreshOutline(force).catch(() => {});
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

function openPanels(open) {
    document.body.classList.toggle('panels-open', open);
    dom.panelsToggle.setAttribute('aria-expanded', String(open));
    if (open) {
        document.getElementById(activeTabId())?.focus();
    }
}

// Polling

let pollTimer = 0;

function schedule(ms) {
    window.clearTimeout(pollTimer);
    if (document.hidden) {
        updateLiveStatus();
        return;
    }
    pollTimer = window.setTimeout(runPoll, ms);
}

async function runPoll() {
    window.clearTimeout(pollTimer);
    if (document.hidden) {
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
    if (!pollSession || generation !== view.generation || result.sessionId !== view.sessionId) {
        refreshSidePanels();
        return false;
    }
    if (result.reset || result.resync || result.agentMissing) {
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
    view.version = result.version;
    view.epoch = result.epoch;
    patchEntries(result.updated);
    const previousTotal = view.total;
    view.total = Math.max(result.total, view.total);
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
        if (document.body.classList.contains('panels-open')) {
            openPanels(false);
            dom.panelsToggle.focus();
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
            const tab = activeTabId();
            const field = tab === 'tab-sessions' ? dom.sessionFilter : dom.toolFilter;
            if (tab === 'tab-details') {
                selectTab('tab-outline');
            }
            openPanels(true);
            field.focus();
            break;
        }
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

let filterTimer = 0;
dom.sessionFilter.addEventListener('input', () => {
    window.clearTimeout(filterTimer);
    filterTimer = window.setTimeout(renderSessionList, 120);
});
dom.toolFilter.addEventListener('input', () => {
    window.clearTimeout(filterTimer);
    filterTimer = window.setTimeout(() => refreshOutline(true).catch(() => {}), 250);
});
for (const radio of document.querySelectorAll('input[name="toolStatus"]')) {
    radio.addEventListener('change', () => refreshOutline(true).catch(() => {}));
}
dom.toolSort.addEventListener('click', () => setToolSort(view.toolSort === 'asc' ? 'desc' : 'asc'));

dom.useCurrent.addEventListener('click', () => selectSession('current'));
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
    openPanels(false);
    moveFocus(-1, 'tool');
});
dom.nextTool.addEventListener('click', () => {
    openPanels(false);
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
dom.panelsToggle.addEventListener('click', () => openPanels(!document.body.classList.contains('panels-open')));
dom.main.addEventListener('click', () => {
    if (document.body.classList.contains('panels-open')) {
        openPanels(false);
    }
});
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
