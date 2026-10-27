// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';

let restore;
let renderMarkdown;
let isSafeUrl;
let externalLink;
before(async () => {
    restore = installFakeDom();
    ({ renderMarkdown, isSafeUrl, externalLink } = await import('../ui/markdown.mjs'));
});
after(() => restore());

const tags = (fragment, tag) => elements(fragment).filter((el) => el.localName === tag);

describe('isSafeUrl', () => {
    it('allows only absolute http and https URLs', () => {
        assert.equal(isSafeUrl('https://learn.microsoft.com/a?b=c#d'), true);
        assert.equal(isSafeUrl('http://127.0.0.1:8080/'), true);
        for (const url of ['javascript:alert(1)', 'JaVaScRiPt:alert(1)', ' javascript:alert(1)', 'data:text/html,<b>x</b>', 'vbscript:msgbox(1)', 'file:///etc/passwd', 'vscode://file/x', '//evil.example/x', '/relative/path', 'docs/readme.md', '', 'https//missing-colon']) {
            assert.equal(isSafeUrl(url), false, url);
        }
    });
});

describe('link helpers', () => {
    it('links only http and https sources and keeps others as text', () => {
        const safe = externalLink('https://example.com/a', 'Source');
        assert.equal(safe.localName, 'a');
        assert.equal(safe.getAttribute('href'), 'https://example.com/a');
        assert.equal(safe.getAttribute('rel'), 'noopener noreferrer');
        for (const url of ['javascript:alert(1)', 'vscode://command/x', 'data:text/html,x', undefined]) {
            const unsafe = externalLink(url, 'Source');
            assert.equal(unsafe.localName, 'span');
            assert.equal(unsafe.getAttribute('href'), null);
            assert.equal(unsafe.textContent, 'Source');
        }
    });
});

