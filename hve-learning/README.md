# HVE Learning Platform

A comprehensive AI-assisted learning platform designed for hyper-velocity engineering education. This platform provides structured learning experiences through katas, training labs, and AI-powered coaching.

## 🌟 Platform Overview

The HVE (Hyper-Velocity Engineering) Learning Platform combines AI assistance with practical engineering challenges, empowering engineers to achieve more through structured, progressive learning experiences.

### Core Philosophy

- **AI-Assisted Learning**: Integrated AI coaching throughout the learning journey
- **Discovery-Based**: OpenHack-style methodology promoting hands-on exploration
- **Progressive Mastery**: Carefully sequenced learning paths building real-world skills
- **Practical Focus**: All exercises solve actual engineering challenges

## 🎯 Learning Components

### 🥋 Katas (15-45 minutes)
Focused practice exercises designed for skill building:
- **Quick Context**: Immediate problem understanding
- **Essential Setup**: Minimal prerequisites
- **Practice Tasks**: Hands-on skill development
- **Completion Check**: Measurable outcomes

### 🧪 Training Labs (2+ hours)
Comprehensive learning experiences for complex systems:
- **Multi-Module Structure**: Progressive complexity building
- **Team-Based Options**: Collaborative learning support
- **Integration Focus**: Real-world system interactions
- **Assessment Integration**: Skill validation checkpoints

### 🤖 AI Coaching Modes
Specialized AI assistants for different learning needs:
- **Learning Kata Coach**: Focused practice guidance with progress tracking
- **Learning Lab Coach**: Comprehensive system coaching for complex scenarios
- **Learning Content Creator**: Collaborative content development partner

## 📁 Platform Structure

```
hve-learning/
├── .github/
│   ├── agents/                 # AI coaching agents
│   │   ├── learning-content-creator.agent.md
│   │   ├── learning-kata-coach.agent.md
│   │   └── learning-lab-coach.agent.md
│   └── instructions/           # Learning content guidelines
│       ├── kata-content.instructions.md
│       ├── kata-category-readme.instructions.md
│       ├── learning-coach-schema.instructions.md
│       ├── learning-path-content.instructions.md
│       ├── markdown.instructions.md
│       └── training-lab-content.instructions.md
├── learning/
│   └── shared/                 # Reusable learning resources
│       ├── templates/          # Content templates
│       ├── schema/             # Validation schemas
│       └── content-guidelines/ # Quality standards
├── scripts/
│   └── learning/              # Automation and validation tools
│       ├── Generate-LearningCatalog.ps1
│       ├── Validate-CatalogConsistency.ps1
│       └── kata-validation/
└── docs/_server/schemas/      # API and progress tracking schemas
```

## 🚀 Quick Start

### 1. Choose Your Learning Path
- **Foundation Builder**: New to platform concepts
- **Skill Developer**: Some experience, ready for structured practice
- **Expert Practitioner**: Advanced learner seeking mastery

### 2. Activate AI Coaching
Use the specialized agents for guided learning:

**For Focused Practice (Katas):**
```
@learning-kata-coach I'm working on [topic] and want interactive coaching
```

**For Complex Systems (Training Labs):**
```
@learning-lab-coach Guide me through [system/integration] learning
```

**For Content Creation:**
```
# Switch to learning-content-creator mode: Help me create learning content for [topic]
```

### 3. Track Your Progress
- Checkbox-based progress tracking in each kata
- Automated skill assessment and recommendations
- Personalized learning path generation

## 📋 Content Creation Guidelines

### Kata Development
1. Use `learning/shared/templates/kata-template.md`
2. Follow 28 YAML frontmatter fields (21 required + 7 optional)
3. Implement flat checkbox structure (no nested content)
4. Include AI coaching integration points

### Quality Standards
- **Inclusive Language**: No "master/mastery" terminology
- **Time Accuracy**: ±10% of stated completion time
- **Technical Validation**: All code/commands tested
- **Progressive Difficulty**: Scaffolding appropriate to skill level

### Validation Tools
- `scripts/learning/kata-validation/Validate-Katas.ps1`
- Automated frontmatter validation
- Learning path consistency checks
- Content quality assessments

## 🎨 AI Coaching Integration

### Schema-Driven Progress Tracking
The platform uses structured schemas for:
- **Kata Progress**: `docs/_server/schemas/kata-progress-schema.json`
- **Learning Paths**: `docs/_server/schemas/learning-path-progress-schema.json`
- **Skill Assessment**: `docs/_server/schemas/self-assessment-schema.json`

### Coaching Methodologies
- **Socratic Questioning**: Guides discovery rather than providing answers
- **Progressive Hints**: Incremental guidance when learners are stuck
- **Metacognitive Validation**: Reflection and self-explanation exercises
- **Learning Transfer**: Connecting concepts across different contexts

## 📚 Learning Science Foundation

### OpenHack Methodology
- **Challenge-Based**: Real problems drive learning motivation
- **Discovery-Oriented**: Learners explore and experiment
- **Failure-Positive**: Learning from mistakes is encouraged
- **Coach-Supported**: Guidance available but not prescriptive

### Scaffolding Levels
- **Heavy** (Beginner): Step-by-step with expected outputs
- **Medium** (Intermediate): Framework with reference links
- **Minimal** (Advanced): Objectives and success criteria only

## 🔧 Technical Implementation

### Template System
- **Consistent Structure**: All content follows validated templates
- **YAML Frontmatter**: Structured metadata for AI coaching integration
- **Progressive Disclosure**: Information revealed as needed
- **Cross-References**: Linked learning experiences

### Validation Pipeline
- **Automated Testing**: All instructions verified in clean environments
- **Schema Compliance**: YAML frontmatter validation
- **Link Verification**: Internal and external reference checking
- **Style Enforcement**: Markdown standards and inclusive language

## 🤝 Contributing

### Content Creation Workflow
1. **Discovery**: Use `learning-content-creator` chat mode for collaborative design
2. **Template Application**: Apply appropriate shared template
3. **Content Development**: Write following quality guidelines
4. **Validation**: Run automated checks and user testing
5. **Integration**: Deploy with progress tracking enabled

### Quality Assurance
- All content must pass `Validate-Katas.ps1` checks
- User testing with target audience required
- Technical accuracy verification in clean environments
- Accessibility and inclusive language review

## 📄 License

MIT License

## 🔗 Integration

This platform can be integrated into any development environment by copying the `.github/agents` and `.github/instructions` directories to enable AI-assisted learning capabilities.

For VS Code integration, add to your `.devcontainer.json`:

```json
{
  "mounts": [
    "source=${localWorkspaceFolder}/.github/agents,target=${containerWorkspaceFolder}/.github/agents,type=bind",
    "source=${localWorkspaceFolder}/.github/instructions,target=${containerWorkspaceFolder}/.github/instructions,type=bind"
  ]
}
```

Ready to start learning? Activate a coaching mode and begin your hyper-velocity engineering journey!
