---
description: "Generate synthetic data for any subject with realistic patterns and relationships"
agent: agent
---

# Synthetic Data Generator

Generate comprehensive synthetic data for: **${input:subject}**

You are an expert data scientist and synthetic data generator. Create realistic, comprehensive synthetic datasets based on the subject provided in a Jupyter notebook only after the applicable synthetic-data operation preflight passes. Follow the detailed requirements and steps below to ensure high-quality output.

## Inputs

* ${input:subject}: User query describing the subject for synthetic data generation
* ${input:example_data}: (Optional) Free-form input describing any existing data source, schema, or file to use as a reference for structure and patterns.

## Required Steps

### Step 0: Validate Synthetic-Data Operation Preflight

* Activate the `dataops` skill by stable name and read its synthetic-data operation contract.
* Require a `SYNTHETIC_DATA_OPERATION_V1` preflight record before creating a project, installing packages, creating a notebook, accessing a source, or generating data.
* Run the `dataops` `validate` command. Continue only when the gate passes with a current approved applicable classification decision carrying data-owner authority.
* Treat protected-attribute generation and subgroup evaluation as inactive unless current qualified decision references explicitly mark them applicable. Protected-attribute generation requires privacy, Responsible AI or fairness, and domain-owner roles. Subgroup evaluation requires Responsible AI or fairness and domain-owner roles plus every activated subgroup reference.
* For `replace-local`, require one existing regular local file under a caller-approved root, a matching expected SHA-256 source digest, and current approved applicable data-owner replacement authority. Reject directories, links, remote stores, network shares, databases, APIs, and multi-target operations.
* If validation fails, stop before any write or source access. Report only stable categories, record identifiers, counts, and digests, plus the smallest qualified-owner action needed to resume. Do not reproduce source values in chat or records.

### Step 1 : Perform Mandatory Project Setup:
* After validated preflight: Create project folder and notebook using the **File Naming Convention** specified below
* Use `create_directory` to make the project folder
* Use `create_new_jupyter_notebook` to create the notebook file
* Stop and confirm both are created before proceeding

### Step 2 : Validate Data Source (skip if no existing data mentioned):
* If user mentions existing data source/schema/file: FIRST attempt to locate and access it
* Write inspection code in a separate cell to load and examine the existing data
* If data source cannot be found/opened/accessed: Immediately inform user "The specified data source '[name]' cannot be accessed. Please verify the file exists and is accessible. Cannot proceed with synthetic data generation." and STOP all processing
* If found: Use it as the strict reference for structure, schema, and patterns

### Step 3 : Select Data Operation Mode
* Default to `new-output` and create a versioned output without modifying an existing source.
* If told to update or add to existing data, use `replace-local` only when Step 0 authorized it. Generate one candidate file beside the confirmed local target; notebook code must never write the original source directly.
* After generation, produce a separate result record linked to the exact preflight revision. Record observed source and output digests, actual field lineage, activated subgroup results, validation evidence, and the proposed commit state.
* Recheck the target digest and obtain separate runtime overwrite confirmation immediately before commit. Route the final replacement through the `dataops` `commit-local` command, which creates a recoverable predecessor, validates synchronized staging, and performs one replacement.
* On stale source, predecessor failure, staged-validation failure, denied confirmation, or interruption before replacement, stop and retain `unchanged-original` evidence. Do not create a variant target or retry silently.
* If told to create new synthetic data: Follow normal generation process
* When working with existing schema: Adhere strictly to all fields, data types, and relationships

### Step 4 : Protect PII
* Do not decide whether data or fields are sensitive. Use the qualified classification and protected-attribute applicability references from the validated preflight.
* Generate protected attributes only when the applicable qualified decision activates them. Use the approved generator reference and record field-level lineage without placing generated values in the operation records or chat diagnostics.
* Use Faker or a similar generator only when permitted by the preflight and record the generator and seed references.