describe('renderMarkdown', () => {
    it('renders markup in the source as text, never as elements', () => {
        const fragment = renderMarkdown('<img src=x onerror="alert(1)"> <script>alert(2)</script> **bold**');
        assert.equal(tags(fragment, 'img').length, 0);
        assert.equal(tags(fragment, 'script').length, 0);
        assert.equal(tags(fragment, 'strong').length, 1);
        assert.match(serialize(fragment), /&lt;img src=x onerror=&quot;alert\(1\)&quot;&gt;/);
    });

    it('links safe URLs in a new browsing context and keeps unsafe ones as text', () => {
        const fragment = renderMarkdown('[docs](https://example.com/guide) and [bad](javascript:alert(1)) and https://example.org/raw and [wiki](https://en.wikipedia.org/wiki/Fence_(computing)).');
        const links = tags(fragment, 'a');
        assert.deepEqual(links.map((a) => a.getAttribute('href')), ['https://example.com/guide', 'https://example.org/raw', 'https://en.wikipedia.org/wiki/Fence_(computing)']);
        assert.match(fragment.textContent, /\(opens in a new tab\)\.$/);
        for (const link of links) {
            assert.equal(link.getAttribute('target'), '_blank');
            assert.equal(link.getAttribute('rel'), 'noopener noreferrer');
        }
        const unsafe = elements(fragment).find((el) => el.className === 'md-link-text');
        assert.equal(unsafe.getAttribute('title'), 'javascript:alert(1)');
        assert.equal(unsafe.textContent, 'bad');
    });

    it('never nests links or chips inside a link', () => {
        const fragment = renderMarkdown('[see D2 at https://example.com/x](https://example.com/y)', { resolveId: () => true, navigate: () => {} });
        const links = tags(fragment, 'a');
        assert.equal(links.length, 1);
        assert.equal(elements(links[0]).filter((el) => el.localName === 'a' || el.localName === 'button').length, 0);
        assert.match(links[0].textContent, /^see D2 at https:\/\/example.com\/x/);
    });

    it('turns known IDs into navigation chips and leaves unknown ones as text', () => {
        const fragment = renderMarkdown('Decided in D2; see P02-T03 and Q9.', { resolveId: (id) => id !== 'Q9', navigate: () => {} });
        const chips = elements(fragment).filter((el) => el.localName === 'button' && el.className.includes('id-chip'));
        assert.deepEqual(chips.map((chip) => chip.textContent), ['D2', 'P02-T03']);
        assert.match(fragment.textContent, /and Q9\./);
    });

    it('steps headings down below the row title and keeps h1 and h2 major', () => {
        const fragment = renderMarkdown('# One\n\n## Two\n\n### Three');
        assert.deepEqual(elements(fragment).filter((el) => /^h\d$/.test(el.localName)).map((el) => `${el.localName}:${el.className}`), ['h4:md-heading is-major', 'h4:md-heading is-major', 'h5:md-heading']);
    });

    it('renders task lists, tables, and fenced code', () => {
        const fragment = renderMarkdown('- [x] Done\n- [ ] Not yet\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```js\nconst a = 1;\n```');
        const tasks = elements(fragment).filter((el) => el.className.includes('md-task'));
        assert.equal(tasks.length, 2);
        assert.match(tasks[0].textContent, /^Done: Done/);
        const well = elements(fragment).find((el) => el.className === 'table-well');
        assert.equal(well.getAttribute('role'), 'region');
        assert.equal(well.getAttribute('aria-label'), 'Table: A, B');
        const labeled = elements(renderMarkdown('| A | B |\n| --- | --- |\n| 1 | 2 |\n\n### Method\n\n| A | B |\n| --- | --- |\n| 3 | 4 |', { label: 'Research record' })).filter((el) => el.className === 'table-well');
        assert.deepEqual(labeled.map((el) => el.getAttribute('aria-label')), ['Research record table: A, B', 'Method table: A, B'], 'tables with the same columns get distinct region names');
        assert.equal(tags(fragment, 'td').length, 2);
        assert.equal(tags(fragment, 'pre')[0].textContent, 'const a = 1;');
    });

    it('caps block quote nesting at six levels', () => {
        const fragment = renderMarkdown(`${'>'.repeat(12)} deep`);
        let depth = 0;
        let node = tags(fragment, 'blockquote')[0];
        while (node) {
            depth += 1;
            node = node.childNodes.find((child) => child.localName === 'blockquote');
        }
        assert.ok(depth <= 7, `depth ${depth}`);
        assert.match(fragment.textContent, /deep/);
    });

    it('truncates very long input and says so', () => {
        const fragment = renderMarkdown('a'.repeat(70000));
        assert.equal(elements(fragment)[0].className, 'md-note');
        assert.ok(fragment.textContent.length < 61000);
    });

    it('stays fast on pathological input', () => {
        const inputs = {
            brackets: '['.repeat(30000),
            backticks: '`'.repeat(30000),
            emphasis: '**a'.repeat(15000),
            underscores: 'a_'.repeat(25000),
            links: '[a]('.repeat(12000),
            distantClose: `${'['.repeat(30000)}](x)`,
            openParens: `${'[a]('.repeat(500)}${'('.repeat(20000)}`,
            nestedParens: `[a](${'('.repeat(15000)}${')'.repeat(15000)}`,
            spacedGroups: '[a](x(y '.repeat(7000),
            quotes: '> '.repeat(20000),
            pipes: `${'|'.repeat(200)}\n${'| --- '.repeat(100)}|\n${'|x'.repeat(10000)}`,
            ids: 'D1 '.repeat(15000),
        };
        for (const [name, input] of Object.entries(inputs)) {
            const start = performance.now();
            renderMarkdown(input, { resolveId: () => true, navigate: () => {} });
            const ms = performance.now() - start;
            // Linear in practice: well under 50 ms locally; the bound leaves room for slower CI hosts.
            assert.ok(ms < 200, `${name} took ${Math.round(ms)} ms`);
        }
    });
});
