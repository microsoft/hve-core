---
title: "Guideline 2.2 — Enough Time"
description: "Guideline 2.2 (Enough Time) requires that users have enough time to read and use content, including adjustable time limits and pause/stop/hide controls for moving content."
---

# Guideline 2.2 — Enough Time

Guideline 2.2 (Enough Time) requires that users have enough time to read and use content, including adjustable time limits and pause/stop/hide controls for moving content.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.2, <https://www.w3.org/TR/WCAG22/#enough-time>.

## sc-2-2-1

**SC 2.2.1 Timing Adjustable (Level A)**

For each time limit set by the content, at least one of: the user can turn off the limit, the user can adjust it to at least 10 times the default, the user is warned before the limit expires and can extend it with a simple action, the limit is essential (auction, real-time event), or the limit is longer than 20 hours.

**Assessment heuristics**:

* Confirm session-timeout warnings appear before expiry with an option to extend by a simple action.
* Confirm timed quizzes and forms offer an accessibility-aware extension or alternative.

Source: <https://www.w3.org/TR/WCAG22/#timing-adjustable>

## sc-2-2-2

**SC 2.2.2 Pause, Stop, Hide (Level A)**

For moving, blinking, scrolling, or auto-updating information that starts automatically, lasts more than 5 seconds, and is presented in parallel with other content, the user has a mechanism to pause, stop, or hide it (or to control its update frequency).

**Assessment heuristics**:

* Confirm auto-rotating carousels and tickers carry a pause control reachable by keyboard.
* Confirm animated content longer than 5 seconds can be stopped without disabling the rest of the page.

Source: <https://www.w3.org/TR/WCAG22/#pause-stop-hide>

## sc-2-2-3

**SC 2.2.3 No Timing (Level AAA)**

Timing is not an essential part of the event or activity presented, except for non-interactive synchronised media and real-time events.

**Assessment heuristics**:

* Confirm any non-essential time limits are removed for AAA targets.

Source: <https://www.w3.org/TR/WCAG22/#no-timing>

## sc-2-2-4

**SC 2.2.4 Interruptions (Level AAA)**

Interruptions (notifications, alerts, banners) can be postponed or suppressed by the user, except interruptions involving an emergency.

**Assessment heuristics**:

* Confirm users can configure or pause non-emergency push notifications.

Source: <https://www.w3.org/TR/WCAG22/#interruptions>

## sc-2-2-5

**SC 2.2.5 Re-authenticating (Level AAA)**

When an authenticated session expires, the user can continue the activity without loss of data after re-authentication.

**Assessment heuristics**:

* Confirm forms preserve user-entered data through a re-authentication flow.

Source: <https://www.w3.org/TR/WCAG22/#re-authenticating>

## sc-2-2-6

**SC 2.2.6 Timeouts (Level AAA)**

Users are warned about the duration of any user inactivity that could cause data loss, unless the data is preserved for more than 20 hours when the user does not take any actions.

**Assessment heuristics**:

* Confirm a clearly visible warning describes the inactivity timeout duration.
* Confirm draft-saving behaviour is documented to the user.

Source: <https://www.w3.org/TR/WCAG22/#timeouts>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
