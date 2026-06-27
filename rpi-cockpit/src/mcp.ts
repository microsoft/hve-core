// rpi-cockpit/src/mcp.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Phase, ValidationStatus, OptionItem, Severity } from "./events.js";
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
    "backlog_start",
    { description: "Begin a backlog board; switches the cockpit to the kanban view. Declare the ordered column/state names (e.g. Triage, Todo, In progress, Done).", inputSchema: { target: z.string(), columns: z.array(z.string()).min(1) } },
    async (a) => text(handlers.backlog_start(bridge, a)),
  );

  server.registerTool(
    "add_item",
    { description: "Add or update a work item on the backlog board, placing it in the given column.", inputSchema: { id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional() } },
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
    "set_context",
    { description: "Set the active context shown in the cockpit's context strip: the instructions (coding standards), skills, and collection currently in effect. Replaces the whole context, so pass everything currently active. Omitting instructions, skills, or collection clears that group.", inputSchema: { instructions: z.array(z.string()).optional(), skills: z.array(z.string()).optional(), collection: z.string().nullable().optional() } },
    async (a) => text(handlers.set_context(bridge, a)),
  );

  server.registerTool(
    "ask_question",
    { description: "Ask the user a free-text question; blocks until they answer. Shows the in-pane question card and, where supported, a native input.", inputSchema: { prompt: z.string() } },
    async (a) =>
      text(
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
        ),
      ),
  );

  server.registerTool(
    "present_options",
    { description: "Ask the user to choose; blocks until they pick. Shows the in-pane card and, where the host supports it, a native choice card; the first answer wins.", inputSchema: { prompt: z.string(), options: z.array(OptionItem).min(1) } },
    async (a) =>
      text(
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
        ),
      ),
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
