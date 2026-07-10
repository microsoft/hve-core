import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const style = document.createElement('style');
      style.setAttribute('data-runtime-a11y-spacing', 'true');
      style.textContent = `
        * { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; }
        p { margin-bottom: 2em !important; }
      `;
      document.head.appendChild(style);

      const clipped = [];
      const elements = Array.from(document.querySelectorAll('body *'));
      for (const element of elements) {
        const text = element.textContent?.trim() || '';
        if (!text) {
          continue;
        }
        const computed = window.getComputedStyle(element);
        const isHiddenOverflow = computed.overflow === 'hidden' && (element.scrollHeight > element.clientHeight || element.scrollWidth > element.clientWidth);
        if (isHiddenOverflow) {
          clipped.push(element.tagName.toLowerCase());
        }
      }

      return {
        clippedElementCount: clipped.length,
      };
    });

    return {
      probeId: 'probe-text-spacing',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.4.12',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.clippedElementCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.4.12 clipped elements=${snapshot.clippedElementCount}`,
          severity: 'serious',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
