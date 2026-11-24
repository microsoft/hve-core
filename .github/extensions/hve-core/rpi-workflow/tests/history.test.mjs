// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createHistory, MAX_PLACES, placeLabel } from '../ui/history.mjs';

const at = (phase, id = null, taskId = 'loop-3', taskTitle = 'Canvas navigation') => ({ taskId, taskTitle, phase, id, scroll: 0 });
const LABELS = { research: 'Research', plan: 'Plan', implement: 'Implement' };
const label = (phase) => LABELS[phase];

describe('one history across phases and tasks', () => {
    it('replays your example: from F1, click Q1 and C6, and Back twice returns to F1', () => {
        const history = createHistory();
        history.move(at('research', 'F1'), at('research', 'Q1'));
        history.move(at('research', 'Q1'), at('research', 'C6'));
        assert.equal(history.back(at('research', 'C6')).id, 'Q1');
        assert.equal(history.back(at('research', 'Q1')).id, 'F1');
        assert.equal(history.back(at('research', 'F1')), null);
        assert.equal(history.forward(at('research', 'F1')).id, 'Q1');
        assert.equal(history.forward(at('research', 'Q1')).id, 'C6');
        assert.equal(history.forward(at('research', 'C6')), null);
    });

    it('goes back from Plan to where you left Research, then through your Research clicks', () => {
        const history = createHistory();
        history.move(at('research', 'F1'), at('research', 'C6'));
        history.move(at('research', 'C6'), at('plan'));
        history.move(at('plan'), at('plan', 'P01-T02'));
        const steps = [];
        let here = at('plan', 'P01-T02');
        for (let place = history.back(here); place; place = history.back(here)) {
            steps.push(`${place.phase}:${place.id ?? 'top'}`);
            here = place;
        }
        assert.deepEqual(steps, ['plan:top', 'research:C6', 'research:F1']);
    });

    it('clears Forward on a new move, ignores a move to the same place, and keeps 50 places', () => {
        const history = createHistory();
        history.move(at('research', 'F1'), at('research', 'Q1'));
        history.back(at('research', 'Q1'));
        assert.equal(history.sizes.forward, 1);
        history.move(at('research', 'F1'), at('research', 'F1'));
        assert.equal(history.sizes.forward, 1, 'staying put keeps Forward');
        history.move(at('research', 'F1'), at('research', 'W2'));
        assert.equal(history.sizes.forward, 0);
        for (let index = 0; index < MAX_PLACES + 20; index += 1) history.move(at('research', `C${index}`), at('research', `C${index + 1}`));
        assert.equal(history.sizes.back, MAX_PLACES);
    });

    it('records the same place once in a row and drops a place that is gone', () => {
        const history = createHistory();
        history.move(at('research', 'F1'), at('research', 'Q1'));
        history.move(at('research', 'F1'), at('research', 'Q2'));
        assert.equal(history.sizes.back, 1);
        history.move(at('plan', null, 'loop-2', 'Artifact conformance'), at('research', 'F1'));
        history.drop(at('plan', null, 'loop-2'));
        assert.equal(history.peek().back.id, 'F1');
    });

    it('names where each button leads, with the task when it is another one', () => {
        assert.equal(placeLabel('back', at('research', 'F1'), 'loop-3', label), 'Back to F1 in Research');
        assert.equal(placeLabel('forward', at('plan'), 'loop-3', label), 'Forward to Plan');
        assert.equal(placeLabel('back', at('implement', 'CH-002', 'loop-2', 'Artifact conformance'), 'loop-3', label), 'Back to CH-002 in Implement of Artifact conformance');
        assert.equal(placeLabel('back', { ...at('implement', 'CH-002'), doc: 1, docLabel: 'An early look' }, 'loop-3', label), 'Back to CH-002 in Implement (An early look)');
    });

    it('keeps the same ID in an earlier document and in the current one as two places', () => {
        const history = createHistory();
        const earlier = { ...at('implement', 'CH-001'), doc: 1, docLabel: 'An early look' };
        history.move(earlier, at('implement', 'CH-001'));
        assert.equal(history.sizes.back, 1, 'moving from the earlier record to the current one is a move');
        assert.equal(history.back(at('implement', 'CH-001')).doc, 1, 'Back returns to the earlier record');
    });
});
