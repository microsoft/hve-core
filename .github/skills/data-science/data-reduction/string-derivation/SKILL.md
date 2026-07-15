---
name: string-derivation
description: Detect derivable data columns via string operations for data reduction - Brought to you by microsoft/hve-core
user-invocable: true
---

# String Derivation Detection

## Overview

Detects data columns that can be derived from other columns using string operations, enabling safe column removal for data reduction. Identifies 9 derivation patterns including lookup expansion (CODE→DESCRIPTION), concatenation, substring extraction, and edit distance transformations using progressive sampling for performance.

Enterprise datasets often contain redundant string columns where one column is a deterministic transformation of another. This skill identifies these relationships so derived columns can be safely removed, reducing dataset dimensionality without information loss. Uses progressive sampling (3→10→30 rows) to achieve 10-100x speedup over full-dataset testing.

**Common patterns detected:**
- **Lookup expansion**: `GENDER` ('F', 'M') → `GENDER_DESCRIPTION` ('Female', 'Male')
- **Concatenation**: `FIRST_NAME` + `LAST_NAME` → `FULL_NAME`
- **Substring**: `EMPLOYEE_ID` contains `DEPT_CODE`
- **Character removal**: `PHONE_NUMBER` = `PHONE_DISPLAY` with formatting removed
- **Case transformation**: `email` vs `EMAIL`
- **Numeric extraction**: `ORDER_123` → `123`
- **Edit distance**: Systematic 1-2 character transformations
- **Format strings**: `{STATE}: {CITY}` patterns
- **Boolean checks**: Derived true/false flags

## When to Use

Use this skill when:
- Reducing dimensionality of string columns while preserving information
- Identifying redundant columns for removal (CODE vs DESCRIPTION columns)
- Dataset contains >10 string columns with potential derivations
- Preparing data for machine learning (feature engineering) or ontology building
- Optimizing storage or processing by eliminating derived columns
- Building data dictionaries that document column relationships

**Do not use when:**
- Dataset has <30 rows (insufficient sample size)
- All columns are numeric (skill focuses on string operations)
- You need exact deterministic guarantees (uses sampling for performance)

**Common patterns detected:**
- **Lookup expansion**: `GENDER` ('F', 'M') → `GENDER_DESCRIPTION` ('Female', 'Male')
- **Concatenation**: `FIRST_NAME` + `LAST_NAME` → `FULL_NAME`
- **Substring**: `EMPLOYEE_ID` contains `DEPT_CODE`
- **Character removal**: `PHONE_NUMBER` = `PHONE_DISPLAY` with formatting removed
- **Case transformation**: `email` vs `EMAIL`
- **Numeric extraction**: `ORDER_123` → `123`
- **Edit distance**: Systematic 1-2 character transformations
- **Format strings**: `{STATE}: {CITY}` patterns
- **Boolean checks**: Derived true/false flags

## Prerequisites

**Python Dependencies:**
```bash
pip install pandas numpy
```

**Platform:** Python 3.7+

**Dataset Requirements:**
- Tabular data with string (object) columns
- 100+ rows recommended for reliable pattern detection
- Multiple string columns to analyze for derivation relationships

## Quick Start

**Note:** The detection algorithms are reference implementations in [references/algorithms.md](references/algorithms.md). Copy the relevant functions (`filter_derivation_candidates`, `detect_all_string_derivations_optimized`, and their dependencies) into your project before using them.

**Basic usage** (analyze one column):

```python
import pandas as pd
# After copying functions from references/algorithms.md:
# from your_module import detect_all_string_derivations_optimized, filter_derivation_candidates

# Load data
df = pd.read_csv('data.csv')
string_cols = df.select_dtypes(include=['object']).columns.tolist()

# Filter candidates once (recommended for batch processing)
filtered_candidates = filter_derivation_candidates(df, string_cols)

# Detect derivations for target column
derivations = detect_all_string_derivations_optimized(
    df=df,
    target_col='EMPLOYEE_FULL_NAME',
    candidate_cols=string_cols,
    filtered_candidates=filtered_candidates
)

# Show results
if derivations:
    best = derivations[0]
    print(f"Formula: {best['formula']}")
    print(f"Confidence: {best['match_ratio']:.1%}")
```

