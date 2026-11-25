// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { isSafeHref, renderMarkdown } from '../ui/markdown.mjs';
import { fakeDocument } from './helpers.mjs';

function render(text) {
    const root = fakeDocument.createElement('div');
    root.append(renderMarkdown(text, fakeDocument));
    return root;
}

function tags(root) {
    return root.elements().map((element) => element.tagName);
}

test('renders the supported Markdown subset', () => {
    const root = render([
        '# Heading',
        '',
        'Some **bold**, *italic*, ~~gone~~, and `code`.',
        '',
        '* one',
        '  * nested',
        '* two',
        '',
        '3. third',
        '',
        '> quoted',
        '',
        '| A | B |',
        '|---|---|',
        '| 1 | 2 |',
        '',
        '```js',
        'const x = 1;',
        '```',
        '',
        '---',
    ].join('\n'));
    const found = tags(root);
    for (const tag of ['H4', 'STRONG', 'EM', 'DEL', 'CODE', 'UL', 'LI', 'OL', 'BLOCKQUOTE', 'TABLE', 'TH', 'TD', 'PRE', 'HR']) {
        assert.ok(found.includes(tag), tag);
    }
    const ol = root.elements().find((element) => element.tagName === 'OL');
    assert.equal(ol.start, '3');
    const nested = root.elements().filter((element) => element.tagName === 'UL');
    assert.equal(nested.length, 2);
    const pre = root.elements().find((element) => element.tagName === 'PRE');
    assert.equal(pre.textContent, 'const x = 1;');
});

test('never produces script elements or event attributes from hostile input', () => {
    const root = render('<script>alert(1)</script>\n<img src=x onerror=alert(1)>\n[click](javascript:alert(1))\n[data](data:text/html,hi)');
    const found = tags(root);
    assert.equal(found.includes('SCRIPT'), false);
    assert.equal(found.includes('IMG'), false);
    assert.equal(found.includes('A'), false);
    for (const element of root.elements()) {
        assert.equal(Object.keys(element.attributes).some((name) => name.startsWith('on')), false);
    }
    assert.match(root.textContent, /<script>alert\(1\)<\/script>/);
    assert.match(root.textContent, /javascript:alert/);
});

test('links only http and https URLs with safe rel and target', () => {
    const root = render('See [docs](https://example.com/a) and http://example.org/b.');
    const links = root.elements().filter((element) => element.tagName === 'A');
    assert.equal(links.length, 2);
    for (const link of links) {
        assert.equal(link.rel, 'noopener noreferrer');
        assert.equal(link.target, '_blank');
    }
    assert.equal(links[1].href, 'http://example.org/b');
    assert.equal(isSafeHref('https://x.test'), true);
    assert.equal(isSafeHref('javascript:alert(1)'), false);
    assert.equal(isSafeHref('file:///etc/passwd'), false);
    assert.equal(isSafeHref('not a url'), false);
});

test('keeps snake_case identifiers literal and bounds long inputs', () => {
    const root = render('call snake_case_name and __init__ here');
    assert.equal(root.elements().some((element) => element.tagName === 'EM'), false);
    const started = Date.now();
    render(`${'a_'.repeat(50000)}\n${'*x'.repeat(20000)}`);
    assert.ok(Date.now() - started < 2000);
});

test('whitespace-heavy block lines render in linear time', () => {
    const spaces = ' '.repeat(64 * 1024);
    const inputs = {
        heading: `# a${spaces}!`,
        fence: `\`\`\`${spaces}!`,
        table: `a | b\n|--${spaces}!`,
        rule: `- -${spaces}x`,
        list: `${spaces}x`,
    };
    for (const [name, input] of Object.entries(inputs)) {
        const started = performance.now();
        render(input);
        assert.ok(performance.now() - started < 50, `${name} took ${performance.now() - started} ms`);
    }
});

test('headings, fences, and tables keep their behavior', () => {
    const root = render('## Title ##\n\n```js  \nconst a = 1;\n```\n\n| a | b |\n| :-- | --: |\n| 1 | 2 |');
    const heading = root.elements().find((element) => element.tagName === 'H5');
    assert.equal(heading.textContent, 'Title');
    assert.equal(root.elements().find((element) => element.tagName === 'CODE').dataset.lang, 'js');
    assert.ok(root.elements().some((element) => element.tagName === 'TABLE'));
    assert.equal(render('#nospace').elements().some((element) => /^H\d$/.test(element.tagName)), false);
    assert.equal(render('| a |\n| - |').elements().some((element) => element.tagName === 'TABLE'), false);
});

test('deep blockquote nesting is capped and renders quickly', () => {
    const started = performance.now();
    const root = render(`${'>'.repeat(20000)} deep`);
    assert.ok(performance.now() - started < 50, `took ${performance.now() - started} ms`);
    assert.ok(root.elements().filter((element) => element.tagName === 'BLOCKQUOTE').length <= 6);
    assert.ok(root.textContent.includes('deep'));
});
