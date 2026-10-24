// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
    bodyOf,
    checkboxHeading,
    codeBlocks,
    field,
    findSection,
    idsIn,
    labeledFields,
    linksIn,
    listItems,
    parseDocument,
    plainText,
    sectionsAt,
    severityHeading,
    tables,
    tableWith,
    titleOf,
} from '../lib/source/markdown.mjs';

const PLAN = `# RPI Plan: Sample

## Phase Checklist

### Before

\`\`\`mermaid
flowchart LR
    a["A"] -->|uses| b["B"]
\`\`\`

<!-- rpi:phase id=P01 -->
### [x] P01: First phase

Goals:
* Do the first thing.

Dependencies:
* None

\`\`\`text
## Not a heading
| not | a table |
|-----|---------|
\`\`\`

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: First task

Goals:
* Outcome one.

Requirements:
* FR-001, NFR-002
* A condition with a nested list:
  * nested one
  * nested two

Details:
* Some detail.

  \`\`\`text
  a -> b | c
  \`\`\`

References:
* [lib/a.mjs](../../lib/a.mjs): why.

Dependencies:
* None

## Goals

* One goal.
`;

describe('document structure', () => {
    it('reads headings, markers, and section ends while ignoring fenced code', () => {
        const doc = parseDocument(PLAN);
        assert.equal(titleOf(doc), 'RPI Plan: Sample');
        assert.ok(!doc.headings.some((heading) => heading.title === 'Not a heading'));
        const phase = doc.headings.find((heading) => heading.marker?.id === 'P01');
        const task = doc.headings.find((heading) => heading.marker?.id === 'P01-T01');
        assert.deepEqual(phase.marker, { kind: 'phase', id: 'P01' });
        assert.equal(task.level, 4);
        assert.ok(phase.end > task.line, 'the phase section contains its task');
        const goals = findSection(doc, 'Goals', { level: 2 });
        assert.equal(task.end, goals.line);
        assert.deepEqual(checkboxHeading(task.title), { checked: false, id: 'P01-T01', title: 'First task' });
        assert.equal(checkboxHeading(phase.title).checked, true);
        const checklist = findSection(doc, 'phase checklist', { level: 2 });
        assert.deepEqual(sectionsAt(doc, 3, checklist).map((heading) => heading.title), ['Before', '[x] P01: First phase']);
        assert.equal(bodyOf(doc, phase, { own: true }).includes('#### [ ]'), false);
        assert.ok(!bodyOf(doc, phase, { own: true }).trim().endsWith('-->'), 'trailing markers are trimmed');
    });

    it('reads standalone label blocks with nested lists and fenced code', () => {
        const doc = parseDocument(PLAN);
        const task = doc.headings.find((heading) => heading.marker?.id === 'P01-T01');
        const fields = labeledFields(bodyOf(doc, task));
        assert.deepEqual([...fields.keys()], ['goals', 'requirements', 'details', 'references', 'dependencies']);
        assert.equal(field(fields, 'Requirements'), '* FR-001, NFR-002\n* A condition with a nested list:\n  * nested one\n  * nested two');
        assert.match(field(fields, 'Details'), /a -> b \| c/);
        assert.equal(field(fields, 'Missing'), '');
    });

    it('reads bullet fields with inline and nested values', () => {
        const fields = labeledFields([
            '* Related phase or task: P01-T01 (RV-001)',
            '* Files:',
            '  * [lib/a.mjs](../../lib/a.mjs)',
            '  * [lib/b.mjs](../../lib/b.mjs)',
            '* Behavior or functionality changed:',
            '  * First change.',
            '',
            '  * Second change after a blank line.',
            '* Validation: Passed.',
            'Plain text: not a bullet, still a line field.',
        ].join('\n'));
        assert.equal(field(fields, 'related phase or task'), 'P01-T01 (RV-001)');
        assert.deepEqual(linksIn(field(fields, 'Files')).map((link) => link.text), ['lib/a.mjs', 'lib/b.mjs']);
        assert.equal(field(fields, 'Behavior or functionality changed'), '* First change.\n\n* Second change after a blank line.');
        assert.equal(field(fields, 'Validation'), 'Passed.');
        assert.equal(field(fields, 'Plain text'), 'not a bullet, still a line field.');
    });
});

