// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it, mock } from 'node:test';

import { buildScenario } from '../lib/scenario.mjs';
import { createCanvasServer } from '../lib/server.mjs';
import { createStore } from '../lib/store.mjs';
import { FileError, findLine, MAX_SOURCE_BYTES, MAX_SOURCE_LINES, readWorkspaceFile, resolveWorkspaceFile } from '../lib/workspace-files.mjs';

let tmp;
let root;
before(async () => {
    tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-files-')));
    root = path.join(tmp, 'repo');
    const write = async (file, text) => {
        await fs.mkdir(path.dirname(path.join(root, file)), { recursive: true });
        await fs.writeFile(path.join(root, file), text);
    };
    await write('src/app.mjs', ['// header', "import x from 'y';", '', 'const ID_RE = /x/;', '', 'export function navigate(ref) {', '    return ref;', '}', 'const act = {', '    openFile(changeId, path) {', '        return navigate(changeId);', '    },', '};', ''].join('\n'));
    await write('docs/guide.md', ['# Guide', '', '## Flow', '', 'Step one.', '', '### [x] P01: Establish the change', '', '## Evidence Log', 'Row C1 cites `ID_RE`.', ''].join('\n'));
    await write('.env', 'TOKEN=secret');
    await write('keys/server.pem', 'key');
    await write('.git/config', '[core]');
    await write('big.txt', 'a'.repeat(MAX_SOURCE_BYTES + 1));
    await write('image.bin', Buffer.from([0x89, 0x50, 0x00, 0x47]));
    await write('long.txt', Array.from({ length: MAX_SOURCE_LINES * 2 }, (_, index) => (index === 7000 ? 'needle' : `line ${index + 1}`)).join('\n'));
    await fs.writeFile(path.join(tmp, 'outside.md'), '# Outside');
    await fs.symlink(path.join(tmp, 'outside.md'), path.join(root, 'link.md'));
    await fs.symlink(tmp, path.join(root, 'linked-dir'));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

const refusal = async (target) => {
    try {
        await resolveWorkspaceFile(root, target);
    } catch (error) {
        assert.ok(error instanceof FileError, String(error));
        return error.code;
    }
    return assert.fail(`${target} was accepted`);
};

describe('the workspace read boundary', () => {
    it('accepts a workspace-relative file and reports its real path', async () => {
        const file = await resolveWorkspaceFile(root, './src/app.mjs');
        assert.equal(file.path, 'src/app.mjs');
    });

    it('refuses paths that leave the workspace, absolute paths, and empty input', async () => {
        assert.equal(await refusal('../outside.md'), 'source_outside');
        assert.equal(await refusal('src/../../outside.md'), 'source_outside');
        assert.equal(await refusal(path.join(root, 'src/app.mjs')), 'source_invalid');
        assert.equal(await refusal('C:/repo/a.md'), 'source_invalid');
        assert.equal(await refusal(''), 'source_invalid');
        assert.equal(await refusal(42), 'source_invalid');
        assert.equal(await refusal('src/app.mjs\0.md'), 'source_invalid');
    });

    it('refuses .git and credential folders and secret-looking files', async () => {
        assert.equal(await refusal('.git/config'), 'source_blocked');
        assert.equal(await refusal('.GIT/config'), 'source_blocked');
        assert.equal(await refusal('.env'), 'source_blocked');
        assert.equal(await refusal('keys/server.pem'), 'source_blocked');
        assert.equal(await refusal('home/.ssh/id_ed25519'), 'source_blocked');
        assert.equal(await refusal('.npmrc'), 'source_blocked');
    });

    it('refuses symbolic links, linked folders that lead outside, folders, and missing files', async () => {
        assert.equal(await refusal('link.md'), 'source_blocked');
        assert.equal(await refusal('linked-dir/outside.md'), 'source_outside');
        assert.equal(await refusal('src'), 'source_invalid');
        assert.equal(await refusal('src/missing.mjs'), 'source_not_found');
    });

    it('refuses files over 1 MB and binary files', async () => {
        assert.equal(await refusal('big.txt'), 'source_too_large');
        await assert.rejects(readWorkspaceFile(root, 'image.bin'), (error) => error.code === 'source_binary');
    });

    it('refuses a colon in any segment, which names a drive or an alternate data stream', async () => {
        assert.equal(await refusal('src/app.mjs:Zone.Identifier'), 'source_invalid');
        assert.equal(await refusal('.env::$DATA'), 'source_invalid');
        assert.equal(await refusal('docs/D:/guide.md'), 'source_invalid');
    });

    it('refuses a file whose real name looks secret, as a Windows short name would resolve', async () => {
        await fs.writeFile(path.join(root, 'keys', 'ENV~1'), 'TOKEN=secret');
        const original = fs.realpath;
        const realpath = mock.method(fs, 'realpath', async (target) => (target.endsWith('ENV~1') ? path.join(root, 'keys', '.env') : original(target)));
        try {
            assert.equal(await refusal('keys/ENV~1'), 'source_blocked');
        } finally {
            realpath.mock.restore();
        }
    });

    it('refuses an anchor that is not short text', async () => {
        await assert.rejects(readWorkspaceFile(root, 'src/app.mjs', 'x'.repeat(201)), (error) => error.code === 'source_invalid');
        await assert.rejects(readWorkspaceFile(root, 'src/app.mjs', { name: 'x' }), (error) => error.code === 'source_invalid');
    });
});

describe('finding the cited place', () => {
    it('finds headings, link fragments, and section prefixes in Markdown', async () => {
        const lines = (await fs.readFile(path.join(root, 'docs/guide.md'), 'utf8')).split('\n');
        assert.deepEqual(findLine(lines, 'Evidence Log'), { line: 9, match: 'heading' });
        assert.deepEqual(findLine(lines, '#evidence-log'), { line: 9, match: 'fragment' });
        assert.deepEqual(findLine(lines, '#p01-establish-the-change'), { line: 7, match: 'fragment' });
        assert.deepEqual(findLine(lines, 'Flow step 3'), { line: 3, match: 'heading' });
        assert.deepEqual(findLine(lines, '#nowhere'), { line: null, match: 'not-found' });
        assert.deepEqual(findLine(['<div id="announcer">', '<p>x</p>'], '#announcer'), { line: 1, match: 'text' });
    });

    it('finds definitions before mentions, including methods and dotted names', async () => {
        const lines = (await fs.readFile(path.join(root, 'src/app.mjs'), 'utf8')).split('\n');
        assert.deepEqual(findLine(lines, 'ID_RE'), { line: 4, match: 'definition' });
        assert.deepEqual(findLine(lines, '`navigate`'), { line: 6, match: 'definition' });
        assert.deepEqual(findLine(lines, 'act.openFile'), { line: 10, match: 'definition' });
        assert.deepEqual(findLine(lines, 'changeId'), { line: 10, match: 'text' });
        assert.deepEqual(findLine(lines, ''), { line: null, match: 'none' });
    });

    it('stays fast on a hostile heading line', async () => {
        await fs.writeFile(path.join(root, 'docs', 'hostile.md'), `# a${' '.repeat(200000)}b\n\n## Target\n`);
        const started = Date.now();
        const result = await readWorkspaceFile(root, 'docs/hostile.md', 'Target');
        assert.ok(Date.now() - started < 1000, `read in ${Date.now() - started} ms`);
        assert.deepEqual([result.line, result.match], [3, 'heading']);
    });

    it('returns at most 5,000 lines centered on the cited line', async () => {
        const result = await readWorkspaceFile(root, 'long.txt', 'needle');
        assert.equal(result.line, 7001);
        assert.equal(result.lines.length, MAX_SOURCE_LINES);
        assert.ok(result.start <= 7001 && result.start + result.lines.length - 1 >= 7001);
        assert.equal(result.lines[result.line - result.start], 'needle');
        assert.equal(result.total, MAX_SOURCE_LINES * 2);
    });
});

function request(url, pathname, body) {
    return new Promise((resolve, reject) => {
        const payload = JSON.stringify(body);
        const req = http.request({ host: '127.0.0.1', port: url.port, method: 'POST', path: pathname, headers: { 'content-type': 'application/json', 'x-rw-key': url.searchParams.get('k') } }, (res) => {
            let text = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                text += chunk;
            });
            res.on('end', () => resolve({ status: res.statusCode, json: JSON.parse(text) }));
        });
        req.on('error', reject);
        req.write(payload);
        req.end();
    });
}

