// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import type { Page } from '@playwright/test';

const MIN_TARGET_SIZE = 24;
const CIRCLE_DIAMETER = MIN_TARGET_SIZE;

export async function collectTargetSizeViolations(page: Page): Promise<string[]> {
  return await page.evaluate(
    ({ minTargetSize, circleDiameter }) => {
      const candidates: Array<{
        element: string;
        tagName: string;
        text: string;
        x: number;
        y: number;
        width: number;
        height: number;
        isInline: boolean;
        isInteractive: boolean;
      }> = [];
      const interactiveElements = Array.from(document.querySelectorAll<HTMLElement>('a, button, [role="button"], input, select, textarea'));

      const normalizeText = (value: string | null | undefined): string => {
        return (value ?? '').replace(/\s+/g, ' ').trim();
      };

      const isInteractiveElement = (element: Element): boolean => {
        const tagName = element.tagName.toLowerCase();
        if (tagName === 'a' || tagName === 'button' || tagName === 'input' || tagName === 'select' || tagName === 'textarea') {
          return true;
        }

        return element.getAttribute('role') === 'button';
      };

      const isInlineElement = (element: Element): boolean => {
        const tagName = element.tagName.toLowerCase();
        const style = window.getComputedStyle(element);
        const isInlineDisplay = ['inline', 'inline-block', 'inline-flex', 'inline-grid'].includes(style.display);
        const hasMeaningfulText = normalizeText(element.textContent ?? element.getAttribute('aria-label')) !== '';
        const isTextLink = tagName === 'a' && isInlineDisplay && hasMeaningfulText && !element.closest('nav, ul, ol, aside, .table-of-contents, .menu');
        const isInlineTextWrapper = ['span', 'strong', 'em'].includes(tagName) && isInlineDisplay && hasMeaningfulText;
        return isTextLink || isInlineTextWrapper;
      };

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

        if ((element as HTMLButtonElement).disabled) {
          continue;
        }

        const rect = element.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) {
          continue;
        }

        const width = Math.round(rect.width);
        const height = Math.round(rect.height);
        const text = normalizeText(element.textContent ?? element.getAttribute('aria-label'));
        const isInline = isInlineElement(element);

        candidates.push({
          element: element.tagName.toLowerCase(),
          tagName: element.tagName.toLowerCase(),
          text,
          x: rect.x,
          y: rect.y,
          width,
          height,
          isInline,
          isInteractive: true,
        });
      }

      const violations: string[] = [];
      const spacingExceptionCandidates = candidates.filter((candidate) => !candidate.isInline);

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

      return violations;
    },
    { minTargetSize: MIN_TARGET_SIZE, circleDiameter: CIRCLE_DIAMETER },
  );
}
