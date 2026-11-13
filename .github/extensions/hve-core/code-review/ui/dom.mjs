// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// DOM builders. All review text is untrusted: it enters the page through text nodes and
// links restricted to http and https, never through HTML parsing.

import { safeWebUrl } from './views.mjs';

const SVG = 'http://www.w3.org/2000/svg';

/**
 * Creates an element. `props` sets `class`, `text`, `on` listeners, and attributes.
 * `aria-*` booleans serialize as "true" or "false"; other `null` or `false` values are omitted.
 */
export function h(tag, props = {}, ...children) {
    const element = document.createElement(tag);
    for (const [key, value] of Object.entries(props ?? {})) {
        if (value === null || value === undefined) continue;
        if (key.startsWith('aria-') && typeof value === 'boolean') {
            element.setAttribute(key, String(value));
            continue;
        }
        if (value === false) continue;
        if (key === 'class') element.className = value;
        else if (key === 'text') element.textContent = String(value);
        else if (key === 'on') for (const [event, handler] of Object.entries(value)) element.addEventListener(event, handler);
        else if (key === 'dataset') Object.assign(element.dataset, value);
        else if (key in element && !key.includes('-') && typeof value !== 'string') element[key] = value;
        else element.setAttribute(key, value === true ? '' : String(value));
    }
    append(element, children);
    return element;
}

function append(element, children) {
    for (const child of children.flat(Infinity)) {
        if (child === null || child === undefined || child === false) continue;
        element.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
}

/** Creates an SVG element. Paint comes from stylesheet classes, never inline style attributes. */
export function svg(tag, attributes = {}, ...children) {
    const element = document.createElementNS(SVG, tag);
    for (const [key, value] of Object.entries(attributes)) if (value !== null && value !== undefined) element.setAttribute(key, String(value));
    for (const child of children.flat(Infinity)) {
        if (child === null || child === undefined || child === false) continue;
        element.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return element;
}

export function icon(name, className = 'icon') {
    const svg = document.createElementNS(SVG, 'svg');
    svg.setAttribute('class', className);
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    const use = document.createElementNS(SVG, 'use');
    use.setAttribute('href', `#i-${name}`);
    svg.append(use);
    return svg;
}

/** A status chip: icon and word, tinted by tone. Strong badges mark levels and kinds. */
export function badge(meta, { strong = false, text } = {}) {
    return h('span', { class: `badge tone-${meta.tone}${strong ? ' is-strong' : ''}` }, icon(meta.icon), text ?? meta.label);
}

export function idChip(value, { kind = null, title = null } = {}) {
    return h('span', { class: 'id-chip', 'data-kind': kind, title }, value);
}

export function count(value, label = null) {
    if (!label) return h('span', { class: 'count' }, String(value));
    return h('span', { class: 'count' }, h('span', { 'aria-hidden': 'true' }, String(value)), h('span', { class: 'visually-hidden' }, `, ${label}`));
}

export function meta(text, className = '') {
    return h('span', { class: `meta${className ? ` ${className}` : ''}` }, text);
}

/** Paragraph text with Markdown-style links limited to public web schemes. */
export function prose(value, className = 'prose') {
    const paragraph = h('p', { class: className });
    const source = String(value ?? '');
    let at = 0;
    for (const match of source.matchAll(/\[([^\]\n]+)\]\(([^)\s]+)\)/g)) {
        paragraph.append(document.createTextNode(source.slice(at, match.index)));
        const url = safeWebUrl(match[2]);
        if (url) paragraph.append(h('a', { href: url, target: '_blank', rel: 'noopener noreferrer' }, match[1], icon('go-to', 'icon icon-inline')));
        else paragraph.append(h('span', { title: match[2] }, match[1]));
        at = match.index + match[0].length;
    }
    paragraph.append(document.createTextNode(source.slice(at)));
    return paragraph;
}

const relative = typeof Intl.RelativeTimeFormat === 'function' ? new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }) : null;
const absolute = new Intl.DateTimeFormat(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZoneName: 'short' });

/** Relative time with the full date in its title; times update with the data, not a timer. */
export function time(iso) {
    const date = new Date(iso);
    if (!Number.isFinite(date.getTime())) return null;
    const seconds = Math.round((date.getTime() - Date.now()) / 1000);
    const steps = [[60, 'second'], [60, 'minute'], [24, 'hour'], [7, 'day'], [4.35, 'week'], [12, 'month'], [Infinity, 'year']];
    let value = seconds;
    let unit = 'second';
    for (const [size, name] of steps) {
        unit = name;
        if (Math.abs(value) < size) break;
        value /= size;
    }
    const label = relative ? relative.format(Math.round(value), unit) : absolute.format(date);
    return h('time', { datetime: date.toISOString(), title: absolute.format(date) }, label);
}

export function shortSha(value) {
    return typeof value === 'string' && /^[0-9a-f]{40,64}$/i.test(value) ? value.slice(0, 7) : value;
}
