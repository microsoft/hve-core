// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h, svg } from './dom.mjs';
import { EDGE_FIT, edgeLabels, fitLabel, mapText, partWords, routePath, shownIn } from './map.mjs';

/**
 * Draws one view of a laid-out change map as native SVG, adapted from the RPI Workflow canvas's
 * renderer. Every part keeps the place the shared layout gave it, so switching views only shows or
 * hides parts. Each change has a border, a corner glyph, and words: dashed with a plus for new,
 * thick with a delta for changed, dotted and struck through with a minus for removed. Parts are
 * buttons: hover or focus shows a preview after a short delay, and a click, Enter, or Space pins it.
 */

const VIEW_WORDS = Object.freeze({ changes: 'Changes', before: 'Before', after: 'After' });
const GLYPH = Object.freeze({ new: '+', changed: '\u0394', removed: '\u2212' });
const NODE_LINE = 17;
const FRAME_PAD = 12;
const TITLE_LINE = 15;
/** Preview delays in milliseconds, matching the RPI Workflow canvas's `TIMING`. */
const TIMING = Object.freeze({ showHover: 500, showFocus: 300, hide: 300 });
/** Closes the newest map's open preview; set by `attachPreviews` for each render. */
let closeActive = null;

/**
 * Closes the open map preview, returning focus to its part only when focus was inside the preview.
 * The page calls this first on Escape, wherever focus is.
 *
 * @returns {boolean} whether a preview was open
 */
export function closeMapPreview() {
    return closeActive?.() ?? false;
}

/** One drawn line of runs; styled runs become `tspan` elements, and label markup never becomes markup. */
function textLine(runs, attrs) {
    const text = svg('text', attrs);
    if (runs.length === 1 && !runs[0].bold && !runs[0].italic && !runs[0].code) {
        text.textContent = runs[0].text;
        return text;
    }
    for (const run of runs) {
        const span = svg('tspan', { class: ['diagram-run', run.bold ? 'is-bold' : '', run.italic ? 'is-italic' : '', run.code ? 'is-code' : ''].filter(Boolean).join(' ') });
        span.textContent = run.text;
        text.append(span);
    }
    return text;
}

