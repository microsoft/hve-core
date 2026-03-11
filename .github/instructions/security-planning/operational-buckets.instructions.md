---
description: "Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/security-plans/**'
---

# Operational Security Buckets

Application components classify into operational security domains. Each component maps to exactly one bucket based on its primary function. Cross-cutting concerns receive separate treatment through the General Security (GS) overlay.

Seven buckets apply to all security plans. The eighth bucket (ai-ml) applies only when `raiEnabled` is true in the security plan state.

Use these bucket definitions during Phase 1 (project scoping and component identification) and Phase 2 (detailed bucket-by-bucket security analysis).

## Bucket Definitions

### infra

Infrastructure encompasses servers, virtual machines, containers, networking, DNS, load balancers, firewalls, and CDNs. These components form the foundational compute and network layer.

Security-relevant characteristics:

* Direct exposure to network traffic
* Shared responsibility boundaries between cloud provider and tenant
* Configuration drift risk across environments

Common threat categories: unauthorized network access, misconfigured cloud resources, unpatched operating systems, lateral movement between segments.

Controls that commonly apply: network segmentation policies, patch management schedules, host-based intrusion detection, least-privilege network ACLs.

Classification example: A virtual network peering configuration belongs to infra. A Kubernetes cluster running workloads classifies as devops/platform-ops, not infra, because its primary function is orchestration.

### devops/platform-ops

DevOps and Platform Operations covers CI/CD pipelines, deployment automation, container orchestration, infrastructure-as-code, and monitoring systems. These components manage how software reaches production.

Security-relevant characteristics:

* Privileged access to production environments
* Automated execution of code and configuration changes
* Supply chain dependencies on third-party actions and images

Common threat categories: pipeline poisoning, secret exfiltration through build logs, compromised deployment credentials, unauthorized infrastructure changes.

Controls that commonly apply: pipeline access controls, secret rotation policies, signed commits and artifacts, deployment approval gates, audit logging for platform changes.

Classification example: A GitHub Actions workflow that deploys to Azure belongs to devops/platform-ops. The Azure resources it provisions classify under their respective buckets (infra for VMs, data for databases).

### build

Build Systems include compilation toolchains, packaging, artifact registries, dependency managers, and build caches. These components transform source code into deployable artifacts.

Security-relevant characteristics:

* Direct consumption of external dependencies
* Artifact integrity as a trust anchor for downstream stages
* Cache poisoning potential

Common threat categories: dependency confusion attacks, compromised build tools, unsigned artifacts, reproducibility failures, malicious packages.

Controls that commonly apply: dependency pinning with verified hashes, artifact signing, reproducible build verification, isolated build environments, vulnerability scanning of dependencies.

Classification example: An npm registry mirror storing internal packages belongs to build. The CI pipeline that runs `npm install` classifies as devops/platform-ops because its primary role is deployment automation.

### messaging

Messaging and Events covers message queues, event buses, webhooks, pub/sub systems, and streaming platforms. These components transport data between services asynchronously.

Security-relevant characteristics:

* Asynchronous processing creates timing-sensitive security boundaries
* Message payloads may contain sensitive data in transit
* Fan-out patterns amplify the impact of a single compromised message

Common threat categories: message replay attacks, unauthorized subscription, payload tampering, denial-of-service through queue flooding, unencrypted message contents.

Controls that commonly apply: message signing and verification, transport encryption, consumer authentication, replay detection (idempotency keys), dead-letter queue monitoring.

Classification example: An Azure Service Bus namespace belongs to messaging. An API endpoint that publishes events to the bus classifies as web/UI/reporting because it primarily serves HTTP traffic.

### data

Data includes databases, data warehouses, blob storage, caches, data lakes, and ETL pipelines. These components persist, transform, and retrieve information.

Security-relevant characteristics:

* Long-term storage of sensitive and regulated information
* Complex access patterns spanning multiple consumers
* Backup and retention requirements driven by compliance

Common threat categories: SQL injection, unauthorized data access, unencrypted storage, excessive data retention, backup exfiltration, privilege escalation through database accounts.

