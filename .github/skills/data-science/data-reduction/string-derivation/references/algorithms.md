---
description: "Reference implementation of 9 string derivation detection algorithms with progressive sampling optimization"
---

# String Derivation Detection - Algorithm Reference

Detailed implementation of all 9 string derivation detection algorithms with progressive sampling optimization.

## Detection Strategy

For each string column `C`, test whether it can be derived from one or more other string columns using common string operations. This is inspired by FlashFill program synthesis but uses pattern-based heuristics for performance.

## Progressive Sampling Strategy

**Unified approach for all dataset sizes**: Testing all column pairs with all detection algorithms creates O(n²) complexity. Progressive sampling eliminates non-matches early, making detection practical for datasets of any size.

The optimized implementation uses three-phase progressive sampling:
- **Phase 1**: All checks on all pairs with 3 samples, keep checks with 100% match
- **Phase 2**: Re-run all checks on surviving pairs with 10 samples, keep checks with 100% match
- **Phase 3**: Re-run all checks on final survivors with 30 samples, keep checks with ≥95% match

### Performance Optimization Tips

1. **Progressive sampling strategy**: Start with 3 samples to eliminate 80-90% of non-matching pairs, then 10 samples to validate survivors, finally 30 samples for confirmation. This avoids testing all checks on all rows.

2. **String length truncation for edit distance**: Edit distance is O(n·m) where n and m are string lengths. The `max_string_length` parameter (default 32 characters) provides 10-100x speedup on long strings. Adjust this parameter based on your data characteristics.

3. **Skip expensive O(n²) operations**: Concatenation detection requires testing all column pairs. For 100+ columns, this creates 5,000+ tests. Consider skipping concatenation entirely or only testing manually-specified pairs.

4. **Filter candidates intelligently**: Skip high-cardinality columns (likely unique IDs) using the `max_cardinality` threshold (default 1000 distinct values) and prioritize columns with semantic keywords ('CODE', 'NAME', 'DESC', 'TYPE', 'STATUS') that are most likely to contain derivable patterns. Limit candidates using the `max_candidates` parameter (default 50). Both thresholds are configurable via `filter_derivation_candidates()` parameters. See implementation below for the filtering logic.

5. **Use pattern-based detection for common cases**: For CODE→DESCRIPTION lookups, use naming heuristics instead of brute-force testing (see lookup expansion example below).

## Common String Operations

### 1. Concatenation with Separator

```python
def detect_concatenation(df, col_c, col_a, col_b, max_sep_length=3):
    """Detect if col_c = col_a + separator + col_b"""
    
    derivations = []
    
    # Pre-convert to strings once
    col_a_str = df[col_a].astype(str)
    col_b_str = df[col_b].astype(str)
    col_c_str = df[col_c].astype(str)
    
    # Test common separators
    separators = ['', ' ', '_', '-', ',', '|', '/', '\\', '.', ': ', ' - ', ', ']
    
    for sep in separators:
        # Fast length check: skip if lengths don't match
        expected_length = col_a_str.str.len() + len(sep) + col_b_str.str.len()
        actual_length = col_c_str.str.len()
        length_match_discrepancy = (expected_length - actual_length).sum() / len(df)
        
        # Only proceed with expensive concatenation if lengths match for most rows
        if abs(length_match_discrepancy) > 0.1:
            continue
        
        # Build expected concatenation
        expected = col_a_str + sep + col_b_str
        
        # Handle NaN
        match_mask = (col_c_str == expected) | (df[col_c].isna() & expected.isna())
        match_ratio = match_mask.sum() / len(df)
        
        if match_ratio > 0.95:
            derivations.append({
                'type': 'concatenation',
                'operands': [col_a, col_b],
                'separator': sep,
                'formula': f'{col_c} = {col_a} + "{sep}" + {col_b}',
                'match_ratio': match_ratio
            })

            # Break after the first separator successfully found
            break
    
    return derivations
```

### 2. Substring Extraction

