import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const media = Array.from(document.querySelectorAll('audio, video'));
      const autoplayWithSound = media.filter((element) => {
        const hasAutoplay = element.hasAttribute('autoplay');
        const hasControls = element.hasAttribute('controls');
        const isMuted = element.hasAttribute('muted') || element.getAttribute('muted') === '';
        return hasAutoplay && !hasControls && !isMuted;
      });

      return {
        autoplayWithSoundCount: autoplayWithSound.length,
      };
    });

    return {
      probeId: 'probe-audio-control',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.4.2',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.autoplayWithSoundCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.4.2 autoplay-with-sound media=${snapshot.autoplayWithSoundCount}`,
          severity: 'serious',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
