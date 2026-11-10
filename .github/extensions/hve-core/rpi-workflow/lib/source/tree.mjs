// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The session tree: every task whose state sits in one session folder, parents before
 * children. A child's `parent_task` decides where it sits; its parent's `child_tasks`
 * orders siblings. Pure functions: the workspace reader supplies states, titles, and the
 * tasks its links reach outside the folder, and reports what it could not read.
 *
 * A link that names a Copilot session (`session_id`) reaches a task in that session's
 * workspace. The tree never matches such a link to a task of this folder by ID or path, and a
 * linked child is a leaf labeled with its session; the tree does not read that session's own tasks.
 */

/**
 * @typedef {object} LinkedTask A task reached through a link outside this folder.
 * @property {string} id Task ID.
 * @property {string} title
 * @property {'completed' | 'running' | 'stopped'} status
 * @property {string} statePath Workspace-relative state path, in the task's own workspace.
 * @property {string} session `<date>/<session>` of the task's folder.
 * @property {number} changedAt
 * @property {string | null} phase The task's phase in the canvas vocabulary, when it has one.
 * @property {string | null} sessionId The Copilot session that holds the task, when a link names one.
 * @property {string | null} sessionName That session's name, or a short form of its ID.
 * @property {string | null} root The real path of that session's workspace.
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
 * @property {LinkedTask | null} continues A parent reached through a link outside this folder.
 * @property {number} changedAt When the state file last changed, in milliseconds.
 * @property {string | null} sessionId Copilot session of a child task in another session; null for a task of this folder.
 * @property {string | null} sessionName That session's label, for a child task in another session.
 * @property {string | null} root That session's workspace root, for a child task in another session.
 * @property {string | null} phase The child task's phase, for a child task in another session.
 */

/** True when a link names a Copilot session, even one that is not a valid ID. */
export const namesSession = (link) => typeof link?.sessionId === 'string';

/**
 * The key a link's reached task is stored under: the state path for a link that names no
 * session, and the session, path, and task ID for one that does.
 *
 * @param {{ sessionId?: string | null, statePath?: string | null, taskId?: string | null }} link
 * @returns {string | null}
 */
export function linkKey(link) {
    if (!namesSession(link)) return link.statePath ?? null;
    return `session:${link.sessionId.toLowerCase()}\n${link.statePath ?? ''}\n${link.taskId ?? ''}`;
}

/** How a link is named in a warning: its task, the session it names, and its state path. */
function linkName(link) {
    const session = namesSession(link) ? `in Copilot session ${link.sessionId || '(not a session ID)'} ` : '';
    return `${link.taskId ?? link.statePath} ${session}${link.statePath ? `at ${link.statePath}` : 'with no state path'}`;
}

/** A reason as a clause, without its final period. */
const reasonOf = (text) => String(text).replace(/\.$/, '');

/** Session folder name as words: hyphens become spaces and the first letter is capitalized. */
export function humanizeSlug(slug) {
    const words = String(slug ?? '').replace(/-+/g, ' ').trim();
    return words ? words[0].toUpperCase() + words.slice(1) : '';
}

