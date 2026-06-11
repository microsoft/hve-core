---
title: "ARIA APG family — Tabs"
description: "The Tabs family covers tabbed-content interfaces, where a row of tabs controls which of several tab panels is visible."
---

# ARIA APG family — Tabs

The Tabs family covers tabbed-content interfaces, where a row of tabs controls which of several tab panels is visible. APG separates the family into two activation modes (manual and automatic) because the keyboard contract differs even though the markup is identical. The third historical APG entry, Tabbed Carousel, lives in `family-disclosure.md` alongside the other carousel variants because the source rollup groups all three carousel patterns there.

Source: W3C WAI-ARIA Authoring Practices Guide, Tabs family, <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/>.

## pattern-tabs-manual-activation

**Tabs (Manual Activation)** is the variant where moving keyboard focus along the tablist does not change which panel is visible. The user moves focus with the arrow keys and then presses Enter or Space to activate the focused tab and reveal its panel. This is the recommended activation mode when revealing a panel is expensive (large data fetch, layout reflow, or destructive side effects).

**Required keyboard**

* Tab moves focus to the active tab when entering the tablist, and out of the tablist on the next Tab press.
* Left and Right arrows (for horizontal tablists) or Up and Down arrows (for vertical tablists) move focus between tabs without activating them.
* Home moves focus to the first tab; End moves focus to the last tab.
* Enter or Space activates the focused tab, showing its associated panel.
* Delete (optional) removes a closable tab.

**Required ARIA**

* `role="tablist"` on the container, with `aria-orientation="horizontal"` or `aria-orientation="vertical"` as appropriate.
* `role="tab"` on each tab, with `aria-selected="true"` on the active tab and `aria-selected="false"` on the rest.
* `aria-controls` on each tab pointing at its panel's `id`.
* `role="tabpanel"` on each panel, with `aria-labelledby` pointing at its owning tab's `id`.
* Only the active tab is in the page tab sequence (`tabindex="0"`); inactive tabs are removed with `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/examples/tabs-manual/>

## pattern-tabs-automatic-activation

**Tabs (Automatic Activation)** is the variant where moving keyboard focus along the tablist immediately changes which panel is visible. Pressing Left or Right (or Up or Down for a vertical tablist) both moves focus and activates the newly focused tab. This is the recommended activation mode when revealing a panel is cheap and the user benefits from a fast scan across panels.

**Required keyboard**

* Tab moves focus to the active tab when entering the tablist, and out of the tablist on the next Tab press.
* Left and Right arrows (horizontal) or Up and Down arrows (vertical) move focus and activate the newly focused tab in a single step.
* Home moves focus to and activates the first tab; End moves focus to and activates the last tab.
* Delete (optional) removes a closable tab.

**Required ARIA**

* `role="tablist"` on the container, with `aria-orientation` set appropriately.
* `role="tab"` on each tab, with `aria-selected="true"` on the currently focused and active tab.
* `aria-controls` on each tab pointing at its panel's `id`.
* `role="tabpanel"` on each panel, with `aria-labelledby` pointing at its owning tab's `id`.
* Only the active tab is in the page tab sequence (`tabindex="0"`); inactive tabs use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/examples/tabs-automatic/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
