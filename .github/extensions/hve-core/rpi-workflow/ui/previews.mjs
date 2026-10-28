// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { button, h, icon, sr } from './dom.mjs';
import { previewContent } from './preview-content.mjs';
import { createPreviewState, TIMING } from './preview-state.mjs';

const SVG_NS = 'http://www.w3.org/2000/svg';
const GAP = 6;
const MARGIN = 8;
const supportsPopover = () => typeof HTMLElement !== 'undefined' && Object.prototype.hasOwnProperty.call(HTMLElement.prototype, 'popover');

/** The ring that fills while a hovered preview arms, before it locks. */
function lockRing() {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'preview-ring');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('aria-hidden', 'true');
    for (const name of ['ring-track', 'ring-fill']) {
        const circle = document.createElementNS(SVG_NS, 'circle');
        circle.setAttribute('class', name);
        circle.setAttribute('cx', '8');
        circle.setAttribute('cy', '8');
        circle.setAttribute('r', '6');
        svg.appendChild(circle);
    }
    return svg;
}

/**
 * Wires ID previews into the page. Hovering or focusing any element with `data-preview`
 * shows the item, and the preview model decides when previews lock, nest, and close. A
 * preview whose trigger sits in the document or its outline, or in a preview opened from
 * there, reads the context of the shown document, which may be an earlier one.
 *
 * @param {{ context: (inDocument: boolean) => any, revision: () => number }} deps
 */
