// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { kindOf } from './ids.mjs';

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
    // An ID chip carries its family, which sets its color, however it was built.
    if (element.classList?.contains('id-chip') && !element.dataset.kind) {
        const kind = kindOf(String(element.textContent ?? '').trim());
        if (kind) element.dataset.kind = kind.key;
    }
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

/** The main landmark on screen: the document, or the Not connected screen while it shows. */
export function shownMain() {
    return [...document.querySelectorAll('main')].find((element) => !element.closest('[hidden]')) ?? null;
}

// Times read in the reader's language and time zone, through the browser's own formatters.
const RELATIVE = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });
const SHORT_DATE = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' });
const FULL_TIME = new Intl.DateTimeFormat(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZoneName: 'short' });

/** The full date and time in the reader's language and time zone, or null for a missing time. */
export function fullTime(iso) {
    const then = Date.parse(iso ?? '');
    return Number.isNaN(then) ? null : FULL_TIME.format(then);
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
    const seconds = Math.round((then - now) / 1000);
    const size = Math.abs(seconds);
    if (size < 45) return RELATIVE.format(0, 'second');
    if (size < 45 * 60) return RELATIVE.format(Math.round(seconds / 60), 'minute');
    if (size < 22 * 3600) return RELATIVE.format(Math.round(seconds / 3600), 'hour');
    if (size < 6 * 86400) return RELATIVE.format(Math.round(seconds / 86400), 'day');
    return SHORT_DATE.format(then);
}

/** Relative time with the full local date and time as a title, or null when no valid time was recorded. */
export function timeEl(iso, now) {
    if (!iso || Number.isNaN(Date.parse(iso))) {
        return null;
    }
    return h('time', { datetime: iso, title: fullTime(iso), class: 'time', text: relTime(iso, now) });
}

/**
 * The decision a bare `D#` names while a phase is viewed: a decision of that phase whose
 * artifact ID matches, such as the plan's D1 while viewing Plan, else the ID itself.
 *
 * @param {any} session
 * @param {string} id
 * @param {string | null | undefined} phase
 */
export function decisionAlias(session, id, phase) {
    if (typeof id !== 'string' || !/^D\d{1,3}$/.test(id) || !phase) {
        return id;
    }
    const local = session?.decisions?.find((decision) => decision.ref === id && decision.phase === phase);
    return local ? local.id : id;
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
    ['todo', 'circle', 'Backlog', 'muted'],
    ['paused', 'pause', 'Paused for you', 'attention'],
    ['blocked', 'alert', 'Blocked', 'danger'],
]);

