import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const titleElements = Array.from(document.querySelectorAll('[title]'));
      const interactiveTitleElements = titleElements.filter((element) => {
        const tag = element.tagName.toLowerCase();
        const role = element.getAttribute('role');
        return ['a', 'button', 'input', 'select', 'textarea', 'summary', 'details'].includes(tag) || role === 'button' || role === 'link';
      });
      const hoverRevealElements = Array.from(document.querySelectorAll('*')).filter((element) => {
        const hasHoverHandler = element.hasAttribute('onmouseover') || element.hasAttribute('onmouseenter') || element.hasAttribute('onmouseout') || element.hasAttribute('onmouseleave');
        const hasKeyboardSupport = element.hasAttribute('tabindex') || element.matches('a[href], button, input, select, textarea, summary, details') || element.getAttribute('role') === 'button';
        return hasHoverHandler && !hasKeyboardSupport;
      });

      return {
        titleElementCount: titleElements.length,
        interactiveTitleCount: interactiveTitleElements.length,
        hoverRevealCount: hoverRevealElements.length,
      };
    });

    let status = 'pass';
    if (snapshot.interactiveTitleCount > 0 || snapshot.hoverRevealCount > 0) {
      status = 'fail';
    } else if (snapshot.titleElementCount > 0) {
      status = 'partial';
    }

    return {
      probeId: 'probe-hover-focus',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.4.13',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status,
          method: 'runtime-automation',
          evidence: `1.4.13 title elements=${snapshot.titleElementCount} hover-reveal=${snapshot.hoverRevealCount}`,
          severity: 'serious',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
