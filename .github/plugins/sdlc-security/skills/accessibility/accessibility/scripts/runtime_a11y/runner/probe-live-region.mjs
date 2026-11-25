// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { liveRegionStatus } from './_core.mjs';
import { buildProbeResults, emitProbeResult, readLiveRegionSnapshot, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    // The shared runner installs a live-region observer before navigation and
    // clears its log immediately before the state trigger, so any recorded
    // update is a genuine trigger-driven announcement. readLiveRegionSnapshot
    // settles debounced announcers before reading.
    const snapshot = await readLiveRegionSnapshot(page);

    // Method adequacy for WCAG 4.1.3: an announcement is decided only when a
    // live region fires an update in a state that should produce a status
    // message (pass). A region that exists but never fires only informs
    // (partial); an absent region in an expecting state fails.
    const results = await buildProbeResults({
      probeId: 'probe-live-region',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: liveRegionStatus(snapshot, state),
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-live-region',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
