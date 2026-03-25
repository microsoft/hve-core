import { buildCollectionDiagram } from '../index';
import type { CollectionCardData } from '../../data/collectionCards';

describe('buildCollectionDiagram', () => {
  const sampleCards: CollectionCardData[] = [
    {
      name: 'ado',
      description: 'Azure DevOps work items',
      artifacts: 21,
      maturity: 'Stable',
      href: '/docs/getting-started/collections',
    },
    {
      name: 'hve-core',
      description: 'RPI workflow',
      artifacts: 40,
      maturity: 'Stable',
      href: '/docs/getting-started/collections',
    },
  ];

  const sampleMeta: Record<string, number> = {
    'hve-core-all': 100,
    installer: 2,
  };

  it('starts with graph TD', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toMatch(/^graph TD/);
  });

  it('includes HCA node with meta count', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toContain('HCA["hve-core-all<br/>(100 artifacts)"]');
  });

  it('includes INS node with meta count', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toContain('INS["installer<br/>(2 artifacts)"]');
  });

  it('creates a node for each card', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toContain('ado["ado"]');
    expect(result).toContain('hve_core["hve-core"]');
  });

  it('creates HCA edges to every card', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toContain('HCA --> ado');
    expect(result).toContain('HCA --> hve_core');
  });

  it('replaces hyphens with underscores in node IDs', () => {
    const cards: CollectionCardData[] = [
      {
        name: 'coding-standards',
        description: 'Coding conventions',
        artifacts: 15,
        maturity: 'Stable',
        href: '/docs/getting-started/collections',
      },
    ];
    const result = buildCollectionDiagram(cards, sampleMeta);
    expect(result).toContain('coding_standards["coding-standards"]');
    expect(result).toContain('HCA --> coding_standards');
  });

  it('handles an empty cards array', () => {
    const result = buildCollectionDiagram([], sampleMeta);
    expect(result).toMatch(/^graph TD/);
    expect(result).toContain('HCA["hve-core-all<br/>(100 artifacts)"]');
    expect(result).toContain('INS["installer<br/>(2 artifacts)"]');
    expect(result).not.toContain('HCA -->');
  });

  it('reflects different meta values', () => {
    const meta = { 'hve-core-all': 999, installer: 5 };
    const result = buildCollectionDiagram([], meta);
    expect(result).toContain('(999 artifacts)');
    expect(result).toContain('(5 artifacts)');
  });

  it('produces one node line and one edge line per card', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    const lines = result.split('\n');
    const nodeLines = lines.filter((l) => /^\s+\w+\["/.test(l));
    const edgeLines = lines.filter((l) => /HCA -->/.test(l));
    // 2 cards + HCA + INS = 4 node lines
    expect(nodeLines).toHaveLength(4);
    expect(edgeLines).toHaveLength(2);
  });
});
