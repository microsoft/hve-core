// rpi-cockpit/public/client.js
// Thin painter: every value comes from the server's view model (src/render.ts).
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const WF_ICON = { build: "</>", review: "✓", plan: "▦", docs: "▤", data: "▥", coach: "✷" };

// Client mirror of src/url.ts isLoopbackHttpUrl. The app frame is a TRUSTED iframe
// (scripts + the app's own origin), so its URL is constrained to a loopback http(s)
// origin. The server already rejects non-loopback URLs at the MCP tool boundary;
// this re-check before assigning the iframe src is defense in depth. Keep this in
// lockstep with the TS predicate.
function isLoopbackHttpUrl(u) {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    const h = url.hostname.toLowerCase();
    return h === "localhost" || h === "127.0.0.1" || h === "[::1]" || h === "::1";
  } catch {
    return false;
  }
}

// Client mirror of src/url.ts isGalleryUrl. Gallery tiles may frame loopback dev
// servers (http or https) and external https sites; external http is rejected.
// Re-checked here before assigning an iframe src (defense in depth). Keep this in
// lockstep with the TS predicate.
function isGalleryUrl(u) {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    if (isLoopbackHttpUrl(u)) return true;
    return url.protocol === "https:";
  } catch {
    return false;
  }
}

function renderNavTiles(v) {
  setHtml("nav-workflows", (v.workflows || []).map((w) =>
    `<div class="wf-tile" data-launch="${esc(w.id)}" role="button" tabindex="0" aria-label="Start ${esc(w.name)}">
       <div class="wf-ico">${esc(WF_ICON[w.id] || "•")}</div>
       <div class="wf-name">${esc(w.name)}</div>
       <div class="wf-hint">${esc(w.hint)}</div>
       <div class="wf-desc">${esc(w.description)}</div>
     </div>`).join(""));
}

function renderContext(v) {
  const c = v.context || { instructions: [], skills: [], collection: null };
  const strip = document.getElementById("context-strip");
  if (!strip) return;
  const chip = (t, cls) => `<span class="ctx-chip${cls ? " " + cls : ""}">${esc(t)}</span>`;
  const group = (id, chips) => {
    const el = document.getElementById(id);
    if (!el) return false;
    const has = chips.length > 0;
    el.hidden = !has;
    if (has) el.querySelector(".ctx-chips").innerHTML = chips.join("");
    return has;
  };
  const gi = group("ctx-instructions", (c.instructions || []).map((t) => chip(t)));
  const gs = group("ctx-skills", (c.skills || []).map((t) => chip(t)));
  const gc = group("ctx-collection", c.collection ? [chip(c.collection, "collection")] : []);
  strip.hidden = !(gi || gs || gc);
}

// App frame panel (#app-frame). SECURITY: the app frame is the TRUSTED sibling of
// the sandboxed screen pane. The iframe's sandbox is fixed in index.html to
// "allow-scripts allow-same-origin allow-forms" (no top-navigation, no popups);
// because the framed app runs on its own port it is cross-origin to the cockpit,
// so allow-same-origin grants the app its OWN origin, never the cockpit's. We
// re-check the loopback predicate here before assigning src as defense in depth:
// the server already rejected non-loopback URLs at the tool boundary, but a stale
// or tampered view-model URL must never reach the iframe. The URL text lands in
// the cockpit DOM via setText (escaped), and src is set via setAttribute only
// after the check passes.
function renderAppFrame(v) {
  const panel = document.getElementById("app-frame");
  const iframe = document.getElementById("af-iframe");
  if (!panel || !iframe) return;
  const url = v.appFrame && v.appFrame.url;
  if (url && isLoopbackHttpUrl(url)) {
    panel.hidden = false;
    setText("af-url", url);
    if (iframe.getAttribute("src") !== url) iframe.setAttribute("src", url);
  } else {
    panel.hidden = true;
    if (iframe.getAttribute("src")) iframe.removeAttribute("src");
    setText("af-url", "");
  }
}

let ws = null;
let backoff = 500;
// Tracks the rendered codemap node-id signature so renderCodemap rebuilds the
// node elements only when the node set changes (build-once); focus/touch updates
// then mutate classes + the camera transform in place so the camera glides. (codemap)
let cmSig = null;
// Gallery view state: the current items (for lightbox lookup by index) and the
// user's S/M/L size override (sticky across re-renders until the server sends a
// new gallery.open size). (gallery)
let glItems = [];
let glSizeOverride = null;
let glResizeRaf = 0;
// Promptlab: which case rows are expanded, keyed by the case's data-pc value (its
// stable case id). The expanded state lives here (not read back from the DOM) so a
// click flips it and writes the row's class in one shot. (promptlab)
const plOpen = new Set();
// Memory: which entry rows are expanded, keyed by the entry's data-me id (the same
// id-keyed Set + per-render reconcile + document re-scan pattern the promptlab case
// rows use, because happy-dom's eval harness does not reflect parentElement mutations).
const meOpen = new Set();

// Flow canvas camera + interaction state. The agent narrates topology (v.flow); the client
// lays it out (computeFlowLayout), renders cards into #gw-world, and applies a 2D camera.
let gwCam = { x: 40, y: 40, z: 1 };
let gwFocusOverride = undefined; // undefined = follow server; string|null = local drill
let gwServerFocus = null;        // last server focus seen, to detect new narration
let gwSel = null;                // selected node id
let gwPos = {}, gwNodes = [];    // active layout positions + nodes (for inspector + minimap)
let gwFitSig = null;             // active scope + node-set signature; re-fit the camera when it changes
const GW_GLYPH = { workflow: "▦", trigger: "⊙", guard: "⚿", agent: "✦", output: "▣", mcp: "⚙" };

// Last view-model rendered. The flow drill-in/select/clear handlers re-render the
// flow scope by calling renderFlow(lastView); without a retained view-model they
// would have nothing to rebuild from. Set at the top of render(v).
let lastView = null;

function connect() {
  setConn("connecting");
  // The per-session token usually rides the same-origin cookie set when this page
  // loaded via /?key=…. Forward it explicitly from the URL too, so the WS handshake
  // authenticates even before/without that cookie.
  const key = new URLSearchParams(location.search).get("key");
  const suffix = key ? `/?key=${encodeURIComponent(key)}` : "";
  ws = new WebSocket(`ws://${location.host}${suffix}`);
  ws.onopen = () => { backoff = 500; };
  ws.onmessage = (e) => {
    let msg;
    try { msg = JSON.parse(e.data); } catch { return; }
    if (msg.type === "state" && msg.view) { setConn("live"); render(msg.view); }
  };
  ws.onclose = () => { setConn("offline"); setTimeout(connect, backoff); backoff = Math.min(backoff * 2, 8000); };
  ws.onerror = () => { try { ws.close(); } catch (_) {} };
}

function setConn(status) {
  const pill = document.getElementById("conn-pill");
  if (pill) pill.dataset.status = status;
  setText("conn-label", status === "live" ? "live" : status === "offline" ? "offline" : "connecting…");
}

