// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';

import { createFeedback, recordActivity } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { createStore, dataRoot, resolveCopilotHome } from '../lib/store.mjs';

const NOW = '2026-10-23T12:00:00.000Z';
const HERE = path.dirname(fileURLToPath(import.meta.url));
let tmp;

before(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-store-'));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

const fresh = async (name) => createStore({ root: path.join(tmp, name), pollMs: 20, lockWaitMs: 4000 });

describe('paths', () => {
    it('uses COPILOT_HOME when set and ~/.copilot otherwise', () => {
        assert.equal(resolveCopilotHome({ COPILOT_HOME: '/x/home' }, '/u'), '/x/home');
        assert.equal(resolveCopilotHome({ COPILOT_HOME: '' }, '/u'), path.join('/u', '.copilot'));
        assert.equal(dataRoot('/x/home'), path.join('/x/home', 'extension-data', 'hve-core-rpi-workflow'));
    });
});

describe('sessions', () => {
    it('writes atomically and reads back', async () => {
        const store = await fresh('roundtrip');
        const created = await store.create(buildScenario('research'));
        const loaded = await store.load(created.id);
        assert.equal(loaded.revision, created.revision);
        const files = await fs.readdir(path.join(store.root, 'sessions'));
        assert.deepEqual(files.filter((f) => f.endsWith('.tmp')), []);
        store.close();
    });

    it('upgrades a document saved before the session tree, so the page can render it', async () => {
        const store = await fresh('upgrade');
        const dir = path.join(store.root, 'sessions');
        await fs.mkdir(dir, { recursive: true });
        const old = buildScenario('implement');
        delete old.followUps.tree;
        old.followUps.lineage = [];
        old.scenario = { ...old.scenario, userChanges: 4 };
        await fs.writeFile(path.join(dir, `${old.id}.json`), JSON.stringify(old));
        const loaded = await store.load(old.id);
        assert.equal('lineage' in loaded.followUps, false);
        assert.deepEqual(loaded.followUps.tree, {
            key: null,
            date: null,
            name: old.task.title,
            tasks: [{ id: old.task.id, title: old.task.title, status: 'running', depth: 0, statePath: null, parent: null, shown: true, continues: null }],
        });
        const { session } = await store.update(old.id, (current) => recordActivity(current, { text: 'Still works' }, new Date().toISOString()));
        assert.ok(session.followUps.tree, 'the next write keeps the upgraded shape');
        store.close();
    });

    it('reports corrupt and future files and leaves them in place', async () => {
        const store = await fresh('corrupt');
        const dir = path.join(store.root, 'sessions');
        await fs.mkdir(dir, { recursive: true });
        await fs.writeFile(path.join(dir, 'broken.json'), '{ not json');
        await assert.rejects(store.load('broken'), { code: 'storage_corrupt' });
        assert.equal(await fs.readFile(path.join(dir, 'broken.json'), 'utf8'), '{ not json');
        const future = { ...buildScenario('research'), id: 'future', version: 9 };
        await fs.writeFile(path.join(dir, 'future.json'), JSON.stringify(future));
        await assert.rejects(store.load('future'), { code: 'storage_unsupported' });
        await fs.writeFile(path.join(dir, 'foreign.json'), JSON.stringify({ format: 'someone-else', version: 1 }));
        await assert.rejects(store.update('foreign', (s) => ({ session: s, result: null })), { code: 'storage_corrupt' });
        await assert.rejects(store.load('../escape'), { code: 'invalid_input' });
        store.close();
    });

    it('refuses to replace a session with user changes unless asked, and keeps a backup until the next replace', async () => {
        const store = await fresh('replace');
        const scenario = buildScenario('research');
        const backupFile = path.join(store.root, 'sessions', `${scenario.id}.previous.json`);
        await store.create(scenario);
        await store.create(buildScenario('research'));
        await assert.rejects(fs.readFile(backupFile, 'utf8'), { code: 'ENOENT' }, 'replacing an untouched sample keeps no backup');
        await store.update(scenario.id, (s) => createFeedback(s, { kind: 'comment', text: 'mine' }, NOW), { by: 'user' });
        await assert.rejects(store.create(buildScenario('plan')), { code: 'scenario_exists' });
        const replaced = await store.create(buildScenario('plan'), { replace: true });
        assert.equal(replaced.session.activePhase, 'plan');
        const backup = JSON.parse(await fs.readFile(backupFile, 'utf8'));
        assert.equal(backup.scenario.userChanges, 1);
        await store.create(buildScenario('implement'));
        assert.deepEqual(JSON.parse(await fs.readFile(backupFile, 'utf8')), backup, 'a later stage load keeps the backup');
        store.close();
    });

    it('reapplies a change on a fresh read when another writer commits first', async () => {
        const store = await fresh('reapply');
        const scenario = await store.create(buildScenario('research'));
        const file = path.join(store.root, 'sessions', `${scenario.id}.json`);
        // Simulates a writer that ignored the lock and committed while this update ran.
        const sneak = (text) => {
            const { session } = recordActivity(JSON.parse(readFileSync(file, 'utf8')), { text }, NOW);
            writeFileSync(file, JSON.stringify(session));
        };
        let first = true;
        const result = await store.update(scenario.id, (s) => {
            if (first) {
                first = false;
                sneak('theirs');
            }
            return recordActivity(s, { text: 'mine' }, NOW);
        });
        const texts = result.session.implementation.activity.map((line) => line.text);
        assert.ok(texts.includes('theirs') && texts.includes('mine'));
        assert.equal(result.session.revision, scenario.revision + 2);
        await assert.rejects(store.update(scenario.id, (s) => {
            sneak('again');
            return recordActivity(s, { text: 'never' }, NOW);
        }), { code: 'storage_busy' });
        const stored = await store.load(scenario.id);
        assert.equal(stored.implementation.activity.filter((line) => line.text === 'again').length, 3);
        assert.ok(!stored.implementation.activity.some((line) => line.text === 'never'));
        store.close();
    });

    it('never writes under or removes a lock another process took over', async () => {
        const store = createStore({ root: path.join(tmp, 'stolen'), lockWaitMs: 30 });
        const scenario = await store.create(buildScenario('research'));
        const lock = path.join(store.root, 'sessions', `${scenario.id}.json.lock`);
        const theirs = '4242 0123456789abcdef01234567 2026-10-23T12:00:00.000Z\n';
        await assert.rejects(store.update(scenario.id, (s) => {
            writeFileSync(lock, theirs);
            return recordActivity(s, { text: 'mine' }, NOW);
        }), { code: 'storage_busy' });
        assert.equal(await fs.readFile(lock, 'utf8'), theirs);
        assert.equal((await store.load(scenario.id)).revision, scenario.revision);
        const old = new Date(Date.now() - 60000);
        await fs.utimes(lock, old, old);
        const late = createStore({ root: store.root, lockStaleMs: 1000 });
        const written = await late.update(scenario.id, (s) => recordActivity(s, { text: 'after takeover' }, NOW));
        assert.equal(written.changed, true);
        await assert.rejects(fs.access(lock), { code: 'ENOENT' });
        assert.deepEqual((await fs.readdir(path.dirname(lock))).filter((name) => name.endsWith('.aside')), []);
        store.close();
        late.close();
    });

    it('loses no updates when two processes write at once', async () => {
        const root = path.join(tmp, 'concurrent');
        const store = createStore({ root });
        const scenario = await store.create(buildScenario('implement'));
        const worker = path.join(HERE, 'helpers', 'store-writer.mjs');
        const run = (tag) => new Promise((resolve, reject) => {
            const child = spawn(process.execPath, [worker, root, scenario.id, tag, '25'], { stdio: ['ignore', 'ignore', 'pipe'] });
            let stderr = '';
            child.stderr.on('data', (chunk) => {
                stderr += chunk;
            });
            child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(stderr || `exit ${code}`))));
        });
        await Promise.all([run('a'), run('b')]);
        const final = await store.load(scenario.id);
        const lines = final.implementation.activity.filter((line) => /^(a|b) \d+$/.test(line.text));
        assert.equal(lines.length, 50);
        assert.equal(final.revision, scenario.revision + 50);
        store.close();
    });

    it('recovers from a stale lock', async () => {
        const store = createStore({ root: path.join(tmp, 'stale'), lockStaleMs: 50 });
        const scenario = await store.create(buildScenario('research'));
        const lock = path.join(store.root, 'sessions', `${scenario.id}.json.lock`);
        await fs.writeFile(lock, 'dead');
        const old = new Date(Date.now() - 60000);
        await fs.utimes(lock, old, old);
        const result = await store.update(scenario.id, (s) => recordActivity(s, { text: 'after stale lock' }, NOW));
        assert.equal(result.changed, true);
        store.close();
    });

    it('detects changes written by another process', async () => {
        const root = path.join(tmp, 'watch');
        const watcherStore = createStore({ root, pollMs: 20 });
        const writerStore = createStore({ root });
        const scenario = await writerStore.create(buildScenario('research'));
        const stop = watcherStore.watch(scenario.id);
        await new Promise((resolve) => setTimeout(resolve, 60));
        const seen = new Promise((resolve) => watcherStore.events.once('change', (_id, session) => resolve(session.revision)));
        const written = await writerStore.update(scenario.id, (s) => recordActivity(s, { text: 'external' }, NOW));
        assert.equal(await seen, written.session.revision);
        stop();
        watcherStore.close();
        writerStore.close();
    });
});

describe('preferences', () => {
    it('defaults, saves, and validates', async () => {
        const store = await fresh('prefs');
        assert.deepEqual(await store.loadPreferences(), { theme: 'system', contrast: 'standard' });
        assert.deepEqual(await store.savePreferences({ theme: 'dark' }), { theme: 'dark', contrast: 'standard' });
        assert.deepEqual(await store.loadPreferences(), { theme: 'dark', contrast: 'standard' });
        await assert.rejects(store.savePreferences({ theme: 'purple' }), { code: 'invalid_input' });
        await assert.rejects(store.savePreferences({ text: 'large' }), { code: 'invalid_input' });
        store.close();
    });
});
