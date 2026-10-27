// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h, icon, sr } from './dom.mjs';
import { ID_KINDS, LEGEND_GROUPS, LINK_ICONS } from './ids.mjs';

const section = (id, title, ...content) => h('section', { class: 'legend-section', 'aria-labelledby': id }, h('h3', { id, text: title }), ...content);

/**
 * The legend dialog's content: every ID family by phase from the ID table, what each link
 * icon means, and how previews and history work.
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
        section('legend-ids', 'IDs', h('p', { class: 'meta', text: 'RPI files number what they record. The canvas links these IDs wherever they appear.' }), ...groups),
        section('legend-icons', 'What a click does',
            h('dl', { class: 'legend-list legend-icons' }, LINK_ICONS.flatMap((entry) => [
                h('dt', null, h('span', { class: 'legend-icon' }, icon(entry.icon))),
                h('dd', null, h('strong', { text: entry.label }), ` ${entry.description}`),
            ]))),
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
