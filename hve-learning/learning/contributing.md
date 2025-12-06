---
title: Contributing to the Learning Platform
description: Guidelines for contributing katas, training labs, and content to the Learning Platform
author: HVE Essentials Team
ms.date: 2025-07-21
ms.topic: hub-page
estimated_reading_time: 15
difficulty: all levels
keywords:
  - learning platform
  - contributing
  - community
  - ai-assisted engineering
---

## Overview

The Learning Platform welcomes contributions from the community! This guide provides guidelines for contributing high-quality katas, training labs, and other content to the platform.

### Types of Contributions

- **Katas**: Short, focused practice exercises (15-45 minutes)
- **Training Labs**: Comprehensive hands-on labs (2-50+ hours)
- **Documentation**: Improvements to existing content
- **Tools & Scripts**: Utilities to enhance the learning experience

## Contribution Standards

### Content Quality Requirements

All contributions must meet these standards:

- **Educational Value**: Clear learning objectives and practical skills
- **Technical Accuracy**: Verified and tested content
- **Accessibility**: Clear instructions for different skill levels
- **Completeness**: All necessary resources and dependencies included

### Documentation Standards

- Use the standard frontmatter template for consistency
- Follow markdown formatting guidelines from [`.mega-linter.yml`][mega-linter]
- Include proper headings, code blocks, and tables
- Provide clear navigation and cross-references

### Code Standards

- Follow existing workspace patterns and conventions
- Include error handling and validation
- Provide clear comments and documentation
- Test all code examples and scripts

## Contribution Process

### 1. Planning Your Contribution

1. **Review existing content** to avoid duplication
2. **Identify the learning gap** your contribution will fill
3. **Choose the appropriate type** (kata, lab, documentation)
4. **Define clear learning objectives** and success criteria

### 2. Content Development

1. **Use the appropriate template** from [`/learning/shared/templates/`][templates-directory]
2. **Follow the standard frontmatter format**
3. **Structure content** according to template guidelines
4. **Test all instructions** and code examples
5. **Review for accessibility** and clarity

### 3. Submission Process

1. **Create a fork** of the repository
2. **Add your content** to the appropriate directory:
   - Katas: [`/learning/katas/[category]/`][katas-directory]
   - Training Labs: [`/learning/training-labs/[track]/`][training-labs-directory]
3. **Update navigation** and index files as needed
4. **Test the complete experience** end-to-end
5. **Submit a pull request** with clear description

### 4. Review Process

All contributions go through:

- **Technical review** for accuracy and completeness
- **Educational review** for learning effectiveness
- **Editorial review** for clarity and consistency
- **Testing** by community volunteers

## Content Guidelines

### For Katas

- **Duration**: 15-45 minutes maximum
- **Focus**: Single skill or concept proficiency
- **Structure**: 3-round practice progression
- **Validation**: Clear success criteria
- **Repeatability**: Can be practiced multiple times

### For Training Labs

- **Duration**: 2-50+ hours depending on complexity
- **Scope**: Comprehensive learning experience
- **Modules**: Break into logical sections
- **Validation**: Checkpoints throughout
- **Resources**: All necessary tools and references

### For Documentation

- **Accuracy**: Verify all information
- **Completeness**: Cover all necessary details
- **Navigation**: Clear links and references
- **Maintenance**: Keep content current

## Templates and Examples

### Required Templates

Use these templates for consistency:

- **Kata Template**: [`/learning/shared/templates/kata-template.md`][kata-template]
- **Training Lab Template**: [`/learning/shared/templates/training-lab-template.md`][training-lab-template]
- **Hub Page Template**: [`/learning/shared/templates/hub-page-template.md`][hub-page-template]

### Example Content

Reference these for structure and quality:

- **Sample Katas**: [`/learning/katas/*/`][katas-directory] directories
- **Sample Labs**: [`/learning/training-labs/*/`][training-labs-directory] directories

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and improve
- Follow project contribution guidelines

### Getting Help

- **Discussions**: Use [GitHub Discussions][github-discussions] for questions
- **Issues**: Report bugs or suggest improvements through [GitHub Issues][github-issues]
- **Community**: Join community showcases and feedback sessions

## Technical Requirements

### Development Environment

- Use the provided [dev container][devcontainers] for consistency
- Test with the same tools and versions using [VS Code][vscode]
- Validate with project linting and testing tools
- Follow [Azure development best practices][azure-dev-best-practices]

### File Organization

- Follow the established directory structure
- Use consistent naming conventions
- Include all necessary supporting files
- Update index and navigation files

### Testing Requirements

- Verify all commands and code examples
- Test on clean environment
- Validate learning progression
- Check all links and references

## Recognition

Contributors will be recognized through:

- **Author attribution** in contributed content
- **Community showcase** features
- **Contributor listings** in project documentation
- **Special recognition** for outstanding contributions

---

*Thank you for contributing to the Learning Platform and helping build the future of AI-assisted engineering education!*

<!-- Reference Links -->
[azure-dev-best-practices]: https://learn.microsoft.com/azure/developer/
[devcontainers]: https://learn.microsoft.com/visualstudio/vscode/remote/containers
[github-discussions]: https://docs.github.com/discussions
[github-issues]: https://docs.github.com/issues
[hub-page-template]: /learning/shared/templates/hub-page-template.md
[kata-template]: /learning/shared/templates/kata-template.md
[katas-directory]: /learning/katas/
[mega-linter]: /.mega-linter.yml
[templates-directory]: /learning/shared/templates/
[training-lab-template]: /learning/shared/templates/training-lab-template.md
[training-labs-directory]: /learning/training-labs/
[vscode]: https://learn.microsoft.com/visualstudio/vscode/

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
