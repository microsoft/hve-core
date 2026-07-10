---
description: Launch the HVE Cockpit agent gallery (all 65 agents) and show it live in the preview pane
argument-hint: ""
---

# Gallery

Open the **HVE Cockpit gallery** surface (the scrollable contact sheet of every HVE Core agent) and show it live in the Claude Code preview pane. Do this without asking for confirmation.

1. **Build if needed.** From `rpi-cockpit/`, run `npm run build` only when `dist/` is missing or older than `src/`; otherwise skip it.
2. **Launch the producer in the background:** `cd rpi-cockpit && node tools/agent-gallery.mjs` (pass `PORT=<n>` if 4505 is taken). It renders every agent through the real cockpit client and prints `agent gallery: http://127.0.0.1:<port>/?key=<token>` while it keeps serving. Capture that full keyed URL from its output.
3. **Show it in the preview pane.** Start or reuse a preview server, then navigate the preview to the captured keyed URL (`preview_eval` setting `window.location.href`). The page loads the full cockpit with the `gallery` domain already open.
4. **Verify** with a screenshot (agent tiles grouped by category, the S/M/L size toggle bottom-left of the header, click-to-expand lightbox) and a console-error check.
5. **Report** the keyed URL so the user can open it in their own browser, and remind them the **S/M/L** toggle resizes the tiles and clicking a tile opens the full-size lightbox.

Leave the producer running so the user can keep exploring; it serves until killed.
