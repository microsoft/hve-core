// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { highlightLines, languageOf, MAX_HIGHLIGHT } from '../ui/highlight.mjs';

/** The colored parts of each line, as `type:text`. */
const colored = (source, language) => highlightLines(source.split('\n'), language).map((tokens) => tokens.filter((token) => token.type).map((token) => `${token.type}:${token.text}`));
const flat = (source, language) => colored(source, language).flat();

describe('highlighter', () => {
    it('picks a scanner by extension and leaves other files plain', () => {
        assert.deepEqual(['a/b.mjs', 'x.tsx', 'p.json', 'README.md', 'c.yaml', 's.py', 'm.psm1', 'run.sh', 'ui/styles.css', 'i.html', 'svc.cs', 'notes.txt', 'Makefile'].map(languageOf),
            ['js', 'js', 'json', 'md', 'yaml', 'py', 'ps', 'sh', 'css', 'html', 'clike', null, null]);
        assert.deepEqual(highlightLines(['a b', ''], null), [[{ text: 'a b', type: null }], [{ text: '', type: null }]]);
    });

    it('keeps the text exactly, whatever it colors', () => {
        const source = 'const re = /["\']+/g; // note\nfunction go(a) { return `t ${a}\n end`; }\n# Head `x` and **b**';
        for (const language of ['js', 'md', 'py', 'sh', 'ps', 'css', 'html', 'yaml', 'json', 'clike']) {
            const lines = highlightLines(source.split('\n'), language);
            assert.deepEqual(lines.map((tokens) => tokens.map((token) => token.text).join('')), source.split('\n'), language);
        }
    });

    it('colors JavaScript keywords, calls, strings, numbers, comments, and regular expressions', () => {
        assert.deepEqual(colored('const re = /["\']+/g; // note\nif (go(2) === null) throw new Error("bad \\"q");', 'js'), [
            ['keyword:const', 'regexp:/["\']+/g', 'comment:// note'],
            ['keyword:if', 'function:go', 'number:2', 'literal:null', 'keyword:throw', 'keyword:new', 'function:Error', 'string:"bad \\"q"'],
        ]);
        assert.deepEqual(colored('x = a / 2 / b;', 'js'), [['number:2']], 'division is not a regular expression');
    });

    it('carries block comments and template strings across lines', () => {
        assert.deepEqual(colored('/* one\ntwo */ let x = `a\nb`;', 'js'), [['comment:/* one'], ['comment:two */', 'keyword:let', 'string:`a'], ['string:b`']]);
    });

    it('colors JSON keys apart from values', () => {
        assert.deepEqual(flat('{ "key": "value", "n": 12.5e3, "ok": true }', 'json'), ['property:"key"', 'string:"value"', 'property:"n"', 'number:12.5e3', 'property:"ok"', 'literal:true']);
    });

    it('colors Markdown headings, lists, inline code, links, fences, front matter, and comments', () => {
        assert.deepEqual(colored('---\ntitle: x\n---\n# Head\n* item with `code`, **bold**, and [a](b)\n```js\nconst a = 1;\n```\n<!-- note\nstill -->', 'md'), [
            ['meta:---'], ['property:title'], ['meta:---'], ['heading:# Head'],
            ['list:* ', 'code:`code`', 'strong:**bold**', 'link:[a](b)'],
            ['meta:```js'], ['code:const a = 1;'], ['meta:```'], ['comment:<!-- note'], ['comment:still -->'],
        ]);
    });

    it('colors YAML keys, values, and comments', () => {
        assert.deepEqual(colored('key: "v" # c\n- name: 3\n  on: true', 'yaml'), [['property:key', 'string:"v"', 'comment:# c'], ['property:name', 'number:3'], ['property:on', 'literal:true']]);
    });

    it('colors Python decorators, definitions, and triple-quoted strings across lines', () => {
        assert.deepEqual(colored('@dec\ndef f(x):\n    return """multi\nline""" # c', 'py'), [['function:@dec'], ['keyword:def', 'function:f'], ['keyword:return', 'string:"""multi'], ['string:line"""', 'comment:# c']]);
    });

    it('colors PowerShell cmdlets, variables, parameters, and block comments', () => {
        assert.deepEqual(colored('Write-Host "$Path" -ForegroundColor Red; $true <# block\n#>', 'ps'), [['function:Write-Host', 'string:"$Path"', 'attr:-ForegroundColor', 'literal:$true', 'comment:<# block'], ['comment:#>']]);
    });

    it('colors shell variables and comments but not a # inside a word', () => {
        assert.deepEqual(flat('echo $HOME a#b # c', 'sh'), ['variable:$HOME', 'comment:# c']);
    });

    it('colors CSS properties, custom properties, numbers, and at-rules, but not selectors', () => {
        assert.deepEqual(colored('a:hover { color: red; }\n  --rw-bg: var(--x);\n  margin: 12px 0;\n@media (min-width: 10px) {', 'css'), [
            [], ['property:--rw-bg', 'variable:--x'], ['property:margin', 'number:12px', 'number:0'], ['keyword:@media', 'number:10px'],
        ]);
    });

    it('colors HTML tags, attributes, values, entities, and comments', () => {
        assert.deepEqual(flat('<a href="x">t &amp; u</a><!-- c -->', 'html'), ['tag:<a', 'attr:href', 'string:"x"', 'literal:&amp;', 'tag:</a', 'comment:<!-- c -->']);
    });

    it('colors only the start of a very long line', () => {
        const long = `const a = "${'x'.repeat(MAX_HIGHLIGHT + 500)}";`;
        const [tokens] = highlightLines([long], 'js');
        assert.equal(tokens.map((token) => token.text).join(''), long);
        assert.equal(tokens.at(-1).type, null);
        assert.equal(tokens.at(-1).text.length, long.length - MAX_HIGHLIGHT);
    });

    it('stays fast on 5,000 lines and on hostile input', () => {
        const lines = Array.from({ length: 5000 }, (_, index) => `const value${index} = compute(${index}, "text", /re/g); // line ${index}`);
        let started = performance.now();
        highlightLines(lines, 'js');
        assert.ok(performance.now() - started < 300, '5,000 lines of JavaScript');
        const hostile = ['`'.repeat(MAX_HIGHLIGHT), '['.repeat(MAX_HIGHLIGHT), '"'.repeat(MAX_HIGHLIGHT), '/*'.repeat(MAX_HIGHLIGHT / 2), '\\'.repeat(MAX_HIGHLIGHT), '<'.repeat(MAX_HIGHLIGHT)];
        started = performance.now();
        for (const language of ['js', 'md', 'html', 'yaml', 'py', 'ps', 'sh', 'css']) highlightLines(hostile, language);
        assert.ok(performance.now() - started < 500, 'hostile lines stay linear');
    });
});