Controls that commonly apply: encryption at rest and in transit, row-level or column-level access controls, data classification tagging, retention policies, backup encryption, audit logging for data access.

Classification example: A PostgreSQL database storing user profiles belongs to data. A Redis instance used for caching API responses also classifies as data. Redis used solely as a message broker classifies as messaging.

### web/UI/reporting

Web, UI, and Reporting covers web applications, single-page applications, APIs, dashboards, report generators, and portals. These components present information to users and accept input.

Security-relevant characteristics:

* Direct exposure to end users and external traffic
* Input validation as the first line of defense
* Session management and authentication flow integration

Common threat categories: cross-site scripting (XSS), cross-site request forgery (CSRF), broken authentication, insecure direct object references, server-side request forgery, API abuse.

Controls that commonly apply: input validation and output encoding, Content Security Policy headers, CSRF tokens, rate limiting, authentication and authorization middleware, API schema validation.

Classification example: A React dashboard consuming a REST API belongs to web/UI/reporting. The REST API itself also classifies here because it primarily serves HTTP responses. An API gateway classifies here with a secondary concern in identity/auth.

### identity/auth

Identity and Authentication encompasses identity providers, SSO integrations, MFA services, token services, RBAC/ABAC engines, and directory services. These components manage who can access what.

Security-relevant characteristics:

* Central trust anchor for the entire application
* Credential storage and transmission sensitivity
* Federation complexity across organizational boundaries

Common threat categories: credential stuffing, session hijacking, token theft, privilege escalation, federation misconfiguration, insecure password storage.

Controls that commonly apply: MFA enforcement, token expiration and rotation, least-privilege role definitions, session management policies, credential storage using approved vaults, federation trust validation.

Classification example: An Azure AD B2C tenant belongs to identity/auth. An OAuth middleware library embedded in a web API classifies under web/UI/reporting because the API is its primary context; the identity concern becomes a GS mapping.

### ai-ml

> [!NOTE]
> This bucket applies only when `raiEnabled` is true in the security plan state.

AI and ML Systems covers model training, inference, retrieval-augmented generation, and agent orchestration. These components introduce unique attack surfaces around data poisoning, prompt injection, and model extraction.

| Component Category  | Description                                                                                             |
|---------------------|---------------------------------------------------------------------------------------------------------|
| Model Pipelines     | Training data ingestion, feature engineering, model training, validation, and deployment pipelines      |
| Inference Endpoints | Real-time and batch prediction APIs, model serving infrastructure                                       |
| RAG Systems         | Retrieval-augmented generation stacks including vector stores, embedding pipelines, document processors |
| Embedding Stores    | Vector databases and similarity search infrastructure                                                   |
| Agent Tool Access   | LLM agent frameworks with tool/function calling, plugin systems                                         |
| Content Safety      | Input/output guardrails, content filtering, prompt injection defenses                                   |
| Model Registry      | Model versioning, artifact storage, provenance tracking                                                 |
| Training Data       | Dataset management, labeling pipelines, data lineage                                                    |

Security-relevant characteristics:

* Adversarial inputs can degrade model behavior without traditional exploit indicators
* Model artifacts encode sensitive training data, creating extraction and memorization risks
* Agent tool access introduces privilege escalation vectors through prompt manipulation
* Supply chain for models includes weights, datasets, and fine-tuning scripts that lack standard signing mechanisms

Common threat categories: prompt injection, training data poisoning, model extraction, adversarial evasion, excessive agency in agentic systems, output hallucination, data leakage through memorization, model denial of service.

Controls that commonly apply: input validation and content filtering, model provenance tracking (ML-BOM), human-in-the-loop for high-risk decisions, output guardrails, rate limiting on inference endpoints, access controls on model artifacts, adversarial testing and red-teaming.

Classification example: A fine-tuned LLM deployed behind a REST API belongs to ai-ml. The REST API gateway itself classifies as web/UI/reporting; the model and its serving infrastructure classify as ai-ml. A vector database used exclusively for RAG retrieval classifies as ai-ml, not data, because its primary function is supporting model inference.

## Cross-Cutting Concerns: General Security