/** The path of a rectangle with rounded corners, for shapes the part `rect` rules must not style. */
const roundedRect = (x, y, width, height, r) => `M${x + r} ${y}H${x + width - r}A${r} ${r} 0 0 1 ${x + width} ${y + r}V${y + height - r}A${r} ${r} 0 0 1 ${x + width - r} ${y + height}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + height - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;

/** A hover title holding a label the drawing had to cut. */
function fullLabel(text) {
    const title = svg('title');
    title.textContent = text;
    return title;
}

/** Legend entries for the marks a view draws, each a swatch and its words. */
export function mapLegend(model, view) {
    const shown = model.parts.filter((part) => shownIn(view, part));
    const has = (change) => shown.some((part) => part.change === change);
    const links = model.links.filter((link) => shownIn(view, link, 'links'));
    const entries = [];
    if (has('new')) entries.push(['is-new', 'Dashed border and +: new.']);
    if (has('changed')) entries.push(['is-changed', 'Thick border and \u0394: changed.']);
    if (has('removed')) entries.push(['is-removed', 'Dotted border, struck through, and \u2212: removed.']);
    if (view === 'changes' && has('unchanged')) entries.push(['is-unchanged', 'Muted: unchanged.']);
    const words = [];
    if (links.some((link) => link.kind === 'checks')) words.push('Dashed arrows: tests and docs.');
    if (links.some((link) => link.change !== 'unchanged')) words.push('+ or \u2212 before an arrow label: a new or removed link.');
    if (links.some((link) => link.uncertainty)) words.push('"Unsure" on an arrow: the agent could not point to evidence for it.');
    return { entries, words };
}

/**
 * @param {{ source: string, title: string, description: string, boxes: any[], parts: any[], links: any[] }} model
 * @param {{ graph: any, laid: any }} layout from `layoutMap`
 * @param {{ view: 'changes' | 'before' | 'after', idPrefix: string, highlight?: Set<string>, pinned?: string | null,
 *   preview: (partId: string) => Node[], onPin: (partId: string | null) => void, textOpen?: boolean, onTextToggle?: (open: boolean) => void,
 *   evidence?: (link: { from: string, to: string, anchor: any }) => Node }} options
 *   `preview` builds a part's preview content; `onPin` records the pinned part so a re-render reopens it;
 *   `evidence` builds the control that goes to a link's evidence in the text version.
 * @returns {HTMLElement}
 */
export function renderMap(model, { graph, laid }, options) {
    const view = options.view;
    const highlight = options.highlight ?? new Set();
    const parts = new Map(model.parts.map((part) => [part.id, part]));
    const shown = new Set(model.parts.filter((part) => shownIn(view, part)).map((part) => part.id));
    const edgeShown = (index) => shownIn(view, model.links[index], 'links') && shown.has(model.links[index].from) && shown.has(model.links[index].to);
    const caption = `${model.title}, ${VIEW_WORDS[view]} view`;
    const pad = 12;
    const titleId = `${options.idPrefix}-title`;
    const descId = `${options.idPrefix}-desc`;
    const linkCount = model.links.filter((_link, index) => edgeShown(index)).length;
    const root = svg('svg', {
        viewBox: `${-pad} ${-pad} ${laid.width + pad * 2} ${laid.height + pad * 2}`, width: laid.width + pad * 2, height: laid.height + pad * 2,
        role: 'group', 'aria-labelledby': titleId, 'aria-describedby': descId, class: `diagram-svg is-${view}`,
    });
    const title = svg('title', { id: titleId });
    title.textContent = `${caption}: ${shown.size} parts and ${linkCount} relationships. A text version follows.`;
    const desc = svg('desc', { id: descId });
    desc.textContent = model.description;
    root.append(title, desc);
    const marker = svg('marker', { id: `${options.idPrefix}-arrow`, viewBox: '0 0 10 10', refX: '9', refY: '5', markerWidth: '7', markerHeight: '7', orient: 'auto-start-reverse' });
    marker.append(svg('path', { d: 'M0 0L10 5L0 10z', class: 'diagram-arrow' }));
    const defs = svg('defs');
    defs.append(marker);
    root.append(defs);

    const holds = (frame) => model.parts.some((part) => shown.has(part.id) && (part.box === frame.id || model.boxes.find((box) => box.id === part.box)?.parent === frame.id));
    const frames = [...laid.frames.values()].filter(holds).sort((a, b) => a.depth - b.depth);
    for (const frame of frames) {
        const group = svg('g', { class: `diagram-box is-depth-${frame.depth}` });
        group.append(svg('rect', { x: frame.x, y: frame.y, width: frame.width, height: frame.height, rx: 8 }));
        root.append(group);
    }
    graph.edges.forEach((edge, index) => {
        if (!edgeShown(index)) return;
        const classes = ['diagram-edge', edge.dashed ? 'is-dashed' : '', edge.change !== 'unchanged' ? `is-${edge.change}` : ''].filter(Boolean).join(' ');
        root.append(svg('path', { d: routePath(laid.routes[index], laid.horizontal), class: classes, 'marker-end': `url(#${options.idPrefix}-arrow)` }));
    });
    const titles = svg('g', { class: 'diagram-box-titles' });
    for (const frame of frames) {
        frame.title.lines.forEach((line, index) => titles.append(textLine(line, { x: frame.x + FRAME_PAD, y: frame.y + FRAME_PAD + 11 + index * TITLE_LINE, class: 'diagram-box-title' })));
    }
    root.append(titles);
    const labels = edgeLabels(graph, laid);
    if (labels.length === graph.edges.length) {
        labels.forEach((label, index) => {
            if (!edgeShown(index)) return;
            const fit = fitLabel(label.text, EDGE_FIT);
            const group = svg('g', { class: `diagram-label is-${graph.edges[index].change}` });
            if (fit.cut) group.append(fullLabel(label.text));
            group.append(svg('rect', { x: label.x - label.width / 2, y: label.y - label.height / 2, width: label.width, height: label.height, rx: 4, class: 'diagram-edge-bg' }));
            fit.lines.forEach((line, row, all) => {
                const text = svg('text', { x: label.x, y: label.y + 4 + (row - (all.length - 1) / 2) * 13, 'text-anchor': 'middle', class: 'diagram-edge-label' });
                text.textContent = line;
                group.append(text);
            });
            root.append(group);
        });
    }
    for (const [id, box] of laid.positions) {
        if (!shown.has(id)) continue;
        const part = parts.get(id);
        const variant = box.variants[view];
        const classes = ['diagram-node', `is-${part.change}`, highlight.has(id) ? 'is-highlight' : '', options.pinned === id ? 'is-pinned' : ''].filter(Boolean).join(' ');
        const group = svg('g', { class: classes, tabindex: '0', role: 'button', 'aria-label': partWords(part), 'aria-expanded': String(options.pinned === id), 'data-part': id, 'data-key': `map-part-${id}` });
        if (variant.cut) group.append(fullLabel(partWords(part)));
        group.append(svg('rect', { x: box.x, y: box.y, width: box.width, height: box.height, rx: 6 }));
        variant.lines.forEach((line, index) => {
            const kind = index >= variant.tagFrom ? 'diagram-tag' : index === 0 ? 'diagram-name' : 'diagram-clause';
            group.append(textLine(line, { x: box.x + box.width / 2, y: box.y + 22 + index * NODE_LINE, 'text-anchor': 'middle', class: kind }));
        });
        if (GLYPH[part.change]) {
            const mark = svg('g', { class: `diagram-glyph is-${part.change}`, 'aria-hidden': 'true' });
            mark.append(svg('circle', { cx: box.x + box.width - 2, cy: box.y + 2, r: 8 }));
            const glyph = svg('text', { x: box.x + box.width - 2, y: box.y + 6, 'text-anchor': 'middle' });
            glyph.textContent = GLYPH[part.change];
            mark.append(glyph);
            group.append(mark);
        }
        // Browsers do not outline an SVG group, so a part draws its own focus ring, 2px wide and 2px out.
        group.append(svg('path', { d: roundedRect(box.x - 3, box.y - 3, box.width + 6, box.height + 6, 9), class: 'diagram-focus' }));
        root.append(group);
    }

    // Scales down to fit its column, then scrolls rather than shrinking text below 80 percent.
    root.style.minWidth = `${Math.round((laid.width + pad * 2) * 0.8)}px`;
    const scroll = h('div', { class: 'diagram-scroll', tabindex: '0', role: 'region', 'aria-label': `${caption}, scrollable`, dataset: { key: `${options.idPrefix}-scroll` } }, root);
    const text = mapText(model, view);
    const legend = mapLegend(model, view);
    const figure = h('figure', { class: 'diagram change-map' },
        scroll,
        h('figcaption', {}, caption),
        legend.entries.length || legend.words.length || highlight.size ? h('p', { class: 'meta legend' },
            legend.entries.map(([swatch, words]) => [h('span', { class: `legend-swatch ${swatch}`, 'aria-hidden': 'true' }), ` ${words} `]),
            highlight.size ? [h('span', { class: 'legend-swatch is-highlight', 'aria-hidden': 'true' }), ' Filled: the selected reason or area. '] : null,
            legend.words.join(' ')) : null,
        h('details', { class: 'diagram-details', open: Boolean(options.textOpen), ontoggle: (event) => options.onTextToggle?.(event.target.open) },
            h('summary', { dataset: { key: `${options.idPrefix}-text` } }, 'Show as text'),
            h('ul', { class: 'diagram-text' },
                text.boxes.map((box) => h('li', {}, `In ${box.label}: ${box.parts.join('; ')}`)),
                text.parts.map((words) => h('li', {}, words)),
                text.links.map((link) => h('li', {}, link.description ? `${link.words}: ${link.description}` : link.words,
                    link.anchor && options.evidence ? [' ', options.evidence(link)] : null)))));
    attachPreviews(scroll, options);
    return figure;
}

