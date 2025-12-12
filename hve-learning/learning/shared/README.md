---
title: Learning Platform Shared Resources
description: Templates, scripts, tools, and documentation supporting the learning platform
author: HVE Essentials Team
ms.date: 2025-06-15
ms.topic: hub-page
estimated_reading_time: 8
difficulty: all levels
keywords:
  - learning
  - shared resources
  - templates
  - tools
  - documentation
---

## Overview

The Learning Platform Shared Resources provide templates, scripts, tools, and documentation that support the entire learning platform. These resources ensure consistency, accelerate content creation, and enhance the learning experience following [Microsoft documentation standards][documentation-standards] and [VS Code best practices][vscode-docs].

### What You'll Find Here

- **Templates**: Standardized formats for katas, labs, and documentation following [Markdown guidelines][markdown-guide]
- **Scripts**: Automation tools for environment setup and validation
- **Tools**: Utilities for learning, practice, and development with [GitHub integration][github-docs]
- **Documentation**: Guidelines, standards, and best practices using [Azure DevOps templates][azure-devops-templates]

### Resource Categories

| Category                           | Purpose                           | Primary Users                  |
|------------------------------------|-----------------------------------|--------------------------------|
| **[Templates][templates-section]** | Content creation standards        | Content creators, contributors |
| **[Scripts][scripts-section]**     | Automation and validation         | Learners, instructors          |
| **[Tools][tools-section]**         | Learning enhancement utilities    | All users                      |
| **[Documentation][docs-section]**  | Platform guidelines and standards | Contributors, maintainers      |

## Templates

### Content Templates

Standardized templates ensure consistency across all learning platform content:

#### Available Templates

| Template                                               | Purpose                          | Usage                             |
|--------------------------------------------------------|----------------------------------|-----------------------------------|
| **[Kata Template][kata-template]**                     | Practice exercise structure      | Creating new katas                |
| **[Training Lab Template][training-lab-template]**     | Comprehensive lab structure      | Creating new training labs        |
| **[Hub Page Template][hub-page-template]**             | Navigation page structure        | Creating index and overview pages |
| **[Contribution Guidelines][contribution-guidelines]** | Community contribution standards | Contributors and maintainers      |

#### Template Features

- **Standard Frontmatter**: Consistent metadata across all content
- **Structured Layouts**: Proven organization patterns for effective learning
- **Accessibility Features**: Inclusive design and clear navigation
- **Integration Points**: Seamless connection with platform navigation

### Using Templates

#### For Content Creators

1. **Select Appropriate Template**: Choose based on content type
2. **Follow Structure**: Maintain template organization and sections
3. **Customize Content**: Replace placeholders with specific content
4. **Validate Format**: Ensure frontmatter and markdown compliance

#### For Contributors

1. **Review [Contribution Guidelines][contribution-guidelines]**: Understand standards and processes
2. **Use Required Templates**: Follow template structure for contributions
3. **Submit for Review**: Follow contribution process for new content

## Scripts

### Automation and Validation

Scripts provide automation for common tasks and validation of environments:

#### Environment Scripts

- **Setup Validation**: Verify development environment readiness
- **Dependency Installation**: Automated tool and service setup
- **Configuration Management**: Standard environment configuration

#### Content Validation

- **Template Compliance**: Verify content follows template standards
- **Link Validation**: Check all internal and external links
- **Markdown Linting**: Ensure markdown formatting compliance

#### Learning Support

- **Progress Tracking**: Monitor learning progression and completion
- **Performance Metrics**: Collect and analyze learning effectiveness data
- **Automation Helpers**: Streamline repetitive learning tasks

### Script Usage

#### For Learners

```bash
# Validate environment setup
./scripts/validate-environment.sh

# Check learning progress
./scripts/check-progress.sh

# Reset lab environment
./scripts/reset-lab.sh
```

#### Script Usage for Content Creators

```bash
# Validate new content
./scripts/validate-content.sh [content-path]

# Generate content index
./scripts/generate-index.sh [directory]

# Check template compliance
./scripts/check-template.sh [file-path]
```

## Tools

### Learning Enhancement Utilities

Tools that enhance the learning experience and provide additional capabilities:

#### Learning Tools

- **Progress Trackers**: Monitor completion and skill development
- **Assessment Tools**: Evaluate learning and identify improvement areas
- **Practice Generators**: Create additional practice scenarios
- **Performance Analyzers**: Measure learning effectiveness

#### Development Tools

- **AI Assistant Integrations**: Enhanced AI coding assistant configurations
- **Prompt Libraries**: Reusable prompt collections for common scenarios
- **Workflow Automation**: AI-assisted development workflow tools
- **Quality Validators**: Code and content quality assessment tools