describe('tables, blocks, lists, and links', () => {
    it('reads pipe tables outside fences and keeps escaped pipes in cells', () => {
        const block = [
            '| ID | Question | Status |',
            '|----|----------|--------|',
            '| Q1 | Does `a \\| b` work? | answered |',
            '| Q2 | Second | open |',
            '',
            '```text',
            '| fenced | table |',
            '|--------|-------|',
            '```',
        ].join('\n');
        const found = tables(block);
        assert.equal(found.length, 1);
        assert.equal(found[0].rows[0].question, 'Does `a | b` work?');
        assert.equal(tableWith(block, ['id', 'STATUS']).rows[1].status, 'open');
        assert.equal(tableWith(block, ['Missing']), null);
        assert.deepEqual(tables('| Code | Note |\n|---|---|\n| `x | y` | kept |')[0].cells, [['`x | y`', 'kept']], 'pipes in code spans stay in the cell');
        const empty = tables('| ID | Claim |\n|----|-------|\n\nNo rows yet.');
        assert.deepEqual([empty.length, empty[0].rows.length], [1, 0], 'an empty table has headers and no rows');
    });

    it('reads fenced blocks by language, including indented fences', () => {
        const blocks = codeBlocks(PLAN, 'mermaid');
        assert.equal(blocks.length, 1);
        assert.match(blocks[0].code, /^flowchart LR\n {4}a\["A"\] -->\|uses\| b\["B"\]$/);
        assert.equal(codeBlocks(PLAN, 'text').at(-1).code, 'a -> b | c');
    });

    it('splits top-level list items with their nested lines', () => {
        assert.deepEqual(listItems('* One\n  * nested\n* Two\n\nAfter'), ['One\n* nested', 'Two']);
        assert.deepEqual(listItems('* None'), ['None']);
    });

    it('finds links outside code spans', () => {
        assert.deepEqual(linksIn('See [a](x.md) and `[not](y.md)`.'), [{ text: 'a', href: 'x.md' }]);
    });
});

describe('IDs and headings', () => {
    it('expands ranges and lists without inventing IDs', () => {
        assert.deepEqual(idsIn('C5 to C8, C20, W2'), ['C5', 'C6', 'C7', 'C8', 'C20', 'W2']);
        assert.deepEqual(idsIn('RD-001 to RD-003 and RV-010 through RV-011'), ['RD-001', 'RD-002', 'RD-003', 'RV-010', 'RV-011']);
        assert.deepEqual(idsIn('P01-T01 (RV-001); P02-T03'), ['P01-T01', 'RV-001', 'P02-T03']);
        assert.deepEqual(idsIn('C9 to C2'), ['C9', 'C2'], 'a backwards range stays as written');
        assert.deepEqual(idsIn('C1 to W3'), ['C1', 'W3'], 'mixed prefixes stay as written');
        assert.equal(idsIn('C1 to C900').length, 2, 'oversized ranges stay as written');
        assert.deepEqual(idsIn('C1, W2, FR-001', /^[CW]\d+$/), ['C1', 'W2']);
    });

    it('reads severity headings and plain text', () => {
        assert.deepEqual(severityHeading('RV-011 [Low]: Storage gaps'), { id: 'RV-011', severity: 'low', title: 'Storage gaps' });
        assert.equal(severityHeading('PC-001 [Urgent]: x'), null);
        assert.equal(plainText('Use **`store.update`** and [the guide](https://example.com/g), _please_.'), 'Use store.update and the guide, please.');
    });
});
