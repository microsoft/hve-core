// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { elements, installFakeDom } from './helpers/fake-dom.mjs';
import { PATHS, rootSession } from './helpers/rpi-fixture.mjs';

let restore;
let components;
let connect;
let makeContext;
before(async () => {
    restore = installFakeDom();
    components = await import('../ui/components.mjs');
    connect = await import('../ui/connect-view.mjs');
    ({ makeContext } = await import('./helpers/render-views.mjs'));
});
after(() => restore());

const NOW = Date.parse('2026-10-27T15:00:00.000Z');
const SHOWN = 'c4d5e6f7-0a1b-4c2d-9e3f-4a5b6c7d8e9f';
const LIVE = 'd5e6f7a8-1b2c-4d3e-8f4a-5b6c7d8e9f0a';
const OWN = '0c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
const STARTED_BLANK = 'f7a8b9c0-1d2e-4f3a-9b4c-5d6e7f8a9b0c';
const OTHER = 'e6f7a8b9-0c1d-4e2f-8a3b-4c5d6e7f8a9b';
const IDLE_UI = { asking: false, askedAt: 0, retryAfterMs: 30000, error: null, helpOpen: false };

const textOf = (node) => node.textContent.replace(/\s+/g, ' ').trim();
const within = (root) => elements(root);
const byLabel = (root, label) => within(root).find((node) => node.getAttribute('aria-label') === label) ?? null;
const byKey = (root, key) => within(root).find((node) => node.getAttribute('data-key') === key) ?? null;
const withClass = (root, name) => within(root).filter((node) => node.classList.contains(name));
const headingsOf = (root, tag) => within(root).filter((node) => node.localName === tag).map(textOf);
const buttonsOf = (root) => within(root).filter((node) => node.localName === 'button');
/** The picker's rows: list items that name a session. */
const rowsOf = (root) => within(root).filter((node) => node.localName === 'li' && node.dataset.session !== undefined);
/** A row's repository and branch line. */
const metaOf = (row) => withClass(row, 'meta').find((node) => !node.classList.contains('copilot-task') && !node.classList.contains('copilot-reason'));

const task = (over = {}) => ({ taskId: 'trail-maps', title: 'Offline trail maps', phase: 'plan', status: 'running', statePath: PATHS.rootState, ...over });
const entry = (over = {}) => ({ sessionId: SHOWN, name: 'Trail maps', repository: 'microsoft/trails', branch: 'main', mine: true, own: false, live: false, task: task(), problem: null, ...over });
const idle = (over = {}) => ({ loading: false, error: null, list: { sessions: [], skipped: 0 }, shown: null, showError: null, note: null, ...over });

/** Handlers that record what the picker's controls asked for. */
function recorder() {
    const calls = { show: [], open: [], refresh: 0 };
    return {
        calls,
        options: (idPrefix = 'menu') => ({
            idPrefix,
            title: 'Copilot sessions',
            headingClass: 'menu-subtitle',
            onShow: (item) => calls.show.push(item.sessionId),
            onOpen: (ref) => calls.open.push(ref),
            onRefresh: () => {
                calls.refresh += 1;
            },
        }),
    };
}

const picker = (model, options) => components.copilotSessionsPicker(model, options);