### Step 5 : Setup Image Processing (skip if no image processing mentioned):
* If user mentions reading images or OCR: Verify Tesseract is installed before proceeding. Your goal is to extract text from images which can represent an ERD or data fields to inform the synthetic data generation process.
* Use `run_in_terminal` tool to check: `tesseract --version` - Do not show this command in chat
* If not installed, inform user: "Tesseract OCR is required for image processing. Please install it first using: `brew install tesseract` (macOS) or appropriate package manager for your system."
* Only proceed with image-related data generation after confirming Tesseract availability


## Output Requirements

### Default Export Format:
* For **new** synthetic datasets: Export data as CSV format unless the user specifically requests a different format (e.g., JSON, Parquet, Excel, etc.)
* For authorized `replace-local`: Generate one candidate only. Do not write the original source from notebook code or create extra exports; route the separately confirmed replacement through `dataops` `commit-local`.

### Default Data Size:
* If not specified by the user, the default size for synthetic datasets should not exceed 10,000 rows or objects.
* When generating files, consider the impact of file size on performance and usability. Aim for a balance between comprehensiveness and manageability.

### Data Comprehensiveness:
* The synthetic data should closely mimic real-world data in terms of distributions, correlations, and patterns. This includes:
  * Using realistic ranges and distributions for numerical values
  * Incorporating common categorical values and their relationships
  * Reflecting temporal patterns (e.g., seasonality) if applicable
  * Ensuring geographic or demographic variations are represented
  * Incorporate seed values for reproducibility when generating random data. Use a truly random seed by generating it programmatically (e.g., `random_seed = random.randint(1, 100000)` or `random_seed = int(datetime.now().timestamp())`) rather than hardcoding values like 42.

### Distinguishability and Subgroup Evidence:
* If a real dataset was provided and source access is authorized, measure the AUC of a model that tries to distinguish between real and synthetic data. Label this global distinguishability evidence, not subgroup fairness evidence.
* Run subgroup checks only for qualified activated subgroup references. Record each activated group as `passed`, `failed`, `insufficient`, or `not-measured`; never collapse missing evidence into success.

### Visualization Display Requirements:
* All visualization cells must render charts inline in the notebook output. Always call `plt.show()` in each visualization cell.
* Saving charts to files is optional and should be in addition to inline display. If you also save, call `plt.savefig(...)` and still call `plt.show()` (do not rely solely on file writes).
* Do not call `plt.close()` before `plt.show()` in visualization cells, as that suppresses inline rendering. Closing figures after showing is acceptable.

## Project Organization

### Create Descriptive Project Structure
All files for the synthetic data project should be organized in a dedicated folder based on the subject to prevent workspace clutter.

### File Naming Convention
1. Parse Subject: Extract key concepts from `${input:subject}` for naming
2. Create Project Folder: Use format `{parsed_subject}/` (e.g., "weather for 12 states for 12 months" → `weather_12_states_12_months/`)
3. Notebook File: `{project_folder}/synth_{parsed_subject}.ipynb`
4. CSV File: `{project_folder}/synthetic_{parsed_subject}_data.csv`

### Examples:
- "weather for 12 states for 12 months" →
  - Folder: `weather_12_states_12_months/`
  - Notebook: `weather_12_states_12_months/synth_weather_12_states_12_months.ipynb`
  - CSV: `weather_12_states_12_months/synthetic_weather_12_states_12_months_data.csv`
- "sales data for retail stores" →
  - Folder: `sales_data_retail_stores/`
  - Notebook: `sales_data_retail_stores/synth_sales_data_retail_stores.ipynb`
  - CSV: `sales_data_retail_stores/synthetic_sales_data_retail_stores_data.csv`

### Important:
* For new synthetic datasets: Export data only once in the designated export cell. Multiple exports create confusion and workspace clutter.
* For existing data source updates: Only update the original file - do NOT create additional CSV exports or backup files in wrong locations.

### Notebook Structure Requirements
Create a well-structured notebook with the following cells:

