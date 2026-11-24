#!/usr/bin/env node
// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Lists installed Copilot session event schemas, snapshots one into the Session Log canvas
 * baseline, or diffs one against that baseline with the event types the canvas handles flagged.
 *
 * Reads the selected schema (an installed `session-events.schema.json` or a `--schema` path), its
 * package version, the baseline, and the type lists exported by the canvas indexer, which it
 * imports. It never reads session logs. Output goes to stdout; `snapshot --write` writes only the
 * skill's `assets/event-shapes.json`, and only after the schema is confirmed to define event types.
 */

import { constants as fsConstants } from 'node:fs';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SKILL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const BASELINE_PATH = path.join(SKILL_ROOT, 'assets', 'event-shapes.json');
export const DEFAULT_INDEXER_PATH = path.resolve(SKILL_ROOT, '..', '..', 'extensions', 'hve-core', 'session-log', 'lib', 'indexer.mjs');
const SCHEMA_FILE = path.join('schemas', 'session-events.schema.json');
const MAX_SCHEMA_BYTES = 16 * 1024 * 1024;
const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_DEPTH = 3;
const MAX_ENUM = 12;
// Bounds for crafted schemas: signature nesting, work units shared by one extractShapes call, and
// characters per signature. The published schema uses a small fraction of each.
const MAX_SIGNATURE_DEPTH = 16;
const MAX_WORK = 200_000;
const MAX_SIGNATURE_LENGTH = 4096;
const MAX_REF_LENGTH = 256;
const TRUNCATED = '…';
const NAME_RE = /^[A-Za-z0-9_$.-]{1,96}$/;
const SHAPES_FORMAT = 1;

const USAGE = `Usage:
  node event-schema.mjs list [--json]
  node event-schema.mjs snapshot [--schema <path | version | latest>] [--write]
  node event-schema.mjs diff [--schema <path | version | latest>] [--baseline <path>] [--indexer <path>] [--json]

Options:
  --indexer <path>  Module whose HANDLED_EVENT_TYPES export marks handled types; defaults to the
                    canvas indexer. The module runs in this process, so pass only a trusted path.

Environment:
  COPILOT_HOME  Copilot home folder; defaults to ~/.copilot. Installed schemas are read from
                <COPILOT_HOME>/pkg/<platform>/<version>/schemas/session-events.schema.json.`;

class UsageError extends Error {}

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {string} The Copilot home folder.
 */
export function copilotHome(env = process.env) {
    return env.COPILOT_HOME && env.COPILOT_HOME.trim() ? path.resolve(env.COPILOT_HOME) : path.join(os.homedir(), '.copilot');
}

/**
 * Orders versions such as `0.0.420`, `1.0.96-2`, and `1.0.101` numerically, segment by segment.
 *
 * @param {string} a
 * @param {string} b
 * @returns {number}
 */
export function compareVersions(a, b) {
    const parts = (value) => String(value).split(/[^0-9]+/).filter(Boolean).map(Number);
    const x = parts(a);
    const y = parts(b);
    for (let i = 0; i < Math.max(x.length, y.length); i += 1) {
        const diff = (x[i] ?? 0) - (y[i] ?? 0);
        if (diff !== 0) {
            return diff;
        }
    }
    return 0;
}

// Read-only, without following a final symbolic link or blocking on a FIFO where the platform
// supports those flags.
const OPEN_FLAGS = fsConstants.O_RDONLY | (fsConstants.O_NOFOLLOW ?? 0) | (fsConstants.O_NONBLOCK ?? 0);

/**
 * Parses a JSON file of at most `maxBytes`. The type check, size check, and read all use one open
 * handle, so the file cannot be swapped between the check and the read.
 *
 * @param {string} file
 * @param {number} maxBytes
 * @returns {Promise<unknown>}
 */
