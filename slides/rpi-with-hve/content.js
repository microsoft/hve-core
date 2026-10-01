// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
// cspell:words distractors Willison Tobi Lutke Andrej Karpathy sublabel
(function () {
  'use strict';
  const hve = 'https://github.com/microsoft/hve-core/blob/33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d/';
  const rpi = hve + '.github/skills/rpi/';
  const vscode = 'https://github.com/microsoft/vscode/blob/1.139.0/extensions/copilot/src/extension/tools/node/';
  const sources = {
    snapshot: { title: 'HVE Core source snapshot 33ac6ec', url: 'https://github.com/microsoft/hve-core/tree/33ac6ec4a4ab7d1e5b44b01abb4179c567e3d23d', note: 'RPI behavior is described at this revision, observed September 23, 2026.' },
    'rpi-overview': { title: 'Understanding the RPI workflow', url: hve + 'docs/rpi/README.md', note: 'Explains the phases, how to start them and when a direct edit is enough. Updated September 11, 2026.' },
    'why-rpi': { title: 'Why the RPI workflow works', url: hve + 'docs/rpi/why-rpi.md', note: 'Explains phase separation and when research is needed, using resource_prefix as an example.' },
    'context-doc': { title: 'Context engineering in RPI', url: hve + 'docs/rpi/context-engineering.md', note: 'Covers /clear, resuming from saved files and what /compact can lose. Its 128K to 200K window figures describe earlier models.' },
    research: { title: 'rpi-research skill', url: rpi + 'rpi-research/SKILL.md', note: 'Investigates missing evidence without editing project source. Each cycle runs Wider, Deeper and Contrarian waves. C# and W# IDs connect findings to sources.' },
    'research-template': { title: 'Research artifact template', url: rpi + 'rpi-research/templates/research.md', note: 'Puts findings and decisions first, followed by the Research Record and Evidence Log. Planning Readiness states whether planning can proceed.' },
    plan: { title: 'rpi-plan skill', url: rpi + 'rpi-plan/SKILL.md', note: 'The planner writes and revises one plan, arranges its critique and decides whether it is ready for implementation.' },
    'plan-template': { title: 'Implementation plan template', url: rpi + 'rpi-plan/templates/implementation-plan.md', note: 'Uses Pxx phase IDs and Pxx-Txx task IDs. Each task includes Goals, Requirements, Details, References and Dependencies.' },
    critique: { title: 'rpi-plan-critique skill', url: rpi + 'rpi-plan-critique/SKILL.md', note: 'Assesses the final plan without changing it. Records Pass, Revise or Blocked; the planner handles the findings.' },
    implement: { title: 'rpi-implement skill', url: rpi + 'rpi-implement/SKILL.md', note: 'Follows the plan, updates it when needed and records completed work and check results in a changes log.' },
    'changes-template': { title: 'Changes record template', url: rpi + 'rpi-implement/templates/changes-log.md', note: 'Records what changed, how the plan was updated, which checks ran and what remains to be done.' },
    review: { title: 'rpi-review skill', url: rpi + 'rpi-review/SKILL.md', note: 'Produces one review per RPI task. Separates completion of the review from acceptance of the result, and identifies where follow-up work belongs.' },
    'review-template': { title: 'Review record template', url: rpi + 'rpi-review/templates/review-log.md', note: 'Records RV-xxx findings and suggested next actions. The Parent Decision Record preserves subsequent decisions without rewriting earlier ones.' },
    agent: { title: 'RPI Agent', url: hve + '.github/agents/hve-core/rpi-agent.agent.md', note: 'Optional agent that coordinates the phase skills. Offers four participation choices and supports Full Auto when requested.' },
    'advisory-helpers': { title: 'Optional, advisory RPI subagents / PR #2902', url: 'https://github.com/microsoft/hve-core/pull/2902', note: 'Merged September 18, 2026. Subagents are optional. The assistant responsible for the phase verifies their suggestions before recording evidence.' },
    loops: { title: 'Automatic RPI loops and walkthroughs / PR #2859', url: 'https://github.com/microsoft/hve-core/pull/2859', note: 'Merged September 8, 2026. Defines when RPI continues, asks for input or stops, and how follow-ups are handled.' },
    'gpt6-astra': { title: 'OpenAI: GPT-6 Astra model', url: 'https://developers.openai.com/api/docs/models/gpt-6-astra', note: '1,050,000-token context window; 922,000 maximum input and 128,000 maximum output tokens. Retrieved September 23, 2026.' },
    'gpt6-release': { title: 'OpenAI API changelog', url: 'https://developers.openai.com/api/docs/changelog', note: 'GPT-6 Astra released September 3, 2026. GPT-6 Sol and Luna released September 22.' },
    'gpt6-guide': { title: 'OpenAI: Using GPT-6', url: 'https://developers.openai.com/api/docs/guides/latest-model', note: 'OpenAI describes better coherence on long tasks and closer adherence to file-based instructions. It recommends auditing skills and files such as AGENTS.md.' },
    'opus-55': { title: 'Anthropic: Claude Opus 5.5', url: 'https://platform.claude.com/docs/en/models/opus-5-5/overview', note: 'Released September 22, 2026. 1M-token context window; 128K maximum output.' },
    'claude-context': { title: 'Anthropic: Context windows', url: 'https://platform.claude.com/docs/en/build-with-claude/context-windows', note: 'Explains what uses context space and warns that larger inputs can reduce accuracy and recall. Input includes instructions, messages, tool results and tool definitions.' },
    'copilot-models': { title: 'GitHub Docs: Supported AI models in Copilot', url: 'https://docs.github.com/en/copilot/reference/ai-models/supported-models', note: 'Lists GPT-6 Astra, Sol, Luna and Claude Opus 5.5 as generally available. Retrieved September 23, 2026; plan availability varies.' },
    'vscode-release': { title: 'VS Code 1.139.0 release', url: 'https://github.com/microsoft/vscode/releases/tag/1.139.0', note: 'Published September 23, 2026. The tool examples use source from this release.' },
    'vscode-search-tool': { title: 'VS Code 1.139.0: grep_search tool source', url: vscode + 'findTextInFilesTool.tsx', note: 'Defaults to 100 results with a 200-result cap; both are experiment-based settings. Reports how many matches were found and shown, and truncates long lines.' },
    'vscode-dir-tool': { title: 'VS Code 1.139.0: list_dir tool source', url: vscode + 'listDirTool.tsx', note: 'Lists the immediate contents of the requested directory. A root listing does not inspect nested files or explain what those files do.' },
    'vscode-read-tool': { title: 'VS Code 1.139.0: read_file tool source', url: vscode + 'readFileTool.tsx', note: 'Stops at 2,000 lines and truncates lines longer than 2,000 characters. Tells the model to continue with offset and limit.' },
    'vscode-sessions': { title: 'VS Code: Manage agent sessions', url: 'https://code.visualstudio.com/docs/agents/run/sessions/manage-sessions', note: 'Explains the context-usage control, automatic history compaction and starting a separate session for independent work.' },
    'vscode-debug': { title: 'VS Code: Debug chat interactions', url: 'https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view', note: 'Chat Debug shows request context and tool responses; Agent Debug Logs show calls and subagents. Logging requires setup and is not retroactive. The deck uses invented traces and explanatory context snapshots, not exported logs.' },
    'vscode-flow-layout': { title: 'VS Code 1.139.0: Agent Flow Chart renderer', url: 'https://github.com/microsoft/vscode/blob/1.139.0/src/vs/workbench/contrib/chat/browser/chatDebug/chatDebugFlowLayout.ts', note: 'Visual reference for typed node colors, colored gutters, rounded cards, arrows and purple subagent groups. The deck uses an original, enlarged renderer and focused trace excerpts; no upstream renderer or screenshots are bundled.' },
    'vscode-flow-view': { title: 'VS Code 1.139.0: Agent Flow Chart view', url: 'https://github.com/microsoft/vscode/blob/1.139.0/src/vs/workbench/contrib/chat/browser/chatDebug/chatDebugFlowChartView.ts', note: 'Breadcrumbs, event selection and the event-details pane informed the reconstruction. The presentation uses fitted excerpts rather than the native pan, zoom and filter controls.' },
    'vscode-debug-types': { title: 'VS Code 1.139.0: Debug event types', url: 'https://github.com/microsoft/vscode/blob/1.139.0/src/vs/workbench/contrib/chat/common/chatDebugService.ts', note: 'Defines model turns, tool calls, subagent invocations, responses and generic events. Compaction is not a dedicated type in this contract; the deck labels its compaction node as an illustrative generic event.' },
    'vscode-best-practices': { title: 'VS Code: Best practices for using AI', url: 'https://code.visualstudio.com/docs/agents/best-practices', note: 'Recommends focused tasks, relevant context and planning for complex changes. Covers fresh sessions and excluding noisy files from search.' },
    'vscode-context-guide': { title: 'VS Code: Context engineering flow', url: 'https://code.visualstudio.com/docs/agents/guides/context-engineering-guide', note: 'Recommends saving a plan, referencing it in a new implementation chat and reviewing the result in a fresh chat.' },
    'claude-code-practices': { title: 'Claude Code: Best practices', url: 'https://code.claude.com/docs/en/best-practices', note: 'Warns about long, unfocused sessions and repeated corrections. Recommends planning where useful and a direct edit for a small, clear change.' },
    'codex-practices': { title: 'OpenAI Codex: Best practices', url: 'https://learn.chatgpt.com/guides/best-practices', note: 'Recommends task-relevant files and examples, a clear goal, constraints and a way to check success. This is general Codex guidance, not an Astra-specific long-context benchmark. Planning helps with complex or ambiguous work.' },
    'anthropic-context-eng': { title: 'Anthropic: Effective context engineering for AI agents', url: 'https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents', note: 'Recommends selecting information that helps the next action. Describes context degradation across models, with differences in severity, and favors the simplest effective approach.' },
    'context-rot': { title: 'Chroma: Context rot', url: 'https://www.trychroma.com/research/context-rot', note: 'July 2025 study of 18 models on controlled tasks. Longer inputs often reduced performance, but the effect varied by model and task.' },
    distracted: { title: 'Shi et al.: LLMs can be easily distracted by irrelevant context', url: 'https://arxiv.org/abs/2302.00093', note: '2023 study of earlier models. Adding irrelevant sentences reduced accuracy on the math problems tested.' },
    'lost-middle': { title: 'Liu et al.: Lost in the middle', url: 'https://arxiv.org/abs/2307.03172', note: '2023 study of earlier models. Relevant information was used less reliably when placed in the middle of long inputs.' },
    'context-term': { title: 'Simon Willison: Context engineering', url: 'https://simonwillison.net/2025/Jun/27/context-engineering/', note: 'June 27, 2025 discussion of the term, with links to posts by Tobi Lutke and Andrej Karpathy. The slide summarizes the idea rather than quoting it.' }
  };

  const request = {
    kind: 'composer', phase: 'Request', state: 'RPI Agent selected',
    title: 'Start with the change you need', label: 'Reconstructed Copilot Chat input',
    body: 'Add a configurable log retention setting to every storage module. Use the repo\'s variable naming conventions.',
    attachments: ['modules/'], mode: 'RPI Agent',
    insight: 'RPI Agent checks what is already known and whether the task needs research.'
  };

  const participation = {
    kind: 'question', title: 'Choose how involved you want to be', label: 'Reconstructed Copilot question',
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

  const trackingRoot = ['.copilot-tracking/', 'changes/', 'docs/', 'src/', 'var/'];
  const trackingRead = { file: 'docs/tracking.md', start: 1, end: 40, total: 128 };
  const trackingMeanings = [
    { name: 'Planning notes', path: '.copilot-tracking/', use: 'Local, Git-ignored notes' },
    { name: 'Job receipts', path: 'var/jobs/', use: 'Runtime retry state' },
    { name: 'Release entries', path: 'changes/', use: 'Committed release inputs' }
  ];
  const trackingScene = {
    kind: 'workbench', workspace: 'sample-repo', focus: 'chat', agent: 'Agent',
    label: 'Scripted VS Code example / fictional repo'
  };
  const flowKinds = {
    modelTurn: 'Model turn',
    toolCall: 'Tool call',
    subagentInvocation: 'Subagent',
    agentResponse: 'Agent response',
    generic: 'Generic event'
  };
  const trackingFlow = {
    delegate: { kind: 'modelTurn', label: 'Model turn', sublabel: 'Agent / delegate', sourceStep: 0, messageIndex: 1 },
    explore: { kind: 'subagentInvocation', label: 'Explore', sublabel: 'Subagent', sourceStep: 0, messageIndex: 0, note: 'Explore runs the shown calls in its own context and returns a summary to the parent agent.' },
    search: { kind: 'toolCall', label: 'grep_search', sublabel: 'success / 1 match', parent: 'explore', sourceStep: 1, messageIndex: 0 },
    list: { kind: 'toolCall', label: 'list_dir', sublabel: 'success / root only', parent: 'explore', sourceStep: 2, messageIndex: 0 },
    read: { kind: 'toolCall', label: 'read_file', sublabel: 'success / lines 1-40', parent: 'explore', sourceStep: 3, messageIndex: 0 },
    summary: { kind: 'agentResponse', label: 'Explore response', sublabel: 'Summary returned', parent: 'explore', sourceStep: 4, messageIndex: 0 },
    resume: { kind: 'modelTurn', label: 'Model turn', sublabel: 'Agent / accept summary', sourceStep: 4, messageIndex: 1 },
    compaction: { kind: 'generic', label: 'Compaction', sublabel: 'Illustrative event', sourceStep: 5, messageIndex: 1, note: 'This generic event illustrates a later compaction. It is not a dedicated native node type or a claim that the original logs were deleted.' },
    write: { kind: 'modelTurn', label: 'Model turn', sublabel: 'Agent / write answer', sourceStep: 6, messageIndex: 0 },
    answer: { kind: 'agentResponse', label: 'Agent Response', sublabel: 'Answer produced', sourceStep: 6, messageIndex: 0, note: 'The response completed, but its claims are unsupported. This is a presenter assessment, not a failed tool call.' }
  };

  const demos = {
    tracking: {
      label: 'Tracking files',
      phases: ['Question', 'Tools', 'Explore', 'Compaction', 'Answer', 'Check'],
      steps: [
        {
          ...trackingScene, phase: 'Question', state: 'Sounds straightforward',
          title: 'One question, several possible meanings',
          editor: {
            kind: 'files', title: 'Explorer', caption: 'A fictional repository',
            files: trackingRoot
          },
          messages: [
            { kind: 'request', title: 'You', body: 'Explain how this repo uses tracking files.' },
            { kind: 'message', title: 'Copilot', body: 'I\'ll ask Explore to inspect the repo, then summarize what it finds.' }
          ],
          insight: 'A small question hides an open decision: what counts as a tracking file?'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Tools', state: 'One phrase searched', agent: 'Explore',
          title: 'The search finds a phrase, not every use',
          flow: { nodes: ['delegate', 'explore', 'search'], selected: 'search' },
          editor: {
            kind: 'code', title: 'Search results', caption: 'Literal text matches only',
            numbered: false,
            body: 'Query: "tracking files"\n\n1 match\n\ndocs/tracking.md:1\n# Tracking files'
          },
          messages: [
            { kind: 'tool', title: 'grep_search', detail: 'query: "tracking files"', body: 'docs/tracking.md:1\n# Tracking files' },
            { kind: 'message', title: 'Explore', body: 'I found the tracking-files documentation. I\'ll start there.' }
          ],
          insight: 'The phrase matches planning notes. Receipts and release entries use other words.'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Tools', state: 'Root directory only', focus: 'editor', agent: 'Explore',
          title: 'A directory listing does not explain behavior',
          flow: { nodes: ['explore', 'search', 'list'], selected: 'list' },
          editor: {
            kind: 'files', title: 'Explorer', caption: 'Root listed; nested files not inspected',
            files: trackingRoot
          },
          messages: [
            { kind: 'tool', title: 'list_dir', detail: 'path: sample-repo/', body: trackingRoot.join('\n') },
            { kind: 'message', title: 'Explore', body: 'I\'ll read docs/tracking.md.' }
          ],
          insight: 'A root listing gives names. Explore never inspects the worker or release code.'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Tools', state: 'Only lines 1-40 read', focus: 'editor', agent: 'Explore',
          title: 'The requested range misses the later section',
          flow: { nodes: ['explore', 'search', 'list', 'read'], selected: 'read', detailView: 'context' },
          readRange: trackingRead,
          editor: {
            kind: 'code', title: trackingRead.file,
            caption: 'Lines 84-90: not included in the read',
            startLine: 84,
            body: '## Other records\n\nJob receipts: var/jobs/\nPrevent duplicate jobs.\n\nRelease entries: changes/\nCommitted release inputs.'
          },
          messages: [
            { kind: 'tool', title: 'read_file', detail: `${trackingRead.file} / lines ${trackingRead.start}-${trackingRead.end} of ${trackingRead.total}`, body: '# Tracking files\n## Planning notes\nLocal research and plans.\nIn .copilot-tracking/.\nIgnored by Git.' },
            { kind: 'message', title: 'Explore', body: 'These are local planning notes.' }
          ],
          insight: 'Only the requested lines reach Explore. This is not the 2,000-line tool cap.'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Explore', state: 'Limits dropped',
          title: 'The Explore summary sounds more complete',
          flow: { nodes: ['explore', 'read', 'summary', 'resume'], selected: 'summary' },
          editor: {
            kind: 'code', title: 'Checked evidence', caption: 'What the investigation actually covered',
            numbered: false,
            body: 'Search: "tracking files"\nListing: repo root\nRead: docs/tracking.md 1-40\n\nNot checked:\n- Other terms and folders\n- Remaining file sections'
          },
          messages: [
            { kind: 'helper', title: 'Explore returned', body: 'Tracking files are local planning notes in .copilot-tracking/. They are ignored by Git.' },
            { kind: 'message', title: 'Copilot', body: 'That gives me the repo-wide convention.' }
          ],
          insight: 'Explore drops the limits. The parent mistakes one convention for a repo-wide fact.'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Compaction', state: 'Tool detail omitted',
          title: 'Compaction keeps the conclusion, loses the limits',
          flow: { nodes: ['explore', 'summary', 'resume', 'compaction'], selected: 'compaction' },
          editor: {
            kind: 'code', title: 'Before compaction', caption: 'Details omitted from the next model input',
            numbered: false,
            body: 'query: "tracking files"\nlist_dir: root only\nread_file: 1-40 of 128\n\nNo evidence about:\n- Runtime consumers\n- Other tracking locations'
          },
          messages: [
            { kind: 'notice', title: 'Conversation compacted', body: 'Later, after more tool calls.' },
            { kind: 'summary', title: 'Retained summary / illustrative', body: 'Task: explain tracking files.\nFinding: local planning notes.\nNext: write the explanation.' }
          ],
          insight: 'Read limits vanish from this model input. The original logs are not erased.'
        },
        {
          ...trackingScene, kind: 'agent-flow', phase: 'Answer', state: 'Unsupported claims',
          title: 'The final answer fills the gaps with assumptions',
          flow: { nodes: ['compaction', 'write', 'answer'], selected: 'answer' },
          editor: {
            kind: 'code', title: 'Evidence check', caption: 'Presenter annotations on the answer',
            numbered: false,
            body: '"All tracking files"\nNo repo-wide coverage.\n\n"Never affect runtime"\nNo runtime code inspected.\n\n"Can be deleted safely"\nNo lifecycle checked.'
          },
          messages: [
            { kind: 'answer', title: 'Copilot / incorrect in this example', body: 'All tracking files live in .copilot-tracking/ and are ignored by Git. They never affect runtime behavior and can be deleted safely.' }
          ],
          insight: 'The agent invents "all", "never" and "safe to delete" without checking those claims.'
        },
        {
          ...trackingScene, phase: 'Check', state: 'Three different uses', focus: 'editor',
          title: 'The same question needed three separate checks',
          editor: {
            kind: 'definitions', title: 'What the repo contains', caption: 'Scripted facts missed by the answer',
            meanings: trackingMeanings
          },
          messages: [
            { kind: 'message', title: 'A supported answer would say', body: 'I found the planning-note convention. I haven\'t checked the worker receipts or release records yet.' },
            { kind: 'notice', title: 'Before generalizing', body: 'Clarify the term, finish the reads and inspect the consumers. Save the evidence and its limits.' }
          ],
          insight: 'Check each meaning and its consumers before giving a repo-wide answer.'
        }
      ]
    },
    rpi: {
      label: 'Log retention example',
      phases: ['Request', 'Research', 'Plan', 'Implement', 'Review'],
      steps: [
        request,
        {
          kind: 'code', phase: 'Research', state: 'Search is incomplete',
          title: 'The search leaves 212 matches unread', file: 'grep_search result', surface: 'tool', label: 'Reconstructed tool output',
          body: 'Found 312 matches in 14 files for "variable"\n(showing 100 matches in 14 files)\n\nmodules/blob/variables.tf\n3:variable "resource_prefix" {\n11:variable "location" {\n... (19 more matches in this file)\n\nmodules/legacy-table/variables.tf\n2:variable "prefix" {\n... (24 more matches in this file)',
          insight: 'Only 100 of 312 matches are shown. Search each module before drawing a repo-wide conclusion.'
        },
        {
          kind: 'question', phase: 'Research', state: 'Decision needed',
          title: 'Resolve the naming exception', label: 'Reconstructed Copilot question',
          body: 'Two legacy modules use prefix instead of resource_prefix. Should this change rename them?',
          options: [
            { label: 'Keep the existing names', detail: 'Add the setting to every module. Leave renaming for separate work.' },
            { label: 'Rename them as part of this change', detail: 'Use the same names everywhere. Callers will need updating.' },
            { label: 'Leave the legacy modules out', detail: 'Those two modules won\'t get the setting. This narrows the request.' }
          ],
          selected: 0,
          insight: 'Record the answer as D1, alongside the evidence for the two naming patterns.'
        },
        {
          kind: 'code', phase: 'Plan', state: 'Critique: Revise; finding resolved',
          title: 'Catch a missing test before coding', file: 'log-retention-plan.md', label: 'Illustrative excerpt',
          body: '#### [ ] P01-T01: Add log retention\nRequirements:\n* FR-001: Default to 30 days.\n* FR-002: Accept only 1 to 365 days.\n* FR-003: Keep legacy names (D1).\n\n## Critique Disposition\nPC-001: No check for out-of-range values.\nResolved: test 0 and 366 in each module.',
          insight: 'The planner adds checks for invalid values. They must cover the legacy modules too.'
        },
        {
          kind: 'implementation', phase: 'Implement', state: 'Reported complete',
          title: 'The agent reports the work as done', label: 'Scripted implementation report',
          plan: 'log-retention-plan.md', phaseTitle: 'P01 / Log retention',
          tasks: ['P01-T01 Add the variable', 'P01-T02 Run the checks'],
          changes: '## Validation Record\nterraform validate: Passed\nterraform test: Passed\nScope: not recorded',
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
          insight: 'The log says checks passed, but not which modules they covered. FR-002 still needs verification.'
        },
        {
          kind: 'code', phase: 'Review', state: 'Complete / Defects found',
          title: 'Two modules are missing validation', file: 'log-retention-review.md', label: 'Illustrative excerpt',
          body: '### RV-001 [Medium]: legacy modules accept 0\nExpected: FR-002 in all 14 modules.\nObserved: legacy-table and legacy-files lack\nthe validation block.\nRoute: rpi-implement (P01-T01)\n\n## Parent Decision Record\nExecution: Complete\nOutcome: Defects found',
          insight: 'Return P01-T01 to implementation. Passing checks didn\'t establish coverage of every module.'
        }
      ]
    }
  };

  function flowTrace(ids) {
    if (!Array.isArray(ids) || !ids.length || new Set(ids).size !== ids.length) {
      throw new Error('A flow excerpt requires unique event IDs.');
    }
    const nodes = ids.map(id => {
      if (!Object.hasOwn(trackingFlow, id)) throw new Error(`Unknown flow event: ${id}`);
      return { id, ...trackingFlow[id] };
    });
    const closedGroups = new Set();
    let group = null;
    nodes.forEach((node, index) => {
      const nextGroup = node.kind === 'subagentInvocation' ? node.id : node.parent ?? null;
      if (group !== nextGroup && group) closedGroups.add(group);
      if (nextGroup && closedGroups.has(nextGroup)) throw new Error('Subagent events must stay together.');
      if (node.parent && !nodes.slice(0, index).some(parent => parent.id === node.parent && parent.kind === 'subagentInvocation')) {
        throw new Error(`Missing preceding subagent: ${node.parent}`);
      }
      group = nextGroup;
    });
    return { nodes, edges: ids.slice(1).map((id, index) => [ids[index], id]) };
  }

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
  globalThis.DeckContent = { sources, examples, demos, trackingFlow, flowKinds, flowTrace, moveStep, diffStats };
}());
