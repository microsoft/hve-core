// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import path from 'node:path';

import { SESSION_ID_RE } from './paths.mjs';
import { parseFlatYaml } from './yaml.mjs';

const TITLE_MAX = 160;
const INUSE_RE = /^inuse\.(\d+)\.lock$/;

/**
 * Host client names recorded in `workspace.yaml` mapped to readable labels.
 * Unknown values are shown as recorded.
 */
export const CLIENT_LABELS = Object.freeze({
    'github/autopilot': 'GitHub Copilot app',
    'github/cli': 'Copilot CLI',
    'vscode-agent-host': 'VS Code (Copilot harness)',
    vscode: 'VS Code',
});

/**
 * Returns true when a process with the given ID is running.
 *
 * @param {number} pid
 * @returns {boolean}
 */
export function isPidAlive(pid) {
    if (!Number.isInteger(pid) || pid <= 0) {
        return false;
    }
    try {
        process.kill(pid, 0);
        return true;
    } catch (error) {
        return /** @type {NodeJS.ErrnoException} */ (error).code === 'EPERM';
    }
}

/**
 * Picks a single-line, capped title from recorded session text.
 *
 * @param {unknown} value
 * @returns {string}
 */
export function toTitle(value) {
    if (typeof value !== 'string') {
        return '';
    }
    const line = value.split('\n').map((part) => part.trim()).find((part) => part.length > 0) ?? '';
    return line.length > TITLE_MAX ? `${line.slice(0, TITLE_MAX - 1)}…` : line;
}

/**
 * Lists sessions with recorded events, newest first.
 *
 * Reads `workspace.yaml` only when its size or modification time changed since
 * the cached record, so an unchanged refresh reads no file content.
 */
export class SessionCatalog {
    /**
     * @param {string} root Session-state root folder.
     * @param {{ isPidAlive?: (pid: number) => boolean }} [options]
     */
    constructor(root, options = {}) {
        this.root = root;
        this.isPidAlive = options.isPidAlive ?? isPidAlive;
        /** @type {Map<string, { key: string, record: object }>} */
        this.cache = new Map();
        this.contentReads = 0;
    }

    /**
     * @returns {Promise<Array<{ sessionId: string, title: string, summary: string, repository: string | null, branch: string | null, cwd: string | null, client: string | null, clientLabel: string | null, createdAt: string | null, updatedAt: string, eventsBytes: number, active: boolean }>>}
     */
    async list() {
        let dirents;
        try {
            dirents = await fs.readdir(this.root, { withFileTypes: true });
        } catch (error) {
            if (/** @type {NodeJS.ErrnoException} */ (error).code === 'ENOENT') {
                this.cache.clear();
                return [];
            }
            throw error;
        }
        const seen = new Set();
        const records = await Promise.all(
            dirents
                .filter((entry) => entry.isDirectory() && SESSION_ID_RE.test(entry.name))
                .map(async (entry) => {
                    seen.add(entry.name);
                    return this.#describe(entry.name);
                }),
        );
        for (const key of this.cache.keys()) {
            if (!seen.has(key)) {
                this.cache.delete(key);
            }
        }
        return records
            .filter((record) => record !== null)
            .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : a.updatedAt > b.updatedAt ? -1 : 0));
    }

    /**
     * @param {string} sessionId
     */
    async get(sessionId) {
        if (!SESSION_ID_RE.test(sessionId)) {
            return null;
        }
        return this.#describe(sessionId.toLowerCase());
    }

    async #describe(sessionId) {
        const folder = path.join(this.root, sessionId);
        const folderStat = await statOrNull(folder);
        if (!folderStat?.isDirectory()) {
            this.cache.delete(sessionId);
            return null;
        }
        const eventsStat = await statOrNull(path.join(folder, 'events.jsonl'));
        if (!eventsStat || !eventsStat.isFile() || eventsStat.size === 0) {
            this.cache.delete(sessionId);
            return null;
        }
        const yamlPath = path.join(folder, 'workspace.yaml');
        const yamlStat = await statOrNull(yamlPath);
        const key = [eventsStat.size, eventsStat.mtimeMs, yamlStat?.size ?? -1, yamlStat?.mtimeMs ?? -1].join(':');
        const cached = this.cache.get(sessionId);
        let base;
        if (cached && cached.key === key) {
            base = cached.record;
        } else {
            let yaml = {};
            if (yamlStat?.isFile()) {
                try {
                    this.contentReads += 1;
                    yaml = parseFlatYaml(await fs.readFile(yamlPath, 'utf8'));
                } catch {
                    yaml = {};
                }
            }
            const title = toTitle(yaml.name) || toTitle(yaml.summary) || sessionId;
            const yamlUpdated = typeof yaml.updated_at === 'string' ? Date.parse(yaml.updated_at) : NaN;
            const updatedMs = Math.max(eventsStat.mtimeMs, Number.isFinite(yamlUpdated) ? yamlUpdated : 0);
            const client = typeof yaml.client_name === 'string' ? yaml.client_name : null;
            base = {
                sessionId,
                title,
                summary: toTitle(yaml.summary),
                repository: stringOrNull(yaml.repository),
                branch: stringOrNull(yaml.branch),
                cwd: stringOrNull(yaml.cwd),
                client,
                clientLabel: client ? (Object.hasOwn(CLIENT_LABELS, client) ? CLIENT_LABELS[client] : client) : null,
                createdAt: stringOrNull(yaml.created_at),
                updatedAt: new Date(updatedMs).toISOString(),
                eventsBytes: eventsStat.size,
            };
            this.cache.set(sessionId, { key, record: base });
        }
        return { ...base, active: await this.#isActive(folder) };
    }

    async #isActive(folder) {
        let names;
        try {
            names = await fs.readdir(folder);
        } catch {
            return false;
        }
        for (const name of names) {
            const match = INUSE_RE.exec(name);
            if (match && this.isPidAlive(Number(match[1]))) {
                return true;
            }
        }
        return false;
    }
}

/**
 * Stats a path without following symlinks, so links cannot point reads outside the root.
 *
 * @param {string} target
 */
async function statOrNull(target) {
    try {
        return await fs.lstat(target);
    } catch {
        return null;
    }
}

function stringOrNull(value) {
    return typeof value === 'string' && value.length > 0 ? value : null;
}
