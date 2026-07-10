// rpi-cockpit/src/mcp.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Phase, ValidationStatus, OptionItem, Severity, AgentStatus, CodeKind, TouchKind } from "./events.js";
import { handlers } from "./handlers.js";
import { presentOptionsWithElicitation, askQuestionWithElicitation, presentWorkflows, decisionTimeoutMs, questionTimeoutMs, type ElicitFormParams } from "./elicit.js";
import type { Bridge } from "./bridge.js";

const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });

export function buildMcpServer(bridge: Bridge): McpServer {
  const server = new McpServer({ name: "rpi-cockpit", version: "0.1.0" });

  server.registerTool(
    "session_begin",
    { description: "Open the cockpit session.", inputSchema: { task: z.string(), host: z.string() } },
    async (a) => text(handlers.session_begin(bridge, a)),
  );

  server.registerTool(
    "phase_enter",
    { description: "Enter an RPI phase.", inputSchema: { phase: Phase } },
    async (a) => text(handlers.phase_enter(bridge, a)),
  );

  server.registerTool(
    "subagent_start",
    { description: "Mark a subagent active.", inputSchema: { name: z.string(), role: z.string().optional() } },
    async (a) => text(handlers.subagent_start(bridge, a)),
  );

  server.registerTool(
    "subagent_stop",
    { description: "Mark a subagent idle.", inputSchema: { name: z.string(), result: z.string().optional() } },
    async (a) => text(handlers.subagent_stop(bridge, a)),
  );

  server.registerTool(
    "artifact_update",
    { description: "Record a tracking artifact.", inputSchema: { path: z.string(), summary: z.string().optional() } },
    async (a) => text(handlers.artifact_update(bridge, a)),
  );

  server.registerTool(
    "validate",
    { description: "Report a validation check.", inputSchema: { check: z.string(), status: ValidationStatus } },
    async (a) => text(handlers.validate(bridge, a)),
  );

  server.registerTool(
    "review_start",
    { description: "Begin a review; switches the cockpit to the findings panel.", inputSchema: { target: z.string() } },
    async (a) => text(handlers.review_start(bridge, a)),
  );

  server.registerTool(
    "add_finding",
    { description: "Add a review finding (rendered in the findings panel, grouped by severity).", inputSchema: { severity: Severity, title: z.string(), file: z.string().optional(), line: z.number().int().optional(), detail: z.string().optional() } },
    async (a) => text(handlers.add_finding(bridge, a)),
  );

  server.registerTool(
    "interview_start",
    { description: "Begin a guided document interview; switches the cockpit to the interview view.", inputSchema: { docType: z.string() } },
    async (a) => text(handlers.interview_start(bridge, a)),
  );

  server.registerTool(
    "set_steps",
    { description: "Show a progress stepper above the interview conversation: declare the program's ordered step names and the active step index (0-based). Re-call to advance (a higher current) or to re-declare the steps as an adaptive program clarifies. label is an optional program name. progress is an optional { done, total } shown on the active step.", inputSchema: { steps: z.array(z.string()).min(1), current: z.number().int(), label: z.string().optional(), progress: z.object({ done: z.number().int(), total: z.number().int() }).optional() } },
    async (a) => text(handlers.set_steps(bridge, a)),
  );

  server.registerTool(
    "backlog_start",
    { description: "Begin a backlog board; switches the cockpit to the kanban view. Declare the ordered column/state names (e.g. Triage, Todo, In progress, Done).", inputSchema: { target: z.string(), columns: z.array(z.string()).min(1) } },
    async (a) => text(handlers.backlog_start(bridge, a)),
  );

  server.registerTool(
    "add_item",
    { description: "Add or update a work item on the backlog board, placing it in the given column. Pass parent (a parent item's id) to nest it under that item in the hierarchy.", inputSchema: { id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional(), parent: z.string().optional() } },
    async (a) => text(handlers.add_item(bridge, a)),
  );

  server.registerTool(
    "move_item",
    { description: "Move a work item to a different column on the board.", inputSchema: { id: z.string(), column: z.string() } },
    async (a) => text(handlers.move_item(bridge, a)),
  );

  server.registerTool(
    "set_backlog_action",
    { description: "Set or clear the current action line in the board header (pass null to clear).", inputSchema: { text: z.string().nullable() } },
    async (a) => text(handlers.set_backlog_action(bridge, a)),
  );

  server.registerTool(
    "dataset_profile",
    { description: "Begin a dataset profile; switches the cockpit to the data-profile table view. Name the dataset; optionally give its row count, total column count, and source.", inputSchema: { name: z.string(), rows: z.number().int().optional(), columns: z.number().int().optional(), source: z.string().optional() } },
    async (a) => text(handlers.dataset_profile(bridge, a)),
  );

  server.registerTool(
    "add_column",
    { description: "Add or update one column's profile in the dataset profile view (a dataset field, not a kanban column). Give its name and dtype; optionally null percentage (0-100), distinct count, a representative stat string (e.g. \"0-4820\" or \"mean 126.2\"), and a quality flag (ok/warn/risk).", inputSchema: { name: z.string(), dtype: z.string(), nullPct: z.number().optional(), distinct: z.number().int().optional(), stat: z.string().optional(), quality: z.enum(["ok", "warn", "risk"]).optional() } },
    async (a) => text(handlers.add_column(bridge, a)),
  );

  server.registerTool(
    "set_context",
    { description: "Set the active context shown in the cockpit's context strip: the instructions (coding standards), skills, and collection currently in effect. Replaces the whole context, so pass everything currently active. Omitting instructions, skills, or collection clears that group.", inputSchema: { instructions: z.array(z.string()).optional(), skills: z.array(z.string()).optional(), collection: z.string().nullable().optional() } },
    async (a) => text(handlers.set_context(bridge, a)),
  );

  server.registerTool(
    "set_app_frame",
    { description: "Embed the user's app-under-development in a trusted iframe beside the cockpit. The URL MUST be a loopback http(s) URL (localhost / 127.0.0.1 / [::1]); non-loopback URLs are rejected. Pass null to clear the frame.", inputSchema: { url: z.string().nullable() } },
    async (a) => text(handlers.set_app_frame(bridge, a)),
  );

  server.registerTool(
    "team_start",
    { description: "Begin a team-orchestration run; switches the cockpit to the team board. Names the orchestrator (lead) and the overall task.", inputSchema: { task: z.string(), orchestrator: z.string() } },
    async (a) => text(handlers.team_start(bridge, a)),
  );

  server.registerTool(
    "add_agent",
    { description: "Add a subagent to the team board with a status (queued/running/blocked/done/failed).", inputSchema: { id: z.string(), name: z.string(), role: z.string().optional(), status: AgentStatus } },
    async (a) => text(handlers.add_agent(bridge, a)),
  );

  server.registerTool(
    "update_agent",
    { description: "Update a team subagent's status and/or current action.", inputSchema: { id: z.string(), status: AgentStatus.optional(), action: z.string().nullable().optional() } },
    async (a) => text(handlers.update_agent(bridge, a)),
  );

  server.registerTool(
    "remove_agent",
    { description: "Remove a subagent from the team board.", inputSchema: { id: z.string() } },
    async (a) => text(handlers.remove_agent(bridge, a)),
  );

  server.registerTool(
    "codemap_set",
    { description: "Set the codebase map: the slice of files/dirs relevant to this task (max 60). Switches the cockpit to the 3D codebase map.", inputSchema: { nodes: z.array(z.object({ id: z.string(), path: z.string(), kind: CodeKind, group: z.string().optional() })).max(60) } },
    async (a) => text(handlers.codemap_set(bridge, a)),
  );

  server.registerTool(
    "codemap_focus",
    { description: "Move the codebase-map camera to a node (the file the agent is now working in).", inputSchema: { id: z.string() } },
    async (a) => text(handlers.codemap_focus(bridge, a)),
  );

  server.registerTool(
    "codemap_touch",
    { description: "Mark a codebase-map node as read or edited (the agent's trail).", inputSchema: { id: z.string(), kind: TouchKind } },
    async (a) => text(handlers.codemap_touch(bridge, a)),
  );

  server.registerTool(
    "ask_question",
    { description: "Ask the user a free-text question; blocks until they answer. Shows the in-pane question card and, where supported, a native input.", inputSchema: { prompt: z.string(), id: z.string().optional() } },
    async (a) => {
      bridge.setHostElicits(server.server.getClientCapabilities()?.elicitation !== undefined);
      return text(
        await askQuestionWithElicitation(
          {
            getClientCapabilities: () => server.server.getClientCapabilities(),
            elicitInput: (params: ElicitFormParams, opts) =>
              server.server.elicitInput(params as unknown as Parameters<typeof server.server.elicitInput>[0], opts),
          },
          bridge,
          a.prompt,
          // Free-text answers default to no auto-resolve (see questionTimeoutMs):
          // an empty timeout fallback is indistinguishable from a deliberate empty
          // answer, so let the interactive interview block until the user answers.
          questionTimeoutMs(),
          a.id,
        ),
      );
    },
  );

  server.registerTool(
    "present_options",
    { description: "Ask the user to choose; blocks until they pick. Shows the in-pane card and, where the host supports it, a native choice card; the first answer wins.", inputSchema: { prompt: z.string(), options: z.array(OptionItem).min(1), id: z.string().optional() } },
    async (a) => {
      bridge.setHostElicits(server.server.getClientCapabilities()?.elicitation !== undefined);
      return text(
        await presentOptionsWithElicitation(
          {
            getClientCapabilities: () => server.server.getClientCapabilities(),
            elicitInput: (params: ElicitFormParams, opts) =>
              server.server.elicitInput(params as unknown as Parameters<typeof server.server.elicitInput>[0], opts),
          },
          bridge,
          a.prompt,
          a.options,
          decisionTimeoutMs(),
          a.id,
        ),
      );
    },
  );

  server.registerTool(
    "offer_approaches",
    { description: "Offer the user a structured choice for the next phase (populates the cockpit's Steer select).", inputSchema: { label: z.string(), options: z.array(OptionItem).min(1) } },
    async (a) => text(handlers.offer_approaches(bridge, a)),
  );

  server.registerTool(
    "check_directives",
    { description: "Pull any user directives queued from the cockpit. Returns them as text; you MUST read and act on the result. Call at each phase_enter.", inputSchema: {} },
    async () => text(handlers.check_directives(bridge)),
  );

  server.registerTool(
    "show_screen",
    { description: "Render arbitrary static HTML in a dedicated, sandboxed cockpit pane (no scripts run; isolated from the page). For one-off rich content the fixed cockpit can't show: a mockup, a diff, rendered markdown, a diagram.", inputSchema: { html: z.string(), title: z.string().optional() } },
    async (a) => text(handlers.show_screen(bridge, a)),
  );

  server.registerTool(
    "clear_screen",
    { description: "Remove the agent-authored screen pane from the cockpit.", inputSchema: {} },
    async () => text(handlers.clear_screen(bridge)),
  );

  server.registerTool(
    "open_navigator",
    { description: "Open the Navigator pop-up in the cockpit so the user can pick a workflow. Use for a /Nav command or at the start of the main skill.", inputSchema: {} },
    async () => text(handlers.open_navigator(bridge)),
  );

  const galleryItemSchema = z.object({ id: z.string().optional(), label: z.string(), group: z.string().optional(), url: z.string().optional(), html: z.string().optional(), caption: z.string().optional() });

  server.registerTool(
    "gallery_open",
    { description: "Open the gallery view: a scrollable grid of scaled live thumbnails. Pass a title and an array of items; each item is EITHER a live `url` (a website or loopback dev server, framed live) OR an inline `html` snapshot, plus a `label`, optional `group` (section header), and optional `caption`. `url` must be a loopback http(s) URL or an external https URL. `size` is s/m/l (default m).", inputSchema: { title: z.string(), items: z.array(galleryItemSchema), size: z.enum(["s", "m", "l"]).optional() } },
    async (a) => text(handlers.gallery_open(bridge, a)),
  );

  server.registerTool(
    "gallery_add",
    { description: "Add or update one gallery tile by id (upsert). The item has the same shape as a gallery_open item (label, one of url/html, optional group/caption). Use this to stream tiles into an open gallery.", inputSchema: { item: galleryItemSchema } },
    async (a) => text(handlers.gallery_add(bridge, a)),
  );

  server.registerTool(
    "gallery_clear",
    { description: "Remove all tiles from the gallery (the view stays open with its title).", inputSchema: {} },
    async () => text(handlers.gallery_clear(bridge)),
  );

  server.registerTool(
    "promptlab_start",
    { description: "Begin a prompt workbench (the behavior test bench); switches the cockpit to the promptlab view. Name the prompt being hardened; optionally give its current text and the iteration round (default 1). Re-call with round+1 for a fresh pass.", inputSchema: { name: z.string(), prompt: z.string().optional(), round: z.number().int().optional() } },
    async (a) => text(handlers.promptlab_start(bridge, a)),
  );

  server.registerTool(
    "add_case",
    { description: "Add or update one prompt TEST CASE in the workbench (a scenario the prompt is run on, not a kanban item). Give an id and the scenario; once the Tester runs it and the Evaluator judges, update the same id with the literal output, a verdict (pending/running/pass/warn/fail), and an optional note.", inputSchema: { id: z.string(), scenario: z.string(), output: z.string().optional(), verdict: z.enum(["pending", "running", "pass", "warn", "fail"]).optional(), note: z.string().optional() } },
    async (a) => text(handlers.add_case(bridge, a)),
  );

  server.registerTool(
    "memory_open",
    { description: "Open the Memory view and switch the cockpit to it. Optionally name the collection (e.g. a project memory name). Clears the entries and handoffs for a fresh session view.", inputSchema: { title: z.string().optional() } },
    async (a) => text(handlers.memory_open(bridge, a)),
  );

  server.registerTool(
    "add_memory",
    { description: "Add or update one MEMORY ENTRY (a recalled or written fact, not a kanban item / dataset column / prompt case). Give an id, its content, and a category to group by (a memory type like user/feedback/project/reference, or a source); optionally a short title and a tag: recalled (loaded into context), added (written this session), or updated.", inputSchema: { id: z.string(), content: z.string(), category: z.string(), tag: z.enum(["recalled", "added", "updated"]).optional(), title: z.string().optional() } },
    async (a) => text(handlers.add_memory(bridge, a)),
  );

  server.registerTool(
    "add_handoff",
    { description: "Add or update one memory HANDOFF: another agent handing state to Memory. Give an id, `from` (the handing-off agent's name), a summary of what was handed, and an action: stored, merged, or recalled.", inputSchema: { id: z.string(), from: z.string(), summary: z.string(), action: z.enum(["stored", "merged", "recalled"]).optional() } },
    async (a) => text(handlers.add_handoff(bridge, a)),
  );

  server.registerTool(
    "flow_open",
    { description: "Open the flow canvas (the gh-aw agentic-workflow pipeline as a node graph) and switch the cockpit to it. Optionally name the pipeline. Clears nodes/edges and the drill focus.", inputSchema: { title: z.string().optional() } },
    async (a) => text(handlers.flow_open(bridge, a)),
  );
  server.registerTool(
    "add_flow_node",
    { description: "Add or update one FLOW NODE (a node in the pipeline graph, not a kanban item). kind is workflow (an orchestration-level workflow) or trigger/guard/agent/output/mcp (an anatomy element inside one workflow). For an anatomy node set scope to the workflow node's id; orchestration nodes leave scope default. status (idle/running/passed/failed/skipped/stale) drives the live-run look; sub is a short subtitle.", inputSchema: { id: z.string(), kind: z.enum(["workflow", "trigger", "guard", "agent", "output", "mcp"]), label: z.string(), scope: z.string().optional(), sub: z.string().optional(), status: z.enum(["idle", "running", "passed", "failed", "skipped", "stale"]).optional() } },
    async (a) => text(handlers.add_flow_node(bridge, a)),
  );
  server.registerTool(
    "add_flow_edge",
    { description: "Add or update one FLOW EDGE between two node ids. kind: label or event or output (orchestration handoffs) or step (anatomy). label is the handoff (e.g. a label name like agent-ready). status active animates the edge during a live run. Set scope to a workflow id for an anatomy edge; orchestration edges leave scope default.", inputSchema: { id: z.string(), from: z.string(), to: z.string(), scope: z.string().optional(), label: z.string().optional(), kind: z.enum(["label", "event", "output", "step"]).optional(), status: z.enum(["idle", "active"]).optional() } },
    async (a) => text(handlers.add_flow_edge(bridge, a)),
  );
  server.registerTool(
    "flow_focus",
    { description: "Drill the flow canvas to a workflow's anatomy by its node id, or omit / pass null to return to the orchestration pipeline. Use during a debug narration to pull the pane to a failing workflow.", inputSchema: { workflow: z.string().nullable().optional() } },
    async (a) => text(handlers.flow_focus(bridge, a)),
  );

  server.registerTool(
    "present_workflows",
    { description: "Offer the user the HVE Core workflows as a native choice card and return the chosen workflow's launch instruction. Use to let the user pick what to do.", inputSchema: {} },
    async () =>
      text(
        await presentWorkflows({
          getClientCapabilities: () => server.server.getClientCapabilities(),
          elicitInput: (params: ElicitFormParams, opts) =>
            server.server.elicitInput(params as unknown as Parameters<typeof server.server.elicitInput>[0], opts),
        }),
      ),
  );

  return server;
}

export async function connectStdio(server: McpServer): Promise<void> {
  await server.connect(new StdioServerTransport());
}
