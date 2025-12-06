# AI Coaching Integration

Guidelines for implementing AI coaching features, schema compliance, and progress tracking in learning katas.

## Schema Compliance Framework

<!-- <schema-compliance-requirements> -->
**CRITICAL**: All AI coaching features MUST comply with JSON schemas located in `/docs/_server/schemas/`

### Required Schemas

- **Kata Progress**: `kata-progress-schema.json` - Individual kata progress tracking
- **Self-Assessment**: `self-assessment-schema.json` - Skill assessment and recommendations
- **Learning Path**: `learning-path-progress-schema.json` - Multi-kata learning journey tracking

### Validation Requirements

- **Schema Validation**: All progress files MUST validate against their respective schemas
- **File Naming**: Follow naming conventions specified in learning-coach-schema.instructions.md
- **Storage Location**: Use `/.copilot-tracking/learning/` for all progress files
- **Source Attribution**: Always set `"source": "coach"` for coach-generated files
<!-- </schema-compliance-requirements> -->

## Progress Tracking Implementation

<!-- <progress-tracking-setup> -->
### Checkbox Progress Integration

Katas with interactive progress MUST support:

- **Markdown Checkboxes**: Use `[ ]` and `[x]` syntax for task completion tracking
- **Local Storage Sync**: Progress persists in browser local storage when using docsify
- **File-Based Backup**: Coach creates JSON progress files for comprehensive tracking
- **Reset Functionality**: Support for clearing progress and starting fresh

### Progress File Management

Follow the intelligent file management strategy:

- **Per-Kata Updates**: Reuse files for the same kata across sessions
- **Unique Naming**: Use kataId and timestamp for file identification
- **Consistent IDs**: Maintain exact kataId formatting across all files
- **Circular Prevention**: Avoid creating progress files when reading existing progress
<!-- </progress-tracking-setup> -->

## Coaching Interaction Patterns

<!-- <coaching-interaction-guidelines> -->
### Discovery-Based Coaching

Implement coaching that:

- **Guides Discovery**: Ask questions that lead learners to solutions
- **Provides Progressive Hints**: Escalate guidance levels based on learner needs
- **Encourages Experimentation**: Support hands-on learning and productive failure
- **Builds Confidence**: Help learners develop problem-solving skills and engineering intuition

### Progress-Aware Guidance

Coaching MUST adapt based on:

- **Current Progress**: Reference completed tasks and demonstrated skills
- **Progress Patterns**: Identify where learners typically struggle or excel
- **Session Resumption**: Help learners continue from previous checkpoints
- **Skill Gaps**: Provide targeted guidance for identified knowledge gaps
<!-- </coaching-interaction-guidelines> -->

## Mode Transition Support

<!-- <mode-transition-framework> -->
### AI Assistance Mode Integration

Prepare learners for different AI assistance modes:

- **Exploration Mode**: Open-ended discovery and broad questioning
- **Implementation Mode**: Specific coding tasks with step-by-step guidance
- **Review Mode**: Code review, optimization, and best practice analysis
- **Debugging Mode**: Systematic troubleshooting and error resolution

### Advanced Chatmode Transitions

Guide learners to specialized chatmodes when appropriate:

- **Task Research**: Switch to `@task-researcher` for comprehensive analysis
- **Task Planning**: Use `@task-planner` for structured implementation plans
- **Project Planning**: Apply `@learning-project-planner` for real-world scenarios
- **Hyper-Velocity Workflow**: Introduce complete project lifecycle management
<!-- </mode-transition-framework> -->

## Learning Path Integration

<!-- <learning-path-integration> -->
### Path-Aware Coaching

When coaching within learning paths:

- **Path Context**: Reference position within broader learning journey
- **Progress Reinforcement**: Acknowledge overall path completion percentage
- **Connection Building**: Link current kata to previous and upcoming content
- **Milestone Recognition**: Celebrate achievement of learning path milestones

### Cross-Kata Learning Transfer

Help learners connect knowledge across their learning path:

- **Skill Building**: Reference techniques from previous katas
- **Pattern Recognition**: Identify recurring concepts and approaches
- **Competency Integration**: Combine skills from multiple katas for complex challenges
- **Real-World Application**: Connect kata skills to actual project scenarios
<!-- </learning-path-integration> -->

## Assessment and Recommendation System

<!-- <assessment-system-integration> -->
### Skill Assessment Workflows

Support both comprehensive and focused assessment approaches:

- **Interactive Assessment**: Full 26-question evaluation across 4 skill areas
- **Self-Assessment Workflow**: Focused 15-question evaluation with persistent progress files
- **Real-Time Scoring**: Provide immediate feedback and category-specific insights
- **Personalized Recommendations**: Generate kata recommendations based on assessment results

