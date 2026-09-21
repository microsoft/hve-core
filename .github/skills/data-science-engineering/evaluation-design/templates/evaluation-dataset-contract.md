---
title: Evaluation dataset contract
description: Machine-readable JSON and CSV shapes for an AI evaluation dataset, with field semantics, the recorded-distribution rule, the overlapping population coverage rule, and the migration notice for the previous contract
---

## Purpose

Copy these shapes when emitting an evaluation dataset. Produce both forms from the same source of truth so they cannot disagree. Confirm the destination with the caller rather than assuming one; suggest a project-appropriate location only when the caller has no convention.

## JSON shape

The example below shows a thirty-pair dataset with three of its pairs written out.

```json
{
  "metadata": {
    "system_name": "string",
    "created_date": "YYYY-MM-DD",
    "version": "1.0.0",
    "total_pairs": 30,
    "distribution": {
      "easy": 6,
      "grounding": 3,
      "hard": 12,
      "negative": 6,
      "safety": 3
    },
    "user_populations": ["Field technician", "Dispatcher", "New hire"],
    "population_coverage": {
      "Field technician": 20,
      "Dispatcher": 14,
      "New hire": 0
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
      "populations": ["Field technician"],
      "tools_expected": ["tool_name"],
      "source_reference": "grounding source this answer should rest on, when applicable",
      "needs_sme_review": false,
      "notes": "curation rationale or open question"
    },
    {
      "id": "002",
      "query": "A request both populations would make in the same words",
      "expected_response": "Observable expected behavior",
      "category": "scenario grouping",
      "difficulty": "hard",
      "populations": ["Field technician", "Dispatcher"],
      "tools_expected": [],
      "source_reference": null,
      "needs_sme_review": false,
      "notes": "exercises the same behavior for two populations"
    },
    {
      "id": "003",
      "query": "A request that is not specific to any population",
      "expected_response": "Observable expected behavior",
      "category": "scenario grouping",
      "difficulty": "safety",
      "populations": [],
      "tools_expected": [],
      "source_reference": null,
      "needs_sme_review": false,
      "notes": "applies regardless of who asks"
    }
  ]
}
```

## CSV shape

```csv
id,query,expected_response,category,difficulty,populations,tools_expected,source_reference,needs_sme_review,notes
001,"User request","Expected behavior","category","easy","Field technician","tool_a;tool_b","https://example.invalid/doc",false,"notes"
002,"Shared request","Expected behavior","category","hard","Field technician;Dispatcher","","",false,"notes"
003,"General request","Expected behavior","category","safety","","","",false,"notes"
```

Encode `populations` and `tools_expected` as semicolon-delimited lists, and use an empty value when the list is empty. Quote any field containing a comma or a line break.

The JSON file is authoritative for dataset-level metadata. The CSV remains a pair-only companion generated from the same evaluation-pair source of truth; it does not duplicate aggregate metadata. A pair's `populations` value must name the same populations in both forms. Consumers that need the confirmed population list, coverage counts, provenance, or review progression read the sibling JSON metadata.

## Field semantics

| Field               | Meaning                                                                                                    |
|---------------------|------------------------------------------------------------------------------------------------------------|
| `id`                | Stable identifier. Keep it stable across revisions so review feedback stays attributable                   |
| `query`             | The request as a real user would phrase it, including imperfect phrasing where representative              |
| `expected_response` | Observable expected behavior. Use exact wording only when the wording is itself the requirement            |
| `category`          | Scenario grouping, drawn from the interview rather than invented per pair                                  |
| `difficulty`        | The balance category this pair counts toward                                                               |
| `populations`       | The confirmed user populations this pair is designed to exercise; empty when it is not population-specific |
| `tools_expected`    | Tools the system should invoke; empty when tool use is not expected                                        |
| `source_reference`  | The grounding source the answer should rest on; required for grounding pairs                               |
| `needs_sme_review`  | True when the expected answer could not be grounded during authoring                                       |
| `notes`             | Why this pair exists, or what remains open about it                                                        |

Metadata fields have distinct meanings:

| Field                 | Scope and meaning                                                                                                                                                |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `user_populations`    | The user populations confirmed during the interview. Every `populations` entry on a pair is drawn from this list                                                 |
| `population_coverage` | Dataset-level pair counts keyed by confirmed user population, with one entry for every population in `user_populations`, including the ones with a count of zero |
| `validation_status`   | Provenance of validation: `ai-generated`, `expert-reviewed`, or `mixed`; defaults to `ai-generated`                                                              |
| `generation_method`   | The workflow that produced the pairs, such as `interview-driven-ai-generation`                                                                                   |
| `review_state`        | Authoring progression through `draft`, `sampled`, and `confirmed`; it is not a substitute for validation provenance                                              |

## Recorded-distribution rule

The counts in `distribution` must equal the actual number of rows in each category, and their sum must equal `total_pairs`. A recorded distribution that disagrees with the rows makes every downstream coverage claim false. Verify this after any revision that adds pairs, removes pairs, or moves a pair between categories.

## Population coverage rule

A pair may serve several populations, so `population_coverage` works differently from `distribution`:

* `population_coverage` has exactly one entry for every population in `user_populations`. A population with no pairs is recorded as `0` rather than omitted, because an absent key and an untested population look identical to a reader.
* Each count equals the number of pairs whose `populations` array contains that population.
* The counts overlap and do not sum to `total_pairs`. Their sum can exceed `total_pairs` when pairs serve several populations, and fall below it when pairs are not population-specific.
* Any combination of populations is counted from the pairs when it is needed, so combinations are not stored separately and cannot drift from the pairs they describe.

Difficulty and population answer different questions. Difficulty records how demanding a pair is, and it partitions the dataset because a pair has exactly one. Population records whose usage the pair is intended to exercise, and it does not partition anything. Population is never a sixth `difficulty` value or a `distribution` key.

## Migration from the previous contract

This is a breaking change with no compatibility path. An earlier dataset recorded only non-overlapping `population_coverage` totals that summed to `total_pairs`, and its pairs carried no population field. Those totals cannot be converted, because a total does not identify which pairs produced it, and the pairs it counted may each have served populations the exclusive assignment discarded. Re-derive `populations` on each pair from the confirmed population list, then recompute the counts from the pairs. Do not infer memberships from the old totals and do not add a version field or a dual-mode reader.

## Content rules

* A population label describes test design, never a real person's identity. It records which confirmed population a pair is written to exercise, not an attribute that the imagined requester possesses.
* Use representative synthetic content. Real customer data, credentials, tokens, and personal information do not belong in an evaluation dataset.
* Keep safety pairs specific enough to test refusal and general enough to avoid becoming a how-to. The expected behavior is the refusal and its accompanying action, never the prohibited content itself.
* Mark rather than guess. A pair with `needs_sme_review` set is more useful than a confidently wrong expectation.