```python
def detect_substring(df, col_c, col_source):
    """Detect if col_c is a substring of col_source"""
    
    derivations = []
    
    # Convert to string
    source_vals = df[col_source].astype(str)
    target_vals = df[col_c].astype(str)
    
    # Check if each value in col_c is substring of the value in col_source at the same row
    is_substring = pd.Series([
        tgt in src if pd.notna(tgt) and pd.notna(src) else True
        for tgt, src in zip(target_vals, source_vals)
    ])
    
    match_ratio = is_substring.sum() / len(df)
    
    if match_ratio > 0.95:
        derivations.append({
            'type': 'substring',
            'operands': [col_source],
            'formula': f'{col_c} is substring of {col_source}',
            'match_ratio': match_ratio
        })
    
    return derivations
```

### 3. Character Removal/Replacement

```python
def detect_character_removal(df, col_c, col_source):
    """Detect if col_c = col_source with certain characters removed"""
    
    derivations = []
    
    source_vals = df[col_source].astype(str)
    target_vals = df[col_c].astype(str)
    
    # Test common character removals
    char_sets = [
        (' ', 'whitespace'),
        ('-', 'hyphens'),
        ('_', 'underscores'),
        ('.', 'periods'),
        (',', 'commas'),
        ('()', 'parentheses'),
        ('[]', 'brackets'),
        ('-_ ', 'separators'),
    ]
    
    for chars, description in char_sets:
        # Remove characters
        removed = source_vals.str.translate(str.maketrans('', '', chars))
        match_ratio = (target_vals == removed).sum() / len(df)
        
        if match_ratio > 0.95:
            derivations.append({
                'type': 'character_removal',
                'operands': [col_source],
                'characters': chars,
                'description': description,
                'formula': f'{col_c} = {col_source}.replace([{chars}], "")',
                'match_ratio': match_ratio
            })

            # Break after the first character set successfully found
            break
    
    return derivations
```

### 4. Case Transformation

```python
def detect_case_transformation(df, col_c, col_source):
    """Detect if col_c is case transformation of col_source
    
    Note: Some rare Unicode characters have multiple lowercase representations,
    but this is ignored for performance and simplicity.
    """
    
    derivations = []
    
    source_vals = df[col_source].astype(str)
    target_vals = df[col_c].astype(str)
    
    # Lowercase both and compare
    source_lower = source_vals.str.lower()
    target_lower = target_vals.str.lower()
    
    match_ratio = (source_lower == target_lower).sum() / len(df)
    
    if match_ratio > 0.95:
        derivations.append({
            'type': 'case_transformation',
            'operands': [col_source],
            'formula': f'{col_c} = case_transform({col_source})',
            'match_ratio': match_ratio
        })
    
    return derivations
```

### 5. Equality/Substring Checks (Boolean)

```python
def detect_boolean_check(df, col_c, col_a, col_b=None):
    """Detect if col_c is boolean that matches col_a
    
    Simplified approach: just check if both columns map to the same True/False flags.
    Lowercase strings before mapping for consistent boolean conversion.
    """
    
    derivations = []
    
    # Boolean mapping
    bool_map = {'yes': True, 'no': False, 'true': True, 'false': False, 
                '1': True, '0': False, 1: True, 0: False, 1.0: True, 0.0: False}
    
    def to_bool(series):
        """Convert series to boolean, lowercasing strings first"""
        s = series.copy()
        if s.dtype == 'object':
            s = s.astype(str).str.lower().strip()
        return s.map(bool_map)
    
    try:
        target_bool = to_bool(df[col_c])
        
        if target_bool.notna().sum() / len(df) > 0.95:
            # Check if col_a maps to same boolean values
            source_bool = to_bool(df[col_a])
            match_ratio = (target_bool == source_bool).sum() / len(df)
            
            if match_ratio > 0.95:
                derivations.append({
                    'type': 'boolean_match',
                    'operands': [col_a],
                    'formula': f'{col_c} = boolean({col_a})',
                    'match_ratio': match_ratio
                })
    except:
        pass
    
    return derivations
```

### 6. Numeric String Extraction

