# Learning Coach Schema Instructions

Instructions for AI coaches when writing progress files and managing learner progress tracking in the learning platform.

## Core Requirements

### Schema Files Location

- **Kata Progress**: `../../docs/_server/schemas/kata-progress-schema.json`
- **Lab Progress**: `../../docs/_server/schemas/lab-progress-schema.json`
- **Self-Assessment**: `../../docs/_server/schemas/self-assessment-schema.json`
- **Learning Path Progress**: `../../docs/_server/schemas/learning-path-progress-schema.json`
- **Learning Recommendation**: `../../docs/_server/schemas/learning-recommendation-schema.json`

### File Management Rules

- **Storage Location**: `.copilot-tracking/learning/`
- **File Strategy**: Per-kata/lab updates (same file reused for same ID)
- **Naming Convention**:
  - Kata/Lab: `{type}-progress-{id}-{timestamp}.json`
  - Learning Path: `learning-path-progress-{pathId}-{timestamp}.json`
  - Recommendation: `learning-recommendation-{recommendationId}-{timestamp}.json`
- **Source Identification**: Always use `"source": "coach"` to prevent circular updates

### Common Standards

- **ISO 8601 timestamps**: Use `new Date().toISOString()`
- **Consistent IDs**: Use kebab-case for kata/lab IDs throughout sessions
- **Schema validation**: All files automatically validated against schemas
- **Version tracking**: Use `"version": "1.0.0"` in metadata

## File Management Strategy

### Smart File Updates

- **Per-Kata/Lab Updates**: Files are named with timestamps but the same file is updated for the same kata/lab ID
- **File Reuse**: Existing files get updated instead of creating new ones for the same activity
- **New Activity = New File**: Only new katas/labs get new files
- **Auto-cleanup**: System maintains maximum 5 files per activity for history
- **CRITICAL**: Use consistent `kataId`/`labId` values to ensure proper file grouping

### ID Consistency Rules

- **Use kebab-case**: `kata-progress-tracking`, `azure-iot-basics`, `terraform-fundamentals`
- **Be specific**: Include the actual kata/lab name, not generic terms
- **Stay consistent**: Once you establish an ID, use it throughout the coaching session
- **Avoid timestamps**: Don't include dates/times in IDs (system handles time stamps)
- **Self-assessment exception**: Always use `"kataId": "self-assessment-workflow"`

### When to Write Progress Files

Write progress files in these situations:

- **Coaching sessions**: After significant coaching interactions or insights
- **Progress milestones**: When learners complete major sections or overcome challenges
- **Skill assessment**: When you observe specific competency developments
- **Self-assessment workflow**: When users complete the focused 15-question assessment
- **Session completion**: At the end of productive coaching sessions
- **Stuck points**: When learners need assistance and you provide guidance
- **Learning path creation**: When generating personalized learning paths based on assessments
- **Learning recommendations**: When providing targeted recommendations for skill development
- **Path progress updates**: When learners make significant progress on their learning paths

### Circular Update Prevention

- **Source identification**: Always set `"source": "coach"` in metadata
- **File watcher awareness**: Progress system monitors files and updates UI automatically
- **Avoid double updates**: Don't modify files created by file-watcher or UI sources
- **Session coordination**: If file-watcher update occurs, acknowledge and build on it

## Kata Progress Files

### File Structure

