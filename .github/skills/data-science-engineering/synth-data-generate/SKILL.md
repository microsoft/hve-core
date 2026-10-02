---
name: synth-data-generate
description: 'Generate synthetic datasets in a Jupyter notebook after the dataops synthetic-data preflight passes. Use when creating new synthetic data or preparing a guarded local replacement candidate from an approved source.'
argument-hint: 'subject=... [example_data=...]'
license: MIT
user-invocable: true
disable-model-invocation: true
---
<!-- cspell:ignore distinguishability tesseract pydatetime savefig scipy timedelta -->

# Synthetic Data Generator

## Goal

Generate realistic, comprehensive synthetic data for `subject` in a Jupyter notebook only after the applicable `dataops` synthetic-data operation preflight passes. Use `example_data` when the user supplies an existing data source, schema, or file to use as a strict reference for structure and patterns.

## Inputs

* `subject`: Required. User query describing the subject for synthetic data generation.
* `example_data`: Optional. Free-form input describing an existing data source, schema, or file to use as a reference for structure and patterns.

## Required steps

### Step 0: Validate synthetic-data operation preflight

* Activate the `dataops` skill by stable name and read its synthetic-data operation contract.
* Require a `SYNTHETIC_DATA_OPERATION_V1` preflight record before creating a project, installing packages, creating a notebook, accessing a source, or generating data.
* Run the `dataops` `validate` command. Continue only when the gate passes with a current approved applicable classification decision carrying data-owner authority.
* Treat protected-attribute generation and subgroup evaluation as inactive unless current qualified decision references explicitly mark them applicable. Protected-attribute generation requires privacy, Responsible AI or fairness, and domain-owner roles. Subgroup evaluation requires Responsible AI or fairness and domain-owner roles plus every activated subgroup reference.
* For `replace-local`, require one existing regular local file under a caller-approved root, a matching expected SHA-256 source digest, and current approved applicable data-owner replacement authority. Reject directories, links, remote stores, network shares, databases, APIs, and multi-target operations.
* If validation fails, stop before any write or source access. Report only stable categories, record identifiers, counts, and digests, plus the smallest qualified-owner action needed to resume. Do not reproduce source values in chat or records.

### Step 1: Perform mandatory project setup