function renderHome(v) {
  const wf = v.activeWorkflow ? (v.workflows.find((w) => w.id === v.activeWorkflow) || null) : null;
  const running = v.started || !!v.activeWorkflow;
  setHtml("orient", running
    ? `<span>${esc((wf && wf.name) || v.task || "A loop")} is running. <button id="to-loop" class="crumb-back">Open it</button></span>`
    : `Nothing running yet. Ask in chat to start a workflow.`);
  const welcome = document.getElementById("welcome");
  if (welcome) welcome.hidden = localStorage.getItem("hve-welcome-dismissed") === "1";
  const status = document.getElementById("home-status");
  if (status) status.textContent = running ? "Loop running" : "No loop running";
}

function render(v) {
  lastView = v;
  renderContext(v);
  renderAppFrame(v);
  renderNavTiles(v);
  renderDecisionFlow(v);
  if (v.navigatorOpen) { const w = document.getElementById("welcome"); if (w) w.hidden = false; }

  const home = document.getElementById("home");
  const loop = document.getElementById("loop");
  if (home && loop) {
    const onHome = v.view === "home";
    home.hidden = !onHome;
    loop.hidden = onHome;
    const toHomeBtn = document.getElementById("to-home");
    if (toHomeBtn) toHomeBtn.hidden = onHome;
    if (onHome) { renderHome(v); return; }
  }

  const rpiView = document.getElementById("rpi-view");
  const findingsView = document.getElementById("findings-view");
  const interviewView = document.getElementById("interview-view");
  const backlogView = document.getElementById("backlog-view");
  const teamView = document.getElementById("team-view");
  const codemapView = document.getElementById("codemap-view");
  const dataprofileView = document.getElementById("dataprofile-view");
  const galleryView = document.getElementById("gallery-view");
  const promptlabView = document.getElementById("promptlab-view");
  const memoryView = document.getElementById("memory-view");
  const flowView = document.getElementById("flow-view");
  if (rpiView && findingsView) {
    if (v.domain === "codemap") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = false;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderCodemap(v);
      return;
    }
    if (v.domain === "team") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = false;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderTeam(v);
      return;
    }
    if (v.domain === "backlog") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = false;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderBoard(v);
      return;
    }
    if (v.domain === "dataprofile") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = false;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderDataProfile(v);
      return;
    }
    if (v.domain === "gallery") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = false;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderGallery(v);
      return;
    }
    if (v.domain === "promptlab") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = false;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderPromptlab(v);
      return;
    }
    if (v.domain === "flow") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = false;
      renderFlow(v);
      return;
    }
    if (v.domain === "memory") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = false;
      if (flowView) flowView.hidden = true;
      renderMemory(v);
      return;
    }
    if (v.domain === "interview") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = false;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = true;
      if (flowView) flowView.hidden = true;
      renderInterview(v);
      return;
    }
    const review = v.domain === "review";
    rpiView.hidden = review;
    findingsView.hidden = !review;
    if (interviewView) interviewView.hidden = true;
    if (backlogView) backlogView.hidden = true;
    if (teamView) teamView.hidden = true;
    if (codemapView) codemapView.hidden = true;
    if (dataprofileView) dataprofileView.hidden = true;
    if (galleryView) galleryView.hidden = true;
    if (promptlabView) promptlabView.hidden = true;
    if (memoryView) memoryView.hidden = true;
    if (flowView) flowView.hidden = true;
    if (review) { renderFindings(v); return; }
  }

  setText("crumb-task", v.task || "—");
  setText("phase-title", v.phaseNumber ? `Phase ${v.phaseNumber} · ${v.phaseLabel}` : "RPI session");
  setText("phase-state", v.phase ? "● running" : "");
  setText("lead", v.lead);
  const host = document.getElementById("host-pill");
  if (host) { host.textContent = `via MCP · ${v.host}`; host.hidden = !v.host; }

  setHtml("steps", v.steps.map((st, i) =>
    `<div class="step ${esc(st.status)}"><div class="ring">${st.status === "done" ? "✓" : i + 1}</div>
      <div><div class="lbl">${i + 1} · ${LABEL[st.phase] ?? esc(st.phase)}</div></div>${i < v.steps.length - 1 ? '<div class="connector"></div>' : ""}</div>`).join(""));

  setHtml("subagents", v.subagents.length
    ? v.subagents.map((a) =>
        `<div class="sub-card"><div class="av">${initials(a.name)}</div>
          <div style="flex:1"><div class="nm">${esc(a.name)}</div><div class="meta">${esc(a.role ?? "")}</div></div>
          <span class="tagidle">${esc(a.status)}</span></div>`).join("")
    : `<div class="sub-card"><div class="meta">No subagents yet.</div></div>`);

  setHtml("gate", v.validations.map(({ check, status }) => {
    const cls = status === "ok" ? "ok" : status === "running" ? "run" : status === "fail" ? "fail" : "wait";
    const mark = status === "ok" ? "✓" : status === "running" ? "●" : status === "fail" ? "✕" : "○";
    return `<span class="check ${cls}">${mark} ${esc(check)}</span>`;
  }).join("") || `<span class="check wait">○ no checks yet</span>`);

  const sel = document.getElementById("steer-select");
  if (sel) {
    setText("steer-label", v.steerMenu.label);
    const cur = sel.value;
    sel.innerHTML = v.steerMenu.options.map((o) => `<option value="${esc(o.id)}">${esc(o.title)}</option>`).join("");
    if (cur) sel.value = cur;
  }

  setHtml("directives", v.directives.map((d) =>
    `<div class="evt"><span><span class="k s2">queued</span> <span class="txt">${esc(d.kind === "note" ? d.text : d.label)} · applies at next checkpoint</span></span></div>`).join(""));

  renderScreen(v.screen);

  const stream = document.querySelector(".stream");
  if (stream) stream.innerHTML = v.log.slice(-12).map((l) =>
    `<div class="evt"><span class="ts">${new Date(l.t).toLocaleTimeString().slice(0, 5)}</span>
      <span><span class="k ${kindCls(l.kind)}">${esc(l.kind)}</span> <span class="txt">${esc(l.detail)}</span></span></div>`).join("");
}

// Agent-authored screen pane. SECURITY: the agent HTML renders inside an iframe
// whose `sandbox` attribute is set to the empty string — the maximally restrictive
// value: scripts are disabled and the frame gets a unique opaque origin. So the
// HTML is inert (no JS) and isolated from the cockpit (no cookie/token/DOM reach
// into the parent). We assign it via `srcdoc` (NOT escaped — the sandbox is the
// boundary, escaping would break legitimate markup); only the title is escaped,
// since that text lands in the cockpit's own DOM. We rebuild the iframe each time
// so a cleared screen leaves no live frame behind.
function renderScreen(screen) {
  const pane = document.getElementById("screen");
  if (!pane) return;
  if (!screen) { pane.hidden = true; pane.innerHTML = ""; return; }
  pane.hidden = false;
  const title = document.createElement("div");
  title.className = "sec";
  title.id = "screen-title";
  title.innerHTML = esc(screen.title || "Screen");
  const frame = document.createElement("div");
  frame.className = "screen-frame";
  const iframe = document.createElement("iframe");
  iframe.id = "screen-iframe";
  iframe.title = "Agent screen";
  // Empty value = no allow-scripts, no allow-same-origin. Do NOT loosen this.
  iframe.setAttribute("sandbox", "");
  iframe.srcdoc = screen.html;
  frame.appendChild(iframe);
  pane.replaceChildren(title, frame);
}