```json
{
  "metadata": {
    "version": "1.0.0",
    "kataId": "consistent-kebab-case-id",
    "source": "coach",
    "fileType": "kata-progress"
  },
  "progress": {
    "completionPercentage": 0.0,
    "tasksCompleted": [],
    "currentPhase": "string"
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Implementation Guidelines

- **File naming**: `kata-progress-{kataId}-{timestamp}.json`
- **Use consistent `kataId`** in kebab-case throughout session
- **Include coaching observations** and recommendations
- **Track skill assessments** and competency development
- **Reference specific tasks** and milestones

## Lab Progress Files

### File Structure

```json
{
  "metadata": {
    "version": "1.0.0",
    "labId": "consistent-kebab-case-id",
    "source": "coach",
    "fileType": "lab-progress"
  },
  "progress": {
    "completionPercentage": 0.0,
    "currentPhase": "string",
    "phasesCompleted": []
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Implementation Guidelines

- **File naming**: `lab-progress-{labId}-{timestamp}.json`
- **Support multi-session tracking** with session arrays
- **Include environment state** (clusters, services, deployments)
- **Track phase-based completion** for complex labs
- **Document integration milestones** and system architecture insights

## Self-Assessment Files

### File Structure

```json
{
  "metadata": {
    "version": "1.0.0",
    "kataId": "self-assessment-workflow",
    "source": "coach",
    "fileType": "self-assessment-progress"
  },
  "assessment": {
    "type": "focused-self-assessment",
    "totalQuestions": 12,
    "completed": true,
    "categories": {
      "aiAssistedEngineering": { "score": 0.0, "responses": [] },
      "promptEngineering": { "score": 0.0, "responses": [] },
      "edgeDeployment": { "score": 0.0, "responses": [] },
      "systemTroubleshooting": { "score": 0.0, "responses": [] }
    },
    "overallScore": 0.0,
    "skillLevel": "beginner|intermediate|advanced"
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Implementation Guidelines

- **File naming**: `self-assessment-progress-{timestamp}.json`
- **Always use** `"kataId": "self-assessment-workflow"`
- **Include all 4 categories** with scores and responses
- **Calculate overall score** and skill level
- **Provide specific coaching recommendations** and learning paths

## Learning Path Progress Files

### File Structure

```json
{
  "metadata": {
    "version": "1.0.0",
    "learningPathId": "consistent-kebab-case-path-id",
    "source": "coach",
    "fileType": "learning-path-progress",
    "pathType": "foundation-builder|skill-developer|expert-practitioner|custom|assessment-generated",
    "basedOnAssessment": "assessment-id-if-applicable"
  },
  "learningPath": {
    "title": "Learning Path Title",
    "description": "Detailed description of the learning path",
    "categories": ["ai-assisted-engineering", "prompt-engineering"],
    "estimatedDuration": {
      "hours": 20,
      "weeks": 3,
      "text": "2-3 weeks of regular practice"
    },
    "items": [
      {
        "id": "learning-item-id",
        "type": "kata|lab|assessment|resource|checkpoint",
        "title": "Learning Item Title",
        "category": "skill-category",
        "order": 1,
        "isRequired": true
      }
    ]
  },
  "progress": {
    "itemProgress": {
      "learning-item-id": {
        "status": "not-started|in-progress|completed|skipped",
        "startedAt": "2024-01-15T10:30:00.000Z",
        "completedAt": "2024-01-15T10:45:00.000Z",
        "progressPercentage": 100.0
      }
    },
    "overallProgress": {
      "itemsCompleted": 1,
      "totalItems": 5,
      "completionPercentage": 20.0,
      "currentItem": "next-item-id"
    }
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Implementation Guidelines

- **File naming**: `learning-path-progress-{pathId}-{timestamp}.json`
- **Use consistent `learningPathId`** in kebab-case throughout session
- **Include complete learning path structure** with ordered items
- **Track progress for each item** in the path
- **Support coaching interactions** and path adjustments
- **Include analytics and insights** for learning pattern analysis

## Learning Recommendation Files

### File Structure

```json
{
  "metadata": {
    "version": "1.0.0",
    "recommendationId": "learning-recommendation-{timestamp}",
    "source": "coach",
    "fileType": "learning-recommendation",
    "basedOnAssessment": "assessment-id-if-applicable",
    "coachMode": "kata-coach|lab-coach|assessment-coach|path-coach"
  },
  "recommendation": {
    "type": "learning-path|skill-focus|item-suggestion|prerequisite-gap|next-step",
    "title": "Recommendation Title",
    "description": "Detailed recommendation description",
    "priority": "high|medium|low",
    "rationale": "Reasoning behind this recommendation",
    "targetSkills": ["ai-assisted-engineering", "prompt-engineering"],
    "learningPath": {
      "pathId": "recommended-path-id",
      "pathTitle": "Recommended Learning Path",
      "pathType": "foundation-builder|skill-developer|expert-practitioner|custom",
      "estimatedDuration": {
        "hours": 20,
        "weeks": 3,
        "text": "2-3 weeks of regular practice"
      },
      "items": [
        {
          "id": "learning-item-id",
          "type": "kata|lab|assessment|resource",
          "title": "Learning Item Title",
          "category": "skill-category",
          "priority": "high|medium|low",
          "reasoning": "Why this item is recommended"
        }
      ]
    }
  },
  "context": {
    "assessmentScores": {
      "overallScore": 3.2,
      "categoryScores": {
        "ai-assisted-engineering": 2.8,
        "prompt-engineering": 2.5
      },
      "strengthCategories": ["system-troubleshooting"],
      "growthCategories": ["ai-assisted-engineering", "prompt-engineering"]
    }
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Implementation Guidelines

- **File naming**: `learning-recommendation-{recommendationId}-{timestamp}.json`
- **Base on assessment results** when available
- **Include specific rationale** for recommendations
- **Provide actionable learning paths** with clear next steps
- **Consider learner context** (role, experience, goals)
- **Include implementation guidance** and success metrics

## Validation and Error Handling

### Schema Validation

All files are automatically validated against their schemas. Common validation errors:

- **Missing required fields**: Check schema for all required properties
- **Invalid timestamps**: Must be ISO 8601 UTC format
- **Incorrect source**: Always use `"source": "coach"`
- **Invalid skill levels**: Must match enum values in schema
- **Malformed categories**: Self-assessment must include all 4 categories
- **Invalid learning path structure**: Must include all required learning path fields
- **Invalid recommendation type**: Must match enum values for recommendation types
- **Missing context**: Learning recommendations should include assessment or progress context

### Error Resolution

If files are rejected:

1. Check console for specific validation errors
2. Verify all required fields are present
3. Ensure timestamps are properly formatted
4. Confirm schema version matches current version
5. Validate JSON syntax and structure

## Integration Points

### System Integration

Progress files automatically integrate with:

- **UI progress tracking**: Real-time checkbox synchronization
- **SSE updates**: Live progress notifications
- **Coach resumption**: Context for continued coaching sessions
- **Analytics**: Skills assessment and learning pattern analysis

### File Storage and Management

- **Per-kata/lab updates**: Same file gets updated for same kata/lab ID
- **Storage location**: `.copilot-tracking/learning/`
- **File watching**: System monitors files for real-time UI updates
- **Circular update prevention**: Use `"source": "coach"` to prevent loops

## Best Practices

### Quick Implementation Tips

1. **Always validate your JSON** before writing files
2. **Use consistent naming** for kata/lab/learning path IDs throughout sessions
3. **Include meaningful coaching data** in observations and recommendations
4. **Reference specific tasks and milestones** in progress tracking
5. **For self-assessments**, use the exact 15-question format from skill-assessment.md
6. **For learning paths**, base recommendations on assessment results when available
7. **Create personalized learning paths** that match learner goals and skill level
8. **Include clear rationale** for all recommendations and path suggestions

### Quality Guidelines

- **Be specific with IDs**: Use actual kata/lab/learning path names, not generic terms
- **Maintain consistency**: Once you establish an ID, use it throughout the session
- **Include coaching context**: Provide meaningful observations and recommendations
- **Track meaningful progress**: Focus on actual learning milestones and competency development
- **Reference real tasks**: Connect progress to specific kata/lab tasks and objectives
- **Personalize learning paths**: Base recommendations on assessment results and learner context
- **Provide clear rationale**: Explain why specific learning paths or items are recommended
- **Support path adaptation**: Allow for adjustments based on learner progress and feedback

## Dependencies

### Required Files

- Schema files in `../../docs/_server/schemas/`
- Progress tracking UI system
- File watcher system for automatic updates
- SSE notification system

### Related Systems

- Learning platform
- Coach chatmode integration
- Progress tracking UI
- Skill assessment system

## Success Criteria

### Effective Progress Tracking

- Files validate against schemas without errors
- UI updates automatically reflect progress changes
- Coaching context is preserved between sessions
- Learner progress is accurately tracked and meaningful
- System integration works seamlessly without circular updates

### Quality Indicators

- Consistent ID usage throughout coaching sessions
- Meaningful coaching observations and recommendations
- Accurate progress percentage and milestone tracking
- Proper integration with UI and notification systems
- Clear learning path progression and skill development tracking
