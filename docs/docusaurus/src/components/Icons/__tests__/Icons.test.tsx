import React from 'react';
import { render } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import {
  GettingStartedIcon,
  AgentsPromptsIcon,
  InstructionsSkillsIcon,
  WorkflowsIcon,
  DesignThinkingIcon,
  TemplatesExamplesIcon,
} from '..';

expect.extend(toHaveNoViolations);

const icons = [
  { name: 'GettingStartedIcon', Component: GettingStartedIcon },
  { name: 'AgentsPromptsIcon', Component: AgentsPromptsIcon },
  { name: 'InstructionsSkillsIcon', Component: InstructionsSkillsIcon },
  { name: 'WorkflowsIcon', Component: WorkflowsIcon },
  { name: 'DesignThinkingIcon', Component: DesignThinkingIcon },
  { name: 'TemplatesExamplesIcon', Component: TemplatesExamplesIcon },
];

describe('Icons', () => {
  it.each(icons)('$name renders an SVG with aria-hidden', ({ Component }) => {
    const { container } = render(<Component />);
    const svg = container.querySelector('svg');
    expect(svg).toBeInTheDocument();
    expect(svg).toHaveAttribute('aria-hidden', 'true');
  });

  it.each(icons)('$name accepts a className prop', ({ Component }) => {
    const { container } = render(<Component className="custom-class" />);
    const svg = container.querySelector('svg');
    expect(svg).toHaveClass('custom-class');
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<GettingStartedIcon />);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });
});