async function readJson(file, maxBytes) {
    let handle;
    try {
        handle = await fs.open(file, OPEN_FLAGS);
    } catch (error) {
        if (error?.code === 'ELOOP') {
            throw new Error(`Not a regular file: ${file}`);
        }
        throw error;
    }
    try {
        const stat = await handle.stat();
        if (!stat.isFile()) {
            throw new Error(`Not a regular file: ${file}`);
        }
        if (stat.size > maxBytes) {
            throw new Error(`File exceeds ${maxBytes} bytes: ${file}`);
        }
        // One byte past the checked size detects a file that grew after the check.
        const buffer = Buffer.alloc(stat.size + 1);
        let length = 0;
        while (length < buffer.length) {
            const { bytesRead } = await handle.read(buffer, length, buffer.length - length, null);
            if (bytesRead === 0) {
                break;
            }
            length += bytesRead;
        }
        if (length > stat.size) {
            throw new Error(`File changed while reading: ${file}`);
        }
        return JSON.parse(buffer.toString('utf8', 0, length));
    } finally {
        await handle.close();
    }
}

/**
 * Reads the package name and version that own a schema file from `<package>/package.json`.
 *
 * @param {string} schemaPath Path to `<package>/schemas/session-events.schema.json`.
 * @returns {Promise<{ package: string | null, version: string | null }>}
 */
export async function packageFor(schemaPath) {
    try {
        const manifest = await readJson(path.join(path.dirname(path.dirname(schemaPath)), 'package.json'), MAX_MANIFEST_BYTES);
        return {
            package: typeof manifest.name === 'string' && /^[@a-z0-9/._-]{1,128}$/.test(manifest.name) ? manifest.name : null,
            version: typeof manifest.version === 'string' && NAME_RE.test(manifest.version) ? manifest.version : null,
        };
    } catch {
        return { package: null, version: null };
    }
}

/**
 * Finds installed session event schemas under `<home>/pkg/<platform>/<version>/`, oldest first.
 *
 * @param {string} home Copilot home folder.
 * @returns {Promise<Array<{ package: string | null, version: string, platform: string, path: string }>>}
 */
export async function findSchemas(home) {
    const pkg = path.join(home, 'pkg');
    const found = [];
    let platforms = [];
    try {
        platforms = await fs.readdir(pkg, { withFileTypes: true });
    } catch {
        return found;
    }
    for (const platform of platforms.filter((entry) => entry.isDirectory())) {
        let versions = [];
        try {
            versions = await fs.readdir(path.join(pkg, platform.name), { withFileTypes: true });
        } catch {
            continue;
        }
        for (const folder of versions.filter((entry) => entry.isDirectory())) {
            const root = path.join(pkg, platform.name, folder.name);
            const schema = path.join(root, SCHEMA_FILE);
            const stat = await fs.lstat(schema).catch(() => null);
            if (!stat?.isFile()) {
                continue;
            }
            const owner = await packageFor(schema);
            // The folder name is the version when the manifest is missing or unreadable.
            found.push({ package: owner.package, version: owner.version ?? folder.name, platform: platform.name, path: schema });
        }
    }
    return found.sort((a, b) => compareVersions(a.version, b.version) || a.platform.localeCompare(b.platform));
}

function refName(ref) {
    return typeof ref === 'string' && ref.length <= MAX_REF_LENGTH && ref.startsWith('#/') ? ref.split('/').pop() : null;
}

/**
 * Splits a signature into its top-level alternatives, ignoring ` | ` inside quoted strings,
 * parentheses, and angle brackets.
 *
 * @param {string} text
 * @returns {string[]}
 */
function topLevelAlternatives(text) {
    const parts = [];
    let depth = 0;
    let quoted = false;
    let start = 0;
    for (let i = 0; i < text.length; i += 1) {
        const char = text[i];
        if (quoted) {
            if (char === '\\') {
                i += 1;
            } else if (char === '"') {
                quoted = false;
            }
        } else if (char === '"') {
            quoted = true;
        } else if (char === '(' || char === '<') {
            depth += 1;
        } else if (char === ')' || char === '>') {
            depth -= 1;
        } else if (depth === 0 && text.startsWith(' | ', i)) {
            parts.push(text.slice(start, i));
            start = i + 3;
            i += 2;
        }
    }
    parts.push(text.slice(start));
    return parts;
}

