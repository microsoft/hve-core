// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
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
                const expected = !control ? [] : control.classList.contains('task-toggle') ? ['#i-file'] : ['#i-go-to'];
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

    it('teaches the change map\'s corner marks with the map\'s own glyphs, and the contrast-theme hatch', async () => {
        const { legendContent } = await import('../ui/legend.mjs');
        const root = document.createElement('div');
        for (const node of legendContent()) root.appendChild(node);
        const map = elements(root).find((node) => node.getAttribute('aria-labelledby') === 'legend-map');
        assert.match(map.textContent.replace(/\s+/g, ' '), /In Implement, a check marks a part whose change is done, a dot one in progress, and a hollow circle one still needed\. In a contrast theme, done parts are also hatched\./);
        const marks = elements(map).filter((node) => node.localName === 'svg' && node.getAttribute('class') === 'legend-mark');
        assert.deepEqual(marks.map((node) => node.firstChild.getAttribute('class')), ['diagram-mark is-done', 'diagram-mark is-active', 'diagram-mark is-needed']);
        assert.ok(marks.every((node) => node.getAttribute('aria-hidden') === 'true'), 'the words name each state, so the glyphs are decorative');
    });

    it('explains pinning previews, and that a change-map part pins only on purpose, saying pin rather than lock', async () => {
        const { legendContent } = await import('../ui/legend.mjs');
        const root = document.createElement('div');
        for (const node of legendContent()) root.appendChild(node);
        const section = (id) => elements(root).find((node) => node.getAttribute('aria-labelledby') === id).textContent;
        assert.match(section('legend-previews'), /To pin the preview, keep the pointer on the ID until the ring around the pin fills, press the pin, or middle-click the ID\. From the keyboard, press Down Arrow\. Press the pin again to unpin it\./);
        assert.match(section('legend-previews'), /In a pinned preview, hover or focus an ID to preview it too\./);
        assert.match(section('legend-map'), /it goes away when you move off\. Click the part, press Enter on it, or press the pin to pin it, then go to a task\./);
        assert.doesNotMatch(root.textContent, /\block(s|ed)?\b/i);
    });
});

