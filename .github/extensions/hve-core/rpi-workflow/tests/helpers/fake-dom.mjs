// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Minimal DOM for Node tests of the UI renderers. It covers only the APIs those
 * modules use, and serializes trees with escaped text so tests can assert structure.
 */

class FakeNode {
    constructor() {
        this.childNodes = [];
        this.parentNode = null;
    }

    appendChild(child) {
        if (child instanceof FakeFragment) {
            for (const node of [...child.childNodes]) this.appendChild(node);
            child.childNodes = [];
            return child;
        }
        child.parentNode?.removeChild(child);
        child.parentNode = this;
        this.childNodes.push(child);
        return child;
    }

    append(...items) {
        for (const item of items) this.appendChild(typeof item === 'string' ? new FakeText(item) : item);
    }

    removeChild(child) {
        this.childNodes = this.childNodes.filter((node) => node !== child);
        child.parentNode = null;
        return child;
    }

    get firstChild() {
        return this.childNodes[0] ?? null;
    }

    get textContent() {
        return this.childNodes.map((node) => node.textContent).join('');
    }

    set textContent(value) {
        this.childNodes = [];
        if (value !== '' && value !== null && value !== undefined) this.appendChild(new FakeText(String(value)));
    }
}

class FakeText extends FakeNode {
    constructor(data) {
        super();
        this.data = data;
    }

    get textContent() {
        return this.data;
    }

    set textContent(value) {
        this.data = String(value);
    }
}

class FakeFragment extends FakeNode {}

class FakeElement extends FakeNode {
    constructor(tag) {
        super();
        this.localName = tag;
        this.attributes = new Map();
        this.dataset = {};
        this.style = {};
        this.listeners = {};
        this.classList = {
            add: (...names) => {
                const set = new Set(this.className.split(/\s+/).filter(Boolean));
                for (const name of names) set.add(name);
                this.className = [...set].join(' ');
            },
            contains: (name) => this.className.split(/\s+/).includes(name),
        };
    }

    get className() {
        return this.attributes.get('class') ?? '';
    }

    set className(value) {
        this.attributes.set('class', String(value));
    }

    setAttribute(name, value) {
        this.attributes.set(name, String(value));
    }

    getAttribute(name) {
        return this.attributes.has(name) ? this.attributes.get(name) : null;
    }

    hasAttribute(name) {
        return this.attributes.has(name);
    }

    removeAttribute(name) {
        this.attributes.delete(name);
    }

    addEventListener(type, listener) {
        (this.listeners[type] ??= []).push(listener);
    }

    /** Supports single simple selectors: `.class`, `#id`, or `tag`. */
    querySelectorAll(selector) {
        const test = selector.startsWith('.')
            ? (el) => el.classList.contains(selector.slice(1))
            : selector.startsWith('#')
                ? (el) => el.getAttribute('id') === selector.slice(1)
                : (el) => el.localName === selector;
        return elements(this).filter(test);
    }

    querySelector(selector) {
        return this.querySelectorAll(selector)[0] ?? null;
    }
}

/** Installs the fake document and Node globals; returns a restore function. */
export function installFakeDom() {
    const previous = { document: globalThis.document, Node: globalThis.Node };
    globalThis.Node = FakeNode;
    globalThis.document = {
        createElement: (tag) => new FakeElement(tag),
        createElementNS: (_ns, tag) => new FakeElement(tag),
        createTextNode: (text) => new FakeText(String(text)),
        createDocumentFragment: () => new FakeFragment(),
    };
    return () => {
        globalThis.document = previous.document;
        globalThis.Node = previous.Node;
    };
}

const escape = (text) => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Serializes a fake tree; text is escaped, so markup in input can never appear as tags. */
export function serialize(node) {
    if (node instanceof FakeText) return escape(node.data);
    const inner = node.childNodes.map(serialize).join('');
    if (node instanceof FakeFragment) return inner;
    const attrs = [...node.attributes].map(([name, value]) => ` ${name}="${escape(value)}"`).join('');
    return `<${node.localName}${attrs}>${inner}</${node.localName}>`;
}

/** Every element in the tree, depth first. */
export function elements(node) {
    const out = [];
    const walk = (current) => {
        for (const child of current.childNodes) {
            if (child instanceof FakeElement) {
                out.push(child);
                walk(child);
            }
        }
    };
    walk(node);
    return out;
}