function renderDecisionFlow(v) {
  const flow = document.getElementById("decision-flow");
  if (!flow) return;
  const ds = v.decisions || [];
  if (ds.length === 0) { flow.hidden = true; flow.innerHTML = ""; return; }
  flow.hidden = false;
  const interactive = !v.hostElicits; // pane is a fallback input only when chat can't elicit
  flow.innerHTML = ds.map((d) => {
    const chips = d.kind === "choice" && d.options ? `<div class="flow-chips">${d.options.map((o) =>
      `<span class="flow-chip ${d.answer === o.id ? "picked" : ""}" ${interactive && d.status === "pending" ? `data-choice="${esc(o.id)}" data-id="${esc(d.id)}" role="button" tabindex="0"` : ""}>${esc(o.title)}</span>`).join("")}</div>` : "";
    const answer = d.kind === "text" && d.answer ? `<div class="flow-answer">${esc(d.answer)}</div>` : "";
    const pendingHint = d.status === "pending" ? `<div class="flow-chat">awaiting your answer in chat</div>` : "";
    const revise = d.status === "answered" ? `<button class="flow-revise" data-revise="${esc(d.id)}">revisit</button>` : "";
    return `<div class="flow-row ${esc(d.status)}" data-decision-id="${esc(d.id)}">
      <div class="flow-prompt">${esc(d.prompt)}</div>${answer}${chips}${pendingHint}${revise}</div>`;
  }).join("");
  // Host the flow in the active view's slot (RPI center / interview), else leave in #loop.
  const slot = document.querySelector(v.domain === "rpi" ? "#rpi-view .center .flow-slot" : v.domain === "interview" ? "#interview-view .flow-slot" : null);
  if (slot && flow.parentElement !== slot) slot.appendChild(flow);
}

// Event delegation: home interactions + decision buttons + steer "Queue directive" button.
document.addEventListener("click", (e) => {
  const iv = e.target.closest("[data-intervene]");
  if (iv) { sendMsg({ type: "intervene", action: iv.dataset.intervene, agentId: iv.dataset.agent }); return; }
  const gsize = e.target.closest(".gl-size[data-gsize]");
  if (gsize) {
    // Every size renders thumbnails, so a toggle is just a class swap plus a re-scale to the
    // new tile width (no rebuild). S/M are multi-column; L is one full-width column.
    glSizeOverride = gsize.dataset.gsize;
    const grid = document.getElementById("gl-grid");
    if (grid) grid.className = `gsize-${glSizeOverride}`;
    document.querySelectorAll(".gl-size").forEach((b) => b.classList.toggle("active", b.dataset.gsize === glSizeOverride));
    sizeGalleryThumbs();
    return;
  }
  if (e.target.closest("#gl-lb-close")) { closeLightbox(); return; }
  if (e.target.id === "gl-lightbox") { closeLightbox(); return; } // backdrop
  if (e.target.closest("[data-noexpand]")) return; // let open-in-tab work
  const glCardEl = e.target.closest(".gl-card[data-gl]");
  if (glCardEl) { openLightbox(+glCardEl.dataset.gl); return; }
  const pcHead = e.target.closest(".pc-head");
  if (pcHead && pcHead.parentElement) {
    // Toggle the case row's expanded state. We resolve the live .pc-case from a fresh
    // document scan (matching its stable data-pc id) and write its class in a single
    // assignment from plOpen, rather than mutating pcHead.parentElement / calling
    // classList.toggle: in a real browser both resolve to the same node and either
    // works, but under the happy-dom test harness the event-target node is a separate
    // object graph (mutations don't reflect) and DOMTokenList.toggle on a queried node
    // is unreliable, so a single className write from our own state is the robust path.
    // We match by getAttribute (not a built selector) so an exotic id cannot malform it.
    const k = pcHead.parentElement.getAttribute("data-pc");
    if (k != null) {
      if (plOpen.has(k)) plOpen.delete(k); else plOpen.add(k);
      const cls = plOpen.has(k) ? "pc-case open" : "pc-case";
      document.querySelectorAll(".pc-case").forEach((el) => { if (el.getAttribute("data-pc") === k) el.className = cls; });
    }
    return;
  }
  const meHead = e.target.closest(".me-head");
  if (meHead && meHead.parentElement) {
    const k = meHead.parentElement.getAttribute("data-me");
    if (k != null) {
      if (meOpen.has(k)) meOpen.delete(k); else meOpen.add(k);
      const cls = meOpen.has(k) ? "me-entry open" : "me-entry";
      document.querySelectorAll(".me-entry").forEach((el) => { if (el.getAttribute("data-me") === k) el.className = cls; });
    }
    return;
  }
  const gwBack = e.target.closest("#gw-back");
  if (gwBack) { gwFocusOverride = null; const w = lastView; if (w) renderFlow(w); return; }
  const gwNode = e.target.closest(".gw-node[data-gw]");
  if (gwNode) {
    const id = gwNode.getAttribute("data-gw");
    gwSel = id;
    if (gwNode.getAttribute("data-kind") === "workflow") gwFocusOverride = id; // drill in
    if (lastView) renderFlow(lastView);
    return;
  }
  const gwMini = e.target.closest("#gw-minimap");
  if (gwMini) {
    const r = gwMini.getBoundingClientRect();
    const s = parseFloat(gwMini.dataset.scale || "1"), pad = parseFloat(gwMini.dataset.pad || "8");
    const wx = (e.clientX - r.left - pad) / s, wy = (e.clientY - r.top - pad) / s;
    const c = document.getElementById("gw-canvas").getBoundingClientRect();
    gwCam.x = c.width / 2 - wx * gwCam.z; gwCam.y = c.height / 2 - wy * gwCam.z; gwApplyCam(); gwRenderMinimap();
    return;
  }
  const gwBg = e.target.closest("#gw-canvas");
  if (gwBg && !e.target.closest(".gw-node")) { if (gwSel !== null) { gwSel = null; if (lastView) renderFlow(lastView); } /* fallthrough to allow pan */ }
  if (e.target.closest("#to-home")) { sendMsg({ type: "navigate", screen: "home" }); return; }
  if (e.target.closest("#to-loop")) { sendMsg({ type: "navigate", screen: "loop" }); return; }
  if (e.target.closest("#help-btn")) { const w = document.getElementById("welcome"); if (w) w.hidden = false; return; }
  if (e.target.closest("#welcome-dismiss")) {
    // Clear the server flag too — open_navigator set navigatorOpen:true, and
    // render() reopens the overlay on every state push until the server flips it
    // back. The localStorage write only suppresses the first-run welcome. (A2)
    localStorage.setItem("hve-welcome-dismissed", "1");
    sendMsg({ type: "navigator", open: false });
    const w = document.getElementById("welcome"); if (w) w.hidden = true;
    return;
  }
  const tile = e.target.closest("[data-launch]");
  if (tile) { launchWorkflow(tile.dataset.launch); return; }
  const rev = e.target.closest("[data-revise]");
  if (rev) { sendMsg({ type: "revise", id: rev.dataset.revise }); return; }
  const fchoice = e.target.closest("#decision-flow [data-choice]");
  if (fchoice) { sendMsg({ type: "decide", id: fchoice.dataset.id, choiceId: fchoice.dataset.choice }); return; }
  const loc = e.target.closest(".finding-loc[data-loc]");
  if (loc) { copyLoc(loc); return; }
  const open = e.target.closest(".finding-open[data-file]");
  if (open) {
    const file = open.dataset.file;
    const line = open.dataset.line;
    sendMsg(line != null ? { type: "open", file, line: Number(line) } : { type: "open", file });
    return;
  }
  if (e.target.closest("#steer-send")) {
    const note = document.getElementById("steer-note");
    const text = (note && note.value || "").trim();
    if (text) { sendMsg({ type: "steer", directive: { kind: "note", text } }); note.value = ""; return; }
    const sel = document.getElementById("steer-select");
    if (sel && sel.value) {
      // The agent reads the rendered label (see summarizeDirective); `value` is advisory,
      // not a stable enum to switch on (preset ids carry no session meaning).
      const opt = sel.options[sel.selectedIndex];
      sendMsg({ type: "steer", directive: { kind: "approach", value: sel.value, label: opt ? opt.textContent : sel.value } });
    }
  }
});

