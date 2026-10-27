// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { button, h, icon, sr } from './dom.mjs';
import { externalLink } from './markdown.mjs';

/** Why a cited location has no source view, in words. */
const UNAVAILABLE = Object.freeze({
    missing: 'not a file in this workspace',
    outside: 'outside the workspace',
    hidden: 'not shown by the canvas',
    folder: 'a folder',
});

const MATCH_WORDS = Object.freeze({ heading: 'heading', fragment: 'linked heading', definition: 'definition', text: 'first mention' });

/** The editor that opens files from this canvas, or null. */
const editorOf = (ctx) => ctx.data.editor ?? null;

/** VS Code opens these as a workspace window, so the canvas only shows them. */
const OPENS_AS_WORKSPACE = /\.code-workspace$/i;

/**
 * An icon button that opens a workspace file in the editor at a cited place, or null when no
 * editor is available.
 *
 * @param {any} ctx
 * @param {string} path
 * @param {string | null} [anchor]
 * @param {string} [key] stable `data-key` for focus restoration
 */
export function editorButton(ctx, path, anchor, key) {
    const editor = editorOf(ctx);
    if (!editor || ctx.data.session.source?.kind !== 'rpi' || OPENS_AS_WORKSPACE.test(path)) return null;
    return h('button', { type: 'button', class: 'icon-btn source-editor', title: `Open in ${editor.name}`, dataset: key ? { key } : undefined, onclick: () => ctx.act.openInEditor(path, anchor ?? null) },
        icon('file-code'), sr(`Open ${path} in ${editor.name}`));
}

/**
 * One cited location: a chip that shows the file here at the cited place, and the editor
 * button when one is available. A location that is not a readable file shows as text with
 * the reason.
 *
 * @param {any} ctx
 * @param {{ path: string, anchor: string | null, status?: string }} location
 */
export function sourceChip(ctx, location) {
    const label = [h('code', { text: location.path }), location.anchor ? h('span', { class: 'source-anchor', text: location.anchor }) : null];
    if (location.status && location.status !== 'file') {
        const reason = UNAVAILABLE[location.status] ?? 'not available';
        return h('span', { class: 'source-chip is-unavailable' }, label, h('span', { class: 'source-note', text: reason }));
    }
    return h('span', { class: 'source-item' },
        h('button', { type: 'button', class: 'source-chip', onclick: () => ctx.act.openSource(location.path, location.anchor) },
            label, icon('file', { className: 'icon-inline chip-icon' }), sr(', shows the file here')),
        editorButton(ctx, location.path, location.anchor));
}

/**
 * Where a piece of evidence came from: its website, its cited locations in a real session,
 * or the source text as written.
 *
 * @param {any} ctx
 * @param {any} item evidence item
 */
export function evidenceSource(ctx, item) {
    if (item.url) return h('span', { class: 'evidence-source' }, icon('globe', { className: 'source-kind' }), externalLink(item.url, item.source || item.url));
    if (item.locations?.length && ctx.data.session.source?.kind === 'rpi') {
        return h('span', { class: 'evidence-source source-list' }, item.locations.map((location) => sourceChip(ctx, location)));
    }
    return item.source ? h('code', { class: 'evidence-source', text: item.source }) : null;
}

const sheetHead = (path) => h('div', { class: 'dialog-head' },
    h('h2', { id: 'fileSheetTitle', class: 'sheet-title' }, icon('file'), h('code', { text: path })),
    h('button', { type: 'button', class: 'icon-btn', 'data-close': '' }, icon('x'), sr('Close')));

/**
 * The source sheet: the file's lines with numbers, the cited line highlighted, and Open in
 * the editor and Copy path.
 *
 * @param {any} ctx
 * @param {{ path: string, start: number, lines: string[], total: number, line: number, match: string, anchor: string | null }} result
 */
export function sourceSheet(ctx, result) {
    const found = MATCH_WORDS[result.match];
    const where = result.anchor
        ? found ? `Line ${result.line}, the ${found} for ${result.anchor}.` : `${result.anchor} was not found, so this shows the top of the file.`
        : `From line ${result.line}.`;
    const end = result.start + result.lines.length - 1;
    const editor = editorOf(ctx);
    return [
        sheetHead(result.path),
        h('p', { class: 'sheet-meta' }, where, result.lines.length < result.total ? ` Showing lines ${result.start} to ${end} of ${result.total}.` : ''),
        h('div', { class: 'source-view', tabindex: '0', role: 'region', 'aria-label': `${result.path}, read only` },
            result.lines.map((text, index) => {
                const number = result.start + index;
                const cited = number === result.line && Boolean(found);
                return h('div', { class: ['source-line', cited ? 'is-cited' : null], dataset: { line: String(number) } },
                    h('span', { class: 'source-num', 'aria-hidden': 'true', text: String(number) }),
                    cited ? sr('Cited line: ') : null,
                    h('span', { class: 'source-text', text: text || ' ' }));
            })),
        h('div', { class: 'btn-row' },
            editor && !OPENS_AS_WORKSPACE.test(result.path) ? button(`Open in ${editor.name}`, { iconName: 'file-code', onClick: () => ctx.act.openInEditor(result.path, result.anchor) }) : null,
            button('Copy path', { iconName: 'copy', title: `Copies ${result.path}:${result.line}`, onClick: () => ctx.act.copy(`${result.path}:${result.line}`) })),
    ];
}

/**
 * The source sheet when the file cannot be shown: the reason in plain words and Copy path.
 *
 * @param {any} ctx
 * @param {string} path
 * @param {string} message
 */
export function sourceProblem(ctx, path, message) {
    return [
        sheetHead(path),
        h('p', { class: 'notice tone-attention', role: 'status' }, icon('alert'), message),
        h('div', { class: 'btn-row' }, button('Copy path', { iconName: 'copy', onClick: () => ctx.act.copy(path) })),
    ];
}