describe('the source route', () => {
    async function serve(name, source) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const session = await store.create(buildScenario('research'));
        const server = createCanvasServer({ store, getSessionId: () => session.id, getSource: () => source });
        return { server, url: new URL(await server.start()) };
    }

    it('returns the file around the cited line without the absolute path', async () => {
        const { server, url } = await serve('route-ok', { kind: 'rpi', workspace: { root, tracking: path.join(root, '.copilot-tracking') } });
        try {
            const ok = await request(url, '/api/source', { path: 'docs/guide.md', anchor: 'Evidence Log' });
            assert.equal(ok.status, 200);
            assert.deepEqual([ok.json.path, ok.json.line, ok.json.match, ok.json.absolute], ['docs/guide.md', 9, 'heading', undefined]);
            const statuses = await Promise.all(['.env', '../x.md', 'src/missing.mjs', 'big.txt', 'image.bin'].map((target) => request(url, '/api/source', { path: target })));
            assert.deepEqual(statuses.map((reply) => [reply.status, reply.json.error.code]), [[403, 'source_blocked'], [403, 'source_outside'], [404, 'source_not_found'], [413, 'source_too_large'], [415, 'source_binary']]);
        } finally {
            await server.stop();
        }
    });

    it('shows no files for a canvas that is not reading a workspace', async () => {
        const { server, url } = await serve('route-none', null);
        try {
            const reply = await request(url, '/api/source', { path: 'docs/guide.md' });
            assert.deepEqual([reply.status, reply.json.error.code], [404, 'source_unavailable']);
        } finally {
            await server.stop();
        }
    });
});
