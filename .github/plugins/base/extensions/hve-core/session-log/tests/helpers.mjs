// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import http from 'node:http';

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

/**
 * Sends an HTTP request with full control over headers, including Host.
 *
 * @param {string} baseUrl Server base URL.
 * @param {string} path Request path and query.
 * @param {{ method?: string, headers?: Record<string, string>, body?: string }} [options]
 * @returns {Promise<{ status: number, headers: http.IncomingHttpHeaders, text: string, json: () => any }>}
 */
export function request(baseUrl, path, options = {}) {
    const url = new URL(path, baseUrl);
    return new Promise((resolve, reject) => {
        const req = http.request({
            host: url.hostname,
            port: url.port,
            path: `${url.pathname}${url.search}`,
            method: options.method ?? 'GET',
            headers: { Host: url.host, ...(options.headers ?? {}) },
        }, (res) => {
            const chunks = [];
            res.on('data', (chunk) => chunks.push(chunk));
            res.on('end', () => {
                const text = Buffer.concat(chunks).toString('utf8');
                resolve({ status: res.statusCode, headers: res.headers, text, json: () => JSON.parse(text) });
            });
        });
        req.on('error', reject);
        if (options.body !== undefined) {
            req.write(options.body);
        }
        req.end();
    });
}

class FakeNode {
    constructor(nodeName) {
        this.nodeName = nodeName;
        this.children = [];
        this.parent = null;
    }

    append(...nodes) {
        for (const node of nodes) {
            if (node instanceof FakeFragment) {
                for (const child of node.children) {
                    child.parent = this;
                    this.children.push(child);
                }
                node.children = [];
            } else {
                node.parent = this;
                this.children.push(node);
            }
        }
    }

    get textContent() {
        return this.children.map((child) => child.textContent).join('');
    }

    set textContent(value) {
        this.children = [new FakeText(String(value))];
    }

    get lastElementChild() {
        for (let index = this.children.length - 1; index >= 0; index -= 1) {
            if (this.children[index] instanceof FakeElement) {
                return this.children[index];
            }
        }
        return null;
    }

    /** Depth-first list of descendant elements. */
    elements() {
        const out = [];
        for (const child of this.children) {
            if (child instanceof FakeElement) {
                out.push(child, ...child.elements());
            }
        }
        return out;
    }
}

class FakeText extends FakeNode {
    constructor(text) {
        super('#text');
        this.text = text;
    }

    get textContent() {
        return this.text;
    }
}

class FakeFragment extends FakeNode {
    constructor() {
        super('#fragment');
    }
}

class FakeElement extends FakeNode {
    constructor(tagName) {
        super(tagName.toUpperCase());
        this.tagName = tagName.toUpperCase();
        this.attributes = {};
        this.dataset = {};
        this.className = '';
    }

    setAttribute(name, value) {
        this.attributes[name] = String(value);
    }

    getAttribute(name) {
        return this.attributes[name] ?? null;
    }
}

for (const property of ['href', 'target', 'rel', 'scope', 'start']) {
    Object.defineProperty(FakeElement.prototype, property, {
        get() {
            return this.attributes[property] ?? '';
        },
        set(value) {
            this.attributes[property] = String(value);
        },
    });
}

/** Minimal document implementing the APIs the Markdown renderer uses. */
export const fakeDocument = {
    createElement: (tag) => new FakeElement(tag),
    createTextNode: (text) => new FakeText(text),
    createDocumentFragment: () => new FakeFragment(),
};