export function installPreviews(deps) {
    /** @type {{ trigger: Element, element: HTMLElement, revision: number }[]} */
    let shown = [];
    let serial = 0;
    const model = createPreviewState({ onChange: render });

    const triggerOf = (node) => node?.closest?.('[data-preview]') ?? null;
    const previewOf = (node) => node?.closest?.('.preview') ?? null;
    const indexOfPreview = (element) => shown.findIndex((entry) => entry.element === element);
    const parentOf = (trigger) => {
        const host = previewOf(trigger);
        return host ? indexOfPreview(host) : -1;
    };
    /** True when a trigger reads the shown document: it sits in the document or outline, or in a preview opened from there. */
    const inDocument = (trigger) => {
        const host = previewOf(trigger);
        if (!host) return Boolean(trigger.closest?.('#docBody, #navBody'));
        const parent = shown[indexOfPreview(host)];
        return parent ? inDocument(parent.trigger) : false;
    };
    const contextFor = (trigger) => deps.context(inDocument(trigger));
    const known = (trigger) => Boolean(trigger.dataset.preview && contextFor(trigger).find(trigger.dataset.preview));

    function setInteractive(element, interactive) {
        for (const control of element.querySelectorAll('button, a[href], input, select, textarea')) {
            if (interactive) control.removeAttribute('tabindex');
            else control.setAttribute('tabindex', '-1');
        }
    }

    function build(entry, index) {
        const id = `rw-preview-${serial += 1}`;
        const titleId = `${id}-title`;
        const content = previewContent(contextFor(entry.trigger), entry.id, { titleId });
        const element = h('div', { class: 'preview', id, dataset: { previewId: entry.id } });
        if (supportsPopover()) element.setAttribute('popover', 'manual');
        element.style.setProperty('--rw-lock-ms', `${TIMING.lock}ms`);
        const state = h('span', { class: 'preview-state' }, lockRing(), icon('pin', { className: 'preview-pin' }), sr('Locked'));
        const close = button('Close preview', { iconName: 'x', hideLabel: true, attrs: { class: 'icon-btn preview-close' }, onClick: () => {
            model.close(indexOfPreview(element));
            restoreFocus(entry.trigger, true);
        } });
        if (content) {
            content.head.append(state, close);
            element.append(content.head, ...content.body);
        } else {
            element.append(h('p', { class: 'meta', id: titleId, text: `${entry.id} is not in this task.` }));
        }
        element.dataset.titleId = titleId;
        element.addEventListener('pointerenter', () => model.enterPreview(indexOfPreview(element)));
        element.addEventListener('pointerleave', (event) => {
            if (!previewOf(event.relatedTarget)) model.leavePreview(indexOfPreview(element));
        });
        const host = entry.trigger.closest('dialog[open]') ?? document.body;
        host.appendChild(element);
        if (element.showPopover) element.showPopover();
        return { trigger: entry.trigger, element, revision: deps.revision() };
    }

    /** Places a preview below its ID, or above it, inside the viewport. */
    function place(element, trigger) {
        if (!trigger.isConnected) return;
        const rect = trigger.getBoundingClientRect();
        const width = element.offsetWidth;
        const height = element.offsetHeight;
        let top = rect.bottom + GAP;
        if (top + height > window.innerHeight - MARGIN && rect.top - GAP - height >= MARGIN) top = rect.top - GAP - height;
        top = Math.max(MARGIN, Math.min(top, window.innerHeight - MARGIN - height));
        const left = Math.max(MARGIN, Math.min(rect.left, window.innerWidth - MARGIN - width));
        element.style.top = `${Math.round(top)}px`;
        element.style.left = `${Math.round(left)}px`;
    }

    function remove(entry) {
        if (entry.trigger.getAttribute('aria-describedby') === entry.element.id) entry.trigger.removeAttribute('aria-describedby');
        if (entry.element.hidePopover && entry.element.matches(':popover-open')) entry.element.hidePopover();
        entry.element.remove();
    }

    function render(stack) {
        const next = [];
        stack.forEach((entry, index) => {
            const existing = shown[index];
            if (existing && existing.trigger === entry.trigger) {
                next.push(existing);
            } else {
                if (existing) remove(existing);
                next.push(build(entry, index));
            }
        });
        for (const extra of shown.slice(stack.length)) {
            if (!next.includes(extra)) remove(extra);
        }
        shown = next;
        stack.forEach((entry, index) => {
            const { element, trigger } = shown[index];
            const fresh = !element.classList.contains('is-placed');
            element.classList.toggle('is-locked', entry.locked);
            element.classList.toggle('is-arming', entry.arming);
            if (entry.locked) {
                element.setAttribute('role', 'dialog');
                element.setAttribute('aria-modal', 'false');
                element.setAttribute('aria-labelledby', element.dataset.titleId);
                if (trigger.getAttribute('aria-describedby') === element.id) trigger.removeAttribute('aria-describedby');
            } else {
                element.setAttribute('role', 'tooltip');
                element.removeAttribute('aria-modal');
                element.removeAttribute('aria-labelledby');
                if (trigger.isConnected) trigger.setAttribute('aria-describedby', element.id);
            }
            setInteractive(element, entry.locked);
            if (fresh) {
                place(element, trigger);
                element.classList.add('is-placed');
            }
        });
    }

    /** Moves focus out of a closed preview, back to its ID when it is still on the page. */
    function restoreFocus(trigger, hadFocus) {
        if (!hadFocus) return;
        if (trigger?.isConnected) trigger.focus({ preventScroll: true });
        else document.getElementById('document')?.focus({ preventScroll: true });
    }

    function lockFromKeyboard(trigger) {
        const index = model.lock(trigger, { id: trigger.dataset.preview, parent: parentOf(trigger) });
        if (index === -1) return false;
        shown[index]?.element.querySelector('.preview-go, button, a[href]')?.focus({ preventScroll: true });
        return true;
    }

    document.addEventListener('pointerover', (event) => {
        if (event.pointerType === 'touch') return;
        const trigger = triggerOf(event.target);
        if (trigger && known(trigger)) model.enter(trigger, { id: trigger.dataset.preview, parent: parentOf(trigger), via: 'pointer' });
    });

    document.addEventListener('pointerout', (event) => {
        const trigger = triggerOf(event.target);
        if (trigger && !trigger.contains(event.relatedTarget)) model.leave(trigger);
    });

    document.addEventListener('focusin', (event) => {
        const trigger = triggerOf(event.target);
        if (trigger && trigger === event.target && known(trigger) && trigger.matches(':focus-visible')) {
            model.enter(trigger, { id: trigger.dataset.preview, parent: parentOf(trigger), via: 'focus' });
        }
    });

    document.addEventListener('focusout', (event) => {
        const trigger = triggerOf(event.target);
        if (!trigger || trigger !== event.target) return;
        const index = shown.findIndex((entry) => entry.trigger === trigger);
        if (index !== -1 && shown[index].element.contains(event.relatedTarget)) return;
        model.leave(trigger);
    });

    // A middle click locks at once; preventing the default stops autoscroll.
    document.addEventListener('mousedown', (event) => {
        if (event.button !== 1) return;
        const trigger = triggerOf(event.target);
        if (!trigger || !known(trigger)) return;
        event.preventDefault();
        model.lock(trigger, { id: trigger.dataset.preview, parent: parentOf(trigger) });
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !event.isComposing && model.stack.length) {
            const top = shown.at(-1);
            const hadFocus = Boolean(top?.element.contains(document.activeElement));
            const closed = model.escape();
            event.preventDefault();
            event.stopPropagation();
            restoreFocus(closed?.trigger, hadFocus);
            return;
        }
        if (event.key === 'ArrowDown' && !event.altKey && !event.ctrlKey && !event.metaKey) {
            const trigger = triggerOf(document.activeElement);
            if (trigger && trigger === document.activeElement && known(trigger) && lockFromKeyboard(trigger)) event.preventDefault();
        }
    }, true);

    // A click outside every preview closes them all.
    document.addEventListener('click', (event) => {
        if (!model.stack.length || previewOf(event.target)) return;
        model.closeAll();
    }, true);

    // Scrolling the page would leave unlocked previews behind their IDs; locked ones stay put.
    // Re-renders restore scroll positions, so only the reader's own wheel counts.
    document.addEventListener('wheel', (event) => {
        if (!model.stack.length || previewOf(event.target)) return;
        const firstUnlocked = model.stack.findIndex((entry) => !entry.locked);
        if (firstUnlocked !== -1) model.close(firstUnlocked);
    }, { capture: true, passive: true });

    const hasFocus = (index) => Boolean(shown[index]?.element.contains(document.activeElement));

    return {
        /** Closes every preview, as a navigation does. */
        closeAll() {
            const hadFocus = shown.some((entry) => entry.element.contains(document.activeElement));
            model.closeAll();
            if (hadFocus) document.getElementById('document')?.focus({ preventScroll: true });
        },

        /**
         * Keeps open previews current after the page re-renders: an unlocked preview whose ID
         * left the page closes, and previews rebuild when the data changed and focus is
         * elsewhere.
         */
        refresh() {
            const stack = model.stack;
            const gone = stack.findIndex((entry, index) => !entry.locked && !shown[index]?.trigger.isConnected);
            if (gone !== -1) model.close(gone);
            const revision = deps.revision();
            shown.forEach((entry, index) => {
                if (entry.revision === revision || hasFocus(index)) return;
                const titleId = entry.element.dataset.titleId;
                const content = previewContent(contextFor(entry.trigger), entry.element.dataset.previewId, { titleId });
                if (!content) return;
                const keep = entry.element.querySelector('.preview-state');
                const close = entry.element.querySelector('.preview-close');
                content.head.append(keep, close);
                entry.element.replaceChildren(content.head, ...content.body);
                setInteractive(entry.element, Boolean(model.stack[index]?.locked));
                entry.revision = revision;
            });
        },
    };
}
