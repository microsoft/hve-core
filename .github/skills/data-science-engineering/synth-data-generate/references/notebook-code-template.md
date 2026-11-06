---
title: Synthetic Data Notebook Code Template
description: Starter Python cell template for generated synthetic data notebooks
---
<!-- cspell:ignore figsize kwargs pyplot randn scipy timedelta xlabel ylabel -->

## Template

Adapt this template to the subject domain, approved operation mode, and schema constraints.

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
    Generate synthetic data for the requested subject with realistic patterns.

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

# Cell 5: Export Data - conditional based on operation type (Python)
# For new synthetic data:
if creating_new_dataset:
    subject = "<subject>"
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

# Cell 6-9: Multiple visualization cells (Python, always render inline)
# Create charts using matplotlib and seaborn. Always call plt.show().
# Optionally also save figures to files in the project folder.
plt.figure(figsize=(6, 4))
plt.plot(data.index[:100], np.random.randn(100).cumsum(), label="sample")
plt.title("Sample Visualization")
plt.xlabel("Index")
plt.ylabel("Value")
plt.legend()
plt.tight_layout()
# Optional file save in addition to inline display:
# plt.savefig(os.path.join(project_folder, "sample_plot.png"))
plt.show()

# Cell 10: Summary and Validation (Python)
print("=== DATA SUMMARY ===")
print(data.describe())
print(f"\\nGeneration timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
```
