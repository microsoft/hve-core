// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useEffect, useRef } from 'react';
import SearchBar from '@theme-original/SearchBar';

const srOnlyStyle = {
  position: 'absolute',
  width: '1px',
  height: '1px',
  padding: 0,
  margin: '-1px',
  overflow: 'hidden',
  clip: 'rect(0, 0, 0, 0)',
  whiteSpace: 'nowrap',
  border: 0,
};

// WI-07 accessibility wrapper for the local search input.
//
// The upstream @easyops-cn/autocomplete.js (via @easyops-cn/docusaurus-search-local)
// already promotes the navbar search input to the WAI-ARIA APG Combobox pattern at
// runtime: it sets role="combobox", aria-autocomplete, aria-expanded (toggled on
// open/close), aria-activedescendant (on arrow navigation), and aria-owns pointing at
// the generated role="listbox" element. The popup items receive role="option".
//
// Two divergences from the current APG Combobox pattern remain, and this wrapper
// closes both without ejecting the upstream component (keeping the swizzle resilient
// to package upgrades):
//   1. The popup is wired with the legacy aria-owns attribute instead of aria-controls,
//      so we mirror aria-owns onto aria-controls and keep them in sync.
//   2. The "See all results" footer link is rendered as a bare interactive child of the
//      role="listbox" element, which is not an allowed listbox child (WCAG 1.3.1 / axe
//      aria-required-children). We tag the footer's anchor itself with role="option" so
//      the listbox only owns valid leaf options; tagging the wrapping div instead would
//      leave the focusable anchor as a nested interactive descendant (axe nested-interactive).
export default function SearchBarWrapper(props) {
  const containerRef = useRef(null);
  const statusRef = useRef(null);

  useEffect(() => {
    const root = containerRef.current;
    const statusNode = statusRef.current;
    if (!root || !statusNode) {
      return undefined;
    }

    let lastResultCount = null;
    let announceTimer = null;

    const announceResultCount = (count) => {
      const message = count === 0 ? 'No results' : `${count} result${count === 1 ? '' : 's'}`;
      window.clearTimeout(announceTimer);
      announceTimer = window.setTimeout(() => {
        statusNode.textContent = message;
      }, 120);
    };

    const sync = () => {
      const input = root.querySelector('input.navbar__search-input');
      if (input) {
        const owns = input.getAttribute('aria-owns');
        if (owns) {
          if (input.getAttribute('aria-controls') !== owns) {
            input.setAttribute('aria-controls', owns);
          }
        } else if (input.hasAttribute('aria-controls')) {
          input.removeAttribute('aria-controls');
        }
      }

      const listbox = root.querySelector('[role="listbox"]');
      if (listbox) {
        const footerLink = listbox.querySelector('[class*="hitFooter"] a');
        if (footerLink && footerLink.getAttribute('role') !== 'option') {
          footerLink.setAttribute('role', 'option');
        }

        const options = Array.from(listbox.querySelectorAll('[role="option"]')).filter(
          (option) => !option.closest('[class*="hitFooter"]'),
        );
        const resultCount = options.length;
        if (resultCount !== lastResultCount) {
          lastResultCount = resultCount;
          announceResultCount(resultCount);
        }
      } else if (lastResultCount !== 0) {
        lastResultCount = 0;
        announceResultCount(0);
      }
    };

    // The combobox attributes are applied lazily, the first time the input is
    // focused and the search index loads, and the popup contents are rebuilt on
    // every keystroke, so observe the whole search container rather than reading
    // the initial state once.
    sync();
    const observer = new MutationObserver(sync);
    observer.observe(root, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['aria-owns'],
    });

    return () => {
      observer.disconnect();
      window.clearTimeout(announceTimer);
    };
  }, []);

  return (
    <div ref={containerRef} style={{ display: 'contents' }}>
      <div ref={statusRef} role="status" aria-live="polite" aria-atomic="true" style={srOnlyStyle} />
      <SearchBar {...props} />
    </div>
  );
}
