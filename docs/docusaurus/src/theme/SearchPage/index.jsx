// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useEffect, useRef } from 'react';
import SearchPage from '@theme-original/SearchPage';

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

export default function SearchPageWrapper(props) {
  const statusRef = useRef(null);

  useEffect(() => {
    // The status region is owned by this component and rendered inside the main
    // landmark. It was previously created on <body> under a fixed id and removed
    // unconditionally on unmount, so two live instances left the survivor writing
    // to a detached node and announcements stopped with no error.
    const statusNode = statusRef.current;
    if (!statusNode) {
      return undefined;
    }
    statusNode.textContent = '';

    // Separate timers: one debounces recomputation, the other sets the text.
    // Sharing a single timer let the results observer keep cancelling the
    // pending announcement so it never fired.
    let syncTimer = null;
    let announceTimer = null;
    let zeroConfirmTimer = null;
    let lastMessage = null;

    const getSearchInput = () => document.querySelector('input[name="q"]');

    // WCAG 2.4.1 Bypass Blocks: the upstream search page server-renders the
    // query field with an autofocus attribute. Autofocus moves the sequential
    // navigation start point past every control that precedes the field in the
    // document, and the skip-to-content link is the first of them. Measured on
    // the built site: on this route the first Tab landed on a footer link
    // instead of the skip link, while the same Tab on the home route reached
    // the skip link correctly. The bypass mechanism is therefore unreachable by
    // forward tabbing on the one route whose landmark it exists to reach.
    //
    // The attribute is removed rather than the focus being moved elsewhere. A
    // user who navigated to /search/ deliberately still has the field one Tab
    // away, and removing the attribute restores the document's natural focus
    // order without taking focus away from anyone mid-interaction.
    const searchField = getSearchInput();
    if (searchField?.hasAttribute('autofocus')) {
      searchField.removeAttribute('autofocus');
      if (document.activeElement === searchField) {
        // Blurring alone is not enough. Chromium keeps a sequential focus
        // navigation starting point at the element that was last focused, so a
        // bare blur() leaves the next Tab resuming from the search field and
        // landing on the first control after it - measured on the built site as
        // a footer link, with the whole page bypassed. Focusing the body moves
        // that starting point to the beginning of the document, which is where
        // a freshly loaded page starts and where the skip link is the first
        // stop. The tabindex is removed immediately so the body does not become
        // a lasting tab stop of its own.
        searchField.blur();
        document.body.setAttribute('tabindex', '-1');
        document.body.focus();
        document.body.removeAttribute('tabindex');
      }
    }

    // Results render as <article> elements (searchResultItem). Scope the count
    // to the main landmark so unrelated articles elsewhere on the page cannot
    // inflate the announced result count.
    const getResultsRoot = () => document.querySelector('main, [role="main"]') ?? document.body;
    const getResultCount = () => getResultsRoot().querySelectorAll('article').length;

    // The upstream search page renders its own result summary paragraph as a
    // direct child of the search container, and only once the query has
    // resolved. It renders for both outcomes: "N documents found" and the
    // not-found text. Its presence is therefore a render-level answer to "has
    // this search finished", which elapsed time is not.
    const getResultSummary = () => {
      const container = getSearchInput()?.closest('.container') ?? null;
      return container ? container.querySelector(':scope > p') : null;
    };

    const announce = (message) => {
      if (message === lastMessage) {
        return;
      }
      lastMessage = message;
      window.clearTimeout(announceTimer);
      announceTimer = window.setTimeout(() => {
        statusNode.textContent = message;
      }, 60);
    };

    const syncStatus = () => {
      const input = getSearchInput();
      const query = input?.value?.trim() ?? '';
      if (!query) {
        window.clearTimeout(announceTimer);
        window.clearTimeout(zeroConfirmTimer);
        statusNode.textContent = '';
        lastMessage = null;
        return;
      }
      const count = getResultCount();
      if (count > 0) {
        window.clearTimeout(zeroConfirmTimer);
        announce(`${count} document${count === 1 ? '' : 's'} found`);
        return;
      }

      // A zero count is ambiguous: the query may simply not have resolved yet.
      // Search results render asynchronously, so announcing "No documents
      // found" on the first pass tells a screen-reader user there are no
      // results for a query that is still running, and the later correction
      // does not undo what they already heard.
      //
      // A quiet period alone cannot tell those two states apart, because it
      // measures elapsed time rather than whether the search finished. Measured
      // under parallel load: this timer fired about 1750 ms after the last
      // keystroke while results arrived 1860-4413 ms after it, so every sampled
      // run announced a definitive "no results" for a query returning 100
      // documents. Requiring upstream's rendered summary as well replaces that
      // proxy with the fact it was approximating.
      //
      // The quiet period is kept rather than replaced: upstream does not reset
      // its results when the query changes, only when the query empties, so a
      // summary left over from a previous query can still be on screen while
      // the current one is running.
      window.clearTimeout(zeroConfirmTimer);
      zeroConfirmTimer = window.setTimeout(() => {
        const currentInput = getSearchInput();
        const currentQuery = currentInput?.value?.trim() ?? '';
        if (currentQuery !== query || getResultCount() !== 0) {
          return;
        }
        // Stay silent while the search is still running. The observer below
        // schedules another sync when upstream renders its summary, which
        // re-enters this path with the query resolved.
        if (!getResultSummary()) {
          return;
        }
        announce('No documents found');
      }, 1500);
    };

    const scheduleSync = () => {
      window.clearTimeout(syncTimer);
      syncTimer = window.setTimeout(syncStatus, 150);
    };

    const input = getSearchInput();
    if (input) {
      input.addEventListener('input', scheduleSync);
    }

    // Watch for result additions/removals. The observer must see the whole
    // document because the results container is replaced during rendering, but
    // it ignores this component's own status writes: a body-wide observer that
    // reacts to them repeatedly reschedules the debounce and starves the
    // announcement it exists to trigger.
    const observer = new MutationObserver((records) => {
      const relevant = records.some(
        (record) => record.target !== statusNode && !statusNode.contains(record.target),
      );
      if (relevant) {
        scheduleSync();
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });

    scheduleSync();

    return () => {
      if (input) {
        input.removeEventListener('input', scheduleSync);
      }
      observer.disconnect();
      window.clearTimeout(syncTimer);
      window.clearTimeout(announceTimer);
      window.clearTimeout(zeroConfirmTimer);
    };
  }, []);

  return (
    <>
      <div
        ref={statusRef}
        id="search-results-status"
        role="status"
        aria-live="polite"
        aria-atomic="true"
        style={srOnlyStyle}
      />
      <SearchPage {...props} />
    </>
  );
}
