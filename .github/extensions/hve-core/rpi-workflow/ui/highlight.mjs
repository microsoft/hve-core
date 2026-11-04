// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * A small syntax highlighter for the source view. It reads one line at a time, carries block
 * comments, multi-line strings, and Markdown fences across lines, and returns plain tokens:
 * the caller builds DOM from them, so no text is ever parsed as HTML. Each line is scanned
 * once with sticky patterns, and only its first MAX_HIGHLIGHT characters are colored.
 *
 * @typedef {{ text: string, type: string | null }} Token
 */

export const MAX_HIGHLIGHT = 2000;

const words = (text) => new Set(text.split(/\s+/).filter(Boolean));

const JS_KEYWORDS = words(`abstract as async await break case catch class const continue debugger declare default delete do else enum export extends finally for from function get if implements import in infer instanceof interface is keyof let module namespace new of private protected public readonly return satisfies set static super switch this throw try type typeof var void while with yield`);
const CLIKE_KEYWORDS = words(`abstract as async await base bool break byte case catch char class const continue default defer delegate do double else enum event explicit extern final finally fixed float fn for foreach func go goto if impl implements import in int interface internal is let lock long loop match mod move mut namespace new object operator out override package params private protected pub public readonly ref return sealed select short sizeof static string struct super switch this throw trait try type typeof uint ulong unsafe use using var virtual void volatile where while yield`);
const PY_KEYWORDS = words(`and as assert async await break class continue def del elif else except finally for from global if import in is lambda match case nonlocal not or pass raise return try while with yield`);
const PS_KEYWORDS = words(`begin break catch class continue data do dynamicparam else elseif end enum exit filter finally for foreach from function if in param process return switch throw trap try until using while`);
const SH_KEYWORDS = words(`case do done elif else esac export fi for function if in local readonly return select set shift source then time trap unset until while`);
const LITERALS = words(`true false null undefined NaN Infinity nil None True False`);

/** File extensions and the scanner each uses. */
const BY_EXTENSION = Object.freeze({
    js: 'js', mjs: 'js', cjs: 'js', jsx: 'js', ts: 'js', tsx: 'js', mts: 'js', cts: 'js',
    json: 'json', jsonc: 'json',
    md: 'md', mdx: 'md',
    yml: 'yaml', yaml: 'yaml',
    py: 'py',
    ps1: 'ps', psm1: 'ps', psd1: 'ps',
    sh: 'sh', bash: 'sh', zsh: 'sh',
    css: 'css', scss: 'css',
    html: 'html', htm: 'html', xml: 'html', svg: 'html',
    cs: 'clike', rs: 'clike', go: 'clike', java: 'clike', kt: 'clike', swift: 'clike', c: 'clike', h: 'clike', cpp: 'clike', hpp: 'clike',
});

/**
 * The scanner for a workspace path, by extension, or null to show it plain.
 *
 * @param {string} path
 * @returns {string | null}
 */
export function languageOf(path) {
    const name = String(path ?? '').split('/').pop() ?? '';
    const extension = /\.([A-Za-z0-9]{1,10})$/.exec(name)?.[1]?.toLowerCase();
    return (extension && BY_EXTENSION[extension]) || null;
}

/** Settings for the code scanner, by language. */
const CODE = Object.freeze({
    js: { line: ['//'], block: [['/*', '*/']], strings: ['"', "'", '`'], multiline: ['`'], keywords: JS_KEYWORDS, calls: true, regex: true },
    json: { line: ['//'], block: [['/*', '*/']], strings: ['"'], multiline: [], keywords: new Set(), keys: true },
    py: { line: ['#'], block: [], strings: ['"""', "'''", '"', "'"], multiline: ['"""', "'''"], keywords: PY_KEYWORDS, calls: true, decorators: true },
    ps: { line: ['#'], block: [['<#', '#>']], strings: ['@"', "@'", '"', "'"], multiline: ['@"', "@'"], closers: { '@"': '"@', "@'": "'@" }, keywords: PS_KEYWORDS, insensitive: true, variables: true, cmdlets: true, parameters: true, escape: '`' },
    sh: { line: ['#'], block: [], strings: ['"', "'"], multiline: ['"', "'"], keywords: SH_KEYWORDS, variables: true, lineNeedsSpace: true },
    css: { line: [], block: [['/*', '*/']], strings: ['"', "'"], multiline: [], keywords: new Set(['important']), properties: true, atRules: true },
    clike: { line: ['//'], block: [['/*', '*/']], strings: ['"', "'"], multiline: [], keywords: CLIKE_KEYWORDS, calls: true },
});