General Security (GS) is not a bucket. It is an overlay that applies across all operational domains. GS concerns generate their own backlog work items, tagged with the relevant bucket or buckets.

GS topics include:

* Logging and monitoring: centralized log aggregation, alerting, SIEM integration
* Incident response: runbooks, escalation paths, communication plans
* Compliance requirements: regulatory frameworks, audit schedules, evidence collection
* Security governance: policy ownership, exception processes, review cadences
* Key management: encryption key rotation, key hierarchy, access to key vaults
* Certificate lifecycle: issuance, renewal, revocation, monitoring for expiry
* Container security: image scanning and provenance, runtime security policies (seccomp, AppArmor), registry access controls, supply chain attestation (SLSA, S2C2F)
* API security: authentication and authorization patterns, rate limiting and abuse prevention, input validation and schema enforcement, API gateway security configuration

When `raiEnabled` is true, the following AI-specific cross-cutting concerns also apply:

* Supply chain integrity: model provenance, training data poisoning, weight and dataset signing
* Prompt injection and jailbreak resistance: direct and indirect injection vectors across all LLM-consuming components
* Model extraction and inversion attacks: query-based reconstruction of model weights or training data
* Output hallucination and unsafe content generation: factual accuracy, harmful content, and ungrounded outputs
* Data leakage through model memorization: sensitive training data recoverable through crafted prompts
* Bias and fairness in model outputs: disparate impact across demographic groups, stereotyped associations

Apply GS after completing bucket-by-bucket analysis. For each GS topic, determine which buckets it affects and document the mapping. A single GS concern often spans multiple buckets: key management touches data (encryption at rest), messaging (transport encryption), and identity/auth (token signing). Container security spans infra and devops/platform-ops. API security spans web/UI/reporting and identity/auth.

GS items produce distinct backlog entries rather than being embedded within bucket-specific work items. Each GS work item references the buckets it supports.

## Classification Guidance

When a component's bucket assignment is ambiguous, follow these questions in order. The first matching question determines the bucket.

1. Does the component primarily handle user authentication or authorization? Assign to identity/auth.
2. Does the component primarily serve web content or APIs to users? Assign to web/UI/reporting.
3. Does the component primarily store or process persistent data? Assign to data.
4. Does the component primarily transport messages between systems? Assign to messaging.
5. Does the component primarily manage build, compilation, or artifact packaging? Assign to build.
6. Does the component primarily manage deployment or platform operations? Assign to devops/platform-ops.
7. Does the component primarily involve AI/ML model training, inference, or related pipelines? Assign to ai-ml. This question applies only when `raiEnabled` is true.
8. No prior question matched. Assign to infra as the default.

Multi-concern components classify by primary function. Note secondary concerns in the component record for GS mapping during the cross-cutting analysis phase.

Tricky classification examples:

* API Gateway: primary function is serving API traffic (web/UI/reporting), secondary concern in identity/auth for request authentication
* Kubernetes: primary function is workload orchestration (devops/platform-ops), secondary concern in infra for underlying compute
* Redis: primary function determines classification. Caching data responses places it in data. Serving as a message broker places it in messaging.
* Terraform modules: primary function is infrastructure provisioning (devops/platform-ops), secondary concern in infra for the resources they create

## Bucket Analysis Template

For each identified bucket, produce a structured analysis using this format:

```markdown
### {bucket-name}

Components:

* {component-name} ({technology})
* {component-name} ({technology})

Data flows:

* Inbound: {description of data entering this bucket}
* Outbound: {description of data leaving this bucket}

Integration points:

* Connects to {other-bucket} via {mechanism}
* Connects to {other-bucket} via {mechanism}

Existing security controls:

* {control description} (present in capture mode, omit in greenfield)

Identified gaps:

* {preliminary gap, refined during standards mapping in Phase 3}
```

Populate the components list with specific technology names discovered during scoping. Data flow descriptions capture what information enters and exits the bucket. Integration points identify which other buckets connect and through what mechanism. Existing controls appear only when analyzing a running system (capture mode). Gaps remain preliminary until standards mapping refines them.
