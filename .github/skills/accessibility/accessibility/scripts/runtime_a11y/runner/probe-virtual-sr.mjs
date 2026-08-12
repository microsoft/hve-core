// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { virtualSrNameRoleStatus } from './_core.mjs';
import { buildProbeResults, captureVirtualSr, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    // The virtual screen reader decides name/role announcement at the
    // accname/AAM spec layer. A control announced by role with no accessible
    // name is a genuine WCAG 4.1.2 defect (fail). When the simulator cannot run,
    // the verdict is candidate rather than a false pass. Real-screen-reader
    // confirmation (Guidepup NVDA) is the higher-fidelity tier.
    const snapshot = await captureVirtualSr(page);

    const results = await buildProbeResults({
      probeId: 'probe-virtual-sr',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: virtualSrNameRoleStatus(snapshot),
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-virtual-sr',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
