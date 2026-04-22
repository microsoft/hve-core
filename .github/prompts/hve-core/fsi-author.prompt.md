---
description: 'Author or extend a Framework Skill with manifest, per-item YAML, and SKILL.md registration - Brought to you by microsoft/hve-core'
agent: Prompt Builder
argument-hint: 'Describe the Framework Skill to create or extend (framework name, domain, itemKind, source spec)'
---

# FSI Author

Author or extend a Framework Skill following the FSI authoring contract.

## Inputs

* ${input:description}: (Required) Framework Skill requirements including framework name, domain, itemKind (`control`, `capability`, or `document-section`), and source specification.

## Skill Reference

#file:.github/skills/shared/framework-skill-interface/SKILL.md

## Authoring Requirements

1. Create `index.yml` with required fields: `framework`, `version`, `summary`, `phaseMap`. Include `domain`, `itemKind`, `globals`, and `status` as needed. New Framework Skills should set `status: draft`.

   ```yaml
   framework: example-standard
   version: "1.0"
   summary: Example security standard controls
   domain: security
   phaseMap:
     standards-mapping:
       - example-control-1
     gap-analysis:
       - example-control-1
   status: draft
   ```

2. Place the Framework Skill at `.github/skills/<domain>/<framework-id>/` with the directory name matching the `framework` value in `index.yml`.
3. Select the per-item schema by `itemKind`: use `planner-framework-control.schema.json` for `control` or `capability`; use `document-section.schema.json` for `document-section`. Consult existing Framework Skills in the same domain for per-item file structure.
4. Create `SKILL.md` with `name`, `description` (include "Brought to you by" attribution), and a domain overview. The `validate:skills` command checks for its presence.
5. Use `{{var}}` tokens for dynamic content (applies to `document-section` itemKind), resolved from `globals` and `inputs[].name`. Escape literal braces with `\{{`. Unresolved tokens fail validation.
6. Set `inputs[].persistence` (applies to `document-section` itemKind) when inputs should survive beyond the current invocation:
   * `none`: default; value is not persisted
   * `session`: reused within a single workflow run
   * `project`: persists across runs in the same repository
   * `user`: personal preferences that follow the user
7. Reserved forward-looking fields are not yet implemented. Do not populate these until their schemas land:
   * `pipeline.stages[].produces[].{id, kind}`: shape TBD, see Phase 4

## Validation

Run these commands to verify the Framework Skill:

* `npm run validate:skills`: directory structure and SKILL.md presence
* `npm run validate:fsi-content`: manifest, per-item YAML, and `{{var}}` resolution
* `npm run lint:frontmatter`: SKILL.md frontmatter schema

Framework Skills outside `.github/skills/` can be validated directly:

```powershell
Test-FrameworkSkillInterface -RepoRoot $PWD -ManifestPath <path-to-index.yml>
```

---

Read the FSI authoring skill in full. Author the Framework Skill described in `${input:description}`, validate it, and iterate until all checks pass.