/**
 * Joins signature alternatives with ` | `, keeping each top-level alternative once in first-seen
 * order, so merging `string` with `string | null` gives `string | null`.
 *
 * @param {string[]} list
 * @returns {string}
 */
function joinAlternatives(list) {
    return [...new Set(list.flatMap(topLevelAlternatives))].join(' | ');
}

/**
 * Summarizes a session events JSON Schema as event types with their `data` field paths and type
 * signatures. Follows local `$ref` links with cycle and depth guards. A field reached through more
 * than one union alternative, or through more than one root variant of the same type, lists every
 * signature it can have and is marked required only when every occurrence requires it. Signature
 * depth, total work, and signature length are bounded; a signature cut short ends in `…`.
 *
 * @param {object} schema Parsed `session-events.schema.json`.
 * @returns {Record<string, { ephemeral: boolean, fields: Record<string, string> }>}
 * @throws {Error} When the schema has no session event root or defines no event types.
 */
export function extractShapes(schema) {
    const defs = schema?.definitions ?? schema?.$defs ?? {};
    let work = MAX_WORK;
    // Charges units of the shared work budget; false once it is spent.
    const spend = (units) => (work -= units) >= 0;
    const resolve = (node) => {
        let current = node;
        for (let hops = 0; current && typeof current.$ref === 'string' && hops < 16; hops += 1) {
            const name = refName(current.$ref);
            current = name && Object.hasOwn(defs, name) ? defs[name] : null;
        }
        return current && typeof current === 'object' ? current : null;
    };
    const variantsOf = (node) => (Array.isArray(node?.anyOf) ? node.anyOf : Array.isArray(node?.oneOf) ? node.oneOf : null);
    const clip = (text) => (text.length > MAX_SIGNATURE_LENGTH ? `${text.slice(0, MAX_SIGNATURE_LENGTH - 1)}${TRUNCATED}` : text);
    // Charges a newly built string by its length.
    const built = (text) => (spend(text.length >> 6) ? clip(text) : TRUNCATED);
    // Const and enum signatures depend only on their node, so each is rendered once.
    const leaves = new Map();
    const leaf = (node, render) => {
        if (!leaves.has(node)) {
            leaves.set(node, clip(render()));
        }
        return leaves.get(node);
    };

    // Lists the sorted unique alternatives of a node's signature, flattening nested unions.
    const alternatives = (node, seen, depth) => {
        if (depth > MAX_SIGNATURE_DEPTH || !spend(1)) {
            return [TRUNCATED];
        }
        const name = refName(node?.$ref);
        if (name && seen.has(name)) {
            return [`ref(${name})`];
        }
        const next = name ? new Set([...seen, name]) : seen;
        const resolved = resolve(node);
        if (!resolved) {
            return ['unknown'];
        }
        if (Object.hasOwn(resolved, 'const')) {
            return [leaf(resolved, () => `const(${JSON.stringify(resolved.const)})`)];
        }
        if (Array.isArray(resolved.enum)) {
            return [leaf(resolved, () => {
                const values = resolved.enum.slice(0, MAX_ENUM).map((value) => JSON.stringify(value));
                return `enum(${values.join('|')}${resolved.enum.length > MAX_ENUM ? '|…' : ''})`;
            })];
        }
        const variants = variantsOf(resolved);
        if (variants) {
            const found = new Set();
            let length = 0;
            for (const variant of variants) {
                for (const text of alternatives(variant, next, depth + 1)) {
                    if (!found.has(text)) {
                        found.add(text);
                        length += text.length + 3;
                    }
                }
                if (length > MAX_SIGNATURE_LENGTH || work < 0) {
                    found.add(TRUNCATED);
                    break;
                }
            }
            return [...found].sort();
        }
        const types = Array.isArray(resolved.type) ? resolved.type : resolved.type ? [resolved.type] : resolved.properties ? ['object'] : ['any'];
        if (!spend(types.length)) {
            return [TRUNCATED];
        }
        return [built(types.map((type) => (type === 'array' ? `array<${resolved.items ? signature(resolved.items, next, depth + 1) : 'any'}>` : type)).join(' | '))];
    };
    const signature = (node, seen, depth) => built(joinAlternatives(alternatives(node, seen, depth)));

    // Adds one occurrence of a field: its signature alternatives and whether it was required there.
    const record = (fields, path, found, required) => {
        const entry = fields.get(path) ?? { signatures: new Set(), length: 0, required };
        entry.required &&= required;
        for (const text of found) {
            if (entry.length <= MAX_SIGNATURE_LENGTH && !entry.signatures.has(text)) {
                entry.signatures.add(text);
                entry.length += text.length + 3;
            }
        }
        fields.set(path, entry);
    };

    const walk = (node, prefix, depth, seen, fields, required) => {
        const name = refName(node?.$ref);
        const cycle = Boolean(name && seen.has(name));
        const found = cycle ? [`ref(${name})`] : alternatives(node, seen, 0);
        const size = found.reduce((total, text) => total + text.length, prefix.length);
        record(fields, prefix, spend(1 + (size >> 6)) ? found : [TRUNCATED], required);
        if (cycle || depth >= MAX_DEPTH || work < 0) {
            return;
        }
        // Marks this field when the budget runs out before all of its children are walked.
        const cut = () => record(fields, prefix, [TRUNCATED], required);
        const next = name ? new Set([...seen, name]) : seen;
        const resolved = resolve(node);
        const options = variantsOf(resolved) ?? [resolved];
        if (!spend(options.length)) {
            cut();
            return;
        }
        const objects = options.map(resolve).filter(Boolean);
        for (const object of objects) {
            const keys = Object.keys(object.properties ?? {});
            const requiredKeys = Array.isArray(object.required) ? object.required : [];
            if (!spend(keys.length + requiredKeys.length)) {
                cut();
                return;
            }
            const requiredSet = new Set(requiredKeys);
            const children = keys.filter((key) => NAME_RE.test(key)).map((key) => [object.properties[key], `${prefix}.${key}`, requiredSet.has(key) && objects.length === 1]);
            if (object.additionalProperties && typeof object.additionalProperties === 'object') {
                children.push([object.additionalProperties, `${prefix}.*`, false]);
            }
            if (object.type === 'array' && object.items) {
                const items = resolve(object.items);
                if (items?.properties || variantsOf(items)) {
                    children.push([object.items, `${prefix}[]`, false]);
                }
            }
            for (const [child, path, childRequired] of children) {
                walk(child, path, depth + 1, next, fields, childRequired);
                if (work < 0) {
                    cut();
                    return;
                }
            }
        }
    };

    const events = variantsOf(resolve(schema?.$ref ? schema : defs.SessionEvent));
    if (!events) {
        throw new Error('no session event root was found; expected a top-level $ref or a SessionEvent definition that lists the event variants in anyOf or oneOf');
    }
    const types = new Map();
    for (const variant of events) {
        const event = resolve(variant);
        const type = event?.properties?.type?.const;
        if (typeof type !== 'string' || !NAME_RE.test(type)) {
            continue;
        }
        const entry = types.get(type) ?? { ephemeral: true, fields: new Map() };
        entry.ephemeral &&= event.properties.ephemeral?.const === true;
        if (event.properties.data) {
            const requiredKeys = Array.isArray(event.required) ? event.required : [];
            walk(event.properties.data, 'data', 0, new Set(), entry.fields, spend(1 + requiredKeys.length) && requiredKeys.includes('data'));
        }
        types.set(type, entry);
    }
    if (types.size === 0) {
        throw new Error('no event types were found; no session event variant has a usable type constant');
    }
    const render = (fields) => Object.fromEntries([...fields].map(([path, entry]) => [path, `${clip(joinAlternatives([...entry.signatures].sort()))}${entry.required ? ' required' : ''}`]));
    return Object.fromEntries([...types].sort(([a], [b]) => a.localeCompare(b)).map(([type, entry]) => [type, { ephemeral: entry.ephemeral, fields: render(entry.fields) }]));
}

