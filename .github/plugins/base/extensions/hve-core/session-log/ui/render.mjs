// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { formatDuration, formatRelativeDate, formatSize, formatTime, formatTokens, percent } from './format.mjs';
import { appendJson, appendTagged, looksLikeJson } from './highlight.mjs';
import { renderMarkdown } from './markdown.mjs';

const MARKDOWN_LIMIT = 64 * 1024;
/** Disclosure under a tool's preview boxes: telemetry, full pages of truncated fields, and raw events. */
const TOOL_DETAIL_LABEL = 'Telemetry and raw events';

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
 * @param {boolean} [options.json]
 * @param {'text' | 'json' | 'tags' | 'markdown'} [options.mode] How to show the text; `markdown` renders prose.
 * @param {'start' | 'end'} options.anchor
 * @param {'default' | 'error'} [options.tone]
 * @param {() => Promise<{ text: string, note?: string }>} [options.loadFull]
 * @param {{ get: (key: string) => boolean, set: (key: string, value: boolean) => void }} [options.state]
 * @param {string} [options.stateKey]
 * @param {boolean} [options.watchSize] Re-check a short box for clipped text whenever it resizes; for
 *   boxes that shrink with their panel.
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
        body.replaceChildren(mode === 'markdown' ? proseBlock(text) : codeBlock(text, mode, 'io-pre wrap'));
        const short = !cut && text.length <= 600 && text.split('\n', 9).length <= 8;
        box.classList.toggle('is-short', short);
        toggle.hidden = short;
        if (short) {
            // Wrapped lines in narrow panels can still overflow a short box; measure once rendered.
            window.requestAnimationFrame(() => {
                if (box.classList.contains('is-short') && body.scrollHeight > body.clientHeight + 2) {
                    box.classList.remove('is-short');
                    toggle.hidden = false;
                }
            });
        }
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
        if (box.classList.contains('is-short') && body.scrollHeight > body.clientHeight + 2) {
            box.classList.remove('is-short');
            toggle.hidden = false;
        }
        if (!box.classList.contains('is-expanded') && !box.classList.contains('is-short') && !String(window.getSelection?.() ?? '')) {
            setExpanded(true);
        }
    });
    box.append(el('div', { class: 'io-head' }, el('span', { class: 'io-title' }, title), size, note, hint, toggle), body);
    if (state?.get(stateKey)) {
        setExpanded(true);
    }
    if (options.watchSize && typeof ResizeObserver === 'function') {
        const observer = new ResizeObserver(() => {
            if (!box.isConnected) {
                observer.disconnect();
            } else if (box.classList.contains('is-short') && body.scrollHeight > body.clientHeight + 2) {
                box.classList.remove('is-short');
                toggle.hidden = false;
            }
        });
        observer.observe(body);
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
        // The argument and output boxes show previews; truncated fields still page in below.
        const completeIndex = byType('tool.execution_complete');
        const metrics = completeIndex >= 0 ? events[completeIndex].data?.toolTelemetry?.metrics : null;
        if (metrics && typeof metrics === 'object') {
            const pairs = Object.entries(metrics).slice(0, 20).map(([key, value]) => [key.replace(/_/g, ' '), typeof value === 'number' ? value.toLocaleString() : String(value)]);
            const list = kvList(pairs);
            if (list) {
                body.append(el('div', { class: 'detail-block' }, el('p', { class: 'detail-block-title' }, 'Telemetry'), list));
            }
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
                    note: cutValues.length ? `${cutValues.length} long ${cutValues.length === 1 ? 'value is' : 'values are'} cut at ${formatSize(detail.pageChars)}; load the rest under ${TOOL_DETAIL_LABEL}` : '',
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
                return { text: field.text, note: page > 0 ? `Showing the last ${formatSize(field.text.length)}; page through all of it under ${TOOL_DETAIL_LABEL}` : '' };
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
        agent?.description
            ? clampedDescription(agent.description, { id: `desc-${ctx.agentKey}-${entry.seq}`, className: 'meta', state: ctx.ui, stateKey: `card-description:${entry.subagent}` })
            : null,
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
            bodyWrap.append(lazyDisclosure(preview ? TOOL_DETAIL_LABEL : isSubagentTool ? 'Task arguments and final result' : 'Arguments and result', entry, ctx));
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
 * A description clamped to three lines. Show more appears only while the clamp cuts text off. The
 * open choice and the last clipping measurement survive re-renders through `state`, so a re-rendered
 * toggle is visible at once and keeps keyboard focus.
 *
 * @param {string} text
 * @param {object} options
 * @param {string} options.id Element ID for the text, unique in the page.
 * @param {string} options.className Class for the text paragraph.
 * @param {{ get: (key: string) => boolean, set: (key: string, value: boolean) => void } | undefined} options.state
 * @param {string} options.stateKey
 */
function clampedDescription(text, options) {
    const { id, className, state, stateKey } = options;
    const clippedKey = `${stateKey}:clipped`;
    const wrap = el('div', { class: 'description-clamp' });
    const para = el('p', { class: `clamp-text ${className}`, id }, text);
    const toggle = el('button', { class: 'link-button description-toggle', type: 'button', 'aria-expanded': 'false', 'aria-controls': id }, 'Show more');
    const sync = () => {
        if (wrap.classList.contains('is-open')) {
            toggle.hidden = false;
            return;
        }
        // A paragraph without a box (in a hidden panel) measures 0; keep the last answer until it has one.
        if (para.clientHeight === 0) {
            return;
        }
        const clipped = para.scrollHeight > para.clientHeight + 1;
        toggle.hidden = !clipped;
        state?.set(clippedKey, clipped);
    };
    const setOpen = (open) => {
        wrap.classList.toggle('is-open', open);
        toggle.setAttribute('aria-expanded', String(open));
        toggle.textContent = open ? 'Show less' : 'Show more';
        state?.set(stateKey, open);
        sync();
    };
    toggle.addEventListener('click', () => setOpen(!wrap.classList.contains('is-open')));
    toggle.hidden = !state?.get(clippedKey);
    wrap.append(para, toggle);
    if (state?.get(stateKey)) {
        setOpen(true);
    }
    // Width changes (panel resizes) can start or stop the clamp cutting text off.
    if (typeof ResizeObserver === 'function') {
        const observer = new ResizeObserver(() => {
            if (wrap.isConnected) {
                sync();
            } else {
                observer.disconnect();
            }
        });
        observer.observe(para);
    } else {
        window.requestAnimationFrame(sync);
    }
    return wrap;
}

/**
 * Renders the inspector's agent title bar and overview: model, totals, and context use.
 *
 * @param {{ head: HTMLElement, body: HTMLElement }} targets Title bar and overview containers.
 * @param {object | undefined} agent Summary agent.
 * @param {object} ctx Header context.
 */
export function renderAgentHeader(targets, agent, ctx) {
    const { head, body } = targets;
    head.replaceChildren();
    body.replaceChildren();
    if (!agent) {
        head.append(el('h2', { id: 'agentHeading', class: 'inspector-title' }, 'Agent'));
        body.append(el('p', { class: 'meta' }, 'Select a session to see its agents.'));
        return;
    }
    const isRoot = agent.key === 'root';
    const name = isRoot ? agent.customAgent?.displayName || 'Main agent' : agentLabel(agent);
    head.append(...[
        icon('i-agent', 'icon inspector-title-icon'),
        el('h2', { id: 'agentHeading', class: 'inspector-title', title: name }, name),
        isRoot && agent.customAgent?.displayName ? el('span', { class: 'inspector-role' }, 'main agent') : null,
        !isRoot && agent.agentType && agent.agentType !== name ? el('span', { class: 'badge badge-agent' }, agent.agentType) : null,
        !isRoot ? statusNode(agent.status) : null,
        isRoot && ctx.session?.active ? el('span', { class: 'badge badge-live' }, icon('i-dot'), 'Active') : null,
    ].filter(Boolean));

    if (!isRoot && agent.description) {
        body.append(clampedDescription(agent.description, { id: 'agentDescription', className: 'overview-description', state: ctx.ui, stateKey: `description:${ctx.sessionId}:${agent.key}` }));
    }
    const model = joinMeta([agent.model, agent.reasoningEffort ? `${agent.reasoningEffort} effort` : null, agent.contextTier]);
    body.append(el('p', { class: 'overview-model' }, icon('i-cpu'), el('span', null, model || 'Model not recorded')));

    const stats = el('dl', { class: 'stat-grid' });
    const stat = (label, value, wide = false) => {
        if (value === null || value === undefined || value === '') {
            return;
        }
        stats.append(el('div', { class: `stat${wide ? ' stat-wide' : ''}` }, el('dt', null, label), el('dd', null, value)));
    };
    stat('Turns', String(agent.counts.turns));
    stat('Tool calls', agent.counts.tools.toLocaleString());
    if (agent.children?.length) {
        stat('Subagents', String(agent.children.length));
    }
    if (agent.usage?.requests) {
        stat('Requests', agent.usage.requests.toLocaleString());
        stat('Tokens', `${formatTokens(agent.usage.inputTokens)} in · ${formatTokens(agent.usage.outputTokens)} out`, true);
    }
    if (Number.isFinite(agent.durationMs)) {
        stat('Duration', formatDuration(agent.durationMs));
    }
    if (agent.models?.length > 1) {
        stat('Models used', String(agent.models.length));
    }
    body.append(stats);

    const context = agent.context ?? {};
    const meterRow = el('div', { class: 'meter-row' });
    const pct = percent(context.current, context.limit);
    const label = Number.isFinite(context.current)
        ? `Context ${formatTokens(context.current)}${Number.isFinite(context.limit) ? ` of ${formatTokens(context.limit)}` : ' tokens'}${pct !== null ? ` (${Math.round(pct)}%)` : ''}`
        : 'Context use not recorded';
    const secondary = Number.isFinite(context.peak) && context.peak !== context.current ? `peak ${formatTokens(context.peak)}` : null;
    meterRow.append(el('p', { class: 'meta' }, label, secondary ? el('span', { class: 'meter-secondary' }, ` · ${secondary}`) : null));
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
    body.append(meterRow);
}

/**
 * @param {{ added: number, removed: number, resized: number } | null | undefined} changes
 * @returns {string} Section changes in a short phrase, such as `2 sections added, 1 resized`.
 */
export function sectionChangeText(changes) {
    if (!changes) {
        return '';
    }
    const parts = [];
    if (changes.added) {
        parts.push(`${changes.added} added`);
    }
    if (changes.removed) {
        parts.push(`${changes.removed} removed`);
    }
    if (changes.resized) {
        parts.push(`${changes.resized} resized`);
    }
    if (parts.length === 0) {
        return 'same sections';
    }
    const total = (changes.added ?? 0) + (changes.removed ?? 0) + (changes.resized ?? 0);
    return `${total === 1 ? 'section' : 'sections'} ${parts.join(', ')}`;
}

function listRow(button) {
    return el('li', null, button);
}

function emptyRow(text) {
    return el('li', { class: 'list-empty' }, text);
}

/**
 * Renders the system prompt versions of an agent, oldest first, each opening its version in the log.
 *
 * @param {HTMLElement} list
 * @param {HTMLElement} count Heading count.
 * @param {object | undefined} agent Summary agent.
 * @param {{ onShowSystemPrompt: (key: string, seq: number | null) => void }} ctx
 */
export function renderPromptVersions(list, count, agent, ctx) {
    const versions = agent?.systemPromptVersions ?? [];
    const total = agent?.systemPromptCount ?? versions.length;
    count.textContent = total > 0 ? String(total) : '';
    if (!agent?.systemPrompt) {
        list.replaceChildren(emptyRow('No system prompt recorded for this agent.'));
        return;
    }
    const latest = versions[versions.length - 1]?.seq;
    const rows = versions.slice().reverse().map((version) => {
        const why = version.version === 1 ? 'Initial prompt' : version.reasons?.length ? `After ${reasonText(version.reasons)}` : 'Rebuilt';
        const size = joinMeta([formatSize(version.chars), Number.isFinite(version.delta) && version.version > 1 ? signedSize(version.delta) : null, sectionChangeText(version.changes)]);
        const button = el('button', { class: 'nav-item rich-row', type: 'button', 'aria-current': version.seq === latest ? 'true' : null },
            el('span', { class: 'rich-row-head' },
                el('span', { class: 'rich-row-name' }, `Version ${version.version}`),
                version.seq === latest ? el('span', { class: 'badge badge-current' }, 'Latest') : null,
                el('span', { class: 'nav-item-time' }, formatTime(version.ts))),
            el('span', { class: 'rich-row-text' }, why),
            size ? el('span', { class: 'rich-row-meta' }, size) : null);
        button.title = `Show version ${version.version} in the log`;
        button.addEventListener('click', () => ctx.onShowSystemPrompt(agent.key, version.seq));
        return listRow(button);
    });
    if (total > versions.length) {
        rows.push(emptyRow(`${total - versions.length} earlier versions are not listed.`));
    }
    list.replaceChildren(...rows);
}

/**
 * @param {object} compaction Summary compaction record.
 * @returns {string} Tokens before and after with the reduction, such as `92k to 15k (−84%)`.
 */
export function compactionTokens(compaction) {
    const { before, after } = compaction;
    if (Number.isFinite(before) && Number.isFinite(after)) {
        const kept = percent(after, before);
        return `${formatTokens(before)} to ${formatTokens(after)} tokens${kept !== null ? ` (−${Math.round(100 - kept)}%)` : ''}`;
    }
    return Number.isFinite(before) ? `${formatTokens(before)} tokens` : '';
}

/**
 * Renders an agent's compactions, oldest first, each revealing its entry in the log.
 *
 * @param {HTMLElement} list
 * @param {HTMLElement} count Heading count.
 * @param {object | undefined} agent Summary agent.
 * @param {{ onRevealSeq: (seq: number) => void }} ctx
 */
export function renderCompactions(list, count, agent, ctx) {
    const records = [...(agent?.compactions ?? [])];
    if (agent?.activeCompaction) {
        records.push(agent.activeCompaction);
    }
    const total = (agent?.compactionTotal ?? agent?.compactions?.length ?? 0) + (agent?.activeCompaction ? 1 : 0);
    count.textContent = total > 0 ? String(total) : '';
    if (records.length === 0) {
        list.replaceChildren(emptyRow('No compactions yet. Copilot compacts the conversation when context nears its limit.'));
        return;
    }
    const rows = records.slice().reverse().map((record) => {
        const label = record.status === 'running' ? 'Compacting' : record.status === 'failed' ? 'Compaction failed' : 'Compacted';
        const tokens = compactionTokens(record);
        const meta = joinMeta([
            Number.isFinite(record.removed) ? `${record.removed.toLocaleString()} ${record.removed === 1 ? 'message' : 'messages'} removed` : null,
            record.trigger,
            Number.isFinite(record.durationMs) ? formatDuration(record.durationMs) : null,
            Number.isFinite(record.checkpointNumber) ? `checkpoint ${record.checkpointNumber}` : null,
        ]);
        const button = el('button', { class: `nav-item rich-row compaction-row status-${record.status}`, type: 'button' },
            el('span', { class: 'rich-row-head' },
                icon(record.status === 'failed' ? 'i-x-circle' : 'i-compress', 'icon compaction-icon'),
                el('span', { class: 'rich-row-name' }, label),
                el('span', { class: 'nav-item-time' }, formatTime(record.ts))),
            tokens ? el('span', { class: 'rich-row-text' }, tokens) : null,
            meta ? el('span', { class: 'rich-row-meta' }, meta) : null,
            record.error ? el('span', { class: 'rich-row-meta rich-row-error' }, record.error) : null);
        button.title = record.checkpointName ? `Show this compaction in the log. Checkpoint ${record.checkpointName}` : 'Show this compaction in the log';
        button.addEventListener('click', () => ctx.onRevealSeq(record.seq));
        return listRow(button);
    });
    if (total > records.length) {
        rows.push(emptyRow(`${total - records.length} earlier compactions are not listed.`));
    }
    list.replaceChildren(...rows);
}

const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

/**
 * Normalizes an agent name, ID, display name, or type for matching, so `hve-core:rpi-plan-critic`
 * matches `RPI Plan Critic`.
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
 * Returns a Details group's sort choice: the saved choice, else its default.
 *
 * @param {{ id: string, order?: string, count?: object, defaultSort?: { key: string, dir: string } }} spec
 * @param {{ sort: Map<string, { key: string, dir: string }> }} state
 */
export function detailSort(spec, state) {
    const saved = state.sort.get(spec.id);
    if (saved && (saved.key === 'name' || (saved.key === 'count' && spec.count) || (saved.key === 'order' && spec.order))) {
        return saved;
    }
    return spec.defaultSort ?? (spec.order ? { key: 'order', dir: 'asc' } : spec.count ? { key: 'count', dir: 'desc' } : { key: 'name', dir: 'asc' });
}

/**
 * Sorts Details items without changing the source array. Count ties fall back to name order.
 *
 * @param {object[]} items
 * @param {{ key: 'order' | 'count' | 'name', dir: 'asc' | 'desc' }} sort
 * @param {{ nameOf: (item: object) => string, count?: { of: (item: object) => number } }} spec
 * @returns {object[]}
 */
export function sortDetailItems(items, sort, spec) {
    if (sort.key === 'order') {
        return items.slice();
    }
    const byName = (a, b) => collator.compare(spec.nameOf(a) ?? '', spec.nameOf(b) ?? '');
    const sign = sort.dir === 'desc' ? -1 : 1;
    if (sort.key === 'count' && spec.count) {
        return items.slice().sort((a, b) => sign * ((spec.count.of(a) ?? 0) - (spec.count.of(b) ?? 0)) || byName(a, b));
    }
    return items.slice().sort((a, b) => sign * byName(a, b));
}

function sortChips(spec, sort, onChange) {
    const chips = [];
    const chip = (key, text, title, next) => {
        const button = el('button', { class: 'sort-chip', type: 'button', 'aria-pressed': String(sort.key === key), title }, text);
        button.addEventListener('click', () => onChange(next));
        chips.push(button);
    };
    if (spec.order) {
        chip('order', spec.order, `Show in ${spec.order.toLowerCase()}`, { key: 'order', dir: 'asc' });
    }
    if (spec.count) {
        const active = sort.key === 'count';
        const dir = active ? sort.dir : 'desc';
        const text = dir === 'desc' ? spec.count.most : spec.count.fewest;
        const other = dir === 'desc' ? spec.count.fewest : spec.count.most;
        chip('count', text, active ? `Sorted by ${text.toLowerCase()} first. Select to show ${other.toLowerCase()} first.` : `Sort by ${text.toLowerCase()} first`, { key: 'count', dir: active ? (dir === 'desc' ? 'asc' : 'desc') : 'desc' });
    }
    const nameActive = sort.key === 'name';
    const nameDir = nameActive ? sort.dir : 'asc';
    chip('name', nameDir === 'asc' ? 'A–Z' : 'Z–A', nameActive ? `Sorted by name, ${nameDir === 'asc' ? 'A to Z' : 'Z to A'}. Select to reverse.` : 'Sort by name, A to Z', { key: 'name', dir: nameActive ? (nameDir === 'asc' ? 'desc' : 'asc') : 'asc' });
    return chips;
}

function defNote(text, tone = 'info') {
    return el('p', { class: `def-note tone-${tone}` }, icon(tone === 'warning' ? 'i-alert' : 'i-info'), el('span', null, text));
}

function defHeading(text) {
    return el('h3', { class: 'def-subhead' }, text);
}

const PRETTY_JSON_MAX = 256 * 1024;

/**
 * Indents JSON text for reading. Text that is not complete JSON, or is too large, is returned
 * unchanged so it still highlights token by token.
 *
 * @param {string} text
 * @returns {string}
 */
export function prettyJson(text) {
    if (typeof text !== 'string' || !looksLikeJson(text) || text.length > PRETTY_JSON_MAX) {
        return text;
    }
    try {
        const value = JSON.parse(text);
        return typeof value === 'object' && value !== null ? JSON.stringify(value, null, 2) : text;
    } catch {
        return text;
    }
}

/** JSON mode for text that looks like JSON, otherwise tagged text so prompt markup stands out. */
function textMode(text) {
    return looksLikeJson(text) ? 'json' : 'tags';
}

function defBox(ctx, key, title, text, mode = 'text', options = {}) {
    const shown = mode === 'json' ? prettyJson(text) : text;
    const chars = Math.max(options.chars ?? 0, shown.length);
    return ioBox({ title, text: shown, chars, mode, anchor: 'start', tone: options.tone, state: ctx.ui, stateKey: `def:${key}:${title}` });
}

function liveNotes(def, kind) {
    const live = def.live ?? {};
    if (live.item && live.scope === 'live-session') {
        return [defNote(`Not recorded for this session. Showing the ${kind} definition from the live session, which may differ.`, 'warning')];
    }
    if (live.item) {
        return [];
    }
    switch (live.status) {
        case 'not-initialized':
            return [defNote('The live session has not loaded its tools yet.')];
        case 'not-offered':
            return [defNote('The live session does not offer this tool now.')];
        case 'not-found':
            return [defNote(kind === 'agent' && def.live?.listing
                ? 'The host does not describe this agent beyond its task tool listing.'
                : `The live session has no ${kind} by this name now.`)];
        case 'not-applicable':
            return [defNote(`Live ${kind} details are shown only for the session that opened this canvas.`)];
        default:
            return [defNote(`The live ${kind} definition is unavailable.`)];
    }
}

function actionButton(label, iconId, onClick) {
    const button = el('button', { class: 'btn btn-small', type: 'button' }, icon(iconId), label);
    button.addEventListener('click', onClick);
    return button;
}

function actions(...buttons) {
    const present = buttons.filter(Boolean);
    return present.length ? el('div', { class: 'detail-actions' }, ...present) : null;
}

function code(text) {
    return el('code', null, text);
}

function plural(count, one, many = `${one}s`) {
    return `${count.toLocaleString()} ${count === 1 ? one : many}`;
}

const TYPE_TEXT_MAX = 120;

/**
 * Describes a JSON Schema property type in a short line, such as `array of string`.
 *
 * @param {unknown} prop
 * @param {number} [depth]
 * @returns {string}
 */
export function schemaType(prop, depth = 0) {
    if (!prop || typeof prop !== 'object' || depth > 4) {
        return 'any';
    }
    let text;
    if (Array.isArray(prop.enum)) {
        text = `one of ${prop.enum.slice(0, 6).map((value) => JSON.stringify(value)).join(', ')}${prop.enum.length > 6 ? ', …' : ''}`;
    } else if (Object.hasOwn(prop, 'const')) {
        text = `exactly ${JSON.stringify(prop.const)}`;
    } else if (Array.isArray(prop.anyOf ?? prop.oneOf)) {
        text = (prop.anyOf ?? prop.oneOf).slice(0, 4).map((variant) => schemaType(variant, depth + 1)).join(' | ');
    } else {
        const type = Array.isArray(prop.type) ? prop.type.join(' | ') : prop.type;
        text = type === 'array' ? `array of ${schemaType(prop.items, depth + 1)}` : type ?? (prop.properties ? 'object' : 'any');
    }
    return text.length > TYPE_TEXT_MAX ? `${text.slice(0, TYPE_TEXT_MAX - 1)}…` : text;
}

function parameterList(schema, emptyText = 'Takes no parameters.') {
    const props = schema && typeof schema.properties === 'object' && !Array.isArray(schema.properties) ? schema.properties : null;
    if (!props || Object.keys(props).length === 0) {
        return el('p', { class: 'meta' }, emptyText);
    }
    const required = new Set(Array.isArray(schema.required) ? schema.required : []);
    const list = el('ul', { class: 'param-list' });
    for (const [name, prop] of Object.entries(props).slice(0, 100)) {
        list.append(el('li', null,
            el('span', { class: 'param-head' },
                el('code', { class: 'param-name' }, name),
                el('span', { class: 'param-type' }, schemaType(prop)),
                required.has(name) ? el('span', { class: 'badge' }, 'Required') : null),
            typeof prop?.description === 'string' && prop.description ? el('span', { class: 'param-desc' }, prop.description) : null));
    }
    return list;
}

/** Links to related Context items, such as the tools of an MCP server or the skills of a plugin. */
function relatedList(rows, ctx, emptyText) {
    if (rows.length === 0) {
        return el('p', { class: 'meta' }, emptyText);
    }
    const list = el('ul', { class: 'related-list' });
    for (const { section, item } of rows.slice(0, 200)) {
        const button = el('button', { class: 'related-item', type: 'button' },
            el('span', { class: `related-name${item.mono ? ' mono' : ''}` }, item.name),
            el('span', { class: 'meta' }, item.countText));
        button.addEventListener('click', () => ctx.onOpenItem(section.id, item.key));
        list.append(el('li', null, button));
    }
    if (rows.length > 200) {
        list.append(el('li', { class: 'list-empty' }, `${(rows.length - 200).toLocaleString()} more`));
    }
    return list;
}

function latestCallView(call, ctx, key) {
    const nodes = [defHeading('Latest call')];
    nodes.push(kvList([
        ['Status', STATUS_TEXT[call.status] ?? call.status],
        ['Time', call.ts ? `${formatRelativeDate(call.ts)} ${formatTime(call.ts)}` : null],
        ['Duration', Number.isFinite(call.durationMs) ? formatDuration(call.durationMs) : null],
    ]));
    nodes.push(actions(actionButton('Show in log', 'i-open', () => ctx.onRevealTool(call.toolCallId))));
    if (call.arguments) {
        nodes.push(defBox(ctx, key, 'Arguments', call.arguments.text, textMode(call.arguments.text) === 'json' ? 'json' : 'text', { chars: call.arguments.chars }));
    }
    if (call.error) {
        nodes.push(defBox(ctx, key, 'Error', call.error.text, 'text', { chars: call.error.chars, tone: 'error' }));
    }
    if (call.result) {
        nodes.push(defBox(ctx, key, 'Response', call.result.text, textMode(call.result.text), { chars: call.result.chars }));
    } else if (!call.error && call.status !== 'running') {
        nodes.push(el('p', { class: 'meta' }, 'The log recorded no response text for this call.'));
    }
    return nodes;
}

function toolView(def, item, ctx, key) {
    const live = def.live?.item ?? null;
    const recorded = def.recorded ?? {};
    const server = live?.mcpServerName ?? recorded.mcpServer ?? null;
    const nodes = [...liveNotes(def, 'tool')];
    const loading = live?.deferLoading === true
        ? recorded.activatedBySearch ? 'On demand; loaded by tool search in this session' : 'On demand through tool search'
        : live?.deferLoading === false ? 'Always offered' : recorded.activatedBySearch ? 'Loaded by tool search' : null;
    nodes.push(kvList([
        ['Source', server ? `MCP server ${server}${live?.mcpToolName && live.mcpToolName !== live.name ? `, tool ${live.mcpToolName}` : ''}` : live ? 'Built-in or extension' : null],
        ['Loading', loading],
        ['Other agents', recorded.otherAgentCalls > 0 ? plural(recorded.otherAgentCalls, 'call') : null],
        ['Schema hash', recorded.schemaHash ? code(recorded.schemaHash) : null],
    ]));
    if (live) {
        if (live.definition.description) {
            nodes.push(defBox(ctx, key, 'Description', live.definition.description, 'markdown'));
        }
        nodes.push(defHeading('Arguments'));
        nodes.push(live.schemaTooLarge ? el('p', { class: 'meta' }, 'The input schema is too large to show.') : parameterList(live.definition.input_schema));
        nodes.push(defHeading('Response'));
        nodes.push(el('p', { class: 'meta' }, recorded.latestCall ? 'Tools declare no response schema; the latest response below shows what this tool returns.' : 'Tools declare no response schema; the model reads whatever the tool returns.'));
        nodes.push(defBox(ctx, key, 'Definition the model is given', JSON.stringify(live.definition), 'json'));
    } else {
        nodes.push(el('p', { class: 'meta' }, 'The tool definition is not recorded in the log.'));
    }
    if (recorded.latestCall) {
        nodes.push(...latestCallView(recorded.latestCall, ctx, key));
    }
    return nodes.filter(Boolean);
}

function runRow(run, ctx) {
    const status = run.status === 'failed' ? 'badge-danger' : run.status === 'running' ? 'badge-live' : '';
    const tokens = [run.usage?.inputTokens ? `${formatTokens(run.usage.inputTokens)} in` : null, run.usage?.outputTokens ? `${formatTokens(run.usage.outputTokens)} out` : null].filter(Boolean).join(' / ');
    return el('li', null,
        el('span', { class: 'run-head' },
            el('span', { class: 'item-name' }, run.displayName || run.name || run.agentType || 'Subagent'),
            run.status ? el('span', { class: `badge ${status}` }, STATUS_TEXT[run.status] ?? run.status) : null),
        el('span', { class: 'meta' }, [run.model, Number.isFinite(run.durationMs) ? formatDuration(run.durationMs) : null, tokens || null, Number.isFinite(run.totalToolCalls) ? `${run.totalToolCalls} tool calls` : null].filter(Boolean).join(' · ')),
        el('span', { class: 'detail-actions' }, actionButton('Open log', 'i-open', () => ctx.onOpenAgent(run.key))));
}

function agentView(def, item, ctx, key, role) {
    const live = def.live?.item ?? null;
    const recorded = def.recorded ?? {};
    const runs = recorded.runs ?? [];
    const selections = recorded.selections ?? [];
    const selected = selections.reduce((sum, selection) => sum + (selection.count ?? 0), 0);
    const nodes = [...liveNotes(def, 'agent')];
    const listing = def.live?.listing ?? null;
    if (role === 'subagents') {
        nodes.push(listing ? defBox(ctx, key, 'What the task tool tells the model', listing, 'text') : el('p', { class: 'meta' }, 'The task tool listing is available only for the session that opened this canvas.'));
    }
    nodes.push(kvList([
        ['ID', live?.id && live.id !== live.name ? code(live.id) : null],
        ['Source', live?.source],
        ['File', live?.path ? el('span', { class: 'mono' }, live.path) : null],
        ['Main agent', selected ? `Selected ${selected.toLocaleString()}×${recorded.current ? ', current' : ''}` : recorded.current ? 'Current' : null],
        ['Selectable', live ? (live.userInvocable === false ? 'Only as a subagent' : live.disableModelInvocation ? 'Only by the user' : 'By the user and as a subagent') : null],
        ['Model', live?.models?.length ? live.models.join(', ') : live?.model ?? runs[0]?.model],
        ['Reasoning effort', live?.reasoningEffort],
        ['Tools', live ? (live.tools === null ? 'Default tool set' : live.tools.length === 0 ? 'None' : `${live.tools.length}: ${live.tools.join(', ')}`) : null],
        ['Preloaded skills', live?.skills?.length ? live.skills.join(', ') : null],
        ['MCP servers', live?.mcpServers?.length ? live.mcpServers.map((server) => `${server.name}${server.type ? ` (${server.type})` : ''}`).join(', ') : null],
        ['Description', live?.description ?? runs[0]?.description ?? item?.description],
    ]));
    if (role !== 'subagents' && listing) {
        nodes.push(defBox(ctx, key, 'What the task tool tells the model', listing, 'text'));
    }
    const delivered = recorded.delivered;
    if (delivered) {
        nodes.push(defBox(ctx, key, delivered.form === 'main' ? 'Instructions in the main system prompt' : 'Prompt its latest run received', delivered.text, 'tags', { chars: delivered.chars }));
        nodes.push(actions(actionButton('Show that system prompt', 'i-book', () => ctx.onShowSystemPrompt(delivered.agentKey, delivered.seq))));
    } else if (live?.prompt) {
        nodes.push(defBox(ctx, key, 'Authored prompt', live.prompt, 'tags', { chars: live.promptChars }));
    } else {
        nodes.push(el('p', { class: 'meta' }, 'No prompt for this agent is recorded; it has not run or been selected in this session.'));
    }
    const runTotal = Math.max(recorded.runTotal ?? 0, runs.length);
    nodes.push(defHeading(`Runs in this session (${runTotal.toLocaleString()})`));
    if (runTotal > runs.length) {
        nodes.push(el('p', { class: 'meta' }, `Showing the latest ${runs.length}.`));
    }
    nodes.push(runs.length > 0 ? el('ul', { class: 'run-list' }, ...runs.map((run) => runRow(run, ctx))) : el('p', { class: 'meta' }, 'No runs recorded in this session.'));
    if (live) {
        const { prompt: _prompt, promptChars: _chars, promptTruncated: _cut, ...rest } = live;
        nodes.push(defBox(ctx, key, 'Definition from the host', JSON.stringify(rest, (_key, value) => (value === null ? undefined : value)), 'json'));
    }
    return nodes.filter(Boolean);
}

function skillView(def, ctx, key) {
    const live = def.live?.item ?? null;
    const recorded = def.recorded ?? {};
    const latest = recorded.invocations?.latest ?? null;
    const nodes = def.live?.scope === 'this-session' || def.live?.status === 'not-applicable' ? [] : [...liveNotes(def, 'skill')];
    nodes.push(kvList([
        ['Command', live?.commandName ? code(`/${live.commandName}`) : null],
        ['Arguments', live?.argumentHint],
        ['Source', live?.pluginName ? `plugin ${live.pluginName}` : live?.source ?? (latest?.pluginName ? `plugin ${latest.pluginName}` : latest?.source)],
        ['State', live?.enabled === false ? 'Disabled' : null],
        ['Invocation', live?.userInvocable === false ? 'Model only' : null],
        ['File', live?.path || latest?.path ? el('span', { class: 'mono' }, live?.path || latest.path) : null],
        ['Uses', String(recorded.invocations?.count ?? 0)],
    ]));
    if (recorded.promptEntry) {
        nodes.push(defBox(ctx, key, recorded.promptEntry.form === 'xml' ? 'System prompt entry' : 'System prompt listing', recorded.promptEntry.text, 'tags'));
    } else {
        nodes.push(el('p', { class: 'meta' }, 'Not listed in the latest system prompt.'));
    }
    if (latest) {
        nodes.push(defHeading('Loaded into context'));
        nodes.push(kvList([
            ['Trigger', latest.trigger],
            ['Turn', Number.isFinite(latest.invokedAtTurn) ? String(latest.invokedAtTurn) : null],
            ['Loaded', latest.ts ? formatTime(latest.ts) : null],
            ['Allowed tools', latest.allowedTools?.length ? latest.allowedTools.join(', ') : null],
        ]));
        nodes.push(el('div', { class: 'detail-actions' }, actionButton('Show in log', 'i-open', () => ctx.onRevealSeq(latest.seq))));
        if (latest.content) {
            nodes.push(defBox(ctx, key, 'Loaded text', latest.content, 'tags'));
            if (latest.truncated) {
                nodes.push(el('p', { class: 'meta' }, `Showing ${formatSize(latest.content.length)} of ${formatSize(latest.contentChars)}.`));
            }
            if (latest.resolvedFrom) {
                nodes.push(el('p', { class: 'meta' }, 'The log recorded this load as a reference; the text comes from the earlier load with the same content.'));
            }
        } else if (latest.contentChars > 0) {
            nodes.push(defNote(`The log recorded this load (${formatSize(latest.contentChars)}) as a reference to text it does not contain.`));
        }
    } else if ((recorded.invocations?.count ?? 0) === 0) {
        nodes.push(el('p', { class: 'meta' }, 'Not loaded in this session.'));
    }
    return nodes.filter(Boolean);
}

function instructionView(def, item, ctx, key) {
    const live = def.live?.item ?? null;
    const recorded = def.recorded ?? {};
    const entry = recorded.promptEntry ?? null;
    const nodes = [];
    nodes.push(kvList([
        ['Applies to', live?.applyTo?.length ? live.applyTo.join(', ') : entry?.applyTo ?? null],
        ['Type', live?.type],
        ['Location', live?.location],
        ['File', live?.sourcePath ? el('span', { class: 'mono' }, live.sourcePath) : null],
        ['Reads', recorded.reads ? `Read ${recorded.reads.toLocaleString()}× with a file view` : 'Not read in this session'],
        ['Discovered', recorded.discovered ? `${recorded.discovered.description ?? 'Found by the runtime'}${recorded.discovered.triggerFile ? ` while reading ${recorded.discovered.triggerFile}` : ''}` : null],
        ['State', live?.defaultDisabled ? 'Off until enabled' : null],
    ]));
    if (recorded.discovered) {
        nodes.push(actions(actionButton('Show in log', 'i-open', () => ctx.onRevealSeq(recorded.discovered.seq))));
    }
    nodes.push(entry ? defBox(ctx, key, 'System prompt entry', entry.text) : el('p', { class: 'meta' }, 'Not listed in the latest system prompt.'));
    if (live?.content) {
        nodes.push(defBox(ctx, key, 'File content', live.content, 'tags', { chars: live.contentChars }));
    } else if (def.live?.status === 'not-applicable') {
        nodes.push(defNote('File content is shown only for the session that opened this canvas.'));
    }
    return nodes.filter(Boolean);
}

/**
 * Chooses the capabilities a canvas definition shows: the live definition when it belongs to this
 * session, then capabilities this session recorded, then another session's live definition.
 *
 * @param {{ live?: { item?: object | null, scope?: string | null }, recorded?: { capabilities?: { text?: string } } }} def
 * @returns {{ live: object | null, captured: object | null, useLive: boolean, source: object | null }}
 */
export function canvasSource(def) {
    const live = def.live?.item ?? null;
    let captured = null;
    if (def.recorded?.capabilities?.text) {
        try {
            captured = JSON.parse(def.recorded.capabilities.text);
        } catch {
            captured = null;
        }
    }
    const useLive = Boolean(live) && (def.live?.scope === 'this-session' || !captured);
    return { live, captured, useLive, source: useLive ? live : captured };
}

function canvasView(def, item, ctx, key) {
    const recorded = def.recorded ?? {};
    const activity = recorded.activity;
    const { live, captured, useLive, source } = canvasSource(def);
    const nodes = [];
    if (useLive || !captured) {
        nodes.push(...liveNotes(def, 'canvas'));
    } else if (live) {
        nodes.push(defNote('Showing the capabilities recorded in this session. The live session may offer a different version.'));
    }
    const open = (recorded.instances ?? []).filter((instance) => !instance.removed).length;
    nodes.push(kvList([
        ['Canvas ID', code(item?.key ?? source?.canvasId ?? '')],
        ['Extension', (useLive ? live.extensionName ?? live.extensionId : null) ?? activity?.extensionId ?? source?.extensionId],
        ['Calls', activity ? `${plural(activity.opens, 'open')}, ${plural(activity.actionCalls, 'action call')}, ${plural(activity.capabilityCalls, 'capability check')}` : null],
        ['Open now', open ? plural(open, 'instance') : null],
    ]));
    if (activity?.lastCallId) {
        nodes.push(actions(actionButton('Show latest call', 'i-open', () => ctx.onRevealTool(activity.lastCallId))));
    }
    const description = source?.description ?? item?.description;
    if (description) {
        nodes.push(el('p', { class: 'def-description' }, description));
    }
    if (recorded.promptEntry) {
        nodes.push(defBox(ctx, key, 'System prompt entry', recorded.promptEntry.text, 'tags'));
    }
    if (source) {
        nodes.push(defHeading('Open input'));
        nodes.push(parameterList(source.inputSchema, 'Opens without input.'));
        const counts = new Map((activity?.actions ?? []).map((action) => [action.name, action.count]));
        const actionList = Array.isArray(source.actions) ? source.actions : [];
        nodes.push(defHeading(`Actions (${actionList.length})`));
        if (actionList.length === 0) {
            nodes.push(el('p', { class: 'meta' }, 'This canvas offers no actions.'));
        }
        for (const action of actionList) {
            nodes.push(el('div', { class: 'def-action' },
                el('p', { class: 'def-action-head' }, code(action.name ?? ''), el('span', { class: 'meta' }, counts.get(action.name) ? plural(counts.get(action.name), 'call') : 'Not called')),
                action.description ? el('p', { class: 'def-action-desc' }, action.description) : null,
                parameterList(action.inputSchema, 'Takes no input.')));
        }
    } else {
        nodes.push(el('p', { class: 'meta' }, 'The input schema and actions are not recorded; the model never asked for this canvas\'s capabilities.'));
    }
    if (recorded.capabilities?.text) {
        nodes.push(defBox(ctx, key, 'Capabilities the model read', recorded.capabilities.text, 'json', { chars: recorded.capabilities.chars }));
        nodes.push(actions(actionButton('Show that call', 'i-open', () => ctx.onRevealTool(recorded.capabilities.toolCallId))));
    } else if (live) {
        nodes.push(defBox(ctx, key, 'Declaration', JSON.stringify(live), 'json'));
    }
    const instances = recorded.instances ?? [];
    if (instances.length) {
        nodes.push(defHeading(`Instances (${instances.length})`));
        nodes.push(el('ul', { class: 'run-list' }, ...instances.map((instance) => el('li', null,
            el('span', { class: 'run-head' }, el('span', { class: 'item-name mono' }, instance.instanceId), el('span', { class: `badge${instance.removed ? '' : ' badge-live'}` }, instance.removed ? 'Closed' : 'Open')),
            el('span', { class: 'meta' }, [instance.title, instance.ts ? `opened ${formatTime(instance.ts)}` : null, instance.removedTs ? `closed ${formatTime(instance.removedTs)}` : null].filter(Boolean).join(' · '))))));
    }
    return nodes.filter(Boolean);
}

function mcpView(def, item, ctx, key) {
    const live = def.live?.item ?? null;
    const recorded = def.recorded ?? {};
    const nodes = [...liveNotes(def, 'MCP server')];
    nodes.push(kvList([
        ['Source', live?.source],
        ['Plugin', live?.sourcePlugin ? `${live.sourcePlugin}${live.sourcePluginVersion ? ` ${live.sourcePluginVersion}` : ''}` : null],
        ['Address', live?.url ? el('span', { class: 'mono' }, live.url) : null],
    ]));
    if (live?.error) {
        nodes.push(defBox(ctx, key, 'Error', live.error, 'text', { tone: 'error' }));
    }
    if (live?.instructions) {
        nodes.push(defBox(ctx, key, 'Server instructions given to the model', live.instructions, 'markdown', { chars: live.instructionsChars }));
    }
    const offered = ctx.findItems((section, row) => section.id === 'tools' && row.owner === `mcp:${item?.key}`);
    const recordedOnly = (recorded.tools ?? []).filter((tool) => !offered.some(({ item: row }) => row.key === tool.name));
    nodes.push(defHeading(`Tools (${offered.length + recordedOnly.length})`));
    nodes.push(relatedList(offered, ctx, recordedOnly.length ? 'Tools seen only in recorded calls:' : 'No tools from this server are listed.'));
    if (recordedOnly.length) {
        nodes.push(el('ul', { class: 'related-list' }, ...recordedOnly.map((tool) => el('li', null,
            el('span', { class: 'related-item is-static' }, el('span', { class: 'related-name mono' }, tool.name), el('span', { class: 'meta' }, plural(tool.count, 'call')))))));
    }
    return nodes.filter(Boolean);
}

function hookView(def, item, ctx, key) {
    const recorded = def.recorded ?? {};
    const nodes = [];
    if (item?.description) {
        nodes.push(el('p', { class: 'def-description' }, item.description));
    }
    nodes.push(kvList([
        ['Added context', recorded.contextCount ? `${recorded.contextCount.toLocaleString()}×` : null],
        ['Latest run', recorded.lastRun ? `${STATUS_TEXT[recorded.lastRun.status] ?? recorded.lastRun.status}, ${formatTime(recorded.lastRun.ts)}${recorded.lastRun.tool ? ` for ${recorded.lastRun.tool}` : ''}` : null],
    ]));
    nodes.push(actions(Number.isInteger(recorded.lastRun?.seq) ? actionButton('Show latest run', 'i-open', () => ctx.onRevealSeq(recorded.lastRun.seq)) : null));
    nodes.push(defNote('Copilot does not list configured hooks for a session; this view comes from recorded runs. Successful runs do not name their plugin.'));
    const sources = recorded.sources ?? [];
    if (sources.length) {
        nodes.push(defHeading('Failures by plugin'));
        nodes.push(el('ul', { class: 'run-list' }, ...sources.map((source) => el('li', null,
            el('span', { class: 'run-head' }, el('span', { class: 'item-name' }, source.source || 'Unknown source'), el('span', { class: 'badge badge-danger' }, `${source.failed.toLocaleString()} failed`)),
            source.error ? el('span', { class: 'meta' }, source.error) : null))));
    }
    if (recorded.latestFailure?.message) {
        nodes.push(defBox(ctx, key, 'Latest failure', recorded.latestFailure.message, 'text', { tone: 'error' }));
    }
    if (recorded.latestContext) {
        nodes.push(defBox(ctx, key, 'Latest context added for the model', recorded.latestContext.text, 'tags', { chars: recorded.latestContext.chars }));
    }
    return nodes.filter(Boolean);
}

function pluginView(def, item, ctx) {
    const live = def.live?.item ?? null;
    const nodes = [...liveNotes(def, 'plugin')];
    nodes.push(kvList([
        ['Version', live?.version],
        ['Marketplace', live?.marketplace],
        ['State', live ? (live.enabled === false ? 'Disabled' : 'Enabled') : null],
        ['Source', live?.source],
        ['Installed from', live?.installedFrom ? el('span', { class: 'mono' }, live.installedFrom) : null],
        ['Managed', live?.managed ? 'Yes' : null],
    ]));
    const owner = `plugin:${item?.key}`;
    nodes.push(defHeading('Skills'));
    nodes.push(relatedList(ctx.findItems((section, row) => section.id === 'skills' && row.owner === owner), ctx, 'No skills from this plugin are listed.'));
    nodes.push(defHeading('MCP servers'));
    nodes.push(relatedList(ctx.findItems((section, row) => section.id === 'mcp' && row.owner === owner), ctx, 'No MCP servers from this plugin are listed.'));
    nodes.push(el('p', { class: 'meta' }, 'Agents, instructions, and hooks do not name their plugin in session data.'));
    return nodes.filter(Boolean);
}

function extensionView(def, item, ctx) {
    const live = def.live?.item ?? null;
    const nodes = [...liveNotes(def, 'extension')];
    nodes.push(kvList([
        ['ID', live?.id ? code(live.id) : null],
        ['Source', live?.source],
        ['Status', live?.status],
    ]));
    nodes.push(defHeading('Canvases'));
    nodes.push(relatedList(ctx.findItems((section, row) => section.id === 'canvases' && row.owner === `extension:${item?.key}`), ctx, 'No canvases from this extension are listed.'));
    return nodes.filter(Boolean);
}

function definitionView(kind, def, item, ctx, key, role) {
    switch (kind) {
        case 'tool':
            return toolView(def, item, ctx, key);
        case 'agent':
            return agentView(def, item, ctx, key, role);
        case 'skill':
            return skillView(def, ctx, key);
        case 'canvas':
            return canvasView(def, item, ctx, key);
        case 'mcp':
            return mcpView(def, item, ctx, key);
        case 'hook':
            return hookView(def, item, ctx, key);
        case 'plugin':
            return pluginView(def, item, ctx);
        case 'extension':
            return extensionView(def, item, ctx);
        default:
            return instructionView(def, item, ctx, key);
    }
}

// Context sections

/** Sort labels per Context section. */
const CONTEXT_SORT = Object.freeze({
    tools: ['Most calls', 'Fewest calls'],
    skills: ['Most loads', 'Fewest loads'],
    agents: ['Most used', 'Least used'],
    subagents: ['Most runs', 'Fewest runs'],
    canvases: ['Most calls', 'Fewest calls'],
    instructions: ['Most reads', 'Fewest reads'],
    mcp: ['Most calls', 'Fewest calls'],
    hooks: ['Most runs', 'Fewest runs'],
    plugins: ['Most used', 'Least used'],
    extensions: ['Most used', 'Least used'],
});

const CONTEXT_RENDER_LIMIT = 400;

/**
 * Sort spec for one Context section, as used by {@link detailSort} and {@link sortDetailItems}.
 *
 * @param {{ id: string }} section
 */
export function contextSpec(section) {
    const [most, fewest] = CONTEXT_SORT[section.id] ?? ['Most used', 'Least used'];
    return { id: section.id, nameOf: (item) => item.name, count: { of: (item) => item.count, most, fewest } };
}

/**
 * Filters Context items by a case-insensitive query over name, key, description, count, and badges.
 *
 * @param {object[]} items
 * @param {string} query
 * @returns {object[]}
 */
export function filterContextItems(items, query) {
    const needle = query.trim().toLowerCase();
    if (!needle) {
        return items;
    }
    return items.filter((item) => [item.name, item.key, item.description, item.countText, ...item.badges.map((badge) => badge.text)]
        .some((value) => typeof value === 'string' && value.toLowerCase().includes(needle)));
}

const BADGE_TONES = { accent: 'badge-current', live: 'badge-live', success: 'badge-live', warning: 'badge-warning', danger: 'badge-danger' };

function contextRow(section, item, ctx) {
    const sub = item.badges.length || item.description
        ? el('span', { class: 'context-item-sub' },
            ...item.badges.map((badge) => el('span', { class: `badge${BADGE_TONES[badge.tone] ? ` ${BADGE_TONES[badge.tone]}` : ''}` }, badge.text)),
            item.description ? el('span', { class: 'context-item-desc' }, item.description) : null)
        : null;
    const button = el('button', { class: 'context-item', type: 'button', 'data-key': item.key },
        el('span', { class: 'context-item-head' },
            el('span', { class: `context-item-name${item.mono ? ' mono' : ''}` }, item.name),
            el('span', { class: `context-item-count${item.count ? '' : ' is-zero'}` }, item.countText, item.failed ? el('span', { class: 'context-item-failed' }, ` · ${item.failed.toLocaleString()} failed`) : null)),
        sub);
    button.title = item.description ? `${item.name}\n${item.description}` : item.name;
    button.addEventListener('click', () => ctx.onOpenItem(section.id, item.key));
    return el('li', null, button);
}

const sectionSignatures = new WeakMap();

function renderContextSection(node, section, ctx, query) {
    const { state } = ctx;
    const spec = contextSpec(section);
    const sort = detailSort(spec, state);
    const matches = filterContextItems(section.items, query);
    const filtering = query.trim().length > 0;
    const collapsed = filtering ? matches.length === 0 || state.filterCollapsed.has(section.id) : state.collapsed.has(section.id);
    const rows = sortDetailItems(matches, sort, spec);
    const signature = JSON.stringify([section.status, section.note, section.total, collapsed, filtering, sort, rows.slice(0, CONTEXT_RENDER_LIMIT).map((row) => [row.key, row.name, row.countText, row.failed, row.description, row.badges])]);
    if (sectionSignatures.get(node) === signature) {
        return;
    }
    sectionSignatures.set(node, signature);
    const listId = `ctx-list-${section.id}`;
    const headingId = `ctx-heading-${section.id}`;
    node.className = `inspector-section context-section${collapsed ? ' is-collapsed' : ''}${filtering && matches.length === 0 ? ' is-empty' : ''}`;
    node.setAttribute('aria-labelledby', headingId);
    const total = section.items.length;
    const countText = filtering ? `${matches.length.toLocaleString()} of ${total.toLocaleString()}` : total.toLocaleString();
    const toggle = el('button', { class: 'section-toggle', type: 'button', 'aria-expanded': String(!collapsed), 'aria-controls': listId },
        icon('i-chevron'), section.title, ' ', el('span', { class: 'heading-count' }, countText));
    toggle.addEventListener('click', () => ctx.onToggleSection(section.id, collapsed, filtering));
    const heading = el('h2', { id: headingId, class: 'panel-heading' }, toggle);
    const children = [];
    if (!collapsed && rows.length > 1) {
        children.push(el('div', { class: 'panel-heading-row' }, heading, el('div', { class: 'sort-bar', role: 'group', 'aria-label': `Sort ${section.title}` }, ...sortChips(spec, sort, (next) => ctx.onSort(section.id, next)))));
    } else {
        children.push(heading);
    }
    if (!collapsed) {
        children.push(el('p', { class: 'source-note' }, section.note));
        const list = el('ul', { id: listId, class: 'context-list scroll-well', 'aria-label': section.title });
        list.append(...(rows.length
            ? rows.slice(0, CONTEXT_RENDER_LIMIT).map((row) => contextRow(section, row, ctx))
            : [el('li', { class: 'list-empty' }, filtering ? 'No matches.' : 'Nothing listed.')]));
        if (rows.length > CONTEXT_RENDER_LIMIT) {
            list.append(el('li', { class: 'list-empty' }, `${(rows.length - CONTEXT_RENDER_LIMIT).toLocaleString()} more; filter to narrow the list.`));
        }
        children.push(list);
    }
    const scroller = node.querySelector('.context-list');
    const scrollTop = scroller?.scrollTop ?? 0;
    const focusKey = node.contains(document.activeElement) ? document.activeElement?.dataset?.key ?? null : null;
    const focusSort = node.contains(document.activeElement) && document.activeElement?.classList?.contains('sort-chip') ? [...node.querySelectorAll('.sort-chip')].indexOf(document.activeElement) : -1;
    const focusToggle = node.contains(document.activeElement) && document.activeElement?.classList?.contains('section-toggle');
    node.replaceChildren(...children);
    const nextScroller = node.querySelector('.context-list');
    if (nextScroller) {
        nextScroller.scrollTop = scrollTop;
    }
    if (focusKey !== null) {
        node.querySelector(`.context-item[data-key="${CSS.escape(focusKey)}"]`)?.focus({ preventScroll: true });
    } else if (focusSort >= 0) {
        node.querySelectorAll('.sort-chip')[focusSort]?.focus({ preventScroll: true });
    } else if (focusToggle) {
        node.querySelector('.section-toggle')?.focus({ preventScroll: true });
    }
}

/**
 * Renders the Context sections, re-rendering only sections whose rows, sort, filter, or collapse
 * state changed so scroll positions and focus survive refreshes.
 *
 * @param {HTMLElement} container
 * @param {object} data
 * @param {object[]} data.sections Sections from the inventory route.
 * @param {string} data.query Filter text.
 * @param {object} data.ctx `state` (`collapsed`, `filterCollapsed`, `sort`), `onToggleSection(id, expand, filtering)`,
 *   `onSort`, and `onOpenItem`.
 */
export function renderContextSections(container, { sections, query, ctx }) {
    const existing = new Map([...container.children].map((node) => [node.dataset.section, node]));
    const nodes = sections.map((section) => {
        const node = existing.get(section.id) ?? el('section', { 'data-section': section.id });
        renderContextSection(node, section, ctx, query);
        return node;
    });
    if (nodes.length !== container.children.length || nodes.some((node, index) => container.children[index] !== node)) {
        container.replaceChildren(...nodes);
    }
}

const KIND_LABEL = { tool: 'Tool', agent: 'Agent', skill: 'Skill', instruction: 'Instruction', canvas: 'Canvas', mcp: 'MCP server', hook: 'Hook', plugin: 'Plugin', extension: 'Extension' };

/**
 * Renders a definition page: Back, the item's name, kind, and use, then what the model receives.
 *
 * @param {HTMLElement} container
 * @param {object} data
 * @param {{ id: string, title: string }} data.section
 * @param {object} data.item Context item.
 * @param {object | null} data.def Definition route payload, or null while loading.
 * @param {string | null} data.error Load error message.
 * @param {string} data.backLabel Where Back returns to.
 * @param {object} data.ctx Definition context.
 */
export function renderDefinitionPage(container, { section, item, def, error, backLabel, ctx }) {
    const kind = item.definition?.kind ?? 'instruction';
    const key = `${section.id}:${item.key}`;
    const back = el('button', { class: 'btn btn-small def-back', type: 'button', 'aria-keyshortcuts': 'Escape' }, icon('i-arrow-left'), backLabel);
    back.title = `Back to ${backLabel} (Escape)`;
    back.addEventListener('click', () => ctx.onBack());
    const head = el('div', { class: 'def-page-head' },
        back,
        el('span', { class: 'def-kind' }, KIND_LABEL[kind] ?? section.title));
    const title = el('h2', { id: 'contextDetailTitle', class: `def-title${item.mono ? ' mono' : ''}`, tabindex: '-1' }, item.name);
    const meta = el('p', { class: 'def-meta' },
        el('span', { class: item.count ? '' : 'is-zero' }, item.countText),
        item.failed ? el('span', { class: 'context-item-failed' }, ` · ${item.failed.toLocaleString()} failed`) : null,
        ...item.badges.filter((badge) => !(kind === 'hook' && badge.tone === 'danger')).map((badge) => el('span', { class: `badge${BADGE_TONES[badge.tone] ? ` ${BADGE_TONES[badge.tone]}` : ''}` }, badge.text)));
    const body = el('div', { class: 'def-body', 'aria-busy': String(!def && !error) });
    if (error) {
        body.append(el('p', { class: 'meta' }, `Could not load the definition: ${error}.`), actions(actionButton('Try again', 'i-refresh', () => ctx.onRetry())));
    } else if (!def) {
        body.append(el('div', { class: 'skeleton', 'aria-hidden': 'true' }, el('div', { class: 'skeleton-row mid' }), el('div', { class: 'skeleton-row' }), el('div', { class: 'skeleton-row short' })), el('p', { class: 'visually-hidden' }, 'Loading definition'));
    } else {
        body.append(...definitionView(kind, def, item, ctx, key, section.id));
    }
    container.replaceChildren(head, title, meta, body);
}

// Details panel

/**
 * Renders the Details panel: facts about the session and its main agent. What the model is given
 * lives in the inspector's Context view.
 *
 * @param {HTMLElement} container
 * @param {object} data
 * @param {{ onOpenContext?: () => void }} [data.ctx]
 */
export function renderDetailsPanel(container, { summary, inventory, agent, session, ctx }) {
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
        ['Premium requests', Number.isFinite(summary.session?.shutdown?.totalPremiumRequests ?? summary.session?.checkpoint?.totalPremiumRequests) ? String(summary.session.shutdown?.totalPremiumRequests ?? summary.session.checkpoint.totalPremiumRequests) : null],
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
    if (ctx?.onOpenContext) {
        const open = el('button', { class: 'btn btn-small', type: 'button' }, icon('i-layers'), 'Show what the model is given');
        open.addEventListener('click', () => ctx.onOpenContext());
        container.append(el('p', { class: 'source-note' }, 'Tools, skills, agents, canvases, instructions, MCP servers, hooks, plugins, and extensions are in the inspector\'s Context view.'), el('div', { class: 'detail-actions' }, open));
    }
}