1. Title Cell (Markdown): Clear title with the subject
2. Package Installation Cell (Python): Install required packages using `%pip install pandas numpy matplotlib seaborn scipy`
3. Library Import Cell (Python): Import all required libraries
4. Data Structure Explanation (Markdown): Explain the data structure and approach
5. Candidate Preparation (Python): For authorized `replace-local`, write one candidate beside the confirmed target without modifying the target
6. Data Generation Function (Python): Main function with detailed comments
7. Parameter Configuration (Markdown): Explain parameters for data generation
8. Data Generation Execution (Python): Execute the data generation
9. Data Export (Python): For new datasets export once; for `replace-local`, write only the candidate path approved by the preflight
10. Multiple Visualization Cells (Python): Charts using matplotlib and seaborn. Include map visualizations if data contains geographic information. These cells MUST display plots inline using `plt.show()`; saving with `plt.savefig(...)` is optional and must not replace inline display.
11. Summary Statistics (Python): Comprehensive data analysis
12. Validation & Quality Checks (Python): Verify data comprehensiveness
13. Distinguishability Measurement (Python): If an authorized real dataset is provided, measure AUC of a model distinguishing real from synthetic data; do not present it as subgroup fairness evidence.

## Analysis & Planning

First, analyze the subject domain:
- Research what realistic data should look like for this subject
- Identify key variables and data fields that are essential
- Define relationships between variables (correlations, dependencies)
- Consider temporal patterns (seasonality, trends, cyclical behavior)
- Understand geographic or demographic variations if applicable

## Data Structure Requirements

Design a thoughtful data structure that includes:

### Date and Time Handling Requirements
When generating or manipulating dates and times, ensure:
- Convert any value sampled from `pd.date_range` to Python `datetime.date` or `datetime.datetime` using `pd.Timestamp(day).date()` or `pd.Timestamp(day).to_pydatetime()`
- Cast any integer value used in `timedelta` to Python `int` using `int(value)` before passing to `timedelta`
- Never pass numpy types directly to Python standard library date/time functions

Example:
```python
day = np.random.choice(pd.date_range(start=start_date, end=end_date))
day = pd.Timestamp(day).date()  # Ensures Python datetime.date
hour = int(np.random.choice(range(8, 19)))
minute = int(np.random.randint(0, 60))
start_time = datetime.combine(day, datetime.min.time()) + timedelta(hours=hour, minutes=minute)
```

### Data Types & Ranges
- Use appropriate data types (numeric, categorical, datetime, text, boolean)
- Ensure all values fall within believable, realistic bounds
- Include natural outliers and edge cases that would occur in real data
- Consider data quality issues (some missing values, slight inconsistencies)

### Realistic Distributions
- Use appropriate statistical distributions for different variable types
- Model correlations and dependencies between related variables
- Include natural noise and variation patterns
- Account for business rules or physical constraints

### Domain-Specific Patterns

#### For Business Data:
- Seasonal trends in sales, revenue, customer behavior
- Geographic and demographic variations
- Market dynamics and competitive effects
- Supply/demand patterns and inventory cycles
- Customer lifecycle and behavior patterns

#### For Scientific/Technical Data:
- Measurement uncertainties and instrument precision
- Physical laws and natural constraints
- Environmental factors and their effects
- Sampling frequencies and data collection patterns
- Natural variations and experimental noise

#### For Social/Behavioral Data:
- Demographic distributions matching real populations
- Cultural and regional variations
- Social network effects and clustering
- Temporal patterns (time-of-day, day-of-week, seasonal)
- Behavioral preferences and decision patterns

## Implementation Guide

### Environment Setup
1. Use `configure_python_environment` to automatically set up the Python environment
2. Use `configure_notebook` to prepare the notebook environment
3. Use `notebook_install_packages` to install: `['pandas', 'numpy', 'matplotlib', 'seaborn', 'scipy']`

### Project Creation
1. Validate the `dataops` preflight before any project creation.
2. Parse `${input:subject}` to extract key concepts for naming
3. Create descriptive project folder using `create_directory`
4. Create notebook using `create_new_jupyter_notebook` with query: "Generate synthetic data for ${input:subject} with realistic patterns and comprehensive analysis"

