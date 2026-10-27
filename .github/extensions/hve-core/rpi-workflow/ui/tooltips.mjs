// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h } from './dom.mjs';

/**
 * The canvas's own tooltips. Hosts such as VS Code's canvas view do not show `title`
 * tooltips, so the canvas draws them: after a short hover, at once on keyboard focus, and
 * held open while the pointer is over the tooltip. Escape, a click, or scrolling hides it.
 * The first time an element is hovered or focused, its `title` moves into `data-tip`, so a
 * host that does show titles never shows two.
 */

export const TIP_TIMING = Object.freeze({ show: 500, warm: 300, hide: 150 });
const GAP = 6;
const MARGIN = 8;
const supportsPopover = () => typeof HTMLElement !== 'undefined' && Object.prototype.hasOwnProperty.call(HTMLElement.prototype, 'popover');

/** The tooltip text for an element, taking over its `title` the first time. */
export function tipText(element) {
    if (element.hasAttribute('title')) {
        const title = element.getAttribute('title').trim();
        element.removeAttribute('title');
        if (title) {
            element.setAttribute('data-tip', title);
            // The title described the element; keep that for screen readers when it says more than the name.
            const name = (element.getAttribute('aria-label') ?? element.textContent ?? '').replace(/\s+/g, ' ').trim();
            if (title !== name && !element.hasAttribute('aria-description')) element.setAttribute('aria-description', title);
        }
    }
    const text = element.getAttribute('data-tip')?.trim();
    if (!text) return '';
    const keys = element.getAttribute('aria-keyshortcuts');
    return keys && !text.includes(`(${keys})`) ? `${text} (${keys})` : text;
}

export function installTooltips() {
    const tip = h('div', { class: 'tooltip', id: 'rwTip', role: 'tooltip' });
    if (supportsPopover()) tip.setAttribute('popover', 'manual');
    let trigger = null;
    let showTimer = 0;
    let hideTimer = 0;
    let hiddenAt = 0;

    const targetOf = (node) => {
        const element = node instanceof Element ? node.closest('[title], [data-tip]') : null;
        // IDs show their previews instead.
        return element && !element.closest('[data-preview]') ? element : null;
    };

    function place() {
        const rect = trigger.getBoundingClientRect();
        const width = tip.offsetWidth;
        const height = tip.offsetHeight;
        let top = rect.bottom + GAP;
        if (top + height > window.innerHeight - MARGIN) top = rect.top - GAP - height;
        top = Math.max(MARGIN, Math.min(top, window.innerHeight - MARGIN - height));
        const left = Math.max(MARGIN, Math.min(rect.left + rect.width / 2 - width / 2, window.innerWidth - MARGIN - width));
        tip.style.top = `${Math.round(top)}px`;
        tip.style.left = `${Math.round(left)}px`;
    }

    function show(element) {
        window.clearTimeout(showTimer);
        window.clearTimeout(hideTimer);
        const text = element.isConnected ? tipText(element) : '';
        if (!text) {
            hide();
            return;
        }
        trigger = element;
        tip.textContent = text;
        // The tooltip lives in the main landmark, or in the open dialog it serves; the top layer places it.
        const host = element.closest('dialog[open]') ?? document.getElementById('document') ?? document.body;
        if (tip.parentElement !== host) host.appendChild(tip);
        if (tip.showPopover && !tip.matches(':popover-open')) tip.showPopover();
        tip.hidden = false;
        place();
    }

    function hide() {
        window.clearTimeout(showTimer);
        window.clearTimeout(hideTimer);
        if (trigger) hiddenAt = Date.now();
        trigger = null;
        if (tip.hidePopover && tip.matches(':popover-open')) tip.hidePopover();
        tip.hidden = true;
    }

    function hideSoon() {
        window.clearTimeout(hideTimer);
        hideTimer = window.setTimeout(hide, TIP_TIMING.hide);
    }

    document.addEventListener('pointerover', (event) => {
        if (event.pointerType === 'touch' || tip.contains(event.target)) return;
        const element = targetOf(event.target);
        if (!element) return;
        if (element === trigger) {
            window.clearTimeout(hideTimer);
            return;
        }
        window.clearTimeout(showTimer);
        // Moving from one tooltip to the next shows the next one at once.
        const warm = trigger !== null || Date.now() - hiddenAt < TIP_TIMING.warm;
        if (warm) show(element);
        else showTimer = window.setTimeout(() => show(element), TIP_TIMING.show);
    });

    document.addEventListener('pointerout', (event) => {
        const element = targetOf(event.target);
        if (!element) return;
        if (element !== trigger) {
            if (!element.contains(event.relatedTarget)) window.clearTimeout(showTimer);
            return;
        }
        if (!element.contains(event.relatedTarget) && !tip.contains(event.relatedTarget)) hideSoon();
    });

    tip.addEventListener('pointerenter', () => window.clearTimeout(hideTimer));
    tip.addEventListener('pointerleave', (event) => {
        if (!trigger?.contains(event.relatedTarget)) hideSoon();
    });

    document.addEventListener('focusin', (event) => {
        const element = targetOf(event.target);
        if (element && element === event.target && element.matches(':focus-visible')) show(element);
        else if (trigger) hide();
    });
    document.addEventListener('focusout', (event) => {
        if (trigger && event.target === trigger) hide();
    });
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && trigger) hide();
    }, true);
    document.addEventListener('pointerdown', hide, true);
    document.addEventListener('wheel', () => {
        if (trigger) hide();
    }, { capture: true, passive: true });

    return {
        hide,
        /** Hides the tooltip when the page re-rendered its trigger away. */
        refresh() {
            if (trigger && !trigger.isConnected) hide();
        },
    };
}
