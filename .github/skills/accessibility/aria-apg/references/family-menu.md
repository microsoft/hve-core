---
title: "ARIA APG family — Menu"
description: "The Menu family covers application menus, menu buttons, menubars, and menubars that support multi-selection of menu items."
---

# ARIA APG family — Menu

The Menu family covers application menus, menu buttons, menubars, and menubars that support multi-selection of menu items. Menu widgets behave like desktop application menus rather than navigation menus: users move focus with arrow keys, open submenus along the perpendicular axis, and dismiss menus with Escape. Navigation menus that look like menubars but use links instead of menuitems are documented as `pattern-menubar-navigation` to make the distinction explicit.

Source: W3C WAI-ARIA Authoring Practices Guide, Menu and Menubar patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/> and <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/>.

## pattern-menu-button

**Menu Button** is a button that opens a popup menu of actions, options, or commands. The button acts as the menu's trigger and its accessible reference; the menu itself follows the standard `role="menu"` keyboard contract once it opens.

**Required keyboard**

* When focus is on the button: Enter, Space, or Down arrow opens the menu and moves focus to the first menu item; Up arrow opens the menu and moves focus to the last menu item.
* When focus is in the menu: Down and Up arrows move focus between menu items (wrapping at the ends); Home and End jump to the first and last items.
* Escape closes the menu and returns focus to the button.
* Tab closes the menu and moves focus to the next focusable element after the button.
* Enter or Space on a focused menu item activates the item and closes the menu.
* Printable characters jump focus to the next menu item whose visible label starts with the typed character.

**Required ARIA**

* The button uses `aria-haspopup="menu"` and `aria-expanded="true"` or `aria-expanded="false"`; when the menu is open, `aria-controls` on the button points at the menu's `id`.
* The popup uses `role="menu"`, with each item using `role="menuitem"` (or `role="menuitemcheckbox"` or `role="menuitemradio"` when stateful).
* Submenu triggers use `aria-haspopup="menu"` and `aria-expanded`.
* The first menu item receives focus when the menu opens; subsequent navigation uses managed focus.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/>

## pattern-menubar-editor

**Menubar (Editor)** is the editor-style menubar found in desktop applications such as word processors. Top-level menu items live in a horizontal menubar, and each top-level item opens a vertical dropdown menu that may contain submenus. The pattern emphasises rapid keyboard navigation between menus.

**Required keyboard**

* Tab moves focus into and out of the menubar; the menubar itself is one tab stop.
* Within the menubar: Left and Right arrows move focus between top-level items (wrapping at the ends); Down arrow or Enter opens the focused menu and moves focus to its first item; Up arrow opens the menu and moves focus to its last item.
* Within an open menu: Down and Up arrows move focus between items; Right arrow opens a submenu or moves to the next top-level menu; Left arrow closes the current submenu (or moves to the previous top-level menu when at the root).
* Enter or Space activates the focused menuitem and closes the menu chain.
* Escape closes the current menu and returns focus to its trigger (or to the menubar item for top-level menus).
* Printable characters jump focus to the next item whose label starts with the typed character.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"`.
* Top-level items use `role="menuitem"` with `aria-haspopup="menu"` and `aria-expanded`.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.
* Submenu items use `role="menuitem"`, `role="menuitemcheckbox"`, or `role="menuitemradio"` as appropriate.
* Only one element in the menubar carries `tabindex="0"` at any time; the rest use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-editor/>

## pattern-menubar-navigation

**Menubar (Navigation)** is the navigation-style variant of a menubar, used as a site-wide or section-level navigation bar. The visible behaviour resembles `pattern-menubar-editor`, but the leaf items are links that navigate to URLs rather than menuitems that fire JavaScript actions. APG keeps the pattern separate because the activation contract differs: leaf items are activated by following a link rather than by invoking an application command.

**Required keyboard**

* Tab moves focus into and out of the navigation menubar.
* Left and Right arrows move focus between top-level items; Down arrow opens the submenu under the focused top-level item.
* Within an open submenu: Down and Up arrows move focus between submenu items (which are typically links); Right arrow opens a nested submenu; Left arrow closes the current submenu and returns focus to its trigger.
* Enter or Space on a leaf link follows the link (the same as activating an `<a>` element directly).
* Escape closes the current submenu.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"` and an accessible name (`aria-label` such as "Main").
* Top-level items that open a submenu use `role="menuitem"` with `aria-haspopup="menu"` and `aria-expanded`.
* Leaf items use native `<a>` elements; the surrounding `role="menu"` and `role="none"` wrappers expose the structure to assistive technology without breaking link semantics.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-navigation/>

## pattern-actions-menu-button

**Actions Menu Button** is a specialised menu button whose menu items represent contextual actions on a target object (for example, the row-level actions menu in a data grid or the per-item kebab menu in a list view). The keyboard contract is identical to `pattern-menu-button`; APG documents the pattern separately to highlight authoring guidance about labelling, contextual scope, and menu placement.

**Required keyboard**

* Enter, Space, or Down arrow on the button opens the menu and moves focus to the first action.
* Up arrow on the button opens the menu and moves focus to the last action.
* Within the menu: Down and Up arrows move focus between actions; Home and End jump to the first or last action.
* Escape closes the menu and returns focus to the button.
* Tab closes the menu and moves focus to the next focusable element.
* Enter or Space activates the focused action and closes the menu.
* Printable characters jump focus to the next action whose label starts with the typed character.

**Required ARIA**

* The button uses `aria-haspopup="menu"`, `aria-expanded`, and `aria-controls`. The button label identifies both the context and the kind of menu (for example, "Actions for Smith order #4421").
* The popup uses `role="menu"` with `aria-label` describing the target of the actions.
* Each action uses `role="menuitem"`, or `role="menuitemcheckbox"` or `role="menuitemradio"` when the action toggles state.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/examples/menu-button-actions-active-descendant/>

## pattern-menubar-multi-select

**Menubar with Multiple Selection** is a menubar variant where items support multi-selection through `role="menuitemcheckbox"` or `role="menuitemradio"`. Users toggle selection state on each item without dismissing the menu, which suits filter menus, column-picker menus, and tag-assignment menus.

**Required keyboard**

* Tab moves focus into and out of the menubar.
* Left and Right arrows move focus between top-level menus; Down arrow opens a menu and moves focus to its first item.
* Within an open menu: Down and Up arrows move focus between items; Home and End jump to the first or last item.
* Space toggles the selection state of the focused `menuitemcheckbox` or `menuitemradio` without closing the menu.
* Enter activates the focused item; on a checkbox or radio item the behaviour is the same as Space but typically also closes the menu in the default APG implementation.
* Shift+arrow keys (optional) extend selection across a contiguous range of items.
* Ctrl+A (optional) selects all items in the current menu when multi-selection is permitted.
* Escape closes the menu and returns focus to its menubar trigger.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"`.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.
* Multi-select items use `role="menuitemcheckbox"` with `aria-checked="true"` or `aria-checked="false"`.
* Single-select-within-group items use `role="menuitemradio"` with `aria-checked` and a `role="group"` wrapper that scopes the radio set.
* `aria-multiselectable="true"` may appear on the parent menu when grouped multi-selection is supported across items.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-editor/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