// Keyboard access for the workflow tiles (role=button, tabindex=0): Enter/Space
// activate the focused tile the same as a click. Space is prevented so it does
// not scroll the overlay. (C1)
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    const lb = document.getElementById("gl-lightbox");
    if (lb && !lb.hidden) { closeLightbox(); return; }
  }
  if (e.key !== "Enter" && e.key !== " " && e.key !== "Spacebar") return;
  const tile = e.target.closest && e.target.closest("[data-launch]");
  if (!tile) return;
  e.preventDefault();
  launchWorkflow(tile.dataset.launch);
});

// Re-scale gallery thumbnails to their (fluid) tile width when the viewport changes.
window.addEventListener("resize", () => {
  if (glResizeRaf) return;
  glResizeRaf = requestAnimationFrame(() => { glResizeRaf = 0; sizeGalleryThumbs(); });
});

// Flow canvas camera: pan by dragging the canvas background, wheel to zoom around the
// cursor. Delegated document listeners wired once; the world transform lives in gwCam.
(function gwCameraWiring() {
  let dragging = false, lx = 0, ly = 0;
  document.addEventListener("pointerdown", (e) => {
    const canvas = e.target.closest && e.target.closest("#gw-canvas");
    if (!canvas || e.target.closest(".gw-node") || e.target.closest("#gw-minimap")) return;
    dragging = true; lx = e.clientX; ly = e.clientY; canvas.classList.add("grabbing");
  });
  document.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    gwCam.x += e.clientX - lx; gwCam.y += e.clientY - ly; lx = e.clientX; ly = e.clientY; gwApplyCam();
  });
  document.addEventListener("pointerup", () => { dragging = false; const c = document.getElementById("gw-canvas"); if (c) c.classList.remove("grabbing"); });
  document.addEventListener("wheel", (e) => {
    const canvas = e.target.closest && e.target.closest("#gw-canvas");
    if (!canvas) return;
    e.preventDefault();
    const r = canvas.getBoundingClientRect();
    const mx = e.clientX - r.left, my = e.clientY - r.top;
    const nz = Math.min(2, Math.max(0.3, gwCam.z * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
    // zoom around cursor: keep the world point under the cursor fixed
    gwCam.x = mx - (mx - gwCam.x) * (nz / gwCam.z);
    gwCam.y = my - (my - gwCam.y) * (nz / gwCam.z);
    gwCam.z = nz; gwApplyCam();
  }, { passive: false });
})();

// Launch a workflow and close the Navigator: tell the server to clear
// navigatorOpen (startLaunch already does, but the explicit frame is belt-and-
// suspenders if the launch path ever changes) and hide the overlay locally. (A2/C1)
function launchWorkflow(workflowId) {
  sendMsg({ type: "launch", workflowId });
  sendMsg({ type: "navigator", open: false });
  const w = document.getElementById("welcome"); if (w) w.hidden = true;
}

function sendMsg(m) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(m)); }
const setText = (id, t) => { const el = document.getElementById(id); if (el) el.textContent = t; };
const setHtml = (id, h) => { const el = document.getElementById(id); if (el) el.innerHTML = h; };
const initials = (n) => (n || "?").split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const kindCls = (k) => k.startsWith("directive") ? "s2" : k === "validate" ? "ok" : "";

const SEV_LABEL = { critical: "Critical", high: "High", medium: "Medium", low: "Low", info: "Info" };

function copyLoc(btn) {
  const text = btn.dataset.loc;
  try { if (navigator.clipboard) navigator.clipboard.writeText(text); } catch { /* clipboard unavailable */ }
  btn.textContent = "copied";
  setTimeout(() => { btn.textContent = text; }, 1200);
}

function renderFindings(v) {
  setText("rev-target", v.reviewTarget || "Review");
  const total = v.findingGroups.reduce((n, g) => n + g.items.length, 0);
  setText("rev-counts", total === 1 ? "1 finding" : `${total} findings`);
  const pipe = document.getElementById("rev-pipeline");
  if (pipe) {
    const subs = v.subagents || [];
    if (subs.length) {
      pipe.hidden = false;
      pipe.innerHTML = `<div class="rev-pipe-label">Live reviewers</div>` + subs.map((a) =>
        `<div class="sub-card"><div class="av">${initials(a.name)}</div>
          <div style="flex:1"><div class="nm">${esc(a.name)}</div><div class="meta">${esc(a.role ?? "")}</div></div>
          <span class="tagidle">${esc(a.status)}</span></div>`).join("");
    } else { pipe.hidden = true; pipe.innerHTML = ""; }
  }
  setHtml("findings", v.findingGroups.map((g) =>
    `<div class="sev-group sev-${esc(g.severity)}">
       <div class="sev-label">${esc(SEV_LABEL[g.severity] || g.severity)} (${g.items.length})</div>
       ${g.items.map((f) => {
         const loc = f.file ? esc(f.file) + (f.line != null ? ":" + esc(String(f.line)) : "") : "";
         return `<div class="finding">
            <div class="finding-top">
              <span class="finding-title">${esc(f.title)}</span>
              ${f.file ? `<button type="button" class="finding-loc" data-loc="${loc}" title="Copy location">${loc}</button><button type="button" class="finding-open" data-file="${esc(f.file)}"${f.line != null ? ` data-line="${esc(String(f.line))}"` : ""} title="Open in editor" aria-label="Open ${loc}">↗</button>` : ""}
            </div>
            ${f.detail ? `<div class="finding-detail">${esc(f.detail)}</div>` : ""}
          </div>`;
       }).join("")}
     </div>`).join("")
    || `<div class="meta">No findings.</div>`);
}

