// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/** DOM helpers, formatting, and the status vocabularies from the style guide. */

const SVG_NS = 'http://www.w3.org/2000/svg';

/**
 * Creates an element. Strings become text nodes; untrusted text is never parsed as HTML.
 *
 * @param {string} tag
 * @param {Record<string, any> | null} [attrs]
 * @param {...any} children
 * @returns {HTMLElement}
 */
export function h(tag, attrs, ...children) {
    const element = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs ?? {})) {
        if (value === undefined || value === null || value === false) {
            continue;
        }
        if (key === 'class') {
            element.className = Array.isArray(value) ? value.filter(Boolean).join(' ') : value;
        } else if (key === 'text') {
            element.textContent = String(value);
        } else if (key.startsWith('on') && typeof value === 'function') {
            element.addEventListener(key.slice(2).toLowerCase(), value);
        } else if (key === 'dataset') {
            for (const [name, data] of Object.entries(value)) {
                element.dataset[name] = String(data);
            }
        } else if (value === true) {
            element.setAttribute(key, '');
        } else {
            element.setAttribute(key, String(value));
        }
    }
    append(element, children);
    return element;
}

/**
 * @param {Node} parent
 * @param {any[]} children
 */
export function append(parent, children) {
    for (const child of children.flat(Infinity)) {
        if (child === null || child === undefined || child === false) {
            continue;
        }
        parent.appendChild(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return parent;
}

/**
 * Inline icon from the sprite; decorative unless a label is given.
 *
 * @param {string} name
 * @param {{ label?: string, className?: string }} [options]
 */
export function icon(name, options = {}) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', ['icon', options.className].filter(Boolean).join(' '));
    if (options.label) {
        svg.setAttribute('role', 'img');
        svg.setAttribute('aria-label', options.label);
    } else {
        svg.setAttribute('aria-hidden', 'true');
    }
    svg.setAttribute('focusable', 'false');
    const use = document.createElementNS(SVG_NS, 'use');
    use.setAttribute('href', `#i-${name}`);
    svg.appendChild(use);
    return svg;
}

/** Visually hidden text for assistive technology. */
export const sr = (text) => h('span', { class: 'visually-hidden', text });

export function clear(element) {
    while (element.firstChild) {
        element.removeChild(element.firstChild);
    }
    return element;
}

/**
 * Relative time from the data's own clock, never a timer.
 *
 * @param {string | null | undefined} iso
 * @param {number} now
 */
export function relTime(iso, now) {
    if (!iso) {
        return 'Not recorded';
    }
    const then = Date.parse(iso);
    if (Number.isNaN(then)) {
        return 'Not recorded';
    }
    const minutes = Math.round((now - then) / 60000);
    if (minutes < 1) return 'just now';
    if (minutes < 60) return `${minutes} min ago`;
    const hours = Math.round(minutes / 60);
    if (hours < 24) return `${hours} h ago`;
    return new Date(then).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/** Local HH:MM with the full ISO time available as a title. */
export function timeEl(iso, now) {
    return h('time', { datetime: iso ?? undefined, title: iso ?? undefined, class: 'time', text: relTime(iso, now) });
}

const vocab = (entries) => Object.freeze(Object.fromEntries(entries.map(([key, iconName, label, tone]) => [key, Object.freeze({ icon: iconName, label, tone })])));

export const PHASE_STATUS = vocab([
    ['done', 'check-circle', 'Done', 'success'],
    ['active', 'active', 'In progress', 'accent'],
    ['upcoming', 'circle', 'Upcoming', 'muted'],
    ['paused', 'pause', 'Paused for you', 'attention'],
    ['blocked', 'alert', 'Blocked', 'danger'],
    ['skipped', 'dash-circle', 'Skipped', 'muted'],
]);

export const TASK_STATUS = vocab([
    ['done', 'check-circle', 'Done', 'success'],
    ['in-progress', 'active', 'In progress', 'accent'],
    ['todo', 'circle', 'Up next', 'muted'],
    ['paused', 'pause', 'Paused for you', 'attention'],
    ['blocked', 'alert', 'Blocked', 'danger'],
]);

export const FEEDBACK_STATE = vocab([
    ['draft', 'pencil', 'Draft', 'muted'],
    ['queued', 'inbox', 'Queued', 'accent'],
    ['sent', 'send', 'Sent', 'accent'],
    ['interpreted', 'sparkle', 'Interpreted', 'agent'],
    ['applied', 'check', 'Applied', 'success'],
    ['corrected', 'undo', 'Corrected', 'attention'],
    ['dismissed', 'x', 'Dismissed', 'muted'],
]);

export const DECISION_STATUS = vocab([
    ['needs-input', 'hand', 'Needs your input', 'attention'],
    ['answered', 'person', 'Answered', 'user'],
    ['decided', 'sparkle', 'Agent decided', 'agent'],
    ['override-pending', 'undo', 'Override pending', 'attention'],
    ['resolved', 'check', 'Resolved', 'success'],
]);

export const EVIDENCE_STATE = vocab([
    ['evidence-backed', 'shield-check', 'Evidence-backed', 'success'],
    ['partially-supported', 'half', 'Partially supported', 'attention'],
    ['hypothesis', 'bulb', 'Hypothesis', 'muted'],
    ['weakened', 'trend-down', 'Weakened', 'danger'],
    ['unresolved', 'question', 'Unresolved', 'muted'],
]);

export const SEVERITY = vocab([
    ['critical', 'alert', 'Critical', 'danger'],
    ['high', 'alert', 'High', 'danger'],
    ['medium', 'alert', 'Medium', 'severe'],
    ['low', 'info', 'Low', 'muted'],
]);

export const VALIDATION = vocab([
    ['passed', 'check', 'Passed', 'success'],
    ['failed', 'x-circle', 'Failed', 'danger'],
    ['skipped', 'dash', 'Skipped', 'muted'],
    ['unavailable', 'slash-circle', 'Unavailable', 'muted'],
]);

export const DISCOVERY_KIND = vocab([
    ['local', 'check', 'Local judgment', 'muted'],
    ['annotation', 'pencil', 'Implementation note', 'accent'],
    ['follow-up', 'flag', 'Follow-up', 'attention'],
    ['plan-change', 'signpost', 'Plan change', 'severe'],
]);

export const FEEDBACK_KIND = Object.freeze({
    answer: { icon: 'person', label: 'Answer' },
    override: { icon: 'undo', label: 'Override' },
    comment: { icon: 'message', label: 'Comment' },
    context: { icon: 'info', label: 'Context' },
    'research-request': { icon: 'search', label: 'Research request' },
    edit: { icon: 'pencil', label: 'Section edit' },
    checklist: { icon: 'checklist', label: 'Review checklist' },
    correction: { icon: 'undo', label: 'Correction' },
    'task-request': { icon: 'list', label: 'Task request' },
});

export const PHASE_META = Object.freeze({
    research: { icon: 'search', label: 'Research', key: '1' },
    plan: { icon: 'list', label: 'Plan', key: '2' },
    implement: { icon: 'code', label: 'Implement', key: '3' },
    review: { icon: 'eye', label: 'Review', key: '4' },
    followup: { icon: 'loop', label: 'Follow-up', key: '5' },
});

/**
 * Status chip: icon, word, and a tinted tone. Meaning never rides on color alone.
 *
 * @param {{ icon: string, label: string, tone: string } | undefined} meta
 * @param {{ prefix?: string, title?: string }} [options]
 */
export function badge(meta, options = {}) {
    if (!meta) {
        return null;
    }
    return h('span', { class: ['badge', `tone-${meta.tone}`], title: options.title }, icon(meta.icon), options.prefix ? `${options.prefix} ${meta.label.toLowerCase()}` : meta.label);
}

/** Plain chip for counts or labels. */
export const chip = (text, tone = 'muted') => h('span', { class: ['badge', `tone-${tone}`], text });

/** Monospace ID; a button when navigation is available. */
export function idChip(id, onNavigate, options = {}) {
    if (!onNavigate) {
        return h('span', { class: 'id-chip', text: id });
    }
    return h('button', { type: 'button', class: ['id-chip', 'is-link', options.className], title: options.title ?? `Go to ${id}`, onclick: (event) => {
        event.stopPropagation();
        onNavigate(id);
    } }, id);
}

/** A button with an icon and a visible or hidden label. */
export function button(label, options = {}) {
    const { iconName, onClick, kind = 'neutral', hideLabel = false, disabled = false, title, attrs = {} } = options;
    return h('button', { type: 'button', class: ['btn', `btn-${kind}`, hideLabel ? 'btn-icon' : null], disabled, title: title ?? (hideLabel ? label : undefined), onclick: onClick, ...attrs }, iconName ? icon(iconName) : null, hideLabel ? sr(label) : h('span', { text: label }));
}

/** Plural helper: "1 item", "2 items". */
export const plural = (count, word, many = `${word}s`) => `${count} ${count === 1 ? word : many}`;
