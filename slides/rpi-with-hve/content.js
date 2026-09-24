// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
// cspell:words distractors Willison Tobi Lutke Andrej Karpathy
(function () {
  'use strict';
  const hve = 'https://github.com/microsoft/hve-core/blob/33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d/';
  const rpi = hve + '.github/skills/rpi/';
  const vscode = 'https://github.com/microsoft/vscode/blob/1.139.0/extensions/copilot/src/extension/tools/node/';
  const sources = {
    snapshot: { title: 'HVE Core source snapshot 33ac6ec', url: 'https://github.com/microsoft/hve-core/tree/33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d', note: 'Repository state observed September 23, 2026. RPI claims in this deck describe this revision.' },
    'rpi-overview': { title: 'Understanding the RPI workflow', url: hve + 'docs/rpi/README.md', note: 'Lifecycle concepts, entry surfaces and when a smaller direct edit is enough. ms.date 2026-09-11.' },
    'why-rpi': { title: 'Why the RPI workflow works', url: hve + 'docs/rpi/why-rpi.md', note: 'Phase separation, research readiness and the resource_prefix example.' },
    'context-doc': { title: 'Context engineering in RPI', url: hve + 'docs/rpi/context-engineering.md', note: 'Deliberate /clear, resuming from artifacts and the /compact trade-off. Its 128K to 200K window range predates current models.' },
    research: { title: 'rpi-research skill', url: rpi + 'rpi-research/SKILL.md', note: 'Read-only. Research runs for a demonstrated gap; each cycle completes Wider, Deeper and Contrarian waves; findings map to C# and W# evidence IDs.' },
    'research-template': { title: 'Research artifact template', url: rpi + 'rpi-research/templates/research.md', note: 'Findings, alternatives, decisions and Planning Readiness above the Research Record and Evidence Log.' },
    plan: { title: 'rpi-plan skill', url: rpi + 'rpi-plan/SKILL.md', note: 'One task-centered plan. The primary planner owns orchestration, revisions, critique timing and readiness.' },
    'plan-template': { title: 'Implementation plan template', url: rpi + 'rpi-plan/templates/implementation-plan.md', note: 'Pxx phases and Pxx-Txx tasks with Goals, Requirements, Details, References and Dependencies.' },
    critique: { title: 'rpi-plan-critique skill', url: rpi + 'rpi-plan-critique/SKILL.md', note: 'One read-only credibility assessment of the final plan, recorded as Pass, Revise or Blocked.' },
    implement: { title: 'rpi-implement skill', url: rpi + 'rpi-implement/SKILL.md', note: 'Follows the plan, keeps it current, checks off completed work and keeps a condensed changes log.' },
    'changes-template': { title: 'Changes record template', url: rpi + 'rpi-implement/templates/changes-log.md', note: 'Completed work, implementation-time plan updates, validation record and remaining work.' },
    review: { title: 'rpi-review skill', url: rpi + 'rpi-review/SKILL.md', note: 'One review per task. Execution status is separate from outcome. Gaps route to implementation, planning, research or a follow-up item.' },
    'review-template': { title: 'Review record template', url: rpi + 'rpi-review/templates/review-log.md', note: 'RV-xxx findings with proposed routes and an append-only Parent Decision Record.' },
    agent: { title: 'RPI Agent', url: hve + '.github/agents/hve-core/rpi-agent.agent.md', note: 'Optional user-selected wrapper. Four participation choices; manual by default; Full Auto on request.' },
    'advisory-helpers': { title: 'Optional, advisory RPI subagents / PR #2902', url: 'https://github.com/microsoft/hve-core/pull/2902', note: 'Merged September 18, 2026. No phase requires a subagent. Helpers return suggestions; the phase owner verifies them and assigns every evidence ID.' },
    loops: { title: 'Automatic RPI loops and walkthroughs / PR #2859', url: 'https://github.com/microsoft/hve-core/pull/2859', note: 'Merged September 8, 2026. Participation choices, progression and stop rules.' },
    'gpt6-astra': { title: 'OpenAI: GPT-6 Astra model', url: 'https://developers.openai.com/api/docs/models/gpt-6-astra', note: '1,050,000-token context window; 922,000 maximum input and 128,000 maximum output tokens. Retrieved September 23, 2026.' },
    'gpt6-release': { title: 'OpenAI API changelog', url: 'https://developers.openai.com/api/docs/changelog', note: 'GPT-6 Astra released September 3, 2026. GPT-6 Sol and Luna released September 22.' },
    'gpt6-guide': { title: 'OpenAI: Using GPT-6', url: 'https://developers.openai.com/api/docs/guides/latest-model', note: 'Astra stays coherent on long tasks and asks when input could change the result. It is more sensitive to instructions in skills and files such as AGENTS.md; OpenAI recommends auditing them.' },
    'opus-55': { title: 'Anthropic: Claude Opus 5.5', url: 'https://platform.claude.com/docs/en/models/opus-5-5/overview', note: 'Released September 22, 2026. 1M-token context window; 128K maximum output.' },
    'claude-context': { title: 'Anthropic: Context windows', url: 'https://platform.claude.com/docs/en/build-with-claude/context-windows', note: 'More context is not automatically better; accuracy and recall degrade as token count grows. The system prompt, messages, tool results and tool definitions all count.' },
    'copilot-models': { title: 'GitHub Docs: Supported AI models in Copilot', url: 'https://docs.github.com/en/copilot/reference/ai-models/supported-models', note: 'Lists GPT-6 Astra, Sol, Luna and Claude Opus 5.5 as generally available. Retrieved September 23, 2026; plan availability varies.' },
    'vscode-release': { title: 'VS Code 1.139.0 release', url: 'https://github.com/microsoft/vscode/releases/tag/1.139.0', note: 'Published September 23, 2026. Tool behavior below is read from this tag.' },
    'vscode-search-tool': { title: 'VS Code 1.139.0: grep_search tool source', url: vscode + 'findTextInFilesTool.tsx', note: 'Default 100 results and a 200-result cap, both experiment-based settings. Reports found versus shown matches and truncates long lines.' },
    'vscode-read-tool': { title: 'VS Code 1.139.0: read_file tool source', url: vscode + 'readFileTool.tsx', note: 'Truncates at 2,000 lines and 2,000 characters per line, then asks the model to continue with offset and limit.' },
    'vscode-sessions': { title: 'VS Code: Manage agent sessions', url: 'https://code.visualstudio.com/docs/agents/run/sessions/manage-sessions', note: 'Context window control in the chat input; automatic compaction when the window fills; new sessions for independent tasks.' },
    'vscode-best-practices': { title: 'VS Code: Best practices for using AI', url: 'https://code.visualstudio.com/docs/agents/best-practices', note: 'Bounded tasks, relevant context, plan first for complex changes, new sessions for unrelated work and search exclusions for noisy files.' },
    'vscode-context-guide': { title: 'VS Code: Context engineering flow', url: 'https://code.visualstudio.com/docs/agents/guides/context-engineering-guide', note: 'Save the plan to a file, start a new chat that references it and review in a fresh chat against the plan.' },
    'claude-code-practices': { title: 'Claude Code: Best practices', url: 'https://code.claude.com/docs/en/best-practices', note: 'Context fills fast and performance degrades as it fills. Explore, plan, then code; skip the plan when the diff fits in one sentence. Names the infinite-exploration failure pattern.' },
    'codex-practices': { title: 'OpenAI Codex: Best practices', url: 'https://learn.chatgpt.com/guides/best-practices', note: 'Goal, context, constraints and a done condition; plan first for complex or ambiguous work. Useful results are possible with minimal setup.' },
    'anthropic-context-eng': { title: 'Anthropic: Effective context engineering for AI agents', url: 'https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents', note: 'Context rot appears across models; aim for the smallest set of high-signal tokens; larger windows remain subject to pollution; do the simplest thing that works.' },
    'context-rot': { title: 'Chroma: Context rot', url: 'https://www.trychroma.com/research/context-rot', note: 'July 2025 study of 18 models. With task difficulty held constant, accuracy fell as input grew, and distractors had non-uniform effects.' },
    distracted: { title: 'Shi et al.: LLMs can be easily distracted by irrelevant context', url: 'https://arxiv.org/abs/2302.00093', note: '2023. Irrelevant details in math problems substantially reduced accuracy. Evaluated an earlier model generation.' },
    'lost-middle': { title: 'Liu et al.: Lost in the middle', url: 'https://arxiv.org/abs/2307.03172', note: '2023. Relevant information in the middle of long inputs was used less reliably. Evaluated an earlier model generation.' },
    'context-term': { title: 'Simon Willison: Context engineering', url: 'https://simonwillison.net/2025/Jun/27/context-engineering/', note: 'June 27, 2025. Quotes Tobi Lutke and Andrej Karpathy on the term, with links to their original posts.' }
  };

  const request = {
    kind: 'composer', phase: 'Request', state: 'RPI Agent selected',
    title: 'Describe the task and its constraint', label: 'Reconstructed Copilot Chat input',
    body: 'Add a configurable log retention setting to every storage module. Follow the existing variable naming.',
    attachments: ['modules/'], mode: 'RPI Agent',
    insight: 'Scripted request. RPI Agent first checks if existing evidence is enough.'
  };

  const participation = {
    kind: 'question', title: 'Choose a participation mode', label: 'Reconstructed Copilot question',
    body: 'How would you like us to work on this?', headingLevel: 3,
    options: [
      { label: 'Handle it end to end', detail: 'I\'ll make the decisions and work through Research, Planning, Implementation, Review, and any needed follow-ups until your request is complete.' },
      { label: 'Keep going, but check with me', detail: 'I\'ll work through all RPI phases and needed follow-ups automatically, asking you when decisions or direction need clarification, until your request is complete.' },
      { label: 'Research and plan with me', detail: 'I\'ll research and plan, asking you when decisions or direction need clarification. Then I\'ll walk you through the artifacts and stop before Implementation so we can refine the research and plan together.' },
      { label: 'Work through each phase with me', detail: 'I\'ll ask about unclear decisions and direction, walk you through the research, plan, implementation, and review artifacts, and wait for you to choose when we move to the next phase.' }
    ],
    selected: 2
  };

  const examples = { request, participation };

  const demos = {
    rpi: {
      label: 'Log retention example',
      phases: ['Request', 'Research', 'Plan', 'Implement', 'Review'],
      steps: [
        request,
        {
          kind: 'code', phase: 'Research', state: 'Coverage incomplete',
          title: 'The first search returns a partial view', file: 'grep_search result', surface: 'tool', label: 'Reconstructed tool output',
          body: 'Found 312 matches in 14 files for "variable"\n(showing 100 matches in 14 files)\n\nmodules/blob/variables.tf\n3:variable "resource_prefix" {\n11:variable "location" {\n... (19 more matches in this file)\n\nmodules/legacy-table/variables.tf\n2:variable "prefix" {\n... (24 more matches in this file)',
          insight: 'Only 100 of 312 matches came back. Research reruns the search per module.'
        },
        {
          kind: 'question', phase: 'Research', state: 'Decision needed',
          title: 'Ask before deciding for the user', label: 'Reconstructed Copilot question',
          body: 'Two legacy modules use prefix, not resource_prefix. How should the plan treat them?',
          options: [
            { label: 'Add the setting and keep their names', detail: 'Smallest change. Renaming becomes a separate follow-up.' },
            { label: 'Rename their variables too', detail: 'Consistent names, but a breaking change for callers.' },
            { label: 'Skip the legacy modules', detail: 'Two modules would not get the setting.' }
          ],
          selected: 0,
          insight: 'The answer is recorded as decision D1, next to evidence C1 and C2.'
        },
        {
          kind: 'code', phase: 'Plan', state: 'Critique: Revise, then resolved',
          title: 'The critique finds a missing check', file: 'log-retention-plan.md', label: 'Illustrative excerpt',
          body: '#### [ ] P01-T01: Add log retention\nRequirements:\n* FR-001: defaults to 30 days.\n* FR-002: rejects values outside 1 to 365.\n* FR-003: legacy modules keep prefix (D1).\n\n## Critique Disposition\nPC-001: FR-002 has no check.\nResolved: add terraform test cases for 0 and 366.',
          insight: 'The planner added the missing check before any code changed.'
        },
        {
          kind: 'implementation', phase: 'Implement', state: 'New chat from the plan',
          title: 'Implement the task and record the checks', label: 'Scripted implementation',
          plan: 'log-retention-plan.md', phaseTitle: 'P01 / Log retention',
          tasks: ['P01-T01 Add the variable', 'P01-T02 Run the checks'],
          changes: '## Completed Work\nP01-T01: all 14 modules\naccept log_retention_days.\n## Validation Record\nterraform validate: Passed\nterraform test: Passed',
          file: 'modules/blob/variables.tf', startLine: 14,
          diff: [
            { type: 'context', text: '}' },
            { type: 'add', text: 'variable "log_retention_days" {' },
            { type: 'add', text: '  type    = number' },
            { type: 'add', text: '  default = 30' },
            { type: 'add', text: '  validation {' },
            { type: 'add', text: '    condition = (' },
            { type: 'add', text: '      var.log_retention_days >= 1 &&' },
            { type: 'add', text: '      var.log_retention_days <= 365)' },
            { type: 'add', text: '    error_message = "Use 1 to 365 days."' },
            { type: 'add', text: '  }' },
            { type: 'add', text: '}' }
          ],
          insight: 'A fresh chat started from the plan. Tasks were checked only when requirements held.'
        },
        {
          kind: 'code', phase: 'Review', state: 'Complete / Defects found',
          title: 'Review against the plan and route the gap', file: 'log-retention-review.md', label: 'Illustrative excerpt',
          body: '### RV-001 [Medium]: legacy modules accept 0\nExpected: FR-002 validation in all 14 modules.\nObserved: legacy-table and legacy-files have no\nvalidation block.\nRoute: rpi-implement (P01-T01)\n\n## Parent Decision Record\nExecution: Complete\nOutcome: Defects found',
          insight: 'The FR-002 defect goes back to implementation. Finishing is not passing.'
        }
      ]
    }
  };

  function moveStep(index, action, length) {
    if (!Number.isInteger(length) || length < 1 || !Number.isInteger(index) || index < 0 || index >= length) {
      throw new Error('Invalid walkthrough state.');
    }
    if (action === 'reset') return 0;
    if (action === 'next') return Math.min(length - 1, index + 1);
    if (action === 'back') return Math.max(0, index - 1);
    throw new Error(`Unknown walkthrough action: ${action}`);
  }
  function diffStats(rows) {
    if (!Array.isArray(rows) || rows.some(row => !['add', 'remove', 'context'].includes(row.type) || typeof row.text !== 'string')) {
      throw new Error('Invalid displayed diff rows.');
    }
    return {
      added: rows.filter(row => row.type === 'add').length,
      removed: rows.filter(row => row.type === 'remove').length
    };
  }
  globalThis.DeckContent = { sources, examples, demos, moveStep, diffStats };
}());
