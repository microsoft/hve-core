// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Renders a restricted Markdown subset into DOM nodes. Untrusted text is only
// ever inserted through text nodes; no HTML string is parsed.

const MAX_INPUT = 256 * 1024;
const MAX_QUOTE_DEPTH = 6;
// Block patterns run on trimmed lines and avoid adjacent optional runs, so matching stays linear.
const FENCE_RE = /^( {0,3})(`{3,}|~{3,})[ \t]*([\w+-]*)$/;
const HEADING_RE = /^\s{0,3}(#{1,6})[ \t]/;
const TABLE_CELL_RE = /^:?-{2,}:?$/;
const LIST_RE = /^(\s*)([*+-]|\d{1,9}[.)])\s+(.*)$/;
const RULE_RE = /^\s{0,3}([-*_])(\s*\1){2,}\s*$/;
const QUOTE_RE = /^\s{0,3}>\s?(.*)$/;

/**
 * Returns true when a URL is safe to use as a link target.
 *
 * @param {string} url
 * @returns {boolean}
 */
export function isSafeHref(url) {
    try {
        const parsed = new URL(url);
        return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch {
        return false;
    }
}

/**
 * Renders Markdown text into a document fragment.
 *
 * @param {string} source Untrusted Markdown text.
 * @param {Document} [doc] Document used to create nodes.
 * @returns {DocumentFragment}
 */
export function renderMarkdown(source, doc = globalThis.document) {
    const text = typeof source === 'string' ? source.slice(0, MAX_INPUT) : '';
    return renderBlocks(text.replace(/\r\n?/g, '\n').split('\n'), doc, 0);
}

/**
 * @param {string} line
 * @returns {boolean} True for a table separator row such as `| --- | :-: |`.
 */
function isTableSeparator(line) {
    let body = line.trim();
    if (body.startsWith('|')) {
        body = body.slice(1);
    }
    if (body.endsWith('|')) {
        body = body.slice(0, -1);
    }
    const cells = body.split('|');
    return cells.length > 0 && cells.every((cell) => TABLE_CELL_RE.test(cell.trim()));
}

/**
 * @param {string} rest Heading text after the opening hashes.
 * @returns {string} The text without an optional closing hash sequence.
 */
function headingText(rest) {
    let text = rest.trimEnd();
    let end = text.length;
    while (end > 0 && text[end - 1] === '#') {
        end -= 1;
    }
    if (end < text.length && (end === 0 || text[end - 1] === ' ' || text[end - 1] === '\t')) {
        text = text.slice(0, end);
    }
    return text.trim();
}

/**
 * @param {string[]} lines
 * @param {Document} doc
 * @param {number} depth Blockquote nesting depth.
 * @returns {DocumentFragment}
 */
function renderBlocks(lines, doc, depth) {
    const fragment = doc.createDocumentFragment();
    let index = 0;
    let paragraph = [];

    const flushParagraph = () => {
        if (paragraph.length === 0) {
            return;
        }
        const p = doc.createElement('p');
        paragraph.forEach((line, lineIndex) => {
            if (lineIndex > 0) {
                p.append(doc.createElement('br'));
            }
            appendInline(p, line, doc);
        });
        fragment.append(p);
        paragraph = [];
    };

    while (index < lines.length) {
        const line = lines[index];
        const fence = FENCE_RE.exec(line.trimEnd());
        if (fence) {
            flushParagraph();
            const marker = fence[2];
            const body = [];
            index += 1;
            while (index < lines.length && !lines[index].trimStart().startsWith(marker[0].repeat(marker.length))) {
                body.push(lines[index]);
                index += 1;
            }
            index += 1;
            const pre = doc.createElement('pre');
            pre.className = 'code-well';
            pre.tabIndex = 0;
            const code = doc.createElement('code');
            if (fence[3]) {
                code.dataset.lang = fence[3].slice(0, 30);
            }
            code.textContent = body.join('\n');
            pre.append(code);
            fragment.append(pre);
            continue;
        }
        if (line.trim().length === 0) {
            flushParagraph();
            index += 1;
            continue;
        }
        const heading = HEADING_RE.exec(line);
        if (heading) {
            flushParagraph();
            const level = Math.min(6, heading[1].length + 3);
            const h = doc.createElement(`h${level}`);
            h.className = `md-heading md-h${heading[1].length}`;
            appendInline(h, headingText(line.slice(heading[0].length)), doc);
            fragment.append(h);
            index += 1;
            continue;
        }
        if (RULE_RE.test(line)) {
            flushParagraph();
            fragment.append(doc.createElement('hr'));
            index += 1;
            continue;
        }
        if (line.includes('|') && index + 1 < lines.length && isTableSeparator(lines[index + 1])) {
            flushParagraph();
            const rows = [line];
            index += 2;
            while (index < lines.length && lines[index].includes('|') && lines[index].trim().length > 0) {
                rows.push(lines[index]);
                index += 1;
            }
            fragment.append(renderTable(rows, doc));
            continue;
        }
        if (QUOTE_RE.test(line)) {
            flushParagraph();
            const quoted = [];
            while (index < lines.length && QUOTE_RE.test(lines[index])) {
                quoted.push(QUOTE_RE.exec(lines[index])[1]);
                index += 1;
            }
            const blockquote = doc.createElement('blockquote');
            if (depth + 1 >= MAX_QUOTE_DEPTH) {
                const p = doc.createElement('p');
                p.textContent = quoted.join('\n');
                blockquote.append(p);
            } else {
                blockquote.append(renderBlocks(quoted, doc, depth + 1));
            }
            fragment.append(blockquote);
            continue;
        }
        if (LIST_RE.test(line)) {
            flushParagraph();
            const items = [];
            while (index < lines.length) {
                const current = lines[index];
                const match = LIST_RE.exec(current);
                if (match) {
                    items.push({ indent: match[1].replace(/\t/g, '    ').length, ordered: /\d/.test(match[2]), start: Number.parseInt(match[2], 10), text: match[3] });
                    index += 1;
                    continue;
                }
                if (current.trim().length > 0 && /^\s{2,}/.test(current) && items.length > 0) {
                    items[items.length - 1].text += `\n${current.trim()}`;
                    index += 1;
                    continue;
                }
                break;
            }
            fragment.append(renderList(items, doc));
            continue;
        }
        paragraph.push(line);
        index += 1;
    }
    flushParagraph();
    return fragment;
}

function renderList(items, doc) {
    const rootIndent = items[0].indent;
    const makeList = (ordered, start) => {
        const list = doc.createElement(ordered ? 'ol' : 'ul');
        if (ordered && Number.isFinite(start) && start !== 1) {
            list.start = start;
        }
        return list;
    };
    const root = makeList(items[0].ordered, items[0].start);
    const stack = [{ indent: rootIndent, list: root }];
    for (const item of items) {
        while (stack.length > 1 && item.indent < stack[stack.length - 1].indent) {
            stack.pop();
        }
        let top = stack[stack.length - 1];
        if (item.indent > top.indent && stack.length < 6) {
            const parentItem = top.list.lastElementChild;
            if (parentItem) {
                const nested = makeList(item.ordered, item.start);
                parentItem.append(nested);
                stack.push({ indent: item.indent, list: nested });
                top = stack[stack.length - 1];
            }
        }
        const li = doc.createElement('li');
        item.text.split('\n').forEach((part, partIndex) => {
            if (partIndex > 0) {
                li.append(doc.createElement('br'));
            }
            appendInline(li, part, doc);
        });
        top.list.append(li);
    }
    return root;
}

function splitRow(row) {
    let trimmed = row.trim();
    if (trimmed.startsWith('|')) {
        trimmed = trimmed.slice(1);
    }
    if (trimmed.endsWith('|') && !trimmed.endsWith('\\|')) {
        trimmed = trimmed.slice(0, -1);
    }
    return trimmed.split(/(?<!\\)\|/).map((cell) => cell.replace(/\\\|/g, '|').trim());
}

function renderTable(rows, doc) {
    const wrapper = doc.createElement('div');
    wrapper.className = 'md-table';
    const table = doc.createElement('table');
    const thead = doc.createElement('thead');
    const headRow = doc.createElement('tr');
    for (const cell of splitRow(rows[0])) {
        const th = doc.createElement('th');
        th.scope = 'col';
        appendInline(th, cell, doc);
        headRow.append(th);
    }
    thead.append(headRow);
    table.append(thead);
    const tbody = doc.createElement('tbody');
    for (const row of rows.slice(1, 501)) {
        const tr = doc.createElement('tr');
        for (const cell of splitRow(row)) {
            const td = doc.createElement('td');
            appendInline(td, cell, doc);
            tr.append(td);
        }
        tbody.append(tr);
    }
    table.append(tbody);
    wrapper.append(table);
    return wrapper;
}

/**
 * Appends inline Markdown (code, links, emphasis) as DOM nodes.
 *
 * @param {Element} parent
 * @param {string} text
 * @param {Document} doc
 */
export function appendInline(parent, text, doc = globalThis.document) {
    const segments = text.split(/(`+[^`]*?`+)/);
    for (const segment of segments) {
        if (segment.length === 0) {
            continue;
        }
        const code = /^(`+)([\s\S]*?)\1$/.exec(segment);
        if (code && code[2].length > 0) {
            const element = doc.createElement('code');
            element.textContent = code[2].trim().length > 0 ? code[2].replace(/^ (.*) $/, '$1') : code[2];
            parent.append(element);
            continue;
        }
        appendLinksAndEmphasis(parent, segment, doc);
    }
}

const LINK_RE = /\[([^\]\n]{1,500})\]\(([^)\s]{1,2000})\)|(https?:\/\/[^\s<>()]{1,2000}[^\s<>().,;:!?'"\]])/g;

function appendLinksAndEmphasis(parent, text, doc) {
    let cursor = 0;
    let match;
    LINK_RE.lastIndex = 0;
    while ((match = LINK_RE.exec(text)) !== null) {
        appendEmphasis(parent, text.slice(cursor, match.index), doc);
        const label = match[1] ?? match[3];
        const href = match[2] ?? match[3];
        if (isSafeHref(href)) {
            const anchor = doc.createElement('a');
            anchor.href = href;
            anchor.target = '_blank';
            anchor.rel = 'noopener noreferrer';
            anchor.textContent = label;
            parent.append(anchor);
        } else {
            parent.append(doc.createTextNode(match[0]));
        }
        cursor = match.index + match[0].length;
    }
    appendEmphasis(parent, text.slice(cursor), doc);
}

const EMPHASIS_RE = /(\*\*|__)(?=\S)([^\n]{0,300}?\S)\1|(\*|_)(?=\S)([^\n]{0,300}?\S)\3(?![\w*])|~~(?=\S)([^\n]{0,300}?\S)~~/;

function appendEmphasis(parent, text, doc, depth = 0) {
    if (text.length === 0) {
        return;
    }
    if (depth > 4) {
        parent.append(doc.createTextNode(text));
        return;
    }
    let rest = text;
    while (rest.length > 0) {
        const match = EMPHASIS_RE.exec(rest);
        if (!match) {
            parent.append(doc.createTextNode(rest));
            return;
        }
        const before = rest.slice(0, match.index);
        const precededByWord = match[3] === '_' && /\w$/.test(before);
        if (precededByWord) {
            parent.append(doc.createTextNode(rest.slice(0, match.index + 1)));
            rest = rest.slice(match.index + 1);
            continue;
        }
        if (before) {
            parent.append(doc.createTextNode(before));
        }
        let element;
        let inner;
        if (match[1]) {
            element = doc.createElement('strong');
            inner = match[2];
        } else if (match[3]) {
            element = doc.createElement('em');
            inner = match[4];
        } else {
            element = doc.createElement('del');
            inner = match[5];
        }
        appendEmphasis(element, inner, doc, depth + 1);
        parent.append(element);
        rest = rest.slice(match.index + match[0].length);
    }
}
