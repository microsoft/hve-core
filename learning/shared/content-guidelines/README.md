# Content Creation Guidelines

Comprehensive guidelines for creating, maintaining, and quality-assuring all learning content in the HVE Learning Platform.

## Overview

This directory contains the canonical guidelines and standards for all learning content creation within the HVE Learning Platform. These guidelines ensure consistency, quality, and effectiveness across all learning experiences.

## Guidelines Structure

### Core Documents

- **[Kata Creation Standards](kata-creation-standards.md)**: Template compliance, field requirements, and content structure standards
- **[AI Coaching Integration](ai-coaching-integration.md)**: Progress tracking, coaching features, and assessment integration
- **[Content Quality Standards](content-quality-standards.md)**: Quality assurance, review processes, and validation requirements

### Purpose and Scope

These guidelines serve as the definitive reference for:

- **Content Creators**: Authors developing new learning katas and materials
- **Technical Reviewers**: Subject matter experts validating content accuracy
- **Learning Experience Designers**: Professionals ensuring pedagogical soundness
- **AI Coaching Specialists**: Teams implementing AI-assisted learning features
- **Quality Assurance Teams**: Groups responsible for content validation and maintenance

## Quick Start

1. **New Content Creation**: Start with [Kata Creation Standards](kata-creation-standards.md)
2. **AI Features Integration**: Reference [AI Coaching Integration](ai-coaching-integration.md)
3. **Quality Validation**: Use [Content Quality Standards](content-quality-standards.md)

## Guidelines Application

### Mandatory Compliance

All learning content MUST adhere to these guidelines:

- Template compliance using `learning/shared/templates/kata-template.md`
- AI coaching schema integration for progress tracking
- Quality standards validation before publication
- Regular review and maintenance cycles

### Validation Tools

- **Template Validation**: `scripts/kata-validation/Validate-Katas.ps1`
- **Quality Checklists**: Embedded within each guideline document
- **AI Schema Validation**: Automated progress tracking validation
- **Content Review Process**: Multi-stage review requirements

## Content Creation Workflow

<!-- <content-creation-workflow> -->
### Phase 1: Planning and Design

1. **Learning Objectives Definition**: Identify specific, measurable learning outcomes
2. **Audience Analysis**: Understand prerequisite skills and target learner profile
3. **Content Scope**: Define kata scope within broader learning path context
4. **AI Integration Planning**: Determine coaching features and progress tracking needs

### Phase 2: Content Development

1. **Template Application**: Use `learning/shared/templates/kata-template.md` as foundation
2. **Content Writing**: Develop learning content following quality standards
3. **Technical Validation**: Test all instructions and code in clean environment
4. **AI Schema Integration**: Implement progress tracking and coaching features

### Phase 3: Quality Assurance

1. **Template Compliance**: Validate using `scripts/kata-validation/Validate-Katas.ps1`
2. **Multi-Stage Review**: Technical, pedagogical, and accessibility review
3. **Quality Checklist**: Complete comprehensive validation checklist
4. **Iterative Improvement**: Address feedback and validation results

### Phase 4: Publication and Maintenance

1. **Content Publishing**: Deploy validated content to learning platform
2. **Performance Monitoring**: Track learner outcomes and engagement
3. **Feedback Integration**: Incorporate user feedback and performance data
4. **Regular Updates**: Maintain content currency and technical accuracy
<!-- </content-creation-workflow> -->

## Quality Framework

<!-- <quality-framework-overview> -->
### Quality Pillars

- **Learning Effectiveness**: Content achieves stated learning objectives
- **Technical Accuracy**: All instructions and code are verified and current
- **Accessibility**: Content accommodates diverse learning styles and needs
- **Consistency**: Adherence to platform standards and conventions
- **Maintainability**: Content can be efficiently updated and maintained

### Validation Process

- **Automated Validation**: Template compliance and schema validation
- **Expert Review**: Technical accuracy and best practice alignment
- **User Testing**: Learner experience and accessibility validation
- **Continuous Monitoring**: Performance tracking and improvement cycles
<!-- </quality-framework-overview> -->

## Related Resources

- **Template Reference**: `learning/shared/templates/kata-template.md`
- **Schema Documentation**: `/.github/instructions/learning-coach-schema.instructions.md`
- **Validation Scripts**: `scripts/kata-validation/`
- **AI Coaching Prompt**: `.github/chatmodes/learning-kata-coach.chatmode.md`
- **Platform Documentation**: Repository-wide standards and conventions

---

*These guidelines are living documents that evolve with platform capabilities and learning science best practices. Contributions and improvements are welcomed through standard repository contribution processes.*
