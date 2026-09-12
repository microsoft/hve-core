// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import test from 'node:test';
import assert from 'node:assert/strict';
import { copyFile, cp, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildAllDecks } from '../scripts/build-decks.mjs';
import { createDeck } from '../scripts/create-deck.mjs';

const skillDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

async function workspace(t) {
  const root = await mkdtemp(path.join(tmpdir(), 'hve-slide-build-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return realpath(root);
}

async function fixtureDeck(root, name, source) {
  const directory = path.join(root, 'slides', name);
  await mkdir(directory, { recursive: true });
  await writeFile(path.join(directory, 'bundle.mjs'), source);
  return directory;
}

test('bundles multiple scaffolded decks into independent named HTML files', async t => {
  const root = await workspace(t);
  for (const slug of ['hve-updates', 'hve-full']) {
    const directory = await createDeck({ repoRoot: root, slug, title: `${slug} presentation` });
    await cp(
      path.join(skillDirectory, 'templates/deck/node_modules/reveal.js'),
      path.join(directory, 'node_modules/reveal.js'),
      { recursive: true }
    );
  }
  await writeFile(path.join(root, 'slides/README.md'), 'Deck collection.');
  const outputs = await buildAllDecks({ repoRoot: root });
  assert.deepEqual(outputs, ['hve-full', 'hve-updates'].map(slug => path.join(root, 'slides', slug, 'dist', `${slug}.html`)));
  for (const [index, slug] of ['hve-full', 'hve-updates'].entries()) {
    const html = await readFile(outputs[index], 'utf8');
    assert.ok(html.includes(`${slug} presentation`));
    assert.ok(!html.includes(`${slug === 'hve-full' ? 'hve-updates' : 'hve-full'} presentation`));
    assert.match(html, /bundled-third-party-notices/);
    assert.doesNotMatch(html, /<script[^>]+\bsrc=|<link rel="stylesheet"/);
    assert.ok((await readFile(path.join(root, 'slides', slug, 'dist/index.html'), 'utf8')).includes('<!doctype html>'));
  }
  assert.deepEqual((await readdir(path.join(root, 'slides'))).sort(), ['README.md', 'hve-full', 'hve-updates']);
});

test('reports empty collections and missing bundlers rather than skipping decks', async t => {
  const root = await workspace(t);
  await mkdir(path.join(root, 'slides'));
  await assert.rejects(buildAllDecks({ repoRoot: root }), /No slide decks found/);
  await mkdir(path.join(root, 'slides/incomplete'));
  await assert.rejects(buildAllDecks({ repoRoot: root }), /Failed to bundle slides\/incomplete:.*ENOENT/);
});

test('rejects symbolic-link slide roots, deck directories and bundlers', async t => {
  const root = await workspace(t);
  const outside = path.join(root, 'outside');
  await mkdir(outside);
  await symlink(outside, path.join(root, 'slides'), 'junction');
  await assert.rejects(buildAllDecks({ repoRoot: root }), /real directory/);
  await rm(path.join(root, 'slides'));
  await mkdir(path.join(root, 'slides'));
  await symlink(outside, path.join(root, 'slides/linked'), 'junction');
  await assert.rejects(buildAllDecks({ repoRoot: root }), /symbolic-link entry/);
  await rm(path.join(root, 'slides/linked'));
  const directory = await fixtureDeck(root, 'linked-script', 'export const bundleDeck = null;');
  await rm(path.join(directory, 'bundle.mjs'));
  await symlink(outside, path.join(directory, 'bundle.mjs'), 'junction');
  await assert.rejects(buildAllDecks({ repoRoot: root }), /bundle.mjs must be a regular file/);
});

test('requires the bundle export and verifies the declared output exists', async t => {
  for (const [name, source, message] of [
    ['no-export', 'export const title = "Example";', /must export a bundleDeck function/],
    ['wrong-path', 'export async function bundleDeck() { return "combined.html"; }', /must return/],
    ['missing-output', 'import { fileURLToPath } from "node:url"; export async function bundleDeck() { return fileURLToPath(new URL("./dist/missing-output.html", import.meta.url)); }', /ENOENT/],
    ['empty-output', `
      import { mkdir, writeFile } from 'node:fs/promises';
      import { fileURLToPath } from 'node:url';
      export async function bundleDeck() {
        await mkdir(new URL('./dist/', import.meta.url));
        const output = new URL('./dist/empty-output.html', import.meta.url);
        await writeFile(output, '');
        return fileURLToPath(output);
      }
    `, /nonempty HTML file/]
  ]) {
    const root = await workspace(t);
    await fixtureDeck(root, name, source);
    await assert.rejects(buildAllDecks({ repoRoot: root }), message);
  }
});

test('preserves a deck failure and stops before later decks', async t => {
  const root = await workspace(t);
  await fixtureDeck(root, 'a-failing', 'export async function bundleDeck() { throw new Error("reveal.js is missing. Run npm ci in this deck."); }');
  const later = await fixtureDeck(root, 'z-later', `
    import { writeFile } from 'node:fs/promises';
    export async function bundleDeck() {
      await writeFile(new URL('./unexpected.txt', import.meta.url), 'Unexpected build');
    }
  `);
  await assert.rejects(buildAllDecks({ repoRoot: root }), /Failed to bundle slides\/a-failing: reveal.js is missing/);
  assert.deepEqual(await readdir(later), ['bundle.mjs']);
});

test('CLI locates decks beside its repository, reports failures and accepts only help', async t => {
  const root = await workspace(t);
  const scripts = path.join(root, '.github/skills/hve-slides/scripts');
  await mkdir(scripts, { recursive: true });
  const script = path.join(scripts, 'build-decks.mjs');
  await copyFile(path.join(skillDirectory, 'scripts/build-decks.mjs'), script);
  await fixtureDeck(root, 'cli-demo', `
    import { mkdir, writeFile } from 'node:fs/promises';
    import { fileURLToPath } from 'node:url';
    export async function bundleDeck() {
      const directory = new URL('./dist/', import.meta.url);
      await mkdir(directory, { recursive: true });
      const output = new URL('cli-demo.html', directory);
      await writeFile(output, '<html>CLI deck</html>');
      return fileURLToPath(output);
    }
  `);
  const run = (...args) => spawnSync(process.execPath, [script, ...args], { cwd: tmpdir(), encoding: 'utf8' });
  const success = run();
  assert.equal(success.status, 0, success.stderr);
  assert.ok(success.stdout.includes(path.join(root, 'slides/cli-demo/dist/cli-demo.html')));
  assert.match(success.stdout, /Bundled 1 deck/);
  assert.equal(run('--help').status, 0);
  const unknown = run('--install');
  assert.equal(unknown.status, 1);
  assert.match(unknown.stderr, /No arguments are supported/);
  await fixtureDeck(root, 'a-failing', 'export async function bundleDeck() { throw new Error("Build failed"); }');
  const failure = run();
  assert.equal(failure.status, 1);
  assert.match(failure.stderr, /Failed to bundle slides\/a-failing: Build failed/);
  assert.doesNotMatch(failure.stdout, /Bundled/);
});
