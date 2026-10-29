// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createPreviewState, MAX_DEPTH, TIMING } from '../ui/preview-state.mjs';

/** A controllable clock: timers run only when the test advances time. */
function fakeClock() {
    let now = 0;
    let next = 1;
    const timers = new Map();
    return {
        setTimer: (fn, ms) => {
            const id = next++;
            timers.set(id, { fn, at: now + ms });
            return id;
        },
        clearTimer: (id) => timers.delete(id),
        advance(ms) {
            const end = now + ms;
            for (;;) {
                const due = [...timers].filter(([, timer]) => timer.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
                if (!due) break;
                timers.delete(due[0]);
                now = due[1].at;
                due[1].fn();
            }
            now = end;
        },
    };
}

function setup() {
    const clock = fakeClock();
    const changes = [];
    const previews = createPreviewState({ onChange: (stack) => changes.push(stack), setTimer: clock.setTimer, clearTimer: clock.clearTimer });
    const ids = () => previews.stack.map((entry) => `${entry.id}${entry.locked ? '*' : ''}`);
    return { clock, previews, changes, ids };
}

describe('preview timing', () => {
    it('opens nothing when the pointer leaves before the delay', () => {
        const { clock, previews, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover - 1);
        previews.leave('c22');
        clock.advance(TIMING.showHover);
        assert.deepEqual(ids(), []);
    });

    it('opens after the hover delay, sooner for keyboard focus', () => {
        const { clock, previews, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover);
        assert.deepEqual(ids(), ['C22']);
        previews.closeAll();
        previews.enter('q1', { id: 'Q1', parent: -1, via: 'focus' });
        clock.advance(TIMING.showFocus);
        assert.deepEqual(ids(), ['Q1']);
    });

    it('stays open while the pointer crosses onto the preview, and hides once it leaves both', () => {
        const { clock, previews, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover);
        previews.leave('c22');
        clock.advance(TIMING.hide - 1);
        previews.enterPreview(0);
        clock.advance(TIMING.hide);
        assert.deepEqual(ids().map((id) => id.replaceAll('*', '')), ['C22']);
        previews.closeAll();
        previews.enter('w11', { id: 'W11', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover);
        previews.leave('w11');
        clock.advance(TIMING.hide);
        assert.deepEqual(ids(), []);
    });
});

describe('locking', () => {
    it('locks after a second of hovering, showing the ring while it arms', () => {
        const { clock, previews, changes, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover);
        assert.equal(previews.stack[0].arming, true);
        clock.advance(TIMING.lock - 1);
        assert.deepEqual(ids(), ['C22']);
        clock.advance(1);
        assert.deepEqual(ids(), ['C22*']);
        assert.equal(changes.at(-1)[0].arming, false);
    });

    it('resets the ring when the pointer leaves, and a locked preview never hides on its own', () => {
        const { clock, previews, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover + TIMING.lock / 2);
        previews.leave('c22');
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.lock / 2);
        assert.deepEqual(ids(), ['C22'], 'the ring restarted');
        clock.advance(TIMING.lock / 2);
        assert.deepEqual(ids(), ['C22*']);
        previews.leave('c22');
        clock.advance(TIMING.hide * 10);
        assert.deepEqual(ids(), ['C22*']);
    });

    it('locks at once on a middle click or Down Arrow, opening the preview when needed', () => {
        const { previews, ids } = setup();
        assert.equal(previews.lock('f1', { id: 'F1', parent: -1 }), 0);
        assert.deepEqual(ids(), ['F1*']);
    });

    it('does not arm a preview opened by keyboard focus', () => {
        const { clock, previews, ids } = setup();
        previews.enter('q1', { id: 'Q1', parent: -1, via: 'focus' });
        clock.advance(TIMING.showFocus + TIMING.lock * 2);
        assert.deepEqual(ids(), ['Q1']);
    });
});

describe('nesting', () => {
    it('nests only from a locked preview', () => {
        const { clock, previews, ids } = setup();
        previews.enter('c22', { id: 'C22', parent: -1, via: 'pointer' });
        clock.advance(TIMING.showHover);
        previews.enter('in-c22-w11', { id: 'W11', parent: 0, via: 'pointer' });
        clock.advance(TIMING.showHover);
        assert.deepEqual(ids(), ['C22'], 'unlocked: no nesting');
        clock.advance(TIMING.lock);
        previews.enter('in-c22-w11', { id: 'W11', parent: 0, via: 'pointer' });
        clock.advance(TIMING.showHover);
        assert.deepEqual(ids(), ['C22*', 'W11']);
    });

    it('replaces a sibling preview and keeps the locked parent', () => {
        const { clock, previews, ids } = setup();
        previews.lock('c22', { id: 'C22', parent: -1 });
        previews.enter('a', { id: 'W11', parent: 0, via: 'pointer' });
        clock.advance(TIMING.showHover);
        previews.leave('a');
        previews.enter('b', { id: 'F2', parent: 0, via: 'pointer' });
        clock.advance(TIMING.showHover);
        assert.deepEqual(ids(), ['C22*', 'F2']);
    });

    it(`stops at ${MAX_DEPTH} previews`, () => {
        const { previews, ids } = setup();
        for (let depth = 0; depth < MAX_DEPTH + 2; depth += 1) previews.lock(`t${depth}`, { id: `C${depth + 1}`, parent: depth - 1 });
        assert.equal(ids().length, MAX_DEPTH);
    });

    it('hides an unlocked nested preview when the pointer goes back to its parent', () => {
        const { clock, previews, ids } = setup();
        previews.lock('c22', { id: 'C22', parent: -1 });
        previews.enter('w', { id: 'W11', parent: 0, via: 'pointer' });
        clock.advance(TIMING.showHover);
        previews.leave('w');
        previews.enterPreview(0);
        clock.advance(TIMING.hide);
        assert.deepEqual(ids(), ['C22*']);
    });
});

describe('closing', () => {
    it('closes the newest preview first with Escape and reports it', () => {
        const { previews, ids } = setup();
        previews.lock('c22', { id: 'C22', parent: -1 });
        previews.lock('w', { id: 'W11', parent: 0 });
        assert.equal(previews.escape().id, 'W11');
        assert.deepEqual(ids(), ['C22*']);
        assert.equal(previews.escape().trigger, 'c22');
        assert.equal(previews.escape(), null);
    });

    it('closes everything on an outside click or navigation, and a pending preview never opens', () => {
        const { clock, previews, ids } = setup();
        previews.lock('c22', { id: 'C22', parent: -1 });
        previews.enter('w', { id: 'W11', parent: 0, via: 'pointer' });
        previews.closeAll();
        clock.advance(TIMING.showHover * 4);
        assert.deepEqual(ids(), []);
    });

    it('closes one preview and those opened from it with its close button', () => {
        const { previews, ids } = setup();
        previews.lock('c22', { id: 'C22', parent: -1 });
        previews.lock('w', { id: 'W11', parent: 0 });
        previews.lock('f', { id: 'F2', parent: 1 });
        previews.close(1);
        assert.deepEqual(ids(), ['C22*']);
    });
});