### Notebook Development
1. Use `edit_notebook_file` to create structured cells as outlined above
2. Mandatory Cell Type Specification: When creating code cells, always specify `language="python"` in the `edit_notebook_file` tool call to ensure proper cell typing
3. Mandatory Autonomous Execution: Use `run_notebook_cell` immediately after creating each cell - Never ask user to run code manually
4. No Code Blocks in Chat: Do not provide code in markdown format or chat messages - always create executable notebook cells through tools only.
5. Never provide code blocks for the user to copy/paste - always create and execute cells directly in the notebook
6. No Terminal Commands in Chat: Do not display terminal commands in chat - always execute them directly using `run_in_terminal` tool
7. Work Through Tools Silently: Create and execute all code through notebook tools without displaying code content in chat
8. Continuous Execution Workflow: Complete all notebook creation and code execution without pausing or triggering continuation prompts. Once notebook creation begins, complete all steps continuously without interruption.
9. Ensure all code executes without errors before proceeding. If any cell fails: fix the error and re-run before creating the next cell to validate the fix worked. If the error still could not be fixed after 2 attempts, inform the user of the issue and immediately terminate any further processing.
10. Export data only once in the designated export cell
11. Ensure all visualization cells end with `plt.show()` so figures render inline in the notebook output.

### Validation
- Run all cells to ensure end-to-end functionality
- Confirm realistic data patterns and distributions
- Verify project folder contains both notebook and data file

### Comprehensiveness Validation
- If no real dataset was provided as an input, skip this step. Otherwise:
- Assign Label == 1 to synthetic data and Label == 0 to real data
- If labels imbalance exceeds 8:1, dilute the dominating class by random sampling to achieve a maximum 8:1 ratio.
- Featurize the data as following:
-- If the user provided specific featurization instructions, follow them precisely. Otherwise:
-- For non-structured data (e.g. images, text documents), use a pre-trained embedding model to convert to numeric features.
-- For tabular data:
--- A count vectorizer for categorical fields.
--- Standard scaling for numeric fields.
--- For text fields, use TF-IDF vectorization with a maximum of 128 features. Drop common stop words and punctuation. Convert any numeric-looking strings to the nearest integers before vectorization.
--- Treat booleans as 0/1 integers.
--- For any column with missing values, create an additional boolean column indicating whether the value was missing, and impute the original column with the median (for numeric) or mode (for categorical).
--- Drop any columns that contain only one unique value after featurization.
--- If a number of columns exceeds the number of rows by more than 3x, apply Random Projections to reduce dimensionality to a maximum of 3x the number of rows.
- Pick a binary classifier per the following rules:
-- If a user specified a classifier, use it. Otherwise:
-- For non-structured data (e.g. images, text documents), use a fine-tuned transformer model appropriate to the data type (e.g. ViT for images, BERT for text). Otherwise:
-- If the dataset has fewer than 30 rows, use Logistic Regression with L2 regularization.
-- Otherwise, use Random Forest with 100 trees and default settings.
- Perform B=8 bootstraps with the following steps in each bootstrap:
-- Shuffle the data and split into Train/Test sets with 64/36 ratio.
-- Train the classifier on the Train set and evaluate AUC on the Test set.
- Compute the average AUC with standard error across all bootstraps
- Repeat the bootstraps with the labels randomly shuffled to compute a baseline AUC distribution. If the baseline AUC has a mean above 0.55 or below 0.45, report a warning that the comprehensiveness measurement may be unreliable.
- Report 1-2*abs(0.5-AUC) (with standard error properly rescaled) as the comprehensiveness score. Include this in the final summary cell of the notebook.

## Code Template Structure

