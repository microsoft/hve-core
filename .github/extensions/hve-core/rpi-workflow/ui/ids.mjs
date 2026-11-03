// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The ID families the canvas links. The inline linker, previews, and the legend all read
 * this one table, so a family the canvas links always has a name and an explanation.
 *
 * Each family has its own hue from Primer's display colors, so its chips share a color.
 *
 * @typedef {{ key: string, hue: string, pattern: string, kind: string, phase: string | null, example: string, description: string }} IdKind
 */

/** @type {ReadonlyArray<IdKind>} */
export const ID_KINDS = Object.freeze([
    { key: 'Q', hue: 'blue', pattern: 'Q\\d{1,3}', kind: 'Research question', phase: 'research', example: 'Q3', description: 'A question the research set out to answer.' },
    { key: 'F', hue: 'green', pattern: 'F\\d{1,3}', kind: 'Finding', phase: 'research', example: 'F2', description: 'What the research found. The canvas numbers findings in the order the file lists them.' },
    { key: 'D', hue: 'indigo', pattern: 'D\\d{1,3}', kind: 'Decision', phase: 'research', example: 'D4', description: 'A choice the research or plan records, with its owner and status. In Plan, D1 means the plan’s own D1.' },
    { key: 'C', hue: 'orange', pattern: 'C\\d{1,3}', kind: 'Code evidence', phase: 'research', example: 'C22', description: 'Evidence from a file in this workspace, cited by path and heading or symbol.' },
    { key: 'W', hue: 'teal', pattern: 'W\\d{1,3}', kind: 'Web evidence', phase: 'research', example: 'W11', description: 'Evidence from a website or document outside the workspace.' },
    { key: 'L', hue: 'gray', pattern: 'L\\d{1,3}', kind: 'Research lane', phase: 'research', example: 'L1', description: 'One line of inquiry the research ran. The canvas numbers lanes.' },
    { key: 'P', hue: 'purple', pattern: 'P\\d{2}', kind: 'Plan phase', phase: 'plan', example: 'P01', description: 'A phase of the plan: a group of tasks with one outcome.' },
    { key: 'T', hue: 'cyan', pattern: 'P\\d{2}-T\\d{2}', kind: 'Plan task', phase: 'plan', example: 'P01-T02', description: 'A task in a plan phase, with its goals and requirements.' },
    { key: 'FR', hue: 'lime', pattern: 'FR-\\d{3}', kind: 'Functional requirement', phase: 'plan', example: 'FR-003', description: 'Something the finished work must do.' },
    { key: 'NFR', hue: 'olive', pattern: 'NFR-\\d{3}', kind: 'Non-functional requirement', phase: 'plan', example: 'NFR-002', description: 'A quality the finished work must have, with a measurable threshold.' },
    { key: 'PC', hue: 'coral', pattern: 'PC-\\d{3}', kind: 'Plan critique finding', phase: 'plan', example: 'PC-004', description: 'A problem the plan critique found, and how the plan answered it.' },
    { key: 'CH', hue: 'yellow', pattern: 'CH-\\d{3}', kind: 'Change', phase: 'implement', example: 'CH-007', description: 'A change the implementation made, from the changes record.' },
    { key: 'DS', hue: 'brown', pattern: 'DS-\\d{3}', kind: 'Discovery', phase: 'implement', example: 'DS-002', description: 'Something learned while implementing, and how it was handled.' },
    { key: 'AL', hue: 'pine', pattern: 'AL-\\d{3}', kind: 'Plan alignment', phase: 'implement', example: 'AL-001', description: 'How completed work lines up with what the plan or its sources asked for.' },
    { key: 'RV', hue: 'red', pattern: 'RV-\\d{3}', kind: 'Review finding', phase: 'review', example: 'RV-005', description: 'A problem or observation the review recorded.' },
    { key: 'RD', hue: 'auburn', pattern: 'RD-\\d{3}', kind: 'Review decision', phase: 'review', example: 'RD-012', description: 'A decision the review recorded, such as accepting work or starting a follow-up.' },
    { key: 'FU', hue: 'pink', pattern: 'FU-\\d{1,3}', kind: 'Follow-up', phase: 'followup', example: 'FU-2', description: 'Work ranked for after this task, and why.' },
    { key: 'FB', hue: 'plum', pattern: 'FB-\\d{3}', kind: 'Your item', phase: null, example: 'FB-003', description: 'Something you added in the canvas: an answer, comment, suggestion, or request.' },
]);

// Longer patterns first, so P01-T02 is never read as P01.
const ALTERNATION = [...ID_KINDS].sort((a, b) => b.example.length - a.example.length).map((entry) => entry.pattern).join('|');

/** Source of a pattern that finds every linked ID in text; build a fresh global RegExp from it. */
export const ID_SOURCE = `\\b(?:${ALTERNATION})\\b`;

const WHOLE = ID_KINDS.map((entry) => ({ entry, re: new RegExp(`^${entry.pattern}$`) }));

/**
 * The family an ID belongs to, or null. A plan decision's internal `plan.D1` is a decision.
 *
 * @param {string} id
 * @returns {IdKind | null}
 */
export function kindOf(id) {
    const bare = String(id ?? '').replace(/^plan\./, '');
    return WHOLE.find(({ re }) => re.test(bare))?.entry ?? null;
}

/** Display order and headings for the legend's ID groups. */
export const LEGEND_GROUPS = Object.freeze([
    { phase: 'research', label: 'Research' },
    { phase: 'plan', label: 'Plan' },
    { phase: 'implement', label: 'Implement' },
    { phase: 'review', label: 'Review' },
    { phase: 'followup', label: 'Follow-up' },
    { phase: null, label: 'Anywhere' },
]);

/** What each link icon means; the legend shows these beside the icons themselves. */
export const LINK_ICONS = Object.freeze([
    { icon: 'go-to', label: 'Goes to the item', description: 'Takes you to the item in the canvas. Back returns you here.' },
    { icon: 'file', label: 'Opens it here', description: 'Opens the item or file in place, without leaving where you are.' },
    { icon: 'globe', label: 'Opens a website', description: 'Opens the page in your browser.' },
    { icon: 'file-code', label: 'Opens your editor', description: 'Opens the file in VS Code at the cited line.' },
]);
