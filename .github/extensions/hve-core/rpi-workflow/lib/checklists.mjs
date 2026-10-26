// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The person's review checklist for each phase, shared by the sample session and by
 * sessions read from RPI artifacts. Each item is a statement the person marks Looks good
 * (`ok`) or Needs work (`needs-work`); items start unmarked.
 */
export const CHECKLISTS = Object.freeze({
    research: Object.freeze([
        { id: 'R1', label: 'The bottom line is clear' },
        { id: 'R2', label: "Each finding's evidence is convincing" },
        { id: 'R3', label: 'The alternatives cover what I would consider' },
        { id: 'R4', label: 'The decisions match what I want' },
        { id: 'R5', label: 'The open risks are acceptable' },
        { id: 'R6', label: 'The research is ready for planning' },
    ]),
    plan: Object.freeze([
        { id: 'P1', label: 'The phases deliver the outcome I want' },
        { id: 'P2', label: 'Each task is small enough to review' },
        { id: 'P3', label: 'Every requirement has a task' },
        { id: 'P4', label: 'Critique findings are resolved or accepted' },
        { id: 'P5', label: 'The plan is ready to implement' },
    ]),
    implement: Object.freeze([
        { id: 'I1', label: 'The current work matches the plan' },
        { id: 'I2', label: 'Plan updates make sense' },
        { id: 'I3', label: 'Discoveries are handled well' },
        { id: 'I4', label: 'Validation results look right' },
    ]),
    review: Object.freeze([
        { id: 'V1', label: 'Each finding has a fair severity' },
        { id: 'V2', label: "Each finding's route makes sense" },
        { id: 'V3', label: 'Nothing important is missing' },
        { id: 'V4', label: 'The work is ready for follow-up' },
    ]),
    followup: Object.freeze([
        { id: 'U1', label: 'The selected follow-up is the right next step' },
        { id: 'U2', label: 'The optional items can wait' },
    ]),
});

export const VERDICTS = Object.freeze(['ok', 'needs-work']);

/**
 * An item's verdict, or null when unmarked. Items saved before verdicts existed read
 * `checked` as Looks good.
 *
 * @param {any} item
 * @returns {'ok' | 'needs-work' | null}
 */
export function verdictOf(item) {
    if (item?.verdict === 'ok' || item?.verdict === 'needs-work') return item.verdict;
    return item?.checked === true ? 'ok' : null;
}

/**
 * A fresh copy of a phase checklist. An array lists items that look good; an object maps
 * item IDs to verdicts.
 *
 * @param {keyof typeof CHECKLISTS} phase
 * @param {string[] | Record<string, 'ok' | 'needs-work'>} [marks]
 */
export function checklistFor(phase, marks = []) {
    const verdicts = Array.isArray(marks) ? Object.fromEntries(marks.map((id) => [id, 'ok'])) : marks;
    return CHECKLISTS[phase].map((item) => (verdicts[item.id] ? { ...item, verdict: verdicts[item.id] } : { ...item }));
}
