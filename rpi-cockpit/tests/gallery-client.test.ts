import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");
function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}
function galleryVm() {
  const s = applyBeat(initialState(), { type: "gallery.open", title: "My apps", size: "m", items: [
    { id: "u", label: "Local", group: "live", url: "http://localhost:3000/" },
    { id: "h", label: "Snap", group: "live", html: "<b>hi</b>" },
  ] }, 1);
  return toViewModel(s);
}

describe("gallery client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the gallery view and hides the others on the gallery domain", () => {
    (win as any).render(galleryVm());
    expect((win.document.getElementById("gallery-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("dataprofile-view") as any).hidden).toBe(true);
  });

  it("renders one card per item, a group header, and the right iframe sandbox/src", () => {
    (win as any).render(galleryVm());
    const cards = win.document.querySelectorAll("#gl-grid .gl-card");
    expect(cards.length).toBe(2);
    expect(win.document.querySelector("#gl-grid .gl-group")?.textContent).toBe("live");
    const urlFrame = win.document.getElementById("gl-thumb-0") as any;
    expect(urlFrame.getAttribute("sandbox")).toBe("allow-scripts allow-same-origin allow-forms");
    expect(urlFrame.getAttribute("src")).toBe("http://localhost:3000/");
    const htmlFrame = win.document.getElementById("gl-thumb-1") as any;
    expect(htmlFrame.getAttribute("sandbox")).toBe("");
    expect(htmlFrame.srcdoc).toBe("<b>hi</b>");
  });

  it("opens the lightbox on a card click and closeLightbox() hides it", () => {
    (win as any).render(galleryVm());
    (win.document.querySelector("#gl-grid .gl-card") as any).dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.getElementById("gl-lightbox") as any).hidden).toBe(false);
    // happy-dom's synthetic Event has no `key`, so the Escape keydown path is not
    // exercised here; call the close handler directly to assert it hides the overlay.
    win.eval("closeLightbox()");
    expect((win.document.getElementById("gl-lightbox") as any).hidden).toBe(true);
  });
});
