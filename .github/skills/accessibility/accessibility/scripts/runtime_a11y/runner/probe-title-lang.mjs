import { emitProbeResult, redactUrl, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const title = document.title || '';
      const langValue = document.documentElement.getAttribute('lang') || '';
      const trimmedTitle = title.trim();
      const trimmedLangValue = langValue.trim();
      const langPattern = /^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$/i;

      return {
        title: trimmedTitle,
        titleLength: trimmedTitle.length,
        langValue: trimmedLangValue,
        isValidLang: trimmedLangValue ? langPattern.test(trimmedLangValue) : false,
      };
    });

    const results = [
      {
        criterionId: 'DEFECT:empty-title',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.titleLength === 0 ? 'fail' : 'pass',
        method: 'runtime-automation',
        evidence: JSON.stringify({ titleLength: snapshot.titleLength, title: snapshot.title ? redactUrl(snapshot.title) : '' }),
        severity: snapshot.titleLength === 0 ? 'moderate' : 'minor',
      },
      {
        criterionId: 'DEFECT:invalid-lang',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.isValidLang ? 'pass' : 'fail',
        method: 'runtime-automation',
        evidence: JSON.stringify({ langValue: snapshot.langValue || '', isValidLang: snapshot.isValidLang }),
        severity: snapshot.isValidLang ? 'minor' : 'moderate',
      },
    ];

    return {
      probeId: 'probe-title-lang',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
