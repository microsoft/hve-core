---
title: Arch Diagram Builder
description: Agent that generates ASCII architecture diagrams by analyzing infrastructure-as-code and project structure
sidebar_position: 4
author: Microsoft
ms.date: 2026-03-07
ms.topic: tutorial
---

The Arch Diagram Builder analyzes infrastructure-as-code files and project structure to generate ASCII architecture diagrams. It reads Terraform, Bicep, Kubernetes manifests, and Docker configurations to identify components, dependencies, and data flows, then renders them as text-based diagrams directly in conversation.

> [!NOTE]
> This agent was missing from the Agent Systems Catalog and is added as part of this documentation effort. It has no persistence and produces output entirely in-conversation.

## Workflow

The agent follows a 4-stage analysis process:

### Stage 1: Discovery

The agent scans the repository structure, identifying infrastructure-as-code files, configuration files, and deployment manifests. It examines Terraform modules, Bicep templates, ARM templates, Kubernetes YAML, Docker Compose files, and shell scripts to build an inventory of infrastructure components.

### Stage 2: Parsing

From the scanned files, the agent identifies services, databases, networking components, external dependencies, and their relationships. It maps resource definitions to logical components and tracks references between them.

### Stage 3: Relationship Mapping

The agent determines diagram layout based on component relationships and data flow direction. It applies layout conventions: external-facing services at the top, compute in the middle, and data stores at the bottom.

### Stage 4: Generation

The agent produces the final text-based diagram using structured conventions:

* `---->` for data flow connections
* `<--->` for bidirectional communication
* `- - >` for optional or conditional paths
* `+-----+` boxes with `:` labeled boundaries for component grouping

## Key Characteristics

| Characteristic | Detail                                       |
|----------------|----------------------------------------------|
| Persistence    | None (output is in-conversation only)        |
| Template       | None (generates directly from code analysis) |
| Output format  | ASCII text diagrams                          |
| Input sources  | Terraform, Bicep, ARM, Kubernetes, Docker    |
| Diagram title  | `<Solution Name> Architecture`               |

Unlike other project planning agents, the Arch Diagram Builder does not save files or maintain session state. Each invocation produces a fresh diagram based on current code analysis.

## Example Output

```text
+---------------------------+
:     External Services     :
:  +-------+   +--------+  :
:  | API GW |-->| CDN    |  :
:  +-------+   +--------+  :
+---------------------------+
       |
       v
+---------------------------+
:     Compute Layer         :
:  +--------+  +--------+  :
:  | App Svc|  | Func   |  :
:  +--------+  +--------+  :
+---------------------------+
       |
       v
+---------------------------+
:     Data Layer            :
:  +--------+  +--------+  :
:  | SQL DB |  | Blob   |  :
:  +--------+  +--------+  :
+---------------------------+
```

## How to Use

> [!TIP]
> Select the agent using the agent picker in the Copilot Chat pane before entering a prompt.

### Option 1: Prompt Shortcut

```text
Generate an architecture diagram for this project. Scan the Terraform
modules in infra/modules/ and the Kubernetes manifests in k8s/.
Show:
- External-facing services at the top (API Gateway, CDN, Load Balancer)
- Compute layer in the middle (AKS pods, Azure Functions)
- Data layer at the bottom (Azure SQL, Blob Storage, Redis Cache)
- Network boundaries between public, DMZ, and private subnets
Use the standard ASCII box notation with labeled boundaries.
```

```text
Create a data flow diagram showing how a customer order traverses the
system. Start from the React frontend in src/web/, trace through the
API gateway, order-service, inventory-service, and payment-service.
Show:
- Synchronous request/response paths with solid arrows
- Async message queue paths with dashed arrows
- Data stores each service writes to
- External third-party integrations (Stripe, SendGrid)
Group services by their Kubernetes namespace from k8s/namespaces/.
```

### Option 2: Direct Agent

Select the Arch Diagram Builder using the agent picker in the Copilot Chat pane, then describe the architecture to visualize:

```text
Map the networking topology from the Bicep
templates in infra/bicep/. Show the VNet structure, subnet allocation,
NSG rules between subnets, and how traffic flows from Azure Front Door
through the Application Gateway to the AKS cluster.
Include:
- Public and private endpoint boundaries
- DNS resolution paths
- Service endpoints vs private endpoints for PaaS services
Output as a layered ASCII diagram with the internet at the top.
```

The agent scans the repository and produces an ASCII diagram. For best results, invoke it in a workspace that contains infrastructure-as-code files.

### Option 3: Refine Output

Ask the agent to adjust a generated diagram in the same session:

```text
Refine the diagram to focus on the data layer only. Show replication
paths between the primary Azure SQL instance and read replicas across
regions. Include the failover group configuration and indicate which
services connect to the primary vs replica endpoints. Remove the
compute and networking layers from the output.
```

Since the agent has no session persistence, refinement must happen within the same conversation.

## Example Prompt

```text
Generate an architecture diagram for this project by analyzing the
Terraform modules in infra/modules/ and Docker Compose in docker/.
Focus on the networking layer and trace how traffic flows from the
public internet to backend services:
- Internet → Azure Front Door → Application Gateway (WAF)
- Application Gateway → AKS Ingress Controller → Service Mesh
- Service Mesh → Individual microservice pods
- Pods → Data stores (Azure SQL, CosmosDB, Redis)
Show:
- Network security boundaries using labeled box notation
- Bidirectional arrows for service mesh communication
- Dashed arrows for optional CDN cache paths
- Port numbers on each connection where defined in the IaC
Group components by their resource group from the Terraform state.
```

## Tips

* ✅ Run the agent in a workspace that contains Terraform, Bicep, ARM, Kubernetes, or Docker files
* ✅ Specify which layer or data flow to emphasize for focused diagrams
* ✅ Copy the ASCII output into ADRs or documentation as supporting material
* ✅ Re-run after infrastructure changes to keep diagrams current
* ❌ Do not expect rendered graphical output (the agent produces ASCII text only)
* ❌ Do not run in a repository without infrastructure files (the agent needs IaC to analyze)
* ❌ Do not combine multiple architecture scopes in a single diagram request
* ❌ Do not assume the diagram captures runtime behavior (it reflects static code analysis)

## Common Pitfalls

| Pitfall                            | Solution                                                                          |
|------------------------------------|-----------------------------------------------------------------------------------|
| Empty or minimal diagram           | Confirm the workspace contains Terraform, Bicep, ARM, Kubernetes, or Docker files |
| Missing components in output       | Specify the file paths or modules to include if the agent misses them             |
| Diagram too complex to read        | Scope the request to a single layer (networking, compute, or data)                |
| Outdated diagram after changes     | Re-run the agent; it analyzes current files with no caching                       |
| Layout does not match expectations | Ask the agent to regenerate with a specific flow direction or grouping            |

## Next Steps

1. Include the diagram in an [ADR](adr-creation.md) as supporting architecture context
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Copy the ASCII diagram into a fenced code block in your documentation. Monospaced rendering preserves the alignment and box characters.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
