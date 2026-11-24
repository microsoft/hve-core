// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const skillRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';

/** Return the npm arguments of the render-only restore command documented in SKILL.md. */
async function documentedRestoreArguments() {
  const skill = await readFile(path.join(skillRoot, 'SKILL.md'), 'utf8');
  const flow = skill.slice(skill.indexOf('## Render-Only Flow'), skill.indexOf('## Authoring Flow'));
  const commands = [...flow.matchAll(/`npm (ci[^`]*)`/g)].map(match => match[1].trim().split(/\s+/));
  assert.equal(commands.length, 1, 'Render-only flow documents exactly one npm restore command');
  return commands[0];
}

/** Create a dependency-free package whose preinstall script writes a sentinel file. */
async function lifecycleFixture(t) {
  const root = await realpath(await mkdtemp(path.join(tmpdir(), 'hve-slides-restore-')));
  t.after(() => rm(root, { recursive: true, force: true }));
  const manifest = {
    name: 'imported-deck',
    version: '1.0.0',
    private: true,
    scripts: { preinstall: 'node -e "require(\'fs\').writeFileSync(\'sentinel\', \'ran\')"' }
  };
  await writeFile(path.join(root, 'package.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  await writeFile(path.join(root, 'package-lock.json'), `${JSON.stringify({
    name: manifest.name,
    version: manifest.version,
    lockfileVersion: 3,
    requires: true,
    packages: { '': { name: manifest.name, version: manifest.version } }
  }, null, 2)}\n`);
  return root;
}

function runNpm(cwd, args) {
  execFileSync(npm, [...args, '--silent'], {
    cwd,
    stdio: 'pipe',
    env: { ...process.env, npm_config_ignore_scripts: '' },
    shell: process.platform === 'win32'
  });
}

test('documented render-only restore never runs supplied lifecycle scripts', async t => {
  const args = await documentedRestoreArguments();
  assert.ok(args.includes('--ignore-scripts'));
  const root = await lifecycleFixture(t);
  runNpm(root, args);
  assert.equal(existsSync(path.join(root, 'sentinel')), false);
});

test('the lifecycle fixture runs its script without the documented flag', async t => {
  const root = await lifecycleFixture(t);
  runNpm(root, ['ci']);
  assert.equal(await readFile(path.join(root, 'sentinel'), 'utf8'), 'ran');
});
