// src/catalog.ts
// The static capability catalog: the workflows the Navigator home offers as
// tiles. `intent` is the directive text sent to the host agent when the user
// clicks a tile; the agent does the actual launch. Names use goal language,
// mapping onto the workflow archetypes in docs/representation-map.md.

export interface Workflow {
  id: string;
  name: string;
  hint: string;
  description: string;
  intent: string;
}

export const WORKFLOWS: Workflow[] = [
  {
    id: "build",
    name: "Build code",
    hint: "Research, plan, implement",
    description: "Research, plan, and implement a change end to end, pausing at each decision for your call.",
    intent: "Launch the Build code workflow: run the RPI build loop (research, plan, implement, review, discover) for the task I describe next.",
  },
  {
    id: "review",
    name: "Review code",
    hint: "Findings by severity",
    description: "Point it at a branch or pull request for severity-ranked findings: bugs, security, accessibility, with file links.",
    intent: "Launch the Review code workflow: run a code review and report findings grouped by severity with file and line links.",
  },
  {
    id: "plan",
    name: "Plan and backlog",
    hint: "Triage and sprint",
    description: "Triage and shape work in GitHub, Azure DevOps, or Jira: discover, plan a sprint, and execute.",
    intent: "Launch the Plan and backlog workflow: triage and shape backlog work (discover, sprint plan, execute).",
  },
  {
    id: "docs",
    name: "Write docs and specs",
    hint: "Guided interview",
    description: "A guided interview that builds a product brief, a decision record, or a security plan, one question at a time.",
    intent: "Launch the Write docs and specs workflow: run a guided document interview (product brief, decision record, or security plan).",
  },
  {
    id: "data",
    name: "Analyze data",
    hint: "Notebooks and dashboards",
    description: "Turn a question and a dataset into a notebook, a dashboard, or a spec, previewed as it builds.",
    intent: "Launch the Analyze data workflow: turn a question and a dataset into a notebook, a dashboard, or a spec.",
  },
  {
    id: "coach",
    name: "Coach and learn",
    hint: "Methods and practices",
    description: "Work through a method with a coach: design thinking, agile practices, or experiment design, at your pace.",
    intent: "Launch the Coach and learn workflow: work through a method or curriculum with a coach.",
  },
];
