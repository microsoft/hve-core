import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';
import { computeTrapFromSequence } from './_core.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const selector = 'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"]), [role="button"]';

    // Tag focusable elements with a stable index so focus identity does not
    // depend on volatile text content, then start focus above the first target.
    const focusableCount = await page.evaluate((candidateSelector) => {
      const elements = Array.from(document.querySelectorAll(candidateSelector));
      elements.forEach((el, index) => el.setAttribute('data-a11y-kbidx', String(index)));
      if (document.body) {
        document.body.setAttribute('tabindex', '-1');
        document.body.focus();
      }
      return elements.length;
    }, selector);

    const sequence = [];
    const maxSteps = Math.min(Math.max(focusableCount + 3, 8), 80);

    for (let step = 0; step < maxSteps; step += 1) {
      await page.keyboard.press('Tab');
      const idx = await page.evaluate(() => {
        const active = document.activeElement;
        const marker = active?.getAttribute?.('data-a11y-kbidx');
        return marker === null || marker === undefined ? 'none' : marker;
      });
      sequence.push(idx);
      const count = sequence.length;
      // Short-circuit once focus has clearly stalled on one element.
      if (count >= 3 && idx !== 'none' && sequence[count - 2] === idx && sequence[count - 3] === idx) {
        break;
      }
    }

    await page.evaluate((candidateSelector) => {
      document.querySelectorAll(candidateSelector).forEach((el) => el.removeAttribute('data-a11y-kbidx'));
      document.body?.removeAttribute('tabindex');
    }, selector);

    const { trapped, reachableCount } = computeTrapFromSequence(sequence);
    const snapshot = {
      focusableCount,
      reachableCount,
      trapped,
      steps: sequence.length,
    };

    // Only a genuine focus trap flips a verdict; partial reachability in a
    // headless Tab walk is expected and never fails on its own.
    const status = trapped ? 'fail' : 'pass';
    const results = await buildProbeResults({
      probeId: 'probe-keyboard-traversal',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: status,
      informStatus: 'partial',
      statusByCriterion: { '2.1.1': status, '2.1.2': status, '2.4.3': status },
    });

    return {
      probeId: 'probe-keyboard-traversal',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