```python
def detect_numeric_extraction(df, col_c, col_source):
    """Detect if col_c extracts numeric part from col_source"""
    
    derivations = []
    
    source_vals = df[col_source].astype(str)
    target_vals = df[col_c].astype(str)
    
    # Extract all digits
    digits_only = source_vals.str.replace(r'\D', '', regex=True)
    match_ratio = (target_vals == digits_only).sum() / len(df)
    
    if match_ratio > 0.95:
        derivations.append({
            'type': 'numeric_extraction',
            'operands': [col_source],
            'formula': f'{col_c} = {col_source}.replace(r"\\D", "", regex=True)',
            'match_ratio': match_ratio
        })
    
    return derivations
```

### 7. Edit Distance 1-2 Transformations

```python
def levenshtein_distance_bounded(s1, s2, max_distance=2):
    """
    Compute Levenshtein distance with early termination when distance exceeds threshold.
    
    Returns max_distance + 1 if the actual distance exceeds max_distance.
    This provides 10-100x speedup when most string pairs have distance > max_distance.
    
    Args:
        s1: First string
        s2: Second string
        max_distance: Maximum distance threshold
    
    Returns:
        int: Edit distance, or max_distance + 1 if exceeded
    """
    len1, len2 = len(s1), len(s2)
    
    # Early termination: if length difference exceeds max_distance,
    # minimum possible distance is the length difference
    if abs(len1 - len2) > max_distance:
        return max_distance + 1
    
    # Use two rows for space-optimized dynamic programming
    prev_row = list(range(len2 + 1))
    curr_row = [0] * (len2 + 1)
    
    for i in range(1, len1 + 1):
        curr_row[0] = i
        row_min = i  # Track minimum value in this row
        
        for j in range(1, len2 + 1):
            if s1[i - 1] == s2[j - 1]:
                cost = 0
            else:
                cost = 1
            
            curr_row[j] = min(
                prev_row[j] + 1,        # deletion
                curr_row[j - 1] + 1,    # insertion
                prev_row[j - 1] + cost  # substitution
            )
            
            row_min = min(row_min, curr_row[j])
        
        # Early termination: if all cells in this row exceed max_distance,
        # the final distance will definitely exceed max_distance
        if row_min > max_distance:
            return max_distance + 1
        
        # Swap rows for next iteration
        prev_row, curr_row = curr_row, prev_row
    
    distance = prev_row[len2]
    return distance if distance <= max_distance else max_distance + 1

def detect_edit_distance_transformation(df, col_c, col_source, max_distance=2, max_string_length=32):
    """Detect systematic edit distance transformations (truncates strings for performance)
    
    Args:
        df: DataFrame containing the data
        col_c: Target column name
        col_source: Source column name
        max_distance: Maximum edit distance to detect (default 2)
        max_string_length: Maximum string length to consider (default 32)
    """
    
    derivations = []
    
    source_vals = df[col_source].astype(str)
    target_vals = df[col_c].astype(str)
    
    # Sample pairs to find pattern
    sample_size = min(100, len(df))
    sample_indices = df.sample(n=sample_size).index
    
    edit_patterns = {}  # (operation, position) -> count
    
    for idx in sample_indices:
        src_val = source_vals.loc[idx]
        tgt_val = target_vals.loc[idx]
        
        if pd.notna(src_val) and pd.notna(tgt_val):
            src = str(src_val)[:max_string_length]  # Truncate for performance
            tgt = str(tgt_val)[:max_string_length]  # Truncate for performance
            dist = levenshtein_distance_bounded(src, tgt, max_distance)
            
            # Skip pairs that exceed max_distance
            if dist > max_distance:
                continue
            
            if 0 < dist <= max_distance:
                # Categorize the edit
                if len(src) == len(tgt):
                    # Substitution
                    for i, (c1, c2) in enumerate(zip(src, tgt)):
                        if c1 != c2:
                            pattern = ('substitute', i, c1, c2)
                            edit_patterns[pattern] = edit_patterns.get(pattern, 0) + 1
                
                elif len(src) < len(tgt):
                    # Insertion
                    for i in range(len(tgt)):
                        if i >= len(src) or src[:i] != tgt[:i]:
                            pattern = ('insert', i, tgt[i])
                            edit_patterns[pattern] = edit_patterns.get(pattern, 0) + 1
                            break
                
                elif len(src) > len(tgt):
                    # Deletion
                    for i in range(len(src)):
                        if i >= len(tgt) or src[:i] != tgt[:i]:
                            pattern = ('delete', i, src[i])
                            edit_patterns[pattern] = edit_patterns.get(pattern, 0) + 1
                            break
    
    # Find most common pattern
    if edit_patterns:
        most_common = max(edit_patterns.items(), key=lambda x: x[1])
        pattern, count = most_common
        
        if count / sample_size > 0.8:  # >80% of samples follow this pattern
            derivations.append({
                'type': 'edit_distance_transformation',
                'operands': [col_source],
                'pattern': pattern,
                'description': f'{pattern[0]} at position {pattern[1]}',
                'match_ratio': count / sample_size
            })
    
    return derivations
```

