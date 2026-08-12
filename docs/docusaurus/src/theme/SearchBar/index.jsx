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
    let lastMessage = null;
    let announceTimer = null;
    let announceDelayTimer = null;
    let currentInput = null;
    // The upstream widget owns a hashed CSS-module "cursor" class for the
    // highlighted option. When focus roves onto the external "See all results"
    // footer we borrow that class so the footer shows the same highlight; this
    // remembers the discovered token across state changes.
    let footerActiveClass = null;
    // Announcement timing mirrors the search page: a quiet period so ordinary
    // typing produces one announcement rather than one per keystroke, a short
    // write delay, and suppression of a repeated message. The quiet period must
    // exceed a realistic inter-keystroke interval, otherwise it elapses between
    // every character and coalesces nothing.
    //
    // 400 ms rather than 300 ms: the announcement a user hears must land a full
    // quiet period after they stop typing, and the write delay is part of that
    // wait. At 300 ms the total settle time was 360 ms, which leaves no margin
    // over a 250 ms conformance floor once event-loop scheduling and the gap
    // between the last keypress and the last input event are counted. 400 ms
    // still sits far above ordinary inter-keystroke intervals, so a whole typed
    // query continues to coalesce into one announcement.
    const ANNOUNCE_QUIET_MS = 400;
    const ANNOUNCE_WRITE_MS = 60;
    // Timestamp of the most recent keystroke, used to measure the quiet period
    // against user input rather than against announcement bookkeeping.
    let lastInputAt = 0;
    const noteUserInput = () => {
      lastInputAt = performance.now();
    };

    const clearStatusMessage = () => {
      window.clearTimeout(announceTimer);
      window.clearTimeout(announceDelayTimer);
      statusNode.textContent = '';
      lastMessage = null;
    };

    const announceResultCount = (count, query) => {
      const message = count === 0
        ? `No results for "${query}". Try a broader term or browse the documentation.`
        : `${count} result${count === 1 ? '' : 's'}`;
      // Suppression is keyed on the query as well as the message. Keying on the
      // message alone withholds confirmation when a changed query happens to
      // return the same count, which is the state a user most needs announced.
      const messageKey = `${query}\u0000${message}`;
      window.clearTimeout(announceDelayTimer);

      // The quiet period is measured against the last keystroke, not against the
      // last time this function ran. Restarting the timer only on entry couples
      // the debounce to whether the message changed: a keystroke that leaves the
      // trimmed query and the result count unchanged (typing the space in
      // "getting started", for example) does not reach this function at all, so
      // a timer armed by an earlier keystroke survives and expires while the
      // user is still typing. Measured on the built site, that fired an
      // announcement 26 ms after a keystroke instead of 300 ms after the last
      // one. Re-checking the elapsed quiet time here makes the delay a property
      // of user input rather than of message-change detection.
      const flush = () => {
        const quietFor = performance.now() - lastInputAt;
        if (quietFor < ANNOUNCE_QUIET_MS) {
          announceDelayTimer = window.setTimeout(flush, ANNOUNCE_QUIET_MS - quietFor);
          return;
        }
        if (messageKey === lastMessage) {
          return;
        }
        lastMessage = messageKey;
        window.clearTimeout(announceTimer);
        announceTimer = window.setTimeout(() => {
          statusNode.textContent = message;
        }, ANNOUNCE_WRITE_MS);
      };
      announceDelayTimer = window.setTimeout(flush, ANNOUNCE_QUIET_MS);
    };

    const getSearchInput = () => root.querySelector('input.navbar__search-input');
    const getListbox = () => root.querySelector('[role="listbox"]');
    const getFooterLink = (listboxNode) => (listboxNode ? listboxNode.querySelector('[class*="hitFooter"] a') : null);
    const getResultOptions = (listboxNode) => Array.from(listboxNode?.querySelectorAll('[role="option"]') ?? []).filter(
      (option) => !option.closest('[class*="hitFooter"]'),
    );
    // Locate whichever element currently carries the upstream "cursor" highlight
    // class (a hashed CSS-module token such as `cursor_xxxx`) so it can be cleared
    // from the options while the footer shows its own highlight.
    const findCursor = (listboxNode) => {
      const holder = listboxNode ? listboxNode.querySelector('[class*="cursor"]') : null;
      const cls = holder
        ? Array.from(holder.classList).find((name) => /cursor/i.test(name))
        : null;
      return { holder, cls: cls ?? footerActiveClass };
    };

    // A focus request that originates from a user gesture is issued while that
    // gesture's event is still being dispatched. An event's phase is reset to
    // NONE once dispatch ends, so this distinguishes the Ctrl+K shortcut, which
    // focuses the input from inside its own keydown dispatch, from the upstream
    // index-load refocus, which runs from an asynchronous continuation.
    let lastUserGesture = null;
    const rememberUserGesture = (event) => {
      lastUserGesture = event;
    };
    document.addEventListener('keydown', rememberUserGesture, true);
    document.addEventListener('pointerdown', rememberUserGesture, true);
    const isUserGestureInFlight = () => Boolean(lastUserGesture)
      && lastUserGesture.eventPhase !== Event.NONE;

    // The upstream package calls focus() on the input once its search index
    // finishes loading. A user who opened search and then moved on while the
    // index was still loading has focus taken back. Wrapping the input's own
    // focus method suppresses exactly that call - focus is elsewhere and no
    // gesture asked for it - while leaving Ctrl+K and every user-driven focus
    // untouched.
    let guardedInput = null;
    const releaseRefocusGuard = () => {
      if (guardedInput) {
        delete guardedInput.focus;
        guardedInput = null;
      }
    };
    const applyRefocusGuard = (input) => {
      if (guardedInput === input) {
        return;
      }
      releaseRefocusGuard();
      const nativeFocus = HTMLElement.prototype.focus;
      input.focus = function guardedFocus(...args) {
        if (document.activeElement !== this && !isUserGestureInFlight()) {
          return undefined;
        }
        return nativeFocus.apply(this, args);
      };
      guardedInput = input;
    };

    // The upstream widget closes its popup when the input blurs, and its close
    // subscriber then calls blur() on the input a second time. During a native
    // Tab the browser has already chosen the next control by the time that
    // second call runs, so it arrives against an input that no longer holds
    // focus. Ignoring exactly that call leaves the browser's chosen destination
    // intact. A blur() issued while the input really is focused - selecting a
    // result, or dismissing the popup - still calls through.
    let blurGuardedInput = null;
    const releaseBlurGuard = () => {
      if (blurGuardedInput) {
        delete blurGuardedInput.blur;
        blurGuardedInput = null;
      }
    };
    const applyBlurGuard = (input) => {
      if (blurGuardedInput === input) {
        return;
      }
      releaseBlurGuard();
      const nativeBlur = HTMLElement.prototype.blur;
      input.blur = function guardedBlur(...args) {
        if (document.activeElement !== this) {
          return undefined;
        }
        return nativeBlur.apply(this, args);
      };
      blurGuardedInput = input;
    };

    // Returns focusable elements in document order starting after (or before,
    // when going backwards) the given element.
    //
    // The widget's own controls are included: the clear button is the correct
    // next stop when the plugin renders one, and skipping it would move focus
    // somewhere the user did not ask for. Candidates are returned rather than a
    // single element because matching the selector and having layout boxes does
    // not make an element focusable - Docusaurus's back-to-top button has both
    // and is visibility:hidden until the page scrolls, so focus() on it is a
    // silent no-op. The caller confirms which candidate actually took focus.
    const collectSequentialFocusCandidates = (fromElement, backwards) => {
      const focusableSelector = [
        'a[href]',
        'button:not([disabled])',
        'input:not([disabled])',
        'select:not([disabled])',
        'textarea:not([disabled])',
        '[tabindex]:not([tabindex="-1"])',
      ].join(',');
      const all = Array.from(document.querySelectorAll(focusableSelector))
        .filter((element) => element.getClientRects().length > 0)
        .filter((element) => element.getAttribute('tabindex') !== '-1');
      const index = all.indexOf(fromElement);
      if (index === -1) {
        return [];
      }
      const step = backwards ? -1 : 1;
      const candidates = [];
      for (let cursor = index + step; cursor >= 0 && cursor < all.length; cursor += step) {
        const candidate = all[cursor];
        if (typeof candidate.focus === 'function') {
          candidates.push(candidate);
        }
      }
      return candidates;
    };

    // Moves focus to the nearest element that genuinely accepts it, and returns
    // that element, or null when nothing does.
    //
    // The activeElement check is a guard, not the mechanism: on the current
    // markup the first candidate always accepts focus, so removing the check
    // does not change behavior here. It stays because focus() is silent when it
    // fails - a visibility:hidden or otherwise unfocusable candidate would
    // return "moved" without moving anything, and the caller would then cancel
    // the browser's own move on the strength of it.
    const moveFocusSequentially = (fromElement, backwards) => {
      for (const candidate of collectSequentialFocusCandidates(fromElement, backwards)) {
        candidate.focus();
        if (document.activeElement === candidate) {
          return candidate;
        }
      }
      return null;
    };

    const clearFooterHighlight = (footerLink) => {      if (footerLink) {
        footerLink.classList.remove('search-footer-active');
      }
      // The borrowed upstream class can also be left on the footer, so clear any
      // stray copy site-wide rather than only the class this repository adds.
      if (footerActiveClass && footerLink) {
        footerLink.classList.remove(footerActiveClass);
      }
    };

    // Exactly one option may claim the active and selected state. APG requires
    // aria-selected on the option the active descendant points at, and requires
    // it to be false (or absent) everywhere else, so a screen reader announces
    // one current choice rather than none or many.
    const setActiveOption = (input, option, listboxNode) => {
      const listbox = listboxNode ?? getListbox();
      const candidates = [
        ...getResultOptions(listbox),
        ...(getFooterLink(listbox) ? [getFooterLink(listbox)] : []),
      ];
      for (const candidate of candidates) {
        candidate.setAttribute('aria-selected', candidate === option ? 'true' : 'false');
      }
      if (option?.id) {
        input.setAttribute('aria-activedescendant', option.id);
      } else {
        input.removeAttribute('aria-activedescendant');
      }
    };

    const clearActiveOption = (input, listboxNode) => {
      const listbox = listboxNode ?? getListbox();
      for (const candidate of getResultOptions(listbox)) {
        candidate.setAttribute('aria-selected', 'false');
      }
      const footerLink = getFooterLink(listbox);
      if (footerLink) {
        footerLink.setAttribute('aria-selected', 'false');
      }
      input.removeAttribute('aria-activedescendant');
    };

    const handleInputKeyDown = (event) => {
      const input = getSearchInput();
      const listbox = getListbox();
      const footerLink = getFooterLink(listbox);
      if (!input) {
        return;
      }

      // The upstream handler cancels Tab to keep focus inside the combobox,
      // which is a WCAG 2.1.2 keyboard trap under a screen reader whose focus
      // mode keeps the popup open.
      //
      // Suppressing that handler is not sufficient on its own. Measured on the
      // built site: with the popup open the native move is left uncancelled and
      // still ends on <body>, while the intended destination stays connected
      // and tabbable throughout and the very next Tab reaches it. The widget's
      // synchronous teardown runs in the same task as the browser's in-flight
      // sequential move and the move is lost. Deferring that teardown by a task
      // was tried and did not recover it.
      //
      // So the move is performed here rather than delegated. Focus is placed on
      // the next element that genuinely accepts it - the clear button when the
      // plugin renders one - and the default is cancelled only once that has
      // been confirmed. If nothing accepts focus the event is left alone and the
      // browser does whatever it would have done, so this can never be the thing
      // that strands a keyboard user.
      if (event.key === 'Tab') {
        event.stopImmediatePropagation();
        clearFooterHighlight(footerLink);
        input.removeAttribute('aria-activedescendant');

        const origin = document.activeElement instanceof HTMLElement
          ? document.activeElement
          : input;
        const moved = moveFocusSequentially(origin, event.shiftKey);
        if (moved) {
          event.preventDefault();
        }
        return;
      }

      // Escape is handled before the listbox gate below: a zero-results query
      // renders no footer link, and gating Escape on one skips cleanup in
      // exactly that state.
      if (event.key === 'Escape') {
        clearFooterHighlight(footerLink);
        clearActiveOption(input, listbox);
        return;
      }

      if (!listbox || !footerLink) {
        return;
      }

      const options = getResultOptions(listbox);
      const lastOption = options[options.length - 1];
      const activeDescendantId = input.getAttribute('aria-activedescendant');
      const isOnFooter = activeDescendantId === footerLink.id;
      const isOnLastOption = Boolean(lastOption) && activeDescendantId === lastOption.id;

      // Last option -> footer. The upstream handler would wrap the selection back
      // to the first option, so stop it and move the active descendant onto the
      // "See all results" footer ourselves. Clear the upstream option highlight
      // and apply our own stable highlight class to the footer.
      if ((event.key === 'ArrowDown' || event.key === 'End') && lastOption && isOnLastOption) {
        event.preventDefault();
        event.stopImmediatePropagation();
        const { holder, cls } = findCursor(listbox);
        if (holder && cls) {
          footerActiveClass = cls;
          holder.classList.remove(cls);
        }
        footerLink.classList.add('search-footer-active');
        setActiveOption(input, footerLink, listbox);
        footerLink.scrollIntoView({ block: 'nearest' });
        return;
      }

      // Footer -> last option. Stop upstream (its internal cursor still points at
      // the last option) and restore the highlight there.
      if (event.key === 'ArrowUp' && isOnFooter && lastOption) {
        event.preventDefault();
        event.stopImmediatePropagation();
        clearFooterHighlight(footerLink);
        if (footerActiveClass) {
          lastOption.classList.add(footerActiveClass);
        }
        setActiveOption(input, lastOption, listbox);
        lastOption.scrollIntoView({ block: 'nearest' });
        return;
      }

      // Footer -> first option (wrap). Let upstream advance from the last option
      // to the first; only clear the footer's highlight first.
      if (event.key === 'ArrowDown' && isOnFooter) {
        clearFooterHighlight(footerLink);
        return;
      }

      // Enter on the footer follows the "See all results" link instead of
      // activating the upstream widget's last selected option.
      if (event.key === 'Enter' && isOnFooter) {
        event.preventDefault();
        event.stopImmediatePropagation();
        footerLink.click();
      }
    };

    const sync = () => {
      const input = getSearchInput();
      if (input && input !== currentInput) {
        if (currentInput) {
          currentInput.removeEventListener('keydown', handleInputKeyDown, true);
          currentInput.removeEventListener('input', noteUserInput);
        }
        currentInput = input;
        currentInput.addEventListener('keydown', handleInputKeyDown, { capture: true });
        currentInput.addEventListener('input', noteUserInput);
        applyRefocusGuard(currentInput);
        applyBlurGuard(currentInput);
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
        // Only claim the combobox role once the widget can actually behave as
        // one. Upstream attaches lazily on first interaction and only then adds
        // aria-autocomplete and the popup wiring; advertising role="combobox"
        // before that point announces "combobox, collapsed" for a control that
        // owns nothing, which is worse than the native searchbox semantics the
        // input already has.
        const upstreamAttached = input.hasAttribute('aria-autocomplete');
        if (upstreamAttached) {
          if (input.getAttribute('role') !== 'combobox') {
            input.setAttribute('role', 'combobox');
          }
          const nextExpanded = isOpen ? 'true' : 'false';
          if (input.getAttribute('aria-expanded') !== nextExpanded) {
            input.setAttribute('aria-expanded', nextExpanded);
          }
        } else {
          if (input.hasAttribute('role')) {
            input.removeAttribute('role');
          }
          if (input.hasAttribute('aria-expanded')) {
            input.removeAttribute('aria-expanded');
          }
        }

        // A collapsed popup owns no options, so a retained active descendant
        // points at an element that is gone or hidden.
        if (!isOpen && input.hasAttribute('aria-activedescendant')) {
          clearActiveOption(input, listbox);
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

        const resultOptions = getResultOptions(listbox);
        const totalOptions = resultOptions.length + (footerLink ? 1 : 0);
        resultOptions.forEach((option, index) => {
          option.setAttribute('aria-posinset', String(index + 1));
          option.setAttribute('aria-setsize', String(totalOptions));
        });
        if (footerLink) {
          footerLink.setAttribute('aria-posinset', String(totalOptions));
          footerLink.setAttribute('aria-setsize', String(totalOptions));
        }

        // The theme renders the clear control with a camelCase CSS-module class
        // (searchClearButton_xxxx) and no type attribute. CSS attribute
        // substring matching is case-sensitive, so the `i` flag is required to
        // match it; without the flag the control never receives its name and is
        // announced only as its glyph.
        const clearButton = root.querySelector('button[type="reset"], button[class*="clear" i]');
        if (clearButton && clearButton.getAttribute('aria-label') !== 'Clear search') {
          clearButton.setAttribute('aria-label', 'Clear search');
        }

        const descriptionId = 'search-shortcut-description';
        let descriptionNode = root.querySelector(`#${descriptionId}`);
        if (!descriptionNode) {
          descriptionNode = document.createElement('div');
          descriptionNode.id = descriptionId;
          // HTMLElement.style is [PutForwards=cssText]; assigning an object is a
          // silent no-op, so copy each declaration onto the live style object to
          // keep the node visually hidden (sr-only) rather than rendered.
          Object.assign(descriptionNode.style, srOnlyStyle);
          descriptionNode.textContent = 'Keyboard shortcut: Control plus K';
          root.prepend(descriptionNode);
        }

        const currentDescribedBy = input.getAttribute('aria-describedby');
        const describedByIds = currentDescribedBy ? currentDescribedBy.split(/\s+/) : [];
        if (!describedByIds.includes(descriptionId)) {
          input.setAttribute('aria-describedby', [...describedByIds, descriptionId].join(' ').trim());
        }

        // The input is named directly. Naming it by reference required injecting
        // a visually hidden h2 into the banner on every page, which disturbed
        // the heading outline around the page title.
        if (input.hasAttribute('aria-labelledby')) {
          input.removeAttribute('aria-labelledby');
        }
        if (input.getAttribute('aria-label') !== 'Search') {
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
        currentInput.removeEventListener('keydown', handleInputKeyDown, true);
        currentInput.removeEventListener('input', noteUserInput);
      }
      releaseRefocusGuard();
      releaseBlurGuard();
      document.removeEventListener('keydown', rememberUserGesture, true);
      document.removeEventListener('pointerdown', rememberUserGesture, true);
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
