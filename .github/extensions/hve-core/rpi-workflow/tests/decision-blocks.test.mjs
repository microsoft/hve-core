// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFeedback } from '../lib/model.mjs';
import { assembleSession } from '../lib/source/assemble.mjs';
import { parsePlan, parseResearch, parseState } from '../lib/source/parse.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';

const NOW = '2026-01-15T12:00:00.000Z';

const RESEARCH = `<!-- markdownlint-disable-file -->
# Task Research: Basemaps

## Executive Summary

* Bottom line: Terrain first.

## Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Impact of answer |
|-------|---------------------------|--------|-------|---------------------------|----------|------------------|
| D1 | Which basemap ships first | input requested | user | See the block | C1 | Changes P01 |
| D2 | Tile format | confirmed | user | B: vector tiles, for smaller downloads | C1, W7 | P02 |
| U1 | An old-style row | proposed | agent | Kept for history | | |

### D1: Which basemap ships first

Which basemap should the first release use?

* A (recommended): Terrain, because hikers read contours.
* B: Satellite, which
  costs more to store.
* not an option
* A: a repeated letter

Satellite can follow in a later release.

### D2: Tile format

Which tile format should the cache store?

* A: Raster tiles.
* B: Vector tiles.

### D9: An orphan block

What about this?

## Research Record

### Evidence Log

| ID | Claim or finding | Source or location | Retrieved and version | Tool | Confidence | Notes |
|----|------------------|--------------------|-----------------------|------|------------|-------|
| C1 | Tiles are cached by region | lib/cache.mjs | 2026-01-15 | read | high | |
`;

const PLAN = `<!-- markdownlint-disable-file -->
# RPI Plan: Basemaps

## User Decisions and Requirements

### Confirmed User Direction

* Ship offline maps.

### Planning Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Planning impact |
|-------|---------------------------|--------|-------|---------------------------|----------|-----------------|
| D1 | Cache size | input requested | user | See below | none | P01 |

#### D1: Cache size

How much space may the cache use?

* A (recommended): 200 MB.
* B: 500 MB.
`;

const assembled = () => assembleSession({
    id: 'rpi-basemaps',
    state: parseState({ task_id: 'basemaps', task_slug: 'basemaps', mode: 'manual', active_phase: 'Research', status: 'active', session_status: 'running', artifact_paths: { research: 'x' } }),
    artifacts: { research: parseResearch(RESEARCH) },
    statePath: '.copilot-tracking/rpi-sessions/2026-01-15/basemaps/basemaps-state.json',
    now: NOW,
});

describe('decision blocks in RPI files', () => {
    it('reads the question, options, recommended mark, wrapped labels, and context of research blocks', () => {
        const research = parseResearch(RESEARCH);
        assert.deepEqual(research.decisions.map((decision) => decision.id), ['D1', 'D2']);
        assert.deepEqual(research.decisions[0].block, {
            title: 'Which basemap ships first',
            question: 'Which basemap should the first release use?',
            options: [
                { id: 'A', label: 'Terrain, because hikers read contours.', recommended: true },
                { id: 'B', label: 'Satellite, which costs more to store.', recommended: false },
            ],
            context: 'Satellite can follow in a later release.',
        });
        assert.deepEqual(research.decisions[1].block.options.map((option) => option.id), ['A', 'B']);
        assert.ok(!research.other.some((record) => /D1|D9/.test(record.heading)), 'blocks are not listed as other sections');
    });

    it('reports list items, rows, and blocks it cannot use, instead of dropping them silently', () => {
        const { warnings } = parseResearch(RESEARCH);
        assert.deepEqual(warnings, [
            'Decision D1: 2 list items are not an option like "A: text" with a new letter, so the card leaves them out.',
            'Decision D9: the block lists no options like "A: text", so the card asks for an answer in your own words.',
            'Decision row U1 is not numbered D1, D2, and so on, so the canvas does not show it.',
            'The block for D9 has no row in the decision table, so the canvas does not show it.',
        ]);
    });

    it('reads plan blocks one level below Planning Decisions and Feedback', () => {
        const plan = parsePlan(PLAN);
        assert.deepEqual(plan.decisions[0].block.options, [{ id: 'A', label: '200 MB.', recommended: true }, { id: 'B', label: '500 MB.', recommended: false }]);
        assert.equal(plan.decisions[0].block.question, 'How much space may the cache use?');
        assert.ok(!plan.warnings.some((text) => /Decision/.test(text)), plan.warnings.join('\n'));
    });

    it('reports a slug title, a missing title, and tables without the expected columns', () => {
        assert.match(parseResearch('# Task Research: basemap-choices\n\n## Executive Summary\n\nx\n').warnings.join('\n'), /The title is the slug "basemap-choices"/);
        assert.match(parseResearch('## Executive Summary\n\nx\n').warnings.join('\n'), /no title heading/);
        const odd = parseResearch('# Task Research: Odd\n\n## Executive Summary\n\nx\n\n## Decisions and Feedback\n\n| ID | Choice |\n|----|--------|\n| D1 | Terrain |\n\n## Research Record\n\n### Evidence Log\n\n| Ref | Text |\n|-----|------|\n| C1 | x |\n');
        assert.deepEqual(odd.warnings, [
            'The decision table has no Group and Decision or feedback item columns, so the canvas shows none of its decisions.',
            'The evidence log has no ID and Claim or finding columns, so the canvas cannot show its sources.',
        ]);
    });
});

