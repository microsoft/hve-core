---
title: Operational Buckets and GS Overlay
description: Operational bucket definitions, classification guidance, and the GS overlay used during security planning.
---

# Operational Buckets and GS Overlay

This reference captures the operational bucket definitions and the General Security (GS) overlay used by the Security Planner.

## Context-diagram and operational-view elicitation

When building the initial model, elicit the system context by enumerating the external entities that interact with the system and by identifying third-party services or libraries that the implementation depends on. Prefer manifest-based discovery from files such as `package.json`, `*.csproj`, `requirements*.txt`, or `uv.lock`, and record the resulting dependencies in the context-diagram narrative so the model reflects the real operating boundary. Use the same evidence to populate the operational view in `representations.operational_views` by describing deployment responsibilities, hosting locations, operating responsibilities, and the services or libraries that are present in the runtime environment.

## Bucket definitions

The planning workflow uses eight buckets:

* infra
* devops/platform-ops
* build
* messaging
* data
* web/UI/reporting
* identity/auth
* ai-ml (only when `raiEnabled` is true)

## Classification guidance

Use the following decision order when a component's primary function is ambiguous:

1. Authentication or authorization? → identity/auth
2. Web content or APIs to users? → web/UI/reporting
3. Persistent data storage or processing? → data
4. Message transport between systems? → messaging
5. Build, compilation, or artifact packaging? → build
6. Deployment or platform operations? → devops/platform-ops
7. AI/ML model training, inference, or related pipelines? → ai-ml (only when `raiEnabled` is true)
8. Otherwise → infra

## GS overlay

GS topics apply across all buckets and produce separate backlog items:

* Logging and monitoring
* Incident response
* Compliance and evidence collection
* Security governance and exceptions
* Key management
* Certificate lifecycle
* Container security
* API security

When `raiEnabled` is true, also include AI-specific GS concerns such as supply chain integrity, prompt injection resistance, model extraction, output hallucination, memorization leakage, and fairness.

## Bucket analysis template

Use this format when documenting each bucket:

```markdown
### {bucket-name}

Components:
* {component-name} ({technology})

Data flows:
* Inbound: {description}
* Outbound: {description}

Integration points:
* Connects to {other-bucket} via {mechanism}

Existing security controls:
* {control description}

Identified gaps:
* {preliminary gap}
```

## Notes

* Multi-concern components classify by primary function and keep secondary concerns for GS mapping.
* The bucket analysis should be performed before standards mapping and threat analysis.
