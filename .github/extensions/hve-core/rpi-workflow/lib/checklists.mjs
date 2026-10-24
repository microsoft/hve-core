// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The person's review checklist for each phase. Shared by the sample session and by
 * sessions read from RPI artifacts; items start unchecked.
 */
export const CHECKLISTS = Object.freeze({
    research: Object.freeze([
        { id: 'R1', label: 'I understand the bottom line' },
        { id: 'R2', label: 'The evidence behind each finding is convincing' },
        { id: 'R3', label: 'The alternatives cover what I would consider' },
        { id: 'R4', label: 'The decisions match my intent' },
        { id: 'R5', label: 'The open risks are acceptable' },
        { id: 'R6', label: 'Research is ready for planning' },
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
        { id: 'I3', label: 'Discoveries are handled' },
        { id: 'I4', label: 'Validation results look right' },
    ]),
    review: Object.freeze([
        { id: 'V1', label: 'Each finding has a fair severity' },
        { id: 'V2', label: 'The routes make sense' },
        { id: 'V3', label: 'Nothing important is missing' },
        { id: 'V4', label: 'Ready for follow-up' },
    ]),
    followup: Object.freeze([
        { id: 'U1', label: 'The selected follow-up is the right next step' },
        { id: 'U2', label: 'The optional items can wait' },
    ]),
});

/**
 * A fresh copy of a phase checklist with the listed items checked.
 *
 * @param {keyof typeof CHECKLISTS} phase
 * @param {string[]} [checkedIds]
 */
export function checklistFor(phase, checkedIds = []) {
    return CHECKLISTS[phase].map((item) => ({ ...item, checked: checkedIds.includes(item.id) }));
}
