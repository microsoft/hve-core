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
    let lastQuery = '';
    let lastOpenState = false;
    let announceTimer = null;
    let currentInput = null;

    const clearStatusMessage = () => {
      window.clearTimeout(announceTimer);
      statusNode.textContent = '';
    };

    const announceResultCount = (count, query) => {
      const message = count === 0
        ? `No results for "${query}". Try a broader term or browse the documentation.`
        : `${count} result${count === 1 ? '' : 's'}`;
      clearStatusMessage();
      announceTimer = window.setTimeout(() => {
        statusNode.textContent = message;
      }, 120);
    };

    const getSearchInput = () => root.querySelector('input.navbar__search-input');
    const getListbox = () => root.querySelector('[role="listbox"]');
    const getFooterLink = (listboxNode) => (listboxNode ? listboxNode.querySelector('[class*="hitFooter"] a') : null);

    const handleInputKeyDown = (event) => {
      const input = getSearchInput();
      const listbox = getListbox();
      const footerLink = getFooterLink(listbox);
      if (!input || !listbox || !footerLink) {
        return;
      }

      const options = Array.from(listbox.querySelectorAll('[role="option"]')).filter(
        (option) => !option.closest('[class*="hitFooter"]'),
      );
      const lastOption = options[options.length - 1];
      if ((event.key === 'ArrowDown' || event.key === 'End') && lastOption) {
        event.preventDefault();
        input.setAttribute('aria-activedescendant', footerLink.id);
        footerLink.focus({ preventScroll: true });
      }
    };

    const sync = () => {
      const input = getSearchInput();
      if (input && input !== currentInput) {
        if (currentInput) {
          currentInput.removeEventListener('keydown', handleInputKeyDown);
        }
        currentInput = input;
        currentInput.addEventListener('keydown', handleInputKeyDown);
      }

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

      const listbox = getListbox();
      const footerLink = getFooterLink(listbox);
      const query = input ? input.value.trim() : '';
      // The upstream widget hides (rather than removes) the popup on Escape, so
      // presence alone is not "open"; require the listbox to be rendered/visible.
      const listboxVisible = Boolean(listbox) && listbox.getClientRects().length > 0;
      const isOpen = listboxVisible && query.length > 0;

      if (input) {
        // aria-expanded/aria-controls/aria-activedescendant are only permitted on a
        // combobox. The upstream widget sets these attributes but does not always
        // apply the role at rest, so enforce it here (WCAG 4.1.2 / axe aria-allowed-attr).
        if (input.getAttribute('role') !== 'combobox') {
          input.setAttribute('role', 'combobox');
        }

        const nextExpanded = isOpen ? 'true' : 'false';
        if (input.getAttribute('aria-expanded') !== nextExpanded) {
          input.setAttribute('aria-expanded', nextExpanded);
        }

        if (footerLink) {
          if (footerLink.getAttribute('role') !== 'option') {
            footerLink.setAttribute('role', 'option');
          }
          if (footerLink.getAttribute('tabindex') !== '-1') {
            footerLink.setAttribute('tabindex', '-1');
          }
          if (!footerLink.id) {
            footerLink.id = 'search-footer-link';
          }
        }

        const clearButton = root.querySelector('button[type="reset"], button[class*="clear"]');
        if (clearButton && clearButton.getAttribute('aria-label') !== 'Clear search') {
          clearButton.setAttribute('aria-label', 'Clear search');
        }

        const descriptionId = 'search-shortcut-description';
        let descriptionNode = root.querySelector(`#${descriptionId}`);
        if (!descriptionNode) {
          descriptionNode = document.createElement('div');
          descriptionNode.id = descriptionId;
          descriptionNode.style = srOnlyStyle;
          descriptionNode.textContent = 'Keyboard shortcut: Control plus K';
          root.prepend(descriptionNode);
        }

        const currentDescribedBy = input.getAttribute('aria-describedby');
        const describedByIds = currentDescribedBy ? currentDescribedBy.split(/\s+/) : [];
        if (!describedByIds.includes(descriptionId)) {
          input.setAttribute('aria-describedby', [...describedByIds, descriptionId].join(' ').trim());
        }

        const headingId = 'search-input-heading';
        let headingNode = root.querySelector(`#${headingId}`);
        if (!headingNode) {
          headingNode = document.createElement('h2');
          headingNode.id = headingId;
          headingNode.style = srOnlyStyle;
          headingNode.textContent = 'Search';
          root.prepend(headingNode);
        }

        if (input.getAttribute('aria-labelledby') !== headingId) {
          input.setAttribute('aria-labelledby', headingId);
        }
        if (!input.hasAttribute('aria-label')) {
          input.setAttribute('aria-label', 'Search');
        }
      }

      let resultCount = 0;
      if (listbox) {
        const options = Array.from(listbox.querySelectorAll('[role="option"]')).filter(
          (option) => !option.closest('[class*="hitFooter"]'),
        );
        resultCount = options.length;
      }

      if (!query || !isOpen) {
        clearStatusMessage();
        lastQuery = query;
        lastResultCount = resultCount;
        lastOpenState = isOpen;
        return;
      }

      const shouldAnnounce =
        query !== lastQuery || resultCount !== lastResultCount || isOpen !== lastOpenState;

      if (shouldAnnounce) {
        announceResultCount(resultCount, query);
      }

      lastQuery = query;
      lastResultCount = resultCount;
      lastOpenState = isOpen;
    };

    // The combobox attributes are applied lazily, the first time the input is
    // focused and the search index loads, and the popup contents are rebuilt on
    // every keystroke, so observe the whole search container rather than reading
    // the initial state once.
    //
    // sync() mutates attributes/DOM inside `root`, which would otherwise be
    // re-observed and re-trigger sync() in an unbounded microtask loop that
    // freezes the main thread once results (and the footer link) render. Wrap
    // every run so the observer is disconnected while our own mutations are
    // applied and reconnected afterward; only genuine upstream mutations then
    // schedule another run.
    let observer;
    const observerConfig = { subtree: true, childList: true, attributes: true };
    const runSync = () => {
      if (observer) {
        observer.disconnect();
      }
      try {
        sync();
      } finally {
        if (observer) {
          observer.observe(root, observerConfig);
        }
      }
    };

    runSync();
    observer = new MutationObserver(runSync);
    observer.observe(root, observerConfig);

    return () => {
      if (currentInput) {
        currentInput.removeEventListener('keydown', handleInputKeyDown);
      }
      observer.disconnect();
      clearStatusMessage();
    };
  }, []);

  return (
    <div ref={containerRef} style={{ display: 'contents' }}>
      <div ref={statusRef} role="status" aria-live="polite" aria-atomic="true" style={srOnlyStyle} />
      <SearchBar {...props} />
    </div>
  );
}
