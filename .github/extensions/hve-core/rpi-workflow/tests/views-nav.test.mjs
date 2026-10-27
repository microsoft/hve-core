// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { buildScenario } from '../lib/scenario.mjs';
import { elements, installFakeDom } from './helpers/fake-dom.mjs';
import { initialUi, makeContext } from './helpers/render-views.mjs';

const NOW = Date.parse('2026-10-23T12:00:00.000Z');
const PHASES = ['research', 'plan', 'implement', 'review', 'followup'];

let restore;
before(() => {
    restore = installFakeDom();
});
after(() => restore());

const iconsOf = (element) => elements(element).filter((node) => node.localName === 'use').map((node) => node.getAttribute('href'));

/** Renders one phase view into a detached root, as the page does. */
async function rendered(session, phase, ui = initialUi(phase)) {
    const view = await import(`../ui/view-${phase}.mjs`);
    const root = document.createElement('div');
    for (const node of [view.renderView(makeContext(session, phase, ui))].flat(Infinity).filter(Boolean)) root.appendChild(node);
    return root;
}

describe('icon rule', () => {
    it('ends every navigating ID chip with the go-to icon and every in-place chip with the page', async () => {
        const session = buildScenario('followup', NOW);
        let navigating = 0;
        let inPlace = 0;
        for (const phase of PHASES) {
            const chips = elements(await rendered(session, phase)).filter((node) => node.localName === 'button' && node.classList.contains('id-chip'));
            for (const chip of chips) {
                const expected = chip.classList.contains('evidence-chip') ? '#i-file' : '#i-go-to';
                assert.deepEqual(iconsOf(chip), [expected], `${phase}: ${chip.textContent}`);
                assert.ok(chip.dataset.preview, `${phase}: ${chip.textContent} has a preview`);
                assert.equal(chip.getAttribute('title'), null, `${phase}: ${chip.textContent} has no native tooltip`);
                if (expected === '#i-file') inPlace += 1;
                else navigating += 1;
            }
        }
        assert.ok(navigating > 20 && inPlace > 0, `${navigating} navigating and ${inPlace} in-place chips`);
    });

    it('marks an ID inside any larger control with that control\'s icon, and leaves plain labels bare', async () => {
        const { steerPanel } = await import('../ui/components.mjs');
        const insideButton = (node) => {
            for (let current = node.parentNode; current; current = current.parentNode) {
                if (current.localName === 'button') return current;
            }
            return null;
        };
        for (const stage of PHASES) {
            const session = buildScenario(stage, NOW);
            const root = await rendered(session, stage);
            for (const node of [steerPanel(makeContext(session, stage))].flat(Infinity).filter(Boolean)) root.appendChild(node);
            for (const chip of elements(root).filter((node) => node.localName === 'span' && node.classList.contains('id-chip'))) {
                const control = insideButton(chip);
                const expected = !control ? [] : control.classList.contains('task-toggle') || control.classList.contains('board-card') ? ['#i-file'] : ['#i-go-to'];
                assert.deepEqual(iconsOf(chip), expected, `${stage}: ${chip.textContent} in ${control?.className ?? 'no control'}`);
            }
        }
    });

    it('gives an expanded evidence item an ID that navigates', async () => {
        const session = buildScenario('research', NOW);
        const finding = session.research.findings.find((item) => item.evidence?.length);
        const ui = initialUi('research');
        ui.openEvidence.add(`${finding.id}:${finding.evidence[0]}`);
        const detail = elements(await rendered(session, 'research', ui)).find((node) => node.classList.contains('evidence-detail'));
        const chip = elements(detail).find((node) => node.localName === 'button' && node.classList.contains('id-chip'));
        assert.equal(chip?.dataset.preview, finding.evidence[0]);
        assert.deepEqual(iconsOf(chip), ['#i-go-to']);
    });

    it('marks websites with the globe and never with the go-to icon', async () => {
        const { externalLink, renderMarkdown } = await import('../ui/markdown.mjs');
        const root = document.createElement('div');
        root.appendChild(externalLink('https://example.com/a', 'Example'));
        root.appendChild(renderMarkdown('See [the docs](https://example.com/docs) and https://example.org/b.', { resolveId: () => false, navigate: () => {} }));
        const links = elements(root).filter((node) => node.localName === 'a');
        assert.equal(links.length, 3);
        for (const link of links) assert.deepEqual(iconsOf(link), ['#i-globe']);
    });
});

