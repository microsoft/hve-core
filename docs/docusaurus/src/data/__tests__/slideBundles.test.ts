// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { loadSlideBundles, syncSlideBundles } from '../../../scripts/slide-bundles.cjs';

let root: string;
let source: string;
let destination: string;

beforeEach(() => {
  root = mkdtempSync(path.join(tmpdir(), 'hve-site-slides-'));
  source = path.join(root, 'source');
  destination = path.join(root, 'static/slides');
  mkdirSync(source);
});

afterEach(() => rmSync(root, { recursive: true, force: true }));

test('discovers sorted deck files and copies raw HTML without altering its scripts', () => {
  const html = '<!doctype html><script>globalThis.deck = true;</script>';
  writeFileSync(path.join(source, 'hve-updates.html'), html);
  writeFileSync(path.join(source, 'hve-full.html'), '<html>Full deck</html>');
  writeFileSync(path.join(source, 'README.md'), 'Not a slide bundle.');
  expect(loadSlideBundles(source)).toEqual([{ slug: 'hve-full' }, { slug: 'hve-updates' }]);
  expect(syncSlideBundles(source, destination)).toEqual(loadSlideBundles(source));
  expect(readdirSync(destination).sort()).toEqual(['hve-full.html', 'hve-updates.html']);
  expect(readFileSync(path.join(destination, 'hve-updates.html'), 'utf8')).toBe(html);
});

test('refreshes changed bundles and removes deleted decks from staging', () => {
  writeFileSync(path.join(source, 'hve-updates.html'), '<html>Before</html>');
  syncSlideBundles(source, destination);
  writeFileSync(path.join(source, 'hve-updates.html'), '<html>After</html>');
  writeFileSync(path.join(destination, 'removed.html'), '<html>Old deck</html>');
  syncSlideBundles(source, destination);
  expect(readFileSync(path.join(destination, 'hve-updates.html'), 'utf8')).toBe('<html>After</html>');
  expect(readdirSync(destination)).toEqual(['hve-updates.html']);
  rmSync(path.join(source, 'hve-updates.html'));
  expect(syncSlideBundles(source, destination)).toEqual([]);
  expect(readdirSync(destination)).toEqual([]);
});

test.each(['index.html', 'Invalid Name.html'])('rejects reserved or invalid bundle names: %s', name => {
  writeFileSync(path.join(source, name), '<html>Invalid deck</html>');
  expect(() => syncSlideBundles(source, destination)).toThrow('regular, lower-kebab-case deck');
});

test('rejects symbolic-link bundles and missing sources explicitly', () => {
  symlinkSync(path.join(source, 'missing.html'), path.join(source, 'linked.html'));
  expect(() => loadSlideBundles(source)).toThrow('regular, lower-kebab-case deck');
  expect(() => loadSlideBundles(path.join(root, 'missing'))).toThrow();
});
