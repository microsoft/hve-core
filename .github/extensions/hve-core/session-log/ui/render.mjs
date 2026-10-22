// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { formatDuration, formatRelativeDate, formatSize, formatTime, formatTokens, percent } from './format.mjs';
import { appendJson, appendTagged, looksLikeJson } from './highlight.mjs';
import { renderMarkdown } from './markdown.mjs';

const MARKDOWN_LIMIT = 64 * 1024;

const KIND_ICON = {
    session: 'i-gear',
    system: 'i-gear',
    user: 'i-person',
    assistant: 'i-sparkle',
    tool: 'i-wrench',
    turn: 'i-layers',
    agent: 'i-agent',
    skill: 'i-book',
    model: 'i-cpu',
    compaction: 'i-compress',
    notification: 'i-bell',
    permission: 'i-shield',
    info: 'i-info',
    warning: 'i-alert',
    error: 'i-x-circle',
    abort: 'i-stop',
    unknown: 'i-question',
};

export const STATUS_TEXT = Object.freeze({ succeeded: 'Succeeded', failed: 'Failed', running: 'Running', completed: 'Completed' });
const STATUS_ICON = { succeeded: 'i-check', completed: 'i-check', failed: 'i-x-circle', running: 'i-clock' };

/**
 * Creates an element with attributes and children. Strings become text nodes.
 *
 * @param {string} tag
 * @param {Record<string, unknown> | null} [attrs]
 * @param {...(Node | string | number | null | undefined | false)} children
 * @returns {HTMLElement}
 */
export function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    if (attrs) {
        for (const [key, value] of Object.entries(attrs)) {
            if (value === undefined || value === null || value === false) {
                continue;
            }
            if (key === 'class') {
                node.className = String(value);
            } else if (key === 'dataset') {
                Object.assign(node.dataset, value);
            } else if (key.startsWith('on') && typeof value === 'function') {
                node.addEventListener(key.slice(2), value);
            } else if (value === true) {
                node.setAttribute(key, '');
            } else {
                node.setAttribute(key, String(value));
            }
        }
    }
    for (const child of children) {
        if (child === null || child === undefined || child === false) {
            continue;
        }
        node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return node;
}

/**
 * Returns an inline SVG icon referencing the page sprite.
 *
 * @param {string} id Symbol ID such as `i-wrench`.
 * @param {string} [className]
 * @returns {SVGSVGElement}
 */
export function icon(id, className = 'icon') {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', className);
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', `#${id}`);
    svg.append(use);
    return svg;
}

function joinMeta(parts) {
    return parts.filter((part) => typeof part === 'string' && part.length > 0).join(' · ');
}

function statusNode(status) {
    if (!status || !STATUS_TEXT[status]) {
        return null;
    }
    return el('span', { class: `entry-status ${status === 'completed' ? 'succeeded' : status}` }, icon(STATUS_ICON[status]), STATUS_TEXT[status]);
}

/**
 * Renders text as Markdown, falling back to preformatted text for very large input.
 *
 * @param {string} text
 * @returns {HTMLElement}
 */
export function proseBlock(text) {
    if (text.length > MARKDOWN_LIMIT) {
        return el('pre', { class: 'code-well wrap' }, text);
    }
    const container = el('div', { class: 'prose' });
    try {
        container.append(renderMarkdown(text));
    } catch {
        return el('pre', { class: 'code-well wrap' }, text);
    }
    return container;
}

function agentLabel(agent) {
    if (!agent) {
        return 'Subagent';
    }
    return agent.displayName || agent.name || 'Subagent';
}

function getAt(object, path) {
    let value = object;
    for (const segment of path.split('.')) {
        if (value === null || typeof value !== 'object') {
            return undefined;
        }
        value = value[segment];
    }
    return value;
}

/**
 * Renders a paged text field with Load more when the server truncated it.
 */
function pagedText(text, truncatedInfo, ctx, entry, options = {}) {
    const pre = el('pre', { class: `code-well${options.wrap === false ? '' : ' wrap'}` }, text);
    const block = el('div', { class: 'detail-block' });
    if (options.title) {
        block.append(el('p', { class: 'detail-block-title' }, options.title));
    }
    block.append(pre);
    if (truncatedInfo) {
        let next = truncatedInfo.next;
        const note = el('span', { class: 'meta' });
        const updateNote = (loaded) => {
            note.textContent = `Showing ${formatSize(loaded)} of ${formatSize(truncatedInfo.length)}`;
        };
        updateNote(next);
        const button = el('button', { class: 'btn btn-small', type: 'button' }, 'Load more');
        button.addEventListener('click', async () => {
            if (next === null) {
                return;
            }
            button.setAttribute('aria-busy', 'true');
            button.disabled = true;
            try {
                const page = await ctx.loadField(entry, truncatedInfo.part, truncatedInfo.path, next);
                pre.append(document.createTextNode(page.text));
                next = page.next;
                updateNote(next ?? page.length);
                if (next === null) {
                    button.remove();
                    note.textContent = `Showing all ${formatSize(page.length)}`;
                }
            } catch (error) {
                note.textContent = `Could not load more: ${error.message}`;
            } finally {
                button.removeAttribute('aria-busy');
                button.disabled = false;
            }
        });
        block.append(el('div', { class: 'detail-actions' }, note, button));
    }
    return block;
}

function kvList(pairs) {
    const dl = el('dl', { class: 'kv' });
    for (const [key, value] of pairs) {
        if (value === null || value === undefined || value === '') {
            continue;
        }
        dl.append(el('dt', null, key), el('dd', null, value instanceof Node ? value : String(value)));
    }
    return dl.childElementCount > 0 ? dl : null;
}

/**
 * A code well whose JSON content is syntax highlighted.
 *
 * @param {string} text
 * @param {boolean} json
 * @param {string} [extraClass]
 */
function codeBlock(text, mode, extraClass = '') {
    const pre = el('pre', { class: `code-well${extraClass ? ` ${extraClass}` : ''}` });
    const code = el('code');
    if ((mode === true || mode === 'json') && looksLikeJson(text)) {
        appendJson(code, text);
        pre.classList.add('is-json');
    } else if (mode === 'tags') {
        appendTagged(code, text);
    } else {
        code.textContent = text;
    }
    pre.append(code);
    if (!extraClass.includes('io-pre')) {
        // Focusable so a click activates scrolling; unfocused wells let the wheel scroll the log.
        pre.tabIndex = 0;
    }
    return pre;
}

/**
 * A bounded input or output box. Collapsed boxes show the start (`anchor: 'start'`) or the latest
 * text (`anchor: 'end'`); expanding grows the box with a scroll bar and loads the full text once.
 *
 * @param {object} options
 * @param {string} options.title
 * @param {string} options.text Preview text.
 * @param {number} options.chars Full length.
 * @param {boolean} options.json
 * @param {'start' | 'end'} options.anchor
 * @param {'default' | 'error'} [options.tone]
 * @param {() => Promise<{ text: string, note?: string }>} [options.loadFull]
 * @param {{ get: (key: string) => boolean, set: (key: string, value: boolean) => void }} [options.state]
 * @param {string} [options.stateKey]
 */
