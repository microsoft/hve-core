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
      note: 'The six phases, approval points, entry modes, saved state and write boundaries.'
    },
    'rai-identity': {
      title: 'RAI identity instructions',
      url: `${blob}.github/instructions/rai-planning/rai-identity.instructions.md`,
      note: 'Phase transitions, framework selection, reference processing and resume behavior.'
    },
    'planner-skill': {
      title: 'rai-planner skill',
      url: `${blob}.github/skills/project-planning/rai-planner/SKILL.md`,
      note: 'Phase guidance for scoping, risk classification, impact assessment and handoff.'
    },
    'capture-reference': {
      title: 'rai-planner capture coaching reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/capture-coaching.md`,
      note: 'Start with the system and its users before introducing framework terminology.'
    },
    'risk-reference': {
      title: 'rai-planner risk classification reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/risk-classification.md`,
      note: 'Screen prohibited uses first, assess indicators, then ask the user to confirm the depth tier.'
    },
    'impact-reference': {
      title: 'rai-planner impact assessment reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/impact-assessment.md`,
      note: 'Prevent, detect and respond controls, evidence fields and tradeoffs.'
    },
    'handoff-reference': {
      title: 'rai-planner backlog handoff reference',
      url: `${blob}.github/skills/project-planning/rai-planner/references/backlog-handoff.md`,
      note: 'Review, draft backlog items, confirmation and optional artifact signing.'
    },
    'rai-standards': {
      title: 'rai-standards skill',
      url: `${blob}.github/skills/rai/rai-standards/SKILL.md`,
      note: 'NIST AI RMF 1.0, AI threat guidance and the pattern for adding a customer standard.'
    },
    'ai-stride': {
      title: 'AI STRIDE overlay reference',
      url: `${blob}.github/skills/rai/rai-standards/references/ai-stride-overlay.md`,
      note: 'AI threat categories and stable threat IDs.'
    },
    reviewer: {
      title: 'RAI Reviewer agent',
      url: `${blob}.github/agents/rai-planning/rai-reviewer.agent.md`,
      note: 'Evidence review of a codebase, diff or plan, separate from the Planner conversation.'
    },
    disclaimer: {
      title: 'Disclaimer language instructions',
      url: `${blob}.github/instructions/shared/disclaimer-language.instructions.md`,
      note: 'The RAI Planning CAUTION block shown before the first question and at exit points.'
    },
    'state-schema': {
      title: 'RAI state JSON schema',
      url: `${blob}scripts/linting/schemas/rai-state.schema.json`,
      note: 'The state.json fields and status values used in the examples.'
    },
    conformance: {
      title: 'RAI Planner conformance eval suite',
      url: `${blob}evals/agent-conformance/rai-planner/eval.yaml`,
      note: 'Scenarios cover disclaimer order, prohibited uses, explicit gates and evidence for claimed fixes. These are source scenarios, not evidence of passing runs.'
    },
    'pr-2568': {
      title: 'PR #2568: Consolidate RAI planner phase files into rai-plan.md',
      url: `${repo}pull/2568`,
      note: 'Merged July 31, 2026. Some published RAI pages still list the earlier per-phase files.'
    },
    'hve-builder': {
      title: 'hve-builder skill',
      url: `${blob}.github/skills/hve-core/hve-builder/SKILL.md`,
      note: 'Create and improve customization files, validate them, review them and resolve findings.'
    },
    'hve-builder-extending': {
      title: 'Extending HVE Builder and HVE workflows',
      url: `${blob}.github/skills/hve-core/hve-builder/references/extending-hve-builder.md`,
      note: 'Read the target workflow first. Choose a discoverable extension and keep its authority scoped.'
    },
    'hve-builder-workflow': {
      title: 'HVE Builder workflow contract',
      url: `${blob}.github/skills/hve-core/hve-builder/references/workflow-contract.md`,
      note: 'The authoring lifecycle, review and responsibility for corrections.'
    },
    'hve-builder-rubric': {
      title: 'HVE Builder review rubric',
      url: `${blob}.github/skills/hve-core/hve-builder/references/review-rubric.md`,
      note: 'Review criteria, finding severities and Pass, Revise or Blocked verdicts.'
    },
    'hve-builder-instructions': {
      title: 'HVE Builder instructions',
      url: `${blob}.github/instructions/hve-core/hve-builder.instructions.md`,
      note: 'Artifact choice, frontmatter, portability and safety conventions.'
    },
    nist: {
      title: 'NIST AI 100-1: AI Risk Management Framework 1.0',
      url: 'https://doi.org/10.6028/NIST.AI.100-1',
      note: 'January 2023. U.S. Government work and the planner\'s default framework.'
    },
    'vscode-skills': {
      title: 'VS Code: Use Agent Skills',
      url: `${vscode}agent-customization/agent-skills`,
      note: `Skill descriptions and explicit invocation. Discovery alone does not guarantee use. ${read}`
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
      note: `The wider workflow, entry modes and handoff guidance. ${read}`
    },
    'sr-26-2': {
      title: 'Federal Reserve SR 26-2: Revised Guidance on Model Risk Management',
      url: 'https://www.federalreserve.gov/supervisionreg/srletters/SR2602.htm',
      note: `April 17, 2026. Issued with the FDIC and OCC; replaces SR 11-7. Expected to be most relevant to banking organizations with over $30 billion in total assets. ${read}`
    },
    'sr-26-2-guidance': {
      title: 'SR 26-2 attachment: Supervisory Guidance on Model Risk Management',
      url: 'https://www.federalreserve.gov/supervisionreg/srletters/SR2602a1.pdf',
      note: `Materiality, effective challenge, conceptual soundness, outcomes analysis and ongoing monitoring. Generative and agentic AI models are out of scope, and the guidance sets no enforceable standards. ${read}`
    },
    'occ-2026-13': {
      title: 'OCC Bulletin 2026-13: Model Risk Management: Revised Guidance',
      url: 'https://www.occ.gov/news-issuances/bulletins/2026/bulletin-2026-13.html',
      note: `The OCC issuance of the same interagency guidance. It rescinds OCC Bulletin 2011-12 and earlier OCC model risk issuances. ${read}`
    }
  };

  const examples = {
    resume: {
      kind: 'composer',
      caption: 'Example request in a new chat. Display only.',
      body: 'Resume the RAI assessment for support-assistant. Read the saved state and plan, summarize where we stopped, then continue.',
      attachments: [], mode: 'RAI Planner'
    },
    policy: {
      kind: 'composer',
      caption: 'Example request at Phase 1. Display only.',
      body: 'Include our model-risk policy as a standard and our prohibited-use list. Keep NIST AI RMF 1.0 as the baseline.',
      attachments: ['model-risk-policy.md', 'prohibited-uses.md'], mode: 'RAI Planner'
    },
    'try-it': {
      kind: 'composer',
      caption: 'Replace <feature> with your own AI feature. Display only.',
      body: 'Help me plan a Responsible AI assessment for <feature>. Ask me for the system context, our policy and any existing PRD or security plan before we start.',
      attachments: [], mode: 'RAI Planner'
    }
  };

  const assessSteps = [
    {
      kind: 'composer', phase: 'Start', state: 'RAI Planner selected',
      title: 'Describe the system in your own words',
      caption: 'Reconstructed Chat input. Scripted; nothing is sent.',
      body: 'Start a capture assessment for support-assistant. Our support chatbot uses a fine-tuned LLM in a web widget. It answers customers and support agents, reads order history and opens pages that customers link to.',
      attachments: ['support-assistant-notes.md'], mode: 'RAI Planner',
      insight: 'Give it enough context to ask useful questions. You can work out the rest in the conversation.'
    },
    {
      kind: 'chat', phase: 'Scope', state: 'Phase 1: notices, then scoping',
      title: 'Work out what the chatbot is allowed to do',
      caption: 'Scripted response. Notice excerpts are from HVE Core.',
      messages: [{
        role: 'assistant', author: 'RAI Planner', blocks: [
          { type: 'callout', label: 'CAUTION', text: 'Disclaimer: This agent is an assistive tool only. It does not provide legal, regulatory, or compliance advice ...' },
          { type: 'text', text: 'This assessment uses the NIST AI Risk Management Framework 1.0 (U.S. Government work, not subject to copyright protection in the United States) as the default evaluation framework.' },
          { type: 'text', text: 'After we confirm your policy and output preferences, I need to understand:' },
          {
            type: 'checklist', items: [
              { status: 'pending', text: 'What can the chatbot do after reading a linked page?' },
              { status: 'pending', text: 'Which decisions must stay with a support agent?' }
            ]
          }
        ]
      }],
      insight: 'The full session also covers provider policies, data retention and optional templates. The notices come before any questions.'
    },
    {
      kind: 'chat', phase: 'Risk', state: 'Phase 2: waiting for confirmation',
      title: 'Confirm how much assessment the system needs',
      caption: 'Scripted exchange; not a recorded run.',
      messages: [
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: 'None of the listed prohibited uses apply. The chatbot can follow instructions it finds in linked pages.' }] },
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            { type: 'text', text: 'Prohibited uses gate: passed. In this example, two indicators are activated:' },
            {
              type: 'list', items: [
                'Rights, fairness and privacy: it reads order history.',
                'Security and explainability: linked pages can redirect it.'
              ]
            },
            { type: 'text', text: 'I suggest comprehensive depth. Are you comfortable with that scope of work before we map the standards?' }
          ]
        }
      ],
      insight: 'Two activated indicators suggest comprehensive depth. You confirm the tier; the planner does not decide it for you.'
    },
    {
      kind: 'code', phase: 'Plan', state: 'Phase 3 confirmed; Phase 4 summarized',
      title: 'Connect the standard to a concrete threat',
      caption: 'Illustrative plan excerpt, after scope confirmation.',
      file: 'rai-plan.md / Standards Mapping + Threat Addendum',
      body: '## Standards Mapping\nSecure and Resilient -> Link reader -> partial\nPrivacy-Enhanced -> Conversation store -> partial\n\n## Threat Addendum\nT-RAI-001  Prompt injection through linked pages\n           Component: link reader\n           STRIDE: Elevation of Privilege\n           Concern: high',
      insight: 'Follow one risk through the plan. T-RAI-001 gives the control, evidence and follow-up work a shared reference.'
    },
    {
      kind: 'chat', phase: 'Evidence', state: 'Phase 5: a control needs verification',
      title: '"We fixed it" still needs a test result',
      caption: 'Scripted exchange; not a recorded run.',
      messages: [
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: 'We fixed prompt injection. The link reader strips instructions.' }] },
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            { type: 'text', text: 'I can record that control, but I still need evidence that it works.' },
            { type: 'code', text: 'EV-001 -> T-RAI-001\nControl: strip instructions from page text\nCoverage: partial   Verification: unverified' },
            { type: 'text', text: 'Can you share the injection test results? Otherwise, I\'ll keep verification as follow-up work.' }
          ]
        }
      ],
      insight: 'Ask for the evidence behind a control before treating it as verified.'
    },
    {
      kind: 'chat', phase: 'Handoff', state: 'Phase 6: draft only',
      title: 'Review the follow-up before creating issues',
      caption: 'Scripted handoff, with one shortened issue draft.',
      messages: [{
        role: 'assistant', author: 'RAI Planner', blocks: [
          { type: 'text', text: 'EV-001 is still unverified. I\'ve drafted a GitHub issue:' },
          { type: 'code', text: '{{RAI-TEMP-1}}\nAdd prompt-injection tests for linked pages\n\nAcceptance: linked-page injection test cases pass.\nEvidence: link the test results to EV-001.' },
          { type: 'text', text: 'Review the plan and draft, then confirm whether to create the issue.' }
        ]
      }],
      insight: 'The draft traces back to the evidence gap. The full handoff includes the review summary and repeats the human-review disclaimer.'
    }
  ];

  const extendSteps = [
    {
      kind: 'composer', phase: 'Request', state: 'Use an agent allowed to edit .github',
      title: 'Ask hve-builder for the reusable setup',
      caption: 'Reconstructed Chat input. Scripted; nothing is sent.',
      body: '/hve-builder Extend RAI Planner for Contoso lending teams. Layer our model-risk policy and SR 26-2, the 2026 interagency model risk guidance, on NIST AI RMF. Summarize SR 26-2 from the official text. Add our prohibited uses, check adverse-action explanations and default to Azure DevOps. Use a skill for policy and an instruction for plan conventions. Keep HVE Core files unchanged.',
      attachments: ['model-risk-policy.md', 'prohibited-uses.md'], mode: 'Agent',
      insight: 'Run this in an agent that can edit .github; RAI Planner only writes assessment files. SR 26-2 is real. Contoso and its policies are fictional.'
    },
    {
      kind: 'code', phase: 'Author', state: 'Policy skill drafted',
      title: 'Put the policies in a skill',
      caption: 'Illustrative file for a fictional company.',
      file: '.github/skills/contoso-rai-policy/SKILL.md',
      body: '---\nname: contoso-rai-policy\ndescription: "Contoso lending policies and SR 26-2 summary.\n  Use with RAI Planner for Contoso lending assessments."\n---\n# Contoso RAI policy\n\nIn Phase 1, supply these files as reference content:\n* references/model-risk-policy.md (standard)\n* references/sr-26-2-summary.md (standard)\n* references/prohibited-uses.md (prohibited-use-framework)',
      insight: 'hve-builder reads the planner\'s extension points first. Published guidance goes in as another standard, next to your own policy.'
    },
    {
      kind: 'code', phase: 'Author', state: 'Real guidance summarized',
      title: 'Add guidance RAI Planner doesn\'t include',
      caption: 'Illustrative file that paraphrases real guidance.',
      file: '.github/skills/contoso-rai-policy/references/sr-26-2-summary.md',
      body: '# SR 26-2 model risk guidance: Contoso summary\nSource: Federal Reserve, FDIC and OCC, April 17, 2026 (paraphrased)\nhttps://www.federalreserve.gov/supervisionreg/srletters/SR2602a1.pdf\nOut of scope: generative and agentic AI models.\n\nIn Phase 3, map these alongside NIST AI RMF:\n* Rigor that matches model materiality\n* Effective challenge by objective experts\n* Conceptual soundness: design, data and assumptions\n* Outcomes analysis against real-world results\n* Ongoing monitoring as conditions change',
      insight: 'Check the scope before adding a policy. SR 26-2 fits this loan model, not an LLM chatbot. Have your model-risk team review the summary.'
    },
    {
      kind: 'code', phase: 'Author', state: 'First draft: review required',
      title: 'Scope the conventions to plan files',
      caption: 'Illustrative first draft. The next step corrects a mistake.',
      file: '.github/instructions/contoso-rai.instructions.md',
      body: '---\ndescription: "Contoso lending conventions for RAI Planner"\napplyTo: \'**/.copilot-tracking/rai-plans/**\'\n---\n# Conventions for Contoso lending assessments\n\n* List applicants and loan officers in Stakeholder Impact.\n* Record adverse-action tests in the Evidence Register.\n* Default userPreferences.targetSystem to "ado".\n* Load contoso-rai-policy and set\n  replaceDefaultFramework to true.',
      insight: 'applyTo targets assessment files. The body limits the rules to lending, but this draft incorrectly replaces NIST.'
    },
    {
      kind: 'review', phase: 'Review', state: 'Draft corrected after review',
      title: 'Check that the extension does what you asked',
      caption: 'Scripted source review and correction; not a test run.',
      checksTitle: 'Checks and review',
      checks: ['Frontmatter and lint checked', 'Source reviewed against the request', 'Corrected file rechecked'],
      finding: {
        label: 'R1 / High / required correction',
        text: 'The request says to layer Contoso\'s policy and SR 26-2 on NIST. This draft replaces NIST AI RMF as the baseline.'
      },
      file: 'contoso-rai.instructions.md',
      diff: [
        { type: 'context', text: '* Default userPreferences.targetSystem to "ado".' },
        { type: 'remove', text: '* Load contoso-rai-policy and set' },
        { type: 'remove', text: '  replaceDefaultFramework to true.' },
        { type: 'add', text: '* Load contoso-rai-policy. Keep NIST' },
        { type: 'add', text: '  AI RMF 1.0 as the active framework.' }
      ],
      insight: 'The author verifies the finding and fixes it. You still need representative assessment runs to check the extension\'s behavior.'
    },
    {
      kind: 'chat', phase: 'Use', state: 'Switch to RAI Planner; Phase 1 references processed',
      title: 'Use the skill in your next assessment',
      caption: 'Scripted exchange and selected state.json fields.',
      messages: [
        { role: 'user', author: 'You', blocks: [{ type: 'text', text: '/contoso-rai-policy Start a capture assessment for our loan eligibility model, project slug loan-eligibility.' }] },
        {
          role: 'assistant', author: 'RAI Planner', blocks: [
            { type: 'text', text: 'I processed three references: Contoso\'s model-risk policy and SR 26-2 as standards, and Contoso\'s prohibited uses. NIST AI RMF 1.0 stays active.' },
            { type: 'code', text: '"riskClassification": {\n  "framework": { "id": "nist-ai-rmf", "replaceDefaultFramework": false }\n},\n"userPreferences": { "targetSystem": "ado", "autonomyTier": "partial" }' }
          ]
        }
      ],
      insight: 'Check the references, active framework and backlog target. The disclaimer, approval points and partial autonomy still apply.'
    },
    {
      kind: 'code', phase: 'Use', state: 'Phase 3 confirmed; SR 26-2 mapped',
      title: 'See the guidance in the plan',
      caption: 'Illustrative plan excerpt after the mapping scope is confirmed.',
      file: 'rai-plan.md / Standards Mapping',
      body: '## Standards Mapping\nBaseline: NIST AI RMF 1.0\nLayered: Contoso model-risk policy; SR 26-2 (2026)\n\nValid and Reliable -> eligibility model -> partial\n  SR 26-2 outcomes analysis: no repayment back-test yet\nAccountable and Transparent -> model governance -> gap-identified\n  SR 26-2 effective challenge: no independent reviewer\nExplainable and Interpretable -> denial reasons -> partial\n  Contoso policy: adverse-action reason test pending',
      insight: 'NIST stays the baseline. SR 26-2 adds model risk checks under it, and Phase 5 records the evidence for each gap.'
    }
  ];

  const demos = {
    assess: {
      label: 'Support chatbot',
      phases: ['Start', 'Scope', 'Risk', 'Plan', 'Evidence', 'Handoff'],
      steps: assessSteps
    },
    extend: {
      label: 'Contoso lending',
      phases: ['Request', 'Author', 'Review', 'Use'],
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
  globalThis.DeckContent = { sources, examples, demos, moveStep, diffStats };
}());
