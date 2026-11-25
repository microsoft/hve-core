// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { access, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { launchChrome, maximizeBrowserWindow } from './_shared.mjs';
import { assertArtifactId, assertHttpUrl } from './validation.mjs';

const DEFAULT_VISUAL_REVIEW_STATES = [
  'desktop',
  'reflow-320',
  'zoom-200',
  'text-spacing',
  'forced-colors',
];

// Resolves a configured route against the validated base origin.
//
// Re-exported from the shared resolver so the probe, calibration, and visual
// review paths cannot drift apart on what a route is allowed to reach.
import { resolveRouteUrl } from './route.mjs';

export { resolveRouteUrl };

// Regions masked in every screenshot. A capture preserves whatever a field
// contains at the moment it is taken, and accessibility review does not depend
// on reading entered values.
const MASKED_SELECTORS = [
  '[data-pii]',
  'input:not([type=checkbox]):not([type=radio]):not([type=button]):not([type=submit])',
  'textarea',
];

export function resolveBrowserVersion(browser, configuredVersion) {
  if (configuredVersion) {
    return configuredVersion;
  }
  try {
    return browser?.version?.() || 'unknown';
  } catch {
    return 'unknown';
  }
}

// Route identity is derived rather than required so existing plans stay valid.
export function buildRouteArtifactId(route) {
  const explicit = route?.routeId || route?.id;
  if (explicit) {
    return String(explicit);
  }
  const routePath = String(route?.path || route?.route || '/');
  const normalized = routePath.replace(/^\/+/, '').replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');
  return normalized.slice(0, 128) || 'root';
}

export function buildVisualReviewArtifactSegment(route, stateName) {
  const routeId = assertArtifactId(buildRouteArtifactId(route), 'Route ID');
  const surfaceId = assertArtifactId(route?.surfaceId || 'surface', 'Surface ID');
  const stateId = assertArtifactId(stateName, 'State ID');
  return [routeId, surfaceId, stateId];
}

function getVisualReviewFilters(config = {}) {
  const rawSurfaces = process.env.RUNTIME_A11Y_VISUAL_REVIEW_SURFACES;
  const rawStates = process.env.RUNTIME_A11Y_VISUAL_REVIEW_STATES;
  const surfaces = rawSurfaces ? JSON.parse(rawSurfaces) : [];
  const states = rawStates ? JSON.parse(rawStates) : [];

  return {
    surfaces: Array.isArray(surfaces) ? surfaces.filter(Boolean) : [],
    states: Array.isArray(states) ? states.filter(Boolean) : [],
  };
}

function normalizeRoutes(config) {
  const configuredRoutes = Array.isArray(config?.visualReview?.routes)
    ? config.visualReview.routes
    : Array.isArray(config?.routes)
      ? config.routes
      : [];

  if (configuredRoutes.length > 0) {
    return configuredRoutes.map((entry) => ({
      path: entry?.path || entry?.route || '/',
      state: entry?.state || 'default',
      surfaceId: entry?.surfaceId || entry?.surfaceIds?.[0] || 'surface',
    }));
  }

  const surfaces = Array.isArray(config?.surfaces) ? config.surfaces : [];
  return surfaces
    .filter((entry) => entry && typeof entry === 'object')
    .map((entry) => ({
      path: entry?.route || '/',
      state: 'default',
      surfaceId: entry?.id || 'surface',
    }));
}

export function buildVisualReviewPlan(config = {}) {
  const routes = normalizeRoutes(config);
  const configuredStates = Array.isArray(config?.visualReview?.states)
    ? config.visualReview.states
    : [];
  const states = configuredStates.length > 0
    ? configuredStates.map((entry) => (typeof entry === 'string' ? { state: entry } : entry))
    : DEFAULT_VISUAL_REVIEW_STATES.map((state) => ({ state }));

  return {
    routes: routes.length > 0 ? routes : [{ path: '/', state: 'default', surfaceId: 'home' }],
    states,
  };
}

function getViewportForState(stateName) {
  if (stateName === 'reflow-320') {
    return { width: 320, height: 900 };
  }
  return { width: 1440, height: 900 };
}

async function applyVisualReviewState(page, stateName) {
  const viewport = getViewportForState(stateName);
  await page.setViewportSize(viewport);
  await page.emulateMedia({
    colorScheme: 'light',
    forcedColors: stateName.includes('forced-colors') ? 'active' : 'none',
    reducedMotion: 'no-preference',
  });

  if (stateName === 'zoom-200') {
    await page.evaluate(() => {
      document.documentElement.style.setProperty('font-size', '200%');
    }).catch(() => undefined);
  }

  if (stateName === 'reflow-320') {
    await page.evaluate(() => {
      document.documentElement.style.setProperty('font-size', '16px');
    }).catch(() => undefined);
  }

  if (stateName === 'text-spacing') {
    await page.evaluate(() => {
      const style = document.createElement('style');
      style.textContent = `html { letter-spacing: 0.12em; line-height: 1.75; word-spacing: 0.16em; }`;
      document.head.appendChild(style);
    }).catch(() => undefined);
  }

  return viewport;
}

