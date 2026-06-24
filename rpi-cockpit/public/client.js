// rpi-cockpit/public/client.js
// Thin painter: every value comes from the server's view model (src/render.ts).
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };

let ws = null;
let backoff = 500;

function connect() {
  setConn("connecting");
  ws = new WebSocket(`ws://${location.host}`);
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

function render(v) {
  setText("crumb-task", v.task || "—");
  setText("phase-title", v.phaseNumber ? `Phase ${v.phaseNumber} · ${v.phaseLabel}` : "RPI session");
  setText("phase-state", v.phase ? "● running" : "");
  setText("lead", v.lead);
  const host = document.getElementById("host-pill");
  if (host) { host.textContent = `via MCP · ${v.host}`; host.hidden = !v.host; }

  setHtml("steps", v.steps.map((st, i) =>
    `<div class="step ${st.status}"><div class="ring">${st.status === "done" ? "✓" : i + 1}</div>
      <div><div class="lbl">${i + 1} · ${LABEL[st.phase]}</div></div></div>`).join(""));

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

  setHtml("decision", v.decision ? decisionHtml(v.decision) : "");

  const stream = document.querySelector(".stream");
  if (stream) stream.innerHTML = v.log.slice(-12).map((l) =>
    `<div class="evt"><span class="ts">${new Date(l.t).toLocaleTimeString().slice(0, 5)}</span>
      <span><span class="k ${kindCls(l.kind)}">${esc(l.kind)}</span> <span class="txt">${esc(l.detail)}</span></span></div>`).join("");
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

// Event delegation: decision buttons + the steer "Queue directive" button.
document.addEventListener("click", (e) => {
  const choice = e.target.closest("#decision [data-choice]");
  if (choice) { sendMsg({ type: "decide", id: choice.dataset.id, choiceId: choice.dataset.choice }); return; }
  if (e.target.closest("#steer-send")) {
    const note = document.getElementById("steer-note");
    const text = (note && note.value || "").trim();
    if (text) { sendMsg({ type: "steer", directive: { kind: "note", text } }); note.value = ""; return; }
    const sel = document.getElementById("steer-select");
    if (sel && sel.value) {
      const opt = sel.options[sel.selectedIndex];
      sendMsg({ type: "steer", directive: { kind: "approach", value: sel.value, label: opt ? opt.textContent : sel.value } });
    }
  }
});

function sendMsg(m) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(m)); }
const setText = (id, t) => { const el = document.getElementById(id); if (el) el.textContent = t; };
const setHtml = (id, h) => { const el = document.getElementById(id); if (el) el.innerHTML = h; };
const initials = (n) => n.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const kindCls = (k) => k.indexOf("directive") === 0 ? "s2" : k === "validate" ? "ok" : "";

connect();