describe('the picker\'s rows', () => {
    it('lists the sessions this chat started first, then the others, under their own headings', () => {
        const node = picker(idle({ list: { sessions: [entry({ sessionId: SHOWN }), entry({ sessionId: OTHER, mine: false, name: 'Tiles' })], skipped: 0 } }), recorder().options());
        assert.deepEqual(headingsOf(node, 'h4'), ['Sessions this chat started', 'Other sessions with RPI work']);
        assert.deepEqual(rowsOf(node).map((row) => row.dataset.session), [SHOWN, OTHER]);
        const lists = within(node).filter((item) => item.localName === 'ul');
        assert.deepEqual(lists.map((list) => list.getAttribute('aria-labelledby')), ['menu-started', 'menu-others'], 'each list is named by its heading');
    });

    it('names each row by its session, or by the first eight characters of its ID when it has no name', () => {
        const node = picker(idle({ list: { sessions: [entry({ sessionId: SHOWN }), entry({ sessionId: LIVE, name: null, mine: false })], skipped: 0 } }), recorder().options());
        assert.ok(byLabel(node, 'Show here: Trail maps'));
        assert.ok(byLabel(node, 'Open in new panel: Trail maps'));
        assert.ok(byLabel(node, 'Show here: Session d5e6f7a8'));
        assert.ok(byLabel(node, 'Open in new panel: Session d5e6f7a8'));
    });

    it('states the repository and branch, and the task as title, phase, and status in words', () => {
        const node = picker(idle({
            list: {
                sessions: [
                    entry({ sessionId: SHOWN }),
                    entry({ sessionId: LIVE, name: null, repository: null, branch: 'feat/tiles', mine: false, task: task({ title: 'Tile cache', phase: 'implement', status: 'completed' }) }),
                    entry({ sessionId: OTHER, mine: false, task: task({ title: 'Routes', phase: null, status: 'stopped' }) }),
                ],
                skipped: 0,
            },
        }), recorder().options());
        const [shownRow, tilesRow, routesRow] = rowsOf(node);
        assert.equal(textOf(metaOf(shownRow)), 'microsoft/trails · main');
        assert.equal(textOf(metaOf(tilesRow)), 'feat/tiles', 'a line with only a branch names only the branch');
        assert.equal(textOf(metaOf(routesRow)), 'microsoft/trails · main');
        assert.deepEqual(withClass(node, 'copilot-task').map(textOf), ['Offline trail maps · Plan · Running', 'Tile cache · Implement · Completed', 'Routes · Phase not recorded · Stopped']);
    });

    it('says in words whether each canvas runs', () => {
        const node = picker(idle({ list: { sessions: [entry({ sessionId: SHOWN, live: true }), entry({ sessionId: OTHER, mine: false, live: false })], skipped: 0 } }), recorder().options());
        const badges = withClass(node, 'badge').map(textOf);
        assert.ok(badges.includes('Canvas running'));
        assert.ok(badges.includes('No canvas running'));
    });

    it('marks this chat, and marks the shown session without a Show here control, which keeps Open in new panel', () => {
        const node = picker(idle({ shown: SHOWN, list: { sessions: [entry({ sessionId: SHOWN, own: true }), entry({ sessionId: OTHER, name: 'Tiles', mine: false })], skipped: 0 } }), recorder().options());
        const shownRow = rowsOf(node).find((row) => row.dataset.session === SHOWN);
        const badges = withClass(shownRow, 'badge').map(textOf);
        assert.ok(badges.includes('This chat') && badges.includes('Shown'), badges.join(', '));
        assert.equal(byLabel(shownRow, 'Show here: Trail maps'), null, 'the shown session has no Show here');
        assert.ok(byLabel(shownRow, 'Open in new panel: Trail maps'));
        const otherRow = rowsOf(node).find((row) => row.dataset.session === OTHER);
        assert.ok(byLabel(otherRow, 'Show here: Tiles'));
        assert.equal(withClass(otherRow, 'badge').map(textOf).includes('Shown'), false);
    });

    it('gives a session of this chat with no RPI work its reason in words, with no controls', () => {
        const cases = [['no-rpi', 'No RPI work yet'], ['not-found', 'Not on this machine'], ['no-workspace', 'Records no workspace folder'], ['no-tracking', 'Its workspace has no .copilot-tracking folder']];
        const ids = [SHOWN, LIVE, OWN, STARTED_BLANK];
        const sessions = cases.map(([problem], index) => entry({ sessionId: ids[index], name: null, task: null, problem, own: index === 2 }));
        const node = picker(idle({ list: { sessions, skipped: 0 } }), recorder().options());
        const rows = rowsOf(node);
        assert.equal(rows.length, 4);
        cases.forEach(([, words], index) => {
            assert.ok(textOf(rows[index]).includes(words), `${words} in ${textOf(rows[index])}`);
            assert.equal(buttonsOf(rows[index]).length, 0, 'a session with no RPI work has no controls');
        });
        assert.ok(withClass(rows[2], 'badge').map(textOf).includes('This chat'), 'the conversation\'s own session is still marked');
    });

    it('gives Show here and Open in new panel their handlers, which a click or the keyboard activates', () => {
        const { calls, options } = recorder();
        const node = picker(idle({ list: { sessions: [entry({ sessionId: SHOWN })], skipped: 0 } }), options());
        const show = byLabel(node, 'Show here: Trail maps');
        const open = byLabel(node, 'Open in new panel: Trail maps');
        assert.deepEqual([show.localName, show.getAttribute('type')], ['button', 'button'], 'native buttons take Enter and Space');
        assert.notEqual(show.getAttribute('tabindex'), '-1');
        show.listeners.click[0]({});
        open.listeners.click[0]({});
        assert.deepEqual(calls.show, [SHOWN]);
        assert.deepEqual(calls.open, [{ session: SHOWN, title: 'Trail maps' }]);
    });

    it('keys every control of its own, so focus returns to the same control after a re-render', () => {
        const node = picker(idle({ shown: SHOWN, list: { sessions: [entry({ sessionId: SHOWN }), entry({ sessionId: OTHER, mine: false })], skipped: 0 } }), recorder().options('connect'));
        const keys = buttonsOf(node).map((button) => button.getAttribute('data-key'));
        assert.deepEqual(keys, ['connect-sessions-refresh', 'connect-open-' + SHOWN, 'connect-show-' + OTHER, 'connect-open-' + OTHER]);
        assert.equal(new Set(keys).size, keys.length);
    });
});

