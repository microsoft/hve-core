// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h, icon, shownMain } from './dom.mjs';

/**
 * The canvas's own right-click menu. A right-click anywhere but a text field opens it at the
 * pointer; Shift with a right-click, or a text field, keeps the host's menu. Shift+F10 and
 * the Menu key open it for the focused element. Keys follow the menu pattern: Up and Down,
 * Home and End, Enter and Space, Escape and Tab.
 *
 * @typedef {{ label: string, icon?: string, onSelect?: () => void, disabled?: boolean, separatorBefore?: boolean, shortcut?: string }} MenuItem
 */

const MARGIN = 8;
const EDITABLE = 'input, textarea, select, [contenteditable="true"]';
const supportsPopover = () => typeof HTMLElement !== 'undefined' && Object.prototype.hasOwnProperty.call(HTMLElement.prototype, 'popover');

/**
 * @param {{ itemsFor: (target: Element) => MenuItem[], onOpen?: () => void }} deps
 */
export function installContextMenu(deps) {
    const menu = h('div', { class: 'ctx-menu', id: 'ctxMenu', role: 'menu', 'aria-label': 'Canvas actions', tabindex: '-1' });
    if (supportsPopover()) menu.setAttribute('popover', 'manual');
    let returnTo = null;
    let openedByKey = 0;

    const entries = () => [...menu.querySelectorAll('[role="menuitem"]:not([aria-disabled="true"])')];

    function close(restore) {
        if (!menu.isConnected) return;
        if (menu.hidePopover && menu.matches(':popover-open')) menu.hidePopover();
        menu.remove();
        const target = returnTo;
        returnTo = null;
        if (restore && target?.isConnected) target.focus({ preventScroll: true });
    }

    function build(items) {
        const children = [];
        items.forEach((item, index) => {
            if (item.separatorBefore && index > 0) children.push(h('div', { class: 'ctx-sep', role: 'separator' }));
            const entry = h('button', {
                type: 'button', class: 'ctx-item', role: 'menuitem', tabindex: '-1',
                'aria-disabled': item.disabled ? 'true' : undefined,
                'aria-keyshortcuts': item.shortcut || undefined,
            }, item.icon ? icon(item.icon, { className: 'ctx-icon' }) : h('span', { class: 'ctx-icon' }), h('span', { class: 'ctx-label', text: item.label }), item.shortcut ? h('kbd', { class: 'ctx-key', text: item.shortcut }) : null);
            entry.addEventListener('click', () => {
                if (item.disabled) return;
                close(false);
                item.onSelect?.();
            });
            children.push(entry);
        });
        menu.replaceChildren(...children);
    }

    function place(x, y) {
        const width = menu.offsetWidth;
        const height = menu.offsetHeight;
        const left = x + width + MARGIN > window.innerWidth ? Math.max(MARGIN, x - width) : x;
        const top = y + height + MARGIN > window.innerHeight ? Math.max(MARGIN, y - height) : y;
        menu.style.left = `${Math.round(left)}px`;
        menu.style.top = `${Math.round(top)}px`;
    }

    function open(target, x, y) {
        const items = deps.itemsFor(target);
        if (!items.length) return;
        close(false);
        deps.onOpen?.();
        returnTo = document.activeElement instanceof HTMLElement && document.activeElement !== document.body ? document.activeElement : target.closest?.('button, a[href], [tabindex]');
        build(items);
        // The menu lives in the main landmark on screen, or in the open dialog it serves; the top layer places it.
        (target.closest?.('dialog[open]') ?? shownMain() ?? document.body).appendChild(menu);
        if (menu.showPopover) menu.showPopover();
        place(x, y);
        (entries()[0] ?? menu).focus({ preventScroll: true });
    }

    function openForFocus() {
        const focused = document.activeElement instanceof Element && document.activeElement !== document.body ? document.activeElement : shownMain();
        const rect = focused?.getBoundingClientRect?.() ?? { left: MARGIN, bottom: MARGIN };
        open(focused, rect.left + 4, rect.bottom + 2);
    }

    document.addEventListener('contextmenu', (event) => {
        if (event.shiftKey || !(event.target instanceof Element)) return;
        if (menu.contains(event.target)) {
            event.preventDefault();
            return;
        }
        if (event.target.closest(EDITABLE)) return;
        event.preventDefault();
        // The Menu key and Shift+F10 also fire this event, aimed at the focused element.
        const fromKeyboard = event.pointerType === '' || (event.pointerType === undefined && event.clientX === 0 && event.clientY === 0);
        if (fromKeyboard) {
            if (Date.now() - openedByKey >= 400) openForFocus();
            return;
        }
        open(event.target, event.clientX, event.clientY);
    });

    document.addEventListener('keydown', (event) => {
        if (menu.isConnected && menu.contains(event.target)) {
            const list = entries();
            const index = list.indexOf(event.target);
            const move = (to) => list[(to + list.length) % list.length]?.focus();
            if (event.key === 'ArrowDown') move(index + 1);
            else if (event.key === 'ArrowUp') move(index < 0 ? list.length - 1 : index - 1);
            else if (event.key === 'Home') move(0);
            else if (event.key === 'End') move(list.length - 1);
            else if (event.key === 'Escape') close(true);
            else if (event.key === 'Tab') close(true);
            else if (event.key === ' ' || event.key === 'Enter') event.target.click();
            else return;
            event.preventDefault();
            event.stopPropagation();
            return;
        }
        const menuKey = event.key === 'ContextMenu' || (event.key === 'F10' && event.shiftKey && !event.ctrlKey && !event.metaKey && !event.altKey);
        if (!menuKey || (event.target instanceof Element && event.target.closest(EDITABLE))) return;
        event.preventDefault();
        openedByKey = Date.now();
        openForFocus();
    }, true);

    document.addEventListener('pointerdown', (event) => {
        if (menu.isConnected && !menu.contains(event.target)) close(false);
    }, true);
    document.addEventListener('wheel', (event) => {
        if (menu.isConnected && !menu.contains(event.target)) close(false);
    }, { capture: true, passive: true });
    window.addEventListener('resize', () => close(false));
    window.addEventListener('blur', () => close(false));

    return {
        close: () => close(false),
        get open() {
            return menu.isConnected;
        },
    };
}