const NUMBER_RE = /(?:0[xX][\da-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)n?/y;
const WORD_RE = /[A-Za-z_$][\w$]*/y;
const PS_WORD_RE = /[A-Za-z_][\w]*(?:-[A-Za-z]\w*)?/y;
const CSS_UNIT_RE = /(?:\d*\.\d+|\d+)(?:%|[a-zA-Z]{1,5})?/y;
const isWordChar = (ch) => ch !== undefined && /[\w$]/.test(ch);

/** The index of the closing quote after `from`, skipping escaped ones, or -1. */
function closeOf(line, from, closer, escape) {
    let i = from;
    while (i < line.length) {
        if (escape && line[i] === escape) {
            i += 2;
            continue;
        }
        if (line.startsWith(closer, i)) return i;
        i += 1;
    }
    return -1;
}

/** Collects tokens for one line, merging plain runs. */
function collector(line) {
    const tokens = [];
    let plain = 0;
    return {
        add(type, start, end) {
            if (start > plain) tokens.push({ text: line.slice(plain, start), type: null });
            if (end > start) tokens.push({ text: line.slice(start, end), type });
            plain = end;
        },
        done(limit = line.length) {
            if (limit > plain) tokens.push({ text: line.slice(plain, limit), type: null });
            return tokens;
        },
    };
}

/** Scans one line of a code language, continuing any comment or string the last line left open. */
function scanCode(line, state, cfg) {
    const out = collector(line);
    const escape = cfg.escape ?? '\\';
    let i = 0;
    if (state.block) {
        const end = line.indexOf(state.block);
        if (end < 0) {
            out.add('comment', 0, line.length);
            return out.done();
        }
        out.add('comment', 0, end + state.block.length);
        i = end + state.block.length;
        state.block = null;
    }
    if (state.string) {
        const { closer, lineStart } = state.string;
        const end = lineStart ? (line.startsWith(closer) ? 0 : -1) : closeOf(line, 0, closer, escape);
        if (end < 0) {
            out.add('string', 0, line.length);
            return out.done();
        }
        out.add('string', 0, end + closer.length);
        i = end + closer.length;
        state.string = null;
    }
    let afterDefinition = false;
    // The last character that was not a space, to tell a regular expression from division.
    let previous = '';
    scan: while (i < line.length) {
        const ch = line[i];
        if (cfg.regex && ch === '/' && line[i + 1] !== '/' && line[i + 1] !== '*' && (previous === '' || '(,=:[!&|?{};+-*%<>~^'.includes(previous))) {
            const end = regexEnd(line, i + 1);
            if (end > 0) {
                out.add('regexp', i, end);
                i = end;
                previous = '/';
                continue;
            }
        }
        if (cfg.properties && ch === '-' && line[i + 1] === '-' && /[A-Za-z]/.test(line[i + 2] ?? '')) {
            const custom = /--[\w-]+/y;
            custom.lastIndex = i;
            const name = custom.exec(line)[0];
            const declared = /^\s*$/.test(line.slice(0, i)) && line.slice(i + name.length).trimStart().startsWith(':');
            out.add(declared ? 'property' : 'variable', i, i + name.length);
            i += name.length;
            previous = 'a';
            continue;
        }
        for (const token of cfg.line) {
            if (line.startsWith(token, i) && (!cfg.lineNeedsSpace || i === 0 || /\s/.test(line[i - 1])) && !(token === '#' && cfg.block.some(([open]) => open.startsWith('<#')) && line[i - 1] === '<')) {
                out.add('comment', i, line.length);
                return out.done();
            }
        }
        for (const [open, close] of cfg.block) {
            if (line.startsWith(open, i)) {
                const end = line.indexOf(close, i + open.length);
                if (end < 0) {
                    out.add('comment', i, line.length);
                    state.block = close;
                    return out.done();
                }
                out.add('comment', i, end + close.length);
                i = end + close.length;
                continue scan;
            }
        }
        for (const quote of cfg.strings) {
            if (!line.startsWith(quote, i)) continue;
            const closer = cfg.closers?.[quote] ?? quote;
            const hereString = Boolean(cfg.closers?.[quote]);
            const end = hereString ? -1 : closeOf(line, i + quote.length, closer, quote === "'" && cfg.insensitive ? null : escape);
            if (end < 0) {
                out.add('string', i, line.length);
                if (cfg.multiline.includes(quote)) state.string = { closer, lineStart: hereString };
                return out.done();
            }
            const after = line.slice(end + closer.length).trimStart();
            out.add(cfg.keys && after.startsWith(':') ? 'property' : 'string', i, end + closer.length);
            i = end + closer.length;
            continue scan;
        }
        if (cfg.variables && ch === '$') {
            const brace = line[i + 1] === '{' ? line.indexOf('}', i + 2) : -1;
            if (brace > 0) {
                out.add('variable', i, brace + 1);
                i = brace + 1;
                continue;
            }
            const match = /\$(?:[A-Za-z_][\w]*(?::[A-Za-z_][\w]*)?|[0-9@?#*!$-])/y;
            match.lastIndex = i;
            const found = match.exec(line);
            if (found) {
                const name = found[0].slice(1).toLowerCase();
                out.add(cfg.insensitive && (name === 'true' || name === 'false' || name === 'null') ? 'literal' : 'variable', i, i + found[0].length);
                i += found[0].length;
                continue;
            }
        }
        if (cfg.decorators && ch === '@' && /[A-Za-z_]/.test(line[i + 1] ?? '')) {
            WORD_RE.lastIndex = i + 1;
            const found = WORD_RE.exec(line);
            out.add('function', i, i + 1 + found[0].length);
            i += 1 + found[0].length;
            continue;
        }
        if (cfg.atRules && ch === '@' && /[A-Za-z]/.test(line[i + 1] ?? '')) {
            WORD_RE.lastIndex = i + 1;
            const found = WORD_RE.exec(line);
            out.add('keyword', i, i + 1 + found[0].length);
            i += 1 + found[0].length;
            continue;
        }
        if (cfg.properties && ch === '#' && /[\da-fA-F]/.test(line[i + 1] ?? '')) {
            const hex = /#[\da-fA-F]{3,8}\b/y;
            hex.lastIndex = i;
            const found = hex.exec(line);
            if (found) {
                out.add('number', i, i + found[0].length);
                i += found[0].length;
                continue;
            }
        }
        if (cfg.parameters && ch === '-' && /[A-Za-z]/.test(line[i + 1] ?? '') && (i === 0 || /\s/.test(line[i - 1]))) {
            WORD_RE.lastIndex = i + 1;
            const found = WORD_RE.exec(line);
            out.add('attr', i, i + 1 + found[0].length);
            i += 1 + found[0].length;
            continue;
        }
        if (/\d/.test(ch) && !isWordChar(line[i - 1])) {
            const pattern = cfg.properties ? CSS_UNIT_RE : NUMBER_RE;
            pattern.lastIndex = i;
            const found = pattern.exec(line);
            if (found && !isWordChar(line[i + found[0].length]) || (found && cfg.properties)) {
                out.add('number', i, i + found[0].length);
                i += found[0].length;
                continue;
            }
        }
        if (/[A-Za-z_$]/.test(ch) && !isWordChar(line[i - 1]) && !(cfg.properties && line[i - 1] === '-')) {
            const pattern = cfg.cmdlets ? PS_WORD_RE : cfg.properties ? /[A-Za-z_][\w-]*/y : WORD_RE;
            pattern.lastIndex = i;
            const word = pattern.exec(line)[0];
            const key = cfg.insensitive ? word.toLowerCase() : word;
            const end = i + word.length;
            const rest = line.slice(end, end + 40).trimStart();
            let type = null;
            if (afterDefinition) type = 'function';
            else if (cfg.properties && /^\s*$/.test(line.slice(0, i)) && rest.startsWith(':') && !rest.startsWith('::') && !line.includes('{')) type = 'property';
            else if (cfg.keywords.has(key)) type = 'keyword';
            else if (LITERALS.has(word)) type = 'literal';
            else if (cfg.cmdlets && /^[A-Z][a-z]+-[A-Z]\w*$/.test(word)) type = 'function';
            else if (cfg.calls && rest.startsWith('(')) type = 'function';
            afterDefinition = type === 'keyword' && (key === 'function' || key === 'def' || key === 'class' || key === 'fn' || key === 'func');
            out.add(type, i, end);
            i = end;
            // After a keyword such as return, a slash starts a regular expression.
            previous = type === 'keyword' ? '(' : 'a';
            continue;
        }
        if (!/\s/.test(ch)) {
            afterDefinition = false;
            previous = ch;
        }
        i += 1;
    }
    return out.done();
}

/** The index after a regular expression literal that starts at `from` (after its slash), or -1. */
function regexEnd(line, from) {
    let inClass = false;
    for (let i = from; i < line.length; i += 1) {
        const ch = line[i];
        if (ch === '\\') {
            i += 1;
        } else if (ch === '[') {
            inClass = true;
        } else if (ch === ']') {
            inClass = false;
        } else if (ch === '/' && !inClass) {
            let end = i + 1;
            while (end < line.length && /[a-z]/.test(line[end])) end += 1;
            return end;
        }
    }
    return -1;
}

/** Inline Markdown: code spans, links, strong, and emphasis, scanned once. */
function scanInlineMarkdown(line, out, from) {
    let i = from;
    while (i < line.length) {
        const ch = line[i];
        if (ch === '`') {
            const end = line.indexOf('`', i + 1);
            if (end > i) {
                out.add('code', i, end + 1);
                i = end + 1;
                continue;
            }
        } else if (ch === '[') {
            const close = line.indexOf('](', i + 1);
            const end = close > i ? line.indexOf(')', close + 2) : -1;
            if (close > i && end > close && close - i <= 500) {
                out.add('link', i, end + 1);
                i = end + 1;
                continue;
            }
        } else if (ch === '*' && line[i + 1] === '*') {
            const end = line.indexOf('**', i + 2);
            if (end > i + 2) {
                out.add('strong', i, end + 2);
                i = end + 2;
                continue;
            }
        } else if ((ch === '*' || ch === '_') && line[i + 1] && line[i + 1] !== ' ' && line[i + 1] !== ch && (i === 0 || /[\s(]/.test(line[i - 1]))) {
            const end = line.indexOf(ch, i + 1);
            if (end > i + 1 && line[end - 1] !== ' ') {
                out.add('emphasis', i, end + 1);
                i = end + 1;
                continue;
            }
        } else if (ch === '<' && line.startsWith('<!--', i)) {
            const end = line.indexOf('-->', i + 4);
            out.add('comment', i, end < 0 ? line.length : end + 3);
            i = end < 0 ? line.length : end + 3;
            continue;
        }
        i += 1;
    }
}

/** One line of YAML: comments, keys, quoted strings, numbers, and literals. */
function scanYaml(line, state) {
    const out = collector(line);
    if (/^(---|\.\.\.)\s*$/.test(line)) {
        out.add('meta', 0, line.length);
        return out.done();
    }
    let i = 0;
    const key = /^(\s*(?:-\s+)?)((?:"[^"]*"|'[^']*'|[^\s#:"'][^:#]*?))(\s*:)(?=\s|$)/.exec(line);
    if (key) {
        out.add('property', key[1].length, key[1].length + key[2].length);
        i = key[0].length;
    }
    while (i < line.length) {
        const ch = line[i];
        if (ch === '#' && (i === 0 || /\s/.test(line[i - 1]))) {
            out.add('comment', i, line.length);
            break;
        }
        if (ch === '"' || ch === "'") {
            const end = closeOf(line, i + 1, ch, ch === '"' ? '\\' : null);
            out.add('string', i, end < 0 ? line.length : end + 1);
            i = end < 0 ? line.length : end + 1;
            continue;
        }
        if (/[\w.~+-]/.test(ch) && (i === 0 || /[\s[,{:-]/.test(line[i - 1]))) {
            const word = /[\w.~+-]+/y;
            word.lastIndex = i;
            const value = word.exec(line)[0];
            const end = i + value.length;
            if (/^(true|false|null|yes|no|on|off|~)$/i.test(value)) out.add('literal', i, end);
            else if (/^[+-]?\d[\d_]*(\.\d+)?([eE][+-]?\d+)?$/.test(value)) out.add('number', i, end);
            i = end;
            continue;
        }
        i += 1;
    }
    return out.done();
}

/** One line of Markdown, with fences, front matter, and HTML comments carried across lines. */
function scanMarkdown(line, state, index) {
    const out = collector(line);
    if (state.front) {
        if (/^(---|\.\.\.)\s*$/.test(line)) {
            state.front = false;
            out.add('meta', 0, line.length);
            return out.done();
        }
        return scanYaml(line, state);
    }
    if (index === 0 && /^---\s*$/.test(line)) {
        state.front = true;
        out.add('meta', 0, line.length);
        return out.done();
    }
    if (state.fence) {
        if (line.trimStart().startsWith(state.fence)) {
            state.fence = null;
            out.add('meta', 0, line.length);
        } else {
            out.add('code', 0, line.length);
        }
        return out.done();
    }
    if (state.comment) {
        const end = line.indexOf('-->');
        out.add('comment', 0, end < 0 ? line.length : end + 3);
        if (end < 0) return out.done();
        state.comment = false;
        scanInlineMarkdown(line, out, end + 3);
        return out.done();
    }
    const fence = /^\s{0,3}(`{3,}|~{3,})/.exec(line);
    if (fence) {
        state.fence = fence[1];
        out.add('meta', 0, line.length);
        return out.done();
    }
    if (/^\s{0,3}#{1,6}(\s|$)/.test(line)) {
        out.add('heading', 0, line.length);
        return out.done();
    }
    if (/^\s*\|?\s*:?-{3,}/.test(line) && line.includes('-')) {
        out.add('meta', 0, line.length);
        return out.done();
    }
    let from = 0;
    const marker = /^(\s*)(>\s?|[-*+]\s+|\d{1,9}[.)]\s+)(\[[ xX]\]\s+)?/.exec(line);
    if (marker) {
        const start = marker[1].length;
        out.add(marker[2].startsWith('>') ? 'comment' : 'list', start, start + marker[2].length);
        if (marker[3]) out.add('meta', start + marker[2].length, marker[0].length);
        from = marker[0].length;
    }
    const open = line.indexOf('<!--', from);
    if (open >= 0 && line.indexOf('-->', open + 4) < 0) {
        scanInlineMarkdown(line.slice(0, open), out, from);
        out.add('comment', open, line.length);
        state.comment = true;
        return out.done();
    }
    scanInlineMarkdown(line, out, from);
    return out.done();
}

/** One line of HTML or XML: comments, tags, attributes, and their values. */
function scanHtml(line, state) {
    const out = collector(line);
    let i = 0;
    if (state.comment) {
        const end = line.indexOf('-->');
        out.add('comment', 0, end < 0 ? line.length : end + 3);
        if (end < 0) return out.done();
        state.comment = false;
        i = end + 3;
    }
    while (i < line.length) {
        if (state.tag) {
            const ch = line[i];
            if (ch === '>' || (ch === '/' && line[i + 1] === '>')) {
                state.tag = false;
                i += ch === '>' ? 1 : 2;
                continue;
            }
            if (ch === '"' || ch === "'") {
                const end = line.indexOf(ch, i + 1);
                out.add('string', i, end < 0 ? line.length : end + 1);
                i = end < 0 ? line.length : end + 1;
                continue;
            }
            if (/[A-Za-z_:@]/.test(ch)) {
                const name = /[\w:.@-]+/y;
                name.lastIndex = i;
                const found = name.exec(line)[0];
                out.add('attr', i, i + found.length);
                i += found.length;
                continue;
            }
            i += 1;
            continue;
        }
        if (line.startsWith('<!--', i)) {
            const end = line.indexOf('-->', i + 4);
            out.add('comment', i, end < 0 ? line.length : end + 3);
            if (end < 0) {
                state.comment = true;
                return out.done();
            }
            i = end + 3;
            continue;
        }
        const tag = /<\/?([A-Za-z][\w:.-]*)|<[!?][A-Za-z]+/y;
        tag.lastIndex = i;
        const found = line[i] === '<' ? tag.exec(line) : null;
        if (found) {
            out.add('tag', i, i + found[0].length);
            i += found[0].length;
            state.tag = true;
            continue;
        }
        if (line[i] === '&') {
            const entity = /&#?\w{1,10};/y;
            entity.lastIndex = i;
            const match = entity.exec(line);
            if (match) {
                out.add('literal', i, i + match[0].length);
                i += match[0].length;
                continue;
            }
        }
        i += 1;
    }
    return out.done();
}

/**
 * Tokens for each line of a file in one language, or each line as one plain token when the
 * language is unknown. Lines longer than MAX_HIGHLIGHT keep the rest plain.
 *
 * @param {string[]} lines
 * @param {string | null} language from `languageOf`
 * @param {{ fromLine?: number }} [options] `fromLine` is the file line the first entry holds
 * @returns {Token[][]}
 */
export function highlightLines(lines, language, options = {}) {
    if (!language) return lines.map((text) => [{ text, type: null }]);
    const state = { block: null, string: null, fence: null, comment: false, front: false, tag: false };
    const first = Number.isInteger(options.fromLine) ? options.fromLine : 1;
    return lines.map((text, index) => {
        const head = text.length > MAX_HIGHLIGHT ? text.slice(0, MAX_HIGHLIGHT) : text;
        let tokens;
        try {
            if (language === 'md') tokens = scanMarkdown(head, state, first - 1 + index);
            else if (language === 'yaml') tokens = scanYaml(head, state);
            else if (language === 'html') tokens = scanHtml(head, state);
            else tokens = scanCode(head, state, CODE[language]);
        } catch {
            tokens = [{ text: head, type: null }];
        }
        if (head.length < text.length) tokens.push({ text: text.slice(MAX_HIGHLIGHT), type: null });
        return tokens;
    });
}