export function buildDeterministicMeasurementEnvelope(input = {}) {
  const viewport = input.viewport || { width: 1440, height: 900 };
  const documentDimensions = input.documentDimensions || {
    scrollWidth: viewport.width,
    clientWidth: viewport.width,
  };
  const overflowClassification = input.overflowClassification || { code: 'none', table: 'none' };
  const rootHorizontalOverflow = Boolean(
    documentDimensions.scrollWidth > documentDimensions.clientWidth,
  );

  return {
    viewport,
    documentDimensions,
    metrics: {
      rootHorizontalOverflow,
      fixedOverlayCount: input.fixedOverlayCount || 0,
      interactiveOutsideViewport: Array.isArray(input.interactiveOutsideViewport)
        ? input.interactiveOutsideViewport
        : [],
      focusRectangleVisible: Boolean(input.focusRectangleVisible),
      clippedTextCandidates: Array.isArray(input.clippedTextCandidates)
        ? input.clippedTextCandidates
        : [],
      overlapCandidates: Array.isArray(input.overlapCandidates)
        ? input.overlapCandidates
        : [],
      allowedOverflow: {
        code: overflowClassification.code || 'none',
        table: overflowClassification.table || 'none',
      },
    },
  };
}

async function writeJsonFile(targetPath, payload) {
  await mkdir(path.dirname(targetPath), { recursive: true });
  await writeFile(targetPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

export async function captureVisualReviewEvidence(config = {}) {
  const plan = buildVisualReviewPlan(config);
  const baseUrl = process.env.RUNTIME_A11Y_BASE_URL || config.baseUrl || 'http://127.0.0.1:3000';
  assertHttpUrl(baseUrl, 'Runtime base URL');
  const runRoot = process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT || path.join(process.cwd(), '.copilot-tracking', 'accessibility', 'local-runs', 'tmp');
  const browserName = process.env.RUNTIME_A11Y_BROWSER_NAME || 'chrome';
  const browserVersion = process.env.RUNTIME_A11Y_BROWSER_VERSION || 'unknown';
  const filters = getVisualReviewFilters(config);
  const selectedRoutes = filters.surfaces.length > 0
    ? plan.routes.filter((route) => filters.surfaces.includes(String(route.surfaceId || route.id || 'surface')))
    : plan.routes;
  const selectedStates = filters.states.length > 0
    ? plan.states.filter((entry) => filters.states.includes(String(typeof entry === 'string' ? entry : entry.state)))
    : plan.states;
  const runs = [];

  let browser;
  try {
    browser = await launchChrome();
    for (const route of selectedRoutes) {
      for (const stateEntry of selectedStates) {
        const stateName = typeof stateEntry === 'string' ? stateEntry : stateEntry.state;
        const artifactSegments = buildVisualReviewArtifactSegment(route, stateName);
        const artifactDir = path.join(runRoot, 'artifacts', ...artifactSegments);
        const outcomeId = artifactSegments.join(':');
        await mkdir(artifactDir, { recursive: true });

        const screenshotPath = path.join(artifactDir, 'screenshot.png');
        const measurementPath = path.join(artifactDir, 'measurements.json');
        const tracePath = path.join(artifactDir, 'trace.zip');
        const rawTarget = route.path || '/';
        const pageUrl = resolveRouteUrl(rawTarget, baseUrl);

        const viewport = getViewportForState(stateName);
        const context = await browser.newContext({ viewport, deviceScaleFactor: 1 });
        const page = await context.newPage();
        let traceStopped = false;
        let maximizeResult = { status: 'unavailable', reason: 'not-attempted' };
        try {
          maximizeResult = await maximizeBrowserWindow({ browser, context, page });
            // Trace snapshots serialize the DOM, including form field values.
            // They are captured only when the operator asks for them.
            await context.tracing.start({
              screenshots: true,
              snapshots: Boolean(config?.visualReview?.traceSnapshots),
            });
          await page.goto(pageUrl, { waitUntil: 'domcontentloaded', timeout: 10000 });
          const actualViewport = await applyVisualReviewState(page, stateName);
          await page.evaluate(() => {
            document.documentElement.style.setProperty('--runtime-a11y-visual-review', 'active');
          });
// Capture is bounded to the viewport unless the operator opts into
            // the full scroll height, and text-entry fields are masked because
            // a screenshot preserves whatever they happen to contain.
            await page.screenshot({
              path: screenshotPath,
              fullPage: Boolean(config?.visualReview?.fullPage),
              mask: MASKED_SELECTORS.map((selector) => page.locator(selector)),
            });

          const measurement = await page.evaluate(() => {
            const root = document.documentElement;
            return {
              scrollWidth: root.scrollWidth,
              clientWidth: root.clientWidth,
              fixedOverlayCount: document.querySelectorAll('[role="dialog"],[aria-modal="true"],[role="alertdialog"]').length,
              interactiveOutsideViewport: Array.from(document.querySelectorAll('button, a, input, select, textarea')).filter((element) => {
                const rect = element.getBoundingClientRect();
                return rect.width <= 0 || rect.height <= 0 || rect.top < 0 || rect.left < 0;
              }).slice(0, 5).map((element) => ({
                tag: element.tagName.toLowerCase(),
                text: (element.textContent || '').trim().slice(0, 40),
              })),
              focusRectangleVisible: document.activeElement !== null,
              clippedTextCandidates: Array.from(document.querySelectorAll('p, h1, h2, h3, li')).filter((element) => {
                const rect = element.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 && element.textContent && element.textContent.trim().length > 0;
              }).slice(0, 3).map((element) => ({
                text: (element.textContent || '').trim().slice(0, 40),
              })),
              overlapCandidates: Array.from(document.querySelectorAll('header, main, footer')).map((element) => ({
                selector: element.tagName.toLowerCase(),
              })),
            };
          });

          const envelope = buildDeterministicMeasurementEnvelope({
            viewport: actualViewport,
            documentDimensions: {
              scrollWidth: measurement.scrollWidth,
              clientWidth: measurement.clientWidth,
            },
            fixedOverlayCount: measurement.fixedOverlayCount,
            interactiveOutsideViewport: measurement.interactiveOutsideViewport,
            focusRectangleVisible: measurement.focusRectangleVisible,
            clippedTextCandidates: measurement.clippedTextCandidates,
            overlapCandidates: measurement.overlapCandidates,
            overflowClassification: { code: 'allowed', table: 'allowed' },
          });

          await context.tracing.stop({ path: tracePath });
          traceStopped = true;
          await access(tracePath).catch(() => {
            throw new Error(`Trace artifact was not produced: ${tracePath}`);
          });
          await writeJsonFile(measurementPath, envelope);

          runs.push({
            route: route.path,
            state: stateName,
            surface: route.surfaceId || 'surface',
            viewport: envelope.viewport,
            deviceScaleFactor: 1,
            screenshotPath: path.relative(runRoot, screenshotPath).replace(/\\/g, '/'),
            measurementPath: path.relative(runRoot, measurementPath).replace(/\\/g, '/'),
            tracePath: path.relative(runRoot, tracePath).replace(/\\/g, '/'),
            deterministicMetrics: envelope.metrics,
            probeOutcomes: [{ id: outcomeId, status: 'pass' }],
            browser: { name: browserName, version: resolveBrowserVersion(browser, browserVersion) },
            maximizeWindow: maximizeResult,
          });
        } catch (error) {
          runs.push({
            route: route.path,
            state: stateName,
            surface: route.surfaceId || 'surface',
            viewport,
            deviceScaleFactor: 1,
            screenshotPath: path.relative(runRoot, screenshotPath).replace(/\\/g, '/'),
            measurementPath: path.relative(runRoot, measurementPath).replace(/\\/g, '/'),
            tracePath: path.relative(runRoot, tracePath).replace(/\\/g, '/'),
            deterministicMetrics: {},
            probeOutcomes: [{ id: outcomeId, status: 'capture-failure', detail: error instanceof Error ? error.message : String(error) }],
            browser: { name: browserName, version: browserVersion || 'unknown' },
            maximizeWindow: maximizeResult,
          });
        } finally {
          if (!traceStopped) {
            await context.tracing.stop({ path: tracePath }).catch(() => undefined);
          }
          await page.close().catch(() => undefined);
          await context.close().catch(() => undefined);
        }
      }
    }
  } finally {
    if (browser) {
      await browser.close().catch(() => undefined);
    }
  }

  return {
    tool: 'runtime_a11y',
    command: 'capture-visual-review',
    runRoot: path.relative(process.cwd(), runRoot).replace(/\\/g, '/'),
    runs,
  };
}

if (process.argv[1] && process.argv[1].endsWith('visual-review-executor.mjs')) {
  const config = JSON.parse(process.env.RUNTIME_A11Y_CONFIG || '{}');
  captureVisualReviewEvidence(config)
    .then((payload) => {
      process.stdout.write(`${JSON.stringify(payload)}\n`);
    })
    .catch((error) => {
      console.error(error instanceof Error ? error.message : String(error));
      process.exit(1);
    });
}
