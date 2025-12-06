# Kata Creation Standards

Comprehensive standards and requirements for creating new learning katas in the HVE Learning Platform.

## Template Compliance Requirements

<!-- <template-compliance-rules> -->
**CRITICAL**: All new katas MUST use the canonical template structure from `learning/shared/templates/kata-template.md`

### Required Fields Verification

Every kata MUST include all 30 template fields:

- **Core Metadata**: `title`, `description`, `category`, `difficulty`, `estimatedTime`, `learningPath`
- **Learning Design**: `objectives`, `prerequisites`, `outcomes`, `successCriteria`
- **AI Coaching**: `aiCoachingEnabled`, `aiCoachingStyle`, `progressTracking`, `checkpointSupport`
- **Technical**: `environment`, `tools`, `frameworks`, `files`, `setup`
- **Content Structure**: `instructions`, `tasks`, `validation`, `troubleshooting`
- **Meta Information**: `tags`, `version`, `lastUpdated`, `author`, `reviewers`
<!-- </template-compliance-rules> -->

### Field Validation Process

Use the validation script to ensure compliance:

```powershell
# Validate specific kata
.\scripts\kata-validation\Validate-Katas.ps1 -TemplateDiff -Path "learning/katas/category/kata-name.md"

# Validate all katas
.\scripts\kata-validation\Validate-Katas.ps1 -TemplateDiff -IncludeIndividualKatas
```

## Learning Design Principles

<!-- <learning-design-framework> -->
### OpenHack-Style Methodology

- **Discovery-Based Learning**: Guide learners to discover solutions rather than providing direct answers
- **Hands-On Practice**: Emphasize practical application over theoretical knowledge
- **Progressive Complexity**: Build skills incrementally through structured practice rounds
- **Real-World Context**: Connect practice to actual project scenarios and industry applications
- **Reflection Integration**: Include reflection prompts and learning consolidation activities
<!-- </learning-design-framework> -->

### Learning Objectives Structure

Learning objectives MUST follow this pattern:

- **Action-Oriented**: Use measurable verbs (implement, analyze, debug, optimize)
- **Skill-Specific**: Target specific competencies and capabilities
- **Context-Aware**: Connect to platform capabilities and real-world scenarios
- **Progressive**: Build on prerequisites and prepare for advanced topics

### Success Criteria Definition

Success criteria MUST be:

- **Measurable**: Observable behaviors and outcomes
- **Achievable**: Realistic within estimated time frame
- **Skill-Focused**: Demonstrate specific competency development
- **Validation-Ready**: Support automated or manual verification

## Content Quality Standards

<!-- <content-quality-requirements> -->
### Writing Standards

- **Clarity**: Use clear, direct language appropriate for technical audience
- **Conciseness**: Eliminate unnecessary verbosity while maintaining completeness
- **Consistency**: Follow established terminology and formatting conventions
- **Accessibility**: Ensure content is accessible to diverse learning styles and backgrounds

### Technical Accuracy

- **Verification**: All technical instructions must be tested and verified
- **Currency**: Content must reflect current platform capabilities and best practices
- **Completeness**: All required setup, tools, and prerequisites must be documented
- **Troubleshooting**: Include common issues and resolution strategies
<!-- </content-quality-requirements> -->

## AI Coaching Integration Requirements

<!-- <ai-coaching-standards> -->
### Schema Compliance

All katas with AI coaching MUST comply with schemas in `/docs/_server/schemas/`:

- **Progress Schema**: kata-progress-schema.json
- **Assessment Schema**: self-assessment-schema.json
- **Learning Path Schema**: learning-path-progress-schema.json

### Coaching Features

- **Progress Tracking**: Enable checkbox progress and file-based tracking
- **Checkpoint Support**: Provide resumption capabilities for multi-session katas
- **Mode Transitions**: Guide learners to appropriate AI assistance modes
- **Skill Assessment**: Integrate with assessment and recommendation systems

### Documentation Requirements

Reference the complete coaching integration guidelines in `ai-coaching-integration.md` for:

- Progress file management strategies
- Schema compliance validation
- Coaching interaction patterns
- Mode transition protocols
<!-- </ai-coaching-standards> -->

## Category and Path Integration

<!-- <category-integration-rules> -->
### Category Requirements

