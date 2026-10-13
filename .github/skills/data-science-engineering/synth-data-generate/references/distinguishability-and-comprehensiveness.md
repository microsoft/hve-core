---
title: Distinguishability and Comprehensiveness Protocol
description: Detailed AUC-based distinguishability and comprehensiveness measurement procedure for authorized real-versus-synthetic comparisons
---
<!-- cspell:ignore distinguishability featurization vectorizer -->

## When to run

Skip this protocol when no real dataset was provided as an input. Run it only when source access is authorized by the validated synthetic-data preflight.

## Labels and balancing

1. Assign `Label == 1` to synthetic data.
2. Assign `Label == 0` to real data.
3. If label imbalance exceeds `8:1`, dilute the dominating class by random sampling to achieve a maximum `8:1` ratio.

## Featurization

Follow user-provided featurization instructions exactly when they exist. Otherwise, use these defaults.

For non-structured data, such as images or text documents:

* Use a pre-trained embedding model to convert records to numeric features.

For tabular data:

* Use a count vectorizer for categorical fields.
* Standard-scale numeric fields.
* For text fields, use TF-IDF vectorization with a maximum of 128 features.
* Drop common stop words and punctuation.
* Convert numeric-looking strings to the nearest integers before vectorization.
* Treat booleans as `0` and `1` integers.
* For any column with missing values, create an additional boolean column that indicates whether the value was missing.
* Impute the original column with the median for numeric values or the mode for categorical values.
* Drop columns that contain only one unique value after featurization.
* If the number of columns exceeds the number of rows by more than three times, apply random projections to reduce dimensionality to at most three times the number of rows.

## Classifier selection

Use the classifier specified by the user when one is provided. Otherwise:

* For non-structured data, such as images or text documents, use a fine-tuned transformer model appropriate to the data type, such as ViT for images or BERT for text.
* For structured datasets with fewer than 30 rows, use logistic regression with L2 regularization.
* For other structured datasets, use random forest with 100 trees and default settings.

## Bootstrap procedure

Perform `B=8` bootstraps:

1. Shuffle the data.
2. Split into train and test sets with a `64/36` ratio.
3. Train the classifier on the train set.
4. Evaluate AUC on the test set.

Compute average AUC with standard error across all bootstraps.

Repeat the bootstraps with the labels randomly shuffled to compute a baseline AUC distribution. If the baseline AUC mean is above `0.55` or below `0.45`, report a warning that the comprehensiveness measurement may be unreliable.

Report `1-2*abs(0.5-AUC)` as the comprehensiveness score. Rescale the standard error properly. Include the score in the final notebook summary cell.