describe('the picker\'s states', () => {
    it('says it is looking while the list loads, and keeps Refresh busy until the answer comes', () => {
        const { calls, options } = recorder();
        const node = picker(idle({ loading: true, list: null }), options());
        assert.equal(textOf(node).includes('Looking for sessions…'), true);
        const refresh = byKey(node, 'menu-sessions-refresh');
        assert.equal(refresh.getAttribute('aria-disabled'), 'true');
        assert.equal(refresh.hasAttribute('disabled'), false, 'a busy Refresh keeps keyboard focus');
        refresh.listeners.click[0]({});
        assert.equal(calls.refresh, 1);
        assert.equal(byKey(picker(idle(), options()), 'menu-sessions-refresh').getAttribute('aria-disabled'), null);
    });

    it('says there are no sessions with RPI work, in one sentence', () => {
        const node = picker(idle(), recorder().options());
        assert.match(textOf(node), /No sessions with RPI work were found on this machine\./);
        assert.equal(headingsOf(node, 'h4').length, 0);
    });

    it('names a listing failure in words, and keeps Refresh so the person can try again', () => {
        const node = picker(idle({ error: 'The session store is busy.', list: null }), recorder().options());
        const error = withClass(node, 'field-error')[0];
        assert.equal(textOf(error), 'Sessions could not be listed: The session store is busy.');
        assert.ok(byKey(node, 'menu-sessions-refresh'));
    });

    it('says why Show here failed, as an alert, and shows the outcome of Open in new panel at the foot of the group', () => {
        const node = picker(idle({
            showError: 'Could not show that session: No RPI session state was found.',
            note: { tone: 'accent', icon: 'panel', text: 'Opened a canvas for Trail maps in a new panel.' },
            list: { sessions: [entry()], skipped: 0 },
        }), recorder().options());
        const alert = within(node).find((item) => item.getAttribute('role') === 'alert');
        assert.equal(textOf(alert), 'Could not show that session: No RPI session state was found.');
        const note = withClass(node, 'copilot-note')[0];
        assert.ok(note.classList.contains('tone-accent'));
        assert.equal(textOf(note), 'Opened a canvas for Trail maps in a new panel.');
        assert.equal(node.childNodes.at(-1), note, 'the notice is the last part of the group');
    });

    it('is a named group, so assistive technology reads it as one', () => {
        const node = picker(idle(), recorder().options('connect'));
        assert.equal(node.getAttribute('role'), 'group');
        assert.equal(node.getAttribute('aria-labelledby'), 'connect-copilot-title');
        const title = within(node).find((item) => item.getAttribute('id') === 'connect-copilot-title');
        assert.equal(textOf(title), 'Copilot sessions');
        assert.equal(title.localName, 'h3');
    });
});