/**
 * @param {Date} date
 * @returns {string} The local calendar date as `YYYY-MM-DD`.
 */
function localDate(date) {
    const pad = (value) => String(value).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/**
 * Builds a baseline document from a schema.
 *
 * @param {object} schema
 * @param {{ package?: string | null, version: string, platform?: string | null }} source
 * @param {Date} [now]
 * @throws {Error} When the schema is not a session events schema; see `extractShapes`.
 */
export function buildSnapshot(schema, source, now = new Date()) {
    return {
        format: SHAPES_FORMAT,
        source: { package: source.package ?? null, version: source.version, platform: source.platform ?? null, captured: localDate(now) },
        types: extractShapes(schema),
    };
}

/**
 * Compares a baseline with a current shape set and flags types the canvas handles.
 *
 * @param {{ types: Record<string, { ephemeral: boolean, fields: Record<string, string> }> }} baseline
 * @param {{ types: Record<string, { ephemeral: boolean, fields: Record<string, string> }> }} current
 * @param {{ types: Set<string>, prefixes: readonly string[] }} handled
 */
export function diffShapes(baseline, current, handled) {
    const isHandled = (type) => handled.types.has(type) || handled.prefixes.some((prefix) => type.startsWith(prefix));
    const before = baseline.types ?? {};
    const after = current.types ?? {};
    const added = [];
    const removed = [];
    const changed = [];
    for (const [type, shape] of Object.entries(after)) {
        if (!Object.hasOwn(before, type)) {
            added.push({ type, ephemeral: shape.ephemeral, handled: isHandled(type), fieldCount: Object.keys(shape.fields).length });
            continue;
        }
        const old = before[type];
        const fieldsAdded = [];
        const fieldsRemoved = [];
        const fieldsChanged = [];
        for (const [field, sig] of Object.entries(shape.fields)) {
            if (!Object.hasOwn(old.fields, field)) {
                fieldsAdded.push({ field, to: sig });
            } else if (old.fields[field] !== sig) {
                fieldsChanged.push({ field, from: old.fields[field], to: sig });
            }
        }
        for (const [field, sig] of Object.entries(old.fields)) {
            if (!Object.hasOwn(shape.fields, field)) {
                fieldsRemoved.push({ field, from: sig });
            }
        }
        if (fieldsAdded.length || fieldsRemoved.length || fieldsChanged.length || old.ephemeral !== shape.ephemeral) {
            changed.push({ type, handled: isHandled(type), ephemeral: shape.ephemeral, ephemeralBefore: old.ephemeral, fieldsAdded, fieldsRemoved, fieldsChanged });
        }
    }
    for (const [type, shape] of Object.entries(before)) {
        if (!Object.hasOwn(after, type)) {
            removed.push({ type, ephemeral: shape.ephemeral, handled: isHandled(type) });
        }
    }
    const handledNotInSchema = [...handled.types].filter((type) => !Object.hasOwn(after, type)).sort();
    return { baseline: baseline.source ?? null, current: current.source ?? null, added, removed, changed, handledNotInSchema };
}

const code = (value) => `\`${String(value).replace(/`/g, "'")}\``;

