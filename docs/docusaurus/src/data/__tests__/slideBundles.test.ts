// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { loadSlideBundles, syncSlideBundles } from '../../../scripts/slide-bundles.cjs';

let root: string;
let source: string;
let destination: string;

function bundleHtml(title: string, description = 'A standalone presentation.'): string {
  const metadata = JSON.stringify({ title, description }).replaceAll('<', '\\u003c');
  return `<!doctype html><script type="application/json" id="hve-slide-metadata">${metadata}</script><script>globalThis.deck = true;</script>`;
}

beforeEach(() => {
  root = mkdtempSync(path.join(tmpdir(), 'hve-site-slides-'));
  source = path.join(root, 'source');
  destination = path.join(root, 'static/slides');
  mkdirSync(source);
});

afterEach(() => rmSync(root, { recursive: true, force: true }));

test('discovers sorted deck files and copies raw HTML without altering its scripts', () => {
  const html = bundleHtml('HVE Core updates');
  writeFileSync(path.join(source, 'hve-updates.html'), html);
  writeFileSync(path.join(source, 'hve-full.html'), bundleHtml('Full HVE overview'));
  writeFileSync(path.join(source, 'README.md'), 'Not a slide bundle.');
  expect(loadSlideBundles(source)).toEqual([
    { slug: 'hve-full', title: 'Full HVE overview', description: 'A standalone presentation.' },
    { slug: 'hve-updates', title: 'HVE Core updates', description: 'A standalone presentation.' },
  ]);
  expect(syncSlideBundles(source, destination)).toEqual(loadSlideBundles(source));
  expect(readdirSync(destination).sort()).toEqual(['hve-full.html', 'hve-updates.html']);
  expect(readFileSync(path.join(destination, 'hve-updates.html'), 'utf8')).toBe(html);
});

test('refreshes changed bundles and removes deleted decks from staging', () => {
  writeFileSync(path.join(source, 'hve-updates.html'), bundleHtml('Before'));
  syncSlideBundles(source, destination);
  writeFileSync(path.join(source, 'hve-updates.html'), bundleHtml('After', 'Updated description.'));
  writeFileSync(path.join(destination, 'removed.html'), '<html>Old deck</html>');
  expect(syncSlideBundles(source, destination)).toEqual([
    { slug: 'hve-updates', title: 'After', description: 'Updated description.' },
  ]);
  expect(readFileSync(path.join(destination, 'hve-updates.html'), 'utf8')).toBe(bundleHtml('After', 'Updated description.'));
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

test('uses generated labels verbatim and sorts by title rather than filename', () => {
  writeFileSync(path.join(source, 'z-last.html'), bundleHtml('A <guide> & examples', 'Useful "details".'));
  writeFileSync(path.join(source, 'a-first.html'), bundleHtml('Z guide'));
  expect(loadSlideBundles(source)).toEqual([
    { slug: 'z-last', title: 'A <guide> & examples', description: 'Useful "details".' },
    { slug: 'a-first', title: 'Z guide', description: 'A standalone presentation.' },
  ]);
});

test.each([
  '<html>No metadata</html>',
  bundleHtml('First') + bundleHtml('Duplicate'),
  bundleHtml('', 'Description'),
  bundleHtml('Title', ' '),
  '<script type="application/json" id="hve-slide-metadata">invalid JSON</script>',
])('rejects missing, duplicate or invalid generated metadata', html => {
  writeFileSync(path.join(source, 'invalid-metadata.html'), html);
  expect(() => syncSlideBundles(source, destination)).toThrow();
});
