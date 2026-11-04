// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Decides when ID previews open, lock, nest, and close, without touching the page. The page
 * reports pointer, focus, and key events; this module keeps the stack of open previews and
 * calls `onChange` whenever it changes. Timers are injected so tests control the clock.
 */

/** Milliseconds: show after hover or keyboard focus, hide after leaving, lock after hovering. */
export const TIMING = Object.freeze({ showHover: 500, showFocus: 300, hide: 300, lock: 1000 });

/** At most this many previews open at once, counting the first. */
export const MAX_DEPTH = 5;

/**
 * @typedef {{ id: string, trigger: any, parent: number, locked: boolean, arming: boolean }} Preview
 * `parent` is the index of the preview holding the trigger, or -1 for the page.
 */

/**
 * @param {{ onChange: (stack: ReadonlyArray<Preview>) => void, setTimer?: (fn: () => void, ms: number) => any, clearTimer?: (handle: any) => void, timing?: typeof TIMING }} options
 */
export function createPreviewState(options) {
    const { onChange, setTimer = setTimeout, clearTimer = clearTimeout, timing = TIMING } = options;
    /** @type {Preview[]} */
    let stack = [];
    let pending = null;
    const hideTimers = new Map();
    let lockTimer = null;

    const emit = () => onChange(stack.map((entry) => ({ ...entry })));
    const indexOf = (trigger) => stack.findIndex((entry) => entry.trigger === trigger);
    const canNestFrom = (parent) => parent === -1 || (Boolean(stack[parent]?.locked) && parent + 1 < MAX_DEPTH);

    function cancelPending() {
        if (pending) clearTimer(pending.timer);
        pending = null;
    }

    function cancelHide(index) {
        const timer = hideTimers.get(index);
        if (timer !== undefined) clearTimer(timer);
        hideTimers.delete(index);
    }

    function stopArming() {
        if (lockTimer) clearTimer(lockTimer);
        lockTimer = null;
        let changed = false;
        for (const entry of stack) {
            if (entry.arming) {
                entry.arming = false;
                changed = true;
            }
        }
        return changed;
    }

    /** Drops previews above `index`, keeping it and its ancestors. */
    function truncate(index) {
        for (const key of [...hideTimers.keys()]) {
            if (key > index) cancelHide(key);
        }
        if (stack.length > index + 1) {
            stack = stack.slice(0, index + 1);
            if (!stack.some((entry) => entry.arming)) stopArming();
            return true;
        }
        return false;
    }

    function arm(index) {
        const entry = stack[index];
        if (!entry || entry.locked) return;
        stopArming();
        entry.arming = true;
        lockTimer = setTimer(() => {
            lockTimer = null;
            const current = stack[index];
            if (current === entry) {
                current.arming = false;
                current.locked = true;
                emit();
            }
        }, timing.lock);
    }

    function open(trigger, id, parent, via) {
        cancelPending();
        truncate(parent);
        stack.push({ id, trigger, parent, locked: false, arming: false });
        if (via === 'pointer') arm(stack.length - 1);
        emit();
        return stack.length - 1;
    }

    function scheduleHide(index) {
        const entry = stack[index];
        if (!entry || entry.locked || hideTimers.has(index)) return;
        hideTimers.set(index, setTimer(() => {
            hideTimers.delete(index);
            if (stack[index] === entry && !entry.locked) {
                truncate(index - 1);
                emit();
            }
        }, timing.hide));
    }

    return {
        /** The open previews, oldest first. */
        get stack() {
            return stack.map((entry) => ({ ...entry }));
        },

        /**
         * The pointer or keyboard focus reached an ID. Opens its preview after the delay,
         * unless it sits in a preview that is not locked yet.
         *
         * @param {any} trigger
         * @param {{ id: string, parent: number, via: 'pointer' | 'focus' }} details
         */
        enter(trigger, { id, parent, via }) {
            const existing = indexOf(trigger);
            if (existing !== -1) {
                cancelHide(existing);
                for (let index = stack[existing].parent; index >= 0; index = stack[index].parent) cancelHide(index);
                if (via === 'pointer' && !stack[existing].locked && !stack[existing].arming) {
                    arm(existing);
                    emit();
                }
                return;
            }
            if (!canNestFrom(parent)) return;
            for (let index = parent; index >= 0; index = stack[index].parent) cancelHide(index);
            if (pending?.trigger === trigger) return;
            cancelPending();
            pending = { trigger, timer: setTimer(() => open(trigger, id, parent, via), via === 'focus' ? timing.showFocus : timing.showHover) };
        },

        /** The pointer or focus left an ID; its unlocked preview hides unless the pointer reaches it. */
        leave(trigger) {
            if (pending?.trigger === trigger) cancelPending();
            const index = indexOf(trigger);
            if (index === -1 || stack[index].locked) return;
            if (stopArming()) emit();
            scheduleHide(index);
        },

        /** The pointer entered the preview at `index`; it and its ancestors stay open. */
        enterPreview(index) {
            for (let current = index; current >= 0; current = stack[current]?.parent ?? -1) cancelHide(current);
            const entry = stack[index];
            if (entry && !entry.locked && !entry.arming) {
                arm(index);
                emit();
            }
        },

        /** The pointer left the preview at `index`. */
        leavePreview(index) {
            const entry = stack[index];
            if (!entry || entry.locked) return;
            if (stopArming()) emit();
            scheduleHide(index);
        },

        /**
         * Locks the trigger's preview now, opening it first when needed, as a middle click or
         * Down Arrow does. Returns the preview's index, or -1 when nesting is not allowed.
         *
         * @param {any} trigger
         * @param {{ id: string, parent: number }} details
         */
        lock(trigger, { id, parent }) {
            let index = indexOf(trigger);
            if (index === -1) {
                if (!canNestFrom(parent)) return -1;
                index = open(trigger, id, parent, 'focus');
            }
            const entry = stack[index];
            cancelHide(index);
            if (entry.arming) stopArming();
            entry.locked = true;
            truncate(index);
            emit();
            return index;
        },

        /** Closes the newest preview and returns it, or null when none is open. */
        escape() {
            cancelPending();
            if (!stack.length) return null;
            const closed = stack[stack.length - 1];
            truncate(stack.length - 2);
            emit();
            return { ...closed };
        },

        /** Closes the preview at `index` and everything opened from it. */
        close(index) {
            cancelPending();
            if (index < 0 || index >= stack.length) return;
            truncate(index - 1);
            emit();
        },

        /** Closes every preview, as an outside click or a navigation does. */
        closeAll() {
            cancelPending();
            stopArming();
            if (truncate(-1)) emit();
        },
    };
}
