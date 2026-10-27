// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, confidenceMeta, h, icon, PRIORITY, riskTypeMeta, sr } from './dom.mjs';
import { ID_KINDS, LEGEND_GROUPS, LINK_ICONS } from './ids.mjs';

const section = (id, title, ...content) => h('section', { class: 'legend-section', 'aria-labelledby': id }, h('h3', { id, text: title }), ...content);

/**
 * The legend dialog's content: every ID family by phase from the ID table, in its color, what
 * each link icon and badge means, and how previews, comments, following, and history work.
 */
export function legendContent() {
    const groups = LEGEND_GROUPS.map((group) => {
        const kinds = ID_KINDS.filter((entry) => entry.phase === group.phase);
        return kinds.length ? h('div', { class: 'legend-group' },
            h('h4', { text: group.label }),
            h('dl', { class: 'legend-list' }, kinds.flatMap((entry) => [
                h('dt', null, h('span', { class: 'id-chip', text: entry.example })),
                h('dd', null, h('strong', { text: entry.kind }), ` ${entry.description}`),
            ]))) : null;
    }).filter(Boolean);
    return [
        h('div', { class: 'dialog-head' },
            h('h2', { id: 'legendTitle' }, icon('legend'), 'What the IDs and icons mean'),
            h('button', { type: 'button', class: 'icon-btn', 'data-close': '' }, icon('x'), sr('Close'))),
        section('legend-ids', 'IDs', h('p', { class: 'meta', text: 'RPI files number what they record. The canvas links these IDs wherever they appear, and each kind has its own color; the letters always say which kind it is.' }), ...groups),
        section('legend-icons', 'What a click does',
            h('dl', { class: 'legend-list legend-icons' }, LINK_ICONS.flatMap((entry) => [
                h('dt', null, h('span', { class: 'legend-icon' }, icon(entry.icon))),
                h('dd', null, h('strong', { text: entry.label }), ` ${entry.description}`),
            ]))),
        section('legend-badges', 'Levels and kinds',
            h('dl', { class: 'legend-list' },
                h('dt', null, h('span', { class: 'legend-badges' }, ['high', 'medium', 'low'].map((word) => badge(confidenceMeta(word), { strong: true })))),
                h('dd', null, h('strong', { text: 'Confidence' }), ' Three bars for high, two for medium, one for low.'),
                h('dt', null, h('span', { class: 'legend-badges' }, ['H', 'M', 'L'].map((key) => badge(PRIORITY[key], { strong: true })))),
                h('dd', null, h('strong', { text: 'Priority' }), ' Of a risk or open question.'),
                h('dt', null, h('span', { class: 'legend-badges' }, ['risk', 'open question', 'further research'].map((word) => badge(riskTypeMeta(word), { strong: true })))),
                h('dd', null, h('strong', { text: 'Type' }), ' Of a row in Risks and open questions.'))),
        section('legend-comments', 'Comments and the canvas menu',
            h('ul', { class: 'legend-steps' },
                h('li', { text: 'Hover a paragraph, list item, table row, or heading, and choose the speech bubble beside it to comment on exactly that part.' }),
                h('li', { text: 'Right-click for the canvas menu: comment, suggest an edit, copy, go back or forward. Hold Shift as you right-click for the host\'s own menu, such as VS Code\'s.' }),
                h('li', { text: 'From the keyboard, Shift+F10 opens the canvas menu for the focused item.' }))),
        section('legend-follow', 'Following the agent',
            h('p', { text: 'While the top of the canvas shows Live, the canvas moves to the loop and phase the agent works in. Choosing a phase, loop, or session yourself stops following, and the control shows Follow agent; press it, or f, to catch up.' })),
        section('legend-previews', 'Previews',
            h('ul', { class: 'legend-steps' },
                h('li', { text: 'Hover over an ID, or move focus to it, to see the whole item.' }),
                h('li', { text: 'Keep the pointer on it until the ring fills, or middle-click it, to lock the preview. From the keyboard, press Down Arrow.' }),
                h('li', { text: 'In a locked preview, hover or focus an ID to preview it too.' }),
                h('li', { text: 'Escape closes the newest preview. Clicking an ID goes to it.' }))),
        section('legend-history', 'Back and forward',
            h('p', { text: 'The arrows beside the phase title, or Alt with the left or right arrow key, retrace the places you moved to, across phases and tasks.' })),
    ];
}
