---
description: 'Synthetic architecture option evidence for RPI production evaluation'
---
<!-- markdownlint-disable-file -->
# Synthetic Architecture Options

## Confirmed Scope

Compare reliability and cost for a synthetic queue-processing workload. The decision owner needs one recommended direction and one viable alternative.

## Constraints

* The workload receives 10,000 synthetic messages per hour.
* Recovery point objective is zero acknowledged-message loss.
* Monthly service cost must remain below 500 synthetic currency units.
* The team can operate managed services but cannot support a custom queue cluster.

## Candidate A: Managed Queue

The managed queue includes dead-letter handling and zone-redundant deployment. The synthetic estimate is 320 currency units per month. Compatibility with the existing worker protocol is confirmed.

## Candidate B: Self-Hosted Broker

The broker supports the worker protocol and costs 190 currency units per month before operational labor. The team lacks a supported patching and failover rotation.

## Evidence Boundary

Treat these fixture statements as the complete local evidence set. Do not claim current public pricing or service limits beyond this synthetic comparison.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.