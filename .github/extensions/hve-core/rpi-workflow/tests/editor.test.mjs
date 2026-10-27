// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createEditorOpener, EditorError, findEditor } from '../lib/editor.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { createCanvasServer } from '../lib/server.mjs';
import { createStore } from '../lib/store.mjs';

let tmp;
before(async () => {
    tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-editor-')));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

const touch = async (file, text = '') => {
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, text);
};
const product = (fields) => JSON.stringify({ nameShort: 'Code - Insiders', nameLong: 'Visual Studio Code - Insiders', applicationName: 'code-insiders', urlProtocol: 'vscode-insiders', ...fields });

describe('finding VS Code', () => {
    it('finds the macOS app from a helper process inside it', async () => {
        const contents = path.join(tmp, 'mac', 'Visual Studio Code - Insiders.app', 'Contents');
        await touch(path.join(contents, 'Resources', 'app', 'product.json'), product());
        await touch(path.join(contents, 'Resources', 'app', 'out', 'cli.js'));
        await touch(path.join(contents, 'MacOS', 'Code - Insiders'));
        const helper = path.join(contents, 'Frameworks', 'Code - Insiders Helper.app', 'Contents', 'MacOS', 'Code - Insiders Helper');
        await touch(helper);
        assert.deepEqual(await findEditor({ execPath: helper, platform: 'darwin' }), {
            name: 'Visual Studio Code - Insiders',
            binary: path.join(contents, 'MacOS', 'Code - Insiders'),
            cli: path.join(contents, 'Resources', 'app', 'out', 'cli.js'),
        });
    });

    it('finds the Windows and Linux layouts beside the app binary', async () => {
        const win = path.join(tmp, 'win', 'Microsoft VS Code');
        await touch(path.join(win, 'resources', 'app', 'product.json'), product({ nameShort: 'Code', applicationName: 'code', urlProtocol: 'vscode', nameLong: 'Visual Studio Code' }));
        await touch(path.join(win, 'resources', 'app', 'out', 'cli.js'));
        await touch(path.join(win, 'Code.exe'));
        assert.equal((await findEditor({ execPath: path.join(win, 'Code.exe'), platform: 'win32' }))?.binary, path.join(win, 'Code.exe'));
        const linux = path.join(tmp, 'linux', 'code-insiders');
        await touch(path.join(linux, 'resources', 'app', 'product.json'), product());
        await touch(path.join(linux, 'resources', 'app', 'out', 'cli.js'));
        await touch(path.join(linux, 'code-insiders'));
        assert.equal((await findEditor({ execPath: path.join(linux, 'code-insiders'), platform: 'linux' }))?.binary, path.join(linux, 'code-insiders'));
    });

    it('finds nothing for another product, a missing CLI, or a plain Node', async () => {
        const other = path.join(tmp, 'other');
        await touch(path.join(other, 'resources', 'app', 'product.json'), product({ urlProtocol: 'cursor' }));
        await touch(path.join(other, 'resources', 'app', 'out', 'cli.js'));
        await touch(path.join(other, 'code-insiders'));
        assert.equal(await findEditor({ execPath: path.join(other, 'code-insiders'), platform: 'linux' }), null);
        const nocli = path.join(tmp, 'nocli');
        await touch(path.join(nocli, 'resources', 'app', 'product.json'), product());
        await touch(path.join(nocli, 'code-insiders'));
        assert.equal(await findEditor({ execPath: path.join(nocli, 'code-insiders'), platform: 'linux' }), null);
        assert.equal(await findEditor({ execPath: path.join(tmp, 'bin', 'node'), platform: 'linux' }), null);
    });
});

describe('opening a file', () => {
    const editor = { binary: '/Apps/VS Code.app/Contents/MacOS/Code', cli: '/Apps/VS Code.app/Contents/Resources/app/out/cli.js' };

    it('runs the CLI with --goto and no shell, in Node mode without NODE_OPTIONS', async () => {
        const calls = [];
        const open = createEditorOpener(editor, { env: { PATH: '/bin', NODE_OPTIONS: '--inspect' }, execFile: (file, args, options, done) => {
            calls.push({ file, args, options });
            done(null);
        } });
        await open('/repo/src/app.mjs', 42);
        assert.equal(calls.length, 1);
        assert.equal(calls[0].file, editor.binary);
        assert.deepEqual(calls[0].args, [editor.cli, '--goto', '/repo/src/app.mjs:42:1']);
        assert.equal(calls[0].options.shell, undefined);
        assert.equal(calls[0].options.env.ELECTRON_RUN_AS_NODE, '1');
        assert.equal('NODE_OPTIONS' in calls[0].options.env, false);
        assert.equal(calls[0].options.env.PATH, '/bin');
    });

    it('never opens a .code-workspace file, which VS Code would open as a workspace', async () => {
        let ran = false;
        const open = createEditorOpener(editor, { execFile: (_file, _args, _options, done) => {
            ran = true;
            done(null);
        } });
        await assert.rejects(open('/repo/team.code-workspace', 1), (error) => error.code === 'editor_invalid' && /new workspace/.test(error.message));
        await assert.rejects(open('/repo/TEAM.CODE-WORKSPACE', 1), (error) => error.code === 'editor_invalid');
        assert.equal(ran, false);
    });

    it('refuses a relative path or a bad line, one open at a time, and reports a failed run', async () => {
        let finish;
        const open = createEditorOpener(editor, { execFile: (_file, _args, _options, done) => {
            finish = done;
        } });
        await assert.rejects(open('src/app.mjs', 1), (error) => error instanceof EditorError && error.code === 'editor_invalid');
        await assert.rejects(open('/repo/a.md', 0), (error) => error.code === 'editor_invalid');
        const first = open('/repo/a.md', 3);
        await assert.rejects(open('/repo/b.md', 3), (error) => error.code === 'editor_busy');
        finish(new Error('exit 1'));
        await assert.rejects(first, (error) => error.code === 'editor_failed');
    });
});

function post(url, pathname, body) {
    return new Promise((resolve, reject) => {
        const req = http.request({ host: '127.0.0.1', port: url.port, method: pathname === '/api/state' ? 'GET' : 'POST', path: pathname, headers: { 'content-type': 'application/json', 'x-rw-key': url.searchParams.get('k') } }, (res) => {
            let text = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                text += chunk;
            });
            res.on('end', () => resolve({ status: res.statusCode, json: JSON.parse(text) }));
        });
        req.on('error', reject);
        if (pathname !== '/api/state') req.write(JSON.stringify(body));
        req.end();
    });
}