- **Category README**: Each category MUST have a compliant README.md file
- **Learning Path**: Categories should connect to broader learning path progression
- **Skill Progression**: Katas within categories should build skills progressively
- **Cross-References**: Include appropriate references to related categories and katas

### Learning Path Alignment

- **Foundation Paths**: Beginner-friendly introduction to platform concepts
- **Skill Development**: Intermediate practice in specific technical areas
- **Expert Practice**: Advanced integration and architectural decision-making
- **Specialization**: Domain-specific expertise development
<!-- </category-integration-rules> -->

## File Organization Standards

<!-- <file-organization-requirements> -->
### Directory Structure

```plain
learning/katas/{category}/
├── README.md                    # Category overview (template compliant)
├── {kata-name}.md              # Individual kata files (template compliant)
└── assets/                     # Supporting files and resources
    ├── images/                 # Kata-specific images
    ├── templates/              # Code templates and starter files
    └── examples/               # Reference implementations
```

### Naming Conventions

- **Categories**: Lowercase with hyphens (e.g., `ai-assisted-engineering`)
- **Kata Files**: Descriptive, kebab-case with logical ordering (e.g., `01-ai-development-fundamentals.md`)
- **Assets**: Organized by type with clear, descriptive names
- **Images**: Descriptive names with appropriate file extensions
<!-- </file-organization-requirements> -->

## Validation and Testing

<!-- <validation-requirements> -->
### Pre-Publication Checklist

- [ ] Template compliance validated using validation script
- [ ] All technical instructions tested in clean environment
- [ ] Learning objectives align with success criteria
- [ ] AI coaching features properly configured
- [ ] Progress tracking schema compliance verified
- [ ] Content quality review completed
- [ ] Peer review process completed

### Ongoing Maintenance

- **Regular Validation**: Run validation scripts periodically
- **Content Updates**: Keep content current with platform changes
- **Feedback Integration**: Incorporate learner and coach feedback
- **Performance Monitoring**: Track completion rates and learning outcomes
<!-- </validation-requirements> -->

## Content Review Process

<!-- <review-process-guidelines> -->
### Review Stages

1. **Self-Review**: Creator validates template compliance and quality standards
2. **Technical Review**: Subject matter expert validates technical accuracy
3. **Learning Design Review**: Learning experience expert validates pedagogical approach
4. **AI Coaching Review**: Coaching integration specialist validates schema compliance
5. **Final Approval**: Designated approver confirms readiness for publication

### Review Criteria

- **Template Compliance**: All required fields present and properly formatted
- **Learning Effectiveness**: Clear objectives, appropriate difficulty, measurable outcomes
- **Technical Accuracy**: Verified instructions, working code, current best practices
- **AI Integration**: Proper schema compliance, coaching features, progress tracking
- **Quality Standards**: Writing quality, accessibility, consistency with platform standards
<!-- </review-process-guidelines> -->

## Common Issues and Solutions

<!-- <common-issues-reference> -->
### Template Compliance Issues

- **Missing Fields**: Use validation script to identify and add missing template fields
- **YAML Errors**: Validate YAML front matter syntax and structure
- **Field Formatting**: Ensure proper field types (strings, arrays, objects)

### Content Quality Issues

- **Unclear Instructions**: Test instructions with fresh environment and naive user perspective
- **Missing Prerequisites**: Document all assumed knowledge and required setup
- **Incomplete Validation**: Provide clear success criteria and verification steps

### AI Coaching Issues

- **Schema Violations**: Use schema validation tools to ensure compliance
- **Progress Tracking**: Test checkbox functionality and file-based progress
- **Mode Transitions**: Verify appropriate coaching guidance for different AI assistance modes
<!-- </common-issues-reference> -->

## Reference Sources

<!-- <reference-sources> -->
- **Template Documentation**: `learning/shared/templates/kata-template.md`
- **Validation Scripts**: `scripts/kata-validation/Validate-Katas.ps1`
- **Schema Documentation**: `/.github/instructions/learning-coach-schema.instructions.md`
- **Coaching Guidelines**: `learning/shared/content-guidelines/ai-coaching-integration.md`
- **Quality Standards**: `learning/shared/content-guidelines/content-quality-standards.md`
<!-- </reference-sources> -->
