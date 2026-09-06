---
description: "Azure organization capture: the collector-mandatory data path, the Grafana product and cost comparison, and the generated collector, infrastructure, and KQL dashboard templates"
---

# Azure capture: collect and chart a fleet's telemetry

## Intended Use

Read this when the user wants organization telemetry in Azure. It carries the data path and why a collector is not optional, the comparison between the free in-portal Grafana and Azure Managed Grafana with the cost of each, the ingestion cost that sits underneath both, and the contract for every generated template.

## A collector is mandatory

The intuitive picture, where Copilot points at Azure the way it points at a local container, does not work. Copilot's exporter sends a static set of headers configured once. Azure Monitor's OTLP ingestion requires Microsoft Entra credentials that rotate. A static header cannot satisfy a rotating credential, so something in between has to hold the identity.

```text
Copilot (VS Code)  ──OTLP──▶  OpenTelemetry Collector  ──▶  Application Insights  ──▶  Log Analytics  ──▶  Grafana
   static headers              holds the Entra identity        connection string           KQL              dashboards
```

Azure Monitor documents three OTLP ingestion mechanisms and all of them are collector-class. There is no supported direct path. Say this early: a user who has budgeted for "point the endpoint at Azure" needs to know they are also standing up and operating a collector.

The collector is also where the useful controls live: it is the only place to filter attributes before they reach billable storage, and the only place to authenticate a fleet without giving every workstation an Azure identity.

## The credential is the security decision

Whatever channel distributes the collector configuration puts a **shared write-side secret on every workstation**. There is no per-user binding and no documented in-place rotation.

The blast radius is write-side only, which is narrower than a data breach. It is not nothing:

* Anyone holding it can inject fabricated telemetry, so dashboards can be made to say whatever the holder wants.
* Anyone holding it can inflate ingestion volume, and ingestion is billed.
* Revoking it means re-distributing to the whole fleet, which is a fleet-wide operation rather than a per-user one.

Say this before generating anything. It is a decision an organization should make on purpose. Never write the ingestion key or connection string into a generated file, a repository, or the conversation; leave it as a named input the operator supplies at deploy time from a secret store.

## Which Grafana

Two products. Default to the free one.

**Azure Monitor dashboards with Grafana** delivers Grafana dashboards inside the Azure portal at no cost and with no configuration. Microsoft's own comparison states it should be your first choice when you only want to use Azure Monitor data, which is exactly this scenario. It is also the ARM- and Bicep-deployable option: dashboards are native Azure resources of type `Microsoft.Dashboard/dashboards`, and the portal can export an existing dashboard as an ARM template.

**Azure Managed Grafana** is a fully managed Grafana with its own web interface. Recommend it only when one of its triggers actually applies:

* External or open-source data sources beyond Azure Monitor, Azure Managed Prometheus, and Azure Resource Graph.
* Grafana alerting or email notification.
* Scheduled reports.
* Sharing dashboard access without sharing access to the underlying data store. The free option authenticates data sources as the current user only, so a viewer needs their own data access.
* Private networking, deterministic outbound IP, or Grafana Enterprise plugins.

The free option does not support alerts, reports, library panels, snapshots, playlists, or app plugins. Those absences are the honest reason to upgrade, not the price.