#### Platform Tools

- **Content Management**: Tools for organizing and maintaining platform content
- **Navigation Generators**: Automated navigation and index creation
- **Integration Utilities**: Platform integration and synchronization tools

### Tool Installation and Usage

#### Prerequisites

- Completed [environment setup][environment-setup]
- Access to development tools and platforms
- Understanding of relevant programming languages and tools

#### Installation

Most tools are included in the dev container or can be installed via platform package managers:

```bash
# Install platform tools
./scripts/install-platform-tools.sh

# Configure AI assistant integrations
./scripts/configure-ai-tools.sh

# Set up learning utilities
./scripts/setup-learning-tools.sh
```

## Documentation

### Platform Guidelines and Standards

Comprehensive documentation covering platform standards, guidelines, and best practices:

#### Content Standards

- **Writing Guidelines**: Clear, consistent content creation standards
- **Technical Standards**: Code, configuration, and tool standards
- **Quality Criteria**: Content quality assessment and improvement guidelines
- **Accessibility Standards**: Inclusive design and accessibility requirements

#### Platform Architecture

- **Learning Design**: Educational methodology and learning experience design
- **Technical Architecture**: Platform structure, integration, and maintenance
- **Content Organization**: Information architecture and navigation design
- **Community Management**: Community guidelines and governance

#### Contribution Process

- **Getting Started**: Guide for new contributors
- **Content Creation**: Step-by-step content development process
- **Review Process**: Quality assurance and approval workflows
- **Maintenance**: Ongoing content updates and platform maintenance

## Usage Guidelines

### Resource Access for Learners

#### Accessing Resources

1. **Browse Templates**: Understand content structure and organization
2. **Use Scripts**: Leverage automation for environment and validation tasks
3. **Explore Tools**: Enhance learning with available utilities
4. **Reference Documentation**: Understand platform standards and guidelines

#### Best Practices

- **Follow Standards**: Use platform conventions and standards
- **Leverage Automation**: Use scripts and tools to streamline learning
- **Share Feedback**: Contribute improvements and suggestions
- **Contribute Back**: Share learnings and create new content

### Content Creation for Contributors

#### Content Creation Workflow

1. **Review Guidelines**: Understand contribution standards and processes
2. **Select Templates**: Choose appropriate template for content type
3. **Create Content**: Follow template structure and platform standards
4. **Validate Content**: Use scripts and tools for quality assurance
5. **Submit Contribution**: Follow review and approval process

#### Quality Assurance

- **Template Compliance**: Ensure content follows template standards
- **Technical Validation**: Verify all code, scripts, and configurations
- **Educational Review**: Confirm learning objectives and effectiveness
- **Community Review**: Engage community for feedback and improvement

## Getting Help

### Support Resources

- **Documentation**: Comprehensive guides and standards documentation
- **Community Forums**: Platform-specific support and discussion
- **Office Hours**: Regular support sessions for contributors and maintainers
- **Issue Tracking**: Report problems and request improvements

### Common Questions

#### How do I create new content?

**Process**: Review [contribution guidelines][contribution-guidelines], select appropriate template, follow creation workflow.

#### Can I modify existing templates?

**Yes**: Template improvements are welcome. Follow contribution process for template updates.

#### How do I report issues with tools or scripts?

**Method**: Use GitHub issues to report problems or request new features.

#### Can I contribute new tools or scripts?

**Absolutely**: New tools and automation are welcome. Follow contribution guidelines for code contributions.

---

**Ready to explore shared resources?**

📁 **[Browse Templates][templates-section]** | 🛠️ **[Explore Tools][tools-section]** | 📚 **[Read Documentation][docs-section]**

---

*Shared resources accelerate learning and ensure platform consistency. Explore the available resources and contribute to the community.*

<!-- Reference Links -->
[templates-section]: /learning/shared/templates/README
[scripts-section]: /learning/shared/scripts/README
[tools-section]: /learning/shared/tools/README
[docs-section]: /learning/shared/docs/README
[kata-template]: /learning/shared/templates/kata-template
[training-lab-template]: /learning/shared/templates/training-lab-template
[hub-page-template]: /learning/shared/templates/hub-page-template
[contribution-guidelines]: /learning/contributing
[environment-setup]: /docs/getting-started/
[vscode-docs]: https://code.visualstudio.com/docs
[github-docs]: https://docs.github.com
[markdown-guide]: https://docs.microsoft.com/contribute/markdown-reference
[azure-devops-templates]: https://docs.microsoft.com/azure/devops/pipelines/process/templates
[documentation-standards]: https://docs.microsoft.com/style-guide/welcome

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
