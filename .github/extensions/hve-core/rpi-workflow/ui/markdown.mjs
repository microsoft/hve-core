// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h, icon, idChip, sr } from './dom.mjs';
import { ID_SOURCE } from './ids.mjs';

/**
 * Restricted Markdown renderer. Builds DOM nodes only (never HTML strings), scans in
 * linear time, caps nesting, falls back to plain text for any block that fails, links
 * only http and https URLs, and turns known RPI IDs into navigation chips.
 */

const MAX_LENGTH = 60000;
const MAX_QUOTE_DEPTH = 6;
const MAX_INLINE_DEPTH = 4;
const MAX_INLINE_LENGTH = 4000;
const ID_RE = new RegExp(ID_SOURCE, 'g');

/** True when the URL may become a link: http or https only. */
export function isSafeUrl(url) {
    try {
        const parsed = new URL(url);
        return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch {
        return false;
    }
}

/**
 * A link to an external source that opens in a new browsing context, or plain text with the
 * address in a tooltip when the address is not http or https.
 *
 * @param {string} url
 * @param {string} label
 */
export function externalLink(url, label) {
    if (!isSafeUrl(url)) {
        return h('span', { class: 'md-link-text', title: String(url ?? ''), text: label });
    }
    return h('a', { href: url, target: '_blank', rel: 'noopener noreferrer', class: 'ext-link' }, label, icon('globe', { className: 'icon-inline' }), sr(' (opens in a new tab)'));
}

const indentOf = (line) => {
    let count = 0;
    while (count < line.length && line[count] === ' ') count += 1;
    return count;
};

function headingLevel(line) {
    const start = indentOf(line);
    if (start > 3) return 0;
    let level = 0;
    while (line[start + level] === '#' && level < 7) level += 1;
    return level >= 1 && level <= 6 && (line[start + level] === ' ' || start + level === line.length) ? level : 0;
}

function headingText(line, level) {
    let text = line.trim().slice(level).trim();
    let end = text.length;
    while (end > 0 && text[end - 1] === '#') end -= 1;
    if (end < text.length && (end === 0 || text[end - 1] === ' ')) {
        text = text.slice(0, end).trimEnd();
    }
    return text;
}

function isRule(line) {
    const trimmed = line.trim();
    if (trimmed.length < 3 || indentOf(line) > 3) return false;
    const mark = trimmed[0];
    if (mark !== '-' && mark !== '*' && mark !== '_') return false;
    let count = 0;
    for (const ch of trimmed) {
        if (ch === mark) count += 1;
        else if (ch !== ' ') return false;
    }
    return count >= 3;
}

const fenceOf = (line) => {
    const trimmed = line.trimStart();
    if (indentOf(line) > 3) return null;
    if (trimmed.startsWith('```')) return '```';
    if (trimmed.startsWith('~~~')) return '~~~';
    return null;
};

function listMarker(line) {
    const start = indentOf(line);
    const ch = line[start];
    if ((ch === '-' || ch === '*' || ch === '+') && line[start + 1] === ' ') {
        return { ordered: false, indent: start, content: start + 2 };
    }
    let digits = 0;
    while (digits < 9 && line[start + digits] >= '0' && line[start + digits] <= '9') digits += 1;
    if (digits > 0 && (line[start + digits] === '.' || line[start + digits] === ')') && line[start + digits + 1] === ' ') {
        return { ordered: true, indent: start, content: start + digits + 2, number: Number(line.slice(start, start + digits)) };
    }
    return null;
}

const isQuote = (line) => indentOf(line) <= 3 && line.trimStart().startsWith('>');

function splitRow(line) {
    let text = line.trim();
    if (text.startsWith('|')) text = text.slice(1);
    if (text.endsWith('|')) text = text.slice(0, -1);
    return text.split('|').map((cell) => cell.trim());
}

function isSeparator(line) {
    if (!line.includes('-')) return false;
    const cells = splitRow(line);
    return cells.length > 0 && cells.every((cell) => {
        let body = cell;
        if (body.startsWith(':')) body = body.slice(1);
        if (body.endsWith(':')) body = body.slice(0, -1);
        return body.length > 0 && [...body].every((ch) => ch === '-');
    });
}

const startsBlock = (line, next) => headingLevel(line) > 0 || fenceOf(line) !== null || isRule(line) || isQuote(line) || listMarker(line) !== null || (line.includes('|') && next !== undefined && isSeparator(next));

/**
 * @param {string} source
 * @param {{ resolveId?: (id: string) => boolean, navigate?: (id: string) => void, label?: string }} [ctx]
 *   `label` names the text's section until a heading inside it does; table regions use it so
 *   two tables with the same columns stay distinguishable.
 * @returns {DocumentFragment}
 */
export function renderMarkdown(source, ctx = {}) {
    const fragment = document.createDocumentFragment();
    let text = typeof source === 'string' ? source : '';
    if (text.length > MAX_LENGTH) {
        text = text.slice(0, MAX_LENGTH);
        fragment.append(h('p', { class: 'md-note', text: 'Showing the first 60,000 characters.' }));
    }
    const section = { name: typeof ctx.label === 'string' && ctx.label.trim() ? ctx.label.trim() : null };
    renderBlocks(fragment, text.replace(/\r\n?/g, '\n').split('\n'), { ...ctx, section }, 0);
    return fragment;
}

/**
 * Inline Markdown as plain text, for tooltips and labels: link text instead of links, and no
 * code or emphasis markers.
 *
 * @param {string | null | undefined} text
 */
export function plainInline(text) {
    return String(text ?? '')
        .replace(/\[([^\]\n]{0,500})\]\([^)\n]{0,2000}\)/g, '$1')
        .replace(/`([^`\n]{0,2000})`/g, '$1')
        .replace(/\*\*([^*\n]{1,2000})\*\*/g, '$1')
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Renders one line of inline Markdown, such as a table cell: code spans, links, emphasis,
 * and linked IDs, with whitespace collapsed. `shortUrls` labels a bare address by its host
 * and the end of its path.
 *
 * @param {string} source
 * @param {{ resolveId?: (id: string) => boolean, navigate?: (id: string) => void, shortUrls?: boolean, baseDir?: string, openSource?: (path: string, anchor: string | null) => void }} [ctx]
 * @returns {DocumentFragment}
 */
export function renderInline(source, ctx = {}) {
    const fragment = document.createDocumentFragment();
    const text = typeof source === 'string' ? source.slice(0, MAX_INLINE_LENGTH).replace(/\s+/g, ' ').trim() : '';
    try {
        inline(fragment, text, ctx, 0);
    } catch {
        fragment.append(document.createTextNode(text));
    }
    return fragment;
}

/**
 * A short label for a web address: its host without `www.`, then the last part of its path
 * when there is one, such as `learn.microsoft.com/…/maximum-file-path-limitation`.
 *
 * @param {string} url
 */
export function shortUrl(url) {
    try {
        const parsed = new URL(url);
        const host = parsed.hostname.replace(/^www\./, '');
        const parts = parsed.pathname.split('/').filter(Boolean);
        if (!parts.length) return host;
        let last = parts.at(-1);
        try {
            last = decodeURIComponent(last);
        } catch {
            // Keep the encoded segment.
        }
        if (last.length > 48) last = `${last.slice(0, 47)}…`;
        return parts.length > 1 ? `${host}/…/${last}` : `${host}/${last}`;
    } catch {
        return String(url ?? '');
    }
}

function renderBlocks(parent, lines, ctx, depth) {
    let i = 0;
    while (i < lines.length) {
        const line = lines[i];
        if (line.trim() === '') {
            i += 1;
            continue;
        }
        const start = i;
        try {
            i = renderBlock(parent, lines, i, ctx, depth);
        } catch {
            parent.append(h('p', { text: lines.slice(start, start + 1).join('\n') }));
            i = start + 1;
        }
        if (i <= start) i = start + 1;
    }
}

function renderBlock(parent, lines, i, ctx, depth) {
    const line = lines[i];
    const fence = fenceOf(line);
    if (fence) {
        const body = [];
        let j = i + 1;
        while (j < lines.length && !lines[j].trimStart().startsWith(fence)) {
            body.push(lines[j]);
            j += 1;
        }
        const lang = line.trim().slice(3).trim().split(/\s/)[0];
        parent.append(h('pre', { class: 'md-code', tabindex: '0', 'aria-label': lang ? `${lang} code` : 'Code' }, h('code', { text: body.join('\n') })));
        return j + 1;
    }
    const level = headingLevel(line);
    if (level) {
        // Rows are h3, so Markdown headings start at h4.
        const heading = h(level <= 2 ? 'h4' : 'h5', { class: ['md-heading', level <= 2 ? 'is-major' : null] });
        inline(heading, headingText(line, level), ctx, 0);
        parent.append(heading);
        if (ctx.section && heading.textContent.trim()) ctx.section.name = heading.textContent.trim();
        return i + 1;
    }
    if (isRule(line)) {
        parent.append(h('hr'));
        return i + 1;
    }
    if (isQuote(line)) {
        const body = [];
        let j = i;
        while (j < lines.length && isQuote(lines[j])) {
            const stripped = lines[j].trimStart().slice(1);
            body.push(stripped.startsWith(' ') ? stripped.slice(1) : stripped);
            j += 1;
        }
        const quote = h('blockquote');
        if (depth + 1 > MAX_QUOTE_DEPTH) {
            quote.append(h('p', { text: body.join('\n') }));
        } else {
            renderBlocks(quote, body, ctx, depth + 1);
        }
        parent.append(quote);
        return j;
    }
    const marker = listMarker(line);
    if (marker) {
        return renderList(parent, lines, i, marker, ctx);
    }
    if (line.includes('|') && i + 1 < lines.length && isSeparator(lines[i + 1])) {
        return renderTable(parent, lines, i, ctx);
    }
    const paragraph = [];
    let j = i;
    while (j < lines.length && lines[j].trim() !== '' && (j === i || !startsBlock(lines[j], lines[j + 1]))) {
        paragraph.push(lines[j].trim());
        j += 1;
    }
    const p = h('p');
    inline(p, paragraph.join(' '), ctx, 0);
    parent.append(p);
    return j;
}

function renderList(parent, lines, i, first, ctx) {
    const list = h(first.ordered ? 'ol' : 'ul', first.ordered && first.number !== 1 ? { start: String(first.number) } : null);
    let j = i;
    while (j < lines.length) {
        const marker = listMarker(lines[j]);
        if (!marker || marker.ordered !== first.ordered || marker.indent > first.indent + 1) break;
        let content = lines[j].slice(marker.content);
        j += 1;
        while (j < lines.length && lines[j].trim() !== '' && !listMarker(lines[j]) && indentOf(lines[j]) >= 2) {
            content += ` ${lines[j].trim()}`;
            j += 1;
        }
        const item = h('li');
        const task = content.startsWith('[ ] ') ? false : content.startsWith('[x] ') || content.startsWith('[X] ') ? true : null;
        if (task !== null) {
            item.classList.add('md-task');
            item.append(icon(task ? 'check-circle' : 'circle', { className: task ? 'tone-success-fg' : 'tone-muted-fg' }), sr(task ? 'Done: ' : 'Not done: '));
            content = content.slice(4);
        }
        inline(item, content, ctx, 0);
        list.append(item);
        while (j < lines.length && lines[j].trim() === '' && j + 1 < lines.length && listMarker(lines[j + 1])?.ordered === first.ordered) j += 1;
    }
    parent.append(list);
    return j;
}

function renderTable(parent, lines, i, ctx) {
    const header = splitRow(lines[i]);
    const table = h('table', { class: 'md-table' });
    const headRow = h('tr');
    for (const cell of header) {
        const th = h('th', { scope: 'col' });
        inline(th, cell, ctx, 0);
        headRow.append(th);
    }
    table.append(h('thead', null, headRow));
    const body = h('tbody');
    let j = i + 2;
    while (j < lines.length && lines[j].includes('|') && lines[j].trim() !== '') {
        const row = h('tr');
        const cells = splitRow(lines[j]);
        for (let c = 0; c < header.length; c += 1) {
            const td = h('td');
            inline(td, cells[c] ?? '', ctx, 0);
            row.append(td);
        }
        body.append(row);
        j += 1;
    }
    table.append(body);
    const section = ctx.section?.name;
    parent.append(h('div', { class: 'table-well', tabindex: '0', role: 'region', 'aria-label': `${section ? `${section.slice(0, 60)} table` : 'Table'}: ${header.join(', ').slice(0, 80)}` }, table));
    return j;
}

/**
 * Appends inline Markdown as nodes. Each closer search is remembered when it fails, so
 * many unmatched markers stay linear.
 */
function inline(parent, text, ctx, depth) {
    if (depth > MAX_INLINE_DEPTH) {
        appendText(parent, text, ctx);
        return;
    }
    // Each token's search start only moves forward, so its next position can be reused.
    const next = new Map();
    const find = (token, from) => {
        const cached = next.get(token);
        if (cached !== undefined && (cached === -1 || cached >= from)) return cached;
        const index = text.indexOf(token, from);
        next.set(token, index);
        return index;
    };
    // Matching parentheses, found once per span, let destinations skip balanced groups.
    let pairs = null;
    let nextSpace = null;
    const matchParens = () => {
        pairs = new Int32Array(text.length).fill(-1);
        nextSpace = new Int32Array(text.length + 1).fill(text.length);
        const stack = [];
        for (let k = 0; k < text.length; k += 1) {
            if (text[k] === '(') stack.push(k);
            else if (text[k] === ')' && stack.length) pairs[stack.pop()] = k;
        }
        for (let k = text.length - 1; k >= 0; k -= 1) {
            nextSpace[k] = text[k] === ' ' || text[k] === '\t' ? k : nextSpace[k + 1];
        }
    };
    const destinationEnd = (from) => {
        if (!pairs) matchParens();
        const limit = Math.min(text.length, from + 2000);
        let k = from;
        while (k < limit) {
            const c = text[k];
            if (c === ')') return k;
            if (c === ' ' || c === '\t') return -1;
            if (c === '(') {
                const end = pairs[k];
                if (end < 0 || end >= limit || nextSpace[k] < end) return -1;
                k = end + 1;
                continue;
            }
            k += 1;
        }
        return -1;
    };
    let buffer = '';
    const flush = () => {
        if (buffer) {
            appendText(parent, buffer, ctx);
            buffer = '';
        }
    };
    let i = 0;
    while (i < text.length) {
        const ch = text[i];
        if (ch === '`') {
            const end = find('`', i + 1);
            if (end > i) {
                flush();
                parent.append(h('code', null, breakAfterSlashes(text.slice(i + 1, end))));
                i = end + 1;
                continue;
            }
        } else if (ch === '[' && !ctx.inLink) {
            const close = find('](', i + 1);
            if (close > i && close - i <= 500) {
                const end = destinationEnd(close + 2);
                if (end > close) {
                    flush();
                    appendLink(parent, text.slice(i + 1, close), text.slice(close + 2, end), ctx, depth, text.slice(end + 1, end + 200));
                    i = end + 1;
                    continue;
                }
            }
        } else if ((ch === '*' && text[i + 1] === '*') || (ch === '~' && text[i + 1] === '~')) {
            const token = ch + ch;
            const end = find(token, i + 2);
            if (end > i + 2) {
                flush();
                const element = h(ch === '*' ? 'strong' : 'del');
                inline(element, text.slice(i + 2, end), ctx, depth + 1);
                parent.append(element);
                i = end + 2;
                continue;
            }
        } else if ((ch === '*' || ch === '_') && text[i + 1] && text[i + 1] !== ' ' && text[i + 1] !== ch && (i === 0 || /[\s([]/.test(text[i - 1]))) {
            const end = find(ch, i + 1);
            if (end > i + 1 && text[end - 1] !== ' ') {
                flush();
                const element = h('em');
                inline(element, text.slice(i + 1, end), ctx, depth + 1);
                parent.append(element);
                i = end + 1;
                continue;
            }
        } else if (ch === 'h' && !ctx.inLink && (i === 0 || /[\s(]/.test(text[i - 1])) && (text.startsWith('https://', i) || text.startsWith('http://', i))) {
            let end = i;
            while (end < text.length && end - i < 2000 && !/\s/.test(text[end])) end += 1;
            while (end > i && '.,;:!?)\'"'.includes(text[end - 1])) end -= 1;
            flush();
            const url = text.slice(i, end);
            appendLink(parent, ctx.shortUrls ? shortUrl(url) : url, url, ctx, depth);
            i = end;
            continue;
        }
        buffer += ch;
        i += 1;
    }
    flush();
}

/**
 * The workspace file a relative link in an artifact points at, resolved against the
 * artifact's folder, or null for links with a scheme, root-relative or fragment-only links,
 * and links that climb above the workspace.
 *
 * @param {string} baseDir workspace-relative folder of the artifact
 * @param {string} url
 * @returns {{ path: string, fragment: string | null } | null}
 */
export function workspaceTarget(baseDir, url) {
    const value = String(url ?? '').trim();
    if (!value || /^[a-z][\w+.-]*:/i.test(value) || value.startsWith('/') || value.startsWith('#') || /\s/.test(value)) return null;
    const [target, hash] = value.split('#');
    let decoded;
    try {
        decoded = decodeURI(target);
    } catch {
        return null;
    }
    const segments = [];
    for (const part of [...String(baseDir).split('/'), ...decoded.replace(/\\/g, '/').split('/')]) {
        if (!part || part === '.') continue;
        if (part === '..') {
            if (!segments.length) return null;
            segments.pop();
        } else {
            segments.push(part);
        }
    }
    return segments.length ? { path: segments.join('/'), fragment: hash ? `#${hash}` : null } : null;
}

/**
 * Link labels never contain links or ID chips, so interactive content never nests. A
 * relative link in an artifact becomes a source link when the caller can show workspace
 * files; its anchor is the link's fragment or a code span right after a colon, as in
 * `[path](path): \`symbol\``.
 */
function appendLink(parent, label, url, ctx, depth, after = '') {
    const labelCtx = { ...ctx, inLink: true };
    if (isSafeUrl(url)) {
        const link = h('a', { href: url, target: '_blank', rel: 'noopener noreferrer', class: 'ext-link', title: url });
        inline(link, label, labelCtx, depth + 1);
        link.append(icon('globe', { className: 'icon-inline' }), sr(' (opens in a new tab)'));
        parent.append(link);
        return;
    }
    const target = ctx.openSource && typeof ctx.baseDir === 'string' ? workspaceTarget(ctx.baseDir, url) : null;
    if (target) {
        const anchor = target.fragment ?? /^\s*:\s*`([^`\n]{1,200})`/.exec(after)?.[1] ?? null;
        const link = h('button', { type: 'button', class: 'source-link', onclick: () => ctx.openSource(target.path, anchor) });
        inline(link, label, labelCtx, depth + 1);
        link.append(icon('file', { className: 'icon-inline chip-icon' }), sr(', shows the file here'));
        parent.append(link);
        return;
    }
    const element = h('span', { class: 'md-link-text', title: url });
    inline(element, label, labelCtx, depth + 1);
    parent.append(element);
}

/** Text with a line break opportunity after each slash, so long paths wrap at folders. */
function breakAfterSlashes(text) {
    if (!text.includes('/')) return [text];
    const parts = text.split('/');
    return parts.flatMap((part, index) => (index < parts.length - 1 ? [`${part}/`, h('wbr')] : part ? [part] : []));
}

function appendText(parent, text, ctx) {
    if (!ctx.resolveId || !ctx.navigate || ctx.inLink) {
        parent.append(document.createTextNode(text));
        return;
    }
    let last = 0;
    ID_RE.lastIndex = 0;
    for (let match = ID_RE.exec(text); match; match = ID_RE.exec(text)) {
        const id = match[0];
        // A key in a combination, such as Shift+F10, is not a finding.
        if (text[match.index - 1] === '+' || text[match.index + id.length] === '+') continue;
        if (!ctx.resolveId(id)) continue;
        if (match.index > last) parent.append(document.createTextNode(text.slice(last, match.index)));
        parent.append(idChip(id, ctx.navigate, { className: 'inline' }));
        last = match.index + id.length;
    }
    if (last < text.length) parent.append(document.createTextNode(text.slice(last)));
}
