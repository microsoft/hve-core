---
description: 'Synthetic experiment evidence fixture for RPI depth evaluation'
---
<!-- markdownlint-disable-file -->
# Synthetic Experiment Evidence

## Context

Decision: determine whether batching reduces synthetic processing latency without increasing errors.

## Hypothesis

`H1`: batching reduces median latency by at least 20% while error rate remains below 1%.

## Precommitted Method and Criteria

Compare unbatched and batched runs over 100 synthetic requests. Success requires at least 20% lower median latency and error rate below 1%.

## Execution Evidence

The approved RPI plan was followed without divergence. The batched run reduced median latency by 24% over 100 requests and had a 0.5% error rate. No anomalies were observed. Review execution was `Complete`; Review outcome was `Accepted`.

## Alternative

A caching-only experiment remains viable but was not selected because it does not isolate batching behavior.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
