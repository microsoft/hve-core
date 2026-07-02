// rpi-cockpit/tests/smoke.test.ts
// Client smoke test: load the real index.html + client.js into happy-dom, feed a
// view model the way the server does (a {type:"state", view} WS frame), and assert
// the painter's behaviour — with special focus on the SECURITY property of the
// agent-authored screen pane: its HTML must render inside a sandboxed <iframe>
// that can neither run scripts nor reach the parent page.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const pub = path.join(here, "..", "public");
const html = readFileSync(path.join(pub, "index.html"), "utf8");
const clientJs = readFileSync(path.join(pub, "client.js"), "utf8");

// A minimal view model that mirrors src/render.ts's ViewModel shape closely enough
// for the painter. Tests override `screen` (and anything else) per case.
function viewModel(overrides: Record<string, unknown> = {}) {
  return {
    started: true,
    task: "demo",
    host: "claude-code",
    phase: "implement",
    phaseLabel: "Implement",
    phaseNumber: 3,
    lead: "Executing the plan.",
    steps: [],
    subagents: [],
    validations: [],
    decision: null,
    steerMenu: { label: "Next-phase approach", source: "preset", options: [] },
    directives: [],
    screen: null,
    log: [],
    ...overrides,
  };
}

let win: Window;
let lastSocket: any;

beforeEach(async () => {
  win = new Window({
    url: "http://127.0.0.1/",
    // Don't let happy-dom fetch subresources referenced by index.html (the
    // `<script src="client.js">` tag, etc.) — we eval the client ourselves, and a
    // real network fetch in the test would surface an unhandled connection error.
    settings: { disableJavaScriptFileLoading: true, disableCSSFileLoading: true, fetch: { disableSameOriginPolicy: false } } as any,
  });
  const doc = win.document;
  doc.write(html);

  // Stub WebSocket: capture the instance so the test can drive onmessage/onopen
  // exactly like the server pushing a state frame. No real network in happy-dom.
  class FakeWS {
    static OPEN = 1;
    readyState = 1;
    onopen: ((e: unknown) => void) | null = null;
    onmessage: ((e: { data: string }) => void) | null = null;
    onclose: ((e: unknown) => void) | null = null;
    onerror: ((e: unknown) => void) | null = null;
    sent: string[] = [];
    constructor() {
      lastSocket = this;
    }
    send(d: string) {
      this.sent.push(d);
    }
    close() {}
  }
  (win as any).WebSocket = FakeWS;

  // Execute the client module body in the window's global scope.
  win.eval(clientJs);
  // Let the client's connect() run and create the socket.
  await new Promise((r) => setTimeout(r, 0));
});

afterEach(() => {
  win.close();
});

function push(view: Record<string, unknown>) {
  lastSocket.onmessage?.({ data: JSON.stringify({ type: "state", view }) });
}

describe("client screen pane", () => {
  it("renders agent HTML inside a sandboxed iframe with srcdoc and no script access", () => {
    push(viewModel({ screen: { html: "<h1>Mockup</h1>", title: "Design mock" } }));
    const pane = win.document.getElementById("screen")!;
    expect(pane.hidden).toBe(false);
    const iframe = pane.querySelector("iframe")!;
    expect(iframe).toBeTruthy();

    // The security boundary: an empty sandbox attribute must be present. An empty
    // value is maximally restrictive — scripts disabled, unique opaque origin —
    // so the agent HTML cannot run JS, read cookies/tokens, or reach the parent DOM.
    expect(iframe.hasAttribute("sandbox")).toBe(true);
    const sandbox = iframe.getAttribute("sandbox") ?? "";
    expect(sandbox).toBe("");
    expect(sandbox).not.toContain("allow-scripts");
    expect(sandbox).not.toContain("allow-same-origin");

    // HTML is delivered via srcdoc (inert markup), not assigned to the parent DOM.
    expect(iframe.getAttribute("srcdoc")).toBe("<h1>Mockup</h1>");
  });

  it("escapes the screen title but passes the iframe markup through untouched", () => {
    push(viewModel({ screen: { html: "<b>kept</b>", title: "<script>x</script>" } }));
    const pane = win.document.getElementById("screen")!;
    // Title is escaped in the host DOM (no live <script> element injected there).
    expect(pane.querySelector("script")).toBeNull();
    expect(pane.innerHTML).toContain("&lt;script&gt;");
    // The iframe srcdoc keeps the legitimate markup verbatim (sandbox is the boundary).
    expect(pane.querySelector("iframe")!.getAttribute("srcdoc")).toBe("<b>kept</b>");
  });

  it("hides the pane when the view model has no screen", () => {
    push(viewModel({ screen: { html: "<p>x</p>" } }));
    expect(win.document.getElementById("screen")!.hidden).toBe(false);
    push(viewModel({ screen: null }));
    const pane = win.document.getElementById("screen")!;
    expect(pane.hidden).toBe(true);
    expect(pane.querySelector("iframe")).toBeNull();
  });
});
