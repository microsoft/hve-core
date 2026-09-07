---
name: vscode-playwright
description: 'VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation'
license: MIT
compatibility: 'Requires VS Code CLI (code or code-insiders), Playwright MCP tools, and curl'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-11"
---

# VS Code Playwright Screenshot Skill

Captures VS Code editor views, code walkthroughs, and Copilot Chat examples using Playwright MCP tools with `serve-web`.

## Overview

This skill provides a complete workflow for capturing high-quality VS Code screenshots suitable for embedding in slide decks, documentation, and other visual media. It handles server lifecycle management, viewport configuration, UI cleanup, and screenshot validation.

## Prerequisites

* VS Code or VS Code Insiders CLI (`code` or `code-insiders`)
* Genuine Playwright MCP browser tools (`mcp_playwright_browser_*`)
* `curl` for server readiness checks

Tool names in this skill use an `mcp_microsoft_pla_browser_*` prefix. The actual prefix is derived from the MCP server's registration name in your host, so it may differ, for example `mcp_playwright_browser_*`. Match the prefix your host exposes.

## Verified Constraints

These three constraints were confirmed against a running `serve-web` instance. Each one invalidates an approach that looks reasonable but does not work.

* User settings live in the browser's IndexedDB, not on disk. Seeding `--server-data-dir/data/User/settings.json` has no effect on VS Code Web, so the theme, font size, and UI visibility cannot be set that way. Apply them through Command Palette commands after the workbench loads.
* Markdown files open as a cross-origin preview webview rather than a Monaco editor. The webview DOM is unreachable from the page, so rendered text inside it cannot be inspected or measured. Capture a code or configuration file when the screenshot needs measurable editor text.
* Confirm browser tooling by attempting a navigation rather than by matching tool names, because MCP tool prefixes vary by server registration. VS Code's built-in browser tools are a known case that loads the page but delivers neither keyboard nor mouse events to the VS Code Web workbench, so an attempt using them fails at the first command-palette step.

## Architecture

The `serve-web` CLI is a Rust-based proxy ("server of servers") that downloads the VS Code Server release and proxies connections to the inner Node.js server. The outer CLI accepts a limited set of flags; `--server-data-dir` is the key flag that controls where server-side data such as the downloaded server build, extensions, and machine state is stored. It does not control user settings, which the browser holds in IndexedDB.

## Quick Start

1. Detect the VS Code CLI variant and start the web server.
2. Navigate Playwright to the VS Code web instance.
3. Clean up the UI (close panels, tabs, notifications).
4. Open files and capture screenshots.
5. Stop the server and clean up.

## Workflow Steps

### Step 1: Detect VS Code CLI Variant

Check the `VSCODE_QUALITY` environment variable first; if it contains `insider`, use `code-insiders`. Otherwise, test availability with `command -v code-insiders` and fall back to `code`. Store the result for reuse:

```bash
if [[ "${VSCODE_QUALITY:-}" == *insider* ]] || command -v code-insiders &>/dev/null; then
  VSCODE_CLI="code-insiders"
else
  VSCODE_CLI="code"
fi
```

### Step 2: Start the VS Code Web Server

Create a temporary server data directory and launch `serve-web`. The `--server-data-dir` flag must receive a literal path, because shell variables from other terminal sessions are not available in background terminals:

```bash
VSCODE_SERVE_DIR=$(mktemp -d)
$VSCODE_CLI serve-web --port 8765 --without-connection-token \
  --accept-server-license-terms --server-data-dir "$VSCODE_SERVE_DIR"
```

Do not write a `data/User/settings.json` file under that directory. VS Code Web keeps user settings in the browser's IndexedDB, so a seeded settings file changes nothing. Set the theme, close restored editors, and hide UI through Command Palette commands after the workbench loads (Step 5), and raise rendered text size with `document.body.style.zoom`.

Do not try to edit the settings JSON editor by typing into a `textarea` selector either. VS Code Insiders uses the EditContext API instead of a `textarea`, so that element does not exist.

The serve-web command and `mktemp` must execute in the **same terminal session** so the `$VSCODE_SERVE_DIR` variable resolves. If using a background terminal (`isBackground: true`), inline the entire block — do not reference variables set in a different terminal.

