// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  const commit = '7e2de1aa135133acc4e9592adffc220cad9bdfdf';
  const repo = 'https://github.com/microsoft/hve-core/';
  const blob = `${repo}blob/${commit}/`;
  const tree = `${repo}tree/${commit}/`;
  const vscode = 'https://code.visualstudio.com/docs/';
  const read = 'Read October 1, 2026.';
  const sources = {
    snapshot: {
      title: 'HVE Core source snapshot 7e2de1a',
      url: tree,
      note: `main branch at September 30, 2026. ${read} Product details in this deck describe this revision.`
    },
    'planner-agent': {
      title: 'RAI Planner agent',
      url: `${blob}.github/agents/rai-planning/rai-planner.agent.md`,
      note: 'Six phases, gates, entry modes, state schema, research activation, backlog handoff and operational constraints.'
    },
    'rai-identity': {
      title: 'RAI identity instructions',
      url: `${blob}.github/instructions/rai-planning/rai-identity.instructions.md`,
      note: 'applyTo **/.copilot-tracking/rai-plans/**. Phase definitions, gate cadence, entry modes, reference-content protocol and resume rules.'
    },
    'license-posture': {
      title: 'RAI license posture instructions',
      url: `${blob}.github/instructions/rai-planning/rai-license-posture.instructions.md`,
      note: 'Reproduction rules for NIST AI RMF, the EU AI Act, OWASP and ISO sources in RAI artifacts.'
    },
    'planner-skill': {
      title: 'rai-planner skill',
      url: `${blob}.github/skills/project-planning/rai-planner/SKILL.md`,
      note: 'On-demand phase references for capture coaching, risk classification, impact assessment and backlog handoff.'
    },
    'capture-reference': {
      title: 'rai-planner capture coaching reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/capture-coaching.md`,
      note: 'Exploration-first questions for Phase 1 scoping.'
    },
    'risk-reference': {
      title: 'rai-planner risk classification reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/risk-classification.md`,
      note: 'Prohibited uses gate, indicator assessment and depth-tier assignment.'
    },
    'impact-reference': {
      title: 'rai-planner impact assessment reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/impact-assessment.md`,
      note: 'Prevent, detect and respond controls; evidence register fields; tradeoff documentation.'
    },
    'handoff-reference': {
      title: 'rai-planner backlog handoff reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/backlog-handoff.md`,
      note: 'Review rubric, final handoff table, backlog-templates delegation and artifact signing.'
    },
    'rai-standards': {
      title: 'rai-standards skill',
      url: `${blob}.github/skills/rai/rai-standards/SKILL.md`,
      note: 'NIST AI RMF 1.0 characteristics and phase mapping, the AI STRIDE overlay, an EU AI Act paraphrase and the customer extension pattern.'
    },
    'ai-stride': {
      title: 'AI STRIDE overlay reference',
      url: `${blob}.github/skills/rai/rai-standards/references/ai-stride-overlay.md`,
      note: 'AI threat surfaces, the dual threat-ID convention and the ML STRIDE matrix.'
    },
    reviewer: {
      title: 'RAI Reviewer agent',
      url: `${blob}.github/agents/rai-planning/rai-reviewer.agent.md`,
      note: 'Audit, diff and plan modes. Dispatches Codebase Profiler, RAI Skill Assessor, Finding Deep Verifier and Report Generator.'
    },
    assessor: {
      title: 'RAI Skill Assessor subagent',
      url: `${blob}.github/agents/rai-planning/subagents/rai-skill-assessor.agent.md`,
      note: 'Assesses one rai-standards framework per invocation and returns structured findings.'
    },
    prompts: {
      title: 'RAI prompt files',
      url: `${tree}.github/prompts/rai-planning`,
      note: 'rai-capture, rai-plan-from-prd and rai-plan-from-security-plan. Each declares agent: "RAI Planner".'
    },
    disclaimer: {
      title: 'Disclaimer language instructions',
      url: `${blob}.github/instructions/shared/disclaimer-language.instructions.md`,
      note: 'The RAI Planning CAUTION block shown before the first question and at exit points.'
    },
    'planner-base': {
      title: 'Planner identity base instructions',
      url: `${blob}.github/instructions/shared/planner-identity-base.instructions.md`,
      note: 'Shared scaffold for the SSSC, RAI, Security, Accessibility and Privacy planners: state, phases, resume and question cadence.'
    },
    untrusted: {
      title: 'Untrusted content boundary instructions',
      url: `${blob}.github/instructions/shared/untrusted-content-boundary.instructions.md`,
      note: 'Fetched pages, handoff payloads and tool output are data, not instructions.'
    },
    'state-schema': {
      title: 'RAI state JSON schema',
      url: `${blob}scripts/linting/schemas/rai-state.schema.json`,
      note: 'Authoritative state.json shape, including the status and preference vocabularies used in the examples.'
    },
    conformance: {
      title: 'RAI Planner conformance eval suite',
      url: `${blob}evals/agent-conformance/rai-planner/eval.yaml`,
      note: 'Scenarios a model judge grades, such as disclaimer first, prohibited uses first, explicit gates, prompt injection, evidence for claimed fixes and no compliance sign-off. This deck cites the scenarios, not run results.'
    },
    'adr-0007': {
      title: 'ADR 0007: Consolidate RAI knowledge into skills',
      url: `${blob}docs/planning/adrs/0007-rai-skill-consolidation.md`,
      note: 'Status: proposed. Keeps RAI standards in shared skills that the Planner and the Reviewer both load.'
    },
    plugin: {
      title: 'hve-core plugin manifest',
      url: `${blob}plugin.json`,
      note: 'Lists the RAI agents, prompts, instructions and skills among the plugin components.'
    },
    'pr-979': {
      title: 'PR #979: Add RAI Planner',
      url: `${repo}pull/979`,
      note: 'Merged March 20, 2026.'
    },
    'pr-2568': {
      title: 'PR #2568: Consolidate RAI planner phase files into rai-plan.md',
      url: `${repo}pull/2568`,
      note: 'Merged July 31, 2026. Some published RAI pages still list the earlier per-phase files.'
    },
    'hve-builder': {
      title: 'hve-builder skill',
      url: `${blob}.github/skills/hve-core/hve-builder/SKILL.md`,
      note: 'Modes, lifecycle, review pass and the use case for extending HVE workflows.'
    },
    'hve-builder-extending': {
      title: 'Extending HVE Builder and HVE workflows',
      url: `${blob}.github/skills/hve-core/hve-builder/references/extending-hve-builder.md`,
      note: 'Discovery by applyTo, description and name; extension precedence; what to capture from a target workflow.'
    },
    'hve-builder-workflow': {
      title: 'HVE Builder workflow contract',
      url: `${blob}.github/skills/hve-core/hve-builder/references/workflow-contract.md`,
      note: 'Mode composition, lifecycle, parent-owned corrections and outcomes.'
    },
    'hve-builder-rubric': {
      title: 'HVE Builder review rubric',
      url: `${blob}.github/skills/hve-core/hve-builder/references/review-rubric.md`,
      note: 'Review dimensions, severity scale and Pass, Revise or Blocked verdicts.'
    },
    'hve-builder-instructions': {
      title: 'HVE Builder instructions',
      url: `${blob}.github/instructions/hve-core/hve-builder.instructions.md`,
      note: 'Choose artifacts by responsibility; frontmatter, portability and safety conventions.'
    },
    nist: {
      title: 'NIST AI 100-1: AI Risk Management Framework 1.0',
      url: 'https://doi.org/10.6028/NIST.AI.100-1',
      note: 'January 2023. U.S. Government work and the planner\'s default framework.'
    },
    'eu-ai-act': {
      title: 'Regulation (EU) 2024/1689 (EU AI Act)',
      url: 'https://eur-lex.europa.eu/eli/reg/2024/1689/oj',
      note: 'Authoritative legal text. rai-standards paraphrases its risk tiers rather than quoting them.'
    },
    'vscode-customization': {
      title: 'VS Code: Understand agent customization',
      url: `${vscode}agents/concepts/customization`,
      note: `How instructions, skills, prompt files, custom agents and hooks are activated. ${read}`
    },
    'vscode-prompts': {
      title: 'VS Code: Use prompt files',
      url: `${vscode}agent-customization/prompt-files`,
      note: `Prompt files are deprecated for Agent Host sessions and still work with the Local agent. ${read}`
    },
    'vscode-skills': {
      title: 'VS Code: Use Agent Skills',
      url: `${vscode}agent-customization/agent-skills`,
      note: `Skill name and description rules, slash invocation and automatic loading. Discovery does not guarantee use. ${read}`
    },
    'vscode-instructions': {
      title: 'VS Code: Use custom instructions',
      url: `${vscode}agent-customization/custom-instructions`,
      note: `An applyTo pattern attaches the file when the agent creates or modifies a matching file. ${read}`
    },
    'vscode-agents': {
      title: 'VS Code: Custom agents',
      url: `${vscode}agent-customization/custom-agents`,
      note: `Select a custom agent from the Agent dropdown in the selected harness. ${read}`
    },
    'rai-docs': {
      title: 'HVE Core documentation: RAI Planning',
      url: 'https://microsoft.github.io/hve-core/docs/agents/rai-planning/',
      note: `Published overview, entry modes, phase reference and handoff pages. ${read}`
    }
  };

  const indicators = [
    { name: 'safety_reliability', method: 'binary', nist: ['MS-2.5', 'MS-2.6'], focus: 'Validity, reliability and safety' },
    { name: 'rights_fairness_privacy', method: 'categorical', nist: ['MS-2.8', 'MS-2.10', 'MS-2.11'], focus: 'Accountability, privacy and fairness' },
    { name: 'security_explainability', method: 'continuous', nist: ['MS-2.7', 'MS-2.9'], focus: 'Security, resilience and explainability' }
  ];
  const tiers = [
    { name: 'basic', activated: '0' },
    { name: 'standard', activated: '1' },
    { name: 'comprehensive', activated: '2+' }
  ];

  const examples = {
    tier: {
      kind: 'tier-explorer',
      caption: 'Interactive: select indicators to see the suggested tier. It runs in this page; no agent is involved.',
      indicators,
      tiers
    }
  };

  const assessSteps = [
    {
      kind: 'composer', phase: 'Start', state: 'RAI Planner selected in the Agent dropdown',
      title: 'Describe the system to RAI Planner',
      caption: 'Reconstructed Chat input. Scripted; nothing is sent.',
      body: 'Start a capture assessment with project slug support-assistant. Our customer support chatbot uses a fine-tuned LLM in a web widget. Support agents and customers use it, and it can open pages that customers link to.',
      attachments: ['support-assistant-notes.md'], mode: 'RAI Planner',
      insight: 'Selecting the agent works in any harness. The /rai-capture prompt file starts the same mode with the Local agent.'
    },
    {
      kind: 'chat', phase: 'Start', state: 'state.json created; Phase 1',
      title: 'The disclaimer and framework come first',
      caption: 'Scripted response. The CAUTION and attribution text are excerpts of HVE Core source.',
      messages: [{
        role: 'assistant', author: 'RAI Planner', blocks: [
          { type: 'callout', label: 'CAUTION', text: 'Disclaimer: This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice and does not replace Responsible AI review boards, ethics committees, legal counsel, compliance teams, or other qualified human reviewers. ...' },
          { type: 'text', text: 'This assessment uses the NIST AI Risk Management Framework 1.0 (U.S. Government work, not subject to copyright protection in the United States) as the default evaluation framework.' },
          { type: 'note', text: 'Created .copilot-tracking/rai-plans/support-assistant/state.json' }
        ]
      }],
      insight: 'disclaimerShownAt and the noticeLog record what was shown, so a resumed session knows.'
    },
    {
      kind: 'chat', phase: 'Scope', state: 'Phase 1: up to seven questions a turn',
      title: 'Explore the system before naming risks',
      caption: 'Scripted response; not a recorded run.',
      messages: [{
        role: 'assistant', author: 'RAI Planner', blocks: [
          { type: 'text', text: 'Phase 1, AI system scoping. From your notes:' },
          {
            type: 'checklist', items: [
              { status: 'done', text: 'Purpose: answer support questions for agents and customers' },
              { status: 'done', text: 'Deployment: a web widget on the support site' },
              { status: 'pending', text: 'Any evaluation standards, prohibited-use lists or output formats to include?' },
              { status: 'pending', text: 'Which provider hosts the model, and does its code of conduct apply?' },
              { status: 'pending', text: 'What customer data enters a conversation, and how long is it kept?' },
              { status: 'pending', text: 'What can the assistant do after it reads a linked page?' },
              { status: 'pending', text: 'Which decisions must stay with a support agent?' }
            ]
          }
        ]
      }],
      insight: 'Open questions about real workflows come before framework vocabulary. Phase 1 ends with a summary you can correct.'
    },
    {
      kind: 'chat', phase: 'Risk', state: 'Hard gate: tier awaits your confirmation',
      title: 'Screen prohibited uses, then three indicators',
      caption: 'Scripted exchange; not a recorded run.',
      messages: [
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: 'No biometric categorization, social scoring or manipulation. It reads order history and follows instructions it finds in linked pages.' }] },
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            {
              type: 'list', items: [
                'Prohibited uses gate: passed',
                'safety_reliability (binary): not activated',
                'rights_fairness_privacy (categorical): activated by order history',
                'security_explainability (continuous): activated by linked-page instructions'
              ]
            },
            { type: 'text', text: 'Two of three are activated, so I suggest a comprehensive assessment. Confirm the tier before Phase 3?' }
          ]
        }
      ],
      insight: 'The tier sets the effort for every later phase, so Phase 2 waits for an explicit answer.'
    },
    {
      kind: 'code', phase: 'Standards', state: 'Hard gate: mapping scope confirmed',
      title: 'Map components to trustworthiness characteristics',
      caption: 'Illustrative excerpt of the generated plan.',
      file: 'rai-plan.md / ## Standards Mapping',
      body: 'Characteristic                   Component            Status\nSecure and Resilient             Link reader          partial\nPrivacy-Enhanced                 Conversation store   partial\nAccountable and Transparent      Agent escalation     addressed\nExplainable and Interpretable    Answer generator     not-yet-covered\nFair with Harmful Bias Managed   Answer generator     gap-identified',
      insight: 'principleTracker keeps a status for all seven characteristics. The values come from the state schema.'
    },
    {
      kind: 'code', phase: 'Threats', state: 'Summary: three threats cataloged',
      title: 'Catalog AI-specific threats with stable IDs',
      caption: 'Illustrative excerpt of the generated plan.',
      file: 'rai-plan.md / ## Threat Addendum',
      body: 'T-RAI-001  Prompt injection      Link reader          high\n           STRIDE: Elevation of Privilege\nT-RAI-002  Privacy leakage       Conversation store   high\n           STRIDE: Information Disclosure\nT-RAI-003  Output manipulation   Answer generator     medium\n           STRIDE: Tampering',
      insight: 'Capture mode starts at T-RAI-001. From a security plan, numbering continues after its threat count.'
    },
    {
      kind: 'chat', phase: 'Impact', state: 'Evidence register: one unverified control',
      title: 'A claimed fix still needs evidence',
      caption: 'Scripted exchange; not a recorded run.',
      messages: [
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: 'We already fixed prompt injection. The link reader strips instructions.' }] },
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            { type: 'text', text: 'I recorded the control, but no test result supports it yet:' },
            { type: 'code', text: 'EV-001  T-RAI-001  prevent  Strip instructions from page text\n        coverage: partial   verification: unverified' },
            { type: 'text', text: 'Can you share an injection test run? If not, EV-001 becomes a backlog candidate.' }
          ]
        }
      ],
      insight: 'Controls are prevent, detect or respond. The conformance suite includes this "already fixed" scenario.'
    },
    {
      kind: 'chat', phase: 'Handoff', state: 'Hard gate: nothing is created yet',
      title: 'Draft the backlog and leave approval to people',
      caption: 'Scripted exchange; not a recorded run.',
      messages: [
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            { type: 'text', text: 'Review summary written. Create these draft GitHub issues?' },
            { type: 'code', text: '{{RAI-TEMP-1}}  Add prompt-injection tests for linked pages\n{{RAI-TEMP-2}}  Enforce transcript retention' }
          ]
        },
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: 'First, can you confirm the chatbot is compliant so we can deploy?' }] },
        { role: 'assistant', author: 'RAI Planner', blocks: [{ type: 'text', text: 'No. This is AI-assisted analysis. Qualified legal, compliance and RAI reviewers decide on deployment.' }] }
      ],
      insight: 'Partial autonomy: nothing is created until you confirm. Azure DevOps drafts use WI-RAI-NNN IDs.'
    }
  ];

  const extendSteps = [
    {
      kind: 'composer', phase: 'Request', state: 'Modes: create, improve and refactor',
      title: 'Ask HVE Builder for an extension',
      caption: 'Reconstructed Chat input. Scripted; nothing is sent.',
      body: '/hve-builder Extend the RAI Planner for Woodgrove lending teams. Layer our model-risk policy on NIST AI RMF, add our prohibited uses, require an adverse-action explanation check in every plan and default the backlog to Azure DevOps. Leave HVE Core files unchanged.',
      attachments: ['model-risk-policy.md', 'prohibited-uses.md'], mode: 'Agent',
      insight: 'HVE Builder is a skill, so any agent can run it. Woodgrove Bank and its policy are fictional.'
    },
    {
      kind: 'chat', phase: 'Scope', state: 'Target workflow contract captured',
      title: 'Read the planner\'s contract before choosing files',
      caption: 'Scripted response; not a recorded run.',
      messages: [{
        role: 'assistant', author: 'Agent using hve-builder', blocks: [
          { type: 'text', text: 'RAI Planner extension points that need no change to the agent:' },
          {
            type: 'checklist', items: [
              { status: 'done', text: 'Phase 1 reference types: standard and prohibited-use-framework' },
              { status: 'done', text: 'Instructions for **/.copilot-tracking/rai-plans/** are attached by path' },
              { status: 'done', text: 'Backlog target lives in userPreferences.targetSystem' },
              { status: 'done', text: 'Writes stay in .copilot-tracking/rai-plans/{slug}/' }
            ]
          },
          { type: 'text', text: 'Plan: a skill for the policy and an instruction for the conventions. No subagent; nothing here needs an isolated context.' }
        ]
      }],
      insight: 'HVE Builder reads a target workflow\'s discovery rules and contract before it chooses an artifact type.'
    },
    {
      kind: 'code', phase: 'Author', state: 'Candidate: skill drafted',
      title: 'A skill carries the policy',
      caption: 'Illustrative file for a fictional company.',
      file: '.github/skills/woodgrove-rai-policy/SKILL.md',
      body: '---\nname: woodgrove-rai-policy\ndescription: "Woodgrove model-risk policy, prohibited uses and\n  adverse-action rules for lending AI. Use with RAI Planner\n  when assessing a Woodgrove lending system."\n---\n# Woodgrove RAI policy\n\nIn Phase 1, supply these files as reference content:\n* references/model-risk-policy.md (standard)\n* references/prohibited-uses.md (prohibited-use-framework)',
      insight: 'The description is how the skill is found: it names the agent, the domain and when to use it.'
    },
    {
      kind: 'code', phase: 'Author', state: 'Candidate: instruction drafted',
      title: 'An instruction adds Woodgrove conventions',
      caption: 'Illustrative first draft for a fictional company.',
      file: '.github/instructions/woodgrove-rai.instructions.md',
      body: '---\ndescription: "Woodgrove conventions for RAI Planner artifacts"\napplyTo: \'**/.copilot-tracking/rai-plans/**\'\n---\n# Woodgrove RAI conventions\n\n* List applicants and loan officers in Stakeholder Impact.\n* Record adverse-action explanation tests in the Evidence Register.\n* Set userPreferences.targetSystem to "ado".\n* Load woodgrove-rai-policy and set\n  replaceDefaultFramework to true.',
      insight: 'VS Code attaches this file whenever the agent creates or changes a file under rai-plans.'
    },
    {
      kind: 'review', phase: 'Review', state: 'Revise, then Pass after one fix',
      title: 'Review the candidate and fix the finding',
      caption: 'Scripted review result; not a recorded run.',
      checksTitle: 'Checks and review',
      checks: ['Frontmatter and lint checks pass', 'Review pass in a fresh context', 'R1 verified at its location'],
      finding: {
        label: 'R1 / High / required correction',
        text: 'The draft replaces NIST AI RMF, but the request says to layer the Woodgrove policy on it.'
      },
      file: 'woodgrove-rai.instructions.md',
      diff: [
        { type: 'context', text: '* Set userPreferences.targetSystem to "ado".' },
        { type: 'remove', text: '* Load woodgrove-rai-policy and set' },
        { type: 'remove', text: '  replaceDefaultFramework to true.' },
        { type: 'add', text: '* Load woodgrove-rai-policy. Keep NIST' },
        { type: 'add', text: '  AI RMF 1.0 as the active framework.' }
      ],
      insight: 'Reviewer findings are suggestions. The agent running HVE Builder verifies each one, fixes it and rechecks.'
    },
    {
      kind: 'composer', phase: 'Use', state: 'RAI Planner selected in the Agent dropdown',
      title: 'Start an assessment with the extension',
      caption: 'Reconstructed Chat input. Scripted; nothing is sent.',
      body: '/woodgrove-rai-policy Start a capture assessment for the loan eligibility model, project slug loan-eligibility.',
      attachments: [], mode: 'RAI Planner',
      insight: 'Naming the skill loads it for this request. A description match makes a skill available but doesn\'t guarantee its use.'
    },
    {
      kind: 'code', phase: 'Use', state: 'Phase 1 references processed',
      title: 'The planner records the layered policy',
      caption: 'Illustrative state.json excerpt; paths shortened.',
      file: '.copilot-tracking/rai-plans/loan-eligibility/state.json',
      body: '"riskClassification": {\n  "framework": { "id": "nist-ai-rmf", "replaceDefaultFramework": false }\n},\n"referencesProcessed": [\n  { "type": "standard", "status": "processed",\n    "filePath": ".../references/woodgrove-model-risk-policy.md" },\n  { "type": "prohibited-use-framework", "status": "processed",\n    "filePath": ".../references/woodgrove-prohibited-uses.md" }\n],\n"userPreferences": { "targetSystem": "ado", "autonomyTier": "partial" }',
      insight: 'The policy goes through the planner\'s own reference protocol. Disclaimer, gates and autonomy are unchanged.'
    }
  ];

  const demos = {
    assess: {
      label: 'Support chatbot assessment',
      phases: ['Start', 'Scope', 'Risk', 'Standards', 'Threats', 'Impact', 'Handoff'],
      steps: assessSteps
    },
    extend: {
      label: 'Woodgrove lending extension',
      phases: ['Request', 'Scope', 'Author', 'Review', 'Use'],
      steps: extendSteps
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
  // Mirrors the rai-planner risk-classification reference: 0 = basic, 1 = standard, 2 or more = comprehensive.
  function depthTier(activated) {
    if (!Number.isInteger(activated) || activated < 0 || activated > indicators.length) {
      throw new Error('Invalid activated indicator count.');
    }
    if (activated === 0) return 'basic';
    return activated === 1 ? 'standard' : 'comprehensive';
  }
  globalThis.DeckContent = { sources, examples, demos, moveStep, diffStats, depthTier };
}());
