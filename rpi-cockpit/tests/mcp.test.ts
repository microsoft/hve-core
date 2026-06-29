// rpi-cockpit/tests/mcp.test.ts
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { ElicitRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Bridge } from "../src/bridge.js";
import { buildMcpServer } from "../src/mcp.js";
import { WORKFLOWS } from "../src/catalog.js";

describe("mcp face", () => {
  it("phase_enter tool advances the bridge", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "phase_enter", arguments: { phase: "review" } });
    expect(bridge.state.phase).toBe("review");
  });

  it("registers the steering and screen tools and lists thirty-three total", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name).sort();
    expect(names).toContain("offer_approaches");
    expect(names).toContain("check_directives");
    expect(names).toContain("show_screen");
    expect(names).toContain("clear_screen");
    expect(names).toContain("present_workflows");
    expect(names).toContain("open_navigator");
    expect(names).toContain("set_context");
    expect(names).toContain("set_app_frame");
    expect(names).toContain("team_start");
    expect(names).toContain("add_agent");
    expect(names).toContain("update_agent");
    expect(names).toContain("remove_agent");
    expect(names).toContain("codemap_set");
    expect(names).toContain("codemap_focus");
    expect(names).toContain("codemap_touch");
    expect(names).toContain("dataset_profile");
    expect(names).toContain("add_column");
    expect(names).toContain("set_steps");
    expect(names).toContain("gallery_open");
    expect(names).toContain("gallery_add");
    expect(names).toContain("gallery_clear");
    expect(tools).toHaveLength(38);
    expect(names).toContain("promptlab_start");
    expect(names).toContain("add_case");

    await client.callTool({ name: "offer_approaches", arguments: { label: "Pick", options: [{ id: "a", title: "A" }] } });
    expect(bridge.state.steerMenu).toMatchObject({ label: "Pick" });
  });

  it("open_navigator opens the navigator pop-up in the bridge state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    expect(bridge.state.navigatorOpen).toBe(false);
    await client.callTool({ name: "open_navigator", arguments: {} });
    expect(bridge.state.navigatorOpen).toBe(true);
  });

  it("show_screen and clear_screen tools drive the bridge screen state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "show_screen", arguments: { html: "<p>hi</p>", title: "Mockup" } });
    expect(bridge.state.screen).toEqual({ html: "<p>hi</p>", title: "Mockup" });
    await client.callTool({ name: "clear_screen", arguments: {} });
    expect(bridge.state.screen).toBeNull();
  });

  it("present_options resolves from a native elicitation when the host supports it", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client(
      { name: "test-client", version: "0.0.1" },
      { capabilities: { elicitation: {} } },
    );
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { choice: "b" } }));
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

    const res = await client.callTool({
      name: "present_options",
      arguments: { prompt: "Which approach?", options: [{ id: "a", title: "A" }, { id: "b", title: "B", recommended: true }] },
    });
    const out = (res.content as { type: string; text: string }[])[0].text;
    expect(out).toContain("b");

    await client.close();
    await server.close();
  });

  it("present_workflows returns the chosen workflow's intent via a native choice card", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client(
      { name: "test-client", version: "0.0.1" },
      { capabilities: { elicitation: {} } },
    );
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { choice: "review" } }));
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

    const res = await client.callTool({ name: "present_workflows", arguments: {} });
    const out = (res.content as { type: string; text: string }[])[0].text;
    const review = WORKFLOWS.find((w) => w.id === "review")!;
    expect(out).toContain(review.intent);

    await client.close();
    await server.close();
  });

  it("review_start and add_finding drive the findings state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "review_start", arguments: { target: "PR 1" } });
    await client.callTool({ name: "add_finding", arguments: { severity: "high", title: "bug", file: "a.ts", line: 2 } });
    expect(bridge.state.domain).toBe("review");
    expect(bridge.state.reviewTarget).toBe("PR 1");
    expect(bridge.state.findings).toHaveLength(1);
    expect(bridge.state.findings[0]).toMatchObject({ severity: "high", title: "bug" });
    await client.close();
    await server.close();
  });

  it("the backlog tools drive the board state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "backlog_start", arguments: { target: "Sprint 4", columns: ["Todo", "Done"] } });
    expect(bridge.state.domain).toBe("backlog");
    expect(bridge.state.boardColumns).toEqual(["Todo", "Done"]);
    await client.callTool({ name: "add_item", arguments: { id: "I1", title: "fix", column: "Todo", kind: "bug", tier: "T2" } });
    expect(bridge.state.boardItems).toHaveLength(1);
    expect(bridge.state.boardItems[0]).toMatchObject({ id: "I1", title: "fix", column: "Todo", kind: "bug", tier: "T2" });
    await client.callTool({ name: "move_item", arguments: { id: "I1", column: "Done" } });
    expect(bridge.state.boardItems[0].column).toBe("Done");
    await client.callTool({ name: "set_backlog_action", arguments: { text: "triaging" } });
    expect(bridge.state.boardAction).toBe("triaging");
    await client.callTool({ name: "set_backlog_action", arguments: { text: null } });
    expect(bridge.state.boardAction).toBeNull();
    await client.close();
    await server.close();
  });

  it("the team tools drive the roster state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "team_start", arguments: { task: "ship", orchestrator: "Lead" } });
    expect(bridge.state.domain).toBe("team");
    expect(bridge.state.orchestrator).toBe("Lead");
    await client.callTool({ name: "add_agent", arguments: { id: "a1", name: "Worker", role: "impl", status: "running" } });
    expect(bridge.state.teamAgents).toHaveLength(1);
    expect(bridge.state.teamAgents[0]).toMatchObject({ id: "a1", name: "Worker", role: "impl", status: "running" });
    await client.callTool({ name: "update_agent", arguments: { id: "a1", status: "done", action: "shipped" } });
    expect(bridge.state.teamAgents[0]).toMatchObject({ status: "done", action: "shipped" });
    await client.callTool({ name: "remove_agent", arguments: { id: "a1" } });
    expect(bridge.state.teamAgents).toHaveLength(0);
    await client.close();
    await server.close();
  });

  it("the codemap tools drive the codemap state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "codemap_set", arguments: { nodes: [{ id: "n1", path: "src/a.ts", kind: "file" }, { id: "n2", path: "src/b.ts", kind: "file" }] } });
    expect(bridge.state.domain).toBe("codemap");
    expect(bridge.state.codemapNodes).toHaveLength(2);
    await client.callTool({ name: "codemap_focus", arguments: { id: "n1" } });
    expect(bridge.state.codemapFocus).toBe("n1");
    await client.callTool({ name: "codemap_touch", arguments: { id: "n2", kind: "edit" } });
    expect(bridge.state.codemapTouches.n2).toBe("edit");
    await client.close();
    await server.close();
  });

  it("set_context with full args sets all three context fields", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_context", arguments: { instructions: ["no em-dashes", "lint to zero"], skills: ["tdd"], collection: "hve-core" } });
    expect(bridge.state.contextInstructions).toEqual(["no em-dashes", "lint to zero"]);
    expect(bridge.state.contextSkills).toEqual(["tdd"]);
    expect(bridge.state.contextCollection).toBe("hve-core");
    await client.close();
    await server.close();
  });

  it("set_context with partial args defaults the others to [] and null", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_context", arguments: { skills: ["deepsearch"] } });
    expect(bridge.state.contextSkills).toEqual(["deepsearch"]);
    expect(bridge.state.contextInstructions).toEqual([]);
    expect(bridge.state.contextCollection).toBeNull();
    await client.close();
    await server.close();
  });

  it("set_app_frame accepts a loopback url and clears on null", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    await client.callTool({ name: "set_app_frame", arguments: { url: "http://localhost:5173" } });
    expect(bridge.state.appFrameUrl).toBe("http://localhost:5173");
    await client.callTool({ name: "set_app_frame", arguments: { url: null } });
    expect(bridge.state.appFrameUrl).toBeNull();
    await client.close();
    await server.close();
  });

  it("set_app_frame rejects non-loopback / non-http urls and leaves state unchanged (server guard)", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: {} });
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    for (const url of ["http://evil.com", "javascript:alert(1)", "file:///etc/passwd"]) {
      const res = await client.callTool({ name: "set_app_frame", arguments: { url } });
      const out = (res.content as { text: string }[])[0].text;
      expect(out).toContain("rejected");
      // The rejected URL never updates state: no beat is emitted, so it stays null.
      expect(bridge.state.appFrameUrl).toBeNull();
    }
    await client.close();
    await server.close();
  });

  it("ask_question resolves from a native free-text elicitation", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const client = new Client({ name: "t", version: "0.0.1" }, { capabilities: { elicitation: {} } });
    client.setRequestHandler(ElicitRequestSchema, async () => ({ action: "accept", content: { answer: "the goal" } }));
    const [ct, st] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(st), client.connect(ct)]);
    const res = await client.callTool({ name: "ask_question", arguments: { prompt: "What is the goal?" } });
    expect((res.content as { text: string }[])[0].text).toBe("the goal");
    await client.close();
    await server.close();
  });

  it("present_options forwards the id into the decisions flow", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    void client.callTool({ name: "present_options", arguments: { prompt: "Pick?", options: [{ id: "a", title: "A" }], id: "d7" } });
    await new Promise((r) => setTimeout(r, 10));
    expect(bridge.state.decisions.find((d) => d.id === "d7")?.kind).toBe("choice");
  });

  it("dataset_profile + add_column drive the data profile state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "dataset_profile", arguments: { name: "sales.csv", rows: 100, columns: 2, source: "dw" } });
    await client.callTool({ name: "add_column", arguments: { name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" } });
    expect(bridge.state.domain).toBe("dataprofile");
    expect(bridge.state.profileDataset).toMatchObject({ name: "sales.csv", cols: 2 });
    expect(bridge.state.profileColumns[0]).toMatchObject({ name: "id", dtype: "int", quality: "ok" });

    await client.close();
    await server.close();
  });

  it("set_steps drives the interview program state", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);
    await client.callTool({ name: "set_steps", arguments: { steps: ["Frame", "Decide", "Govern"], current: 1, label: "ADR" } });
    expect(bridge.state.interviewSteps).toEqual({ label: "ADR", names: ["Frame", "Decide", "Govern"], current: 1 });
  });

  it("set_steps forwards progress", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);
    await client.callTool({ name: "set_steps", arguments: { steps: ["a", "b"], current: 0, progress: { done: 1, total: 4 } } });
    expect(bridge.state.interviewSteps!.progress).toEqual({ done: 1, total: 4 });
  });

  it("gallery tools drive the gallery state and reject bad input", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "gallery_open", arguments: { title: "Apps", size: "l", items: [
      { label: "Local", url: "http://localhost:3000/" },
      { label: "Snap", html: "<b>x</b>" },
    ] } });
    expect(bridge.state.domain).toBe("gallery");
    expect(bridge.state.galleryTitle).toBe("Apps");
    expect(bridge.state.gallerySize).toBe("l");
    expect(bridge.state.galleryItems.map((i) => i.id)).toEqual(["g0", "g1"]);

    await client.callTool({ name: "gallery_add", arguments: { item: { id: "x", label: "Ext", url: "https://example.com" } } });
    expect(bridge.state.galleryItems.at(-1)).toMatchObject({ id: "x", label: "Ext" });

    await client.callTool({ name: "gallery_clear", arguments: {} });
    expect(bridge.state.galleryItems).toEqual([]);

    const bad = await client.callTool({ name: "gallery_open", arguments: { title: "T", items: [{ label: "Bad", url: "http://evil.example.com" }] } });
    expect(bad.isError).toBe(true);
  });

  it("promptlab_start + add_case drive the workbench and reject a bad verdict", async () => {
    const bridge = new Bridge();
    const server = buildMcpServer(bridge);
    const [clientT, serverT] = InMemoryTransport.createLinkedPair();
    await server.connect(serverT);
    const client = new Client({ name: "test", version: "0" });
    await client.connect(clientT);

    await client.callTool({ name: "promptlab_start", arguments: { name: "summarizer.prompt", prompt: "You are…", round: 2 } });
    await client.callTool({ name: "add_case", arguments: { id: "c1", scenario: "empty input", output: "(nothing)", verdict: "fail", note: "no guard" } });
    expect(bridge.state.domain).toBe("promptlab");
    expect(bridge.state.promptName).toBe("summarizer.prompt");
    expect(bridge.state.promptRound).toBe(2);
    expect(bridge.state.promptCases[0]).toMatchObject({ id: "c1", scenario: "empty input", verdict: "fail" });

    const bad = await client.callTool({ name: "add_case", arguments: { id: "c2", scenario: "x", verdict: "bogus" } });
    expect(bad.isError).toBe(true);
  });
});
