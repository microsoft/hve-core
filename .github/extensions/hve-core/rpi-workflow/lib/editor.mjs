// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { execFile as nodeExecFile } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';

/**
 * Opens workspace files in the VS Code that hosts the canvas. No canvas host offers a request
 * for this, so the extension runs VS Code's own command-line tool: the app binary in
 * Node mode with `out/cli.js` and `--goto`, as VS Code's `bin/code` launcher does. The
 * install is found from the extension process's own executable, and nothing runs through a
 * shell.
 */

const VSCODE_PROTOCOLS = new Set(['vscode', 'vscode-insiders', 'vscode-exploration']);
const MAX_LEVELS = 8;
const OPEN_TIMEOUT_MS = 15000;

/**
 * True for files VS Code would open as a workspace rather than in an editor, which would
 * apply the workspace's settings and tasks; the canvas shows these itself instead.
 *
 * @param {string} file
 */
export const opensAsWorkspace = (file) => /\.code-workspace$/i.test(String(file ?? ''));
const MAX_PRODUCT_BYTES = 1024 * 1024;

/** A failure to open the editor, with a stable code. */
export class EditorError extends Error {
    /**
     * @param {'editor_unavailable' | 'editor_busy' | 'editor_invalid' | 'editor_failed'} code
     * @param {string} message
     */
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}

const isFile = (target) => fs.stat(target).then((stat) => stat.isFile(), () => false);

/**
 * Reads `product.json` through one handle, so the type and size checks describe the file
 * that is read.
 *
 * @param {string} productPath
 * @returns {Promise<unknown>} the parsed product, `undefined` when no regular file is there,
 *   or `null` when the file is too large or is not JSON
 */
async function readProduct(productPath) {
    let handle;
    try {
        handle = await fs.open(productPath, 'r');
    } catch {
        return undefined;
    }
    try {
        const stat = await handle.stat();
        if (!stat.isFile()) return undefined;
        if (stat.size > MAX_PRODUCT_BYTES) return null;
        return JSON.parse(await handle.readFile('utf8'));
    } catch {
        return null;
    } finally {
        await handle.close();
    }
}

/**
 * Finds the VS Code install around an executable: the nearest ancestor folder with
 * `Resources/app/product.json` (macOS) or `resources/app/product.json` (Windows and Linux)
 * whose product is VS Code, with its `out/cli.js` and app binary present.
 *
 * @param {{ execPath?: string, platform?: string }} [options]
 * @returns {Promise<{ name: string, binary: string, cli: string } | null>}
 */
export async function findEditor(options = {}) {
    const { execPath = process.execPath, platform = process.platform } = options;
    let dir = path.dirname(execPath);
    for (let level = 0; level < MAX_LEVELS; level += 1) {
        for (const resources of ['Resources', 'resources']) {
            const app = path.join(dir, resources, 'app');
            const product = await readProduct(path.join(app, 'product.json'));
            if (product === undefined) continue;
            if (!VSCODE_PROTOCOLS.has(product?.urlProtocol) || typeof product.nameShort !== 'string' || typeof product.applicationName !== 'string') return null;
            const cli = path.join(app, 'out', 'cli.js');
            const binary = platform === 'darwin'
                ? path.join(dir, 'MacOS', product.nameShort)
                : platform === 'win32' ? path.join(dir, `${product.nameShort}.exe`) : path.join(dir, product.applicationName);
            if (!(await isFile(cli)) || !(await isFile(binary))) return null;
            return { name: typeof product.nameLong === 'string' ? product.nameLong : product.nameShort, binary, cli };
        }
        const parent = path.dirname(dir);
        if (parent === dir) break;
        dir = parent;
    }
    return null;
}

/**
 * An opener for one editor install. Each call runs the CLI with `--goto <file>:<line>:1` and
 * resolves once it exits. One open runs at a time, and a call while one runs is refused.
 *
 * @param {{ binary: string, cli: string }} editor
 * @param {{ execFile?: typeof nodeExecFile, env?: NodeJS.ProcessEnv }} [options]
 */
export function createEditorOpener(editor, options = {}) {
    const { execFile = nodeExecFile, env = process.env } = options;
    let busy = false;
    return async function open(absolute, line) {
        if (typeof absolute !== 'string' || !path.isAbsolute(absolute) || !Number.isInteger(line) || line < 1) {
            throw new EditorError('editor_invalid', 'The editor opens an absolute file path at a line number.');
        }
        if (opensAsWorkspace(absolute)) {
            throw new EditorError('editor_invalid', 'VS Code opens a .code-workspace file as a new workspace, so the canvas shows it here instead.');
        }
        if (busy) throw new EditorError('editor_busy', 'VS Code is still opening the last file. Try again in a moment.');
        busy = true;
        const childEnv = { ...env, ELECTRON_RUN_AS_NODE: '1' };
        delete childEnv.NODE_OPTIONS;
        try {
            await new Promise((resolve, reject) => {
                execFile(editor.binary, [editor.cli, '--goto', `${absolute}:${line}:1`], { env: childEnv, timeout: OPEN_TIMEOUT_MS, windowsHide: true }, (error) => (error ? reject(error) : resolve(undefined)));
            });
        } catch {
            throw new EditorError('editor_failed', 'VS Code did not open the file. Use Copy path instead.');
        } finally {
            busy = false;
        }
    };
}
