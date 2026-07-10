import { buildProbeResults, emitProbeResult, runProbeWithPage, snapshotAccessibilityTree } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const accessibilityTree = await snapshotAccessibilityTree(page);
    const snapshot = await page.evaluate(() => ({
      roles: document.querySelectorAll('[role]').length,
      labels: document.querySelectorAll('[aria-label], [aria-labelledby], label').length,
      accessibleNameCount: document.querySelectorAll('[aria-label], [aria-labelledby], [name]').length,
    }));

    const treeIssues = [];
    const visit = (node) => {
      if (!node) {
        return;
      }
      if ((node.role || '').trim() && !node.name) {
        treeIssues.push(node.role);
      }
      if (Array.isArray(node.children)) {
        node.children.forEach(visit);
      }
    };
    visit(accessibilityTree);

    const hasDefect = snapshot.roles > 0 && treeIssues.length > 0;
    const evidencePayload = {
      snapshot,
      treeIssueCount: treeIssues.length,
      // Capped to avoid bloating evidence payloads on complex pages.
      accessibilityTreeSample: JSON.stringify(accessibilityTree).slice(0, 2000),
    };

    const results = await buildProbeResults({
      probeId: 'probe-aria-tree',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(evidencePayload)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-aria-tree',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