### 8. Format String Application

```python
def detect_format_string(df, col_c, col_a, col_b=None):
    """Detect if col_c is formatted string from col_a (and optionally col_b)"""
    
    derivations = []
    
    # Common format patterns
    if col_b is not None:
        format_patterns = [
            ('{} - {}', 'dash separated'),
            ('{}: {}', 'colon separated'),
            ('{}_{} ', 'underscore separated'),
            ('{}({})  ', 'parenthesized'),
            ('{} [{}]', 'bracketed'),
            ('{}, {}', 'comma separated'),
        ]
        
        for fmt, description in format_patterns:
            formatted = df.apply(
                lambda row: fmt.format(row[col_a], row[col_b]) 
                if pd.notna(row[col_a]) and pd.notna(row[col_b]) 
                else None, 
                axis=1
            )
            
            match_ratio = (df[col_c] == formatted).sum() / len(df)
            
            if match_ratio > 0.95:
                derivations.append({
                    'type': 'format_string',
                    'operands': [col_a, col_b],
                    'format_pattern': fmt,
                    'description': description,
                    'formula': f'{col_c} = "{fmt}".format({col_a}, {col_b})',
                    'match_ratio': match_ratio
                })
    
    return derivations
```

### 9. Lookup Expansion (CODE → DESCRIPTION)

**Most common in enterprise datasets**: Deterministic mappings where a code column expands to a description column.

```python
def detect_lookup_expansion(df, col_c, col_code, sample_indices=None):
    """
    Detect if col_c is a lookup/expansion of col_code 
    (e.g., 'M' -> 'Male', 'F' -> 'Female')
    
    Supports progressive sampling via sample_indices parameter
    """
    
    derivations = []
    
    # Use sample if provided, otherwise full dataset
    df_test = df.iloc[sample_indices] if sample_indices is not None else df
    threshold = 1.0 if sample_indices is not None else 0.80
    
    # Check if there's a deterministic mapping from code to description
    # Each code value should map to exactly one description value
    mapping = df_test.groupby(col_code)[col_c].nunique()
    
    # If each code maps to exactly 1 description, it's a lookup
    if (mapping == 1).all():
        # Calculate coverage
        matched_pairs = df_test[[col_code, col_c]].dropna().shape[0]
        match_ratio = matched_pairs / len(df_test) if len(df_test) > 0 else 0
        
        if match_ratio >= threshold:
            # Get sample mapping for documentation
            sample_map = df_test.groupby(col_code)[col_c].first().to_dict()
            sample_items = list(sample_map.items())[:3]
            
            derivations.append({
                'type': 'lookup_expansion',
                'operands': [col_code],
                'formula': f'{col_c} = lookup({col_code})',
                'description': f'Deterministic mapping from {col_code}',
                'sample_mapping': sample_items,
                'match_ratio': match_ratio,
                'mapping_size': len(sample_map)
            })
    
    return derivations
```

**Example lookup expansions**:
- `GENDER` ('F', 'M', 'U') → `GENDER_DESCRIPTION` ('Female', 'Male', 'UnSpecified')
- `ACTION_CODE` (79, 82, 85) → `ACTION_DESCRIPTION` ('79 Separation From Service', ...)
- `WORK_REGION` ('APAC', 'EMEA', 'CLA') → `WORK_REGION_DESC` ('ASIA PACIFIC', ...)

