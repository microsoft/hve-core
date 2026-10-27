// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * One back and forward history of places across phases and tasks, as browsers and editors
 * keep. Pure: the page reports each move with the place it leaves and the place it goes to,
 * and asks where Back and Forward lead.
 *
 * @typedef {{ taskId: string, taskTitle: string, phase: string, id: string | null, label?: string, scroll: number }} Place
 * `label` is how the place reads in a button, such as D1 for `plan.D1` or a section title.
 */

/** The history keeps at most this many places in each direction. */
export const MAX_PLACES = 50;

/** Two places are the same when they show the same item, or the same phase top, of a task. */
export const samePlace = (a, b) => Boolean(a && b && a.taskId === b.taskId && a.phase === b.phase && (a.id ?? null) === (b.id ?? null));

export function createHistory() {
    /** @type {Place[]} */
    let back = [];
    /** @type {Place[]} */
    let forward = [];
    const push = (list, place) => (samePlace(list.at(-1), place) ? list : [...list, place].slice(-MAX_PLACES));

    return {
        /**
         * Records a move from one place to another. Moving to where you already are records
         * nothing; any real move clears Forward.
         *
         * @param {Place} from
         * @param {Place} to
         */
        move(from, to) {
            if (!from || samePlace(from, to)) return;
            back = push(back, from);
            forward = [];
        },

        /** The place Back leads to, now left behind for Forward, or null. */
        back(current) {
            const target = back.at(-1);
            if (!target) return null;
            back = back.slice(0, -1);
            forward = push(forward, current);
            return target;
        },

        /** The place Forward leads to, now left behind for Back, or null. */
        forward(current) {
            const target = forward.at(-1);
            if (!target) return null;
            forward = forward.slice(0, -1);
            back = push(back, current);
            return target;
        },

        /** Forgets a place that no longer exists, such as a task whose files are gone. */
        drop(place) {
            back = back.filter((entry) => !samePlace(entry, place));
            forward = forward.filter((entry) => !samePlace(entry, place));
        },

        /** Where Back and Forward lead next, without moving. */
        peek() {
            return { back: back.at(-1) ?? null, forward: forward.at(-1) ?? null };
        },

        /** Sizes, for tests and diagnostics. */
        get sizes() {
            return { back: back.length, forward: forward.length };
        },
    };
}

/**
 * Names where a history button leads: "Back to F1 in Research", adding "of" and the task
 * title when the place is in another task.
 *
 * @param {'back' | 'forward'} direction
 * @param {Place} place
 * @param {string} currentTaskId
 * @param {(phase: string) => string} phaseLabel
 */
export function placeLabel(direction, place, currentTaskId, phaseLabel) {
    const where = place.id ? `${place.label ?? place.id} in ${phaseLabel(place.phase)}` : phaseLabel(place.phase);
    const task = place.taskId !== currentTaskId ? ` of ${place.taskTitle}` : '';
    return `${direction === 'back' ? 'Back' : 'Forward'} to ${where}${task}`;
}