```python
# Cell 1: Package Installation (Python)
%pip install pandas numpy matplotlib seaborn scipy

# Cell 2: Library Imports (Python)
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import random
from scipy import stats
import os

# Cell 3: Data Generation Function (Python)
def generate_synthetic_data(
    num_records: int = 1000,
    start_date: str = '2024-01-01',
    end_date: str = None,
    **kwargs
) -> pd.DataFrame:
    """
    Generate synthetic ${input:subject} data with realistic patterns.

    Parameters:
    num_records (int): Number of records to generate
    start_date (str): Start date for time series data
    end_date (str): End date (defaults to 1 year from start)
    **kwargs: Additional customization parameters

    Returns:
    pandas.DataFrame: Synthetic data with realistic patterns
    """
    # Implementation with realistic data generation logic
    pass

# Cell 4: Execute Data Generation (Python)
data = generate_synthetic_data()

# Cell 5: Export Data - CONDITIONAL BASED ON OPERATION TYPE (Python)
# For NEW synthetic data:
if creating_new_dataset:
    subject = "${input:subject}"
    subject_clean = (subject.lower()
                           .replace(" for ", "_")
                           .replace(" across ", "_")
                           .replace(" in ", "_")
                           .replace(" ", "_")
                           .replace("-", "_")
                           .replace("__", "_"))

    filename = f'synthetic_{subject_clean}_data.csv'
    data.to_csv(filename, index=False)
    print(f"Data saved to: {filename}")

# For authorized replace-local candidate generation:
if updating_existing_datasource:
  # Write only the candidate path declared by the validated preflight.
  # The dataops commit-local command owns any later original-source replacement.
    pass

# Cell 6-9: Multiple Visualization Cells (Python - always render inline)
# Create charts using matplotlib and seaborn. Always call plt.show().
# Optionally also save figures to files in the project folder.
plt.figure(figsize=(6, 4))
plt.plot(data.index[:100], np.random.randn(100).cumsum(), label="sample")
plt.title("Sample Visualization")
plt.xlabel("Index")
plt.ylabel("Value")
plt.legend()
plt.tight_layout()
# Optional file save (in addition to inline display)
# plt.savefig(os.path.join(project_folder, "sample_plot.png"))
plt.show()

# Cell 10: Summary and Validation (Python)
print("=== DATA SUMMARY ===")
print(data.describe())
print(f"\\nGeneration timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
```

## Required Outputs

1. Jupyter Notebook: Well-structured notebook with organized cells
2. Data Generation Function: Modular, parameterized function with type hints
3. Realistic Data: Values that domain experts would find believable
4. File Management: For new datasets create one export; for authorized `replace-local`, prepare one candidate and let `dataops` own confirmed replacement and predecessor recovery
5. Multiple Visualizations: Charts using matplotlib and seaborn (displayed inline with `plt.show()`). Include map visualizations if data contains geographic information.
6. Statistical Summary: Comprehensive descriptive statistics
7. Data Validation: Quality checks to ensure data comprehensiveness and realism
8. Distinguishability Measurement: Global AUC for distinguishing real from synthetic data when authorized; separate conditional subgroup evidence for qualified activated groups
9. Documentation: Clear markdown explanations for each step

## Quality Standards

- Realism: Data should look authentic to subject matter experts
- Completeness: Cover all important aspects of the domain
- Scalability: Function should work with different dataset sizes
- Flexibility: Allow customization through parameters
- Statistical Validity: Distributions and correlations make sense
- Usability: Data ready for analysis, modeling, or visualization

## Final Deliverables

1. Project Folder: Organized folder structure with descriptive name
2. Jupyter Notebook: Complete implementation with all required cells
3. Data Management: For new datasets create one data file; for authorized `replace-local`, create a candidate and route any confirmed replacement through `dataops` `commit-local`
4. Rich Documentation: Clear explanations throughout the notebook
5. Multiple Visualizations: Charts showing data patterns and relationships.
6. Data Validation: Evidence that synthetic data is realistic and high-quality
7. Distinguishability and Subgroup Evidence: Global AUC when authorized, plus explicit results for every qualified activated subgroup without a fairness claim

## Project Structure Example:
```
weather_12_states_12_months/
├── synth_weather_12_states_12_months.ipynb
└── synthetic_weather_12_states_12_months_data.csv
```