// Gallery card. SECURITY: the thumbnail iframe's sandbox is fixed here per kind —
// url tiles get "allow-scripts allow-same-origin allow-forms" (the framed app runs
// on its own origin, so same-origin grants it ITS origin, never the cockpit's),
// html snapshots get "" (the empty, maximally restrictive value: inert, opaque
// origin). The src/srcdoc is NOT embedded as an HTML-attribute string here; it is
// assigned as a DOM property after innerHTML in renderGallery (no attribute
// escaping). Every interpolated field passes through esc(). (gallery)
function glCard(it, i) {
  const open = it.kind === "url" && it.src ? `<a class="gl-open" href="${esc(it.src)}" target="_blank" rel="noopener" data-noexpand>open ↗</a>` : "";
  const sandbox = it.kind === "url" ? `sandbox="allow-scripts allow-same-origin allow-forms"` : `sandbox=""`;
  const cap = it.caption ? `<span class="gl-caption">${esc(it.caption)}</span>` : "";
  const thumb = it.kind === "empty"
    ? `<div class="meta">${esc(it.label)}</div>`
    : `<iframe id="gl-thumb-${i}" ${sandbox} title="${esc(it.label)}" tabindex="-1"></iframe>`;
  return `<figure class="gl-card" data-gl="${i}"><figcaption class="gl-cap"><span class="gl-label">${esc(it.label)}</span>${cap}${open}</figcaption><div class="gl-thumb">${thumb}</div></figure>`;
}

// M/L thumbnails are a fixed 1200x780 iframe scaled to the fluid tile width. CSS cannot derive a
// scale ratio from a fluid container, so set transform: scale(width/1200) here (and on resize).
// We also set an explicit pixel height on the wrapper: a thumb whose height comes from
// aspect-ratio inside a 1fr grid column collapses the row (the track can't resolve the
// aspect-derived height), so a definite height is what makes the card take its full size.
function sizeGalleryThumbs() {
  const grid = document.getElementById("gl-grid");
  if (!grid) return;
  grid.querySelectorAll(".gl-thumb").forEach((thumb) => {
    const w = thumb.clientWidth;
    if (!w) return;
    thumb.style.height = Math.round(w * 780 / 1200) + "px";
    const f = thumb.querySelector("iframe");
    if (f) f.style.transform = `scale(${w / 1200})`;
  });
}

function renderGallery(v) {
  const g = v.gallery || { title: null, size: "m", items: [] };
  glItems = g.items;
  setText("gl-title", g.title || "Gallery");
  setText("gl-count", g.items.length ? `${g.items.length} items` : "");
  const grid = document.getElementById("gl-grid");
  if (!grid) return;
  const size = glSizeOverride || g.size || "m";
  grid.className = `gsize-${size}`;
  document.querySelectorAll(".gl-size").forEach((b) => b.classList.toggle("active", b.dataset.gsize === size));
  const order = [];
  const byGroup = new Map();
  g.items.forEach((it, i) => {
    const key = it.group || "";
    if (!byGroup.has(key)) { byGroup.set(key, []); order.push(key); }
    byGroup.get(key).push({ it, i });
  });
  grid.innerHTML = order.map((key) => {
    const head = key ? `<div class="gl-group">${esc(key)}</div>` : "";
    return head + byGroup.get(key).map(({ it, i }) => glCard(it, i)).join("");
  }).join("") || `<div class="meta" style="padding:14px">No items yet.</div>`;
  // Assign each thumbnail source as a DOM property (no HTML-attribute escaping), then scale
  // each iframe to the fluid tile width.
  g.items.forEach((it, i) => {
    const f = document.getElementById(`gl-thumb-${i}`);
    if (!f) return;
    if (it.kind === "url" && it.src && isGalleryUrl(it.src)) f.setAttribute("src", it.src);
    else if (it.kind === "html") f.srcdoc = it.src || "";
  });
  sizeGalleryThumbs();
}

function openLightbox(i) {
  const it = glItems[i];
  if (!it) return;
  const lb = document.getElementById("gl-lightbox");
  const frame = document.getElementById("gl-lb-frame");
  const openLink = document.getElementById("gl-lb-open");
  setText("gl-lb-label", it.label);
  if (it.kind === "url" && it.src && isGalleryUrl(it.src)) {
    frame.removeAttribute("srcdoc"); frame.setAttribute("src", it.src);
    if (openLink) { openLink.href = it.src; openLink.hidden = false; }
  } else if (it.kind === "html") {
    frame.removeAttribute("src"); frame.srcdoc = it.src || "";
    if (openLink) openLink.hidden = true;
  } else {
    frame.removeAttribute("src"); frame.srcdoc = `<body style="margin:0;background:#1e1e1e"></body>`;
    if (openLink) openLink.hidden = true;
  }
  if (lb) lb.hidden = false;
}

function closeLightbox() {
  const lb = document.getElementById("gl-lightbox");
  const frame = document.getElementById("gl-lb-frame");
  if (frame) { frame.removeAttribute("src"); frame.removeAttribute("srcdoc"); }
  if (lb) lb.hidden = true;
}

function renderBoard(v) {
  const b = v.board || { columns: [] };
  setText("board-target", b.target || "Backlog");
  const n = b.count || 0;
  setText("board-count", n === 1 ? "1 item" : n + " items");
  const action = document.getElementById("board-action");
  if (action) { action.textContent = b.action || ""; action.hidden = !b.action; }
  setHtml("board", (b.columns || []).map((c) =>
    `<div class="board-col" role="group" aria-label="${esc(c.name)}">
       <div class="col-head"><span>${esc(c.name)}</span><span class="col-count">${c.items.length}</span></div>
       ${c.items.map((it) =>
         `<div class="bcard"${it.depth ? ` style="margin-left:${it.depth * 16}px"` : ""}>
            <div class="bcard-id">${esc(it.id)}</div>
            ${it.parentRef ? `<div class="bcard-parent">↳ under ${esc(it.parentRef)}</div>` : ""}
            <div class="bcard-title">${esc(it.title)}</div>
            ${(it.kind || it.tier) ? `<div class="bcard-chips">${it.kind ? `<span class="chip-kind">${esc(it.kind)}</span>` : ""}${it.tier ? `<span class="chip-tier">${esc(it.tier)}</span>` : ""}</div>` : ""}
          </div>`).join("") || `<div class="col-empty"></div>`}
     </div>`).join(""));
}

