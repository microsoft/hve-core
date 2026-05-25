## Summary
Adds the `hve-artifact-authoring` skill to the `coding-standards` collection alongside `python-foundational`.

The skill teaches frontmatter contracts, naming conventions, collection packaging, subagent delegation, and validation pipelines for authoring HVE Core artifacts.

## Benchmark Evidence (blind A/B, 8 evals, 34 expectations)

| Metric | With Skill | Baseline | Delta |
|--------|-----------|----------|-------|
| Mean pass rate | 96% | 43% | **+53%** |

| Eval | With Skill | Baseline |
|------|-----------|----------|
| create-orchestrator-agent | 100% | 0% |
| create-collection-package | 100% | 0% |
| design-alignment-delegation-model | 100% | 0% |
| create-full-workflow | 100% | 80% |
| create-instruction-auto-apply | 100% | 50% |
| design-alignment-artifact-hierarchy | 100% | 50% |
| design-alignment-validation-pipeline | 67% | 67% |
| add-skill-with-scripts | 100% | 100% |

Model: Claude Opus 4.6 (1M context)

## Acceptance Criteria
- [x] `hve-artifact-authoring/SKILL.md` present in `coding-standards` collection
- [x] All required frontmatter fields (`name:`, `description:`, `version:`)
- [x] `validate:skills` passes
- [x] Skill ≤ 500 lines

Closes #1506
Part of #1504