/**
 * Renders a diff as a Markdown report.
 *
 * @param {ReturnType<typeof diffShapes>} diff
 * @returns {string}
 */
export function renderMarkdown(diff) {
    const lines = ['# Session event schema diff', ''];
    const describe = (source) => (source ? `${source.package ? `${source.package} ` : ''}${source.version}${source.platform ? ` (${source.platform})` : ''}${source.captured ? `, captured ${source.captured}` : ''}` : 'unknown');
    lines.push(`* Baseline: ${describe(diff.baseline)}`, `* Current: ${describe(diff.current)}`, '');
    const handledChanges = diff.changed.filter((item) => item.handled);
    const persistedAdded = diff.added.filter((item) => !item.ephemeral);
    lines.push(`* Handled types changed: ${handledChanges.length}`, `* New persisted types: ${persistedAdded.length}`, `* Removed types: ${diff.removed.length}`, '');

    lines.push('## Handled types that changed', '');
    if (handledChanges.length === 0) {
        lines.push('None.', '');
    }
    for (const item of handledChanges) {
        lines.push(`### ${code(item.type)}`, '');
        if (item.ephemeral !== item.ephemeralBefore) {
            lines.push(`* Ephemeral: ${item.ephemeralBefore} to ${item.ephemeral}`);
        }
        for (const field of item.fieldsAdded) {
            lines.push(`* Added ${code(field.field)}: ${code(field.to)}`);
        }
        for (const field of item.fieldsRemoved) {
            lines.push(`* Removed ${code(field.field)}: was ${code(field.from)}`);
        }
        for (const field of item.fieldsChanged) {
            lines.push(`* Changed ${code(field.field)}: ${code(field.from)} to ${code(field.to)}`);
        }
        lines.push('');
    }

    lines.push('## New event types', '');
    if (diff.added.length === 0) {
        lines.push('None.', '');
    } else {
        lines.push('| Type | Persisted | Handled | Fields |', '|------|-----------|---------|--------|');
        for (const item of [...diff.added].sort((a, b) => Number(a.ephemeral) - Number(b.ephemeral) || a.type.localeCompare(b.type))) {
            lines.push(`| ${code(item.type)} | ${item.ephemeral ? 'no' : 'yes'} | ${item.handled ? 'yes' : 'no'} | ${item.fieldCount} |`);
        }
        lines.push('');
    }

    lines.push('## Removed event types', '');
    lines.push(diff.removed.length === 0 ? 'None.' : diff.removed.map((item) => `* ${code(item.type)}${item.handled ? ' (handled by the canvas)' : ''}`).join('\n'), '');

    const other = diff.changed.filter((item) => !item.handled);
    lines.push('## Other changed types', '');
    lines.push(other.length === 0 ? 'None.' : other.map((item) => `* ${code(item.type)}${item.ephemeral ? ' (ephemeral)' : ''}: ${item.fieldsAdded.length} added, ${item.fieldsRemoved.length} removed, ${item.fieldsChanged.length} changed`).join('\n'), '');

    if (diff.handledNotInSchema.length > 0) {
        lines.push('## Handled types missing from the current schema', '');
        lines.push('These types are read by the canvas but not defined in the schema; they may be internal, renamed, or removed.', '');
        lines.push(diff.handledNotInSchema.map((type) => `* ${code(type)}`).join('\n'), '');
    }
    return `${lines.join('\n').trimEnd()}\n`;
}

