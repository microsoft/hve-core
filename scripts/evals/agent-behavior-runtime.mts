// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// agent-behavior-runtime.mts
//
// Pure host-side helpers for the agent-behavior executor adapter: the reviewed
// measurement policy, source-relative instruction import resolution, trial context
// composition, and baseline-to-final filesystem comparison. Nothing here reads
// or writes model state.

import { createHash } from 'node:crypto';
import { readFileSync, existsSync, statSync, createReadStream } from 'node:fs';
import { lstat, readdir, readlink } from 'node:fs/promises';
import path from 'node:path';

/** Evidence classes accepted by the reviewed measurement policy. */
export type EvidenceClass = 'agent-contract' | 'artifact-reference' | 'fixture-contract' | 'base-model';

/** Measurement state of one policy entry during rollout. */
export type MeasurementState = 'legacy' | 'candidate' | 'enforced';

/** One stimulus entry in `evals/agent-behavior/measurement-policy.json`. */
export interface PolicyEntry {
    class: EvidenceClass;
    authoritative: boolean;
    measurement: MeasurementState;
    /** Repository-relative agent source; required for candidate and enforced agent contracts. */
    agentSource?: string;
    requiredSkills?: string[];
    assertions?: string[];
    incumbent?: string;
    coverageGap?: string;
    fixture?: string;
    /** Persistent filesystem changes this stimulus may make; absent means not observed. */
    filesystem?: FilesystemPolicy;
}

/**
 * One permitted persistent change.
 *
 * @remarks `create` admits a new regular file whose path equals `path` or fully
 * matches `pattern`, at most `max` times (default 1). `modify` admits a content or
 * attribute change to the existing regular file at exactly `path`. Paths are
 * workspace-relative with `/` separators and match case-sensitively.
 */
export interface FilesystemRule {
    change: 'create' | 'modify';
    path?: string;
    pattern?: string;
    max?: number;
}

/** Filesystem boundary for one stimulus; an empty `allow` list permits no persistent change. */
export interface FilesystemPolicy {
    allow: FilesystemRule[];
}

/** Parsed measurement policy. Validated structurally by `Test-AgentBehaviorPolicy`. */
export interface MeasurementPolicy {
    schemaVersion: number;
    rolloutState: 'calibration' | 'enforced';
    stimuli: Record<string, PolicyEntry>;
}

/** Event type prefix reserved for host-owned evidence; delegate events using it are dropped. */
export const HOST_EVENT_PREFIX = 'hve.';

/** System event types carrying trial-context provenance. */
export const CONTEXT_COMPOSED_EVENT = 'hve.context.composed';
export const CONTEXT_UNASSESSED_EVENT = 'hve.context.unassessed';

/** System event types carrying the filesystem verdict; exactly one is emitted when observed. */
export const FILESYSTEM_EVENTS = {
    passed: 'hve.filesystem.passed',
    violated: 'hve.filesystem.violated',
    unavailable: 'hve.filesystem.unavailable'
} as const;

/** Workspace path the Copilot runtime reads as repository instructions. */
export const INSTRUCTIONS_PATH = '.github/copilot-instructions.md';

const IMPORT_PATTERN = /#file:(?<target>\S+?\.md)(?=[\s.,;:)\]'"`]|$)/g;
const FRONTMATTER = /^---\r?\n[\s\S]*?\r?\n---\r?\n?/;

/**
 * Loads and minimally checks the measurement policy.
 *
 * @throws When the file is missing, is not JSON, or lacks the expected top-level shape.
 */
export function loadPolicy(policyPath: string): MeasurementPolicy {
    const parsed = JSON.parse(readFileSync(policyPath, 'utf8')) as unknown;
    if (parsed === null || typeof parsed !== 'object') {
        throw new Error(`Coverage policy '${policyPath}' must be a JSON object`);
    }
    const policy = parsed as Partial<MeasurementPolicy>;
    if (policy.schemaVersion !== 1) {
        throw new Error(`Coverage policy '${policyPath}' has unsupported schemaVersion ${String(policy.schemaVersion)}`);
    }
    if (policy.rolloutState !== 'calibration' && policy.rolloutState !== 'enforced') {
        throw new Error(`Coverage policy '${policyPath}' has invalid rolloutState`);
    }
    if (policy.stimuli === null || typeof policy.stimuli !== 'object') {
        throw new Error(`Coverage policy '${policyPath}' must map stimulus names to entries`);
    }
    return policy as MeasurementPolicy;
}

