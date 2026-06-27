// rpi-cockpit/public/client.js
// Thin painter: every value comes from the server's view model (src/render.ts).
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const WF_ICON = { build: "</>", review: "✓", plan: "▦", docs: "▤", data: "▥", coach: "✷" };

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

let ws = null;
let backoff = 500;

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
  renderContext(v);
  renderNavTiles(v);
  // present_options is cross-cutting: paint the decision card regardless of domain
  // (it lives outside every view section), so a decision raised during a review,
  // interview, or backlog still shows a card in the pane. (A1)
  setHtml("decision", v.decision ? decisionHtml(v.decision) : "");
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
  if (rpiView && findingsView) {
    if (v.domain === "backlog") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = false;
      renderBoard(v);
      return;
    }
    if (v.domain === "interview") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = false;
      if (backlogView) backlogView.hidden = true;
      renderInterview(v);
      return;
    }
    const review = v.domain === "review";
    rpiView.hidden = review;
    findingsView.hidden = !review;
    if (interviewView) interviewView.hidden = true;
    if (backlogView) backlogView.hidden = true;
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

function decisionHtml(d) {
  const opts = d.options.map((o) =>
    `<div class="opt ${o.recommended ? "rec" : ""}">${o.recommended ? '<span class="badge">RECOMMENDED</span>' : ""}
      <h4>${esc(o.title)}</h4><p>${esc(o.detail ?? "")}</p></div>`).join("");
  const btns = d.options.map((o) =>
    `<button class="btn ${o.recommended ? "primary" : ""}" data-id="${esc(d.id)}" data-choice="${esc(o.id)}">Choose ${esc(o.title)}</button>`).join("");
  return `<div class="decide"><div class="decide-head"><span class="t">${esc(d.prompt)}</span>
    <span class="s">present_options · awaiting your pick</span></div>
    <div class="decide-body"><div class="opts">${opts}</div><div class="btns">${btns}</div></div></div>`;
}

// Event delegation: home interactions + decision buttons + steer "Queue directive" button.
document.addEventListener("click", (e) => {
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
  const choice = e.target.closest("#decision [data-choice]");
  if (choice) { sendMsg({ type: "decide", id: choice.dataset.id, choiceId: choice.dataset.choice }); return; }
  const ivSend = e.target.closest("#iv-send");
  if (ivSend) {
    const input = document.getElementById("iv-input");
    const txt = (input && input.value || "").trim();
    if (txt) sendMsg({ type: "answer", id: ivSend.dataset.answer, text: txt });
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
  if (e.key !== "Enter" && e.key !== " " && e.key !== "Spacebar") return;
  const tile = e.target.closest && e.target.closest("[data-launch]");
  if (!tile) return;
  e.preventDefault();
  launchWorkflow(tile.dataset.launch);
});

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

function renderFindings(v) {
  setText("rev-target", v.reviewTarget || "Review");
  const total = v.findingGroups.reduce((n, g) => n + g.items.length, 0);
  setText("rev-counts", total === 1 ? "1 finding" : `${total} findings`);
  setHtml("findings", v.findingGroups.map((g) =>
    `<div class="sev-group sev-${esc(g.severity)}">
       <div class="sev-label">${esc(SEV_LABEL[g.severity] || g.severity)} (${g.items.length})</div>
       ${g.items.map((f) =>
         `<div class="finding">
            <div class="finding-top">
              <span class="finding-title">${esc(f.title)}</span>
              ${f.file ? `<span class="finding-loc">${esc(f.file)}${f.line != null ? ":" + esc(String(f.line)) : ""}</span>` : ""}
            </div>
            ${f.detail ? `<div class="finding-detail">${esc(f.detail)}</div>` : ""}
          </div>`).join("")}
     </div>`).join("")
    || `<div class="meta">No findings.</div>`);
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
         `<div class="bcard">
            <div class="bcard-id">${esc(it.id)}</div>
            <div class="bcard-title">${esc(it.title)}</div>
            ${(it.kind || it.tier) ? `<div class="bcard-chips">${it.kind ? `<span class="chip-kind">${esc(it.kind)}</span>` : ""}${it.tier ? `<span class="chip-tier">${esc(it.tier)}</span>` : ""}</div>` : ""}
          </div>`).join("") || `<div class="col-empty"></div>`}
     </div>`).join(""));
}

function renderInterview(v) {
  setText("iv-doctype", v.docType ? `Interview: ${v.docType}` : "Interview");
  if (v.pendingQuestion) {
    setHtml("iv-question",
      `<div class="iv-prompt">${esc(v.pendingQuestion.prompt)}</div>
       <textarea id="iv-input" class="iv-input" placeholder="Type your answer"></textarea>
       <button id="iv-send" class="iv-send" data-answer="${esc(v.pendingQuestion.id)}">Send answer</button>`);
  } else {
    setHtml("iv-question", `<div class="iv-empty">Waiting for the next question.</div>`);
  }
  const doc = document.getElementById("iv-doc");
  if (doc) doc.srcdoc = v.screen?.html ?? "";
}

connect();

if (typeof window !== "undefined") window.render = render;
