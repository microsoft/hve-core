---
title: "Objective 8 - Support Adaptation and Personalization"
description: "Objective 8 covers patterns that let users adapt the interface to their preferences and capabilities."
---

# Objective 8 - Support Adaptation and Personalization

Objective 8 covers patterns that let users adapt the interface to their preferences and capabilities. The user need is "User Control": users with cognitive and learning disabilities benefit when they can control motion, integrate assistive extensions, simplify the interface, and personalise the appearance and behaviour to match their needs.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 8, <https://www.w3.org/TR/coga-usable/#objective-8>.

## control-let-users-control-when-the-content-moves-or-changes

**Control 8.1 Let Users Control When the Content Moves or Changes**

Motion, animation, and auto-advancing carousels distract users with attention differences and can trigger vestibular reactions. Users must be able to pause, stop, or disable motion globally.

**Design patterns**:

* Provide pause and stop controls for any moving or auto-advancing content.
* Honour the `prefers-reduced-motion` user preference.
* Disable autoplay for video and animation by default.
* Avoid using motion as the sole indicator of state.

**Assessment heuristics**:

* Confirm `prefers-reduced-motion` disables non-essential animation.
* Confirm auto-advancing content has visible pause and stop controls.
* Confirm motion is not the sole indicator of state changes.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

## control-enable-apis-and-extensions

**Control 8.2 Enable APIs and Extensions**

Users rely on browser extensions, reading aids, and assistive technology to adapt content. The site must use standard semantic markup, expose accessibility APIs correctly, and avoid blocking extensions through anti-automation measures.

**Design patterns**:

* Use semantic HTML so reading aids and extensions can parse the content.
* Expose accessibility properties via ARIA where appropriate.
* Avoid blocking browser extensions or assistive technology with anti-automation defences.
* Avoid heavy client-side rendering that hides content from extensions.

**Assessment heuristics**:

* Confirm content is exposed through the accessibility tree, not only through visual rendering.
* Confirm browser extensions (reading aids, simplifiers, translators) can access and modify content.
* Confirm anti-automation measures do not interfere with assistive technology.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

## control-support-simplification

**Control 8.3 Support Simplification**

Some users benefit from a simplified version of a page. Sites should support reader modes, provide print-friendly views, and avoid layouts that break under simplification.

**Design patterns**:

* Support browser reader mode by using semantic article markup.
* Provide a print-friendly view that strips navigation and decoration.
* Avoid relying on positioning that breaks when content is linearised.
* Ensure key content is reachable in a single linear reading order.

**Assessment heuristics**:

* Confirm reader mode produces a usable, complete version of the content.
* Confirm a print view is available and includes only the relevant content.
* Confirm the linear reading order matches the visual order.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

## control-support-a-personalised-and-familiar-interface

**Control 8.4 Support a Personalised and Familiar Interface**

Personalisation lets users adjust the interface to suit their preferences. Honouring user settings (font size, contrast, dark mode, language) and remembering choices across sessions makes the interface feel familiar and reduces cognitive load.

**Design patterns**:

* Honour user preferences for font size, contrast, dark mode, and language.
* Remember personalisation choices across sessions when the user consents.
* Use standard semantics so personalisation extensions can apply the user's chosen vocabulary, icons, or symbols.
* Avoid forcing a single visual theme on all users.

**Assessment heuristics**:

* Confirm user preferences (`prefers-color-scheme`, `prefers-reduced-motion`, font-size settings) are honoured.
* Confirm personalisation choices persist across sessions when the user has opted in.
* Confirm semantic markup supports personalisation extensions and assistive vocabularies.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
