// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h, icon } from './dom.mjs';
import { kindOf } from './ids.mjs';

/**
 * Comments on a part of a row: the table row, list item, paragraph, heading, quote, or code
 * block the pointer is over. One floating button follows the hovered part, and the canvas
 * menu offers the same anchor, so both name the part the same way.
 *
 * @typedef {{ block: Element, rowId: string, rowTitle: string, part: string, quote: string, label: string }} Anchor
 */

/** Places in a row that are controls or annotations, not the document's own text. */
const EXCLUDED = '.row-head, .row-margin, .composer, .editor, .decision, .btn-row, .voice, .suggestion, .lanes-card, .trace, .evidence-chips, .chip-row, .anchor-chip, .notice, form, button, .preview, dialog, .steer';
/** Containers of the document's own text. */
const CONTENT = '.prose, .data-table, .md-table, .question-list';
const QUOTE_MAX = 200;

/** An element's text with whitespace collapsed, cut at a word near `max`. */
export function quoteOf(element, max = QUOTE_MAX) {
    const text = String(element?.textContent ?? '').replace(/\s+/g, ' ').trim();
    if (text.length <= max) return text;
    const cut = text.lastIndexOf(' ', max - 1);
    return `${text.slice(0, cut > max / 2 ? cut : max - 1)}…`;
}

/** The 1-based position of `block` among the matches of `selector` in `scope`. */
function positionOf(scope, selector, block) {
    return [...scope.querySelectorAll(selector)].indexOf(block) + 1;
}

/**
 * The commentable part of a row at an element, or null when the element is not in a row's
 * text or is part of a control.
 *
 * @param {Element | null} element
 * @returns {Anchor | null}
 */
export function anchorAt(element) {
    const text = element?.closest?.('.row-text');
    if (!text || element.closest(EXCLUDED)) return null;
    const row = text.closest('[data-row]');
    if (!row?.dataset.row) return null;
    const block = element.closest('tbody tr') ?? element.closest('li') ?? element.closest('p, h3, h4, h5, h6, blockquote, pre');
    if (!block || !text.contains(block) || !block.closest(CONTENT) || block.closest(EXCLUDED)) return null;
    // A part is named by its ID only when the files use that ID, such as C12 or Q3.
    const found = block.dataset?.item ?? block.querySelector?.('[data-item]')?.dataset.item ?? null;
    const itemId = found && kindOf(found) ? found : null;
    const tag = block.localName;
    let part;
    if (tag === 'tr') {
        part = itemId ? `table row ${itemId}` : `table row ${positionOf(block.closest('tbody'), 'tr', block)}`;
    } else if (tag === 'li') {
        part = itemId ? `list item ${itemId}` : `list item ${positionOf(text, 'li', block)}`;
    } else if (/^h[3-6]$/.test(tag)) {
        part = `heading "${quoteOf(block, 60)}"`;
    } else if (tag === 'blockquote') {
        part = `quote ${positionOf(text, 'blockquote', block)}`;
    } else if (tag === 'pre') {
        part = `code block ${positionOf(text, 'pre', block)}`;
    } else {
        part = `paragraph ${positionOf(text, 'p:not(li p):not(td p):not(blockquote p)', block)}`;
    }
    const rowTitle = row.querySelector('.row-title')?.textContent?.trim() ?? row.dataset.row;
    return { block, rowId: row.dataset.row, rowTitle, part, quote: quoteOf(block), label: part };
}

/**
 * Shows a comment button beside the part of a row under the pointer.
 *
 * @param {{ scroller: HTMLElement, onComment: (anchor: Anchor) => void }} deps
 *   `scroller` is the positioned element that scrolls the document.
 */
export function installAnchorHandle(deps) {
    const { scroller } = deps;
    const label = h('span', { class: 'visually-hidden' });
    const handle = h('button', { type: 'button', class: 'anchor-handle', hidden: true, tabindex: '-1' }, icon('message'), label);
    scroller.appendChild(handle);
    /** @type {Anchor | null} */
    let current = null;
    let hideTimer = 0;
    let frame = 0;
    let pending = null;

    function mark(next) {
        current?.block.classList.remove('is-anchor-target');
        current = next;
    }

    function show(anchor) {
        window.clearTimeout(hideTimer);
        if (current?.block === anchor.block && !handle.hidden) return;
        mark(anchor);
        const text = anchor.block.closest('.row-text');
        const box = scroller.getBoundingClientRect();
        const block = anchor.block.getBoundingClientRect();
        const column = (text ?? anchor.block).getBoundingClientRect();
        const lineTop = anchor.block.localName === 'tr' ? block.top + 8 : block.top;
        handle.style.left = `${Math.max(2, column.left - box.left + scroller.scrollLeft - 30)}px`;
        handle.style.top = `${lineTop - box.top + scroller.scrollTop}px`;
        const name = `Comment on ${anchor.part}`;
        label.textContent = `${name} of ${anchor.rowTitle}`;
        handle.setAttribute('data-tip', name);
        handle.hidden = false;
    }

    function hide() {
        window.clearTimeout(hideTimer);
        handle.hidden = true;
        mark(null);
    }

    function hideSoon() {
        window.clearTimeout(hideTimer);
        hideTimer = window.setTimeout(hide, 300);
    }

    scroller.addEventListener('pointermove', (event) => {
        if (event.pointerType === 'touch' || handle.contains(event.target)) return;
        pending = event.target;
        if (frame) return;
        frame = window.requestAnimationFrame(() => {
            frame = 0;
            const anchor = anchorAt(pending);
            if (anchor) show(anchor);
            else if (!handle.hidden) hideSoon();
        });
    });
    scroller.addEventListener('pointerleave', hideSoon);
    handle.addEventListener('pointerenter', () => {
        window.clearTimeout(hideTimer);
        current?.block.classList.add('is-anchor-target');
    });
    handle.addEventListener('pointerleave', () => {
        current?.block.classList.remove('is-anchor-target');
        hideSoon();
    });
    handle.addEventListener('click', () => {
        const anchor = current;
        hide();
        if (anchor?.block.isConnected) deps.onComment(anchor);
    });

    return {
        /** Hides the button, as a re-render that replaces the hovered part does. */
        hide,
    };
}
