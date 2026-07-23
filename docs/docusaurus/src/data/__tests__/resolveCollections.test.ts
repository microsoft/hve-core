// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import {
  collectionCardDefinitions,
  resolveCollectionCards,
  resolveMetaCollections,
} from '../collectionCards';

describe('resolveCollectionCards', () => {
  it('maps declared counts onto the matching collection', () => {
    const first = collectionCardDefinitions[0];
    const cards = resolveCollectionCards({ [first.name]: 7 });
    expect(cards.find((card) => card.name === first.name)?.artifacts).toBe(7);
  });

  it('falls back to 0 artifacts when a count is missing', () => {
    const cards = resolveCollectionCards({});
    expect(cards.length).toBe(collectionCardDefinitions.length);
    expect(cards.every((card) => card.artifacts === 0)).toBe(true);
  });
});

describe('resolveMetaCollections', () => {
  it('reads the hve-core-all count when present', () => {
    expect(resolveMetaCollections({ 'hve-core-all': 42 })).toEqual({ 'hve-core-all': 42 });
  });

  it('falls back to 0 when the hve-core-all count is missing', () => {
    expect(resolveMetaCollections({})).toEqual({ 'hve-core-all': 0 });
  });
});
