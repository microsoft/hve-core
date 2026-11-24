// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
// cspell:words Bartosz Ciechanowski
(function () {
  'use strict';
  const hve = 'https://github.com/microsoft/hve-core/blob/301cad63b340d92066c599b28ae85931982e461a/';
  const skill = '.github/skills/';
  const sources = {
    baseline: { title: 'April 1 snapshot: Task Researcher and its subagent', url: 'https://github.com/microsoft/hve-core/blob/62c97a7447a914293c0bf2a94c72db2a4fd3599c/.github/agents/hve-core/task-researcher.agent.md', note: 'Repository state on April 1, 2026. Task Researcher already delegated research.' },
    skills: { title: 'Skill-forward RPI workflows / PR #1953', url: 'https://github.com/microsoft/hve-core/pull/1953', note: 'June 24 Pacific / June 25 UTC, 2026; merged commit 44b42d40.' },
    consolidation: { title: 'Consolidate lifecycle around reusable skills / PR #2474', url: 'https://github.com/microsoft/hve-core/pull/2474', note: 'July 26 Pacific / July 27 UTC, 2026. Removes the legacy task and Prompt Builder entry-point files.' },
    'one-plugin': { title: 'Consolidate HVE Core into one plugin / PR #2712', url: 'https://github.com/microsoft/hve-core/pull/2712', note: 'August 16, 2026. Earlier plugin support already existed.' },
    loops: { title: 'Automatic RPI loops and phase walkthroughs / PR #2859', url: 'https://github.com/microsoft/hve-core/pull/2859', note: 'September 8, 2026. Explicit participation, progression and stop rules.' },
    advisory: { title: 'Optional, advisory subagents and the HVE Builder review pass / PR #2902', url: 'https://github.com/microsoft/hve-core/pull/2902', note: 'September 18, 2026. RPI helpers become read-only; RPI Planner and rpi-quick are removed. HVE Builder drops hve-builder-tester, freeze, sandbox and the behavior gate, and adds the optional HVE Builder Reviewer.' },
    'optional-steps': { title: 'Optional plan critique and Review; no RPI scripts / PR #3061', url: 'https://github.com/microsoft/hve-core/pull/3061', note: 'September 28 Pacific / September 29 UTC, 2026. Removes the plan hash helper; adds critique=skip and the RPI Agent Review step setting.' },
    'aliases-removed': { title: 'Prompt Builder aliases removed / PR #3113', url: 'https://github.com/microsoft/hve-core/pull/3113', note: 'October 5, 2026. Breaking: prompt-builder, prompt-analyze and prompt-refactor are removed. Also documents that the CLI registration tracks main.' },
    'prompts-retired': { title: 'Remaining prompts move into skills and agents / PR #3111', url: 'https://github.com/microsoft/hve-core/pull/3111', note: 'October 7, 2026. Breaking: all 48 .prompt.md files are retired; 10 new skills cover prompts that had no other owner.' },
    lanes: { title: 'Parallel RPI lanes; one critique and one Review / PR #3238', url: 'https://github.com/microsoft/hve-core/pull/3238', note: 'October 19, 2026. Adds RPI Plan Critic lenses, per-lane effort, subagents=none and child loops that skip critique and Review by default.' },
    research: { title: 'rpi-research: evidence gathering and optional helpers', url: hve + skill + 'rpi/rpi-research/SKILL.md', note: 'Standalone skill. Starts at the balanced posture; accepts posture=, effort= and subagents=. Optional RPI Researcher lanes return suggestions only.' },
    'research-template': { title: 'Current research artifact structure', url: hve + skill + 'rpi/rpi-research/templates/research.md', note: 'Reader-first findings, alternatives, decisions and readiness; supporting Research Record.' },
    'research-lanes': { title: 'rpi-research: optional helpers and lane effort', url: hve + skill + 'rpi/rpi-research/references/research.md', note: 'Each independent question gets its own narrow lane, and lanes go out in one parallel batch. Effort is low when a tool returns a complete result, such as a search that lists every match, and max when a lane reads for meaning. RPI Researcher declares max in its frontmatter.' },
    'review-lanes': { title: 'rpi-review: lane reasoning effort', url: hve + skill + 'rpi/rpi-review/references/review.md', note: 'Low for tool checks such as task markers against the changes record, high when comparing against written requirements, max for behavior no requirement states. RPI Reviewer declares max in its frontmatter.' },
    plan: { title: 'rpi-plan: plan drafting and the default critique', url: hve + skill + 'rpi/rpi-plan/SKILL.md', note: 'Runs at most one critique per plan; critique=standard, deep or skip; critique-effort= and subagents=.' },
    'plan-template': { title: 'Current single implementation-plan structure', url: hve + skill + 'rpi/rpi-plan/templates/implementation-plan.md', note: 'Pxx and Pxx-Txx; Goals, Requirements, Details, References, Dependencies.' },
    critique: { title: 'rpi-plan-critique: plan assessment', url: hve + skill + 'rpi/rpi-plan-critique/SKILL.md', note: 'Execution status (Complete, Partial, Blocked, Not produced) is separate from the Pass, Revise or Blocked verdict. The parent assigns PC-xxx IDs.' },
    'critique-lenses': { title: 'Plan critique lens assessment', url: hve + skill + 'rpi/rpi-plan-critique/references/lens-assessment.md', note: 'Coverage (low), Evidence, Executability and Risk (medium) for an initial critique; Reconciliation for a follow-up. Lenses run in one parallel batch through RPI Plan Critic.' },
    implement: { title: 'rpi-implement: follow the plan and record changes', url: hve + skill + 'rpi/rpi-implement/SKILL.md', note: 'Follows the plan, updates it as needed, checks off work and keeps a condensed changes log. Does not require a critique.' },
    'changes-template': { title: 'Current changes record', url: hve + skill + 'rpi/rpi-implement/templates/changes-log.md', note: 'Completed work, plan updates, validation and pre-review reconciliation.' },
    review: { title: 'rpi-review: findings and final decisions', url: hve + skill + 'rpi/rpi-review/SKILL.md', note: 'Optional RPI Reviewer lanes compare bounded slices of evidence. The parent assigns RV-xxx IDs and records outcomes. One review per task.' },
    'rpi-reviewer': { title: 'RPI Reviewer subagent', url: hve + '.github/agents/hve-core/subagents/rpi-reviewer.agent.md', note: 'Read-only. Returns candidate findings with evidence locations; cites where each requirement it calls consistent is met. Claude Haiku 5.5 by default.' },
    'review-template': { title: 'Current review record and Parent Decision Record', url: hve + skill + 'rpi/rpi-review/templates/review-log.md', note: 'Append-only parent decision events; review execution versus final outcome.' },
    agent: { title: 'RPI Agent: optional user-selected lifecycle wrapper', url: hve + '.github/agents/hve-core/rpi-agent.agent.md', note: 'Four participation choices; before-implementation boundary; Planning critique and Review step settings; child loops skip both by default.' },
    builder: { title: 'HVE Builder skill', url: hve + skill + 'hve-core/hve-builder/SKILL.md', note: 'Create, improve, refactor, replace, review or validate prompts, instructions, agents, subagents and skills. Defaults to create, improve and refactor together.' },
    'builder-contract': { title: 'HVE Builder workflow contract', url: hve + skill + 'hve-core/hve-builder/references/workflow-contract.md', note: 'Composable modes, the review pass, parent-owned convergence and the Pass, Revise, Deferred or Blocked outcome.' },
    'builder-dispatch': { title: 'HVE Builder stage dispatch', url: hve + skill + 'hve-core/hve-builder/references/stage-dispatch.md', note: 'The rpi-research bridge and when to dispatch HVE Builder Reviewer. Closure checks only the named finding IDs.' },
    'builder-reviewer': { title: 'HVE Builder Reviewer subagent', url: hve + '.github/agents/hve-core/subagents/hve-builder-review.agent.md', note: 'Read-only, fresh context. Returns severity-graded findings and an advisory verdict. GPT-6 Luna since PR #2992 (September 23).' },
    'builder-rubric': { title: 'HVE Builder review rubric', url: hve + skill + 'hve-core/hve-builder/references/review-rubric.md', note: 'Review dimensions, the Critical to Low severity scale and the Pass, Revise or Blocked verdict.' },
    'builder-extensions': { title: 'Extending HVE Builder and other HVE workflows', url: hve + skill + 'hve-core/hve-builder/references/extending-hve-builder.md', note: 'RPI phase extensions: the description is the contract. Helper subagents return suggestions and write nothing.' },
    'builder-introduction': { title: 'HVE Builder introduction / PR #2438', url: 'https://github.com/microsoft/hve-core/pull/2438', note: 'Merged July 11, 2026 at 19:38 UTC. Commit d293ea35 adds hve-builder/SKILL.md, absent in its parent. PR title: Align HVE Builder artifact workflows.' },
    manifest: { title: 'HVE Core root plugin manifest', url: hve + 'plugin.json', note: 'Version 3.2.2 in the October 21 source snapshot; 61 agents, 85 skills, 53 instructions; no prompts or hooks.' },
    marketplace: { title: 'HVE Core marketplace locator', url: hve + '.github/plugin/marketplace.json', note: 'Marketplace hve-core; sole plugin hve-core; relative source "." points to repository root.' },
    'marketplace-clarity': { title: 'Marketplace registration behavior / PR #2799', url: 'https://github.com/microsoft/hve-core/pull/2799', note: 'September 9, 2026. Registration versus installation distinction.' },
    'cli-plugins-doc': { title: 'HVE Core guide: install with Copilot CLI plugins', url: hve + 'docs/getting-started/methods/cli-plugins.md', note: 'The registration tracks main. Refresh the marketplace before updating; re-add older release-channel or tag registrations.' },
    'cli-guide': { title: 'GitHub Docs: finding and installing CLI plugins', url: 'https://github.com/github/docs/blob/de20b82f73a9b545db514b5f6a2bb33ff041febb/content/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing.md', note: 'Retrieved September 10, 2026. OWNER/REPO and plugin@marketplace grammar. Unqualified source is moving, not version pinned.' },
    'cli-release': { title: 'Copilot CLI v1.0.83 release', url: 'https://github.com/github/copilot-cli/releases/tag/v1.0.83', note: 'Latest release observed on September 10; published September 4, 2026. No CLI installation was performed.' },
    'vscode-release': { title: 'VS Code 1.137.0 release', url: 'https://github.com/microsoft/vscode/releases/tag/1.137.0', note: 'Latest release observed September 10; published September 9, 2026.' },
    'vscode-plugins': { title: 'VS Code: agent plugins, source install and CLI discovery', url: 'https://github.com/microsoft/vscode-docs/blob/a73717c84e7d89da2cb37f28c7fec130c8cf6195/docs/agent-customization/agent-plugins.md', note: 'Official docs retrieved September 10, approved September 9. Published page: code.visualstudio.com/docs/agent-customization/agent-plugins. Check enablement, trust and organization policy.' },
    'vscode-install': { title: 'VS Code 1.137.0 source-install service', url: 'https://github.com/microsoft/vscode/blob/1.137.0/src/vs/workbench/contrib/chat/browser/pluginInstallService.ts', note: 'Released implementation corroborates source install, marketplace discovery and trust gate. Not a runtime installation test.' },
    'vscode-discovery': { title: 'VS Code 1.137.0 CopilotCliAgentPluginDiscovery', url: 'https://github.com/microsoft/vscode/blob/1.137.0/src/vs/workbench/contrib/chat/common/plugins/agentPluginServiceImpl.ts', note: 'Scans IPathService.userHome()/.copilot/installed-plugins/<marketplace>/<plugin>. Same accessible home, not cross-machine synchronization.' },
    'vscode-storage': { title: 'VS Code-managed plugin repository storage', url: 'https://github.com/microsoft/vscode/blob/4e32846cd87ecfdbd6eb49e34d9bdad550d854c3/src/vs/workbench/contrib/chat/browser/agentPluginRepositoryService.ts', note: 'Development source for 1.138.0 shows separate VS Code storage. Manual sharing and other client configurations may differ.' },
    'dark-modern': { title: 'Official VS Code Dark Modern palette reference', url: 'https://github.com/microsoft/vscode/blob/4e32846cd87ecfdbd6eb49e34d9bdad550d854c3/extensions/theme-defaults/themes/dark_modern.json', note: 'Factual palette reference: #181818 chrome, #1F1F1F editor, #CCCCCC text, #85B6FF slash-command accent. Original deck styling; not copied VS Code CSS.' },
    'workbench-design': { title: 'Official VS Code workbench layout reference', url: 'https://github.com/microsoft/vscode/blob/4e32846cd87ecfdbd6eb49e34d9bdad550d854c3/src/vs/workbench/browser/media/part.css', note: 'Title, content and action layout used as a reference for enlarged HTML reconstructions.' },
    reveal: { title: 'reveal.js local-file installation', url: 'https://revealjs.com/installation/', note: 'Version 6.0.2 pinned from public npm. MIT license is bundled locally. No external Markdown or server-dependent speaker plugin used.' },
    'visual-provenance': { title: 'Vercel Geist design-system reference', url: 'https://vercel.com/geist/introduction', note: 'Prior September 10 form research also considered Linear, Raycast, Resend and Bartosz Ciechanowski. Original layout/graphics; no borrowed branding or artwork.' }
  };

  const vscode = 'https://github.com/microsoft/vscode/blob/645f29cc3176500b4b5762ba887cf2a7f0ffdf2c/src/vs/workbench/contrib/chat/';
  Object.assign(sources, {
    'copilot-composer': { title: 'VS Code 1.137: Copilot input and editing-session layout', url: vscode + 'browser/widget/input/chatInputPart.ts', note: 'Direct source research, September 10, 2026. Context chips, editor, mode/model toolbar and above-composer editing slot. Reconstructed display only.' },
    'copilot-questions': { title: 'VS Code 1.137: question carousel and completed answers', url: vscode + 'browser/widget/chatContentParts/chatQuestionCarouselPart.ts', note: 'Submission replaces the question and options with an answer summary. The deck uses scripted states and the supplied screenshot for styling.' },
    'agent-flow-chart': { title: 'Agent Debug Log panel and Agent Flow Chart (Preview)', url: 'https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view', note: 'Official terminology and visual reference, retrieved September 10, 2026. Real logs require enablement; the displayed tool/subagent graph is an invented explanatory trace.' },
    'agent-flow-source': { title: 'VS Code 1.137: typed debug nodes and parent relationships', url: vscode + 'browser/chatDebug/chatDebugFlowGraph.ts', note: 'Defines user, model, tool, subagent and response events. The deck draws an original graph using invented example events.' },
    'copilot-diff': { title: 'VS Code 1.137: changed-file and +/- summary', url: vscode + 'browser/widget/chatContentParts/chatMultiDiffContentPart.ts', note: 'Changed-file count, filenames, insertion/deletion statistics and Open Changes entry point; the inline diff is a separate view.' },
    'edit-review': { title: 'VS Code: review and revert agent changes', url: 'https://code.visualstudio.com/docs/agents/run/review-code-edits', note: 'Agent Host applies edits directly; older extension-host pending edits have Keep/Undo. The deck does not pretend to accept, reject or restore actual edits.' },
    'customizations-editor': { title: 'VS Code 1.137: Agent Customizations sidebar and Plugins page', url: vscode + 'browser/aiCustomization/aiCustomizationManagementEditor.ts', note: 'Category navigation and searchable content area. Original, presentation-enlarged reconstruction; categories vary with the selected agent harness.' },
    'plugins-page': { title: 'VS Code 1.137: Plugins page source-install button', url: vscode + 'browser/aiCustomization/pluginListWidget.ts', note: 'Installed and Available sections; Install from Source action, with Install Plugin from Source tooltip. Sample empty/installed states omit unrelated marketplace content.' },
    'source-quick-input': { title: 'VS Code 1.137: source-entry quick input', url: vscode + 'browser/actions/chatPluginActions.ts', note: 'InstallFromSourceAction opens a top quick-input box accepting owner/repo, a Git URL or a local folder. The deck uses microsoft/hve-core; Enter/Escape only advance or reverse the local illustration.' }
  });

  const participationQuestion = {
    kind: 'question',
    body: 'How would you like us to work on this?',
    selected: 2,
    options: [
      { label: 'Handle it end to end', detail: 'Continue through Review and required follow-ups. The agent makes ordinary decisions.' },
      { label: 'Keep going, but check with me', detail: 'Continue automatically; ask me about unclear decisions and direction.' },
      { label: 'Research and plan with me', detail: 'Keep me involved in Research and Plan, then stop before Implementation.' },
      { label: 'Work through each phase with me', detail: 'Discuss the work and wait for me to choose each phase transition.' }
    ]
  };

  const graphs = {
    research: {
      title: 'Research the snack queue with two parallel lanes',
      batch: { label: 'ONE PARALLEL BATCH', members: ['lane-search', 'lane-docs'], x: 330, y: 136, width: 784, height: 196, labelX: 722, labelY: 244 },
      nodes: [
        { id: 'request', kind: 'user', label: 'User request', detail: 'Snack Mission Control', x: 28, y: 18, width: 262, height: 68 },
        { id: 'model', kind: 'model', label: 'Model turn', detail: 'rpi-research', x: 340, y: 18, width: 300, height: 68 },
        { id: 'response', kind: 'response', label: 'Research synthesis', detail: 'Parent verifies before citing', x: 760, y: 18, width: 342, height: 68 },
        { id: 'read', kind: 'tool', label: 'read_file', detail: 'Current queue source', x: 28, y: 158, width: 262, height: 66 },
        { id: 'lane-search', kind: 'subagent', label: 'RPI Researcher', detail: 'Reset paths, low effort', x: 348, y: 158, width: 360, height: 66 },
        { id: 'lane-docs', kind: 'subagent', label: 'RPI Researcher', detail: 'Storage docs, max effort', x: 736, y: 158, width: 360, height: 66 },
        { id: 'search', kind: 'tool', label: 'grep_search', detail: 'Every reset call', x: 348, y: 254, width: 360, height: 66 },
        { id: 'web', kind: 'tool', label: 'fetch_webpage', detail: 'localStorage behavior', x: 736, y: 254, width: 360, height: 66 }
      ],
      edges: [
        ['request', 'model'], ['model', 'response'], ['model', 'read'],
        ['model', 'lane-search'], ['model', 'lane-docs'], ['lane-search', 'search'], ['lane-docs', 'web']
      ]
    },
    plan: {
      title: 'After / P01: Local snack voting',
      nodes: [
        { id: 'vote', label: 'Vote action', detail: 'Added: local input', x: 35, y: 40, width: 270, height: 78 },
        { id: 'state', label: 'Session state', detail: 'Added: no stored history', x: 425, y: 40, width: 280, height: 78 },
        { id: 'count', label: 'Visible count', detail: 'Added: rendered result', x: 825, y: 40, width: 270, height: 78 },
        { id: 'reset', label: 'Reset action', detail: 'Added: clear + render', x: 425, y: 235, width: 280, height: 78 }
      ],
      edges: [['vote', 'state'], ['state', 'count'], ['reset', 'state'], ['reset', 'count']]
    }
  };

  function mermaidSource(graph) {
    return ['flowchart LR', ...graph.nodes.map(node => `  ${node.id}["${node.label}"]`),
      ...graph.edges.map(([from, to]) => `  ${from} --> ${to}`)].join('\n');
  }

  function diffStats(rows) {
    return {
      added: rows.filter(row => row.type === 'add').length,
      removed: rows.filter(row => row.type === 'remove').length
    };
  }

  const resetDiff = [
    { type: 'context', old: 1, next: 1, text: 'function reset() {' },
    { type: 'remove', old: 2, next: '', text: '  queue = [];' },
    { type: 'add', old: '', next: 2, text: '  votes.clear();' },
    { type: 'add', old: '', next: 3, text: '  renderVotes();' },
    { type: 'context', old: 3, next: 4, text: '}' }
  ];

  // Model shown in reconstructed Chat composers. Display only; nothing is sent.
  const chatModel = 'GPT-6.1 Sol';

  const rpiAgentSelection = {
    kind: 'agent-picker',
    body: 'Select RPI Agent in the dropdown below the Chat input.'
  };

  const demos = {
    rpi: {
      label: 'RPI state', phases: ['Intake', 'Research', 'Plan', 'Critique', 'Boundary', 'Implement', 'Review'],
      steps: [
        { phase: 'Intake', title: 'Describe the app and its limits', state: 'Request drafted', context: 'GitHub Copilot Chat', kind: 'composer', mode: 'RPI Agent', attachments: ['app.js', 'README.md'], body: 'Build Snack Mission Control, a small voting app.\nKeep it local, without accounts or a backend.\nResearch and plan with me before changing code.', insight: 'The request includes source files and a stop before coding.' },
        { phase: 'Intake', title: 'Choose the planning-only mode', state: 'Before implementation', context: 'GitHub Copilot Chat', kind: 'answer', body: 'How would you like us to work on this?', answer: 'Research and plan with me', detail: 'Discuss Research and Planning decisions, then stop before Implementation.', insight: 'A later resume keeps this stop condition unless the user changes it.' },
        { phase: 'Research', title: 'Inspect the research calls', state: 'Gathering evidence', context: 'Agent Debug Logs', kind: 'graph', graph: 'research', body: 'Example model turn, tool call and two helper lanes.', insight: 'Both lanes run in one batch. The parent checks their sources before citing them.' },
        { phase: 'Research', title: 'Read the findings and recommendation', state: 'Research ready', context: 'snack-queue-research.md', kind: 'code', body: '## Executive Summary\nUse session-only state for this app.\n\n## Findings\nC1: current state is in memory.\nW1: localStorage persists on the device.\n\n## Recommendation and Alternatives\nKeep votes in memory; defer persistence.', insight: 'The research document explains how the sources support the recommendation.' },
        { phase: 'Research', title: 'Decide whether votes should persist', state: 'Awaiting an answer', context: 'GitHub Copilot Chat', kind: 'question', body: 'Should votes survive a page reload?', options: [{ label: 'This session only', detail: 'Clear on reload; keep no voting history.', recommended: true }, { label: 'Keep on this device', detail: 'Persist locally between sessions.' }], insight: 'The answer determines how the app stores votes.' },
        { phase: 'Research', title: 'Record the storage decision', state: 'Decision recorded', context: 'GitHub Copilot Chat', kind: 'answer', body: 'Should votes survive a page reload?', answer: 'This session only', detail: 'Add a visible Reset. Do not retain names or voting history.', insight: 'The assistant records the answer before writing the plan.' },
        { phase: 'Plan', title: 'Review the plan diagram', state: 'Plan drafted', context: 'snack-queue-plan.md', kind: 'plan', graph: 'plan', body: 'The After diagram shows local voting, session state, the count and reset.', insight: 'The source toggle shows the same nodes and connections as the diagram.' },
        { phase: 'Plan', title: 'Specify what Reset clears', state: 'Awaiting an answer', context: 'GitHub Copilot Chat', kind: 'question', body: 'What should the Reset action clear?', options: [{ label: 'Votes and the visible count', detail: 'Return the session to zero.', recommended: true }, { label: 'Only the displayed queue', detail: 'Retain accumulated vote totals.' }], insight: 'Settle this behavior before the assistant edits the source.' },
        { phase: 'Plan', title: 'Update the reset requirement', state: 'Requirement agreed', context: 'GitHub Copilot Chat', kind: 'answer', body: 'What should the Reset action clear?', answer: 'Votes and the visible count', detail: 'FR-002: clear the session and display zero immediately.', insight: 'The answer gives implementation a specific result to check.' },
        { phase: 'Critique', title: 'Address the missing plan check', state: 'Finding resolved', context: 'plan-critique.md', kind: 'code', body: 'PC-001: Add a visible-reset check.\nLens: Coverage\n\n## Critique Disposition\nResolved: check stored votes and\nthe displayed count after Reset.\n\nExecution: Complete\nVerdict on original plan: Revise', insight: 'Four lenses ran side by side. The planning assistant fixes the plan; no second critique runs.' },
        { phase: 'Boundary', title: 'Wait at the agreed stop point', state: 'Paused at Plan', context: 'RPI Agent state / excerpt', kind: 'code', body: '{\n  "mode": "manual",\n  "active_phase": "Plan",\n  "status": "active",\n  "session_status": "stopped",\n  "next_action": {\n    "action": "Await explicit implementation"\n  }\n}', insight: 'The plan is ready. Implementation still needs the user to start it.' },
        { phase: 'Boundary', title: 'Start implementation', state: 'Implementation authorized', context: 'GitHub Copilot Chat', kind: 'composer', mode: 'RPI Agent', attachments: ['snack-queue-plan.md'], body: '/rpi-implement\nBuild the agreed local-only plan.\nMake Reset clear votes and the displayed count.', insight: 'This request authorizes the implementation phase in the example.' },
        { phase: 'Implement', title: 'Check the completed tasks and diff', state: 'Implementation complete', context: 'Implementation result', kind: 'implementation', body: 'Completed tasks, changes excerpt and reset diff.', tasks: ['P01-T01  Add local voting', 'P01-T02  Render visible reset'], changes: '## Completed Work\nP01: voting and reset done.\n## Validation Record\nReset -> visible count = 0.', file: 'app.js', diff: resetDiff, insight: 'Compare the task list and check results with the code changes.' },
        { phase: 'Review', title: 'Request an acceptance review', state: 'Review authorized', context: 'GitHub Copilot Chat', kind: 'composer', mode: 'RPI Agent', attachments: ['snack-queue-plan.md', 'changes.md'], body: '/rpi-review\nCompare the completed work with the plan,\ncritique dispositions and check results.', insight: 'Manual mode requires the user to start Review separately.' },
        { phase: 'Review', title: 'Read the final review decision', state: 'Decision recorded', context: 'review.md / example', kind: 'code', body: '## Parent Decision Record\nReview execution: Complete\nFinal outcome: Conformant\nFinding decisions: none required\n\n## Validation Evidence\nReset -> visible count = 0: current\n\nNo remaining work in scope.', insight: 'This passing example has no required follow-up.' }
      ]
    },
    builder: {
      label: 'HVE Builder state', phases: ['Scope', 'Author', 'Validate', 'Review', 'Correct', 'Handoff'],
      steps: [
        { phase: 'Scope', title: 'Ask for a research skill', state: 'Request drafted', context: 'GitHub Copilot Chat', kind: 'composer', mode: 'Agent', attachments: ['research.md'], body: '/hve-builder\nCreate a Snack Evidence skill for research.\nReport missing counts as unknown.\nDo not order snacks or make external changes.', insight: 'No mode is named, so HVE Builder creates, improves and refactors together.' },
        { phase: 'Scope', title: 'Agree on the scope', state: 'Scope recorded', context: 'Scope record / example', kind: 'code', body: 'Target: snack-evidence (new skill)\nModes: create, improve, refactor (default)\nWrite boundary: the new skill folder\nUse: during research on snack stock\n\nRequirements:\n* Separate counted stock from estimates.\n* Report missing counts as unknown.\n* Read-only; the research phase decides.', insight: 'HVE Builder calls rpi-research only when a decision needs more evidence.' },
        { phase: 'Author', title: 'Write the candidate', state: 'Candidate written', context: 'snack-evidence / SKILL.md / excerpt', kind: 'code', body: '---\nname: snack-evidence\ndescription: Use during research when\n  a task involves office snack stock.\n---\n## Evidence criteria\nRecord the source and observation time.\nSeparate counted stock from estimates.\n\nBoundary: read-only; the phase decides.', insight: 'The description names the phase, so rpi-research can find the skill.' },
        { phase: 'Validate', title: 'Run the local checks first', state: 'Checks passed', context: 'Local validation / example', kind: 'code', body: 'Frontmatter        Passed\nSkill structure    Passed\nMarkdown links     Passed\n\nOpen mechanical findings: none\nCandidate ready for the review pass', insight: 'Known mechanical work is finished before the review starts.' },
        { phase: 'Review', title: 'Read the reviewer\'s suggestions', state: 'Suggestions returned', context: 'HVE Builder Reviewer / example', kind: 'code', body: 'Fresh context, read-only\nSuggested verdict: Revise (advisory)\n\nR-001  High, required\n  A missing count has no rule, so\n  an estimate could be reported.\n\nR-002  Low, advisory\n  Rename "Evidence criteria" to\n  "Inventory rules".', insight: 'The reviewer suggests. It does not edit files, write evidence or decide.' },
        { phase: 'Review', title: 'Decide on each finding', state: 'Decisions recorded', context: 'Review evidence / example', kind: 'code', body: 'R-001  Accepted\n  Read Evidence criteria; no rule\n  covers a missing count.\n\nR-002  Rejected\n  Wording preference; the heading\n  fits the skill\'s purpose.\n\nCorrection batch: R-001', insight: 'The assistant reads each cited location and records why it accepts or rejects.' },
        { phase: 'Correct', title: 'Fix R-001 and close it', state: 'Revision 2', context: 'snack-evidence / SKILL.md / correction', kind: 'code', body: '## Missing evidence\nIf a count is absent, report "unknown".\nName the missing source or observation.\nDo not estimate a quantity.\n\nAffected checks: Passed\nTargeted closure, R-001: Resolved', insight: 'Closure checks R-001 only. It does not start another full review.' },
        { phase: 'Handoff', title: 'Hand off the skill and its evidence', state: 'Ready for human review', context: 'Handoff / example', kind: 'code', body: 'Artifact: snack-evidence skill\nReview verdict: Pass (revision 2)\nValidation: Pass\nRejected finding: R-002, reason recorded\n\n[ ] Reviewed by a qualified human\n\nRPI can use it during research.', insight: 'A person completes the human review. This deck does not install the skill.' }
      ]
    },
    install: {
      label: 'Walkthrough state', phases: ['Customizations', 'Plugins', 'Source', 'Trust', 'Confirm'],
      steps: [
        { phase: 'Customizations', title: 'Open Customizations from Chat', state: 'Chat toolbar', context: 'Visual Studio Code', kind: 'install', view: 'chat', body: 'Open Customizations', insight: 'Click the gear in the Chat header. The next example opens Agent Customizations with Plugins selected.' },
        { phase: 'Plugins', title: 'Choose Install from Source', state: 'Plugins selected', context: 'Visual Studio Code', kind: 'install', view: 'plugins', body: 'Install from Source', insight: 'Plugins is near the top of the customization sidebar. The Available section contains Install from Source.' },
        { phase: 'Source', title: 'Enter the marketplace source', state: 'Source entered', context: 'Visual Studio Code', kind: 'install', view: 'source', source: 'microsoft/hve-core', body: 'Enter a GitHub repository, git URL, or local folder path to install a plugin from', insight: 'The top quick-input accepts owner/repo. Enter advances this illustration; Escape returns to Plugins.' },
        { phase: 'Trust', title: 'Review before granting trust', state: 'Human trust decision', context: 'Visual Studio Code', kind: 'install', view: 'trust', source: 'microsoft/hve-core', body: 'Review the repository and publisher before confirming a real trust prompt.', insight: 'Plugins may run code. Organization policy can block a source. Advancing this example grants no real approval.' },
        { phase: 'Confirm', title: 'Find HVE Core in installed plugins', state: 'VS Code-managed install', context: 'Visual Studio Code', kind: 'install', view: 'installed', body: 'hve-core', insight: 'Illustrative result. Check plugin enablement, chat.plugins.enabled and policy in your real client. Nothing was installed here.' }
      ]
    }
  };

  function moveStep(index, action, length) {
    if (!Number.isInteger(length) || length < 1 || !Number.isInteger(index) || index < 0 || index >= length) {
      throw new RangeError('A demo needs a valid index and a nonempty step list.');
    }
    if (action === 'reset') return 0;
    if (action === 'next') return Math.min(length - 1, index + 1);
    if (action === 'back') return Math.max(0, index - 1);
    throw new TypeError(`Unknown demo action: ${action}`);
  }

  const content = { sources, demos, chatModel, rpiAgentSelection, participationQuestion, graphs, mermaidSource, diffStats, moveStep };
  if (typeof module !== 'undefined' && module.exports) module.exports = content;
  else globalThis.HVEContent = content;
}());
