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
