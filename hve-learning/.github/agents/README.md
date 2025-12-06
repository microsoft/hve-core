# HVE Learning Platform Agents

This directory contains specialized AI agents designed to provide enhanced assistance for learning content creation and coaching within the HVE Learning Platform.

## Available Components

### Learning Content Creator (Chat Mode)
**Moved to**: `.github/chatmodes/learning-content-creator.chatmode.md`

**Purpose**: Collaborative partner for creating effective learning content
- **Best for**: Designing katas, training labs, and learning assessments
- **Capabilities**: Template guidance, content structure, quality validation
- **Usage**: Switch to `learning-content-creator` chat mode and ask for content creation help

### Learning Kata Coach (`learning-kata-coach.agent.md`) 
**Purpose**: Focused practice guidance with progress tracking
- **Best for**: Individual skill-building exercises and kata completion
- **Capabilities**: Socratic questioning, progressive hints, skill assessment
- **Usage**: `@learning-kata-coach I'm working on [topic] and want interactive coaching`

### Learning Lab Coach (`learning-lab-coach.agent.md`)
**Purpose**: Comprehensive system coaching for complex scenarios
- **Best for**: Multi-component training labs and team-based learning
- **Capabilities**: OpenHack-style discovery coaching, collaboration guidance
- **Usage**: `@learning-lab-coach Guide me through [system/integration] learning`

## Agent Integration

### Activation
To activate an agent in GitHub Copilot Chat:
1. Open GitHub Copilot Chat in VS Code
2. Reference the agent: `@[agent-name]` 
3. Provide your learning context or content creation goals

### Learning Methodologies
All agents use:
- **Discovery-Based Learning**: OpenHack-style exploration and experimentation
- **Progressive Scaffolding**: Difficulty adapted to learner skill level
- **Schema-Driven Progress**: Structured tracking and validation
- **Inclusive Language**: Person-first terminology and accessible content

### File Structure
Each agent file contains:
- Agent description and capabilities
- Coaching methodologies and approaches
- Schema integration for progress tracking
- Template references and validation standards

## Quality Standards

### Content Validation
- All content must pass automated validation scripts
- Technical accuracy verified in clean environments
- Inclusive language standards enforced
- Time estimates validated through user testing

### Schema Compliance
Agents integrate with structured schemas for:
- `kata-progress-schema.json` - Individual exercise tracking
- `learning-path-progress-schema.json` - Sequential learning journeys  
- `self-assessment-schema.json` - Skill evaluation and recommendations

## Contributing

When modifying agents:
1. Maintain consistent coaching methodology
2. Preserve schema integration capabilities
3. Test with representative learning content
4. Validate against quality standards
5. Update documentation for any new capabilities

For questions or improvements, engage with the learning platform community through standard contribution processes.
