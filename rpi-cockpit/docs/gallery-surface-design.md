<!-- markdownlint-disable MD013 -->
# Gallery surface design

## Purpose

The agent graphic gallery built this session (a scrollable contact sheet that renders every cockpit agent as a scaled live thumbnail) turned out to be a broadly useful way to look at many things at once, not just agents. The same scaled-thumbnail grid is an excellent way to compare several running apps, several pages of one site, or several rendered states side by side. Today it only exists as an untracked generator script (`.gen-gallery.mjs`) that writes a static `gallery.html`; there is no way to use it from inside the cockpit, and it only knows how to render the 65 agents.

This design promotes the gallery to a first-class cockpit surface: a new `gallery` loop view, driven by MCP tools, that renders a set of generic items as a grid of scaled live thumbnails. Each item is either a live URL (a website or a dev server, rendered in an iframe) or an inline HTML snapshot (rendered via `srcdoc`). The 65-agent contact sheet becomes one producer of items rather than the whole feature.

## A new `gallery` domain

`gallery` becomes a new loop-view domain, peer to `rpi`, `review`, `interview`, `backlog`, `team`, `codemap`, and `dataprofile`. Opening it switches the cockpit to the gallery view, exactly as `review.start` / `backlog.start` switch to theirs. The mutually-exclusive view routing is unchanged: the client shows `#gallery-view` when `v.domain === "gallery"` and hides the other views.

## State

Three new `SessionState` fields:

* `galleryTitle: string | null` (the board heading; null when no gallery is active).
* `gallerySize: "s" | "m" | "l"` (the initial thumbnail size the agent requested; defaults to `"m"`). The client offers a local S/M/L toggle that starts from this value; the toggle is a viewer-only override and is never written back to state.
* `galleryItems: GalleryItem[]`, where `GalleryItem = { id: string; label: string; group?: string; url?: string; html?: string; caption?: string }`.

Each item is meant to carry exactly one of `url` or `html`. `url` is a live source rendered in an iframe; `html` is an inline snapshot rendered via the iframe's `srcdoc`. `group` is an optional section header (for example the eight agent categories); items with no `group` fall under an unlabelled default section. `caption` is optional small text under the label. An item with neither `url` nor `html` renders as a labelled empty tile.

## Beats and tools

Three new beats and three new MCP tools. The MCP tool count goes from 33 to 36 (`tests/mcp.test.ts` updates accordingly).

| Tool | Beat | Effect |
| --- | --- | --- |
| `gallery_open(title, items[], size?)` | `gallery.open` | Switch the view to `gallery`, set `galleryTitle` and `gallerySize` (default `"m"`), and replace `galleryItems` with the supplied items (a fresh board). |
| `gallery_add(item)` | `gallery.add` | Append a `GalleryItem`, or update the existing one with the same `id` in place (the same upsert-by-id rule `item.add` uses). |
| `gallery_clear()` | `gallery.clear` | Empty `galleryItems` (the surface stays open with its title; an empty-state shows). |

Item `id` is optional at the tool boundary. `gallery_open` assigns a stable id by position (`g0`, `g1`, ...) to any item that omits one, so a caller can pass a bare list. `gallery_add` requires a concrete `id` so the upsert target is unambiguous.

`url` is validated at the tool boundary: it must match `^https?://` (loopback dev servers and external https sites are both allowed). `javascript:` and `data:` URLs are rejected; inline content goes through the `html` field, which the cockpit owns and renders itself. `size`, when present, is constrained to the `"s" | "m" | "l"` enum (a zod enum) so an unknown value is rejected rather than rendered. The tool descriptions disambiguate "gallery item" from a kanban "item".

## View-model

`toViewModel` projects:

```text
gallery: {
  title: string | null;
  size: "s" | "m" | "l";
  items: { id; label; group: string | null; kind: "url" | "html" | "empty"; src: string | null; caption: string | null }[];
}
```

`kind` is derived purely: `"url"` when `url` is set, else `"html"` when `html` is set, else `"empty"`. `src` carries the `url` (for `url`) or the raw `html` string (for `html`), or `null` (for `empty`). The raw html travels in the view-model as a plain JSON string and the client assigns it via `iframe.srcdoc` as a DOM property, so there is no HTML-attribute escaping step and nested-`srcdoc` content renders correctly (this avoids the string-escaping pitfall the static generator hit). The projection stays pure.

## The view

A new `#gallery-view`, a sibling of the other loop views, shown when `v.domain === "gallery"` and hidden otherwise. It fills `#loop` (like `#rpi-view`) and scrolls. It renders:

* A header line: the `title`, an item count, and an S / M / L segmented toggle.
* One section per distinct `group` (in first-seen order), each with a small group heading and a grid of tiles. Items with no group render in a leading unlabelled section.
* Each tile is a figure: a caption row (the `label`, the optional `caption`, and for `url` tiles an "open in tab" link to the URL) above a thumbnail. The thumbnail is a sandboxed iframe rendered at a fixed logical viewport and CSS-scaled to the tile width. `url` tiles use `sandbox="allow-scripts allow-same-origin allow-forms"` (cross-origin, so the framed app gets its own origin and can never reach the cockpit, the same model as the app frame); `html` snapshot tiles use `sandbox=""` (no scripts; they are static HTML).
* The S / M / L toggle changes the grid column width and the thumbnail scale (roughly 320 / 460 / 640 px tiles). It is local viewer state initialised from `v.gallery.size`.

Clicking a tile (anywhere except the open-in-tab link) opens a lightbox, a fixed overlay that re-renders that one item full-size and scrollable, with the item label as a heading and a close control. Escape, a backdrop click, or the close control dismisses it. This is the "match the window, then scroll" behaviour applied to any single tile.

External sites that refuse framing (via `X-Frame-Options` or CSP `frame-ancestors`) cannot be reliably detected from cross-origin JavaScript, so the view does not claim to. Instead every `url` tile always carries the "open in tab" affordance, and the lightbox header notes that a blank frame usually means the site blocks embedding. Loopback dev servers always frame, so the common case is unaffected.

Every interpolated text field (label, caption, group, title) goes through the existing `esc()` helper. `url` is validated again in the client against the loopback-or-https predicate before it is assigned to an iframe `src`, as defense in depth (the same belt-and-suspenders the app frame uses).

## Agent contract

`agents/cockpit-instructions.md` and the "Cockpit instrumentation" section of the repo `CLAUDE.md` gain a Gallery section: use `gallery_open(title, items)` to show several things at once (multiple running apps or sites as `url` items, or several rendered states as `html` items), `gallery_add` to stream tiles in as they appear, and `gallery_clear` to reset. The note states the one-of-`url`-or-`html` rule and that `url` must be `http(s)`.

## The 65-agent gallery as a producer

The untracked `.gen-gallery.mjs` is promoted to a tracked tool, `tools/agent-gallery.mjs`, that keeps the happy-dom rendering logic (build a representative `SessionState` per agent, render it through the real `public/client.js`, capture `document.body.innerHTML`, pair it with the cockpit CSS) but, instead of writing a static file, pushes the 65 captured snapshots as `html` items (grouped by the eight categories) through `gallery_open("HVE Core agents", items)` to a running cockpit, using the same MCP-producer pattern used to drive the live pane. The app-frame mock injection and the dark-pane wrapping from the scratch version are retained, since a snapshot tile is the same isolated-iframe situation. "Look at websites" needs no producer: it is a direct `gallery_open("My apps", [{ label, url }, ...])` call.

## Testing

* state: `gallery.open` sets the title, size, and items and switches the domain to `gallery`; a missing item id is filled by position; `gallery.add` appends, and a second `gallery.add` with the same id updates in place; `gallery.clear` empties items but keeps the title and domain.
* view-model: `toViewModel` exposes `gallery.title`, `gallery.size`, and the `items` array with `kind` derived as url / html / empty and `src` carrying the right value; null title and default size `"m"` when no gallery started.
* tools: a round trip drives `gallery_open` + `gallery_add` + `gallery_clear` over the in-memory transport and asserts `bridge.state.galleryItems` / `galleryTitle`; the tool count assertion goes 33 to 36; `gallery_open` rejects a non-http(s) `url` and an out-of-enum `size`.
* client: the `gallery` domain shows `#gallery-view` and hides the others; one tile per item; sections render per `group`; a `url` item produces an iframe with the right sandbox plus an open-in-tab link; an `html` item produces a `srcdoc` iframe with `sandbox=""`; clicking a tile opens the lightbox and Escape closes it; fields are escaped. The client test follows the existing happy-dom render-harness pattern.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `gallery` domain, the three state fields and their beats, the three MCP tools with url/size validation, the view-model projection, the `#gallery-view` with grouped scaled thumbnails, the S/M/L toggle, the click-to-expand lightbox, the open-in-tab affordance, the agent contract, the `tools/agent-gallery.mjs` producer, and the tests above.

Deferred / non-goals:

* Saved or persisted galleries (the surface is live narration; the agent re-opens it as needed).
* Server-side screenshotting of external sites (tiles frame the live site; sites that block framing are handled by open-in-tab, not by capturing an image).
* Auto-refresh or polling of `url` tiles (they are live iframes; a reload is a user action in the lightbox).
* Drag-to-reorder, per-tile pinning, or full-text search across tiles (the agent supplies a meaningful order and grouping).
* Reading or measuring cross-origin tile content from the cockpit (forbidden by the sandbox and by the privacy posture).
