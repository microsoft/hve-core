---
title: Synthetic Data Domain Patterns
description: Domain-specific structure, type, range, distribution, and relationship requirements for the synthetic data generator skill
---

## Data types and ranges

Design fields with data types and values that match the subject domain.

* Use appropriate data types: numeric, categorical, datetime, text, and boolean.
* Ensure all values fall within believable, realistic bounds.
* Include natural outliers and edge cases that would occur in real data.
* Consider data quality issues, including some missing values and slight inconsistencies.

## Realistic distributions

Use statistically plausible generation methods.

* Use appropriate statistical distributions for different variable types.
* Model correlations and dependencies between related variables.
* Include natural noise and variation patterns.
* Account for business rules or physical constraints.

## Business data

Include business-specific structures where applicable:

* Seasonal trends in sales, revenue, and customer behavior.
* Geographic and demographic variations.
* Market dynamics and competitive effects.
* Supply, demand, and inventory cycles.
* Customer lifecycle and behavior patterns.

## Scientific and technical data

Include scientific or technical structures where applicable:

* Measurement uncertainties and instrument precision.
* Physical laws and natural constraints.
* Environmental factors and their effects.
* Sampling frequencies and data collection patterns.
* Natural variations and experimental noise.

## Social and behavioral data

Include social or behavioral structures where applicable:

* Demographic distributions matching real populations.
* Cultural and regional variations.
* Social network effects and clustering.
* Temporal patterns, including time of day, day of week, and season.
* Behavioral preferences and decision patterns.
