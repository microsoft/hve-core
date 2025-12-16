# HVE Learning Platform

A comprehensive AI-assisted learning platform designed for hyper-velocity engineering education. This platform provides structured learning experiences through katas, training labs, and AI-powered coaching.

## 🎯 Platform Purpose

The HVE Learning Platform serves two primary purposes:

### 1. Central Learning Gateway

Serves as a comprehensive learning hub that can coach you on:

- **Generic Topics**: Using katas stored in this repository for foundational engineering skills
- **Domain-Specific Topics**: Using katas stored in corresponding accelerator repositories (CAIRA, edge-ai, etc.)
- **Scenario-Based Learning Paths**: Navigate comprehensive multi-accelerator learning journeys (e.g., "Create an AI agentic system") that orchestrate katas from multiple accelerator repositories into cohesive end-to-end experiences

### 2. Learning Content Creation Tool

Empowers developers to create high-quality learning content (katas, labs) using AI-assisted workflows and validated templates.

## 🚀 Getting Started

### Prerequisites

<!-- markdownlint-disable MD036 -->
**GitHub MCP Server in VS Code**
<!-- markdownlint-enable MD036 -->

The platform requires the GitHub MCP (Model Context Protocol) server to be configured in VS Code for full functionality:

1. Ensure you have the latest version of VS Code with GitHub Copilot
2. Configure the GitHub MCP server in your VS Code settings
3. Authenticate with your GitHub account to enable MCP capabilities

This enables AI coaches to interact with GitHub repositories, track learning progress, and provide context-aware assistance.

### For Learners

You have two options to start learning:

#### Option 1: Work Directly in this Repository

1. Clone/open the `hve-learning` repository
2. Select `learning-kata-coach` from the Agents dropdown
3. Start your learning session:

   ```text
   Coach me on edge deployments katas
   ```

#### Option 2: Use the VS Code Extension

1. Install the HVE Learning VS Code extension
2. Open any accelerator repository (e.g., CAIRA, edge-ai)
3. Select `learning-kata-coach` from the Agents dropdown
4. Start your learning session directly in the domain context:

   ```text
   Coach me on deploying AI infra with CAIRA katas
   ```

### For Content Creators

Developers working on new learning content:

1. Install the HVE Learning Platform VS Code extension
2. Open your accelerator repository (e.g., CAIRA)
3. Select `learning-content-creator` from the Agents dropdown
4. Start creating content:

   ```text
   Let's work on production troubleshooting kata
   ```

The extension provides all templates, schemas, and validation tools needed to create high-quality learning content in any repository.

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

```text
hve-learning/
├── .github/
│   ├── agents/                 # AI coaching agents
│   │   ├── learning-content-creator.agent.md
│   │   ├── learning-kata-coach.agent.md
│   │   └── learning-lab-coach.agent.md
│   ├── instructions/           # Learning content guidelines
│   │   ├── kata-content.instructions.md
│   │   ├── kata-category-readme.instructions.md
│   │   ├── learning-coach-schema.instructions.md
│   │   ├── learning-path-content.instructions.md
│   │   ├── markdown.instructions.md
│   │   └── training-lab-content.instructions.md
│   └── workflows/              # GitHub Actions CI/CD
│       ├── code-quality.yml
│       ├── pr.yml
│       └── ci.yml
├── learning/
│   └── shared/                 # Reusable learning resources
│       ├── templates/          # Content templates
│       ├── schema/             # Validation schemas
│       └── content-guidelines/ # Quality standards
├── scripts/
│   ├── learning/              # Automation and validation tools
│   │   ├── Generate-LearningCatalog.ps1
│   │   ├── Validate-CatalogConsistency.ps1
│   │   └── kata-validation/
│   └── linting/               # Code quality scripts
│       ├── Invoke-SpellCheck.ps1
│       ├── Invoke-MarkdownLint.ps1
│       └── Invoke-TableFormat.ps1
└── docs/_server/schemas/      # API and progress tracking schemas
```

## 🎓 Choose Your Learning Path

- **Foundation Builder**: New to platform concepts
- **Skill Developer**: Some experience, ready for structured practice
- **Expert Practitioner**: Advanced learner seeking mastery

## 🤖 Using AI Coaching Agents

Use the specialized agents for guided learning:

**For Focused Practice (Katas):**

```text
@learning-kata-coach I'm working on [topic] and want interactive coaching
```

**For Complex Systems (Training Labs):**

```text
@learning-lab-coach Guide me through [system/integration] learning
```

**For Content Creation:**

```text
@learning-content-creator Help me create learning content for [topic]
```

## 📊 Track Your Progress

- Checkbox-based progress tracking in each kata
- Automated skill assessment and recommendations
- Personalized learning path generation

## 📋 Content Creation Guidelines

### Kata Development

1. Use `learning/shared/templates/kata-template.md`
2. Follow 28 YAML front-matter fields (21 required + 7 optional)
3. Implement flat checkbox structure (no nested content)
4. Include AI coaching integration points

### Quality Standards

- **Inclusive Language**: No "master/mastery" terminology
- **Time Accuracy**: ±10% of stated completion time
- **Technical Validation**: All code/commands tested
- **Progressive Difficulty**: Scaffolding appropriate to skill level

### Validation Tools

- `scripts/learning/kata-validation/Validate-Katas.ps1`
- Automated front-matter validation
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
- **YAML Front-matter**: Structured metadata for AI coaching integration
- **Progressive Disclosure**: Information revealed as needed
- **Cross-References**: Linked learning experiences

### Validation Pipeline

- **Automated Testing**: All instructions verified in clean environments
- **Schema Compliance**: YAML front-matter validation
- **Link Verification**: Internal and external reference checking
- **Style Enforcement**: Markdown standards and inclusive language

## 🤝 Contributing

### Content Creation Workflow

1. **Discovery**: Use `@learning-content-creator` for collaborative design
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

## 🔒 Security

See [SECURITY.md](SECURITY.md) for information on reporting security vulnerabilities.

## 💬 Support

See [SUPPORT.md](SUPPORT.md) for information on getting help and support.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

Ready to start learning? Activate a coaching mode and begin your hyper-velocity engineering journey!