function renderDataProfile(v) {
  const dp = v.dataProfile || { dataset: null, columns: [] };
  const ds = dp.dataset;
  setText("dp-name", ds ? ds.name : "Dataset");
  const meta = ds ? [ds.rows != null ? `${ds.rows} rows` : null, ds.cols != null ? `${ds.cols} cols` : null, ds.source].filter(Boolean).join(" · ") : "";
  setText("dp-meta", meta);
  const head = `<thead><tr><th>Column</th><th>Type</th><th>Null %</th><th>Distinct</th><th>Stat</th><th></th></tr></thead>`;
  const body = (dp.columns || []).map((c) =>
    `<tr><td class="dp-col">${esc(c.name)}</td><td class="dp-type">${esc(c.dtype)}</td>
       <td>${c.nullPct != null ? esc(String(c.nullPct)) + "%" : ""}</td>
       <td>${c.distinct != null ? esc(String(c.distinct)) : ""}</td>
       <td class="dp-stat">${c.stat ? esc(c.stat) : ""}</td>
       <td>${c.quality ? `<span class="dp-q dp-q-${esc(c.quality)}" title="${esc(c.quality)}"></span>` : ""}</td></tr>`).join("")
    || `<tr><td colspan="6" class="meta">No columns profiled yet.</td></tr>`;
  setHtml("dp-table", head + `<tbody>${body}</tbody>`);
}

function renderPromptlab(v) {
  const p = v.promptlab || { name: null, round: 1, prompt: null, summary: { pass: 0, warn: 0, fail: 0, pending: 0, running: 0, total: 0 }, cases: [] };
  // Reconcile plOpen: drop any case id that no longer exists in this session's cases.
  const currentIds = new Set((p.cases || []).map(c => c.id));
  for (const id of plOpen) if (!currentIds.has(id)) plOpen.delete(id);
  setText("pl-name", `${p.name || "Prompt workbench"}  ·  Round ${p.round}`);
  const sm = p.summary;
  const chip = (n, cls, label) => n > 0 ? `<span class="pl-chip ${cls}">${n} ${label}</span>` : "";
  setHtml("pl-summary", sm.total
    ? chip(sm.pass, "pl-c-pass", "pass") + chip(sm.warn, "pl-c-warn", "warn") + chip(sm.fail, "pl-c-fail", "fail")
      + chip(sm.running, "", "running") + chip(sm.pending, "", "pending")
    : "");
  setHtml("pl-cases", (p.cases || []).map((c) => {
    const preview = c.output ? esc(c.output.replace(/\s+/g, " ").slice(0, 120)) : "<span class=\"meta\">awaiting output…</span>";
    const body = `<div class="pc-body"><div class="pc-out">${c.output ? esc(c.output) : "No output yet."}</div>${c.note ? `<div class="pc-note">${esc(c.note)}</div>` : ""}</div>`;
    return `<div class="pc-case${plOpen.has(c.id) ? " open" : ""}" data-pc="${esc(c.id)}"><div class="pc-head"><span class="pc-scenario">${esc(c.scenario)}</span><span class="pc-preview">${preview}</span><span class="pc-verdict pc-v-${esc(c.verdict)}">${esc(c.verdict)}</span></div>${body}</div>`;
  }).join("") || `<div class="meta" style="padding:8px">No cases yet.</div>`);
  const pre = document.getElementById("pl-prompt");
  if (pre) pre.textContent = p.prompt || "";
}

function renderMemory(v) {
  const m = v.memory || { title: null, counts: { recalled: 0, added: 0, updated: 0, total: 0 }, entries: [], handoffs: [] };
  setText("me-title", m.title || "Memory");
  const ct = m.counts;
  const chip = (n, cls, label) => n > 0 ? `<span class="pl-chip ${cls}">${n} ${label}</span>` : "";
  setHtml("me-counts", ct.total
    ? chip(ct.recalled, "me-c-recalled", "recalled") + chip(ct.added, "me-c-added", "added") + chip(ct.updated, "me-c-updated", "updated")
    : "");
  // Reconcile expand state: drop ids no longer present so nothing carries across sessions.
  const ids = new Set((m.entries || []).map((e) => e.id));
  for (const id of meOpen) if (!ids.has(id)) meOpen.delete(id);
  // Group entries by category in first-seen order.
  const order = [];
  const byCat = new Map();
  (m.entries || []).forEach((e) => {
    if (!byCat.has(e.category)) { byCat.set(e.category, []); order.push(e.category); }
    byCat.get(e.category).push(e);
  });
  setHtml("me-entries", order.map((cat) => {
    const rows = byCat.get(cat).map((e) => {
      const name = e.title ? esc(e.title) : esc(e.content.replace(/\s+/g, " ").slice(0, 60));
      const preview = esc(e.content.replace(/\s+/g, " ").slice(0, 120));
      return `<div class="me-entry${meOpen.has(e.id) ? " open" : ""}" data-me="${esc(e.id)}"><div class="me-head"><span class="me-name">${name}</span><span class="me-preview">${preview}</span><span class="me-tag me-t-${esc(e.tag)}">${esc(e.tag)}</span></div><div class="me-entry-body">${esc(e.content)}</div></div>`;
    }).join("");
    return `<div class="me-group"><div class="me-group-head">${esc(cat)}</div>${rows}</div>`;
  }).join("") || `<div class="meta" style="padding:8px">No memory yet.</div>`);
  setHtml("me-handoffs", (m.handoffs || []).map((h) =>
    `<div class="mh-card"><div class="mh-from">${esc(h.from)}</div><div class="mh-summary">${esc(h.summary)}</div><span class="mh-action mh-a-${esc(h.action)}">${esc(h.action)}</span></div>`).join("")
    || `<div class="meta">No handoffs.</div>`);
}

function gwActiveFocus(v) {
  // server narration wins when it changes; otherwise the local drill override holds.
  if (v.flow.focus !== gwServerFocus) { gwServerFocus = v.flow.focus; gwFocusOverride = undefined; }
  return gwFocusOverride !== undefined ? gwFocusOverride : v.flow.focus;
}

function gwApplyCam() {
  const world = document.getElementById("gw-world");
  if (world) world.style.transform = `translate(${gwCam.x}px, ${gwCam.y}px) scale(${gwCam.z})`;
}

// Fit the laid-out graph's bounding box into the live canvas, centered with padding and
// zoom clamped to the same [0.3, 2] range the wheel uses. Called once per node-set/scope
// change (see gwFitSig) so a live-run status update preserves the user's pan/zoom, but a
// fresh pipeline or a drill-in re-frames. No-op when the canvas has no measured size yet
// (e.g. the happy-dom test harness), leaving the default camera untouched.
function gwFitToView(pos) {
  const ids = Object.keys(pos);
  const canvas = document.getElementById("gw-canvas");
  if (!ids.length || !canvas) return;
  const r = canvas.getBoundingClientRect();
  if (!(r.width > 0 && r.height > 0)) return;
  const NODE_W = 180, NODE_H = 76, PAD = 48;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const id of ids) {
    const p = pos[id];
    minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
    maxX = Math.max(maxX, p.x + NODE_W); maxY = Math.max(maxY, p.y + NODE_H);
  }
  const gw = Math.max(1, maxX - minX), gh = Math.max(1, maxY - minY);
  const z = Math.min(2, Math.max(0.3, Math.min((r.width - PAD * 2) / gw, (r.height - PAD * 2) / gh)));
  gwCam.z = z;
  gwCam.x = (r.width - gw * z) / 2 - minX * z;
  gwCam.y = (r.height - gh * z) / 2 - minY * z;
}