Never quote a price. Rates move, and a stale figure carried in a skill is worse than no figure. State the shape instead: the free option costs nothing, and Azure Managed Grafana bills a per-instance rate plus a per-active-user charge, so its cost scales with how many people get access. Send the user to the [Azure Managed Grafana pricing page](https://azure.microsoft.com/pricing/details/managed-grafana/) for the product and the [Azure Monitor pricing page](https://azure.microsoft.com/pricing/details/monitor/) for ingestion, and let them price it against their own region and tenant.

A user who starts free is not stuck. A saved dashboard can be copied into an Azure Managed Grafana instance later from the portal.

## Free Grafana does not mean free telemetry

State this next to the recommendation, every time. The Grafana surface is free; **the data underneath it is not**. Azure Monitor and Log Analytics bill on data ingested and retained, and that bill is driven by how much Copilot sends.

`captureContent` is the dominant multiplier. Turning it on puts prompt text, response text, system instructions, and tool arguments onto spans, which changes span size by orders of magnitude rather than percentages. For a fleet, that is the difference between a modest bill and a surprising one, and it is also the setting with the largest privacy consequence. Recommend `captureContent: false` with `lockCaptureContent: true` for organization capture, and let a team opt in deliberately if they have a reason.

Two other levers worth naming: filter attributes at the collector before they reach ingestion, and set retention deliberately rather than accepting the default.

## The Copilot Metrics API is a complement, not a substitute

Users asking for "org metrics" often mean the GitHub Copilot Metrics API. It returns signed links to daily aggregate report files. There are no spans, no per-tool counts, no token figures, and no latency. It answers "how much is the organization using Copilot" and cannot answer "which tools are slow" or "where are tokens going."

Both are useful and they are not interchangeable. If the user's actual question is seat-level adoption, the API is the cheaper answer and this whole pipeline is unnecessary.

## Generated templates

Everything under `examples/azure/` is a template to copy, adapt, and deploy. The agent writes them; the user runs them, under the execution boundary in `SKILL.md`.

| Artifact                                               | Produces                                                                                        |
|--------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| `otel-collector-config.yaml`                           | Collector pipeline exporting to Application Insights                                            |
| `main.bicep`                                           | Log Analytics workspace, Application Insights, and a `Microsoft.Dashboard/dashboards` dashboard |
| `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` | The same resources via the AzureRM and AzAPI providers                                          |
| `deploy.sh`                                            | The Azure CLI equivalent, for operators who do not want an IaC toolchain                        |

Every one of them requires values the agent must not invent. Ask for subscription, region, and naming before generating anything, per the stop rule in `SKILL.md`. Values the user cannot supply yet stay as named parameters with no default, and are named back to the user as outstanding:

* Subscription and tenant.
* Region, which must be consistent across the resource group and the dashboard.
* Resource naming, which usually follows an existing organizational convention.
* The environment this deployment serves. It has no default, because the templates are deployed once per environment.
* The RBAC principal that will hold `Monitoring Reader`, and `Monitoring Data Reader` when Prometheus data is involved.
* Retention, which is a cost decision rather than a default, and which is also the deletion boundary.
* The fleet ingest token and the TLS certificate and key paths for the collector, which come from the operator's secret store and are never generated here.

### Separation is deployment topology, not an attribute

The default is one collector endpoint, one ingest token, one Application Insights resource, and one Log Analytics workspace per environment.

A resource attribute such as `service.namespace` or `deployment.environment.name` is a grouping key. It lets a reader filter; it does not stop a reader removing the filter. Anyone holding `Monitoring Reader` on a workspace can read everything in that workspace. Never describe an attribute as an isolation control, and scope each reader assignment to a single workspace rather than to the resource group or subscription.

A shared workspace across environments is a legitimate cost trade-off, but say what it costs: every authorized reader gains fleet-wide visibility across all of them, and no attribute can take that back afterwards.

This is environment separation, not customer multi-tenancy. Copilot's exporter sends the same static headers from every workstation, so nothing in the payload identifies a tenant in a way worth trusting for isolation.

### The receiver is authenticated and encrypted by default

The generated collector requires an active bearer authenticator and TLS material, both supplied from the environment. Neither is present as a commented-out suggestion, because a control that must be uncommented is a control that will not be.

Be accurate about the token's limits when presenting it. Copilot sends a fixed header set, so a static shared token is the mechanism available: it authenticates the fleet rather than a person, cannot be rotated for one user, and is extractable from any workstation. It is still worth having, because the alternative is a receiver that accepts and bills spans from anything that can route to it.

Where an ingress controller or load balancer terminates TLS, the `tls` blocks are removed and the terminating hop owns certificate lifecycle and cipher policy. Record that ownership rather than leaving it implied.

One asymmetry to state plainly: this configuration governs the server. How Copilot's exporter validates the server certificate is the exporter's behavior, and nothing here changes it.

### Mandatory authentication silently drops agent-host telemetry

Raise this before an operator deploys, because it is a data-loss defect and its first symptom is an absence.

Managed `telemetry.headers` are applied to the extension exporter directly rather than through environment variables. That is deliberate and correct: an environment variable is inherited by the tool subprocesses the agent spawns, so delivering the ingest token that way would put a fleet-wide write credential inside every model-directed subprocess. The consequence is a split. The extension's telemetry authenticates; the agent host's telemetry does not, and a receiver that requires authentication rejects it.

A rejected OTLP export answers HTTP 401 or gRPC `UNAUTHENTICATED`. Neither is retryable under the OTLP specification, so the export is dropped rather than queued. Nothing is retried later and no partial data arrives. Whether VS Code surfaces the rejection to the developer is not established, so do not rely on someone reporting an error.

Two fixes suggest themselves and both make the deployment less safe. Do not offer either:

* **Putting the token in the environment** so the agent host inherits it. This is the exact path the extension-versus-agent-host split exists to prevent.
* **Removing authentication from the receiver** so the agent host is accepted. This reopens ingestion to anything that can route to the endpoint, on a billed backend.

#### The relay

The carrier that does not require either concession is a per-workstation Collector between the agent host and the fleet endpoint.

```text
agent host ──unauthenticated──▶ local relay ──authenticated, TLS──▶ fleet receiver
                (loopback)      (own config)
```

The agent host exports to `http://127.0.0.1:4318` with no credential, which it can already do. The relay holds the fleet credential in its own configuration and adds it on the upstream hop. The credential therefore lives in a file the relay reads, not in the environment VS Code hands to its children.

Two conditions decide whether that property actually holds. State both when offering this:

* The relay is launched **independently** of VS Code, as a service or a user daemon. A relay started from the same shell as VS Code, or as its child, may share the environment the split exists to keep clean.
* The relay's credential is stored where the relay reads it and the editor does not, meaning its configuration file or a secret store, not an exported variable.

The relay is the same Collector already used locally, so the fail-closed attribute allow-list applies to agent-host telemetry as well.

#### What the relay does not do

Be honest about what changed. The relay moves the exposure; it does not remove it.

Its listener is unauthenticated by construction, so **any local process that can reach loopback can inject telemetry into the fleet backend** through it, carrying genuine service names. Binding to `127.0.0.1` is necessary and not sufficient: it keeps the listener off the network but says nothing about which local process connected. The relay authenticates the *workstation's relay* to the fleet endpoint. It does not authenticate the workstation, and it does not authenticate the developer. Any span arriving through it is attributable to the fleet credential and no further.

The credential is also readable by whatever identity the relay runs as. That is a smaller blast radius than the environment of every agent-spawned subprocess, which is the point, but it is not zero.

Tracked as `G-INF-7`.

#### mTLS is preferred and not yet available

The better answer is mutual TLS, where each workstation presents a client certificate and the receiver verifies it.

The receiver half is settled. Supplying `tls.client_ca_file` alongside `cert_file` and `key_file` selects `RequireAndVerifyClientCert`, so the Collector rejects a connection with no client certificate or one signed by another authority, on both the gRPC and HTTP receivers:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /etc/otel/server.crt
          key_file: /etc/otel/server.key
          # Presence of this field is what makes a client certificate
          # mandatory rather than optional.
          client_ca_file: /etc/otel/clients-ca.crt
```

The sender half is not settled. No primary source establishes that the VS Code agent host can present a client certificate, or that it reads an operating-system certificate store for one. Until that is known, this is a Collector capability rather than a reachable deployment, and offering it as available would be the same unbacked-claim pattern this skill has been correcting.

The test that would settle it: stand up a receiver configured as above, point one workstation's agent host at it, and observe whether the handshake completes. A completed handshake settles it; a rejected one distinguishes "cannot present a certificate" from "presented the wrong certificate" in the Collector's own log.

#### Make the failure detectable

Do not let an operator infer success from an absence of errors. Verify positively that agent-host spans are arriving:

1. Note which span categories only the agent host emits, so their absence is diagnostic rather than ambiguous.
2. After a reload, query the backend for a span from that category within the last few minutes.
3. If none arrives while extension telemetry does, the split is present and the relay is missing or misconfigured.

The symptom to describe to an operator is a **whole category of spans missing while other telemetry looks healthy**, not an error in a log.

### Lifecycle ownership

Retention is the deletion policy. Data ages out at that boundary and not before, and the templates purge nothing on request. An erasure obligation for a named individual is an operator procedure run against the workspace; present it as owned work rather than implying the template handles it.

Terraform state for these files contains the Application Insights connection string, a fleet-wide write credential. `sensitive = true` keeps it out of CLI display, not out of state. Say so, and recommend an encrypted remote backend with restricted access.

Verify every API version and provider version against current documentation at generation time. Do not reuse a version because a template already contains it.

**Terraform.** State that `backend.tf` is intentionally absent: remote state configuration belongs to the consuming repository, not to a generated template. Note that dashboards need the separate Grafana provider if the user targets Azure Managed Grafana; the free in-portal dashboards deploy through AzureRM or AzAPI as ordinary Azure resources.

**Bicep.** The free in-portal dashboard is deployable; Azure Managed Grafana dashboards are not. That asymmetry is a real reason to prefer the free option when infrastructure-as-code matters.

**Azure CLI.** `az monitor account` is generally available and creates an Azure Monitor workspace. The generated script needs the `application-insights` CLI extension and checks for it rather than installing it, because installing an extension mutates the operator's CLI. Azure Managed Grafana commands need the separate `amg` extension.

## The Azure dashboard

The Azure dashboard is a separate deliverable from the local one and shares nothing with it. Local queries Prometheus in PromQL; Azure queries Log Analytics in KQL. Panels do not port between them.

* **Datasource:** Azure Monitor, pointed at the Log Analytics workspace backing the Application Insights resource.
* **Minimum Grafana version:** 10.0. The bundled Azure Monitor datasource plugin is present in both products.
* **Tables:** Copilot spans land as `dependencies` and `requests`, with custom attributes under `customDimensions`. Every generated KQL query names the table and the fields it reads so the user can check it against their own workspace.

Seed from `examples/dashboards/copilot-otel-azure.json`.

Microsoft publishes a prebuilt Copilot dashboard for Azure Managed Grafana at `aka.ms/amg/dash/gh-copilot`. Offer it as an alternative rather than a basis: its contents were never verified during this skill's research, so do not describe it as equivalent to the generated one or claim which panels it contains.

Do not assert that Copilot emits exponential histograms. Application Insights dashboards that depend on them need that confirmed first, and it has not been.

## Links

* [Visualize Azure Monitor data with Grafana](https://learn.microsoft.com/azure/azure-monitor/visualize/visualize-grafana-overview)
* [Use Azure Monitor dashboards with Grafana](https://learn.microsoft.com/azure/azure-monitor/visualize/visualize-use-grafana-dashboards)
* [Azure Managed Grafana overview](https://learn.microsoft.com/azure/managed-grafana/overview)
* [Azure Managed Grafana pricing](https://azure.microsoft.com/pricing/details/managed-grafana/)
* [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/)
* [az monitor account](https://learn.microsoft.com/cli/azure/monitor/account)