**Batch processing** (all string columns):

```python
# Filter candidates ONCE before loop (critical for performance)
filtered_candidates = filter_derivation_candidates(df, string_cols)

# Analyze all columns
all_findings = {}
for col in string_cols:
    derivations = detect_all_string_derivations_optimized(
        df, col, string_cols,
        filtered_candidates=filtered_candidates,
        verbose=True  # Show progress
    )
    if derivations:
        all_findings[col] = derivations[0]  # Store best match

# Summary
print(f"\nFound derivations for {len(all_findings)}/{len(string_cols)} columns")
for col, deriv in all_findings.items():
    print(f"{col} ← {deriv['formula']} ({deriv['match_ratio']:.1%})")
```

## Parameters Reference

### filter_derivation_candidates

Filters candidate columns based on cardinality and naming patterns. **Call once before batch processing.**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `df` | DataFrame | Required | DataFrame containing the data |
| `candidate_cols` | list[str] | Required | Column names to filter |
| `max_cardinality` | int | 1000 | Skip columns with >N unique values (likely IDs) |
| `max_candidates` | int | 50 | Maximum candidates to return |

**Returns:** `list[str]` - Filtered column names prioritizing CODE/NAME/DESC/TYPE/STATUS patterns

### detect_all_string_derivations_optimized

Detects all string derivations for a target column using progressive sampling.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `df` | DataFrame | Required | DataFrame containing the data |
| `target_col` | str | Required | Column to analyze for derivations |
| `candidate_cols` | list[str] | Required | All column names (used if filtered_candidates=None) |
| `filtered_candidates` | list[str] | None | Pre-filtered candidates (RECOMMENDED for batch) |
| `verbose` | bool | False | Print phase-by-phase progress |

**Returns:** `list[dict]` - Derivation findings sorted by confidence (highest first)

**Derivation dictionary schema:**
```python
{
    'type': str,              # 'lookup_expansion', 'concatenation', 'substring', etc.
    'operands': list[str],    # Source column name(s)
    'formula': str,           # Human-readable formula
    'match_ratio': float,     # Confidence score (0.0-1.0)
    # Type-specific fields (varies by derivation)
}
```

## Usage Patterns

### Pattern 1: Quick Single-Column Check

Check if one specific column is derived from others:

```python
derivations = detect_all_string_derivations_optimized(df, 'FULL_NAME', string_cols)
if derivations and derivations[0]['match_ratio'] >= 0.95:
    print(f"✅ Can remove {target_col}: {derivations[0]['formula']}")
```

### Pattern 2: Full Dataset Scan

Scan all string columns to build a column dependency graph:

```python
filtered = filter_derivation_candidates(df, string_cols)
dependencies = {}
for col in string_cols:
    derivs = detect_all_string_derivations_optimized(df, col, string_cols, filtered)
    if derivs and derivs[0]['match_ratio'] >= 0.95:
        dependencies[col] = derivs[0]

# Remove derived columns
safe_to_remove = list(dependencies.keys())
df_reduced = df.drop(columns=safe_to_remove)
print(f"Reduced from {len(df.columns)} to {len(df_reduced.columns)} columns")
```

## Algorithm Reference

See [references/algorithms.md](references/algorithms.md) for:
- **Complete Python implementations** of all 9 detection algorithms
- **Progressive sampling strategy** details (3→10→30 rows)
- **Performance optimization** techniques and complexity analysis
- **Full API reference** with parameter schemas
- **Detection type schemas** for each derivation pattern
- **Helper functions** and dependencies

## Sample Prompts

**User Request:**

"Analyze my employee dataset to find redundant string columns that can be derived from other columns"

or

"Detect which columns in data.csv are lookup expansions or concatenations of other columns"

**Execution Flow:**

1. **User invokes skill** via natural language request mentioning "string derivation", "redundant columns", "derived columns", or "data reduction"
2. **Skill loads data** using pandas to read CSV file
3. **Filter candidates** once using `filter_derivation_candidates()` to:
   - Skip high-cardinality columns (>1000 unique values)
   - Prioritize CODE/NAME/DESC/TYPE/STATUS pattern columns
   - Limit to top 50 candidates
