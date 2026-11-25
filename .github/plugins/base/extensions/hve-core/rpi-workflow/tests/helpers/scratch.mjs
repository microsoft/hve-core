// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

/**
 * Creates a scratch folder for test fixtures in the system temporary folder and returns its real
 * path, so containment checks that resolve symbolic links (such as macOS `/private/var`) compare
 * like with like. Remove the folder with `fs.rm` in an `after` hook.
 *
 * @param {string} name a short name for the fixtures, such as `sessions`
 * @returns {Promise<string>} the folder's real path
 */
export async function scratchFolder(name) {
    return fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), `rpi-workflow-${name}-`)));
}

/**
 * Creates a symbolic link, or skips the calling test where the host does not allow links, such as
 * Windows without Developer Mode.
 *
 * @param {import('node:test').TestContext} t
 * @param {string} target
 * @param {string} linkPath
 * @param {'dir' | 'file'} [type]
 * @returns {Promise<boolean>} Whether the link exists.
 */
export async function symlinkOrSkip(t, target, linkPath, type) {
    try {
        await fs.symlink(target, linkPath, type);
        return true;
    } catch (error) {
        if (error.code === 'EPERM' || error.code === 'EACCES') {
            t.skip(`this host does not allow symbolic links (${error.code})`);
            return false;
        }
        throw error;
    }
}