/**
 * Loads the event types the canvas handles from its indexer module. Importing runs the module, so
 * the path must be trusted.
 *
 * @param {string} indexerPath
 */
export async function loadHandled(indexerPath) {
    const mod = await import(pathToFileURL(path.resolve(indexerPath)).href);
    if (!Array.isArray(mod.HANDLED_EVENT_TYPES)) {
        throw new Error(`The indexer at ${indexerPath} does not export HANDLED_EVENT_TYPES`);
    }
    return { types: new Set(mod.HANDLED_EVENT_TYPES), prefixes: Array.isArray(mod.HANDLED_EVENT_PREFIXES) ? mod.HANDLED_EVENT_PREFIXES : [] };
}

function parseArgs(argv) {
    const [command, ...rest] = argv;
    const options = { json: false, write: false };
    for (let i = 0; i < rest.length; i += 1) {
        const arg = rest[i];
        if (arg === '--json') {
            options.json = true;
        } else if (arg === '--write') {
            options.write = true;
        } else if (arg === '--schema' || arg === '--baseline' || arg === '--indexer') {
            const value = rest[i + 1];
            if (!value || value.startsWith('--')) {
                throw new UsageError(`${arg} needs a value`);
            }
            options[arg.slice(2)] = value;
            i += 1;
        } else {
            throw new UsageError(`Unknown argument: ${arg}`);
        }
    }
    return { command, options };
}

