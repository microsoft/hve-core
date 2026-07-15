#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# Detect string derivations in tabular data
# Brought to you by microsoft/hve-core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
INPUT_FILE=""
TARGET_COLUMN=""
OUTPUT_FILE="string_derivation_report.csv"
VERBOSE=false
MAX_CARDINALITY=1000
MAX_CANDIDATES=50

# Usage function
usage() {
    cat << EOF
Usage: $(basename "$0") -i INPUT_FILE [-t TARGET_COLUMN] [OPTIONS]

Detect string derivations in tabular data using progressive sampling.

Required Arguments:
  -i, --input FILE          Input CSV file path

Optional Arguments:
  -t, --target COLUMN       Analyze specific column (default: all string columns)
  -o, --output FILE         Output report file (default: string_derivation_report.csv)
  -c, --max-cardinality N   Max unique values threshold (default: 1000)
  -m, --max-candidates N    Max candidate columns (default: 50)
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  # Analyze all string columns
  $(basename "$0") -i data.csv

  # Analyze specific column with verbose output
  $(basename "$0") -i data.csv -t FULL_NAME -v

  # Custom output file and thresholds
  $(basename "$0") -i data.csv -o results.csv -c 500 -m 30

Output:
  CSV file with columns: target_column, derivation_type, source_columns, 
  formula, match_ratio, details

Exit Codes:
  0 - Success
  1 - Invalid arguments or file not found
  2 - Missing dependencies
  3 - Python execution error
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_COLUMN="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--max-cardinality)
            MAX_CARDINALITY="$2"
            shift 2
            ;;
        -m|--max-candidates)
            MAX_CANDIDATES="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: Input file required (-i)"
    usage
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Check Python dependencies
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3.7+"
    exit 2
fi

# Check required Python packages
python3 -c "import pandas, numpy" 2>/dev/null || {
    echo "Error: Missing Python dependencies. Install with:"
    echo "  pip install pandas numpy"
    exit 2
}

# Create Python detection script
PYTHON_SCRIPT=$(mktemp)
trap 'rm -f "$PYTHON_SCRIPT"' EXIT

cat > "$PYTHON_SCRIPT" << 'PYTHON_EOF'
import sys
import pandas as pd
import json

# Parse command line arguments
args = json.loads(sys.argv[1])
input_file = args['input_file']
target_column = args.get('target_column')
output_file = args['output_file']
verbose = args['verbose']
max_cardinality = args['max_cardinality']
max_candidates = args['max_candidates']

# Load the detection functions from references/algorithms.md
# NOTE: In production, these should be in a proper Python module
# For now, users must copy the functions from references/algorithms.md
try:
    # Import functions - adjust path as needed
    import sys
    from pathlib import Path
    
    # Try to load from a local module if it exists
    # Otherwise, provide helpful error message
    print("Note: Detection functions must be copied from references/algorithms.md")
    print("Creating inline implementation for demonstration...")
    
    # Minimal inline implementation
    # (In production, source these from algorithms.md)
    exec(open(Path(__file__).parent / 'references' / 'algorithms.md').read())
    
except Exception as e:
    print(f"Error: Could not load detection functions: {e}", file=sys.stderr)
    print("Please copy the functions from references/algorithms.md into your project", file=sys.stderr)
    sys.exit(3)

# Load data
if verbose:
    print(f"Loading data from {input_file}...")

df = pd.read_csv(input_file)
string_cols = df.select_dtypes(include=['object']).columns.tolist()

if verbose:
    print(f"Found {len(string_cols)} string columns in dataset")

# Filter candidates once
filtered_candidates = filter_derivation_candidates(
    df, string_cols, 
    max_cardinality=max_cardinality,
    max_candidates=max_candidates
)

if verbose:
    print(f"Filtered to {len(filtered_candidates)} candidate columns")

# Determine columns to analyze
if target_column:
    if target_column not in df.columns:
        print(f"Error: Column '{target_column}' not found in dataset", file=sys.stderr)
        sys.exit(1)
    analyze_columns = [target_column]
else:
    analyze_columns = string_cols

# Run detection
results = []
for col in analyze_columns:
    if verbose:
        print(f"Analyzing column: {col}")
    
    derivations = detect_all_string_derivations_optimized(
        df, col, string_cols,
        filtered_candidates=filtered_candidates,
        verbose=verbose
    )
    
    for deriv in derivations:
        results.append({
            'target_column': col,
            'derivation_type': deriv['type'],
            'source_columns': ','.join(deriv['operands']),
            'formula': deriv['formula'],
            'match_ratio': deriv['match_ratio'],
            'details': json.dumps({k: v for k, v in deriv.items() 
                                  if k not in ['type', 'operands', 'formula', 'match_ratio']})
        })

# Save results
if results:
    results_df = pd.DataFrame(results)
    results_df.to_csv(output_file, index=False)
    print(f"\nFound {len(results)} derivations")
    print(f"Results saved to: {output_file}")
else:
    print("\nNo derivations found")
    # Create empty output file
    pd.DataFrame(columns=['target_column', 'derivation_type', 'source_columns', 
                          'formula', 'match_ratio', 'details']).to_csv(output_file, index=False)

sys.exit(0)
PYTHON_EOF

# Prepare arguments for Python script
ARGS=$(cat <<EOF
{
    "input_file": "$INPUT_FILE",
    "target_column": "$TARGET_COLUMN",
    "output_file": "$OUTPUT_FILE",
    "verbose": $VERBOSE,
    "max_cardinality": $MAX_CARDINALITY,
    "max_candidates": $MAX_CANDIDATES
}
EOF
)

# Run Python detection
if [[ "$VERBOSE" == "true" ]]; then
    echo "Starting string derivation detection..."
fi

python3 "$PYTHON_SCRIPT" "$ARGS" || exit 3

exit 0