/**
 * Part previews: hover or focus shows one as a tooltip, and a click, Enter, or Space pins it as a
 * non-modal dialog whose controls take focus. A tooltip stays open while the pointer is over its part
 * or over the tooltip itself, and Escape anywhere on the page closes it through `closeMapPreview`, so
 * the preview is hoverable and dismissible (WCAG 1.4.13). Timings match the RPI Workflow canvas.
 */
function attachPreviews(scroll, options) {
    const card = h('div', { class: 'map-preview', id: `${options.idPrefix}-preview`, hidden: true });
    scroll.append(card);
    let current = null;
    let pinned = null;
    let showTimer = null;
    let hideTimer = null;
    let quiet = false;
    const partOf = (target) => target?.closest?.('[data-part]') ?? null;
    const place = (part) => {
        const box = part.getBoundingClientRect();
        const frame = scroll.getBoundingClientRect();
        const left = box.left - frame.left + scroll.scrollLeft;
        card.style.left = `${Math.max(4, Math.min(left, scroll.scrollWidth - card.offsetWidth - 4))}px`;
        card.style.top = `${box.bottom - frame.top + scroll.scrollTop + 6}px`;
    };
    const cancelShow = () => {
        clearTimeout(showTimer);
        showTimer = null;
    };
    const cancelHide = () => {
        clearTimeout(hideTimer);
        hideTimer = null;
    };
    const show = (part, pin, { focus = pin } = {}) => {
        cancelShow();
        cancelHide();
        if (current && current !== part) current.removeAttribute('aria-describedby');
        current = part;
        pinned = pin ? part : null;
        card.replaceChildren(...options.preview(part.dataset.part));
        card.setAttribute('role', pin ? 'dialog' : 'tooltip');
        if (pin) card.setAttribute('aria-label', `Details for ${part.getAttribute('aria-label')}`);
        else card.removeAttribute('aria-label');
        card.classList.toggle('is-pinned', pin);
        part.classList.toggle('is-pinned', pin);
        for (const control of card.querySelectorAll('button')) control.tabIndex = pin ? 0 : -1;
        part.setAttribute('aria-describedby', card.id);
        part.setAttribute('aria-expanded', String(pin));
        card.hidden = false;
        place(part);
        if (focus) card.querySelector('button')?.focus();
    };
    const hide = ({ refocus = false } = {}) => {
        cancelShow();
        cancelHide();
        if (!current) return;
        const part = current;
        part.removeAttribute('aria-describedby');
        part.setAttribute('aria-expanded', 'false');
        part.classList.remove('is-pinned');
        card.hidden = true;
        const wasPinned = pinned;
        current = null;
        pinned = null;
        if (wasPinned) options.onPin(null);
        if (refocus) {
            quiet = true;
            part.focus();
            quiet = false;
        }
    };
    /** Shows a part's tooltip after a delay; while another tooltip is open, the new part shows at once. */
    const showSoon = (part, delay) => {
        cancelHide();
        if (current === part) return;
        cancelShow();
        if (current) {
            show(part, false);
            return;
        }
        showTimer = setTimeout(() => {
            showTimer = null;
            if (part.isConnected && !pinned) show(part, false);
        }, delay);
    };
    const hideSoon = () => {
        cancelShow();
        if (!current || pinned || hideTimer) return;
        hideTimer = setTimeout(() => {
            hideTimer = null;
            if (!pinned) hide();
        }, TIMING.hide);
    };
    const toggle = (part) => {
        if (pinned === part) hide({ refocus: true });
        else {
            options.onPin(part.dataset.part);
            show(part, true);
        }
    };
    closeActive = () => {
        if (!card.isConnected) return false;
        const open = Boolean(current);
        if (open) hide({ refocus: card.contains(document.activeElement) });
        else cancelShow();
        return open;
    };
    scroll.addEventListener('pointerover', (event) => {
        if (event.pointerType === 'touch' || pinned) return;
        if (card.contains(event.target)) {
            cancelHide();
            return;
        }
        const part = partOf(event.target);
        if (part) showSoon(part, TIMING.showHover);
    });
    scroll.addEventListener('pointerout', (event) => {
        if (pinned) return;
        const into = event.relatedTarget;
        const fromPart = partOf(event.target);
        if (fromPart && !fromPart.contains(into) && !card.contains(into)) {
            if (current === fromPart) hideSoon();
            else if (!current) cancelShow();
        } else if (card.contains(event.target) && !card.contains(into) && !(current && current.contains(into))) hideSoon();
    });
    scroll.addEventListener('focusin', (event) => {
        const part = partOf(event.target);
        if (part && !pinned && !quiet) showSoon(part, TIMING.showFocus);
    });
    scroll.addEventListener('focusout', (event) => {
        if (pinned && card.contains(event.relatedTarget)) return;
        if (pinned && (card.contains(event.target) || event.target === pinned) && !scroll.contains(event.relatedTarget)) {
            hide();
            return;
        }
        if (!pinned && partOf(event.target) && !card.contains(event.relatedTarget)) {
            if (current) hide();
            else cancelShow();
        }
    });
    scroll.addEventListener('click', (event) => {
        const part = partOf(event.target);
        if (part) toggle(part);
    });
    scroll.addEventListener('keydown', (event) => {
        const part = partOf(event.target);
        if (part && (event.key === 'Enter' || event.key === ' ')) {
            event.preventDefault();
            toggle(part);
        }
    });
    if (options.pinned) {
        // A re-render reopens the pinned preview without taking focus from wherever the reader is.
        requestAnimationFrame(() => {
            const part = [...scroll.querySelectorAll('[data-part]')].find((element) => element.getAttribute('data-part') === options.pinned);
            if (!part) {
                options.onPin(null);
                return;
            }
            show(part, true, { focus: false });
            if (!document.activeElement || document.activeElement === document.body) part.focus({ preventScroll: true });
        });
    }
}