Verify the server is ready before proceeding: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8765/` must return `200`.

If the server log contains `Ignoring option 'server-data-dir': Value must not be empty`, the variable was empty — the server is using the default data directory instead of the ephemeral one. Kill the process and re-launch with the literal path.

### Step 3: Navigate and Wait

1. Navigate to the workspace: `mcp_microsoft_pla_browser_navigate` to `http://localhost:8765/?folder=/path/to/workspace`.
2. Wait for VS Code to load: `mcp_microsoft_pla_browser_wait_for` with `time: 5` to allow the editor UI to fully render.

### Step 4: Resize Viewport

Resize the viewport to match the target placement ratio: `mcp_microsoft_pla_browser_resize` to a resolution whose aspect ratio matches the PPTX placeholder where the screenshot will be inserted.

Calculate dimensions using `width_px = 1200` and `height_px = int(1200 / (target_width_inches / target_height_inches))`. For example, a 5.5" x 4.2" placeholder produces a 1200 x 916 viewport.

When the screenshot fills a full 16:9 slide, size the viewport to 1920x1080 instead of deriving it from the 1200 px width rule. Use the width rule for every other placement, and do not use 1920x1080 there. Resize before cleanup so UI elements render at the target resolution.

### Step 5: Clean Up the UI

Prepare the editor for clean screenshots using `mcp_microsoft_pla_browser_run_code` with the Command Palette pattern:

1. Dismiss workspace trust dialog if present: take a `mcp_microsoft_pla_browser_snapshot`, look for a trust dialog, and click "Yes, I trust the authors" via `mcp_microsoft_pla_browser_click` if visible.
2. Close all editors and tabs: Command Palette -> `View: Close All Editors`.
3. Clear notifications: Command Palette -> `Notifications: Clear All Notifications`.
4. Enable Do Not Disturb: Command Palette -> `Notifications: Toggle Do Not Disturb Mode`.
5. Close Primary Side Bar: Command Palette -> `View: Close Primary Side Bar`.
6. Close bottom panel: Take a `mcp_microsoft_pla_browser_snapshot` first. If the panel (Terminal, Problems, Output) is visible, run Command Palette -> `View: Close Panel`. Do not run this command blindly — it toggles visibility and opens a hidden panel.
7. Close Secondary Side Bar: Take a `mcp_microsoft_pla_browser_snapshot` first. If the secondary side bar (Chat) is visible, run Command Palette -> `View: Close Secondary Side Bar`.
8. Zoom in for readability: use `mcp_microsoft_pla_browser_run_code` with `await page.evaluate(() => { document.body.style.zoom = '1.75'; })` for full-UI zoom. Treat no single factor as sufficient: raise the zoom and re-measure the rendered text size until it clears the caller's readability floor. At a 14 px base editor font, 18 pt is 24 CSS pixels, so roughly 1.75x is a starting point rather than a guarantee, because the base font size varies. Default font sizes become illegible (~7pt) when screenshots are shrunk to fit slide placeholders.

### Step 6: Open Files and Capture

Open files via `mcp_microsoft_pla_browser_run_code` using the Command Palette pattern: `Go to File` command opens Quick Open, then type the filename and press Enter:

```javascript
async (page) => {
  await page.keyboard.press('F1');
  await page.waitForTimeout(400);
  await page.keyboard.type('Go to File');
  await page.waitForTimeout(300);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(500);
  await page.keyboard.type('doc-ops-update.prompt.md');
  await page.waitForTimeout(500);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1000);
  return 'File opened';
}
```

Set up the view: selectively open only the panels needed for this screenshot (split views, Copilot Chat, Explorer) via click-based navigation using `mcp_microsoft_pla_browser_snapshot` to find refs followed by `mcp_microsoft_pla_browser_click`. Keep the view focused on the subject.

Take the screenshot: `mcp_microsoft_pla_browser_take_screenshot` with `type: "png"` and a descriptive `filename`.

Validate the screenshot fits the target placement. Compare the captured image's aspect ratio against the target placeholder ratio. If they diverge by more than 5%, retake with corrected viewport dimensions. If a measured rendered text size falls below the caller's readability floor, retake with higher zoom. Iterate viewport and zoom adjustments until the screenshot matches the placement dimensions without distortion.