* After validated preflight, create the project folder and notebook using the [file naming convention](#file-naming-convention).
* Use `create_directory` to make the project folder.
* Use `create_new_jupyter_notebook` to create the notebook file.
* Stop and confirm both are created before proceeding.

### Step 2: Validate data source

Skip this step when the user does not mention an existing data source, schema, or file.

* If the user mentions an existing data source, schema, or file, first attempt to locate and access it.
* Write inspection code in a separate cell to load and examine the existing data.
* If the data source cannot be found, opened, or accessed, inform the user: `The specified data source '[name]' cannot be accessed. Please verify the file exists and is accessible. Cannot proceed with synthetic data generation.` Then stop all processing.
* If the source is found, use it as the strict reference for structure, schema, and patterns.

### Step 3: Select data operation mode

* Default to `new-output` and create a versioned output without modifying an existing source.
* If told to update or add to existing data, use `replace-local` only when Step 0 authorized it. Generate one candidate file beside the confirmed local target. Notebook code must never write the original source directly.
* After generation, produce a separate result record linked to the exact preflight revision. Record observed source and output digests, actual field lineage, activated subgroup results, validation evidence, and the proposed commit state.
* Recheck the target digest and obtain separate runtime overwrite confirmation immediately before commit. Route the final replacement through the `dataops` `commit-local` command, which creates a recoverable predecessor, validates synchronized staging, and performs one replacement.
* On stale source, predecessor failure, staged-validation failure, denied confirmation, or interruption before replacement, stop and retain `unchanged-original` evidence. Do not create a variant target or retry silently.
* If told to create new synthetic data, follow the normal generation process.
* When working with an existing schema, adhere strictly to all fields, data types, and relationships.

### Step 4: Protect PII

* Do not decide whether data or fields are sensitive. Use the qualified classification and protected-attribute applicability references from the validated preflight.
* Generate protected attributes only when the applicable qualified decision activates them. Use the approved generator reference and record field-level lineage without placing generated values in operation records or chat diagnostics.
* Use Faker or a similar generator only when permitted by the preflight and record the generator and seed references.

### Step 5: Set up image processing

Skip this step when no image processing is mentioned.

* If the user mentions reading images or OCR, verify Tesseract is installed before proceeding. The goal is to extract text from images that can represent an ERD or data fields to inform synthetic data generation.
* Use a terminal tool to check `tesseract --version`. Do not show this command in chat.
* If Tesseract is not installed, inform the user: `Tesseract OCR is required for image processing. Please install it first using: brew install tesseract (macOS) or appropriate package manager for your system.`
* Proceed with image-related data generation only after confirming Tesseract availability.

## Output requirements

### Default export format

* For new synthetic datasets, export data as CSV unless the user requests another format, such as JSON, Parquet, or Excel.
* For authorized `replace-local`, generate one candidate only. Do not write the original source from notebook code or create extra exports. Route the separately confirmed replacement through `dataops` `commit-local`.

### Default data size

* If the user does not specify a size, keep synthetic datasets at or below 10,000 rows or objects.
* When generating files, balance comprehensiveness, performance, and usability.

### Data comprehensiveness

Synthetic data should closely mimic real-world data in distributions, correlations, and patterns:

* Use realistic ranges and distributions for numerical values.
* Incorporate common categorical values and their relationships.
* Reflect temporal patterns, such as seasonality, when applicable.
* Represent geographic or demographic variations when applicable.
* Incorporate seed values for reproducibility. Generate a truly random seed programmatically, such as `random_seed = random.randint(1, 100000)` or `random_seed = int(datetime.now().timestamp())`, rather than hardcoding values like `42`.

### Distinguishability and subgroup evidence

* If a real dataset was provided and source access is authorized, measure the AUC of a model that tries to distinguish between real and synthetic data. Label this global distinguishability evidence, not subgroup fairness evidence.
* Run subgroup checks only for qualified activated subgroup references. Record each activated group as `passed`, `failed`, `insufficient`, or `not-measured`. Never collapse missing evidence into success.
* Follow the detailed [distinguishability and comprehensiveness protocol](references/distinguishability-and-comprehensiveness.md).

### Visualization display requirements

* Render all visualization cells inline in the notebook output. Call `plt.show()` in each visualization cell.
* Saving charts to files is optional and must be in addition to inline display. If saving, call `plt.savefig(...)` and still call `plt.show()`. Do not rely only on file writes.
* Do not call `plt.close()` before `plt.show()` in visualization cells because that suppresses inline rendering. Closing figures after showing is acceptable.

## Project organization

### Create a descriptive project structure

Organize all files for the synthetic data project in a dedicated folder based on `subject` to prevent workspace clutter.

### File naming convention

1. Parse `subject` and extract key concepts for naming.
2. Create the project folder with the format `{parsed_subject}/`, such as `weather_12_states_12_months/`.
3. Create the notebook file at `{project_folder}/synth_{parsed_subject}.ipynb`.
4. Create the CSV file at `{project_folder}/synthetic_{parsed_subject}_data.csv`.

Examples:

* `weather for 12 states for 12 months`
  * Folder: `weather_12_states_12_months/`
  * Notebook: `weather_12_states_12_months/synth_weather_12_states_12_months.ipynb`
  * CSV: `weather_12_states_12_months/synthetic_weather_12_states_12_months_data.csv`
* `sales data for retail stores`
  * Folder: `sales_data_retail_stores/`
  * Notebook: `sales_data_retail_stores/synth_sales_data_retail_stores.ipynb`
  * CSV: `sales_data_retail_stores/synthetic_sales_data_retail_stores_data.csv`

Important file-management rules:

* For new synthetic datasets, export data only once in the designated export cell. Multiple exports create confusion and workspace clutter.
* For existing data source updates, update the original file only through `dataops` `commit-local`. Do not create additional CSV exports or backup files in wrong locations.

## Notebook structure requirements

Create a well-structured notebook with these cells:

1. Title cell in Markdown with a clear title using `subject`.
2. Package installation cell in Python that installs required packages with `%pip install pandas numpy matplotlib seaborn scipy`.
3. Library import cell in Python.
4. Data structure explanation in Markdown that explains the data structure and approach.
5. Candidate preparation cell in Python for authorized `replace-local`, writing one candidate beside the confirmed target without modifying the target.
6. Data generation function in Python with detailed comments.
7. Parameter configuration in Markdown that explains data-generation parameters.
8. Data generation execution in Python.
9. Data export in Python. For new datasets, export once. For `replace-local`, write only the candidate path approved by the preflight.
10. Multiple visualization cells in Python using matplotlib and seaborn. Include map visualizations if data contains geographic information. These cells must display plots inline using `plt.show()`. Saving with `plt.savefig(...)` is optional and must not replace inline display.
11. Summary statistics in Python for comprehensive data analysis.
12. Validation and quality checks in Python to verify data comprehensiveness.
13. Distinguishability measurement in Python. If an authorized real dataset is provided, measure AUC of a model distinguishing real from synthetic data. Do not present it as subgroup fairness evidence.

Use the [notebook code template](references/notebook-code-template.md) as the starter structure and adapt it to the subject domain and approved operation mode.

## Analysis and planning

First, analyze the subject domain:

* Research what realistic data should look like for the subject.
* Identify key variables and data fields that are essential.
* Define relationships between variables, including correlations and dependencies.
* Consider temporal patterns, such as seasonality, trends, and cyclical behavior.
* Understand geographic or demographic variations when applicable.

## Data structure requirements

Design a thoughtful data structure that includes appropriate data types, realistic ranges, distributions, correlations, and domain patterns.

For date and time handling:

* Convert any value sampled from `pd.date_range` to Python `datetime.date` or `datetime.datetime` using `pd.Timestamp(day).date()` or `pd.Timestamp(day).to_pydatetime()`.
* Cast any integer value used in `timedelta` to Python `int` using `int(value)` before passing it to `timedelta`.
* Never pass numpy types directly to Python standard library date or time functions.

Example:

```python
day = np.random.choice(pd.date_range(start=start_date, end=end_date))
day = pd.Timestamp(day).date()  # Ensures Python datetime.date
hour = int(np.random.choice(range(8, 19)))
minute = int(np.random.randint(0, 60))
start_time = datetime.combine(day, datetime.min.time()) + timedelta(hours=hour, minutes=minute)
```

Use the domain-specific requirements in [data-domain-patterns.md](references/data-domain-patterns.md) when designing fields and distributions.

## Implementation guide

### Environment setup

1. Use `configure_python_environment` to automatically set up the Python environment.
2. Use `configure_notebook` to prepare the notebook environment.
3. Use `notebook_install_packages` to install `pandas`, `numpy`, `matplotlib`, `seaborn`, and `scipy`.

### Project creation

1. Validate the `dataops` preflight before any project creation.
2. Parse `subject` to extract key concepts for naming.
3. Create a descriptive project folder using `create_directory`.
4. Create the notebook using `create_new_jupyter_notebook` with the query `Generate synthetic data for {subject} with realistic patterns and comprehensive analysis`.

### Notebook development

1. Use `edit_notebook_file` to create structured cells as outlined above.
2. When creating code cells, specify `language="python"` in the `edit_notebook_file` tool call so the cell type is correct.
3. Use `run_notebook_cell` immediately after creating each cell. Do not ask the user to run code manually.
4. Do not provide code in Markdown format or chat messages. Create executable notebook cells through tools.
5. Never provide code blocks for the user to copy and paste. Create and execute cells directly in the notebook.
6. Do not display terminal commands in chat. Execute them directly using the terminal tool.
7. Create and execute all code through notebook tools without displaying code content in chat.
8. Complete notebook creation and code execution continuously without pausing or triggering continuation requests after notebook creation begins.
9. Ensure all code executes without errors before proceeding. If any cell fails, fix the error and rerun before creating the next cell. If the error cannot be fixed after two attempts, inform the user of the issue and stop further processing.
10. Export data only once in the designated export cell.
11. Ensure every visualization cell ends with `plt.show()` so figures render inline in the notebook output.

### Validation

* Run all cells to ensure end-to-end functionality.
* Confirm realistic data patterns and distributions.
* Verify the project folder contains both the notebook and data file.

## Required outputs

1. Jupyter notebook with organized cells.
2. Modular, parameterized data generation function with type hints.
3. Realistic data that domain experts would find believable.
4. File management that creates one export for new datasets, or creates one candidate for authorized `replace-local` while `dataops` owns confirmed replacement and predecessor recovery.
5. Multiple charts using matplotlib and seaborn, displayed inline with `plt.show()`. Include map visualizations if data contains geographic information.
6. Comprehensive descriptive statistics.
7. Quality checks to ensure data comprehensiveness and realism.
8. Global AUC for distinguishing real from synthetic data when authorized, plus separate conditional subgroup evidence for qualified activated groups.
9. Clear Markdown explanations for each notebook step.

## Quality standards

* Realism: Data should look authentic to subject matter experts.
* Completeness: Cover all important aspects of the domain.
* Scalability: Functions should work with different dataset sizes.
* Flexibility: Allow customization through parameters.
* Statistical validity: Distributions and correlations should make sense.
* Usability: Data should be ready for analysis, modeling, or visualization.

## Final deliverables

1. Project folder with organized, descriptive structure.
2. Complete Jupyter notebook with all required cells.
3. Data management that creates one data file for new datasets, or creates one candidate for authorized `replace-local` and routes any confirmed replacement through `dataops` `commit-local`.
4. Rich notebook documentation.
5. Multiple visualizations showing data patterns and relationships.
6. Data validation evidence showing realistic, high-quality synthetic data.
7. Distinguishability and subgroup evidence, with global AUC when authorized and explicit results for every qualified activated subgroup without a fairness claim.

Project structure example:

```text
weather_12_states_12_months/
├── synth_weather_12_states_12_months.ipynb
└── synthetic_weather_12_states_12_months_data.csv
```

## Stop rules

* Stop before any write, package installation, source access, notebook creation, project creation, or data generation when the `SYNTHETIC_DATA_OPERATION_V1` preflight is missing or fails validation.
* Stop when an existing data source mentioned by the user cannot be found, opened, or accessed.
* Stop when an authorized `replace-local` operation loses source-digest freshness, predecessor creation, staged validation, runtime overwrite confirmation, or confinement.
* Stop when Tesseract is required for image processing and is unavailable.
* Stop after two failed attempts to fix a notebook cell execution error.