describe('legend', () => {
    it('lists every ID family with its kind, and explains each link icon', async () => {
        const { legendContent } = await import('../ui/legend.mjs');
        const { ID_KINDS, LINK_ICONS } = await import('../ui/ids.mjs');
        const root = document.createElement('div');
        for (const node of legendContent()) root.appendChild(node);
        const examples = elements(root).filter((node) => node.classList.contains('id-chip')).map((node) => node.textContent);
        assert.deepEqual(examples.sort(), ID_KINDS.map((entry) => entry.example).sort());
        const text = root.textContent;
        for (const entry of ID_KINDS) assert.ok(text.includes(`${entry.kind} ${entry.description}`), entry.key);
        for (const entry of LINK_ICONS) assert.ok(iconsOf(root).includes(`#i-${entry.icon}`), entry.icon);
        assert.ok(elements(root).some((node) => node.getAttribute('id') === 'legendTitle'));
    });
});

describe('preview content', () => {
    it('names the kind, offers Go to, and links related IDs for every family in the scenario', async () => {
        const { previewContent } = await import('../ui/preview-content.mjs');
        const { ID_KINDS, kindOf } = await import('../ui/ids.mjs');
        const seen = new Set();
        for (const stage of PHASES) {
            const session = buildScenario(stage, NOW);
            const ctx = makeContext(session, stage);
            const ids = [session.research.questions, session.research.findings, session.research.evidence, session.research.lanes, session.decisions, session.plan.requirements, session.plan.critique?.findings ?? [], session.implementation.changes, session.implementation.discoveries, session.implementation.alignment, session.review.findings, session.review.history, session.followUps.items, session.feedback, session.plan.phases, session.plan.phases.flatMap((phase) => phase.tasks)]
                .flatMap((pool) => (pool ?? []).map((item) => item.ref ?? item.id));
            for (const id of ids) {
                const content = previewContent(ctx, id, { titleId: 'preview-title' });
                assert.ok(content, `${stage}: ${id} has a preview`);
                const root = document.createElement('div');
                root.appendChild(content.head);
                for (const node of content.body) root.appendChild(node);
                const kind = elements(root).find((node) => node.classList.contains('preview-kind'));
                assert.ok(kind.textContent.includes(kindOf(id).kind), `${id} names its kind`);
                assert.ok(elements(root).some((node) => node.localName === 'button' && node.classList.contains('preview-go')), `${id} has Go to`);
                assert.ok(elements(root).some((node) => node.getAttribute('id') === 'preview-title'), `${id} has a title`);
                for (const chip of elements(root).filter((node) => node.localName === 'button' && node.classList.contains('id-chip'))) {
                    assert.ok(chip.dataset.preview, `${id}: related ${chip.textContent} opens a nested preview`);
                }
                seen.add(kindOf(id).key);
            }
        }
        assert.deepEqual([...seen].sort(), ID_KINDS.map((entry) => entry.key).sort(), 'every family was previewed');
    });

    it('shows a website for web evidence and caps long text', async () => {
        const { previewContent, PREVIEW_TEXT_LIMIT } = await import('../ui/preview-content.mjs');
        const session = buildScenario('research', NOW);
        const web = session.research.evidence.find((item) => item.url);
        const ctx = makeContext(session, 'research');
        const content = previewContent(ctx, web.id, { titleId: 't' });
        const root = document.createElement('div');
        for (const node of content.body) root.appendChild(node);
        assert.ok(iconsOf(root).includes('#i-globe'));
        const long = { ...session.research.findings[0], title: 'word '.repeat(PREVIEW_TEXT_LIMIT) };
        const clipped = previewContent({ ...ctx, find: (id) => (id === long.id ? long : ctx.find(id)) }, long.id, { titleId: 't' });
        const text = clipped.body.map((node) => node.textContent).join(' ');
        assert.ok(text.includes(`Go to ${long.id} to read all of it.`));
        assert.ok(text.length < PREVIEW_TEXT_LIMIT * 2);
    });
});