export const FEEDBACK_STATE = vocab([
    ['draft', 'pencil', 'Draft', 'muted'],
    ['queued', 'inbox', 'Not sent', 'accent'],
    ['sent', 'send', 'Sent', 'accent'],
    ['interpreted', 'sparkle', 'Read back', 'agent'],
    ['applied', 'check', 'Read back', 'success'],
    ['corrected', 'undo', 'Corrected', 'attention'],
    ['dismissed', 'x', 'Removed', 'muted'],
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

/** Risk and open question priority, as the research and plan files write it: H, M, or L. */
export const PRIORITY = vocab([
    ['H', 'priority-high', 'High', 'danger'],
    ['M', 'priority-medium', 'Medium', 'attention'],
    ['L', 'priority-low', 'Low', 'accent'],
]);

const capitalize = (word) => word.charAt(0).toUpperCase() + word.slice(1);

/**
 * Confidence as signal bars: three for high, two for medium, one for low, none when it is
 * not recorded. The label keeps the file's own word, such as "Medium-high".
 *
 * @param {unknown} value
 * @returns {{ icon: string, label: string, tone: string }}
 */
export function confidenceMeta(value) {
    const word = String(value ?? '').trim();
    const key = word.toLowerCase();
    if (!word || /^(not recorded|not applicable|n\/a|none|unknown)$/.test(key)) return { icon: 'signal-0', label: 'Not recorded', tone: 'muted' };
    const label = capitalize(word);
    if (/^(very high|high)\b/.test(key)) return { icon: 'signal-3', label, tone: 'success' };
    if (/^(medium-low|low)\b/.test(key)) return { icon: 'signal-1', label, tone: 'severe' };
    if (/^(medium-high|medium|med|moderate)\b/.test(key)) return { icon: 'signal-2', label, tone: 'attention' };
    return { icon: 'signal-0', label, tone: 'muted' };
}

/**
 * The kind of a risk table row: risk, open question, further research, and the other words
 * files use, each with its own icon and color. The label keeps the file's word.
 *
 * @param {unknown} value
 * @returns {{ icon: string, label: string, tone: string } | null}
 */
export function riskTypeMeta(value) {
    const word = String(value ?? '').trim();
    if (!word) return null;
    const key = word.toLowerCase();
    const label = capitalize(word);
    if (/question/.test(key)) return { icon: 'question', label, tone: 'accent' };
    if (/research|investigat/.test(key)) return { icon: 'search', label, tone: 'teal' };
    if (/^risks?\b/.test(key)) return { icon: 'alert', label, tone: 'severe' };
    if (/assum/.test(key)) return { icon: 'bulb', label, tone: 'attention' };
    if (/depend/.test(key)) return { icon: 'branch', label, tone: 'muted' };
    if (/issue|blocker|problem|defect/.test(key)) return { icon: 'x-circle', label, tone: 'danger' };
    return { icon: 'info', label, tone: 'muted' };
}

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
    edit: { icon: 'pencil', label: 'Suggested edit' },
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
 * The vocabulary entry for a key, a neutral entry that names an unrecognized key, or null
 * when no key was recorded.
 *
 * @param {Record<string, { icon: string, label: string, tone: string }>} vocabulary
 * @param {unknown} key
 */
export function known(vocabulary, key) {
    if (key === undefined || key === null || key === '') {
        return null;
    }
    return Object.prototype.hasOwnProperty.call(vocabulary, key) ? vocabulary[key] : { icon: 'info', label: String(key), tone: 'muted' };
}

/**
 * Status chip: icon, word, and a tinted tone. Meaning never rides on color alone. `strong`
 * adds a colored border and a deeper tint, for levels and kinds such as priority.
 *
 * @param {{ icon: string, label: string, tone: string } | undefined | null} meta
 * @param {{ prefix?: string, title?: string, strong?: boolean }} [options]
 */
export function badge(meta, options = {}) {
    if (!meta) {
        return null;
    }
    return h('span', { class: ['badge', `tone-${meta.tone}`, options.strong ? 'is-strong' : null], title: options.title }, icon(meta.icon), options.prefix ? `${options.prefix} ${meta.label.toLowerCase()}` : meta.label);
}

/** Plain chip for counts or labels. */
export const chip = (text, tone = 'muted') => h('span', { class: ['badge', `tone-${tone}`], text });

/**
 * Monospace ID; a button when navigation is available. A navigating chip ends with the
 * go-to icon and carries `data-preview`, so hovering or focusing it shows the item.
 *
 * @param {string} id the ID navigation goes to
 * @param {((id: string) => void) | null} onNavigate
 * @param {{ className?: string, label?: string }} [options] `label` replaces the visible ID, such as an artifact's own `D1` for `plan.D1`.
 */
export function idChip(id, onNavigate, options = {}) {
    const label = options.label ?? id;
    if (!onNavigate) {
        return h('span', { class: 'id-chip', text: label });
    }
    return h('button', { type: 'button', class: ['id-chip', 'is-link', options.className], dataset: { preview: id }, onclick: (event) => {
        event.stopPropagation();
        onNavigate(id);
    } }, label, icon('go-to', { className: 'icon-inline chip-icon' }));
}

/**
 * A static ID label inside a larger control, ending with the icon for what that control does:
 * `go-to` when it navigates, `file` when it opens in place.
 *
 * @param {string} label
 * @param {'go-to' | 'file'} iconName
 */
export function idTag(label, iconName) {
    return h('span', { class: 'id-chip' }, label, icon(iconName, { className: 'icon-inline chip-icon' }));
}

/** A button with an icon and a visible or hidden label. */
export function button(label, options = {}) {
    const { iconName, onClick, kind = 'neutral', hideLabel = false, disabled = false, title, attrs = {} } = options;
    return h('button', { type: 'button', class: ['btn', `btn-${kind}`, hideLabel ? 'btn-icon' : null], disabled, title: title ?? (hideLabel ? label : undefined), onclick: onClick, ...attrs }, iconName ? icon(iconName) : null, hideLabel ? sr(label) : h('span', { text: label }));
}

/** Plural helper: "1 item", "2 items". */
export const plural = (count, word, many = `${word}s`) => `${count} ${count === 1 ? word : many}`;