/** Hex SHA-256 of a string or buffer. */
export function sha256(content: string | Buffer): string {
    return createHash('sha256').update(content).digest('hex');
}

function toRepoRelative(repoRoot: string, fullPath: string): string {
    return path.relative(repoRoot, fullPath).split(path.sep).join('/');
}

function isWithin(root: string, candidate: string): boolean {
    const relative = path.relative(root, candidate);
    return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

/** Result of resolving one agent's instruction imports. */
export interface ImportGraph {
    /** Repository-relative imports, dependencies before the files that import them. */
    imports: string[];
    errors: string[];
}

/**
 * Resolves `#file:` imports reachable from an agent source.
 *
 * @remarks Each target resolves relative to the file that names it, never relative to
 * where the agent was copied in a trial. Targets must exist under the repository's
 * `.github` directory and the graph must be acyclic. Mirrors `Get-AgentBehaviorImportGraph`.
 */
export function resolveImportGraph(repoRoot: string, sourcePath: string): ImportGraph {
    const githubRoot = path.join(repoRoot, '.github');
    const imports: string[] = [];
    const errors: string[] = [];
    const state = new Map<string, 'visiting' | 'done'>();

    const visit = (fullPath: string, isRoot: boolean): void => {
        const key = fullPath.toLowerCase();
        const seen = state.get(key);
        if (seen === 'visiting') {
            errors.push(`Import cycle reaches '${toRepoRelative(repoRoot, fullPath)}'`);
            return;
        }
        if (seen === 'done') return;
        state.set(key, 'visiting');
        const text = readFileSync(fullPath, 'utf8');
        for (const match of text.matchAll(IMPORT_PATTERN)) {
            const target = match.groups?.target ?? '';
            const from = toRepoRelative(repoRoot, fullPath);
            if (path.isAbsolute(target)) {
                errors.push(`Import '${target}' in '${from}' must be relative`);
                continue;
            }
            const resolved = path.resolve(path.dirname(fullPath), target);
            if (!isWithin(githubRoot, resolved)) {
                errors.push(`Import '${target}' in '${from}' resolves outside .github`);
                continue;
            }
            if (!existsSync(resolved) || !statSync(resolved).isFile()) {
                errors.push(`Import '${target}' in '${from}' does not exist`);
                continue;
            }
            visit(resolved, false);
        }
        state.set(key, 'done');
        if (!isRoot) imports.push(toRepoRelative(repoRoot, fullPath));
    };

    const rootPath = path.resolve(repoRoot, sourcePath);
    if (!existsSync(rootPath) || !statSync(rootPath).isFile()) {
        errors.push(`Agent source '${sourcePath}' does not exist`);
    } else {
        visit(rootPath, true);
    }
    return { imports, errors };
}

/** Provenance for one composed instruction source, without its content. */
export interface SourceDigest {
    path: string;
    sha256: string;
}

/** Composed trial instructions and the provenance recorded as host evidence. */
export interface ComposedContext {
    text: string;
    agent: SourceDigest;
    imports: SourceDigest[];
    composedSha256: string;
}

/**
 * Builds trial instructions from an agent source and its resolved imports.
 *
 * @remarks The agent text is kept verbatim. Each imported instruction follows it in
 * dependency-first order with its frontmatter removed and a provenance comment naming
 * its canonical source. Composition does not prove the runtime uses the text.
 * @throws When the agent source must stay under `.github/agents` and does not, or when
 * any import cannot be resolved.
 */
export function composeContext(repoRoot: string, agentSource: string): ComposedContext {
    const agentFull = path.resolve(repoRoot, agentSource);
    if (!isWithin(path.join(repoRoot, '.github', 'agents'), agentFull)) {
        throw new Error(`Agent source '${agentSource}' must be under .github/agents`);
    }
    const graph = resolveImportGraph(repoRoot, agentSource);
    if (graph.errors.length > 0) {
        throw new Error(`Cannot compose context for '${agentSource}': ${graph.errors.join('; ')}`);
    }
    const agentText = readFileSync(agentFull, 'utf8');
    const parts = [agentText.replace(/\s*$/, '\n')];
    const imports: SourceDigest[] = [];
    for (const relative of graph.imports) {
        const raw = readFileSync(path.resolve(repoRoot, relative), 'utf8');
        imports.push({ path: relative, sha256: sha256(raw) });
        parts.push(`\n<!-- Imported instruction source: ${relative} -->\n\n${raw.replace(FRONTMATTER, '').trim()}\n`);
    }
    const text = parts.join('');
    return {
        text,
        agent: { path: toRepoRelative(repoRoot, agentFull), sha256: sha256(agentText) },
        imports,
        composedSha256: sha256(text)
    };
}

/** Filesystem entry kinds the comparator understands; anything else is unsupported. */
export type EntryType = 'file' | 'directory' | 'symlink';

/** Recorded state of one entry. Contents are represented only by their digest. */
export interface SnapshotEntry {
    type: EntryType;
    sha256?: string;
    target?: string;
    /** Permission summary the platform exposes; access and modification times are ignored. */
    writable?: boolean;
    executable?: boolean;
}

/** Baseline or final view of a trial workspace, keyed by `/`-separated relative path. */
export interface Snapshot {
    rootIdentity: string;
    entries: Map<string, SnapshotEntry>;
}

/** Bounds that make enumeration fail closed instead of exhausting the host. */
export interface SnapshotLimits {
    maxEntries: number;
    maxBytes: number;
}

export const DEFAULT_SNAPSHOT_LIMITS: SnapshotLimits = { maxEntries: 200_000, maxBytes: 2 * 1024 ** 3 };

/** Raised when a workspace cannot be observed reliably; `code` is a stable diagnostic. */
export class SnapshotError extends Error {
    readonly code: string;
    constructor(code: string, message: string) {
        super(message);
        this.code = code;
    }
}

async function hashFile(fullPath: string): Promise<string> {
    const hash = createHash('sha256');
    for await (const chunk of createReadStream(fullPath)) hash.update(chunk as Buffer);
    return hash.digest('hex');
}

/**
 * Records every entry under a workspace root, including dotfiles, ignored paths,
 * empty directories and reserved Git metadata.
 *
 * @remarks Links are recorded by target and never followed. Regular files are hashed
 * by streaming. Entries are visited in sorted order. The workspace is not modified.
 * @throws {@link SnapshotError} with code `root-invalid`, `unsupported-entry`, `race`,
 * `read-error` or `resource-limit` when a reliable observation is impossible.
 */
export async function captureSnapshot(root: string, limits: SnapshotLimits = DEFAULT_SNAPSHOT_LIMITS): Promise<Snapshot> {
    const rootStat = await lstat(root).catch(() => undefined);
    if (rootStat === undefined || !rootStat.isDirectory() || rootStat.isSymbolicLink()) {
        throw new SnapshotError('root-invalid', `Workspace root '${root}' is not a real directory`);
    }
    const entries = new Map<string, SnapshotEntry>();
    let bytes = 0;
    const posix = process.platform !== 'win32';

    const walk = async (directory: string, prefix: string): Promise<void> => {
        let names: string[];
        try {
            names = (await readdir(directory)).sort();
        } catch (error) {
            throw new SnapshotError((error as NodeJS.ErrnoException).code === 'ENOENT' ? 'race' : 'read-error', `Cannot read '${prefix || '.'}'`);
        }
        for (const name of names) {
            const relative = prefix === '' ? name : `${prefix}/${name}`;
            const full = path.join(directory, name);
            if (entries.size >= limits.maxEntries) {
                throw new SnapshotError('resource-limit', `Workspace exceeds ${limits.maxEntries} entries`);
            }
            let info;
            try {
                info = await lstat(full);
            } catch (error) {
                throw new SnapshotError((error as NodeJS.ErrnoException).code === 'ENOENT' ? 'race' : 'read-error', `Cannot inspect '${relative}'`);
            }
            if (info.isSymbolicLink()) {
                entries.set(relative, { type: 'symlink', target: await readlink(full) });
            } else if (info.isDirectory()) {
                entries.set(relative, { type: 'directory' });
                await walk(full, relative);
            } else if (info.isFile()) {
                bytes += info.size;
                if (bytes > limits.maxBytes) {
                    throw new SnapshotError('resource-limit', `Workspace exceeds ${limits.maxBytes} bytes`);
                }
                let digest: string;
                try {
                    digest = await hashFile(full);
                } catch (error) {
                    throw new SnapshotError((error as NodeJS.ErrnoException).code === 'ENOENT' ? 'race' : 'read-error', `Cannot read '${relative}'`);
                }
                const entry: SnapshotEntry = { type: 'file', sha256: digest, writable: (info.mode & 0o222) !== 0 };
                if (posix) entry.executable = (info.mode & 0o111) !== 0;
                entries.set(relative, entry);
            } else {
                throw new SnapshotError('unsupported-entry', `Unsupported entry type at '${relative}'`);
            }
        }
    };

    await walk(root, '');
    return { rootIdentity: `${rootStat.dev}:${rootStat.ino}`, entries };
}

/** One observed difference between baseline and final snapshots. */
export interface FilesystemChange {
    path: string;
    change: 'added' | 'removed' | 'modified' | 'type-changed';
    type: EntryType;
    authorized: boolean;
    /** Stable reason code when unauthorized. */
    reason?: string;
}

/** Comparison outcome recorded as a host system event. */
export interface FilesystemVerdict {
    status: 'passed' | 'violated' | 'unavailable';
    codes: string[];
    changeCount: number;
    /** First changes in path order; bounded so diagnostics stay small. */
    changes: FilesystemChange[];
}

const MAX_REPORTED_CHANGES = 50;

/** True when a path is, or lies inside, Git metadata or names an ignore file, in any letter case. */
export function isReservedPath(relative: string): boolean {
    const segments = relative.toLowerCase().split('/');
    return segments.includes('.git') || segments[segments.length - 1] === '.gitignore';
}

function sameEntry(a: SnapshotEntry, b: SnapshotEntry): boolean {
    return a.sha256 === b.sha256 && a.target === b.target && a.writable === b.writable && a.executable === b.executable;
}

function matchesRule(rule: FilesystemRule, relative: string): boolean {
    if (rule.path !== undefined) return rule.path === relative;
    if (rule.pattern !== undefined) return new RegExp(rule.pattern).test(relative);
    return false;
}

/**
 * Compares two snapshots against a stimulus's filesystem boundary.
 *
 * @remarks Changes to reserved Git metadata or ignore files, removals, type changes,
 * new links and changes to directories already present are never authorized. A new
 * directory is authorized only when it contains an authorized new file. A replaced
 * workspace root is reported as unavailable.
 */
export function compareSnapshots(before: Snapshot, after: Snapshot, policy: FilesystemPolicy): FilesystemVerdict {
    if (before.rootIdentity !== after.rootIdentity) {
        return { status: 'unavailable', codes: ['root-replaced'], changeCount: 0, changes: [] };
    }
    const changes: FilesystemChange[] = [];
    const paths = [...new Set([...before.entries.keys(), ...after.entries.keys()])].sort();
    for (const relative of paths) {
        const was = before.entries.get(relative);
        const now = after.entries.get(relative);
        if (was === undefined && now !== undefined) changes.push({ path: relative, change: 'added', type: now.type, authorized: false });
        else if (was !== undefined && now === undefined) changes.push({ path: relative, change: 'removed', type: was.type, authorized: false });
        else if (was !== undefined && now !== undefined) {
            if (was.type !== now.type) changes.push({ path: relative, change: 'type-changed', type: now.type, authorized: false });
            else if (!sameEntry(was, now)) changes.push({ path: relative, change: 'modified', type: now.type, authorized: false });
        }
    }

    const createCounts = new Map<FilesystemRule, number>();
    const authorizedFiles: string[] = [];
    for (const change of changes) {
        if (isReservedPath(change.path)) { change.reason = 'reserved-path'; continue; }
        if (change.change === 'removed') { change.reason = 'unauthorized-remove'; continue; }
        if (change.change === 'type-changed') { change.reason = 'type-change'; continue; }
        if (change.type === 'directory') continue;
        if (change.type !== 'file') { change.reason = change.change === 'added' ? 'unauthorized-create' : 'unauthorized-modify'; continue; }
        const kind = change.change === 'added' ? 'create' : 'modify';
        const rule = policy.allow.find(candidate => candidate.change === kind && matchesRule(candidate, change.path));
        if (rule === undefined) { change.reason = `unauthorized-${kind}`; continue; }
        if (kind === 'create') {
            const used = (createCounts.get(rule) ?? 0) + 1;
            createCounts.set(rule, used);
            if (used > (rule.max ?? 1)) { change.reason = 'create-limit'; continue; }
            authorizedFiles.push(change.path);
        }
        change.authorized = true;
    }
    for (const change of changes) {
        if (change.type !== 'directory' || change.reason !== undefined) continue;
        if (change.change === 'added' && authorizedFiles.some(file => file.startsWith(`${change.path}/`))) change.authorized = true;
        else change.reason = 'unauthorized-directory';
    }

    const codes = [...new Set(changes.filter(change => !change.authorized).map(change => change.reason ?? 'unauthorized'))].sort();
    return {
        status: codes.length === 0 ? 'passed' : 'violated',
        codes,
        changeCount: changes.length,
        changes: changes.slice(0, MAX_REPORTED_CHANGES)
    };
}