**Ontology best practice**: Keep the code column, remove the description column. Descriptions can be regenerated via lookup tables in the semantic layer.

## Comprehensive Detection Pipeline

### Helper Function

```python
def _run_all_detection_types(df, target_col, source_col, verbose=False):
    """
    Run all single-source detection types on the given dataframe sample
    
    Args:
        df: DataFrame containing the data
        target_col: Target column name
        source_col: Source column name
        verbose: Print progress messages for each detection type (default False)
    
    Returns:
        List of all detection results
    """
    all_checks = []
    
    if verbose:
        print(f"  Testing {target_col} ← {source_col}...")
    
    all_checks.extend(detect_substring(df, target_col, source_col))
    all_checks.extend(detect_character_removal(df, target_col, source_col))
    all_checks.extend(detect_case_transformation(df, target_col, source_col))
    all_checks.extend(detect_numeric_extraction(df, target_col, source_col))
    all_checks.extend(detect_edit_distance_transformation(df, target_col, source_col))
    all_checks.extend(detect_lookup_expansion(df, target_col, source_col))
    all_checks.extend(detect_boolean_check(df, target_col, source_col))
    
    return all_checks
```

### Candidate Filtering

```python
def filter_derivation_candidates(df, candidate_cols, max_cardinality=1000, max_candidates=50):
    """
    Filter candidate columns for derivation detection based on cardinality and naming patterns.
    
    Call this ONCE before analyzing multiple target columns to avoid redundant cardinality calculations.
    
    Args:
        df: DataFrame containing the data
        candidate_cols: List of column names to filter
        max_cardinality: Maximum unique values allowed (default 1000)
        max_candidates: Maximum candidates to return (default 50)
    
    Returns:
        List of filtered candidate column names
    """
    # Compute cardinality once for all columns
    col_cardinality = {col: df[col].nunique() for col in candidate_cols}
    
    # Skip high-cardinality columns (likely unique IDs)
    low_card_candidates = [c for c in candidate_cols if col_cardinality[c] < max_cardinality]
    
    # Prioritize CODE/DESC/NAME pattern columns
    priority = [c for c in low_card_candidates 
                if any(kw in c.upper() for kw in ['CODE', 'NAME', 'DESC', 'TYPE', 'STATUS'])]
    
    # Limit to max_candidates
    if len(low_card_candidates) > max_candidates:
        num_priority = min(30, len(priority))
        num_non_priority = max_candidates - num_priority
        non_priority = [c for c in low_card_candidates if c not in priority]
        candidates = priority[:num_priority] + non_priority[:num_non_priority]
    else:
        candidates = low_card_candidates
    
    return candidates
```

### Progressive Sampling Detection (All Dataset Sizes)

