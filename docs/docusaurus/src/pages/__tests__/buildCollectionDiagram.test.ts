import { buildCollectionDiagram } from '../index';
import type { CollectionCardData, MetaCollections } from '../../data/collectionCards';

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

  const sampleMeta: MetaCollections = {
    'hve-core-all': 100,
  };

  it('starts with graph TD', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toMatch(/^graph TD/);
  });

  it('includes HCA node with meta count', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    expect(result).toContain('HCA["hve-core-all<br/>(100 artifacts)"]');
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
    expect(result).not.toContain('HCA -->');
  });

  it('reflects different meta values', () => {
    const meta: MetaCollections = { 'hve-core-all': 999 };
    const result = buildCollectionDiagram([], meta);
    expect(result).toContain('(999 artifacts)');
  });

  it('produces one node line and one edge line per card', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    const lines = result.split('\n');
    const nodeLines = lines.filter((l) => /^\s+\w+\["/.test(l));
    const edgeLines = lines.filter((l) => /HCA -->/.test(l));
    // 2 cards + HCA = 3 node lines
    expect(nodeLines).toHaveLength(3);
    expect(edgeLines).toHaveLength(2);
  });

  describe('Mermaid syntax validation', () => {
    const result = buildCollectionDiagram(sampleCards, sampleMeta);
    const lines = result.split('\n');

    it('all node IDs referenced in edges are declared', () => {
      const nodeIds = new Set<string>();
      for (const line of lines) {
        const match = line.match(/^\s+(\w+)\["/);
        if (match) nodeIds.add(match[1]);
      }
      for (const line of lines) {
        const match = line.match(/^\s+(\w+)\s+-->\s+(\w+)/);
        if (match) {
          expect(nodeIds).toContain(match[1]);
          expect(nodeIds).toContain(match[2]);
        }
      }
    });

    it('node declarations match ID["label"] pattern', () => {
      const nodeLines = lines.filter((l) => /^\s+\w+\["/.test(l));
      for (const line of nodeLines) {
        expect(line).toMatch(/^\s+\w+\["[^"]+"\]$/);
      }
    });

    it('edge declarations match ID --> ID pattern', () => {
      const edgeLines = lines.filter((l) => /-->/.test(l));
      for (const line of edgeLines) {
        expect(line).toMatch(/^\s+\w+\s+-->\s+\w+$/);
      }
    });

    it('has no duplicate node declarations', () => {
      const nodeIds: string[] = [];
      for (const line of lines) {
        const match = line.match(/^\s+(\w+)\["/);
        if (match) nodeIds.push(match[1]);
      }
      expect(new Set(nodeIds).size).toBe(nodeIds.length);
    });
  });
});