export function ioBox(options) {
    const { title, chars, anchor, tone = 'default', loadFull, state, stateKey } = options;
    const mode = options.mode ?? (options.json ? 'json' : 'text');
    let text = options.text;
    const cut = chars > text.length;
    const box = el('div', { class: `io-box anchor-${anchor}${tone === 'error' ? ' tone-error' : ''}` });
    const size = el('span', { class: 'meta' }, cut ? `${anchor === 'end' ? 'last' : 'first'} ${formatSize(text.length)} of ${formatSize(chars)}` : formatSize(chars));
    const toggle = el('button', { class: 'btn btn-small io-toggle', type: 'button', 'aria-expanded': 'false' }, 'Expand');
    const note = el('span', { class: 'meta io-note' });
    const hint = el('span', { class: 'meta io-hint' }, 'Click inside to scroll');
    const body = el('div', { class: 'io-body', tabindex: '0', role: 'region', 'aria-label': title });
    const measure = () => {
        window.requestAnimationFrame(() => {
            box.classList.toggle('has-overflow', box.classList.contains('is-expanded') && body.scrollHeight > body.clientHeight + 2);
        });
    };
    const render = () => {
        body.replaceChildren(codeBlock(text, mode, 'io-pre wrap'));
        const short = !cut && text.length <= 600 && text.split('\n', 9).length <= 8;
        box.classList.toggle('is-short', short);
        toggle.hidden = short;
    };
    render();
    let loaded = !cut || !loadFull;
    const setExpanded = async (expanded) => {
        box.classList.toggle('is-expanded', expanded);
        toggle.setAttribute('aria-expanded', String(expanded));
        toggle.textContent = expanded ? 'Collapse' : 'Expand';
        state?.set(stateKey, expanded);
        if (expanded && !loaded) {
            loaded = true;
            toggle.setAttribute('aria-busy', 'true');
            try {
                const full = await loadFull();
                text = full.text;
                render();
                size.textContent = formatSize(chars);
                note.textContent = full.note ?? '';
            } catch (error) {
                loaded = false;
                note.textContent = `Could not load the full text: ${error.message}`;
            } finally {
                toggle.removeAttribute('aria-busy');
            }
        }
        if (expanded && anchor === 'end') {
            window.requestAnimationFrame(() => {
                body.scrollTop = body.scrollHeight;
            });
        }
        measure();
    };
    toggle.addEventListener('click', () => setExpanded(!box.classList.contains('is-expanded')));
    body.addEventListener('click', () => {
        if (!box.classList.contains('is-expanded') && !box.classList.contains('is-short') && !String(window.getSelection?.() ?? '')) {
            setExpanded(true);
        }
    });
    box.append(el('div', { class: 'io-head' }, el('span', { class: 'io-title' }, title), size, note, hint, toggle), body);
    if (state?.get(stateKey)) {
        setExpanded(true);
    }
    return box;
}

function rawEvents(detail) {
    const details = el('details', { class: 'disclosure' });
    details.append(el('summary', null, icon('i-chevron'), 'Raw event'));
    const body = el('div', { class: 'disclosure-body' });
    for (const event of detail.events) {
        body.append(codeBlock(JSON.stringify(event, null, 2), true));
    }
    details.append(body);
    return details;
}

function truncatedFor(detail, part, path) {
    return detail.truncated.find((item) => item.part === part && item.path === path) ?? null;
}

/**
 * Builds the expanded detail view for an entry from its recorded events.
 */
