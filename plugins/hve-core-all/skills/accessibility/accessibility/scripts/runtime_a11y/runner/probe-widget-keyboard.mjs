import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const widgets = Array.from(document.querySelectorAll('[role="combobox"], [role="menu"], [role="tablist"], [role="listbox"], [role="tree"], [role="dialog"]'));
      const issues = widgets.map((element) => {
        const role = element.getAttribute('role');
        const isFocusable = element.getAttribute('tabindex') !== null || element.matches('input, select, textarea, button, a[href], [contenteditable="true"]');
        const hasExpanded = role === 'combobox' ? element.getAttribute('aria-expanded') !== null : true;
        const hasControls = ['menu', 'combobox', 'dialog'].includes(role || '') ? element.getAttribute('aria-controls') !== null : true;
        return {
          role,
          isFocusable,
          hasExpanded,
          hasControls,
        };
      });
      return {
        roleButtons: document.querySelectorAll('[role="button"], button, a[href]').length,
        widgets: widgets.length,
        missingFocusability: issues.filter((entry) => !entry.isFocusable).length,
        missingAriaAttributes: issues.filter((entry) => !entry.hasExpanded || !entry.hasControls).length,
        issues: issues.slice(0, 5),
      };
    });
    const hasDefect = snapshot.widgets > 0 && (snapshot.missingFocusability > 0 || snapshot.missingAriaAttributes > 0);

    const results = await buildProbeResults({
      probeId: 'probe-widget-keyboard',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-widget-keyboard',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