describe('the open route', () => {
    it('opens a workspace file at the cited line, names the editor in the state, and refuses outside paths', async () => {
        const root = path.join(tmp, 'repo');
        await touch(path.join(root, 'docs', 'guide.md'), '# Guide\n\n## Flow\n\nStep one.\n');
        const opened = [];
        const store = createStore({ root: path.join(tmp, 'store'), pollMs: 20 });
        const session = await store.create(buildScenario('research'));
        const server = createCanvasServer({
            store,
            getSessionId: () => session.id,
            getSource: () => ({ kind: 'rpi', workspace: { root } }),
            getEditor: () => ({ name: 'Visual Studio Code - Insiders', open: async (absolute, line) => opened.push([absolute, line]) }),
        });
        const url = new URL(await server.start());
        try {
            const state = await post(url, '/api/state');
            assert.deepEqual(state.json.editor, { name: 'Visual Studio Code - Insiders' });
            const reply = await post(url, '/api/open', { path: 'docs/guide.md', anchor: 'Flow' });
            assert.deepEqual([reply.status, reply.json], [200, { opened: true, path: 'docs/guide.md', line: 3, match: 'heading' }]);
            assert.deepEqual(opened, [[path.join(root, 'docs', 'guide.md'), 3]]);
            const outside = await post(url, '/api/open', { path: '../store/x.md' });
            assert.deepEqual([outside.status, outside.json.error.code], [403, 'source_outside']);
            assert.equal(opened.length, 1);
        } finally {
            await server.stop();
        }
    });

    it('reports no editor when none was found', async () => {
        const store = createStore({ root: path.join(tmp, 'store-none'), pollMs: 20 });
        const session = await store.create(buildScenario('research'));
        const server = createCanvasServer({ store, getSessionId: () => session.id, getSource: () => ({ kind: 'rpi', workspace: { root: tmp } }) });
        const url = new URL(await server.start());
        try {
            assert.equal((await post(url, '/api/state')).json.editor, null);
            const reply = await post(url, '/api/open', { path: 'x.md' });
            assert.deepEqual([reply.status, reply.json.error.code], [404, 'editor_unavailable']);
        } finally {
            await server.stop();
        }
    });
});
