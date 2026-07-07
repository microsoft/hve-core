import { emitProbeResult, redactUrl, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const consoleMessages = [];
    const pageErrorMessages = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleMessages.push(msg.text());
      }
    });

    page.on('pageerror', (error) => {
      pageErrorMessages.push(error.message || String(error));
    });

    try {
      await page.reload({ waitUntil: 'load' });
      await page.waitForTimeout(500);
    } catch (error) {
      pageErrorMessages.push(error instanceof Error ? error.message : String(error));
    }

    const hasErrors = consoleMessages.length > 0 || pageErrorMessages.length > 0;
    const firstConsoleError = consoleMessages[0] ? redactUrl(consoleMessages[0]) : '';
    const firstPageError = pageErrorMessages[0] ? redactUrl(pageErrorMessages[0]) : '';

    return {
      probeId: 'probe-console-errors',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: 'DEFECT:console-error',
          framework: 'defect-scan',
          surfaceId: surface?.id || 'unknown',
          state,
          status: hasErrors ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: JSON.stringify({
            consoleErrorCount: consoleMessages.length,
            pageErrorCount: pageErrorMessages.length,
            firstConsoleError,
            firstPageError,
          }),
          severity: hasErrors ? 'serious' : 'minor',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
