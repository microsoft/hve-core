// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
(function () {
  'use strict';
  const sources = {
    framework: {
      title: 'reveal.js documentation',
      url: 'https://revealjs.com/',
      note: 'Framework reference only. Replace sample citations with evidence for your topic.'
    }
  };
  const examples = {
    source: {
      kind: 'code', file: 'Illustrative changes excerpt',
      body: '## Completed work\n- [x] Clarify the contributor example\n\n## Check\nThe caption fits beside its source panel.'
    },
    request: {
      kind: 'composer', phase: 'Request', state: 'Waiting for direction',
      title: 'Start with a bounded request', context: 'GitHub Copilot Chat',
      body: 'Add a visible reset control to this example. Keep the state local.',
      attachments: ['example.js'], mode: 'Agent',
      insight: 'The request is scripted. No message is sent to Copilot.'
    },
    question: {
      kind: 'question', phase: 'Scope', state: 'Ask before changing behavior',
      title: 'Clarify the reset behavior', context: 'Example question',
      body: 'What should Reset clear?',
      options: ['Only this example', 'Every example in the presentation'],
      selected: 0, insight: 'The selected answer is part of the illustration.'
    },
    answer: {
      kind: 'answer', phase: 'Scope', state: 'Direction recorded',
      title: 'Keep the choice visible', context: 'Example answer',
      body: 'Only this example. Other walkthroughs should keep their current step.',
      insight: 'The answer narrows the change and its check.'
    },
    implementation: {
      kind: 'implementation', phase: 'Result', state: 'Illustrative result',
      title: 'Read the change and its evidence', context: 'Scripted implementation',
      tasks: ['Add a reset control', 'Check the visible count'],
      changes: '## Change\nReset clears this example.\n\n## Check\nThe displayed count returns to 0.',
      file: 'example.js',
      diff: [
        { type: 'context', text: 'function reset() {' },
        { type: 'remove', text: '  count = 0;' },
        { type: 'add', text: '  state.count = 0;' },
        { type: 'add', text: '  renderCount();' },
        { type: 'context', text: '}' }
      ],
      insight: 'These tasks and results are fictional, not an execution log.'
    }
  };
  const demos = {
    example: {
      label: 'Local reset example', phases: ['Request', 'Scope', 'Result'],
      steps: [examples.request, examples.question, examples.answer, examples.implementation]
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