describe('sources', () => {
    const withEditor = (ctx, editor) => ({ ...ctx, data: { ...ctx.data, editor } });
    const recordingActs = (ctx) => {
        const calls = [];
        const act = new Proxy({}, { get: (_target, name) => (...args) => calls.push([name, ...args]) });
        return { ctx: { ...ctx, act }, calls };
    };

    it('shows a cited location as a chip that opens here, with the editor only when there is one', async () => {
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { sourceChip } = await import('../ui/source-view.mjs');
        const { session } = rootSession();
        const base = recordingActs(makeContext(session, 'research'));
        const plain = document.createElement('div');
        plain.appendChild(sourceChip(base.ctx, { path: 'src/storage/quota.ts', anchor: 'estimate' }));
        const chip = elements(plain).find((node) => node.classList.contains('source-chip'));
        assert.equal(chip.localName, 'button');
        assert.deepEqual(iconsOf(chip), ['#i-file']);
        assert.equal(elements(plain).some((node) => node.classList.contains('source-editor')), false, 'no editor, no button');
        chip.listeners.click[0]({});
        assert.deepEqual(base.calls.at(-1), ['openSource', 'src/storage/quota.ts', 'estimate']);
        const editing = recordingActs(withEditor(makeContext(session, 'research'), { name: 'Visual Studio Code - Insiders' }));
        const root = document.createElement('div');
        root.appendChild(sourceChip(editing.ctx, { path: 'src/storage/quota.ts', anchor: 'estimate', status: 'file' }));
        const open = elements(root).find((node) => node.classList.contains('source-editor'));
        assert.deepEqual(iconsOf(open), ['#i-file-code']);
        open.listeners.click[0]({});
        assert.deepEqual(editing.calls.at(-1), ['openInEditor', 'src/storage/quota.ts', 'estimate']);
    });

    it('offers no editor button for a .code-workspace file', async () => {
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { sourceChip } = await import('../ui/source-view.mjs');
        const ctx = withEditor(makeContext(rootSession().session, 'research'), { name: 'VS Code' });
        const root = document.createElement('div');
        root.appendChild(sourceChip(ctx, { path: 'team.code-workspace', anchor: null, status: 'file' }));
        assert.ok(elements(root).some((node) => node.classList.contains('source-chip')));
        assert.equal(elements(root).some((node) => node.classList.contains('source-editor')), false);
    });

    it('shows a location that is not a readable file as text with the reason', async () => {
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { sourceChip } = await import('../ui/source-view.mjs');
        const ctx = withEditor(makeContext(rootSession().session, 'research'), { name: 'VS Code' });
        const root = document.createElement('div');
        root.appendChild(sourceChip(ctx, { path: 'ui/markdown.mjs', anchor: 'ID_RE', status: 'missing' }));
        assert.equal(elements(root).some((node) => node.localName === 'button'), false);
        assert.match(root.textContent, /ui\/markdown\.mjsID_REnot a file in this workspace/);
    });

    it('turns a relative link in a real artifact into a source link at the symbol after its colon', async () => {
        const { renderMarkdown } = await import('../ui/markdown.mjs');
        const opened = [];
        const fragment = renderMarkdown('* [src/storage/quota.ts](../../../src/storage/quota.ts): `estimate`\n* [guide](../../../docs/guide.md#flow)\n* [up](../../../../outside.md)', { baseDir: '.copilot-tracking/plans/2026-01-01', openSource: (...args) => opened.push(args) });
        const root = document.createElement('div');
        root.appendChild(fragment);
        const links = elements(root).filter((node) => node.classList.contains('source-link'));
        assert.equal(links.length, 2, 'the link above the workspace stays text');
        for (const link of links) {
            assert.deepEqual(iconsOf(link), ['#i-file']);
            link.listeners.click[0]({});
        }
        assert.deepEqual(opened, [['src/storage/quota.ts', 'estimate'], ['docs/guide.md', '#flow']]);
        const plain = document.createElement('div');
        plain.appendChild(renderMarkdown('[x](../x.md)', {}));
        assert.equal(elements(plain).some((node) => node.classList.contains('source-link')), false, 'no base folder, no source link');
    });

    it('explains a refused file and offers Copy path', async () => {
        const { sourceProblem, sourceSheet } = await import('../ui/source-view.mjs');
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const ctx = makeContext(rootSession().session, 'research');
        const root = document.createElement('div');
        for (const node of sourceProblem(ctx, '.env', '.env looks like it holds secrets, so the canvas does not show it.')) root.appendChild(node);
        assert.match(root.textContent, /looks like it holds secrets/);
        assert.ok(elements(root).some((node) => node.getAttribute('id') === 'fileSheetTitle'));
        const sheet = document.createElement('div');
        for (const node of sourceSheet(ctx, { path: 'docs/guide.md', start: 1, lines: ['# Guide', '', '## Flow'], total: 3, line: 3, match: 'heading', anchor: 'Flow' })) sheet.appendChild(node);
        const cited = elements(sheet).filter((node) => node.classList.contains('is-cited'));
        assert.equal(cited.length, 1);
        assert.equal(cited[0].dataset.line, '3');
        assert.match(sheet.textContent, /Line 3, the heading for Flow\./);
    });

    it('offers Show the file and the editor in the file sheet instead of vscode links', async () => {
        const { filePreview } = await import('../ui/components.mjs');
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { session } = rootSession();
        const change = session.implementation.changes.find((item) => item.files?.length);
        const ctx = withEditor(makeContext(session, 'implement'), { name: 'VS Code' });
        const root = document.createElement('div');
        for (const node of filePreview(ctx, change, change.files[0])) root.appendChild(node);
        const labels = elements(root).filter((node) => node.localName === 'button').map((node) => node.textContent);
        assert.ok(labels.includes('Show the file') && labels.includes('Open in VS Code'), labels.join(', '));
        assert.equal(elements(root).some((node) => (node.getAttribute('href') ?? '').startsWith('vscode')), false);
    });
});
