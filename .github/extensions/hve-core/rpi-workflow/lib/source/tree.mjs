// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The session tree: every task whose state sits in one session folder, parents before
 * children. A child's `parent_task` decides where it sits; its parent's `child_tasks`
 * orders siblings. Pure functions: the workspace reader supplies states, titles, and the
 * parents it resolved outside the folder, and reports what it could not read.
 */

/**
 * @typedef {object} TreeMember
 * @property {string} path Workspace-relative state path.
 * @property {number} mtimeMs
 * @property {ReturnType<typeof import('./parse.mjs').parseState>} state
 * @property {string} title
 * @property {'completed' | 'running' | 'stopped'} status
 */

/**
 * @typedef {object} TreeTask
 * @property {string} id Task ID.
 * @property {string} title
 * @property {'completed' | 'running' | 'stopped'} status
 * @property {number} depth 0 for a task that continues no task in this folder.
 * @property {string} statePath
 * @property {string | null} parent State path of the parent in this folder.
 * @property {boolean} shown True for the task the canvas shows.
 * @property {{ id: string, title: string, statePath: string, session: string, status: string } | null} continues
 *   A parent in another session folder.
 * @property {number} changedAt When the state file last changed, in milliseconds.
 */

/** Session folder name as words: hyphens become spaces and the first letter is capitalized. */
export function humanizeSlug(slug) {
    const words = String(slug ?? '').replace(/-+/g, ' ').trim();
    return words ? words[0].toUpperCase() + words.slice(1) : '';
}

/**
 * Builds the tree in display order (depth first). Every member appears once: a member the
 * links do not reach from a top-level task, such as one in a parent loop, is listed at the
 * end with a warning.
 *
 * @param {{
 *   members: TreeMember[],
 *   shownPath: string,
 *   outside?: Map<string, { id: string, title: string, statePath: string, session: string, status: string } | { error: string }>,
 * }} input `outside` holds what the reader found for parent paths in other folders, keyed by the path a child names.
 * @returns {{ tasks: TreeTask[], warnings: string[] }}
 */
export function buildTree({ members, shownPath, outside = new Map() }) {
    const warnings = [];
    const byPath = new Map(members.map((member) => [member.path, member]));
    const byTask = new Map();
    for (const member of [...members].sort((a, b) => b.mtimeMs - a.mtimeMs)) {
        if (member.state.taskId && !byTask.has(member.state.taskId)) byTask.set(member.state.taskId, member);
    }
    const label = (member) => member.state.taskId ?? member.path;
    const find = (link) => (link.statePath ? byPath.get(link.statePath) : undefined) ?? (link.taskId ? byTask.get(link.taskId) : undefined);

    /** @type {Map<string, string>} child path to parent path */
    const parentOf = new Map();
    /** @type {Map<string, any>} */
    const continues = new Map();
    for (const member of members) {
        const link = member.state.parent;
        if (!link) continue;
        const resolved = link.statePath && !byPath.has(link.statePath) ? outside.get(link.statePath) : undefined;
        if (resolved && !resolved.error) {
            continues.set(member.path, resolved);
            continue;
        }
        const parent = find(link);
        if (parent && parent.path !== member.path) {
            parentOf.set(member.path, parent.path);
        } else {
            warnings.push(`${label(member)} continues ${link.taskId ?? link.statePath}, which ${resolved?.error ? `could not be read: ${resolved.error.replace(/\.$/, '')}` : 'is not in this session'}.`);
        }
    }

    // A parent that lists a child whose own parent link is missing or unreadable adopts it.
    for (const member of members) {
        for (const link of member.state.children) {
            const child = find(link);
            if (!child) {
                warnings.push(`${label(member)} lists child ${link.taskId ?? link.statePath}, whose state file is missing.`);
            } else if (!parentOf.has(child.path) && !continues.has(child.path) && child.path !== member.path) {
                parentOf.set(child.path, member.path);
            } else if (parentOf.get(child.path) !== member.path) {
                warnings.push(`${label(member)} lists child ${label(child)}, whose state names another parent.`);
            }
        }
    }

    /** @type {Map<string, TreeMember[]>} */
    const children = new Map();
    for (const [childPath, parentPath] of parentOf) {
        const list = children.get(parentPath) ?? [];
        list.push(/** @type {TreeMember} */ (byPath.get(childPath)));
        children.set(parentPath, list);
    }
    const ordered = (parent) => {
        const kids = children.get(parent.path) ?? [];
        const listed = [];
        for (const link of parent.state.children) {
            const child = find(link);
            if (child && kids.includes(child) && !listed.includes(child)) listed.push(child);
        }
        const unlisted = kids.filter((child) => !listed.includes(child)).sort((a, b) => a.mtimeMs - b.mtimeMs || a.path.localeCompare(b.path));
        for (const child of unlisted) warnings.push(`${label(parent)} does not list its child ${label(child)} in child_tasks.`);
        return [...listed, ...unlisted];
    };

    /** @type {TreeTask[]} */
    const tasks = [];
    const visited = new Set();
    const visit = (member, depth) => {
        if (visited.has(member.path)) return;
        visited.add(member.path);
        tasks.push({
            id: member.state.taskId ?? member.path,
            title: member.title,
            status: member.status,
            depth,
            statePath: member.path,
            parent: parentOf.get(member.path) ?? null,
            shown: member.path === shownPath,
            continues: continues.get(member.path) ?? null,
            changedAt: member.mtimeMs ?? 0,
        });
        for (const child of ordered(member)) visit(child, depth + 1);
    };
    const roots = members.filter((member) => !parentOf.has(member.path)).sort((a, b) => label(a).localeCompare(label(b)));
    for (const root of roots) visit(root, 0);
    for (const member of members) {
        if (visited.has(member.path)) continue;
        warnings.push(`${label(member)} is not reached from a top-level task; its parent links form a loop.`);
        visit(member, 0);
    }
    return { tasks, warnings };
}

/** The task that changed last; the earlier one in tree order wins a tie. */
const newest = (tasks) => tasks.reduce((best, task) => (best === null || (task.changedAt ?? 0) > (best.changedAt ?? 0) ? task : best), /** @type {TreeTask | null} */ (null));

/**
 * Where the agent works in the session: the running task that changed last, or, when none
 * runs, the task that changed last among those no other task continues, its latest loop.
 *
 * @param {TreeTask[]} tasks
 * @returns {TreeTask | null}
 */
export function agentTask(tasks) {
    const running = tasks.filter((task) => task.status === 'running');
    if (running.length) return newest(running);
    const parents = new Set(tasks.map((task) => task.parent).filter(Boolean));
    return newest(tasks.filter((task) => !parents.has(task.statePath)));
}

/**
 * The task to follow next: once the followed task is no longer running, the running task
 * that changed last, wherever it sits in the session. Null while the followed task runs,
 * when it is not in the session, or when no task runs.
 *
 * @param {TreeTask[]} tasks
 * @param {string} statePath The followed task's state path.
 * @returns {TreeTask | null}
 */
export function nextFollowTarget(tasks, statePath) {
    const self = tasks.find((task) => task.statePath === statePath);
    if (!self || self.status === 'running') return null;
    return newest(tasks.filter((task) => task.status === 'running'));
}
