// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { sourceLocations } from '../lib/source/locations.mjs';
import { checkSourceLocations } from '../lib/source/workspace.mjs';
import { writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

describe('reading code evidence locations', () => {
    it('reads a path with its symbol, and several locations split by semicolons', () => {
        assert.deepEqual(sourceLocations('`ui/markdown.mjs` `ID_RE`; ui/app.mjs `resolve`'), [
            { path: 'ui/markdown.mjs', anchor: 'ID_RE' },
            { path: 'ui/app.mjs', anchor: 'resolve' },
        ]);
        assert.deepEqual(sourceLocations('src/inspections/InspectionForm.tsx (useInspectionForm)'), [{ path: 'src/inspections/InspectionForm.tsx', anchor: 'useInspectionForm' }]);
        assert.deepEqual(sourceLocations('package.json scripts'), [{ path: 'package.json', anchor: 'scripts' }]);
        assert.deepEqual(sourceLocations('.github/skills/rpi/rpi-research/SKILL.md Flow step 3'), [{ path: '.github/skills/rpi/rpi-research/SKILL.md', anchor: 'Flow step 3' }]);
    });

    it('resolves a Markdown link against the artifact folder and keeps its fragment', () => {
        assert.deepEqual(sourceLocations('[docs/guide.md](../../../docs/guide.md#flow): the Flow section', '.copilot-tracking/research/2026-01-01'), [{ path: 'docs/guide.md', anchor: '#flow' }]);
        assert.deepEqual(sourceLocations('[lib/a.mjs](../../../lib/a.mjs) `load`', '.copilot-tracking/research/2026-01-01'), [{ path: 'lib/a.mjs', anchor: 'load' }]);
    });

    it('finds no location in a source without a path', () => {
        assert.deepEqual(sourceLocations('find over .copilot-tracking'), []);
        assert.deepEqual(sourceLocations('the read/write split'), []);
        assert.deepEqual(sourceLocations('VS Code 1.144 release notes'), []);
        assert.deepEqual(sourceLocations('https://example.com/a.md'), []);
        assert.deepEqual(sourceLocations('`lib/source/` folder'), [{ path: 'lib/source', anchor: 'folder' }]);
        assert.deepEqual(sourceLocations('scripts/linting/schemas/*-state.schema.json; scripts/tests/a.Tests.ps1'), [{ path: 'scripts/tests/a.Tests.ps1', anchor: null }]);
        assert.deepEqual(sourceLocations('.github/skills/rpi/*/templates H1 lines'), []);
    });
});

describe('reading locations from hostile text', () => {
    it('stays fast on long runs of brackets, commas, and slashes, and reads at most 4,000 characters', () => {
        for (const hostile of ['['.repeat(100000), `${','.repeat(100000)}x`, `a${'/'.repeat(100000)}b.md`, `[x](${'a'.repeat(100000)}`]) {
            const started = Date.now();
            sourceLocations(hostile);
            assert.ok(Date.now() - started < 200, `${hostile.slice(0, 12)}: ${Date.now() - started} ms`);
        }
        assert.deepEqual(sourceLocations(`${'x '.repeat(2000)}; src/late.ts`), []);
        assert.deepEqual(sourceLocations('src/a.ts,,,,'), [{ path: 'src/a.ts', anchor: null }]);
    });
});

describe('checking cited locations', () => {
    let tmp;
    before(async () => {
        tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-locations-')));
        await writeFixtureWorkspace(path.join(tmp, 'repo'));
        await fs.writeFile(path.join(tmp, 'repo', '.env'), 'TOKEN=x');
    });
    after(async () => {
        await fs.rm(tmp, { recursive: true, force: true });
    });

    it('marks each location and reports one problem per evidence ID with missing paths', async () => {
        const at = (target) => ({ path: target, anchor: null });
        const session = { research: { evidence: [
            { id: 'C1', locations: [at('src/storage/quota.ts')] },
            { id: 'C2', locations: [at('ui/markdown.mjs'), at('src/map'), at('ui/app.mjs')] },
            { id: 'C3', locations: [at('../outside.md')] },
            { id: 'C4', locations: [at('.env')] },
            { id: 'C5', locations: [at('a.md'), at('b.md'), at('c.md')] },
            { id: 'W1' },
        ] } };
        const problems = await checkSourceLocations({ root: path.join(tmp, 'repo') }, session);
        assert.deepEqual(session.research.evidence.slice(0, 4).map((item) => item.locations.map((location) => location.status)), [['file'], ['missing', 'folder', 'missing'], ['outside'], ['hidden']]);
        assert.deepEqual(problems, [
            'Research: C2 cites ui/markdown.mjs and ui/app.mjs, which are not files in this workspace; code evidence cites workspace-relative paths.',
            'Research: C3 cites ../outside.md, which is not a file in this workspace; code evidence cites workspace-relative paths.',
            'Research: C5 cites a.md, b.md, and c.md, which are not files in this workspace; code evidence cites workspace-relative paths.',
        ]);
    });
});
