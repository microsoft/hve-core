# Learning Platform Schemas

This directory contains JSON schemas for the HVE Learning Platform's progress tracking and coaching system.

## Current Status

**Note**: These schema files are currently **not used** by the docsify-based documentation system. The full progress tracking functionality that leverages these schemas is planned for a future release.

## Purpose

These schemas define the structure for:

- **`kata-progress-schema.json`**: Progress tracking for kata exercises
- **`lab-progress-schema.json`**: Progress tracking for training labs
- **`self-assessment-schema.json`**: Self-assessment questionnaire data
- **`learning-path-progress-schema.json`**: Learning path progression tracking
- **`learning-path-manifest-schema.json`**: Learning path configuration and structure
- **`learning-recommendation-schema.json`**: AI-generated learning recommendations
- **`learning-path-save-request-schema.json`**: API request format for saving learning paths

## Coming Soon

The upcoming docsify integration will provide:

- Real-time progress tracking in the browser
- Interactive checkbox state management
- Progress visualization and analytics
- Learning path recommendations based on progress data
- Session resumption and continuity
- Multi-user progress tracking

## Schema Validation

All progress files created by AI coaches are automatically validated against these schemas. Files must conform to the structure defined here to ensure compatibility with the future docsify functionality.

For detailed information about how AI coaches should use these schemas, see:

- `../.github/instructions/learning-coach-schema.instructions.md`

---

*Last updated: December 9, 2025*
