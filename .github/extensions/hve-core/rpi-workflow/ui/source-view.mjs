// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { button, h, icon, sr } from './dom.mjs';
import { highlightLines, languageOf } from './highlight.mjs';
import { externalLink, renderInline, shortUrl } from './markdown.mjs';

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

/** A folder path whose lines break only after its slashes. */
function folderText(folder) {
    const parts = folder.split('/');
    return parts.flatMap((part, index) => (index < parts.length - 1 ? [`${part}/`, h('wbr')] : part ? [part] : []));
}

/**
 * One cited location as a file entry: the file name, which shows the file here, and the
 * editor button on one line, then its folder and the cited heading or symbol. A location
 * that is not a readable file shows the same entry as text, with the reason.
 *
 * @param {any} ctx
 * @param {{ path: string, anchor: string | null, status?: string }} location
 */
export function sourceChip(ctx, location) {
    const slash = location.path.lastIndexOf('/');
    const name = location.path.slice(slash + 1) || location.path;
    const folder = slash > 0 ? location.path.slice(0, slash + 1) : '';
    const where = folder || location.anchor
        ? h('span', { class: 'source-where' },
            folder ? h('span', { class: 'source-folder' }, folderText(folder)) : null,
            folder && location.anchor ? h('span', { class: 'source-sep', 'aria-hidden': 'true', text: ' · ' }) : null,
            location.anchor ? h('span', { class: 'source-anchor', text: location.anchor }) : null)
        : null;
    if (location.status && location.status !== 'file') {
        const reason = UNAVAILABLE[location.status] ?? 'not available';
        return h('span', { class: 'source-item is-unavailable' },
            h('span', { class: 'source-head' }, h('code', { class: 'source-file', text: name }), h('span', { class: 'source-note', text: reason })),
            where);
    }
    const spoken = [folder ? `in ${folder}` : null, location.anchor ? `at ${location.anchor}` : null].filter(Boolean).join(', ');
    return h('span', { class: 'source-item', dataset: { path: location.path } },
        h('span', { class: 'source-head' },
            h('button', { type: 'button', class: 'source-chip', title: `Show ${location.path}${location.anchor ? ` at ${location.anchor}` : ''} here`, onclick: () => ctx.act.openSource(location.path, location.anchor) },
                h('code', { class: 'source-file', text: name }), icon('file', { className: 'icon-inline chip-icon' }), sr(`${spoken ? `, ${spoken}` : ''}, shows the file here`)),
            editorButton(ctx, location.path, location.anchor)),
        where);
}

/**
 * Where a piece of evidence came from. Cited workspace files read as file entries. Other
 * sources read as the file wrote them, with each website link labeled by its title or, for
 * a bare address, its host and page, and ending in one globe.
 *
 * @param {any} ctx
 * @param {any} item evidence item
 */
export function evidenceSource(ctx, item) {
    if (item.locations?.length && ctx.data.session.source?.kind === 'rpi') {
        return h('span', { class: 'evidence-source source-list' }, item.locations.map((location) => sourceChip(ctx, location)));
    }
    const text = typeof item.source === 'string' ? item.source.trim() : '';
    // The sample keeps the address apart from the source's name, so the name becomes its link.
    if (item.url && !text.includes(item.url)) {
        return h('span', { class: 'evidence-source' }, externalLink(item.url, text || shortUrl(item.url)));
    }
    if (!text) return null;
    return h('span', { class: 'evidence-source' }, renderInline(text, { resolveId: (id) => Boolean(ctx.resolve(id)), navigate: ctx.act.navigate, shortUrls: true }));
}

const TOKEN_CLASS = new Map();

/**
 * One line's text with its highlighted tokens. It skips `h()`, because a 5,000-line file can
 * hold hundreds of thousands of tokens; every token still goes in as text.
 *
 * @param {{ text: string, type: string | null }[]} tokens
 */
function sourceText(tokens) {
    const body = document.createElement('span');
    body.className = 'source-text';
    for (const token of tokens) {
        if (!token.type) {
            body.appendChild(document.createTextNode(token.text));
            continue;
        }
        let className = TOKEN_CLASS.get(token.type);
        if (!className) TOKEN_CLASS.set(token.type, (className = `tok tok-${token.type}`));
        const span = document.createElement('span');
        span.className = className;
        span.textContent = token.text;
        body.appendChild(span);
    }
    return body;
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
    const language = languageOf(result.path);
    const tokens = highlightLines(result.lines, language, { fromLine: result.start });
    return [
        sheetHead(result.path),
        h('p', { class: 'sheet-meta' }, where, result.lines.length < result.total ? ` Showing lines ${result.start} to ${end} of ${result.total}.` : ''),
        h('div', { class: 'source-view', tabindex: '0', role: 'region', 'aria-label': `${result.path}, read only`, dataset: language ? { language } : undefined },
            result.lines.map((text, index) => {
                const number = result.start + index;
                const cited = number === result.line && Boolean(found);
                return h('div', { class: ['source-line', cited ? 'is-cited' : null], dataset: { line: String(number) } },
                    h('span', { class: 'source-num', 'aria-hidden': 'true', text: String(number) }),
                    cited ? sr('Cited line: ') : null,
                    sourceText(text ? tokens[index] : [{ text: ' ', type: null }]));
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
