import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

import {
  buildProbeResults,
  emitProbeResult,
  loadProbeCriteriaMap,
  redactUrl,
} from './_core.mjs';

const DEFAULT_VIEWPORT = { width: 1280, height: 900 };

function getRuntimeConfig() {
  const raw = process.env.RUNTIME_A11Y_CONFIG || '{}';
  return JSON.parse(raw);
}

function getRuntimeContext() {
  const config = getRuntimeConfig();
  return {
    config,
    probeId: process.env.RUNTIME_A11Y_PROBE_ID || 'probe-unknown',
    surfaceId: process.env.RUNTIME_A11Y_SURFACE_ID || '',
    state: process.env.RUNTIME_A11Y_STATE || 'default',
    baseUrl: process.env.RUNTIME_A11Y_BASE_URL || config.baseUrl || 'http://127.0.0.1:3000',
    trace: process.env.RUNTIME_A11Y_TRACE === '1',
  };
}

function resolveTargetUrl(baseUrl, surface) {
  const route = surface?.route || '';
  if (!route) {
    return baseUrl;
  }

  try {
    return new URL(route, baseUrl).toString();
  } catch {
    const normalized = route.startsWith('/') ? route : `/${route}`;
    return `${baseUrl.replace(/\/$/, '')}${normalized}`;
  }
}

function resolveLocator(page, target) {
  if (typeof target === 'string') {
    return page.locator(target);
  }

  if (target && typeof target === 'object') {
    if (target.kind === 'role') {
      return page.getByRole(target.role || 'button', { name: target.name || undefined });
    }
    if (target.value) {
      return page.locator(target.value);
    }
  }

  return page.locator('body');
}

async function applyTrigger(page, trigger) {
  if (!trigger) {
    return;
  }

  const action = trigger.action || 'visit';
  const target = trigger.target;
  const locator = resolveLocator(page, target);

  switch (action) {
    case 'click':
      await locator.click({ timeout: 1000 }).catch(() => undefined);
      break;
    case 'focus':
      await locator.focus({ timeout: 1000 }).catch(() => undefined);
      break;
    case 'hover':
      await locator.hover({ timeout: 1000 }).catch(() => undefined);
      break;
    case 'type':
      await locator.fill(trigger.value || '', { timeout: 1000 }).catch(() => undefined);
      break;
    case 'press':
      await page.keyboard.press(trigger.value || 'Enter').catch(() => undefined);
      break;
    case 'navigate':
      await page.goto(trigger.value || '/', { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      break;
    case 'visit':
      if (typeof target === 'string' || target?.value) {
        await page.goto(target.value || target || '/', { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      }
      break;
    default:
      break;
  }

  if (trigger.waitFor) {
    const waitFor = resolveLocator(page, trigger.waitFor);
    await waitFor.waitFor({ state: 'visible', timeout: 1000 }).catch(() => undefined);
  }
}

async function applyStateEmulation(page, state) {
  const viewport = state === 'mobile'
    ? { width: 390, height: 844 }
    : state === 'reflow-320'
      ? { width: 320, height: 900 }
      : state === 'zoom-400'
        ? { width: 1280, height: 900 }
        : DEFAULT_VIEWPORT;

  await page.setViewportSize(viewport);
  await page.emulateMedia({
    colorScheme: state.includes('dark') ? 'dark' : 'light',
    forcedColors: state.includes('forced-colors') ? 'active' : 'none',
    reducedMotion: state.includes('reduced-motion') ? 'reduce' : 'no-preference',
  });

  if (state.includes('zoom-400')) {
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '200%';
    }).catch(() => undefined);
  }

  if (state.includes('reflow-320')) {
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '16px';
    }).catch(() => undefined);
  }
}

async function gatherTracingAssets(page, context, tracePath) {
  if (!tracePath) {
    return null;
  }

  await page.screenshot({ path: tracePath.replace(/\.zip$/, '.png'), fullPage: true }).catch(() => undefined);
  await context.tracing.stop({ path: tracePath }).catch(() => undefined);
  return tracePath;
}

export async function injectAxe(page) {
  try {
    const mod = await import('@axe-core/playwright');
    const AxeBuilder = mod.default || mod.AxeBuilder;
    if (!AxeBuilder) {
      return null;
    }
    const builder = new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']);
    return await builder.analyze();
  } catch {
    return null;
  }
}

export async function snapshotAccessibilityTree(page) {
  try {
    return await page.accessibility.snapshot();
  } catch {
    return null;
  }
}

export async function runProbeWithPage(callback) {
  const contextData = getRuntimeContext();
  const { config, probeId, surfaceId, state, baseUrl, trace } = contextData;
  const surface = (config.surfaces || []).find((entry) => entry.id === surfaceId) || null;
  const targetUrl = resolveTargetUrl(baseUrl, surface);
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const context = await browser.newContext({
    viewport: DEFAULT_VIEWPORT,
    colorScheme: 'light',
    forcedColors: 'none',
    reducedMotion: 'no-preference',
  });
  const page = await context.newPage();

  let tracePath = null;
  if (trace) {
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    const artifactsDir = path.join(process.cwd(), 'artifacts', `${probeId}-${surfaceId}-${state}`);
    await mkdir(artifactsDir, { recursive: true });
    tracePath = path.join(artifactsDir, 'trace.zip');
  }

  try {
    await applyStateEmulation(page, state);
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded' });
    // Allow client frameworks to hydrate so probes observe the settled DOM
    // rather than transient pre-hydration markup. Capped so a page that never
    // reaches network idle does not stall the run.
    await page.waitForLoadState('networkidle', { timeout: 2500 }).catch(() => undefined);
    const trigger = surface?.states?.find((entry) => entry.state === state)?.trigger || null;
    await applyTrigger(page, trigger);
    return await callback({ browser, context, page, targetUrl, surface, state, tracePath, baseUrl, probeId, surfaceId });
  } finally {
    if (tracePath) {
      await gatherTracingAssets(page, context, tracePath).catch(() => undefined);
    }
    await context.close().catch(() => undefined);
    await browser.close().catch(() => undefined);
  }
}

export { redactUrl, buildProbeResults, emitProbeResult, loadProbeCriteriaMap };
