// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { iconCards, boxCards } from '../hubCards';

describe('hubCards data', () => {
  it('exposes non-empty icon cards, each with the required fields', () => {
    expect(iconCards.length).toBeGreaterThan(0);
    for (const card of iconCards) {
      expect(card.supertitle).toBeTruthy();
      expect(card.title).toBeTruthy();
      expect(card.href).toBeTruthy();
      expect(card.description).toBeTruthy();
      expect(card.icon).toBeTruthy();
    }
  });

  it('exposes unique icon-card hrefs', () => {
    const hrefs = iconCards.map((card) => card.href);
    expect(new Set(hrefs).size).toBe(hrefs.length);
  });

  it('exposes non-empty box cards, each with at least one link', () => {
    expect(boxCards.length).toBeGreaterThan(0);
    for (const card of boxCards) {
      expect(card.title).toBeTruthy();
      expect(card.description).toBeTruthy();
      expect(Array.isArray(card.links)).toBe(true);
      expect(card.links.length).toBeGreaterThan(0);
      for (const link of card.links) {
        expect(link.label).toBeTruthy();
        expect(link.href).toBeTruthy();
      }
    }
  });
});
