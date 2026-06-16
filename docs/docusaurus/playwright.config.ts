import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3001/hve-core/';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
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
    // In CI the pa11y-ci step leaves a `serve:ci` server running on this URL
    // (a backgrounded process that outlives its step), so reuse it to avoid a
    // port conflict and a redundant rebuild. When no server is already
    // listening -- locally, or if the pa11y server is absent -- Playwright
    // starts its own.
    reuseExistingServer: true,
    timeout: 180000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
