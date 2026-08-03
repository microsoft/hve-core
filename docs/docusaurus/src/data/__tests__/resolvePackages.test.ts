// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import {
  packageCardDefinitions,
  resolvePackageCards,
} from '../packageCards';

describe('packageCardDefinitions', () => {
  it('declares hve-core as the only package identity', () => {
    expect(packageCardDefinitions.map((definition) => definition.name)).toEqual([
      'hve-core',
    ]);
  });
});

describe('resolvePackageCards', () => {
  it('maps a declared count onto the matching package', () => {
    const first = packageCardDefinitions[0];

    const cards = resolvePackageCards({ [first.name]: 7 });

    expect(cards.find((card) => card.name === first.name)?.artifacts).toBe(7);
  });

  it('falls back to 0 artifacts when a count is missing', () => {
    const cards = resolvePackageCards({});

    expect(cards).toHaveLength(packageCardDefinitions.length);
    expect(cards.every((card) => card.artifacts === 0)).toBe(true);
  });

  it('preserves the declaration order and the declared card fields', () => {
    const cards = resolvePackageCards({});

    expect(cards.map((card) => card.name)).toEqual(
      packageCardDefinitions.map((definition) => definition.name),
    );
    cards.forEach((card, index) => {
      const definition = packageCardDefinitions[index];
      expect(card.title).toBe(definition.title);
      expect(card.description).toBe(definition.description);
      expect(card.maturity).toBe(definition.maturity);
      expect(card.href).toBe(definition.href);
    });
  });

  it('ignores counts for retired identities that declare no card', () => {
    const cards = resolvePackageCards({ 'hve-core-all': 99, ado: 12 });

    expect(cards.map((card) => card.name)).toEqual(['hve-core']);
  });
});