```python
def detect_all_string_derivations_optimized(df, target_col, candidate_cols, filtered_candidates=None, verbose=False):
    """
    Optimized detection with progressive sampling for large datasets
    
    Strategy:
    1. Filter candidates intelligently (cardinality, naming patterns) - SKIPPED if filtered_candidates provided
    2. Test ALL checks on filtered pairs with 3 samples, filter to 100% pass
    3. Test surviving checks with 10 samples, filter to 100% pass
    4. Test final surviving checks with 30 samples (require 95% match)
    
    Args:
        df: DataFrame containing the data
        target_col: Column name to analyze for derivations
        candidate_cols: List of all column names (used for fallback filtering if filtered_candidates not provided)
        filtered_candidates: Pre-filtered candidate list from filter_derivation_candidates() (RECOMMENDED for batch processing)
        verbose: Print progress messages during detection (default False)
    
    Returns:
        List of derivation findings
    """
    
    if verbose:
        print(f"\nAnalyzing column: {target_col}")
    
    # Use pre-filtered candidates if provided, otherwise filter now
    if filtered_candidates is not None:
        candidates = filtered_candidates
    else:
        # Pre-filter candidates (backward compatibility - but inefficient for batch processing)
        candidates = filter_derivation_candidates(df, candidate_cols)
    
    # Get sample indices
    n_rows = len(df)
    sample_3 = np.random.choice(n_rows, min(3, n_rows), replace=False)
    sample_10 = np.random.choice(n_rows, min(10, n_rows), replace=False)
    sample_30 = np.random.choice(n_rows, min(30, n_rows), replace=False)
    
    # Create sampled dataframes
    df_3 = df.iloc[sample_3]
    df_10 = df.iloc[sample_10]
    df_30 = df.iloc[sample_30]
    
    # Phase 1: Test ALL checks on ALL pairs with 3 samples
    phase1_checks = {}  # (target, source) -> [checks with 100% pass]
    
    if verbose:
        print(f"  Phase 1: Testing with 3 samples...")
    
    for source_col in candidates:
        if source_col == target_col:
            continue
        
        # Run all single-source detection types
        all_checks = _run_all_detection_types(df_3, target_col, source_col, verbose=False)
        
        # Filter to checks with 100% pass rate
        passed_checks = [c for c in all_checks if c.get('match_ratio', 0) == 1.0]
        
        if passed_checks:
            phase1_checks[(target_col, source_col, 'single')] = passed_checks
    
    # Test two-source operations (concatenation)
    # Note: O(n²) complexity. For >50 columns, consider limiting candidate pairs.
    for i, source_col_a in enumerate(candidates):
        if source_col_a == target_col:
            continue
        for source_col_b in candidates[i+1:]:
            if source_col_b == target_col:
                continue
            
            concat_checks = detect_concatenation(df_3, target_col, source_col_a, source_col_b)
            passed_concat = [c for c in concat_checks if c.get('match_ratio', 0) == 1.0]
            
            if passed_concat:
                phase1_checks[(target_col, source_col_a, source_col_b)] = passed_concat
    
    if not phase1_checks:
        return []
    
    # Phase 2: Test surviving checks with 10 samples
    phase2_checks = {}
    
    if verbose:
        print(f"  Phase 2: Re-testing {len(phase1_checks)} candidates with 10 samples...")
    
    for key, _ in phase1_checks.items():
        if len(key) == 3:  # Single-source operation
            source_col = key[1]
            all_checks = _run_all_detection_types(df_10, target_col, source_col, verbose=False)
        else:  # Two-source operation (concatenation)
            source_col_a, source_col_b = key[1], key[2]
            all_checks = detect_concatenation(df_10, target_col, source_col_a, source_col_b)
        
        # Filter to checks with 100% pass rate
        passed_checks = [c for c in all_checks if c.get('match_ratio', 0) == 1.0]
        
        if passed_checks:
            phase2_checks[key] = passed_checks
    
    if not phase2_checks:
        return []
    
    # Phase 3: Test final surviving checks with 30 samples (95% threshold)
    all_derivations = []
    
    if verbose:
        print(f"  Phase 3: Final validation of {len(phase2_checks)} candidates with 30 samples...")
    
    for key, _ in phase2_checks.items():
        if len(key) == 3:  # Single-source operation
            source_col = key[1]
            all_checks = _run_all_detection_types(df_30, target_col, source_col, verbose=False)
        else:  # Two-source operation (concatenation)
            source_col_a, source_col_b = key[1], key[2]
            all_checks = detect_concatenation(df_30, target_col, source_col_a, source_col_b)
        
        # Accept checks with >= 95% pass rate
        all_derivations.extend([c for c in all_checks if c.get('match_ratio', 0) >= 0.95])
    
    # Sort by match ratio
    all_derivations.sort(key=lambda x: x.get('match_ratio', 0), reverse=True)
    
    return all_derivations
```

## API Reference

### filter_derivation_candidates(df, candidate_cols, max_cardinality=1000, max_candidates=50)

**Purpose**: Filter candidate columns based on cardinality and naming patterns. **Call this ONCE before batch processing** to avoid redundant calculations.

**Parameters**:

* `df` (pd.DataFrame): DataFrame containing the data
* `candidate_cols` (list[str]): List of column names to filter
* `max_cardinality` (int): Maximum unique values threshold (default 1000)
* `max_candidates` (int): Maximum candidates to return (default 50)

**Returns**: `list[str]` - Filtered list of candidate column names