Repeat for additional screenshots. Close the current file's tab before opening the next (Command Palette -> `View: Close All Editors`).

### Step 7: Copilot Chat Screenshots

For Copilot Chat screenshots: the Activity Bar is visible by default and settings seeding cannot change that, so leave it in place during cleanup. Open the Chat panel via Activity Bar click using `mcp_microsoft_pla_browser_snapshot` -> `mcp_microsoft_pla_browser_click`, type the prompt via `mcp_microsoft_pla_browser_run_code` with `page.keyboard.type()`, then wait for the response via `mcp_microsoft_pla_browser_wait_for` before capturing.

### Step 8: Cleanup

Stop the VS Code web server and clean up the ephemeral environment:

```bash
pkill -f "serve-web.*8765" 2>/dev/null || true
rm -rf "$VSCODE_SERVE_DIR"
```

Also close the Playwright browser: `mcp_microsoft_pla_browser_close`.

## Playwright MCP Command Palette Pattern

Individual MCP tool calls execute asynchronously, so the Command Palette closes between separate `press_key`, `type`, and `press_key` calls. All Command Palette operations must use `mcp_microsoft_pla_browser_run_code` to chain actions atomically in a single Playwright execution:

```javascript
async (page) => {
  const runCommand = async (command) => {
    await page.keyboard.press('F1');
    await page.waitForTimeout(400);
    await page.keyboard.type(command);
    await page.waitForTimeout(300);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(500);
  };

  await runCommand('View: Close All Editors');
  await runCommand('View: Close Primary Side Bar');
  // Chain additional commands as needed
  return 'Commands executed';
}
```

Never use separate `mcp_microsoft_pla_browser_press_key` -> `mcp_microsoft_pla_browser_type` -> `mcp_microsoft_pla_browser_press_key` calls for Command Palette operations — the palette loses focus between calls.

## Troubleshooting

| Issue                                                        | Cause                                                            | Solution                                                                                                         |
|--------------------------------------------------------------|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| `Ignoring option 'server-data-dir': Value must not be empty` | Shell variable resolved empty in background terminal             | Inline the full command with the literal temp directory path or run `mktemp` and `serve-web` in the same session |
| Color Theme navigates to Marketplace themes                  | No theme selected yet, and settings seeding does not apply       | Run Command Palette -> `Preferences: Color Theme` after the workbench loads                                      |
| Panel toggle opens hidden panel                              | `View: Toggle Panel Visibility` is a toggle                      | Use `View: Close Panel` only after confirming the panel is visible via snapshot                                  |
| `?file=` parameter does not auto-open files                  | VS Code web only supports `?folder=`                             | Open files through Command Palette `Go to File` command after navigating                                         |
| Text too small in screenshots                                | Default ~14px font becomes ~7pt when shrunk                      | Raise `document.body.style.zoom` and re-measure until it clears the readability floor                            |
| Screenshot aspect ratio distortion                           | Viewport ratio does not match placeholder ratio                  | Calculate viewport from placeholder: `width_px = 1200`, `height_px = int(1200 / (target_w / target_h))`          |
| UI clutter at slide-embedded sizes                           | Explorer, minimap, tabs, toasts visible                          | Close all unnecessary UI elements before each capture                                                            |
| `workbench.action.zoomIn` does not work                      | Electron-only command                                            | Use `editor.action.fontZoomIn` or CSS zoom via `page.evaluate()`                                                 |
| Browser state restoration                                    | IndexedDB/localStorage restore previous files                    | Close editors via Command Palette after load; use a fresh browser context or incognito when available            |
| `Meta+P` triggers browser action                             | Keyboard shortcuts intercepted by browser                        | Use `page.keyboard.press('F1')` to open Command Palette                                                          |
| Screenshot saved to wrong directory                          | `take_screenshot` saves relative to Playwright working directory | Copy screenshots to the target directory after capture                                                           |
| Copilot Chat responses non-deterministic                     | Streaming token-by-token output                                  | Use `mcp_microsoft_pla_browser_wait_for` with expected text or time delay                                        |

