// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3001/hve-core/';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // The suite drives a single `docusaurus serve` instance, which resets
  // connections (net::ERR_ABORTED) under concurrent workers. Serialize on a
  // single worker everywhere for deterministic runs, and keep retries to
  // absorb transient navigation resets (more in CI).
  retries: process.env.CI ? 2 : 1,
  workers: 1,
  reporter: process.env.CI
    ? [['github'], ['list'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    },
  ],
  webServer: {
    command: 'npm run build && npm run serve:ci',
    url: baseURL,
    // Playwright owns its server lifecycle: it builds and serves its own
    // instance for the run. Locally, `reuseExistingServer: true` reuses an
    // already running dev/serve process instead of failing on a port conflict.
    reuseExistingServer: true,
    timeout: 180000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
