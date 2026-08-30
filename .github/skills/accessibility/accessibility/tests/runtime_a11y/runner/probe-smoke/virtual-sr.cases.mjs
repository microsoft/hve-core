// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Fixture cases for the probe-virtual-sr smoke tests. Each case is
// framework-agnostic HTML paired with the expected WCAG 4.1.2 (Name, Role,
// Value) verdict. The negative case guards the shipped nameless-control defect
// (a clear/close control announced by role with no accessible name).
export const CASES = [
  {
    name: 'nameless icon controls fail (WCAG 4.1.2)',
    html: `<!doctype html><html lang="en"><body><main>
      <button type="button"><svg aria-hidden="true" width="16" height="16"></svg></button>
      <a href="/x"><svg aria-hidden="true" width="16" height="16"></svg></a>
    </main></body></html>`,
    expected: { status: 'fail', namelessCount: 2 },
  },
  {
    name: 'labelled controls pass (WCAG 4.1.2)',
    html: `<!doctype html><html lang="en"><body><main>
      <button type="button" aria-label="Clear search">x</button>
      <a href="/x">Docs</a>
    </main></body></html>`,
    expected: { status: 'pass', namelessCount: 0 },
  },
];
