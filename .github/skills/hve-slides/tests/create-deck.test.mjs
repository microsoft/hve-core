// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import test from 'node:test';
import assert from 'node:assert/strict';
import { copyFile, mkdtemp, mkdir, readFile, writeFile, readdir, realpath, rm, symlink } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createDeck, parseArguments, templateFiles } from '../scripts/create-deck.mjs';

async function workspace(t) {
  const root = await mkdtemp(path.join(tmpdir(), 'hve-slide-starter-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return realpath(root);
}

test('copies only the declared starter and personalizes metadata without installing', async t => {
  const root = await workspace(t);
  const destination = await createDeck({ repoRoot: root, slug: 'contributor-tour', title: 'A title <with> "quotes"' });
  assert.equal(destination, path.join(root, 'slides/contributor-tour'));
  assert.deepEqual((await readdir(destination)).sort(), [...templateFiles].sort());
  const manifest = JSON.parse(await readFile(path.join(destination, 'package.json'), 'utf8'));
  const lock = JSON.parse(await readFile(path.join(destination, 'package-lock.json'), 'utf8'));
  const config = JSON.parse(await readFile(path.join(destination, 'deck.json'), 'utf8'));
  assert.equal(manifest.name, 'contributor-tour');
  assert.equal(lock.name, manifest.name);
  assert.equal(lock.packages[''].name, manifest.name);
  assert.deepEqual(lock.packages[''].dependencies, manifest.dependencies);
  assert.equal(config.title, 'A title <with> "quotes"');
  assert.match(await readFile(path.join(destination, '.npmrc'), 'utf8'), /registry=https:\/\/registry\.npmjs\.org\//);
  assert.ok(!await readFile(path.join(destination, 'deck.js'), 'utf8').then(text => text.includes('RPI Agent')));
  assert.match(await readFile(path.join(destination, 'bundle.mjs'), 'utf8'), /export function createStandaloneHtml/);
});

test('refuses existing directories and files without changing them', async t => {
  const root = await workspace(t);
  await mkdir(path.join(root, 'slides/keep-me'), { recursive: true });
  await writeFile(path.join(root, 'slides/keep-me/user.txt'), 'Keep this text.');
  await assert.rejects(createDeck({ repoRoot: root, slug: 'keep-me', title: 'Example' }), /Refusing to overwrite/);
  assert.equal(await readFile(path.join(root, 'slides/keep-me/user.txt'), 'utf8'), 'Keep this text.');
  await mkdir(path.join(root, 'slides/empty'));
  await assert.rejects(createDeck({ repoRoot: root, slug: 'empty', title: 'Example' }), /Refusing to overwrite/);
  await writeFile(path.join(root, 'slides/file'), 'Keep this file.');
  await assert.rejects(createDeck({ repoRoot: root, slug: 'file', title: 'Example' }), /Refusing to overwrite/);
});

test('rejects traversal, reserved names and invalid titles before creating slides', async t => {
  const root = await workspace(t);
  for (const slug of ['../outside', '/absolute', 'Upper', 'two--hyphens', 'a/b', 'a\\b', 'con', 'nul', 'lpt1', '']) {
    await assert.rejects(createDeck({ repoRoot: root, slug, title: 'Example' }), /slug/);
  }
  for (const title of ['', '   ', 'two\nlines', '\u0000']) {
    await assert.rejects(createDeck({ repoRoot: root, slug: 'valid', title }), /single-line title/);
  }
  assert.deepEqual(await readdir(root), []);
});

test('rejects symlinked slides directories and destinations', async t => {
  const root = await workspace(t);
  const outside = path.join(root, 'outside');
  await mkdir(outside);
  await symlink(outside, path.join(root, 'slides'), 'junction');
  await assert.rejects(createDeck({ repoRoot: root, slug: 'escape', title: 'Example' }), /real directory/);
  assert.deepEqual(await readdir(outside), []);
  await rm(path.join(root, 'slides'));
  await mkdir(path.join(root, 'slides'));
  await symlink(outside, path.join(root, 'slides/existing'), 'junction');
  await assert.rejects(createDeck({ repoRoot: root, slug: 'existing', title: 'Example' }), /Refusing to overwrite/);
  await symlink(path.join(root, 'missing'), path.join(root, 'slides/dangling'), 'junction');
  await assert.rejects(createDeck({ repoRoot: root, slug: 'dangling', title: 'Example' }), /Refusing to overwrite/);
});

test('parses only the documented CLI inputs', () => {
  assert.deepEqual(parseArguments(['--slug', 'demo', '--title', 'Demo title']), { slug: 'demo', title: 'Demo title' });
  assert.deepEqual(parseArguments(['--help']), { help: true });
  for (const args of [[], ['--slug'], ['--title', 'Demo'], ['--root', 'elsewhere'], ['--slug', 'one', '--slug', 'two'], ['--help', '--slug', 'demo']]) {
    assert.throws(() => parseArguments(args));
  }
});

test('CLI resolves its repository from its location, not the caller working directory', async t => {
  const root = await workspace(t);
  const fixtureSkill = path.join(root, '.github/skills/hve-slides');
  const actualSkill = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  await mkdir(path.join(fixtureSkill, 'scripts'), { recursive: true });
  await mkdir(path.join(fixtureSkill, 'templates/deck'), { recursive: true });
  await copyFile(path.join(actualSkill, 'scripts/create-deck.mjs'), path.join(fixtureSkill, 'scripts/create-deck.mjs'));
  for (const file of templateFiles) {
    await copyFile(path.join(actualSkill, 'templates/deck', file), path.join(fixtureSkill, 'templates/deck', file));
  }
  const output = execFileSync(process.execPath, [
    path.join(fixtureSkill, 'scripts/create-deck.mjs'), '--slug', 'cli-demo', '--title', 'CLI example'
  ], { cwd: tmpdir(), encoding: 'utf8' });
  assert.ok(output.includes(path.join(root, 'slides/cli-demo')));
  assert.equal(JSON.parse(await readFile(path.join(root, 'slides/cli-demo/deck.json'), 'utf8')).title, 'CLI example');
  assert.deepEqual((await readdir(path.join(root, 'slides/cli-demo'))).sort(), [...templateFiles].sort());
});

test('HVE Updates delegates to the same standalone HTML transformation', async () => {
  const canonical = await import('../templates/deck/bundle.mjs');
  const existing = await import('../../../../slides/hve-updates/bundle.mjs');
  assert.equal(existing.createStandaloneHtml, canonical.createStandaloneHtml);
});
