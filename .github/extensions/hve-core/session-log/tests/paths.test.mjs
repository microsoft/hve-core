// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import path from 'node:path';
import test from 'node:test';

import { isSessionId, resolveSessionStateRoot, sessionFolder } from '../lib/paths.mjs';
import { parseFlatYaml } from '../lib/yaml.mjs';

const ID = '11111111-2222-4333-8444-555555555555';

test('root resolution prefers the joined session workspace folder', () => {
    const result = resolveSessionStateRoot({
        workspacePath: `/custom/home/session-state/${ID}`,
        env: { COPILOT_HOME: '/elsewhere' },
        homedir: '/home/user',
        pathApi: path.posix,
    });
    assert.deepEqual(result, { root: '/custom/home/session-state', source: 'workspace' });
});

test('root resolution ignores a workspace folder outside session-state', () => {
    const result = resolveSessionStateRoot({ workspacePath: `/tmp/${ID}`, env: {}, homedir: '/home/user', pathApi: path.posix });
    assert.deepEqual(result, { root: '/home/user/.copilot/session-state', source: 'home' });
});

test('root resolution falls back to COPILOT_HOME when the workspace path is undefined', () => {
    const result = resolveSessionStateRoot({ workspacePath: undefined, env: { COPILOT_HOME: '/opt/copilot' }, homedir: '/home/user', pathApi: path.posix });
    assert.deepEqual(result, { root: '/opt/copilot/session-state', source: 'COPILOT_HOME' });
});

test('root resolution ignores an empty COPILOT_HOME', () => {
    const result = resolveSessionStateRoot({ env: { COPILOT_HOME: '' }, homedir: '/home/user', pathApi: path.posix });
    assert.equal(result.root, '/home/user/.copilot/session-state');
});

test('root resolution handles Windows-style paths', () => {
    const fromHome = resolveSessionStateRoot({ env: {}, homedir: 'C:\\Users\\dev', pathApi: path.win32 });
    assert.equal(fromHome.root, 'C:\\Users\\dev\\.copilot\\session-state');
    const fromEnv = resolveSessionStateRoot({ env: { COPILOT_HOME: 'D:\\copilot' }, homedir: 'C:\\Users\\dev', pathApi: path.win32 });
    assert.equal(fromEnv.root, 'D:\\copilot\\session-state');
    const fromWorkspace = resolveSessionStateRoot({ workspacePath: `C:\\Users\\dev\\.copilot\\session-state\\${ID}`, env: {}, homedir: 'C:\\x', pathApi: path.win32 });
    assert.deepEqual(fromWorkspace, { root: 'C:\\Users\\dev\\.copilot\\session-state', source: 'workspace' });
});

test('session IDs accept UUID folders and reject everything else', () => {
    assert.equal(isSessionId(ID), true);
    assert.equal(isSessionId(ID.toUpperCase()), true);
    for (const bad of ['', '..', '../etc', `${ID}/..`, `pending-session:${ID}`, `${ID}.lock`, 42, null, undefined]) {
        assert.equal(isSessionId(bad), false, String(bad));
    }
});

test('session folders stay inside the root and normalize case', () => {
    assert.equal(sessionFolder('/root', ID.toUpperCase()), path.join('/root', ID));
    assert.throws(() => sessionFolder('/root', '../escape'), RangeError);
});

test('flat YAML parses scalars, quotes, booleans, and block scalars', () => {
    const parsed = parseFlatYaml([
        'id: abc',
        'name: |-',
        '  First line',
        '  Second line',
        'summary: >',
        '  folded',
        '  text',
        "quoted: 'it''s'",
        'double: "a\\tb"',
        'user_named: false',
        'empty:',
        'nested:',
        '  child: ignored',
        'cwd: /repo',
    ].join('\r\n'));
    assert.equal(parsed.id, 'abc');
    assert.equal(parsed.name, 'First line\nSecond line');
    assert.equal(parsed.summary, 'folded text\n');
    assert.equal(parsed.quoted, "it's");
    assert.equal(parsed.double, 'a\tb');
    assert.equal(parsed.user_named, false);
    assert.equal(parsed.empty, null);
    assert.equal(parsed.cwd, '/repo');
    assert.equal(parseFlatYaml('').id, undefined);
});