function renderFlow(v) {
  const f = v.flow || { title: null, focus: null, nodes: [], edges: [] };
  const focus = gwActiveFocus(v);
  setText("gw-title", focus ? `${f.title || "Flow"}  ·  ${focus}` : (f.title || "Flow"));
  const back = document.getElementById("gw-back");
  if (back) back.hidden = !focus;
  const scope = focus || "orchestration";
  const nodes = f.nodes.filter((n) => n.scope === scope);
  const edges = f.edges.filter((e) => e.scope === scope);
  // legend
  setHtml("gw-legend", ["workflow", "trigger", "guard", "agent", "output", "mcp"].map((k) =>
    `<div class="gw-leg"><span class="gw-dot gw-k-${k}" style="background:currentColor"></span>${k}</div>`).join(""));
  // layout + node cards
  const pos = computeFlowLayout(nodes, edges);
  const world = document.getElementById("gw-world");
  if (!world) return;
  // SVG edge layer (built first so edges sit under the node cards)
  const NODE_W = 180, NODE_H = 64;
  const anchor = (id, side) => {
    const p = pos[id] || { x: 0, y: 0 };
    return { x: p.x + (side === "out" ? NODE_W : 0), y: p.y + NODE_H / 2 };
  };
  // bounding box for the svg canvas size
  let maxX = 0, maxY = 0;
  for (const id in pos) { maxX = Math.max(maxX, pos[id].x + NODE_W); maxY = Math.max(maxY, pos[id].y + NODE_H); }
  const edgesSvg = edges.map((e) => {
    const a = anchor(e.from, "out"), b = anchor(e.to, "in");
    const k = Math.max(40, Math.abs(b.x - a.x) * 0.4);
    const d = `M ${a.x} ${a.y} C ${a.x + k} ${a.y}, ${b.x - k} ${b.y}, ${b.x} ${b.y}`;
    const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - 6 };
    return `<path class="gw-edge gw-e-${esc(e.kind)}${e.status === "active" ? " gw-active" : ""}" d="${d}" marker-end="url(#gw-arrow)"></path>`
      + (e.label ? `<text class="gw-elabel" x="${mid.x}" y="${mid.y}" text-anchor="middle">${esc(e.label)}</text>` : "");
  }).join("");
  const svg = `<svg id="gw-edges" width="${maxX + 40}" height="${maxY + 40}">
    <defs><marker id="gw-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--stroke-2, #4A4A4A)"></path></marker></defs>${edgesSvg}</svg>`;
  const nodesHtml = nodes.map((n) => {
    const p = pos[n.id] || { x: 0, y: 0 };
    return `<figure class="gw-node gw-k-${esc(n.kind)} gw-s-${esc(n.status)}${n.id === gwSel ? " gw-sel" : ""}" data-gw="${esc(n.id)}" data-kind="${esc(n.kind)}" style="left:${p.x}px;top:${p.y}px">
      <span class="gw-port gw-in"></span>
      <figcaption class="gw-head"><span class="gw-glyph">${GW_GLYPH[n.kind] || "•"}</span>${esc(n.label)}</figcaption>
      ${n.sub ? `<div class="gw-body">${esc(n.sub)}</div>` : ""}
      <span class="gw-port gw-out"></span>
    </figure>`;
  }).join("");
  world.innerHTML = svg + nodesHtml;
  // Re-fit the camera only when the active scope or node set changes, so live-run status
  // updates (same nodes) keep the user's current pan/zoom.
  const fitSig = scope + "::" + nodes.map((n) => n.id).join("|");
  if (fitSig !== gwFitSig) { gwFitSig = fitSig; gwFitToView(pos); }
  gwApplyCam();
  // gwNodes is the full flow node set (every scope) so the inspector can resolve a
  // selection even after a drill-in changes the visible scope to the selected
  // workflow's (possibly empty) anatomy. gwPos holds only the active-scope layout,
  // which is what the minimap renders.
  gwPos = pos; gwNodes = f.nodes;
  gwRenderInspector();
  gwRenderMinimap();
}

function gwRenderInspector() {
  const insp = document.getElementById("gw-inspector");
  if (!insp) return;
  const n = gwNodes.find((x) => x.id === gwSel);
  if (!n) { insp.hidden = true; insp.innerHTML = ""; return; }
  insp.hidden = false;
  insp.innerHTML = `<div class="gw-i-label">${esc(n.label)}</div>
    <div class="gw-i-row"><span class="gw-i-k">kind</span><br>${esc(n.kind)}</div>
    <div class="gw-i-row"><span class="gw-i-k">status</span><br>${esc(n.status)}</div>
    ${n.sub ? `<div class="gw-i-row"><span class="gw-i-k">detail</span><br>${esc(n.sub)}</div>` : ""}`;
}

function gwRenderMinimap() {
  const mm = document.getElementById("gw-minimap");
  const canvas = document.getElementById("gw-canvas");
  if (!mm || !canvas) return;
  const ids = Object.keys(gwPos);
  if (ids.length === 0) { mm.hidden = true; return; }
  mm.hidden = false;
  const NODE_W = 180, NODE_H = 64;
  let maxX = 0, maxY = 0;
  for (const id of ids) { maxX = Math.max(maxX, gwPos[id].x + NODE_W); maxY = Math.max(maxY, gwPos[id].y + NODE_H); }
  const pad = 8, mw = 160 - pad * 2, mh = 110 - pad * 2;
  const s = Math.min(mw / (maxX || 1), mh / (maxY || 1));
  const dots = ids.map((id) => `<span class="gw-mm-node" style="left:${pad + gwPos[id].x * s}px;top:${pad + gwPos[id].y * s}px"></span>`).join("");
  // viewport rect: the canvas-visible world region under the current camera
  const r = canvas.getBoundingClientRect();
  const vx = -gwCam.x / gwCam.z, vy = -gwCam.y / gwCam.z;
  const vw = r.width / gwCam.z, vh = r.height / gwCam.z;
  const view = `<span class="gw-mm-view" style="left:${pad + vx * s}px;top:${pad + vy * s}px;width:${vw * s}px;height:${vh * s}px"></span>`;
  mm.innerHTML = dots + view;
  mm.dataset.scale = String(s); mm.dataset.pad = String(pad);
}

function renderTeam(v) {
  const t = v.team || { orchestrator: null, count: 0, columns: [] };
  setText("team-orch", t.orchestrator || "Orchestrator");
  const n = t.count || 0;
  setText("team-count", n === 1 ? "1 agent" : n + " agents");
  setHtml("team-board", (t.columns || []).map((c) =>
    `<div class="board-col">
       <div class="col-head"><span>${esc(c.label)}</span><span class="col-count">${c.agents.length}</span></div>
       ${c.agents.map((a) =>
         `<div class="agent-card">
            <div class="agent-name">${esc(a.name)}</div>
            ${a.role ? `<div class="agent-role">${esc(a.role)}</div>` : ""}
            ${a.action ? `<div class="agent-action">${esc(a.action)}</div>` : ""}
            <span class="agent-status ${esc(c.status)}">${esc(c.label)}</span>
            <div class="agent-actions">
              <button class="mini-btn" data-intervene="pause" data-agent="${esc(a.id)}">Pause</button>
              <button class="mini-btn" data-intervene="swap" data-agent="${esc(a.id)}">Swap</button>
            </div>
          </div>`).join("")}
     </div>`).join(""));
}