describe('phase status', () => {
    it('gives Provided its word, a sprite icon, a legend entry, and a tooltip that says where the work came from', async () => {
        const { legendContent } = await import('../ui/legend.mjs');
        const { badge, PHASE_STATUS } = await import('../ui/dom.mjs');
        const { tipText } = await import('../ui/tooltips.mjs');
        const provided = PHASE_STATUS.provided;
        assert.deepEqual([provided.label, provided.icon, provided.tip], ['Provided', 'nodes', 'Provided by the user or another session']);
        const sprite = await fs.readFile(new URL('../ui/index.html', import.meta.url), 'utf8');
        assert.ok(sprite.includes(`<symbol id="i-${provided.icon}"`), 'the icon is one the sprite already has');
        const chip = badge(provided, { title: provided.tip });
        assert.equal(chip.textContent, 'Provided');
        assert.equal(tipText(chip), 'Provided by the user or another session');
        const root = document.createElement('div');
        for (const node of legendContent()) root.appendChild(node);
        const section = elements(root).find((node) => node.getAttribute('aria-labelledby') === 'legend-phase');
        assert.ok(section, 'the legend explains phase statuses');
        assert.ok(elements(section).some((node) => node.localName === 'dt' && node.textContent.trim() === 'Provided'), 'the legend names the word');
        assert.ok(iconsOf(section).includes('#i-nodes'), 'and shows its icon');
        assert.match(section.textContent, /Provided by the user or another session\. A provided phase's Source section says where its work came from\. While the agent works in the phase, it shows In progress; once the session stops there, it shows Provided\./);
    });

    it('names a provided phase\'s tab, its tooltip, and its description, and keeps the other tabs as they were', async () => {
        const { phaseTabText, PHASE_STATUS } = await import('../ui/dom.mjs');
        assert.deepEqual(phaseTabText({ phase: 'research', meta: PHASE_STATUS.provided, active: false, needs: 0, key: null }), {
            name: 'Research, Provided',
            tooltip: 'Research, Provided. Provided by the user or another session',
            description: 'Provided by the user or another session',
        });
        assert.deepEqual(phaseTabText({ phase: 'plan', meta: PHASE_STATUS.active, active: true, needs: 2, key: '2' }), {
            name: 'Plan, In progress, agent is here, 2 items need you',
            tooltip: 'Plan, In progress, agent is here, 2 items need you (2)',
            description: null,
        });
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

    it('titles a saved item of a kind the canvas no longer creates as a comment', async () => {
        const { previewContent } = await import('../ui/preview-content.mjs');
        const base = buildScenario('research', NOW);
        const saved = { id: 'FB-091', kind: 'research-request', state: 'sent', target: { id: 'F1', type: 'finding', phase: 'research' }, text: 'Check iOS quota.', createdAt: base.updatedAt, updatedAt: base.updatedAt, history: [] };
        const ctx = makeContext({ ...base, feedback: [...base.feedback, saved] }, 'research');
        const content = previewContent(ctx, 'FB-091', { titleId: 'preview-title' });
        const root = document.createElement('div');
        root.appendChild(content.head);
        for (const node of content.body) root.appendChild(node);
        assert.equal(elements(root).find((node) => node.getAttribute('id') === 'preview-title')?.textContent, 'Comment');
    });

    it('shows a task\'s markers, what it waits on, what blocks it, its changes, and the agent\'s recent work', async () => {
        const { previewContent } = await import('../ui/preview-content.mjs');
        const session = buildScenario('implement', NOW);
        const ctx = makeContext(session, 'implement');
        const preview = (id) => {
            const root = document.createElement('div');
            const content = previewContent(ctx, id, { titleId: 't' });
            for (const node of content.body) root.appendChild(node);
            return { text: elements(root).map((node) => [...node.childNodes].filter((child) => typeof child.data === 'string').map((child) => child.data).join('')).join(' ').replace(/\s+/g, ' '), chips: elements(root).filter((node) => node.localName === 'button' && node.classList.contains('id-chip')).map((node) => node.dataset.preview) };
        };
        const paused = preview('P03-T01');
        assert.match(paused.text, /Paused for you/);
        assert.match(paused.text, /Waiting on How should photo metadata writes stay safe\?/);
        assert.ok(paused.chips.includes('D6'), 'Waits on links D6');
        const blocked = preview('P04-T02');
        assert.match(blocked.text, /Blocked The device lab iOS simulators are offline until Friday\. Owner: QA\. Rerun the offline suite when the lab returns\./);
        const agent = preview('P02-T02');
        assert.match(agent.text, /Agent activity Edited src\/offline\/sync-engine\.ts \(\+12 -4\) A 412 response should mark the record as conflicted instead of retrying Ran npm test -- sync-engine: 18 passed, 1 failed/);
        assert.doesNotMatch(preview('P03-T01').text, /Agent activity/, 'only the agent\'s task shows activity');
        assert.ok(preview('P02-T01').chips.includes('CH-003'), 'a task links its changes');
    });


    it('links a research finding or decision and the plan tasks that cite it, both ways', async () => {
        const { previewContent } = await import('../ui/preview-content.mjs');
        const session = buildScenario('implement', NOW);
        const task = session.plan.phases[0].tasks[0];
        task.research = ['F1', 'D1'];
        const ctx = makeContext(session, 'implement');
        const chipsOf = (id) => {
            const root = document.createElement('div');
            for (const node of previewContent(ctx, id, { titleId: 't' }).body) root.appendChild(node);
            return elements(root).filter((node) => node.localName === 'button' && node.classList.contains('id-chip')).map((node) => node.dataset.preview);
        };
        assert.ok(chipsOf('F1').includes(task.id), 'a finding lists the tasks that cite it');
        assert.ok(chipsOf('D1').includes(task.id), 'so does a research decision');
        assert.ok(chipsOf(task.id).includes('F1') && chipsOf(task.id).includes('D1'), 'a task lists the research it cites');
        assert.ok(!chipsOf('F2').includes(task.id));
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

describe('tooltips', () => {
    it('take over a title once, keep it as a description when it says more, and name the shortcut', async () => {
        const { tipText } = await import('../ui/tooltips.mjs');
        const { button, h } = await import('../ui/dom.mjs');
        const comment = button('Comment', { iconName: 'message', hideLabel: true, attrs: { 'aria-keyshortcuts': 'c' } });
        assert.equal(tipText(comment), 'Comment (c)');
        assert.equal(comment.hasAttribute('title'), false, 'no native tooltip doubles it');
        assert.equal(comment.getAttribute('data-tip'), 'Comment');
        assert.equal(comment.hasAttribute('aria-description'), false, 'the title only repeated the name');
        assert.equal(tipText(comment), 'Comment (c)', 'reading it again gives the same tooltip');
        const badge = h('span', { class: 'badge', title: 'The file changed 2 hours ago.' }, 'Updated');
        assert.equal(tipText(badge), 'The file changed 2 hours ago.');
        assert.equal(badge.getAttribute('aria-description'), 'The file changed 2 hours ago.', 'a title that says more stays as a description');
        assert.equal(tipText(h('span', null, 'plain')), '');
    });
});

describe('sources', () => {
    const withEditor = (ctx, editor) => ({ ...ctx, data: { ...ctx.data, editor } });
    const recordingActs = (ctx) => {
        const calls = [];
        const act = new Proxy({}, { get: (_target, name) => (...args) => calls.push([name, ...args]) });
        return { ctx: { ...ctx, act }, calls };
    };

    it('shows a website source with one globe and a readable label, and other sources as prose', async () => {
        const { rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { evidenceSource } = await import('../ui/source-view.mjs');
        const ctx = makeContext(rootSession().session, 'research');
        const render = (item) => {
            const root = document.createElement('td');
            root.appendChild(evidenceSource(ctx, item));
            return root;
        };
        const globes = (root) => elements(root).filter((node) => node.localName === 'use' && node.getAttribute('href') === '#i-globe').length;
        const titled = render({ id: 'W1', source: '[Storage quotas](https://developer.mozilla.org/q)', url: 'https://developer.mozilla.org/q' });
        assert.equal(globes(titled), 1);
        assert.equal(titled.textContent.trim().startsWith('Storage quotas'), true, 'a Markdown link shows its title');
        const bare = render({ id: 'W2', source: 'Vendor terms page, https://example.com/terms/tiles; checked twice', url: 'https://example.com/terms/tiles' });
        assert.equal(globes(bare), 1);
        assert.match(bare.textContent, /^Vendor terms page, example\.com\/…\/tiles/);
        const sample = render({ id: 'W3', source: 'MDN: If-Match header', url: 'https://developer.mozilla.org/if-match' });
        assert.equal(globes(sample), 1, 'a source kept apart from its address becomes the link');
        assert.match(sample.textContent, /^MDN: If-Match header/);
        const prose = render({ id: 'W4', source: 'Copilot SDK `canvas.d.ts`, the VS Code bundle' });
        assert.equal(elements(prose).filter((node) => node.localName === 'code').map((node) => node.textContent).join(), 'canvas.d.ts', 'prose stays prose; only its code spans are code');
        assert.equal(globes(prose), 0);
    });

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
        assert.match(root.textContent, /^markdown\.mjsnot a file in this workspaceui\/ · ID_RE$/, 'the file name and the reason, then its folder and anchor');
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

describe('change-map part previews', () => {
    const AFTER = [
        'flowchart LR',
        '    subgraph ws["`<code>lib/source/workspace.mjs</code>`"]',
        '        pair["`**<code>earlierDocuments()</code>**',
        '        pairs documents by name',
        '        changed · P01, P02`"]',
        '    end',
        '    subgraph ui["`<code>ui/</code>`"]',
        '        nav["`**<code>navigate()</code>**',
        '        changed · P02`"]',
        '    end',
        '    subgraph guides["Canvas docs"]',
        '        readme["`**<code>README.md</code>**',
        '        changed · P03`"]',
        '    end',
        '    plain["A part no phase changes"]',
        '    pair --> nav',
        '    nav -.-> readme',
        '    pair --> plain',
        '    classDef changed stroke-width:3px',
        '    class pair,nav,readme changed',
    ].join('\n');
    const BEFORE = ['flowchart LR', '    subgraph ws["`<code>lib/source/workspace.mjs</code>`"]', '        pair["`**<code>earlierDocuments()</code>**', '        research and plans only', '        changed · P01, P02`"]', '    end', '    classDef changed stroke-width:3px', '    class pair changed'].join('\n');
    const task = (id, title, status, references) => ({ id, title, status, references, goals: '', requirements: [], research: [], details: [], dependencies: [], sectionId: `task-${id.toLowerCase()}` });
    const session = () => {
        const base = buildScenario('implement', NOW);
        return {
            ...base,
            plan: {
                ...base.plan,
                diagram: { before: BEFORE, after: AFTER, phaseNodes: { P01: ['pair'], P02: ['pair', 'nav'], P03: ['readme'] }, tagged: true },
                phases: [
                    { id: 'P01', title: 'Pair documents', status: 'done', tasks: [task('P01-T01', 'Pair each document with its work', 'done', ['.github/extensions/hve-core/rpi-workflow/lib/source/workspace.mjs: `earlierDocuments`']), task('P01-T02', 'Write the guide', 'done', ['docs/rpi/README.md'])] },
                    { id: 'P02', title: 'Navigate', status: 'in-progress', tasks: [task('P02-T01', 'Move between documents', 'in-progress', ['.github/extensions/hve-core/rpi-workflow/ui/app.mjs: `navigate`']), task('P02-T02', 'Keep the web app', 'todo', ['src/webapp.mjs'])] },
                    { id: 'P03', title: 'Docs', status: 'todo', tasks: [task('P03-T01', 'Describe the dropdown', 'todo', ['docs/guide.md']), task('P03-T02', 'Add a revision row', 'todo', [])] },
                ],
            },
        };
    };
    const preview = async (ctx, id) => {
        const { previewContent } = await import('../ui/preview-content.mjs');
        const content = previewContent(ctx, id, { titleId: 'part-title' });
        if (!content) return null;
        const root = document.createElement('div');
        root.appendChild(content.head);
        for (const node of content.body) root.appendChild(node);
        return root;
    };
    const chipsOf = (root) => elements(root).filter((node) => node.localName === 'button' && node.classList.contains('id-chip')).map((node) => node.dataset.preview);

    it('finds a part with its boxes, phases, and the tasks whose References name its file, where a folder names the files inside it', async () => {
        const { mapPart } = await import('../ui/map-part.mjs');
        const pair = mapPart(session(), 'part:after:pair');
        assert.deepEqual(pair.boxes.map((box) => box.id), ['ws']);
        assert.deepEqual(pair.phases.map((phase) => phase.id), ['P01', 'P02']);
        assert.deepEqual(pair.paths, ['lib/source/workspace.mjs']);
        assert.deepEqual(pair.tasks.map((item) => item.id), ['P01-T01']);
        assert.equal(pair.matched, true);
        assert.deepEqual(mapPart(session(), 'part:after:nav').tasks.map((item) => item.id), ['P02-T01'], 'ui/ names ui/app.mjs, not src/webapp.mjs');
        const readme = mapPart(session(), 'part:after:readme');
        assert.deepEqual(readme.tasks.map((item) => item.id), ['P03-T01', 'P03-T02'], 'no task names README.md, so every task in P03 shows');
        assert.equal(readme.matched, false);
        assert.equal(mapPart(session(), 'part:before:pair').node.label, 'earlierDocuments(), research and plans only', 'Before reads its own label');
        assert.deepEqual(mapPart(session(), 'part:after:plain').phases, []);
        assert.equal(mapPart(session(), 'part:after:missing'), null);
        assert.equal(mapPart(session(), 'P01-T01'), null);
    });

    it('previews a part\'s name, boxes, change, progress, phases, and tasks, landing the keyboard on the first task', async () => {
        const ctx = makeContext(session(), 'implement');
        const root = await preview(ctx, 'part:after:pair');
        const text = root.textContent.replace(/\s+/g, ' ');
        assert.match(text, /^Change map part/);
        assert.ok(!elements(root).some((node) => node.classList?.contains('preview-go')), 'a part has no place to go to');
        const title = elements(root).find((node) => node.getAttribute('id') === 'part-title');
        assert.equal(title.textContent, 'earlierDocuments()');
        assert.ok(elements(title).some((node) => node.localName === 'code'), 'the code name keeps its code face');
        assert.match(text, /pairs documents by name/);
        assert.match(text, /In lib\/source\/workspace\.mjs/);
        assert.match(text, /Changed in P01 and P02/);
        assert.match(text, /In progress/, 'P02 is in progress, so the part is');
        assert.deepEqual(chipsOf(root), ['P01', 'P02', 'P01-T01']);
        assert.match(text, /Pair each document with its work/);
        assert.match(text, /The tasks in P01 and P02 whose References name lib\/source\/workspace\.mjs\./);
        const first = elements(root).find((node) => node.dataset?.previewFocus === '');
        assert.equal(first?.dataset.preview, 'P01-T01');
    });

    it('says when no task names the part\'s file, marks a part still needed, and has no preview for a part the map lacks', async () => {
        const ctx = makeContext(session(), 'implement');
        const text = (await preview(ctx, 'part:after:readme')).textContent.replace(/\s+/g, ' ');
        assert.match(text, /Still needed/);
        assert.match(text, /No task in P03 names README\.md, so every task in it shows\./);
        assert.equal(await preview(ctx, 'part:after:missing'), null);
    });
});

describe('session tree', () => {
    const PROJECT_PATH = '.copilot-tracking/rpi-sessions/2026-01-14/project-x/project-x-state.json';

    /**
     * The Follow-up view of a session whose tree holds a parent continued from another session folder. The
     * context's actions record what they are asked to show.
     */
    async function followUp({ continues = null, calls = [] }) {
        const { PATHS, rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { session: shown } = rootSession();
        shown.followUps.tree = {
            key: '2026-01-15/trail-maps',
            date: '2026-01-15',
            name: 'Offline trail maps',
            tasks: [
                { id: 'trail-maps', title: 'Offline trail maps', status: 'completed', depth: 0, statePath: PATHS.rootState, parent: null, shown: true, continues },
                { id: 'trail-maps-fixes', title: 'Offline trail maps review fixes', status: 'completed', depth: 1, statePath: PATHS.childState, parent: PATHS.rootState, shown: false, continues: null },
            ],
        };
        const ctx = makeContext(shown, 'followup');
        ctx.act = { showTask: (ref) => calls.push(ref) };
        const view = await import('../ui/view-followup.mjs');
        const root = document.createElement('div');
        for (const node of [view.renderView(ctx)].flat(Infinity).filter(Boolean)) root.appendChild(node);
        return { root, ctx, view, calls };
    }

    const textOf = (node) => node.textContent.replace(/\s+/g, ' ');
    const itemFor = (root, id) => elements(root).find((node) => node.localName === 'li' && node.dataset?.task === id);

    it('counts every loop of the session in the outline, and lists each one', async () => {
        const { root, ctx, view } = await followUp({});
        assert.equal(view.outline(ctx).find((item) => item.id === 'session-loops').count, 2);
        assert.ok(itemFor(root, 'trail-maps'));
        assert.ok(itemFor(root, 'trail-maps-fixes'));
    });

    it('offers Show on each loop that is not the shown one, and marks the shown loop with no control', async () => {
        const { PATHS } = await import('./helpers/rpi-fixture.mjs');
        const { root, calls } = await followUp({});
        const show = elements(root).find((node) => node.getAttribute('data-key') === 'followup-show-trail-maps-fixes');
        assert.equal(show.localName, 'button', 'a native button takes Enter and Space');
        assert.equal(show.getAttribute('aria-label'), 'Show Offline trail maps review fixes');
        show.listeners.click[0]({});
        assert.deepEqual(calls, [{ statePath: PATHS.childState }]);
        const shownCard = itemFor(root, 'trail-maps').childNodes.find((node) => node.classList?.contains('tree-card'));
        assert.match(textOf(shownCard), /Shown/);
        assert.equal(elements(shownCard).filter((node) => node.localName === 'button').length, 0, 'the shown loop has no Show');
    });

    it('names a parent continued from another session folder above its card, with a labeled Show', async () => {
        const parent = { id: 'project-x', title: 'Project X', statePath: PROJECT_PATH, session: '2026-01-14/project-x', status: 'running' };
        const { root, calls } = await followUp({ continues: parent });
        const line = elements(root).find((node) => node.classList.contains('tree-continues'));
        assert.match(textOf(line), /^Continues Project X from another session/);
        const buttons = elements(line).filter((node) => node.localName === 'button');
        assert.equal(buttons.length, 1, 'the parent offers Show');
        assert.equal(buttons[0].getAttribute('aria-label'), 'Show Project X, from another session');
        assert.deepEqual(calls, []);
        for (const listener of buttons[0].listeners?.click ?? []) listener();
        assert.deepEqual(calls, [{ statePath: PROJECT_PATH }], 'Show switches to the parent by its state path');
    });
});

describe('panel outcomes', () => {
    it('names the session in each outcome, and names no session in a wait the agent was not asked about', async () => {
        const { panelOutcome } = await import('../ui/components.mjs');
        assert.deepEqual(panelOutcome({ outcome: 'opened' }, 'Map API'), { tone: 'accent', icon: 'panel', text: 'Opened a canvas for Map API in a new panel.' });
        assert.equal(panelOutcome({ outcome: 'focused' }, 'Map API').text, 'Focused the canvas for Map API, which was already open in a panel.');
        assert.equal(panelOutcome({ outcome: 'asked' }, 'Map API').text, 'Asked the agent to open a canvas for Map API. Look for the line in the chat.');
        assert.equal(panelOutcome({ outcome: 'failed', reason: 'The message could not be sent.' }, 'Map API').text, 'Opening a canvas for Map API failed: The message could not be sent.');
        const same = panelOutcome({ outcome: 'wait', retryAfterMs: 20000, sameSession: true }, 'Map API');
        assert.equal(same.text, 'The agent was just asked to open a canvas for Map API. Wait 20 seconds, then try again.');
        assert.equal(same.tone, 'attention');
        const other = panelOutcome({ outcome: 'wait', retryAfterMs: 20000, sameSession: false }, 'Map tiles');
        assert.equal(other.text, 'The agent was just asked to open a canvas for another session. Wait 20 seconds, then try again.');
        assert.doesNotMatch(other.text, /Map tiles/);
    });
});

describe('session menu', () => {
    const CHILD_PATH = '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/map-api-state.json';
    const textOf = (node) => node.textContent.replace(/\s+/g, ' ');
    const byKey = (root, key) => elements(root).find((node) => node.getAttribute('data-key') === key);

    /**
     * The session menu's content, as the page builds it, for a session with three loops: the shown one, and
     * two others. The menu shows the session's loops, then the other sessions, and no group of child sessions.
     */
    async function menu({ onShow } = {}) {
        const { sessionMenuNodes } = await import('../ui/components.mjs');
        const { PATHS, rootSession } = await import('./helpers/rpi-fixture.mjs');
        const { session: shown } = rootSession();
        shown.followUps.tree = {
            key: '2026-01-15/trail-maps',
            date: '2026-01-15',
            name: 'Offline trail maps',
            tasks: [
                { id: 'trail-maps', title: 'Offline trail maps', status: 'completed', depth: 0, statePath: PATHS.rootState, parent: null, shown: true, continues: null },
                { id: 'map-api', title: 'Map API', status: 'running', depth: 1, statePath: CHILD_PATH, parent: PATHS.rootState, shown: false, continues: null },
                { id: 'trail-maps-fixes', title: 'Offline trail maps review fixes', status: 'stopped', depth: 1, statePath: PATHS.childState, parent: PATHS.rootState, shown: false, continues: null },
            ],
        };
        const calls = [];
        const ctx = makeContext(shown, 'followup');
        ctx.act = { showTask: (ref) => calls.push({ show: ref }) };
        const root = document.createElement('div');
        for (const node of sessionMenuNodes(ctx, { following: true, onShow })) root.appendChild(node);
        return { root, calls, ctx };
    }

    it('lists this session\'s loops above the other sessions, with no group of child sessions', async () => {
        const { root } = await menu();
        const at = (test) => root.childNodes.findIndex(test);
        const loops = at((node) => node.localName === 'h3' && textOf(node) === 'Loops in this session');
        const others = at((node) => node.localName === 'h3' && textOf(node) === 'Other sessions');
        assert.ok(loops >= 0 && others > loops, `loops ${loops}, other sessions ${others}`);
        assert.equal(elements(root).filter((node) => node.classList.contains('child-sessions')).length, 0);
    });

    it('offers Show on each loop that is not the shown one, with its own key and name', async () => {
        const { root, calls } = await menu();
        const show = byKey(root, 'menu-show-map-api');
        assert.equal(show.localName, 'button', 'a native button takes Enter and Space');
        assert.equal(show.getAttribute('type'), 'button');
        assert.notEqual(show.getAttribute('tabindex'), '-1', 'the control stays in the tab order');
        assert.equal(show.getAttribute('aria-label'), 'Show Map API');
        show.listeners.click[0]({});
        assert.deepEqual(calls, [{ show: { statePath: CHILD_PATH } }]);
        const shownCard = elements(root).find((node) => node.localName === 'li' && node.dataset?.task === 'trail-maps').childNodes.find((node) => node.classList?.contains('tree-card'));
        assert.equal(elements(shownCard).filter((node) => node.localName === 'button').length, 0, 'the shown loop has no Show');
    });

    it('hands a loop\'s Show to the menu, which closes itself and shows the loop', async () => {
        const chosen = [];
        const { root, calls } = await menu({ onShow: (task) => chosen.push(task.id) });
        byKey(root, 'menu-show-map-api').listeners.click[0]({});
        assert.deepEqual(chosen, ['map-api']);
        assert.deepEqual(calls, [], 'the menu, not the view, switches the canvas');
    });

    it('keeps every loop control in the tab order, with a key of its own, so focus returns to it after a re-render', async () => {
        const { root } = await menu();
        const controls = elements(root).filter((node) => node.localName === 'button');
        assert.equal(controls.length, 2);
        for (const control of controls) {
            assert.equal(control.getAttribute('type'), 'button');
            assert.notEqual(control.getAttribute('tabindex'), '-1');
        }
        const keys = elements(root).map((node) => node.getAttribute('data-key')).filter(Boolean);
        assert.equal(new Set(keys).size, keys.length, keys.join(', '));
    });
});