### Assessment File Creation

For self-assessment workflow, create compliant progress files:

```json
{
  "metadata": {
    "version": "1.0",
    "fileType": "self-assessment-progress",
    "source": "coach",
    "kataId": "self-assessment-workflow",
    "sessionId": "[unique-session-id]",
    "createdBy": "kata-coach",
    "lastModified": "[iso-timestamp]"
  },
  "assessment": {
    "type": "focused-self-assessment",
    "totalQuestions": 12,
    "completed": true,
    "categories": { ... },
    "overallScore": 0.0,
    "skillLevel": "beginner|intermediate|advanced"
  },
  "coaching": {
    "recommendations": [],
    "suggestedKatas": [],
    "learningPath": "foundation|skill-developer|expert-practitioner"
  }
}
```
<!-- </assessment-system-integration> -->

## Coaching Quality Standards

<!-- <coaching-quality-requirements> -->
### Interaction Quality

Coaching interactions MUST demonstrate:

- **Active Listening**: Acknowledge learner responses and build on their input
- **Pattern Recognition**: Identify and communicate learning patterns and strengths
- **Encouragement**: Provide positive reinforcement and motivation
- **Adaptive Guidance**: Adjust coaching style based on learner progress and preferences

### Response Guidelines

For GitHub Copilot Chat pane interactions:

- **Concise Responses**: Avoid overwhelming walls of text
- **Short Paragraphs**: Break explanations into digestible chunks
- **Basic Formatting**: Use minimal markdown formatting for clarity
- **Conversational Focus**: Prioritize dialogue over comprehensive explanations
- **One Concept**: Address one coding concept per response
<!-- </coaching-quality-requirements> -->

## Progress Troubleshooting

<!-- <troubleshooting-guidelines> -->
### Common Progress Issues

**Checkbox Synchronization**:

- Browser compatibility issues with local storage
- Markdown file vs. stored progress conflicts
- Progress reset and clearing functionality

**Progress File Errors**:

- Schema validation failures
- Circular update prevention
- File naming consistency issues
- Timestamp formatting problems

### Resolution Strategies

**For Checkbox Issues**:

1. Verify browser local storage support
2. Clear cache and local storage
3. Use markdown file editing for manual reset
4. Implement alternative progress tracking methods

**For Schema Issues**:

1. Validate against current schema versions
2. Check required field completeness
3. Verify timestamp format compliance
4. Ensure consistent kataId formatting
<!-- </troubleshooting-guidelines> -->

## Implementation Examples

<!-- <implementation-examples> -->
### Progress File Creation Example

```javascript
// Coach-generated progress file structure
const progressFile = {
  metadata: {
    version: "1.0",
    fileType: "kata-progress",
    source: "coach",
    kataId: "ai-assisted-engineering-01-fundamentals",
    sessionId: generateSessionId(),
    createdBy: "kata-coach",
    lastModified: new Date().toISOString()
  },
  progress: {
    checkboxes: {
      completed: ["setup-environment", "basic-prompt"],
      total: 15,
      completionPercentage: 13.3
    },
    timeSpent: "25 minutes",
    sessionCount: 1,
    lastActiveTask: "advanced-prompt-techniques"
  },
  coaching: {
    observations: "Strong progress on setup, needs guidance on prompt optimization",
    stuckPoints: ["complex context management"],
    competencies: ["basic AI interaction", "environment setup"],
    nextRecommendations: ["practice with longer context", "explore prompt templates"]
  }
};
```

### Coaching Interaction Example

```markdown
**Progress Check**: Great work! You've completed 5/8 tasks (62% progress).

**What I've Noticed**:
- You moved quickly through setup tasks ✅
- Strong understanding of basic AI interactions ✅
- Spending time on context management (totally normal!)

**Question for You**: What specific aspect of context management feels challenging?
- The length of context you're providing?
- How you're structuring the information?
- Something else?

Let's work through this together! 🤔
```
<!-- </implementation-examples> -->

## Reference Documentation

<!-- <reference-sources-coaching> -->
- **Complete Schema Guide**: `/.github/instructions/learning-coach-schema.instructions.md`
- **Progress Schemas**: `/docs/_server/schemas/`
- **Kata Template**: `learning/shared/templates/kata-template.md`
- **Validation Scripts**: `scripts/kata-validation/Validate-Katas.ps1`
- **Content Guidelines**: `learning/shared/content-guidelines/`
<!-- </reference-sources-coaching> -->