function renderDetail(entry, detail, ctx) {
    const body = document.createDocumentFragment();
    const events = detail.events;
    const handled = new Set();
    const byType = (type) => events.findIndex((event) => event.type === type);

    if (entry.kind === 'tool' && entry.preview) {
        const completeIndex = byType('tool.execution_complete');
        const metrics = completeIndex >= 0 ? events[completeIndex].data?.toolTelemetry?.metrics : null;
        if (metrics && typeof metrics === 'object') {
            const pairs = Object.entries(metrics).slice(0, 20).map(([key, value]) => [key.replace(/_/g, ' '), typeof value === 'number' ? value.toLocaleString() : String(value)]);
            const list = kvList(pairs);
            if (list) {
                body.append(el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Telemetry'), list));
            }
        }
        for (const item of detail.truncated) {
            handled.add(`${item.part}:${item.path}`);
        }
    } else if (entry.kind === 'tool') {
        const startIndex = byType('tool.execution_start') >= 0 ? byType('tool.execution_start') : byType('external_tool.requested');
        const completeIndex = byType('tool.execution_complete');
        if (startIndex >= 0) {
            const args = events[startIndex].data?.arguments;
            body.append(el('div', { class: 'detail-block' },
                el('p', { class: 'detail-block-title' }, 'Arguments'),
                el('pre', { class: 'code-well' }, typeof args === 'string' ? args : JSON.stringify(args ?? {}, null, 2))));
        }
        if (completeIndex >= 0) {
            const data = events[completeIndex].data ?? {};
            if (data.error) {
                const message = typeof data.error === 'string' ? data.error : data.error.message;
                body.append(el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Error'), el('pre', { class: 'code-well wrap' }, [message, data.error.code ? `(${data.error.code})` : ''].filter(Boolean).join(' '))));
            }
            const result = data.result ?? {};
            if (typeof result.content === 'string' && result.content.length > 0) {
                handled.add(`${completeIndex}:data.result.content`);
                body.append(pagedText(result.content, truncatedFor(detail, completeIndex, 'data.result.content'), ctx, entry, { title: 'Result' }));
            }
            if (typeof result.detailedContent === 'string' && result.detailedContent.length > 0 && result.detailedContent !== result.content) {
                handled.add(`${completeIndex}:data.result.detailedContent`);
                body.append(pagedText(result.detailedContent, truncatedFor(detail, completeIndex, 'data.result.detailedContent'), ctx, entry, { title: 'Detailed result' }));
            }
            const metrics = data.toolTelemetry?.metrics;
            if (metrics && typeof metrics === 'object') {
                const pairs = Object.entries(metrics).slice(0, 20).map(([key, value]) => [key.replace(/_/g, ' '), typeof value === 'number' ? value.toLocaleString() : String(value)]);
                const list = kvList(pairs);
                if (list) {
                    body.append(el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Telemetry'), list));
                }
            }
        }
    } else if (entry.kind === 'user') {
        const data = events[0]?.data ?? {};
        if (typeof data.content === 'string' && entry.body !== undefined && data.content.length > entry.body.length) {
            handled.add('0:data.content');
            body.append(pagedText(data.content, truncatedFor(detail, 0, 'data.content'), ctx, entry, { title: 'Full message' }));
        }
        if (typeof data.transformedContent === 'string' && data.transformedContent !== data.content) {
            handled.add('0:data.transformedContent');
            body.append(pagedText(data.transformedContent, truncatedFor(detail, 0, 'data.transformedContent'), ctx, entry, { title: 'Prompt as sent, with injected context' }));
        }
        const list = kvList([['Source', data.source], ['Delivery', data.delivery], ['Message ID', data.messageId]]);
        if (list) {
            body.append(list);
        }
    } else if (entry.kind === 'assistant') {
        const data = events[0]?.data ?? {};
        if (typeof data.reasoningText === 'string' && data.reasoningText.length > 0) {
            handled.add('0:data.reasoningText');
            const truncated = truncatedFor(detail, 0, 'data.reasoningText');
            body.append(truncated
                ? pagedText(data.reasoningText, truncated, ctx, entry, { title: 'Reasoning' })
                : el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Reasoning'), proseBlock(data.reasoningText)));
        }
        if (typeof data.content === 'string' && entry.body !== undefined && data.content.length > entry.body.length) {
            handled.add('0:data.content');
            body.append(pagedText(data.content, truncatedFor(detail, 0, 'data.content'), ctx, entry, { title: 'Full response' }));
        }
        const list = kvList([['Model', data.model], ['Provider', data.providerId], ['Request ID', data.apiCallId]]);
        if (list) {
            body.append(list);
        }
    } else if (entry.kind === 'system') {
        const data = events[0]?.data ?? {};
        const sections = typeof ctx.getSystemSections === 'function' ? ctx.getSystemSections() : null;
        if (sections) {
            const table = el('table', { class: 'data-table' },
                el('thead', null, el('tr', null, el('th', { scope: 'col' }, 'Section'), el('th', { scope: 'col' }, 'Size'))),
                el('tbody', null, ...sections.map((section) => el('tr', null, el('td', null, el('code', null, section.name)), el('td', null, formatSize(section.chars))))));
            body.append(el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Sections'), el('div', { class: 'md-table' }, table)));
        }
        if (typeof data.content === 'string') {
            handled.add('0:data.content');
            const full = el('details', { class: 'disclosure' });
            full.append(el('summary', null, icon('i-chevron'), `Show full text (${formatSize(entry.chars)})`));
            const fullBody = el('div', { class: 'disclosure-body' });
            fullBody.append(pagedText(data.content, truncatedFor(detail, 0, 'data.content'), ctx, entry));
            full.append(fullBody);
            body.append(full);
        }
    } else if (entry.kind === 'compaction') {
        // The summary opens from its own drill row; the raw event keeps only its first page.
        const index = events.findIndex((event) => event.type === 'session.compaction_complete');
        if (index >= 0) {
            handled.add(`${index}:data.summaryContent`);
        }
    } else if (entry.kind === 'notification') {
        const content = events[0]?.data?.content;
        if (typeof content === 'string') {
            handled.add('0:data.content');
            body.append(pagedText(content, truncatedFor(detail, 0, 'data.content'), ctx, entry, { title: 'Notification' }));
        }
    }

    for (const item of detail.truncated) {
        if (handled.has(`${item.part}:${item.path}`)) {
            continue;
        }
        const value = getAt(detail.events[item.part], item.path);
        if (typeof value === 'string') {
            body.append(pagedText(value, item, ctx, entry, { title: `Full value of ${item.path.replace(/^data\./, '')}` }));
        }
    }
    body.append(rawEvents(detail));
    return body;
}

function lazyDisclosure(label, entry, ctx) {
    const details = el('details', { class: 'disclosure' });
    const summary = el('summary', null, icon('i-chevron'), label);
    const body = el('div', { class: 'disclosure-body' });
    details.append(summary, body);
    let loaded = false;
    details.addEventListener('toggle', async () => {
        if (!details.open || loaded) {
            return;
        }
        loaded = true;
        body.replaceChildren(el('div', { class: 'skeleton', 'aria-hidden': 'true' }, el('div', { class: 'skeleton-row mid' }), el('div', { class: 'skeleton-row short' })));
        body.setAttribute('aria-busy', 'true');
        try {
            const detail = await ctx.loadDetail(entry);
            body.replaceChildren(renderDetail(entry, detail, ctx));
        } catch (error) {
            loaded = false;
            body.replaceChildren(el('p', { class: 'meta' }, `Could not load details: ${error.message}. Collapse and expand to try again.`));
        } finally {
            body.removeAttribute('aria-busy');
        }
    });
    return details;
}

/**
 * A drill-down row: a disclosure whose body is built the first time it opens.
 *
 * @param {Array<Node | string | null>} summaryParts
 * @param {() => Promise<Array<Node>> | Array<Node>} build
 * @param {string} [extraClass]
 */
function drill(summaryParts, build, extraClass = '') {
    const item = el('details', { class: `drill${extraClass ? ` ${extraClass}` : ''}` });
    const body = el('div', { class: 'drill-body' });
    item.append(el('summary', null, icon('i-chevron'), ...summaryParts), body);
    let built = false;
    item.addEventListener('toggle', async () => {
        if (!item.open || built) {
            return;
        }
        built = true;
        body.replaceChildren(el('p', { class: 'meta' }, 'Loading'));
        try {
            body.replaceChildren(...(await build()));
        } catch (error) {
            built = false;
            body.replaceChildren(el('p', { class: 'meta' }, `Could not load: ${error.message}`));
        }
    });
    return item;
}

function shareBar(part, whole) {
    const fill = el('span', { class: 'share-fill' });
    fill.style.width = `${Math.max(1, Math.min(100, percent(part, whole) ?? 0))}%`;
    return el('span', { class: 'share-bar', 'aria-hidden': 'true' }, fill);
}

/**
 * @param {number} delta Size change in characters.
 * @returns {string} The change with an explicit sign, such as `+2.6 KB` or `−10 chars`.
 */
export function signedSize(delta) {
    if (!Number.isFinite(delta)) {
        return '';
    }
    return `${delta > 0 ? '+' : delta < 0 ? '−' : '±'}${formatSize(Math.abs(delta))}`;
}

const REASON_TEXT = {
    'session resumed': 'the session resumed',
    'context compacted': 'context compaction',
    'model changed': 'a model change',
    notification: 'a notification',
    'new prompt': 'a new prompt',
};

/**
 * @param {string[]} items
 * @returns {string} Items joined as prose: `a`, `a and b`, or `a, b, and c`.
 */
function proseList(items) {
    if (items.length <= 1) {
        return items.join('');
    }
    return items.length === 2 ? `${items[0]} and ${items[1]}` : `${items.slice(0, -1).join(', ')}, and ${items[items.length - 1]}`;
}

/**
 * @param {string[]} reasons Recorded events since the previous version.
 * @returns {string}
 */
export function reasonText(reasons) {
    return proseList((reasons ?? []).map((reason) => REASON_TEXT[reason] ?? reason));
}

/**
 * Explains a system prompt entry: what it is for the first version, and why and how it changed
 * for later versions.
 */
function systemPromptNote(entry) {
    if (!Number.isInteger(entry.version) || entry.version <= 1) {
        return 'Instructions, tool guidance, skills, and environment context the model receives with each request until the prompt is rebuilt.';
    }
    const sentences = [entry.reasons?.length ? `Rebuilt after ${reasonText(entry.reasons)}.` : 'Rebuilt.'];
    const changed = entry.changed;
    if (changed) {
        const more = (shown, count) => (count > shown.length ? `, and ${count - shown.length} more` : '');
        if (changed.addedCount > 0) {
            sentences.push(`Added ${changed.added.join(', ')}${more(changed.added, changed.addedCount)}.`);
        }
        if (changed.removedCount > 0) {
            sentences.push(`Removed ${changed.removed.join(', ')}${more(changed.removed, changed.removedCount)}.`);
        }
        if (changed.resizedCount > 0) {
            sentences.push(`Changed ${changed.resized.map((item) => `${item.name} (${signedSize(item.delta)})`).join(', ')}${more(changed.resized, changed.resizedCount)}.`);
        }
        if (changed.addedCount + changed.removedCount + changed.resizedCount === 0) {
            sentences.push(entry.delta === 0 ? 'Sections and size match the previous version.' : 'Sections match the previous version.');
        }
    }
    sentences.push('It applies to requests from here on.');
    return sentences.join(' ');
}

function splitText(split) {
    if (!split) {
        return null;
    }
    return joinMeta([
        Number.isFinite(split.system) ? `system ${formatTokens(split.system)}` : null,
        Number.isFinite(split.conversation) ? `conversation ${formatTokens(split.conversation)}` : null,
        Number.isFinite(split.tools) ? `tools ${formatTokens(split.tools)}` : null,
    ]) || null;
}

/**
 * Builds the body of a compaction divider: what happened, its numbers, and drill rows for the
 * request sent to the model and the summary it returned.
 */
function compactionBody(entry, ctx) {
    const nodes = [];
    const running = entry.status === 'running';
    const jump = (label, seq) => {
        const button = el('button', { class: 'link-button', type: 'button' }, label);
        button.addEventListener('click', () => ctx.onRevealSeq?.(seq));
        return button;
    };
    if (entry.phase === 'start') {
        nodes.push(el('p', { class: 'entry-summary' },
            running ? 'Copilot is summarizing the conversation up to here in the background while the turn continues. ' : 'Copilot summarized the conversation up to here in the background while the turn continued. ',
            Number.isInteger(entry.resultSeq) ? jump('Go to the result', entry.resultSeq) : null));
        return nodes;
    }
    if (running) {
        nodes.push(el('p', { class: 'entry-summary' }, 'Copilot is summarizing the conversation up to here. The result appears here when it finishes.'));
    } else if (entry.phase === 'result' && Number.isInteger(entry.startSeq)) {
        nodes.push(el('p', { class: 'entry-summary' }, 'The conversation before the start marker was replaced by the summary below. ', jump('Go to the start', entry.startSeq)));
    } else {
        nodes.push(el('p', { class: 'entry-summary' }, 'The conversation above was replaced by the summary below.'));
    }
    const facts = el('dl', { class: 'agent-header-facts cmp-facts' });
    const fact = (label, value) => {
        if (value !== null && value !== undefined && value !== '') {
            facts.append(el('div', { class: 'fact' }, el('dt', null, label), el('dd', null, value)));
        }
    };
    fact('Model', entry.model);
    fact('Trigger', entry.trigger);
    fact('Tokens used', Number.isFinite(entry.inputTokens) ? joinMeta([`${formatTokens(entry.inputTokens)} in`, Number.isFinite(entry.outputTokens) ? `${formatTokens(entry.outputTokens)} out` : null]) : null);
    fact('Before', splitText(entry.split?.before));
    fact('After', splitText(entry.split?.after));
    if (Number.isFinite(entry.checkpointNumber)) {
        fact('Checkpoint', el('span', { title: entry.checkpointName ?? '' }, `${entry.checkpointNumber}${entry.checkpointName ? ` · ${entry.checkpointName}` : ''}`));
    }
    if (facts.childElementCount > 0) {
        nodes.push(facts);
    }
    if (entry.error) {
        nodes.push(el('p', { class: 'hook-failure' }, icon('i-x-circle'), el('span', null, entry.error)));
    }
    if (!running) {
        const rows = el('ul', { class: 'drill-list' });
        if (Number.isFinite(entry.requestChars) && entry.requestChars > 0) {
            rows.append(el('li', null, drill(
                [el('span', { class: 'drill-label' }, 'Compaction request'), el('span', { class: 'meta' }, joinMeta([formatSize(entry.requestChars), Number.isFinite(entry.requestMessages) ? `sent with ${entry.requestMessages} messages` : null]))],
                async () => {
                    const text = await ctx.loadCompaction(entry, 'request');
                    return [ioBox({ title: 'Instruction sent with the conversation', text, chars: text.length, mode: 'tags', anchor: 'start' })];
                })));
        } else {
            rows.append(el('li', null, el('p', { class: 'meta drill-note' }, 'This session did not record the compaction request.')));
        }
        if (Number.isFinite(entry.summaryChars) && entry.summaryChars > 0) {
            rows.append(el('li', null, drill(
                [el('span', { class: 'drill-label' }, 'Summary response'), el('span', { class: 'meta' }, formatSize(entry.summaryChars))],
                async () => {
                    const text = await ctx.loadCompaction(entry, 'summary');
                    return [ioBox({ title: 'Summary that replaced the compacted messages', text, chars: text.length, mode: 'tags', anchor: 'start' })];
                })));
        }
        nodes.push(rows);
    }
    nodes.push(lazyDisclosure('Raw events', entry, ctx));
    return nodes;
}

/**
 * The inline system prompt view: facts, then sections, skills, instruction files, and the full
 * text, each opening in place.
 */
function systemPromptPanel(entry, ctx) {
    const panel = el('details', { class: 'disclosure sp-panel' });
    panel.append(el('summary', null, icon('i-chevron'), `Prompt structure: ${entry.sectionCount} sections, skills, instructions, and full text`));
    const body = el('div', { class: 'disclosure-body sp-body' });
    panel.append(body);
    let loaded = false;
    panel.addEventListener('toggle', async () => {
        if (!panel.open || loaded) {
            return;
        }
        loaded = true;
        body.replaceChildren(el('p', { class: 'meta' }, 'Loading the prompt structure'));
        try {
            const prompt = await ctx.loadSystemPrompt(entry.seq);
            body.replaceChildren(...systemPromptBody(prompt, ctx));
        } catch (error) {
            loaded = false;
            body.replaceChildren(el('p', { class: 'meta' }, `Could not load the system prompt: ${error.message}`));
        }
    });
    return panel;
}

function systemPromptBody(prompt, ctx) {
    const nodes = [];
    const facts = el('dl', { class: 'agent-header-facts sp-facts' });
    const fact = (label, value) => {
        if (value !== null && value !== undefined && value !== '') {
            facts.append(el('div', { class: 'fact' }, el('dt', null, label), el('dd', null, value)));
        }
    };
    fact('Version', Number.isInteger(prompt.version) && prompt.versionCount > 1 ? `${prompt.version} of ${prompt.versionCount}` : null);
    fact('Size', formatSize(prompt.chars));
    const share = percent(prompt.staticChars, prompt.chars);
    fact('Static', share !== null && prompt.staticChars > 0 ? `${Math.round(share)}%` : null);
    fact('Sections', String(prompt.sections.length));
    fact('Skills', String(prompt.skills.length));
    fact('Instruction files', String(prompt.instructions.length));
    fact('Agent instructions', prompt.agentInstructions?.title ?? (prompt.agentInstructions ? 'Present' : null));
    fact('Prompt format', prompt.promptVersion);
    nodes.push(facts);

    const sections = el('ul', { class: 'drill-list' });
    for (const section of prompt.sections) {
        const label = [el('code', null, section.name), el('span', { class: 'meta' }, formatSize(section.chars)), shareBar(section.chars, prompt.chars)];
        sections.append(el('li', null, drill(label, async () => {
            if (!Number.isInteger(section.start)) {
                return [el('p', { class: 'meta' }, 'Text outside tagged sections; see the full text below.')];
            }
            const text = await ctx.loadPromptText(prompt.seq, section.start, section.chars);
            return [ioBox({ title: 'Section text', text, chars: text.length, mode: 'tags', anchor: 'start' })];
        })));
    }
    nodes.push(el('h4', { class: 'sp-heading' }, `Sections (${prompt.sections.length})`), sections);

    if (prompt.skills.length > 0) {
        nodes.push(drill([el('span', { class: 'sp-heading-inline' }, `Skills available (${prompt.skills.length})`)], () => [
            el('ul', { class: 'details-list' }, ...prompt.skills.map((skill) => el('li', null, el('span', { class: 'item-name mono' }, skill.name), skill.description ? el('span', { class: 'item-path' }, skill.description) : null))),
        ]));
    }
    if (prompt.instructions.length > 0) {
        nodes.push(drill([el('span', { class: 'sp-heading-inline' }, `Instruction files (${prompt.instructions.length})`)], () => [
            el('ul', { class: 'details-list' }, ...prompt.instructions.map((item) => el('li', null,
                el('span', { class: 'item-name mono' }, item.path),
                el('span', { class: 'item-path' }, [item.applyTo ? `applies to ${item.applyTo}` : null, item.description].filter(Boolean).join(' · '))))),
        ]));
    }
    nodes.push(drill([el('span', { class: 'sp-heading-inline' }, `Full text (${formatSize(prompt.chars)})`)], async () => {
        const text = await ctx.loadPromptText(prompt.seq, 0, prompt.chars);
        return [ioBox({ title: 'Full system prompt', text, chars: text.length, mode: 'tags', anchor: 'start' })];
    }));
    return nodes;
}

/**
 * Builds the argument and output or error boxes for a tool entry.
 */
function toolBoxes(entry, preview, ctx) {
    const boxes = [];
    if (preview.args !== null && preview.args !== undefined) {
        boxes.push(ioBox({
            title: entry.subagent ? 'Task arguments' : 'Arguments',
            text: preview.args,
            chars: preview.argsChars,
            json: preview.argsJson || looksLikeJson(preview.args),
            anchor: 'start',
            state: ctx.ui,
            stateKey: `args:${entry.seq}`,
            loadFull: async () => {
                const detail = await ctx.loadDetail(entry);
                const start = detail.events.find((event) => event.type === 'tool.execution_start' || event.type === 'external_tool.requested');
                const args = start?.data?.arguments;
                const cutValues = detail.truncated.filter((item) => item.path.startsWith('data.arguments'));
                return {
                    text: typeof args === 'string' ? args : JSON.stringify(args ?? {}, null, 2),
                    note: cutValues.length ? `${cutValues.length} long ${cutValues.length === 1 ? 'value is' : 'values are'} cut at ${formatSize(detail.pageChars)}; see raw events` : '',
                };
            },
        }));
    }
    if (preview.error) {
        boxes.push(ioBox({ title: 'Error', text: preview.error, chars: preview.errorChars, json: false, anchor: 'end', tone: 'error', state: ctx.ui, stateKey: `error:${entry.seq}` }));
    }
    if (preview.output !== null && preview.output !== undefined) {
        boxes.push(ioBox({
            title: entry.subagent ? 'Final result' : 'Output',
            text: preview.output,
            chars: preview.outputChars,
            json: looksLikeJson(preview.output),
            anchor: 'end',
            state: ctx.ui,
            stateKey: `output:${entry.seq}`,
            loadFull: async () => {
                const page = Math.max(0, preview.outputChars - 128 * 1024);
                const field = await ctx.loadField(entry, preview.outputPart, preview.outputPath, page);
                return { text: field.text, note: page > 0 ? `Showing the last ${formatSize(field.text.length)}` : '' };
            },
        }));
    } else if (entry.status === 'running') {
        boxes.push(el('p', { class: 'meta io-pending' }, icon('i-clock'), 'Waiting for output'));
    }
    return boxes;
}

/**
 * Lists a turn's hook runs; each run loads its input, output, and error on demand.
 */
function hookList(entry, runs, ctx) {
    const failed = runs.filter((run) => run.status === 'failed').length;
    const details = el('details', { class: 'disclosure' });
    const label = `Hooks (${entry.hooks}${failed ? `, ${failed} failed` : ''})`;
    details.append(el('summary', null, icon('i-chevron'), label));
    const body = el('div', { class: 'disclosure-body' });
    details.append(body);
    let built = false;
    details.addEventListener('toggle', () => {
        if (!details.open || built) {
            return;
        }
        built = true;
        const list = el('ul', { class: 'hook-runs' });
        runs.forEach((run, runIndex) => {
            const item = el('details', { class: `hook-run status-${run.status}` });
            const summary = el('summary', null,
                icon('i-chevron'),
                el('code', null, run.type),
                run.tool ? el('span', { class: 'meta mono' }, run.tool) : null,
                statusNode(run.status),
                el('span', { class: 'meta' }, joinMeta([formatTime(run.ts), Number.isFinite(run.durationMs) ? formatDuration(run.durationMs) : null])));
            const runBody = el('div', { class: 'hook-run-body' });
            item.append(summary, runBody);
            let loaded = false;
            item.addEventListener('toggle', async () => {
                if (!item.open || loaded) {
                    return;
                }
                loaded = true;
                runBody.replaceChildren(el('p', { class: 'meta' }, 'Loading hook details'));
                try {
                    const detail = await ctx.loadHook(entry, runIndex);
                    runBody.replaceChildren(...hookDetail(detail, ctx));
                } catch (error) {
                    loaded = false;
                    runBody.replaceChildren(el('p', { class: 'meta' }, `Could not load hook details: ${error.message}`));
                }
            });
            list.append(el('li', null, item));
        });
        if (entry.hookRunsDropped > 0) {
            list.append(el('li', { class: 'meta' }, `${entry.hookRunsDropped} more hook runs are not listed.`));
        }
        body.append(list);
    });
    return details;
}

function hookDetail(detail, ctx) {
    const start = detail.events.find((event) => event.type === 'hook.start');
    const end = detail.events.find((event) => event.type === 'hook.end');
    const nodes = [];
    const json = (value) => (typeof value === 'string' ? value : JSON.stringify(value, null, 2) ?? '');
    const error = end?.data?.error;
    if (error) {
        const message = typeof error === 'string' ? error : error.message ?? '';
        nodes.push(ioBox({ title: 'Error', text: message, chars: message.length, json: false, anchor: 'start', tone: 'error' }));
        const facts = kvList([['Source', typeof error === 'object' ? error.source : null]]);
        if (facts) {
            nodes.push(facts);
        }
        if (typeof error === 'object' && typeof error.stack === 'string' && error.stack.length > 0) {
            nodes.push(ioBox({ title: 'Stack', text: error.stack, chars: error.stack.length, json: false, anchor: 'start', tone: 'error' }));
        }
    }
    if (start?.data?.input !== undefined) {
        const text = json(start.data.input);
        nodes.push(ioBox({ title: 'Input', text, chars: text.length, json: true, anchor: 'start' }));
    }
    if (end?.data?.output !== undefined && end.data.output !== null) {
        const text = json(end.data.output);
        nodes.push(ioBox({ title: 'Output', text, chars: text.length, json: true, anchor: 'end' }));
    } else if (end) {
        nodes.push(el('p', { class: 'meta' }, 'The hook returned no output.'));
    }
    if (detail.truncated.length > 0) {
        nodes.push(el('p', { class: 'meta' }, `${detail.truncated.length} long ${detail.truncated.length === 1 ? 'value is' : 'values are'} cut at ${formatSize(detail.pageChars)}.`));
    }
    nodes.push(rawEvents(detail));
    return nodes;
}

function subagentCard(entry, ctx) {
    const agent = ctx.agents.get(entry.subagent);
    const status = agent?.status ?? 'running';
    const button = el('button', { class: 'btn btn-small', type: 'button', dataset: { openAgent: entry.subagent } }, icon('i-open'), 'Open subagent log');
    button.addEventListener('click', () => ctx.onOpenAgent(entry.subagent, entry));
    const meta = joinMeta([
        agent?.model ?? null,
        Number.isFinite(agent?.durationMs) ? formatDuration(agent.durationMs) : null,
        Number.isFinite(agent?.totalToolCalls) ? `${agent.totalToolCalls} tool calls` : agent?.counts ? `${agent.counts.tools} tool calls` : null,
        Number.isFinite(agent?.totalTokens) ? `${formatTokens(agent.totalTokens)} tokens` : null,
    ]);
    return el('div', { class: 'subagent-card' },
        el('div', { class: 'subagent-card-head' },
            icon('i-agent'),
            el('span', { class: 'subagent-card-name' }, agentLabel(agent)),
            agent?.agentType && agent.agentType !== agentLabel(agent) ? el('span', { class: 'badge badge-agent' }, agent.agentType) : null,
            statusNode(status)),
        agent?.description ? el('p', { class: 'meta' }, agent.description) : null,
        meta ? el('p', { class: 'meta' }, meta) : null,
        agent?.error ? el('p', { class: 'meta' }, `Error: ${agent.error}`) : null,
        el('div', { class: 'detail-actions' }, button));
}

/**
 * Renders one log entry as an ARIA feed article.
 *
 * @param {object} entry Entry from the server.
 * @param {object} ctx Rendering context.
 * @returns {HTMLElement}
 */
export function renderEntry(entry, ctx) {
    const headingId = `h-${ctx.agentKey}-${entry.seq}`;
    const isSubagentTool = entry.kind === 'tool' && entry.subagent;
    const article = el('article', {
        class: `entry entry-${entry.kind}${isSubagentTool ? ' entry-agent' : ''}`,
        id: `entry-${entry.seq}`,
        tabindex: '-1',
        'aria-labelledby': headingId,
        'aria-posinset': entry.index + 1,
        'aria-setsize': ctx.total,
        dataset: { seq: String(entry.seq), kind: entry.kind, ...(entry.toolCallId ? { tool: entry.toolCallId } : {}), ...(entry.subagent ? { subagent: entry.subagent } : {}) },
    });
    const marker = el('div', { class: 'marker' }, icon(isSubagentTool ? 'i-agent' : KIND_ICON[entry.kind] ?? 'i-question'));
    const content = el('div', { class: 'entry-content' });

    const heading = el('h3', { id: headingId }, el('span', { class: 'entry-role' }, isSubagentTool ? 'Subagent' : entry.label ?? entry.kind));
    if (entry.kind === 'tool' || entry.kind === 'skill') {
        heading.append(' ', el('span', { class: 'entry-name' }, entry.name ?? ''));
    }
    const metaParts = [formatTime(entry.ts)];
    if (Number.isFinite(entry.durationMs)) {
        metaParts.push(formatDuration(entry.durationMs));
    }
    if (entry.kind === 'turn') {
        if (Number.isFinite(entry.inputTokens)) {
            metaParts.push(`${formatTokens(entry.inputTokens)} in`);
        }
        if (Number.isFinite(entry.outputTokens)) {
            metaParts.push(`${formatTokens(entry.outputTokens)} out`);
        }
        const pct = percent(entry.inputTokens, entry.maxPromptTokens);
        if (pct !== null) {
            metaParts.push(`context ${Math.round(pct)}%`);
        }
        if (entry.requests > 1) {
            metaParts.push(`${entry.requests} requests`);
        }
        if (entry.hooks > 0) {
            metaParts.push(`hooks ${entry.hooks}${entry.hooksFailed ? ` (${entry.hooksFailed} failed)` : ''}`);
        }
    }
    if (entry.kind === 'assistant' && entry.model && entry.model !== ctx.agentModel) {
        metaParts.push(entry.model);
    }
    if (entry.kind === 'system') {
        const count = ctx.agents.get(ctx.agentKey)?.systemPromptCount ?? 0;
        if (Number.isInteger(entry.version) && count > 1) {
            metaParts.push(`version ${entry.version} of ${count}`);
        }
        metaParts.push(formatSize(entry.chars));
        if (Number.isFinite(entry.delta)) {
            metaParts.push(`${signedSize(entry.delta)} from version ${entry.version - 1}`);
        }
        metaParts.push(`${entry.sectionCount} sections`);
        const share = percent(entry.staticChars, entry.chars);
        if (share !== null && share > 0) {
            metaParts.push(`${Math.round(share)}% static`);
        }
    }
    if (entry.kind === 'compaction') {
        if (entry.phase === 'start' || entry.status === 'running') {
            if (Number.isFinite(entry.before)) {
                const used = percent(entry.before, entry.limit);
                metaParts.push(`${formatTokens(entry.before)}${Number.isFinite(entry.limit) ? ` of ${formatTokens(entry.limit)}` : ''} tokens${used !== null ? ` (${Math.round(used)}%)` : ''}`);
            }
        } else {
            if (Number.isFinite(entry.before) && Number.isFinite(entry.after)) {
                const kept = percent(entry.after, entry.before);
                metaParts.push(`${formatTokens(entry.before)} to ${formatTokens(entry.after)} tokens${kept !== null ? ` (${Math.round(100 - kept)}% smaller)` : ''}`);
            } else if (Number.isFinite(entry.before)) {
                metaParts.push(`${formatTokens(entry.before)} tokens`);
            }
            if (Number.isFinite(entry.removed)) {
                metaParts.push(Number.isFinite(entry.messagesBefore) ? `${entry.removed} of ${entry.messagesBefore} messages removed` : `${entry.removed} messages removed`);
            }
        }
    }
    const head = el('div', { class: 'entry-head' },
        heading,
        el('span', { class: 'entry-meta' }, joinMeta(metaParts)),
        statusNode(isSubagentTool ? ctx.agents.get(entry.subagent)?.status ?? entry.status : entry.status),
        el('span', { class: 'badge badge-current new-badge' }, 'New'));
    content.append(head);

    switch (entry.kind) {
        case 'user': {
            if (entry.attachments?.length) {
                content.append(el('div', { class: 'attachments' }, ...entry.attachments.map((attachment) => el('span', { class: 'badge' }, `${attachment.type}: ${attachment.name || 'unnamed'}`))));
            }
            const text = entry.body ?? entry.summary ?? '';
            content.append(proseBlock(text));
            const extra = [];
            if (entry.chars > text.length) {
                extra.push(`message continues (${formatSize(entry.chars)})`);
            }
            if (entry.injectedChars > 0) {
                extra.push(`injected context ${formatSize(entry.injectedChars)}`);
            }
            content.append(lazyDisclosure(extra.length ? `Details: ${extra.join(', ')}` : 'Details', entry, ctx));
            break;
        }
        case 'assistant': {
            const text = entry.body ?? entry.summary ?? '';
            if (text.trim().length > 0) {
                content.append(proseBlock(text));
            }
            if (entry.toolRequests?.length) {
                const links = el('p', { class: 'entry-summary muted' }, `Requested ${entry.toolRequests.length} tool ${entry.toolRequests.length === 1 ? 'call' : 'calls'}: `);
                entry.toolRequests.slice(0, 12).forEach((request, requestIndex) => {
                    if (requestIndex > 0) {
                        links.append(', ');
                    }
                    if (request.id) {
                        const link = el('button', { class: 'link-button mono', type: 'button' }, request.name ?? 'tool');
                        link.addEventListener('click', () => ctx.onRevealTool(request.id));
                        links.append(link);
                    } else {
                        links.append(request.name ?? 'tool');
                    }
                });
                if (entry.toolRequests.length > 12) {
                    links.append(`, and ${entry.toolRequests.length - 12} more`);
                }
                content.append(links);
            }
            const extra = [];
            if (entry.reasoningChars > 0) {
                extra.push(`reasoning ${formatSize(entry.reasoningChars)}`);
            }
            if (entry.chars > text.length) {
                extra.push(`response continues (${formatSize(entry.chars)})`);
            }
            content.append(lazyDisclosure(extra.length ? `Details: ${extra.join(', ')}` : 'Details', entry, ctx));
            break;
        }
        case 'tool': {
            const collapsed = ctx.ui?.get(`tool:${entry.seq}`) === true;
            const collapse = el('button', { class: 'btn btn-icon btn-compact tool-collapse', type: 'button', 'aria-expanded': String(!collapsed), title: collapsed ? 'Show arguments and output' : 'Hide arguments and output' },
                icon('i-chevron'), el('span', { class: 'visually-hidden' }, collapsed ? 'Show arguments and output' : 'Hide arguments and output'));
            head.prepend(collapse);
            const line = [entry.title && entry.title !== entry.summary ? entry.title : null, entry.summary].filter(Boolean).join(': ');
            if (line) {
                content.append(el('p', { class: 'entry-summary' }, line));
            }
            const bodyWrap = el('div', { class: 'tool-body' });
            if (isSubagentTool) {
                bodyWrap.append(subagentCard(entry, ctx));
            }
            const preview = entry.preview;
            if (preview) {
                bodyWrap.append(...toolBoxes(entry, preview, ctx));
            } else if (entry.result && !isSubagentTool) {
                bodyWrap.append(el('p', { class: 'entry-summary muted mono' }, entry.result));
            }
            bodyWrap.append(lazyDisclosure(preview ? 'Telemetry and raw events' : isSubagentTool ? 'Task arguments and final result' : 'Arguments and result', entry, ctx));
            content.append(bodyWrap);
            article.classList.toggle('is-collapsed', collapsed);
            collapse.addEventListener('click', () => {
                const next = !article.classList.contains('is-collapsed');
                article.classList.toggle('is-collapsed', next);
                collapse.setAttribute('aria-expanded', String(!next));
                const label = next ? 'Show arguments and output' : 'Hide arguments and output';
                collapse.title = label;
                collapse.querySelector('.visually-hidden').textContent = label;
                ctx.ui?.set(`tool:${entry.seq}`, next);
            });
            break;
        }
        case 'turn': {
            const runs = Array.isArray(entry.hookRuns) ? entry.hookRuns : [];
            const failures = runs.map((run, runIndex) => ({ run, runIndex })).filter(({ run }) => run.status === 'failed');
            for (const { run } of failures.slice(0, 5)) {
                content.append(el('p', { class: 'hook-failure' }, icon('i-x-circle'),
                    el('span', null, el('code', null, run.type), run.tool ? ` for ${run.tool}` : '', ' failed', run.error ? `: ${run.error}` : '')));
            }
            if (failures.length > 5) {
                content.append(el('p', { class: 'meta' }, `${failures.length - 5} more failed hooks are listed below.`));
            }
            if (runs.length > 0) {
                content.append(hookList(entry, runs, ctx));
            }
            break;
        }
        case 'system': {
            content.append(el('p', { class: 'entry-summary muted' }, systemPromptNote(entry)));
            content.append(systemPromptPanel(entry, ctx));
            break;
        }
        case 'compaction': {
            article.classList.add(`compaction-${entry.phase ?? 'single'}`);
            content.append(...compactionBody(entry, ctx));
            break;
        }
        case 'notification': {
            if (entry.summary) {
                content.append(el('p', { class: 'entry-summary' }, entry.summary));
            }
            if (entry.ref && ctx.agents.has(entry.ref)) {
                const button = el('button', { class: 'link-button', type: 'button' }, `Open ${agentLabel(ctx.agents.get(entry.ref))} log`);
                button.addEventListener('click', () => ctx.onOpenAgent(entry.ref));
                content.append(el('p', { class: 'entry-summary' }, button));
            }
            content.append(lazyDisclosure('Raw event', entry, ctx));
            break;
        }
        default: {
            if (entry.summary) {
                content.append(el('p', { class: 'entry-summary' }, entry.summary));
            }
            if (entry.outcome) {
                content.append(el('p', { class: 'entry-summary muted' }, `Outcome: ${entry.outcome}`));
            }
            if (entry.kind !== 'turn') {
                content.append(lazyDisclosure('Raw event', entry, ctx));
            }
        }
    }

    article.append(marker, content);
    return article;
}

/**
 * Renders the agent header card with model, context, and totals.
 */
export function renderAgentHeader(container, agent, summary, ctx) {
    container.replaceChildren();
    if (!agent) {
        return;
    }
    const isRoot = agent.key === 'root';
    const title = isRoot ? (agent.customAgent?.displayName ? `${agent.customAgent.displayName} (main agent)` : 'Main agent') : agentLabel(agent);
    const top = el('div', { class: 'agent-header-top' },
        el('h2', { id: 'agentHeading' }, title),
        !isRoot && agent.agentType ? el('span', { class: 'badge badge-agent' }, agent.agentType) : null,
        !isRoot ? statusNode(agent.status) : null,
        isRoot && ctx.session?.active ? el('span', { class: 'badge badge-live' }, icon('i-dot'), 'Active') : null);
    container.append(top);
    if (!isRoot && agent.description) {
        container.append(el('p', { class: 'meta' }, agent.description));
    }

    const facts = el('dl', { class: 'agent-header-facts' });
    const fact = (label, value) => {
        if (value === null || value === undefined || value === '') {
            return;
        }
        facts.append(el('div', { class: 'fact' }, el('dt', null, label), el('dd', null, value)));
    };
    fact('Model', joinMeta([agent.model, agent.reasoningEffort ? `${agent.reasoningEffort} effort` : null, agent.contextTier]) || 'Not recorded');
    if (agent.models?.length > 1) {
        fact('Model changes', String(agent.models.length - 1));
    }
    fact('Turns', String(agent.counts.turns));
    fact('Tool calls', String(agent.counts.tools));
    if (agent.children?.length) {
        fact('Subagents', String(agent.children.length));
    }
    if (agent.usage?.requests) {
        fact('Model requests', `${agent.usage.requests} · ${formatTokens(agent.usage.inputTokens)} in · ${formatTokens(agent.usage.outputTokens)} out`);
    }
    if (Number.isFinite(agent.durationMs)) {
        fact('Duration', formatDuration(agent.durationMs));
    }
    if (isRoot && summary?.session) {
        const start = summary.session.start;
        fact('Copilot', start?.copilotVersion ?? null);
        const premium = summary.session.shutdown?.totalPremiumRequests ?? summary.session.checkpoint?.totalPremiumRequests;
        if (Number.isFinite(premium)) {
            fact('Premium requests', String(premium));
        }
    }
    container.append(facts);

    const context = agent.context ?? {};
    const meterRow = el('div', { class: 'meter-row' });
    const pct = percent(context.current, context.limit);
    const label = Number.isFinite(context.current)
        ? `Context ${formatTokens(context.current)}${Number.isFinite(context.limit) ? ` of ${formatTokens(context.limit)} tokens` : ' tokens'}${pct !== null ? ` (${Math.round(pct)}%)` : ''}`
        : 'Context usage not recorded';
    const secondary = [];
    if (Number.isFinite(context.peak) && context.peak !== context.current) {
        secondary.push(`peak ${formatTokens(context.peak)}`);
    }
    if (agent.compactions?.length) {
        secondary.push(`${agent.compactions.length} ${agent.compactions.length === 1 ? 'compaction' : 'compactions'}`);
    }
    meterRow.append(el('p', { class: 'meta' }, label, secondary.length ? el('span', { class: 'meter-secondary' }, ` · ${secondary.join(' · ')}`) : null));
    if (pct !== null) {
        const meter = el('div', { class: 'meter', 'aria-hidden': 'true' });
        const fill = el('div', { class: 'meter-fill' });
        fill.style.width = `${pct}%`;
        meter.append(fill);
        const peakPct = percent(context.peak, context.limit);
        if (peakPct !== null && peakPct > pct) {
            const tick = el('div', { class: 'meter-tick' });
            tick.style.left = `calc(${peakPct}% - 1px)`;
            meter.append(tick);
        }
        for (const compaction of agent.compactions ?? []) {
            const at = percent(compaction.before, context.limit);
            if (at !== null) {
                const tick = el('div', { class: 'meter-tick compaction' });
                tick.style.left = `calc(${at}% - 1px)`;
                meter.append(tick);
            }
        }
        meterRow.append(meter);
    }
    container.append(meterRow);
    if (agent.systemPrompt && ctx.onShowSystemPrompt) {
        container.append(systemPromptNav(agent, ctx));
    }
}

/**
 * The System prompt control in the agent card: opens the latest version and lists every
 * recorded version with its time, size, change, and reason.
 */
function systemPromptNav(agent, ctx) {
    const count = agent.systemPromptCount ?? 1;
    const versions = agent.systemPromptVersions ?? [];
    const nav = el('div', { class: 'sp-nav' });
    const open = el('button', { class: 'btn btn-small', type: 'button', title: 'Show the latest system prompt in the log and open its structure' },
        icon('i-book'), count > 1 ? `System prompt, version ${count}` : 'System prompt');
    open.addEventListener('click', () => ctx.onShowSystemPrompt(agent.key, null));
    nav.append(open);
    if (count > 1) {
        const list = el('details', { class: 'disclosure sp-versions' });
        list.open = ctx.ui?.get(`sp-versions:${agent.key}`) === true;
        list.addEventListener('toggle', () => ctx.ui?.set(`sp-versions:${agent.key}`, list.open));
        list.append(el('summary', null, icon('i-chevron'), `All ${count} versions`));
        const items = el('ol', { class: 'nav-list sp-version-list' });
        for (const version of versions) {
            const detail = version.version === 1 ? 'initial' : version.reasons?.length ? `after ${reasonText(version.reasons)}` : 'rebuilt';
            const button = el('button', { class: 'nav-item sp-version', type: 'button' },
                el('span', { class: 'nav-item-name' }, `v${version.version}`),
                el('span', { class: 'nav-item-text' }, joinMeta([formatSize(version.chars), Number.isFinite(version.delta) ? signedSize(version.delta) : null, detail])),
                el('span', { class: 'nav-item-time' }, formatTime(version.ts)));
            button.title = `Version ${version.version} at ${version.ts ?? 'an unknown time'}: ${detail}`;
            button.addEventListener('click', () => ctx.onShowSystemPrompt(agent.key, version.seq));
            items.append(el('li', null, button));
        }
        const body = el('div', { class: 'disclosure-body' }, items);
        if (count > versions.length) {
            body.append(el('p', { class: 'meta' }, `${count - versions.length} earlier versions are not listed.`));
        }
        list.append(body);
        nav.append(list);
    }
    return nav;
}

function statusNote(status) {
    switch (status) {
        case 'live':
            return 'Live from this session';
        case 'reconstructed':
            return 'Reconstructed from the session log';
        case 'unavailable':
            return 'Unavailable from the host; nothing recorded in the log';
        default:
            return 'Not recorded in session';
    }
}

function listGroup(title, list, renderItem, open = false) {
    const items = list?.items ?? [];
    const details = el('details', { class: 'disclosure details-group' });
    if (open) {
        details.open = true;
    }
    details.append(el('summary', null, icon('i-chevron'), `${title} (${items.length})`));
    const body = el('div', { class: 'disclosure-body' });
    body.append(el('p', { class: 'source-note' }, statusNote(list?.status)));
    if (items.length > 0) {
        const ul = el('ul', { class: 'details-list' });
        for (const item of items.slice(0, 400)) {
            ul.append(renderItem(item));
        }
        body.append(ul);
        if (items.length > 400) {
            body.append(el('p', { class: 'meta' }, `${items.length - 400} more not shown`));
        }
    }
    details.append(body);
    return details;
}

/**
 * Renders the Details panel: session metadata, counts, and inventories.
 */
export function renderDetailsPanel(container, { summary, inventory, agent, session }) {
    container.replaceChildren();
    if (!summary) {
        container.append(el('p', { class: 'meta' }, 'Select a session to see its details.'));
        return;
    }
    const start = summary.session?.start ?? {};
    container.append(el('h2', { class: 'panel-heading' }, 'Session'));
    container.append(kvList([
        ['Host', session?.clientLabel ?? session?.client ?? 'Not recorded'],
        ['Repository', start.repository ?? session?.repository],
        ['Branch', start.branch ?? session?.branch],
        ['Working folder', start.cwd ?? session?.cwd],
        ['Started', start.startTime ? `${formatRelativeDate(start.startTime)} ${formatTime(start.startTime)}` : null],
        ['Copilot version', start.copilotVersion],
        ['Session ID', session?.sessionId],
        ['Log size', Number.isFinite(summary.fileBytes) ? formatSize(summary.fileBytes) : null],
        ['Events', summary.counts?.events?.toLocaleString()],
        ['Resumes', summary.session?.resumes ? String(summary.session.resumes) : null],
        ['Model debug events', summary.counts?.debugEvents ? String(summary.counts.debugEvents) : null],
        ['Binary assets', summary.counts?.binaryAssets ? String(summary.counts.binaryAssets) : null],
        ['Unreadable lines', summary.counts?.malformed ? String(summary.counts.malformed) : null],
    ]) ?? el('p', { class: 'meta' }, 'Not recorded'));

    if (summary.counts?.unknownTypes?.length) {
        container.append(el('p', { class: 'meta' }, `Other event types: ${summary.counts.unknownTypes.map((item) => `${item.type} (${item.count})`).join(', ')}`));
    }

    container.append(el('h2', { class: 'panel-heading' }, agent?.key === 'root' ? 'Main agent' : agentLabel(agent)));
    if (!inventory) {
        container.append(el('div', { class: 'skeleton', 'aria-hidden': 'true' }, el('div', { class: 'skeleton-row mid' }), el('div', { class: 'skeleton-row' }), el('div', { class: 'skeleton-row short' })));
        return;
    }
    const model = inventory.model?.item;
    const current = inventory.currentAgent?.item;
    container.append(kvList([
        ['Model', model?.modelId ?? agent?.model ?? 'Not recorded'],
        ['Reasoning effort', model?.reasoningEffort ?? agent?.reasoningEffort],
        ['Context tier', model?.contextTier ?? agent?.contextTier],
        ['Custom agent', current ? current.displayName || current.name : 'None recorded'],
        ['Inventory source', inventory.isLive ? 'Live from this session, with recorded fallback' : 'Reconstructed from the session log'],
    ]));

    const sp = inventory.recorded?.systemPrompt;
    if (sp) {
        container.append(listGroup('System prompt sections', { status: 'reconstructed', items: sp.sections }, (section) => el('li', null, el('span', { class: 'item-name' }, section.name), el('span', { class: 'meta' }, formatSize(section.chars)))));
    }
    const invoked = new Set((inventory.invokedSkills?.items ?? []).map((item) => item.name));
    container.append(listGroup('Skills', inventory.skills, (skill) => el('li', null,
        el('span', { class: 'item-name' }, skill.name ?? 'Unnamed', invoked.has(skill.name) ? ' ' : null, invoked.has(skill.name) ? el('span', { class: 'badge badge-current' }, 'Invoked') : null, skill.enabled === false ? el('span', { class: 'badge' }, 'Disabled') : null),
        skill.description ? el('span', { class: 'meta' }, skill.description) : null,
        skill.pluginName || skill.source ? el('span', { class: 'item-path' }, [skill.pluginName ? `plugin ${skill.pluginName}` : null, skill.source].filter(Boolean).join(' · ')) : null)));
    container.append(listGroup('Skills invoked', inventory.invokedSkills, (skill) => el('li', null, el('span', { class: 'item-name' }, skill.name ?? 'Unnamed'))));
    container.append(listGroup('Instructions and rules', inventory.instructions, (item) => el('li', null,
        item.label ? el('span', { class: 'item-name' }, item.label) : null,
        item.sourcePath ? el('span', { class: 'item-path' }, item.sourcePath) : null,
        item.applyTo?.length ? el('span', { class: 'meta' }, `Applies to ${item.applyTo.join(', ')}`) : null,
        item.description ? el('span', { class: 'meta' }, item.description) : null)));
    container.append(listGroup('Available agents', inventory.agents, (item) => el('li', null,
        el('span', { class: 'item-name' }, item.displayName || item.name || 'Unnamed'),
        item.description ? el('span', { class: 'meta' }, item.description) : null,
        el('span', { class: 'item-path' }, [item.source, item.model, Number.isFinite(item.toolCount) ? `${item.toolCount} tools` : null].filter(Boolean).join(' · ')))));
    if (inventory.subagentTypes?.length) {
        container.append(listGroup('Subagent types used', { status: 'reconstructed', items: inventory.subagentTypes }, (item) => el('li', null, el('span', { class: 'item-name' }, item.type), el('span', { class: 'meta' }, `${item.count} ${item.count === 1 ? 'run' : 'runs'}`))));
    }
    const tools = inventory.tools ?? { names: [] };
    const toolNote = Number.isFinite(tools.declaredCount)
        ? `${tools.declaredCount} tools were offered; ${tools.names.length} names were recorded`
        : `${tools.names.length} tool names recorded`;
    const used = Array.isArray(agent?.tools) ? agent.tools : [];
    const usedNames = new Set(used.map((item) => item.name));
    const toolItems = [...used, ...tools.names.filter((name) => !usedNames.has(name)).map((name) => ({ name, count: 0, failed: 0 }))];
    const toolGroup = listGroup('Tools', { status: 'reconstructed', items: toolItems }, (item) => el('li', null,
        el('span', { class: 'item-name mono' }, item.name),
        el('span', { class: 'meta' }, item.count > 0
            ? `${item.count.toLocaleString()} ${item.count === 1 ? 'call' : 'calls'}${item.failed > 0 ? `, ${item.failed.toLocaleString()} failed` : ''}`
            : 'Not called')));
    toolGroup.querySelector('.source-note').textContent = `Reconstructed from the session log: ${toolNote}.`;
    container.append(toolGroup);
    container.append(listGroup('MCP servers', inventory.mcpServers, (item) => el('li', null,
        el('span', { class: 'item-name' }, item.displayName || item.name || 'Unnamed'),
        el('span', { class: 'meta' }, [item.status, item.source, item.sourcePlugin ? `plugin ${item.sourcePlugin}` : null].filter(Boolean).join(' · ')),
        item.error ? el('span', { class: 'meta' }, item.error) : null)));
    container.append(listGroup('Plugins', inventory.plugins, (item) => el('li', null,
        el('span', { class: 'item-name' }, item.name ?? 'Unnamed', item.enabled === false ? ' ' : null, item.enabled === false ? el('span', { class: 'badge' }, 'Disabled') : null),
        el('span', { class: 'meta' }, [item.marketplace, item.version].filter(Boolean).join(' · ')))));
    container.append(listGroup('Extensions', inventory.extensions, (item) => el('li', null,
        el('span', { class: 'item-name' }, item.name ?? 'Unnamed'),
        el('span', { class: 'meta' }, [item.source, item.status].filter(Boolean).join(' · ')))));
}