4. **Progressive sampling detection** for each target column:
   - Phase 1: Test all 9 detection types on 3 samples (100% match required)
   - Phase 2: Re-test survivors on 10 samples (100% match required)
   - Phase 3: Final validation on 30 samples (≥95% match accepted)
5. **Sort results** by confidence (match_ratio descending)
6. **Generate report** with derivation formulas and confidence scores

**Output Artifacts:**

CSV file `string_derivation_report.csv`:
```csv
target_column,derivation_type,source_columns,formula,match_ratio,details
GENDER_DESCRIPTION,lookup_expansion,GENDER,GENDER_DESCRIPTION = lookup(GENDER),0.98,"{""sample_mapping"": [[""F"", ""Female""], [""M"", ""Male""]]}"
FULL_NAME,concatenation,"FIRST_NAME,LAST_NAME",FULL_NAME = FIRST_NAME + " " + LAST_NAME,1.0,"{""separator"": "" ""}"
PHONE_NUMBER,character_removal,PHONE_DISPLAY,PHONE_NUMBER = PHONE_DISPLAY.replace([- ()], ""),0.97,"{""characters"": ""- ()""}"
DEPT_CODE,substring,EMPLOYEE_ID,DEPT_CODE is substring of EMPLOYEE_ID,1.0,"{}"
EMAIL_LOWER,case_transformation,EMAIL,EMAIL_LOWER = case_transform(EMAIL),1.0,"{}"
```

Console output showing progress:
```
Loading data from employee_data.csv...
Found 45 string columns in dataset
Filtered to 32 candidate columns

Analyzing column: GENDER_DESCRIPTION
  Phase 1: Testing with 3 samples...
  Phase 2: Re-testing 5 candidates with 10 samples...
  Phase 3: Final validation of 2 candidates with 30 samples...

Found 12 derivations
Results saved to: string_derivation_report.csv
```

**Success Indicators:**

1. **Report generated** - CSV file exists with derivation findings
2. **High confidence matches** - match_ratio ≥ 0.95 for actionable findings
3. **Derivation types identified** - Clear formulas showing how columns are derived
4. **Reduced column count** - Can safely remove derived columns, reducing from N to N-K columns
5. **Performance acceptable** - Detection completes in <5 minutes for 100-column datasets

**Validation steps:**
- Verify formulas by spot-checking a few rows manually
- Confirm match_ratio is ≥95% before removing columns
- Test data pipeline with reduced dataset to ensure no information loss
- Compare memory/processing time before and after reduction

## Troubleshooting

### Slow performance on large datasets

**Symptom:** Detection takes >10 minutes for 100+ columns

**Solutions:**
1. **Always use filtered_candidates** - Compute once, reuse for all columns
2. **Increase max_cardinality threshold** - Skip more high-cardinality columns
3. **Reduce max_candidates** - Limit to top 30-40 most likely candidates
4. **Skip concatenation** - O(n²) complexity; test manually if needed
5. **Disable verbose mode** - Printing slows down tight loops

### False positives (low confidence matches)

**Symptom:** Derivations found with <95% match ratio

**Solutions:**
1. **Increase sampling size** - Modify progressive sampling to use more rows
2. **Check data quality** - Inconsistent formatting breaks pattern detection
3. **Review match_ratio threshold** - Only act on ≥95% confidence findings

### Missing obvious derivations

**Symptom:** Known derived columns not detected

**Solutions:**
1. **Check cardinality filtering** - Lower max_cardinality to include more candidates
2. **Verify data types** - Only detects string (object) columns
3. **Review naming patterns** - Add keywords to filter_derivation_candidates priority list
4. **Check for data corruption** - Null values or encoding issues break matching

### Memory errors

**Symptom:** Out of memory when processing very wide datasets (300+ columns)

**Solutions:**
1. **Reduce max_candidates** - Process in smaller batches
2. **Filter by column type** - Exclude numeric columns from string_cols
3. **Process chunks** - Split string_cols into batches of 50

> Brought to you by microsoft/hve-core
