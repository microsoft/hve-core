// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Fixture cases for the probe-live-region smoke tests. Each case is
// framework-agnostic HTML paired with the interaction state and the expected
// WCAG 4.1.3 (Status Messages) verdict. Cases guard the shipped defect where a
// status region existed but never announced, and the wrong-surface silence.
export const CASES = [
  {
    name: 'status region that fires an update passes (WCAG 4.1.3)',
    state: 'open',
    fire: true,
    html: `<!doctype html><html lang="en"><body><main>
      <div role="status"></div>
      <script>window.__fire=function(){document.querySelector('[role=status]').textContent='5 documents found';};</script>
    </main></body></html>`,
    expected: { status: 'pass' },
  },
  {
    name: 'present-but-silent region is partial (WCAG 4.1.3)',
    state: 'open',
    fire: false,
    html: `<!doctype html><html lang="en"><body><main>
      <div role="status"></div>
    </main></body></html>`,
    expected: { status: 'partial' },
  },
  {
    name: 'absent region in an expecting state fails (WCAG 4.1.3)',
    state: 'open',
    fire: false,
    html: `<!doctype html><html lang="en"><body><main><p>No live region here.</p></main></body></html>`,
    expected: { status: 'fail' },
  },
  {
    name: 'no region required in a non-expecting state (WCAG 4.1.3)',
    state: 'default',
    fire: false,
    html: `<!doctype html><html lang="en"><body><main><p>Static content.</p></main></body></html>`,
    expected: { status: 'pass' },
  },
];
