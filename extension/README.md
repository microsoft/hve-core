---
title: HVE Core - AI-Powered Development Assistant
description: AI-powered chat agents, prompts, and instructions for hybrid virtual environments
author: Microsoft
ms.date: 2025-12-19
ms.topic: overview
---

> AI-powered chat agents, prompts, and instructions for hybrid virtual environments

HVE Core provides a comprehensive collection of specialized AI chat agents, prompts, and instructions designed to accelerate development workflows in VS Code with GitHub Copilot.

## Features

### 🤖 Chat Agents

Specialized AI assistants for specific development tasks:

#### Development Workflow

- **task-researcher** - Research technical solutions and approaches
- **task-planner** - Plan and break down complex tasks
- **task-implementor** - Implement tasks from detailed plans
- **pr-review** - Comprehensive pull request review assistant
- **github-issue-manager** - Manage GitHub issues efficiently

#### Architecture & Documentation

- **adr-creation** - Create Architecture Decision Records
- **arch-diagram-builder** - Build high-quality ASCII-art architecture diagrams
- **brd-builder** - Build Business Requirements Documents with guided Q&A
- **prd-builder** - Build Product Requirements Documents with guided Q&A
- **prompt-builder** - Build and optimize AI prompts
- **security-plan-creator** - Expert security architect for creating comprehensive cloud security plans

#### Azure DevOps Integration

- **ado-prd-to-wit** - Convert Product Requirements Documents to Azure DevOps work items

#### Data Science & Visualization

- **gen-data-spec** - Generate data specifications and schemas
- **gen-jupyter-notebook** - Generate Jupyter notebooks for data analysis
- **gen-streamlit-dashboard** - Generate Streamlit dashboards
- **test-streamlit-dashboard** - Comprehensive testing of Streamlit dashboards

### 📝 Prompts

Reusable prompt templates for common workflows:

- **Git Operations** - Commit messages, merges, setup, and pull requests
- **GitHub Workflows** - Issue creation and management
- **Azure DevOps** - PR creation, build info, and work item management

### 📚 Instructions

Best practice guidelines for:

- **Languages** - Bash, Python, C#, Bicep
- **Git & Version Control** - Commit messages, merge operations
- **Documentation** - Markdown formatting
- **Azure DevOps** - Work item management and PR workflows
- **Task Management** - Implementation tracking and planning
- **Project Management** - UV projects and dependencies

## Getting Started

After installing this extension, the chat agents will be available in GitHub Copilot Chat. You can:

1. **Use chat agents** by typing `@agent-name` in Copilot Chat
2. **Apply prompts** through the Copilot Chat interface
3. **Reference instructions** - They're automatically applied based on file patterns

## Usage Examples

### Using Chat Agents

```plaintext
@task-planner help me break down this feature into implementable tasks
@pr-review review this pull request for security issues
@adr-creation create an ADR for our new microservice architecture
```

### Applying Prompts

Prompts are available in the Copilot Chat prompt picker and can be used to generate consistent, high-quality outputs for common tasks.

## Requirements

- VS Code version 1.106.1 or higher
- GitHub Copilot extension

## License

MIT License - see [LICENSE](LICENSE) for details

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/microsoft/hve-core).

---

Brought to you by Microsoft ISE HVE Essentials
