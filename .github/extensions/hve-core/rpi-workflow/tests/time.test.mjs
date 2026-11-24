// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { installFakeDom } from './helpers/fake-dom.mjs';

let restore;
let dom;
before(async () => {
    restore = installFakeDom();
    dom = await import('../ui/dom.mjs');
});
after(() => restore());

const NOW = Date.parse('2026-01-15T12:00:00.000Z');
const ago = (seconds) => new Date(NOW - seconds * 1000).toISOString();
const relative = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });

describe('times', () => {
    it('reads relative times in the reader\'s language', () => {
        assert.equal(dom.relTime(ago(10), NOW), relative.format(0, 'second'));
        assert.equal(dom.relTime(ago(5 * 60), NOW), relative.format(-5, 'minute'));
        assert.equal(dom.relTime(ago(3 * 3600), NOW), relative.format(-3, 'hour'));
        assert.equal(dom.relTime(ago(26 * 3600), NOW), relative.format(-1, 'day'));
        assert.equal(dom.relTime(ago(10 * 86400), NOW), new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' }).format(NOW - 10 * 86400 * 1000));
    });

    it('says when no time was recorded', () => {
        assert.equal(dom.relTime(null, NOW), 'Not recorded');
        assert.equal(dom.relTime('not a time', NOW), 'Not recorded');
        assert.equal(dom.timeEl('not a time', NOW), null);
        assert.equal(dom.fullTime(undefined), null);
    });

    it('titles a time with the full local date, time, and time zone', () => {
        const iso = ago(5 * 60);
        const element = dom.timeEl(iso, NOW);
        assert.equal(element.getAttribute('datetime'), iso);
        assert.equal(element.getAttribute('title'), dom.fullTime(iso));
        const parts = new Intl.DateTimeFormat(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZoneName: 'short' }).formatToParts(Date.parse(iso));
        assert.ok(parts.some((part) => part.type === 'timeZoneName' && dom.fullTime(iso).includes(part.value)), 'the title names the time zone');
    });
});