/**
 * Builds the tree in display order (depth first). Every member appears once: a member the
 * links do not reach from a top-level task, such as one in a parent loop, is listed at the
 * end with a warning. A child that names another session is placed where its parent lists
 * it, and a parent reached through such a link is shown as a continuation.
 *
 * @param {{
 *   members: TreeMember[],
 *   shownPath: string,
 *   outside?: Map<string, LinkedTask | { error: string }>,
 * }} input `outside` holds what the reader found for each link that reaches outside this folder, keyed by `linkKey`.
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
    // A link that names a session never matches this folder: its task IDs and paths may repeat in another workspace.
    const find = (link) => (namesSession(link) ? undefined : (link.statePath ? byPath.get(link.statePath) : undefined) ?? (link.taskId ? byTask.get(link.taskId) : undefined));
    const reached = (link) => outside.get(linkKey(link));
    const unreached = (link, resolved) => (namesSession(link)
        ? `${linkName(link)}, which could not be read${resolved?.error ? `: ${reasonOf(resolved.error)}` : ''}`
        : `${link.taskId ?? link.statePath}, which ${resolved?.error ? `could not be read: ${reasonOf(resolved.error)}` : 'is not in this session'}`);

    /** @type {Map<string, string>} child path to parent path */
    const parentOf = new Map();
    /** @type {Map<string, any>} */
    const continues = new Map();
    for (const member of members) {
        const link = member.state.parent;
        if (!link) continue;
        const resolved = namesSession(link) || (link.statePath && !byPath.has(link.statePath)) ? reached(link) : undefined;
        if (resolved && !resolved.error) {
            continues.set(member.path, resolved);
            continue;
        }
        const parent = find(link);
        if (parent && parent.path !== member.path) {
            parentOf.set(member.path, parent.path);
        } else {
            warnings.push(`${label(member)} continues ${unreached(link, resolved)}.`);
        }
    }

    // A parent that lists a child whose own parent link is missing or unreadable adopts it.
    for (const member of members) {
        for (const link of member.state.children) {
            if (namesSession(link)) {
                const linked = reached(link);
                if (!linked || linked.error) warnings.push(`${label(member)} lists child ${unreached(link, linked)}.`);
                continue;
            }
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
    /**
     * A parent's children in its `child_tasks` order, linked children among them, then the
     * unlisted members by age. Each item is a member or a linked child.
     *
     * @returns {({ member: TreeMember } | { linked: LinkedTask })[]}
     */
    const ordered = (parent) => {
        const kids = children.get(parent.path) ?? [];
        const listed = [];
        for (const link of parent.state.children) {
            if (namesSession(link)) {
                const linked = reached(link);
                if (linked && !linked.error && !listed.some((item) => item.linked === linked)) listed.push({ linked });
                continue;
            }
            const child = find(link);
            if (child && kids.includes(child) && !listed.some((item) => item.member === child)) listed.push({ member: child });
        }
        const unlisted = kids.filter((child) => !listed.some((item) => item.member === child)).sort((a, b) => a.mtimeMs - b.mtimeMs || a.path.localeCompare(b.path));
        for (const child of unlisted) warnings.push(`${label(parent)} does not list its child ${label(child)} in child_tasks.`);
        return [...listed, ...unlisted.map((member) => ({ member }))];
    };

    /** @type {TreeTask[]} */
    const tasks = [];
    const visited = new Set();
    const placedLinked = new Set();
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
            sessionId: null,
            sessionName: null,
            root: null,
            phase: null,
        });
        for (const item of ordered(member)) {
            if (item.member) {
                visit(item.member, depth + 1);
            } else if (!placedLinked.has(item.linked)) {
                placedLinked.add(item.linked);
                tasks.push({
                    id: item.linked.id,
                    title: item.linked.title,
                    status: item.linked.status,
                    depth: depth + 1,
                    statePath: item.linked.statePath,
                    parent: member.path,
                    shown: false,
                    continues: null,
                    changedAt: item.linked.changedAt ?? 0,
                    sessionId: item.linked.sessionId,
                    sessionName: item.linked.sessionName,
                    root: item.linked.root,
                    phase: item.linked.phase,
                });
            }
        }
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
 * Tasks in other sessions are not the session's, so they are left out.
 *
 * @param {TreeTask[]} tasks
 * @returns {TreeTask | null}
 */
export function agentTask(tasks) {
    const local = tasks.filter((task) => !task.sessionId);
    const running = local.filter((task) => task.status === 'running');
    if (running.length) return newest(running);
    const parents = new Set(local.map((task) => task.parent).filter(Boolean));
    return newest(local.filter((task) => !parents.has(task.statePath)));
}

/**
 * The task to follow next: once the followed task is no longer running, the running task
 * that changed last, wherever it sits in the session. Null while the followed task runs,
 * when it is not in the session, or when no task runs. A task in another session is never
 * followed, so parallel sessions do not move this one.
 *
 * @param {TreeTask[]} tasks
 * @param {string} statePath The followed task's state path.
 * @returns {TreeTask | null}
 */
export function nextFollowTarget(tasks, statePath) {
    const local = tasks.filter((task) => !task.sessionId);
    const self = local.find((task) => task.statePath === statePath);
    if (!self || self.status === 'running') return null;
    return newest(local.filter((task) => task.status === 'running'));
}