describe('the picker on the Not connected screen', () => {
    const idleView = { asking: false, askedAt: 0, retryAfterMs: 30000, error: null, helpOpen: false };
    const viewModel = (picker) => ({ reason: 'no-input', detail: null, request: 'RPI canvas 3WF0: connect this canvas.', canAsk: true, handle: '3WF0', editor: null, now: NOW, ui: idleView, picker });
    const viewActs = (calls) => ({
        ask: () => calls.push('ask'),
        copyRequest: () => calls.push('copy-request'),
        copyDetails: () => {},
        showSample: () => {},
        toggleHelp: () => {},
        picker: { onShow: (item) => calls.push(['show', item.sessionId]), onOpen: (ref) => calls.push(['open', ref.session]), onRefresh: () => calls.push('refresh') },
    });

    it('shows Show a session\'s RPI work in its own section, before the Ask the agent step', () => {
        const calls = [];
        const root = connect.notConnectedView(viewModel(idle({ list: { sessions: [entry({ sessionId: SHOWN })], skipped: 0 } })), viewActs(calls));
        assert.deepEqual(headingsOf(root, 'h3'), ["Show a session's RPI work", 'Ask the agent to connect it']);
        const section = within(root).find((item) => item.classList.contains('connect-sessions'));
        assert.ok(section, 'the picker sits in a connect step of its own');
        assert.equal(section.localName, 'div');
        assert.deepEqual(rowsOf(section).map((row) => row.dataset.session), [SHOWN]);
    });

    it('wires the picker\'s controls to the screen\'s actions, and leaves the rest of the screen as it was', () => {
        const calls = [];
        const root = connect.notConnectedView(viewModel(idle({ list: { sessions: [entry({ sessionId: SHOWN })], skipped: 0 } })), viewActs(calls));
        byLabel(root, 'Show here: Trail maps').listeners.click[0]({});
        byLabel(root, 'Open in new panel: Trail maps').listeners.click[0]({});
        byKey(root, 'connect-sessions-refresh').listeners.click[0]({});
        byKey(root, 'connect-ask').listeners.click[0]({});
        assert.deepEqual(calls, [['show', SHOWN], ['open', SHOWN], 'refresh', 'ask']);
        assert.match(textOf(root), /Want to look around first\?/);
    });

    it('shows no picker when the screen has no picker model', () => {
        const root = connect.notConnectedView(viewModel(undefined), viewActs([]));
        assert.deepEqual(headingsOf(root, 'h3'), ['Ask the agent to connect it']);
    });
});

describe('the picker in the session menu', () => {
    /** The menu's content for a real session with loops, as the page builds it; `kind` changes the session's source. */
    function menu({ kind = 'rpi', picker } = {}) {
        const { session } = rootSession();
        session.source = { ...session.source, kind };
        session.followUps.tree = {
            key: '2026-01-15/trail-maps',
            date: '2026-01-15',
            name: 'Offline trail maps',
            tasks: [{ id: 'trail-maps', title: 'Offline trail maps', status: 'completed', depth: 0, statePath: PATHS.rootState, parent: null, shown: true, continues: null }],
        };
        const ctx = makeContext(session, 'followup');
        ctx.act = { showTask: () => {} };
        const root = document.createElement('div');
        for (const node of components.sessionMenuNodes(ctx, { following: true, picker })) root.appendChild(node);
        return root;
    }

    it('shows the picker after the session\'s loops and before the other sessions, with no group of child sessions', () => {
        const root = menu({ picker: { model: idle({ list: { sessions: [entry({ sessionId: SHOWN })], skipped: 0 } }), onShow: () => {}, onOpen: () => {}, onRefresh: () => {} } });
        assert.deepEqual(headingsOf(root, 'h3'), ['Loops in this session', 'Copilot sessions', 'Other sessions']);
        assert.equal(withClass(root, 'child-sessions').length, 0);
        assert.deepEqual(rowsOf(root).map((row) => row.dataset.session), [SHOWN]);
        assert.ok(byLabel(root, 'Show here: Trail maps'));
    });

    it('keeps the menu as it was without a picker model', () => {
        const root = menu();
        assert.deepEqual(headingsOf(root, 'h3'), ['Loops in this session', 'Other sessions']);
    });

    it('offers the picker for the sample too, which has no other sessions to list', () => {
        const root = menu({ kind: 'sample', picker: { model: idle(), onShow: () => {}, onOpen: () => {}, onRefresh: () => {} } });
        assert.deepEqual(headingsOf(root, 'h3'), ['Loops in this session', 'Copilot sessions']);
        assert.match(textOf(root), /The sample has no other loops to show\./);
    });
});
