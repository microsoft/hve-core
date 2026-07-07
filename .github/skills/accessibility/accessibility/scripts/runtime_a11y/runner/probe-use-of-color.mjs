import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('a[href]'));
      const suspicious = [];

      for (const link of links) {
        const style = window.getComputedStyle(link);
        const parent = link.parentElement;
        const parentStyle = parent ? window.getComputedStyle(parent) : null;
        const isInline = ['inline', 'inline-block', 'inline-flex', 'inline-grid', 'inline-table', 'contents'].includes(style.display);
        const insideTextContext = !!(parent && ['P', 'LI', 'TD', 'TH', 'DIV', 'SPAN'].includes(parent.tagName));
        const hasNoDecoration = style.textDecorationLine === 'none' || style.textDecoration === 'none';
        const hasNoBorder = ['none', 'hidden'].includes(style.borderTopStyle) && ['none', 'hidden'].includes(style.borderBottomStyle) && ['none', 'hidden'].includes(style.borderLeftStyle) && ['none', 'hidden'].includes(style.borderRightStyle);
        const hasTransparentBackground = style.backgroundColor === 'rgba(0, 0, 0, 0)' || style.backgroundColor === 'transparent' || style.backgroundImage === 'none';
        const fontWeightMatches = parentStyle && parseInt(style.fontWeight || '400', 10) === parseInt(parentStyle.fontWeight || '400', 10);
        const colorDiffers = parentStyle && style.color !== parentStyle.color;

        if (isInline && insideTextContext && hasNoDecoration && hasNoBorder && hasTransparentBackground && fontWeightMatches && colorDiffers) {
          suspicious.push(link.textContent?.trim() || '');
        }
      }

      return {
        suspiciousLinkCount: suspicious.length,
      };
    });

    return {
      probeId: 'probe-use-of-color',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.4.1',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.suspiciousLinkCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.4.1 suspicious links=${snapshot.suspiciousLinkCount}`,
          severity: 'serious',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
