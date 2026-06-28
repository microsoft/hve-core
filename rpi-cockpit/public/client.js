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
  if (rpiView && findingsView) {
    if (v.domain === "codemap") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = false;
      if (dataprofileView) dataprofileView.hidden = true;
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
      renderDataProfile(v);
      return;
    }
    if (v.domain === "interview") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = false;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
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
              ${f.file ? `<button type="button" class="finding-loc" data-loc="${loc}" title="Copy location">${loc}</button>` : ""}
            </div>
            ${f.detail ? `<div class="finding-detail">${esc(f.detail)}</div>` : ""}
          </div>`;
       }).join("")}
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
      steps.innerHTML = lead + ist.steps.map((st) =>
        `<span class="iv-step iv-step-${esc(st.status)}"><span class="iv-step-dot">${st.status === "done" ? "✓" : ""}</span>${esc(st.name)}</span>`).join("");
    } else { steps.hidden = true; steps.innerHTML = ""; }
  }
  const doc = document.getElementById("iv-doc");
  if (doc) doc.srcdoc = v.screen?.html ?? "";
}

connect();

if (typeof window !== "undefined") window.render = render;