describe('decision cards from blocks', () => {
    it('gives a needs-input decision the block question, context, and options with the recommended one marked', () => {
        const { session } = assembled();
        const d1 = session.decisions.find((decision) => decision.id === 'D1');
        assert.deepEqual([d1.status, d1.owner, d1.question, d1.context], ['needs-input', 'user', 'Which basemap should the first release use?', 'Satellite can follow in a later release.']);
        assert.deepEqual(d1.options, [{ id: 'A', label: 'Terrain, because hikers read contours.', recommended: true }, { id: 'B', label: 'Satellite, which costs more to store.' }]);
    });

    it('marks the option a settled answer names and keeps the others as alternatives', () => {
        const { session } = assembled();
        const d2 = session.decisions.find((decision) => decision.id === 'D2');
        assert.deepEqual([d2.chosen, d2.options.map((option) => option.id), d2.rationale], ['B', ['A', 'B'], 'vector tiles, for smaller downloads']);
    });

    it('reports citations the evidence log does not list', () => {
        const { session } = assembled();
        assert.ok(session.source.warnings.includes('Research: A citation points at evidence the log does not list: W7 (D2).'), session.source.warnings.join('\n'));
        assert.ok(session.source.warnings.includes('Research: Decision row U1 is not numbered D1, D2, and so on, so the canvas does not show it.'));
    });
});

describe('the decision card always takes your own words', () => {
    let restore;
    let components;
    let makeContext;
    before(async () => {
        restore = installFakeDom();
        components = await import('../ui/components.mjs');
        ({ makeContext } = await import('./helpers/render-views.mjs'));
    });
    after(() => restore());
    const keyed = (node, key) => elements(node).find((element) => element.getAttribute('data-key') === key);

    it('lists the options, then Your own answer, and makes the text required only for your own answer', () => {
        const { session } = assembled();
        const d1 = session.decisions.find((decision) => decision.id === 'D1');
        const ctx = makeContext(session, 'research');
        const card = components.decisionCard(ctx, d1);
        const html = serialize(card);
        assert.match(html, /Which basemap should the first release use\?/);
        assert.match(html, /Terrain, because hikers read contours\.<span class="badge tone-accent rec-tag">/, 'the recommended option is marked');
        const radios = [...html.matchAll(/<input type="radio" name="decision-D1" id="decision-D1-([^"]+)"/g)].map((match) => match[1]);
        assert.deepEqual(radios, ['A', 'B', components.OWN_ANSWER], 'Your own answer comes last in the same group');
        assert.match(html, /<label class="field-label" for="decision-D1-note">Add a note \(optional\)<\/label>/);
        assert.equal(keyed(card, 'submit-D1').getAttribute('disabled'), null, 'the recommended option is preselected');

        ctx.ui.decisionDrafts.set('D1', { optionId: components.OWN_ANSWER, note: '' });
        const own = components.decisionCard(ctx, d1);
        const ownHtml = serialize(own);
        assert.match(ownHtml, /<label class="field-label" for="decision-D1-note">Your answer<\/label><textarea id="decision-D1-note"[^>]*aria-required="true"/);
        assert.equal(keyed(own, 'submit-D1').getAttribute('disabled'), '', 'an empty answer cannot be sent');
        assert.equal(keyed(own, 'submit-D1').getAttribute('data-needs-text'), 'true');
        const answered = createFeedback(session, { kind: 'answer', target: { id: 'D1' }, text: 'Terrain, then satellite in spring' }, NOW);
        assert.equal(answered.result.optionId, undefined, 'your own words go without an option');
    });

    it('offers Something else when overriding a decision that has alternatives', () => {
        const { session } = assembled();
        const d2 = { ...session.decisions.find((decision) => decision.id === 'D2'), owner: 'agent', status: 'decided' };
        const ctx = makeContext(session, 'research');
        ctx.ui.overrides.add('D2');
        const html = serialize(components.decisionCard(ctx, d2));
        assert.match(html, /Choose a different option, or say what to do instead:/);
        assert.match(html, /id="override-D2-A"/);
        assert.match(html, new RegExp(`id="override-D2-${components.OWN_ANSWER}"`));
        assert.match(html, /Something else/);
    });
});