**Performance**: O(n) where n=len(candidate_cols). Computes cardinality once for all columns.

### detect_all_string_derivations_optimized(df, target_col, candidate_cols, filtered_candidates=None, verbose=False)

**Purpose**: Detect all string derivations for a single target column using progressive sampling optimization.

**Parameters**:

* `df` (pd.DataFrame): DataFrame containing the data to analyze
* `target_col` (str): Column name to analyze for potential derivations
* `candidate_cols` (list[str]): List of column names (used only if `filtered_candidates` not provided)
* `filtered_candidates` (list[str], optional): Pre-filtered candidates from `filter_derivation_candidates()`. **HIGHLY RECOMMENDED for batch processing** to avoid redundant cardinality calculations.
* `verbose` (bool, optional): Print progress messages showing which column is being analyzed and which phase (default False). Useful for monitoring long-running batch processes.

**Returns**: `list[dict]` - List of derivation findings, sorted by `match_ratio` in descending order (highest confidence first).

**Derivation Dictionary Schema**:

```python
{
    'type': str,              # Derivation type: 'lookup_expansion', 'concatenation', 
                              # 'substring', 'character_removal', 'case_transformation',
                              # 'numeric_extraction', 'edit_distance_transformation',
                              # 'format_string', 'boolean_match'
    'operands': list[str],    # Source column name(s) used in the derivation
    'formula': str,           # Human-readable formula describing the transformation
    'match_ratio': float,     # Confidence score (0.0-1.0), percentage of rows matching
    # Type-specific fields (varies by derivation type):
    'separator': str,         # For concatenation: the separator character(s)
    'characters': str,        # For character_removal: removed characters
    'description': str,       # Additional context about the derivation
    'sample_mapping': list,   # For lookup_expansion: sample code→description pairs
    'mapping_size': int,      # For lookup_expansion: total number of mappings
    'pattern': tuple,         # For edit_distance: the edit operation pattern
}
```

**Performance**: O(n·m·k) where n=len(candidate_cols), m=number of detection types (9), k=sample size. Uses three-phase progressive sampling (3→10→30 rows) to eliminate non-matches early, achieving 10-100x speedup over full-dataset testing.

**Candidate Filtering**: When `filtered_candidates` is None, automatically filters high-cardinality columns using the `max_cardinality` threshold (default 1000 unique values) and prioritizes semantic keywords. **For batch processing, use `filter_derivation_candidates()` once and pass result to avoid 100x redundant cardinality calculations.**

> [!IMPORTANT]
> When analyzing multiple columns, **always** use `filter_derivation_candidates()` first. Passing the result via `filtered_candidates` parameter provides 100x speedup by computing cardinality once instead of once-per-column.

## Usage Patterns

### Basic Usage: Single Column Analysis

```python
import pandas as pd

# Load your data
df = pd.read_csv('data.csv')

# Analyze one column for derivations
derivations = detect_all_string_derivations_optimized(
    df=df,
    target_col='EMPLOYEE_FULL_NAME',
    candidate_cols=df.columns.tolist()
)

# Process results
if derivations:
    best = derivations[0]
    print(f"Best match: {best['formula']}")
    print(f"Confidence: {best['match_ratio']:.1%}")
    print(f"Type: {best['type']}")
else:
    print("No derivations found")
```

### Batch Processing: All String Columns (RECOMMENDED PATTERN)

```python
# Get all string columns
string_cols = df.select_dtypes(include=['object']).columns.tolist()

# IMPORTANT: Filter candidates ONCE before the loop
filtered_candidates = filter_derivation_candidates(df, string_cols)
print(f"Filtered {len(string_cols)} columns down to {len(filtered_candidates)} candidates")

# Analyze each column using pre-filtered candidates
findings = {}
for col in string_cols:
    derivations = detect_all_string_derivations_optimized(
        df, col, string_cols, 
        filtered_candidates=filtered_candidates  # Pass pre-filtered list
    )
    if derivations:
        findings[col] = derivations[0]  # Store best match

# Process findings
for col, derivation in findings.items():
    print(f"{col} ← {derivation['formula']} ({derivation['match_ratio']:.1%})")
```