// Codebase map (CSS-3D). Build-once / update-in-place: rebuild the .cn node
// elements only when the node-id signature changes (a new map); on focus/touch
// re-renders only the state classes and the camera transform change, so the
// CSS transition glides the camera instead of snapping. (codemap)
function renderCodemap(v) {
  const cm = v.codemap || { nodes: [], focus: null, touches: {} };
  const world = document.getElementById("cm-world");
  if (!world) return;
  const sig = cm.nodes.map((n) => n.id).join("|");
  if (sig !== cmSig) {
    // rebuild once per node set
    cmSig = sig;
    const groups = [];
    cm.nodes.forEach((n) => { if (!groups.includes(n.group)) groups.push(n.group); });
    const perRow = Math.max(1, Math.ceil(Math.sqrt(groups.length)));
    const counters = {};
    world.innerHTML = cm.nodes.map((n) => {
      const gi = groups.indexOf(n.group);
      const k = (counters[n.group] = (counters[n.group] || 0) + 1) - 1;
      const cgx = gi % perRow, cgz = Math.floor(gi / perRow);
      const clusterX = (cgx - (perRow - 1) / 2) * 430;
      const clusterZ = cgz * 360;
      const col = k % 2, row = Math.floor(k / 2);
      const tx = Math.round(clusterX + (col - 0.5) * 150);
      const ty = Math.round(row * 78 - 30);
      const tz = Math.round(clusterZ);
      const name = n.path.split("/").pop();
      return `<div class="cn" data-node="${esc(n.id)}" style="--tx:${tx}px;--ty:${ty}px;--tz:${tz}px">
        <div class="cn-name">${esc(name)}</div><div class="cn-path">${esc(n.group)}</div></div>`;
    }).join("");
  }
  // update states + camera every time (no rebuild)
  const cards = world.querySelectorAll(".cn");
  let fx = 0, fy = 0, fz = 0, haveFocus = false;
  cards.forEach((el) => {
    const id = el.dataset.node;
    el.classList.toggle("focused", id === cm.focus);
    const t = cm.touches[id];
    el.classList.toggle("read", t === "read");
    el.classList.toggle("edited", t === "edit");
    if (id === cm.focus) {
      fx = parseFloat(el.style.getPropertyValue("--tx")) || 0;
      fy = parseFloat(el.style.getPropertyValue("--ty")) || 0;
      fz = parseFloat(el.style.getPropertyValue("--tz")) || 0;
      haveFocus = true;
    }
  });
  world.style.transform = haveFocus
    ? `translate3d(${-fx}px, ${-fy}px, ${-fz + 150}px)`
    : `translate3d(0,0,-260px)`;
}

function renderInterview(v) {
  setText("iv-doctype", v.docType ? `Interview: ${v.docType}` : "Interview");
  const steps = document.getElementById("iv-steps");
  if (steps) {
    const ist = v.interviewSteps;
    if (ist && ist.steps && ist.steps.length) {
      steps.hidden = false;
      const lead = ist.label ? `<span class="iv-steps-label">${esc(ist.label)}</span>` : "";
      steps.innerHTML = lead + ist.steps.map((st) => {
        const prog = st.progress;
        const extra = prog
          ? `<span class="iv-step-prog">${esc(String(prog.done))}/${esc(String(prog.total))}</span><span class="iv-step-bar"><i style="width:${prog.total > 0 ? Math.round(100 * prog.done / prog.total) : 0}%"></i></span>`
          : "";
        return `<span class="iv-step iv-step-${esc(st.status)}"><span class="iv-step-dot">${st.status === "done" ? "✓" : ""}</span>${esc(st.name)}${extra}</span>`;
      }).join("");
    } else { steps.hidden = true; steps.innerHTML = ""; }
  }
  const doc = document.getElementById("iv-doc");
  if (doc) doc.srcdoc = v.screen?.html ?? "";
}

// Pure layered layout for the flow canvas: longest-path layering on the DAG formed by
// dropping back edges (so a feedback handoff such as needs-revision -> implement does not
// change forward layering or loop), first-seen order within a layer. Returns world px.
function computeFlowLayout(nodes, edges) {
  const COL_W = 240, ROW_H = 120;
  const ids = nodes.map((n) => n.id);
  const idx = new Map(ids.map((id, i) => [id, i]));
  const idSet = new Set(ids);
  const adj = new Map(ids.map((id) => [id, []]));
  for (const e of edges) if (idSet.has(e.from) && idSet.has(e.to) && e.from !== e.to) adj.get(e.from).push(e.to);
  // 1. classify back edges via DFS gray-coloring
  const color = new Map(); // 1 = on stack, 2 = done
  const back = new Set();
  const stack = [];
  for (const root of ids) {
    if (color.get(root)) continue;
    stack.push([root, 0]);
    while (stack.length) {
      const frame = stack[stack.length - 1];
      const [u, i] = frame;
      if (i === 0) color.set(u, 1);
      const kids = adj.get(u);
      if (i < kids.length) {
        frame[1]++;
        const v = kids[i];
        const c = color.get(v);
        if (c === 1) back.add(u + ">" + v);
        else if (!c) stack.push([v, 0]);
      } else {
        color.set(u, 2);
        stack.pop();
      }
    }
  }
  // 2. DAG (non-back edges) + indegree
  const dag = new Map(ids.map((id) => [id, []]));
  const indeg = new Map(ids.map((id) => [id, 0]));
  for (const u of ids) for (const v of adj.get(u)) {
    if (back.has(u + ">" + v)) continue;
    dag.get(u).push(v); indeg.set(v, indeg.get(v) + 1);
  }
  // 3. Kahn topo + longest-path layer
  const layer = new Map(ids.map((id) => [id, 0]));
  const din = new Map(indeg);
  let q = ids.filter((id) => din.get(id) === 0).sort((a, b) => idx.get(a) - idx.get(b));
  while (q.length) {
    const u = q.shift();
    for (const v of dag.get(u)) {
      if (layer.get(u) + 1 > layer.get(v)) layer.set(v, layer.get(u) + 1);
      din.set(v, din.get(v) - 1);
      if (din.get(v) === 0) q.push(v);
    }
  }
  // 4. position: column = layer, row = first-seen order within layer
  const byLayer = new Map();
  for (const id of ids) {
    const L = layer.get(id);
    if (!byLayer.has(L)) byLayer.set(L, []);
    byLayer.get(L).push(id);
  }
  const pos = {};
  for (const [L, members] of byLayer) {
    members.sort((a, b) => idx.get(a) - idx.get(b));
    members.forEach((id, i) => { pos[id] = { x: L * COL_W, y: i * ROW_H }; });
  }
  return pos;
}

connect();

if (typeof window !== "undefined") window.render = render;
if (typeof window !== "undefined") window.computeFlowLayout = computeFlowLayout;
