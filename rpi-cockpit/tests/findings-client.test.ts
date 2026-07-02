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

function reviewVm() {
  let s = applyBeat(initialState(), { type: "review.start", target: "PR 9" }, 1);
  s = applyBeat(s, { type: "finding.add", severity: "critical", title: "RCE", file: "a.ts", line: 4, detail: "bad" }, 2);
  s = applyBeat(s, { type: "finding.add", severity: "low", title: "nit" }, 3);
  return toViewModel(s);
}

function reviewVmWithPipeline() {
  let s = applyBeat(initialState(), { type: "review.start", target: "Security audit" }, 1);
  s = applyBeat(s, { type: "subagent.start", name: "Codebase Profiler", role: "profiler" }, 2);
  s = applyBeat(s, { type: "subagent.start", name: "Skill Assessor", role: "auth skill" }, 3);
  s = applyBeat(s, { type: "finding.add", severity: "high", title: "Missing authz", file: "api.ts", line: 12, detail: "x" }, 4);
  return toViewModel(s);
}

describe("findings client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the findings view and hides the RPI view on a review domain", () => {
    (win as any).render(reviewVm());
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
  });

  it("renders one group per non-empty severity with the finding titles", () => {
    (win as any).render(reviewVm());
    const groups = win.document.querySelectorAll("#findings .sev-group");
    expect(groups.length).toBe(2);
    expect(win.document.querySelector("#findings .finding-title")!.textContent).toBe("RCE");
  });

  it("shows the RPI view on a non-review loop", () => {
    const s = applyBeat(initialState(), { type: "session.begin", task: "t", host: "h" }, 1);
    (win as any).render(toViewModel(s));
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("findings-view") as any).hidden).toBe(true);
  });

  it("renders the live-reviewers pipeline strip from subagents, hidden when none", () => {
    (win as any).render(reviewVmWithPipeline());
    const pipe = win.document.getElementById("rev-pipeline") as any;
    expect(pipe.hidden).toBe(false);
    expect(pipe.querySelectorAll(".sub-card").length).toBe(2);
    (win as any).render(reviewVm()); // reviewVm() has no subagents
    expect((win.document.getElementById("rev-pipeline") as any).hidden).toBe(true);
  });

  it("emits the finding location as a button carrying path:line, and copying flips its label", () => {
    (win as any).render(reviewVmWithPipeline());
    const loc = win.document.querySelector("#findings .finding-loc") as any;
    expect(loc.tagName).toBe("BUTTON");
    expect(loc.getAttribute("data-loc")).toBe("api.ts:12");
    loc.click();
    expect(loc.textContent).toBe("copied");
  });

  it("omits the location button for a finding with no file", () => {
    (win as any).render(reviewVm()); // the "nit" low finding has no file
    const groups = [...win.document.querySelectorAll("#findings .sev-group")];
    const lowGroup = groups.find((g) => g.textContent!.includes("nit"))!;
    expect(lowGroup.querySelector(".finding-loc")).toBeNull();
  });

  it("renders an open button carrying the file and line", () => {
    (win as any).render(reviewVmWithPipeline()); // its high finding is api.ts:12
    const open = win.document.querySelector("#findings .finding-open") as any;
    expect(open.tagName).toBe("BUTTON");
    expect(open.getAttribute("data-file")).toBe("api.ts");
    expect(open.getAttribute("data-line")).toBe("12");
  });
});
