import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const minTargetSize = 24;
      const circleDiameter = 24;
      const interactiveElements = Array.from(document.querySelectorAll('a, button, [role="button"], input, select, textarea'));
      const normalizeText = (value) => (value ?? '').replace(/\s+/g, ' ').trim();
      const isInteractiveElement = (element) => {
        const tagName = element.tagName.toLowerCase();
        return tagName === 'a' || tagName === 'button' || tagName === 'input' || tagName === 'select' || tagName === 'textarea' || element.getAttribute('role') === 'button';
      };
      const isInlineElement = (element) => {
        const tagName = element.tagName.toLowerCase();
        const style = window.getComputedStyle(element);
        const isInlineDisplay = ['inline', 'inline-block', 'inline-flex', 'inline-grid'].includes(style.display);
        const hasMeaningfulText = normalizeText(element.textContent ?? element.getAttribute('aria-label')) !== '';
        const isTextLink = tagName === 'a' && isInlineDisplay && hasMeaningfulText && !element.closest('nav, ul, ol, aside, .table-of-contents, .menu');
        const isInlineTextWrapper = ['span', 'strong', 'em'].includes(tagName) && isInlineDisplay && hasMeaningfulText;
        return isTextLink || isInlineTextWrapper;
      };
      const candidates = [];

      for (const element of interactiveElements) {
        if (!isInteractiveElement(element)) {
          continue;
        }

        const style = window.getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
          continue;
        }

        if (element.hasAttribute('aria-hidden') || element.getAttribute('aria-hidden') === 'true') {
          continue;
        }

        if (element instanceof HTMLButtonElement && element.disabled) {
          continue;
        }

        const rect = element.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) {
          continue;
        }

        candidates.push({
          tagName: element.tagName.toLowerCase(),
          width: Math.round(rect.width),
          height: Math.round(rect.height),
          x: rect.x,
          y: rect.y,
          isInline: isInlineElement(element),
          text: normalizeText(element.textContent ?? element.getAttribute('aria-label')),
        });
      }

      const spacingExceptionCandidates = candidates.filter((candidate) => !candidate.isInline);
      const violations = [];
      for (const candidate of spacingExceptionCandidates) {
        const isTooSmall = candidate.width < minTargetSize || candidate.height < minTargetSize;
        if (!isTooSmall) {
          continue;
        }

        const centerX = candidate.x + candidate.width / 2;
        const centerY = candidate.y + candidate.height / 2;
        const isSpacingExempt = spacingExceptionCandidates.every((other) => {
          if (other === candidate) {
            return true;
          }
          const otherCenterX = other.x + other.width / 2;
          const otherCenterY = other.y + other.height / 2;
          const distance = Math.hypot(centerX - otherCenterX, centerY - otherCenterY);
          return distance >= circleDiameter;
        });

        if (!isSpacingExempt) {
          violations.push(`${candidate.tagName}:${candidate.text || '<empty>'}:${candidate.width}x${candidate.height}`);
        }
      }

      const smallest = candidates.reduce((currentSmallest, candidate) => {
        if (currentSmallest.width === Infinity) {
          return candidate;
        }
        return candidate.width * candidate.height < currentSmallest.width * currentSmallest.height ? candidate : currentSmallest;
      }, { width: Infinity, height: Infinity, tagName: '' });

      return {
        targetCount: candidates.length,
        violationCount: violations.length,
        smallest: smallest.width === Infinity ? 'n/a' : `${smallest.tagName}:${smallest.width}x${smallest.height}`,
        sample: candidates.slice(0, 5).map((candidate) => `${candidate.tagName}:${candidate.width}x${candidate.height}`),
      };
    });
    const hasDefect = snapshot.violationCount > 0;

    const results = await buildProbeResults({
      probeId: 'probe-target-size',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'candidate',
    });

    return {
      probeId: 'probe-target-size',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
