---
title: Evaluation dataset contract
description: Machine-readable JSON and CSV shapes for an AI evaluation dataset, with field semantics and the recorded-distribution rule
---

## Purpose

Copy these shapes when emitting an evaluation dataset. Produce both forms from the same source of truth so they cannot disagree. Confirm the destination with the caller rather than assuming one; suggest a project-appropriate location only when the caller has no convention.

## JSON shape

```json
{
  "metadata": {
    "system_name": "string",
    "created_date": "YYYY-MM-DD",
    "version": "1.0.0",
    "total_pairs": 0,
    "distribution": {
      "easy": 0,
      "grounding": 0,
      "hard": 0,
      "negative": 0,
      "safety": 0
    },
    "population_coverage": {
      "confirmed_user_population": 0
    },
    "approach": "low-code | pro-code",
    "evaluation_mode": ["manual", "batch"],
    "recommended_tooling": "string",
    "review_state": "draft | sampled | confirmed",
    "validation_status": "ai-generated | expert-reviewed | mixed",
    "generation_method": "workflow that produced the pairs"
  },
  "evaluation_pairs": [
    {
      "id": "001",
      "query": "User request as it would actually be phrased",
      "expected_response": "Observable expected behavior",
      "category": "scenario grouping",
      "difficulty": "easy | grounding | hard | negative | safety",
      "tools_expected": ["tool_name"],
      "source_reference": "grounding source this answer should rest on, when applicable",
      "needs_sme_review": false,
      "notes": "curation rationale or open question"
    }
  ]
}
```

## CSV shape

```csv
id,query,expected_response,category,difficulty,tools_expected,source_reference,needs_sme_review,notes
001,"User request","Expected behavior","category","easy","tool_a;tool_b","https://example.invalid/doc",false,"notes"
```

Encode `tools_expected` as a semicolon-delimited list, and use an empty value when no tool is expected. Quote any field containing a comma or a line break.

The JSON file is authoritative for dataset-level metadata. The CSV remains a pair-only companion generated from the same evaluation-pair source of truth; it does not duplicate aggregate metadata or add a population column. Consumers that need population coverage, provenance, or review progression read the sibling JSON metadata.

## Field semantics

| Field               | Meaning                                                                                         |
|---------------------|-------------------------------------------------------------------------------------------------|
| `id`                | Stable identifier. Keep it stable across revisions so review feedback stays attributable        |
| `query`             | The request as a real user would phrase it, including imperfect phrasing where representative   |
| `expected_response` | Observable expected behavior. Use exact wording only when the wording is itself the requirement |
| `category`          | Scenario grouping, drawn from the interview rather than invented per pair                       |
| `difficulty`        | The balance category this pair counts toward                                                    |
| `tools_expected`    | Tools the system should invoke; empty when tool use is not expected                             |
| `source_reference`  | The grounding source the answer should rest on; required for grounding pairs                    |
| `needs_sme_review`  | True when the expected answer could not be grounded during authoring                            |
| `notes`             | Why this pair exists, or what remains open about it                                             |

Metadata fields have distinct meanings:

| Field                 | Scope and meaning                                                                                                   |
|-----------------------|---------------------------------------------------------------------------------------------------------------------|
| `population_coverage` | Dataset-level pair counts keyed by confirmed user population. Counts are non-overlapping and sum to `total_pairs`   |
| `validation_status`   | Provenance of validation: `ai-generated`, `expert-reviewed`, or `mixed`; defaults to `ai-generated`                 |
| `generation_method`   | The workflow that produced the pairs, such as `interview-driven-ai-generation`                                      |
| `review_state`        | Authoring progression through `draft`, `sampled`, and `confirmed`; it is not a substitute for validation provenance |

## Recorded-distribution rule

The counts in `distribution` must equal the actual number of rows in each category, and their sum must equal `total_pairs`. A recorded distribution that disagrees with the rows makes every downstream coverage claim false. Verify this after any revision that adds pairs, removes pairs, or moves a pair between categories.

The counts in `population_coverage` also sum to `total_pairs`. Difficulty and population answer different questions: difficulty records how demanding a pair is, while population records whose usage the pair is intended to represent.

## Content rules

* Use representative synthetic content. Real customer data, credentials, tokens, and personal information do not belong in an evaluation dataset.
* Keep safety pairs specific enough to test refusal and general enough to avoid becoming a how-to. The expected behavior is the refusal and its accompanying action, never the prohibited content itself.
* Mark rather than guess. A pair with `needs_sme_review` set is more useful than a confidently wrong expectation.