async function resolveSchema(selector, env) {
    if (selector && selector.endsWith('.json')) {
        const schemaPath = path.resolve(selector);
        const owner = await packageFor(schemaPath);
        return { path: schemaPath, package: owner.package, version: owner.version ?? 'unknown', platform: null };
    }
    const installed = await findSchemas(copilotHome(env));
    if (installed.length === 0) {
        throw new Error(`No session-events.schema.json found under ${path.join(copilotHome(env), 'pkg')}. Pass --schema <path>.`);
    }
    if (!selector || selector === 'latest') {
        return installed[installed.length - 1];
    }
    const match = installed.filter((item) => item.version === selector);
    if (match.length === 0) {
        throw new Error(`No installed schema for version ${selector}. Run the list command to see installed versions.`);
    }
    return match[match.length - 1];
}

/**
 * Reads a schema file and builds its snapshot, naming the file when it is not a session events
 * schema so callers fail before writing anything.
 *
 * @param {{ path: string, package?: string | null, version: string, platform?: string | null }} source
 * @param {Date} [now]
 */
async function readSnapshot(source, now) {
    const schema = await readJson(source.path, MAX_SCHEMA_BYTES);
    try {
        return buildSnapshot(schema, source, now);
    } catch (error) {
        throw new Error(`${source.path} is not a session events schema: ${error instanceof Error ? error.message : String(error)}`);
    }
}

/**
 * Runs a command and returns its exit code.
 *
 * @param {string[]} argv
 * @param {{ env?: NodeJS.ProcessEnv, stdout?: (text: string) => void, stderr?: (text: string) => void, baselinePath?: string, now?: Date }} [io]
 * @returns {Promise<number>}
 */
export async function main(argv, io = {}) {
    const env = io.env ?? process.env;
    const out = io.stdout ?? ((text) => process.stdout.write(text));
    const err = io.stderr ?? ((text) => process.stderr.write(text));
    try {
        const { command, options } = parseArgs(argv);
        if (command === 'list') {
            const installed = await findSchemas(copilotHome(env));
            if (options.json) {
                out(`${JSON.stringify(installed.map((item) => ({ package: item.package, version: item.version, platform: item.platform })), null, 2)}\n`);
            } else {
                out(installed.length === 0 ? `No installed schemas under ${path.join(copilotHome(env), 'pkg')}.\n` : `${installed.map((item) => `${item.version}\t${item.platform}\t${item.package ?? ''}`.trimEnd()).join('\n')}\n`);
            }
            return 0;
        }
        if (command === 'snapshot') {
            const source = await resolveSchema(options.schema, env);
            const snapshot = await readSnapshot(source, io.now);
            const text = `${JSON.stringify(snapshot, null, 2)}\n`;
            if (options.write) {
                const target = io.baselinePath ?? BASELINE_PATH;
                await fs.mkdir(path.dirname(target), { recursive: true });
                await fs.writeFile(target, text);
                out(`Wrote ${Object.keys(snapshot.types).length} event types from ${source.version} to ${path.relative(process.cwd(), target) || target}\n`);
            } else {
                out(text);
            }
            return 0;
        }
        if (command === 'diff') {
            const baseline = await readJson(path.resolve(options.baseline ?? io.baselinePath ?? BASELINE_PATH), MAX_SCHEMA_BYTES);
            if (baseline.format !== SHAPES_FORMAT || typeof baseline.types !== 'object') {
                throw new Error('The baseline is not an event-shapes document; recreate it with snapshot --write.');
            }
            const source = await resolveSchema(options.schema, env);
            const current = await readSnapshot(source, io.now);
            const handled = await loadHandled(options.indexer ?? DEFAULT_INDEXER_PATH);
            const diff = diffShapes(baseline, current, handled);
            out(options.json ? `${JSON.stringify(diff, null, 2)}\n` : renderMarkdown(diff));
            return 0;
        }
        throw new UsageError(command ? `Unknown command: ${command}` : 'Missing command');
    } catch (error) {
        if (error instanceof UsageError) {
            err(`${error.message}\n\n${USAGE}\n`);
            return 2;
        }
        err(`${error instanceof Error ? error.message : String(error)}\n`);
        return 1;
    }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    process.exitCode = await main(process.argv.slice(2));
}
