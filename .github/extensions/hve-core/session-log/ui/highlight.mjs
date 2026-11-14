// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Token-level JSON highlighting. Output is built from text nodes and spans only.

const MAX_HIGHLIGHT_CHARS = 256 * 1024;
// Alternatives are disjoint at each position, so matching stays linear in the input length.
const TOKEN_RE = /("(?:\\.|[^"\\\n])*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b|([{}[\],])/g;

/**
 * Returns true when text looks like JSON worth highlighting.
 *
 * @param {string} text
 * @returns {boolean}
 */
export function looksLikeJson(text) {
    if (typeof text !== 'string' || text.length === 0 || text.length > MAX_HIGHLIGHT_CHARS) {
        return false;
    }
    const first = text.trimStart()[0];
    return first === '{' || first === '[' || first === '"';
}

/**
 * Appends highlighted JSON text to a parent node.
 *
 * @param {Node} parent Target node.
 * @param {string} text JSON text, possibly cut at either end.
 * @param {Document} [doc]
 */
export function appendJson(parent, text, doc = globalThis.document) {
    if (text.length > MAX_HIGHLIGHT_CHARS) {
        parent.append(doc.createTextNode(text));
        return;
    }
    let last = 0;
    TOKEN_RE.lastIndex = 0;
    for (let match = TOKEN_RE.exec(text); match; match = TOKEN_RE.exec(text)) {
        if (match.index > last) {
            parent.append(doc.createTextNode(text.slice(last, match.index)));
        }
        if (match[1] !== undefined) {
            parent.append(span(doc, match[2] !== undefined ? 'tok-key' : 'tok-str', match[1]));
            if (match[2] !== undefined) {
                parent.append(span(doc, 'tok-punc', match[2]));
            }
        } else if (match[3] !== undefined) {
            parent.append(span(doc, 'tok-num', match[3]));
        } else if (match[4] !== undefined) {
            parent.append(span(doc, match[4] === 'null' ? 'tok-null' : 'tok-bool', match[4]));
        } else {
            parent.append(span(doc, 'tok-punc', match[5]));
        }
        last = TOKEN_RE.lastIndex;
    }
    if (last < text.length) {
        parent.append(doc.createTextNode(text.slice(last)));
    }
}

function span(doc, className, text) {
    const node = doc.createElement('span');
    node.className = className;
    node.textContent = text;
    return node;
}

// Opening, closing, and self-closing tags; bounded attribute text keeps matching linear.
const TAG_RE = /<\/?[A-Za-z][\w.:-]{0,64}(?:\s[^<>\n]{0,300})?\/?>/g;

/**
 * Appends text with XML-style tags highlighted, as used to structure system prompts.
 *
 * @param {Node} parent Target node.
 * @param {string} text
 * @param {Document} [doc]
 */
export function appendTagged(parent, text, doc = globalThis.document) {
    if (text.length > MAX_HIGHLIGHT_CHARS) {
        parent.append(doc.createTextNode(text));
        return;
    }
    let last = 0;
    TAG_RE.lastIndex = 0;
    for (let match = TAG_RE.exec(text); match; match = TAG_RE.exec(text)) {
        if (match.index > last) {
            parent.append(doc.createTextNode(text.slice(last, match.index)));
        }
        parent.append(span(doc, 'tok-tag', match[0]));
        last = TAG_RE.lastIndex;
    }
    if (last < text.length) {
        parent.append(doc.createTextNode(text.slice(last)));
    }
}
