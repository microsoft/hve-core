---
title: Azure Capture Templates
description: Collector configuration, Bicep, Terraform, and Azure CLI templates for collecting GitHub Copilot fleet telemetry into Azure
author: Microsoft
ms.date: 2026-08-18
ms.topic: reference
keywords:
  - opentelemetry
  - copilot
  - azure
  - bicep
  - terraform
estimated_reading_time: 4
---

## What is here

Templates to copy, adapt, and deploy yourself. Nothing here runs automatically, and the skill will not run any of it for you. Each one creates billable Azure resources.

| File                                          | Deploys                                                                 |
|-----------------------------------------------|-------------------------------------------------------------------------|
| `otel-collector-config.yaml`                  | Collector pipeline receiving OTLP and exporting to Application Insights |
| `agent-host-relay/otel-collector-config.yaml` | The per-workstation relay's Collector pipeline                          |
| `agent-host-relay/compose.yaml`               | The per-workstation relay as a restart-managed container                |
| `main.bicep`                                  | Log Analytics workspace, Application Insights, Azure Monitor dashboard  |
| `main.tf` and friends                         | The same resources through Terraform                                    |
| `deploy.sh`                                   | The same resources through the Azure CLI                                |

Pick one deployment path for the Azure resources. They are three routes to the same result, not three stages. The relay is not one of those routes: it is deployed to every workstation regardless of which one you pick.

## Before you deploy

Read `references/azure-capture.md` in the skill root first. Three things there change how you should approach this:

* A collector is mandatory. Copilot cannot export to Azure Monitor directly, because it sends static headers and Azure Monitor requires rotating Entra credentials.
* The connection string is a fleet-wide write credential. Every workstation gets the same value, and there is no documented in-place rotation.
* The Grafana surface is free; the data underneath it is not. `captureContent` is the dominant cost multiplier and the dominant privacy exposure.

## Values you must supply

None of these have safe defaults, so all of them are required inputs:

* Subscription and tenant.
* Region. The dashboard must sit in the same region as the workspace.
* Resource naming, which usually follows an existing organizational convention.
* The principal that will hold `Monitoring Reader` on the workspace.
* Retention and the daily ingestion cap, which are cost decisions.

## Prerequisites

`deploy.sh` needs the `application-insights` CLI extension. It checks and exits rather than installing it for you:

```bash
az extension add --name application-insights
```

Azure Managed Grafana, if you decide its triggers apply, needs `az extension add --name amg`.

## Deploying

Deploy once per environment. Every resource name carries the environment, so `prod` and `staging` produce separate workspaces rather than colliding.

```bash
# Bicep
az deployment group create -g <resource-group> -f main.bicep \
  -p namePrefix=<prefix> environment=<prod|staging|dev>

# Terraform
terraform init
terraform plan  -var name_prefix=<prefix> -var environment=<env> -var resource_group_name=<rg> -var location=<region>
terraform apply -var name_prefix=<prefix> -var environment=<env> -var resource_group_name=<rg> -var location=<region>

# Azure CLI
RESOURCE_GROUP=<rg> LOCATION=<region> NAME_PREFIX=<prefix> ENVIRONMENT=<env> ./deploy.sh
```

`backend.tf` is intentionally absent from the Terraform configuration. Remote state belongs to the repository that consumes these files, not to the template.

The Terraform state for this configuration contains the Application Insights connection string, which is a fleet-wide write credential. The output is marked `sensitive`, which keeps it out of CLI display but does **not** keep it out of state. Use a remote backend with encryption at rest and restricted access, and treat the state file as a secret in its own right.

## Why one deployment per environment

A resource attribute such as `service.namespace` or `deployment.environment.name` is a grouping key. It lets a reader filter; it does not stop them removing the filter. Anyone with `Monitoring Reader` on a workspace can read everything in it.

Separation therefore comes from separate workspaces and separate collector endpoints, each with its own ingest token, and from scoping every reader assignment to a single workspace. The templates scope the assignment to the workspace for this reason; assigning at subscription or resource-group scope hands the principal every environment at once and undoes the split.

This is environment separation, not customer multi-tenancy. Copilot's exporter sends the same static headers from every workstation, so nothing in the payload identifies a tenant in a way you could trust for isolation.

## Collector authentication and TLS

`otel-collector-config.yaml` requires both, actively rather than as a suggestion:

```bash
export COPILOT_OTEL_INGEST_TOKEN="<fleet ingest token>"
export COPILOT_OTEL_ENVIRONMENT="prod"
export COPILOT_OTEL_TLS_CERT_FILE="/etc/otel/tls/tls.crt"
export COPILOT_OTEL_TLS_KEY_FILE="/etc/otel/tls/tls.key"
```

Be clear about what the token does. Every workstation holds the same value, so it authenticates the fleet rather than a person, it cannot be rotated for one user, and anyone who extracts it from a workstation can write spans as the fleet. It is still worth having: without it the receiver accepts spans from anything that can route to it, and every accepted span is billed and stored.

If TLS is terminated by an ingress controller or load balancer in front of the collector, delete the `tls` blocks and record that the terminating hop owns certificate lifecycle and cipher policy. Deleting them because certificates are inconvenient leaves fleet telemetry in plaintext on the wire.

What the collector configuration cannot control is the sender. Copilot's exporter decides how it validates the server certificate, and no setting here changes that.

## Every workstation runs the relay

Requiring authentication on the receiver has a consequence that is easy to miss because its symptom is an absence.

Managed `telemetry.headers` are applied to the extension exporter directly and are deliberately **not** exported into the environment, because an environment variable would be inherited by the tool subprocesses the agent spawns, putting this fleet-wide write credential inside every model-directed subprocess. So the extension authenticates and the agent host does not. This receiver rejects the agent host's export with HTTP 401 or gRPC `UNAUTHENTICATED`, and neither is retryable under the OTLP specification: the data is dropped, not queued.

Do not fix this by exporting the token into the environment, and do not fix it by removing authentication from the receiver. The first defeats the separation that keeps the credential away from agent-spawned subprocesses; the second reopens ingestion to anything that can route to this endpoint, on a billed backend.

The shipped fix is `agent-host-relay/`: a Collector on each workstation that listens on loopback, applies the same fail-closed allow-list and content scrub this fleet Collector applies, and adds the fleet credential on its own upstream hop.

```text
extension  ─┐
            ├─▶ 127.0.0.1:4318 relay ──bearer, verified TLS──▶ fleet receiver
agent host ─┘      (filters both)
```

Managed settings apply one endpoint to both emitters, so both go to the relay. Neither carries the fleet credential, and managed settings no longer set `telemetry.headers` at all.

**This makes the relay load-bearing for everything.** After the managed endpoint moves to loopback, a workstation whose relay is stopped, missing, or unhealthy sends no telemetry at all. Nothing queues it elsewhere. Deploy and verify relays first; change managed settings second.

### What the operator supplies

The relay ships no credential and no certificate authority. Put three values in a file outside this repository, readable only by the account that runs the relay:

```bash
# /etc/copilot-otel/relay.env, mode 600, owned by the relay account
COPILOT_OTEL_FLEET_ENDPOINT=https://otel.example.internal:4318
COPILOT_OTEL_INGEST_TOKEN=<fleet ingest token>
COPILOT_OTEL_FLEET_CA_BUNDLE=/etc/copilot-otel/fleet-ca.pem
```

```bash
chmod 600 /etc/copilot-otel/relay.env
```

On Windows, restrict it to the same single account:

```powershell
icacls C:\ProgramData\copilot-otel\relay.env /inheritance:r /grant:r "$env:USERNAME:(R)"
```

`COPILOT_OTEL_FLEET_CA_BUNDLE` must be an absolute path to the CA bundle that signs the fleet receiver's certificate. The relay mounts it read-only and verifies against it: a receiver presenting an untrusted certificate, or one whose subject alternative names do not include the endpoint hostname, is refused rather than trusted. There is no plaintext fallback and no verification opt-out.

### Running it

Start the relay independently of VS Code, so it neither inherits nor shares the editor's environment and `restart: unless-stopped` brings it back after a reboot:

```bash
docker compose --env-file /etc/copilot-otel/relay.env \
  -f /opt/copilot-otel/agent-host-relay/compose.yaml up -d
```

Verify it before touching managed settings:

```bash
curl -sf http://127.0.0.1:13133/ && echo relay healthy
```

Rotate the token by editing the env file and recreating the container:

```bash
docker compose --env-file /etc/copilot-otel/relay.env \
  -f /opt/copilot-otel/agent-host-relay/compose.yaml up -d --force-recreate
```

When decommissioning a workstation, stop the relay and delete the env file. Removing the container does not remove it:

```bash
docker compose --env-file /etc/copilot-otel/relay.env \
  -f /opt/copilot-otel/agent-host-relay/compose.yaml down
rm -f /etc/copilot-otel/relay.env
```

### Rollout and rollback

1. Deploy the relay to every workstation and confirm each one reports healthy.
2. Change managed settings to `http://127.0.0.1:4318` with `otlp-http`, and remove `telemetry.headers`.
3. Query the backend for a span category only the agent host emits. Extension telemetry arriving does not establish that agent-host telemetry is.

If telemetry stops fleet-wide or on one workstation, point managed settings back at the fleet endpoint and restore `telemetry.headers`. That returns extension telemetry immediately and returns the agent-host gap with it, which is the state that existed before the relay.

The relay listens on OTLP/HTTP port 4318 only. gRPC is unsupported: managed settings must select `otlp-http`, and pointing an emitter at 4317 reaches nothing.

### Detection

| Symptom                                               | Likely cause                                                |
|-------------------------------------------------------|-------------------------------------------------------------|
| No telemetry at all from one workstation              | Its relay is stopped or unhealthy                           |
| Agent-host span categories missing, extension present | Managed settings still point at the fleet endpoint directly |
| Relay healthy, nothing arrives upstream               | Certificate, hostname, or bearer rejection in the relay log |

The relay's own log names which of the three it hit. Check it before changing anything else.

### What the relay does not do

Its listener is unauthenticated, so any local process that can reach loopback can inject telemetry into this backend through it. Binding to `127.0.0.1` keeps the listener off the network; it says nothing about which local process connected. The relay authenticates the relay to this endpoint. It does not authenticate the workstation and it does not authenticate the developer.

The env file is readable by anything running as the same operating-system account, and by anything that can inspect the container. That is a smaller blast radius than the environment of every agent-spawned subprocess, which is the point, but it is not isolation.

Mutual TLS would be better, and this receiver already supports the server half: adding `client_ca_file` beside `cert_file` and `key_file` makes a valid client certificate mandatory on both protocols. Whether the VS Code agent host can present one is unknown, so it is not offered here as an available option.

## Retention and deletion

`retentionInDays` and `retention_in_days` are the deletion policy. Data ages out at that boundary and not before, and nothing in these templates purges on request. An erasure obligation for a specific person is an operator procedure run against the workspace; treat it as owned work rather than as something the template handles.

The daily cap is the only spend guardrail. Setting it to `-1` removes it.

## After you deploy

1. Retrieve the Application Insights connection string and put it in a secret store. Do not commit it.
2. Run the collector somewhere the fleet can reach, with `APPLICATIONINSIGHTS_CONNECTION_STRING`, `COPILOT_OTEL_INGEST_TOKEN`, `COPILOT_OTEL_ENVIRONMENT`, and the TLS paths supplied from that secret store. Where it runs is your platform decision; Container Apps, AKS, and a VM behind a load balancer all work.
3. Deploy `agent-host-relay/` to every workstation and confirm each one reports healthy. Do this **before** the next step: once managed settings point at loopback, a workstation without a working relay sends nothing.
4. Distribute the loopback endpoint through Copilot managed settings. See `references/org-distribution.md`.
5. Import `../dashboards/copilot-otel-azure.json` into Azure Monitor dashboards with Grafana and set the workspace variable to your Log Analytics resource ID. The templates provision the dashboard resource empty; this import is what fills it.
6. Confirm data landed by querying Log Analytics, not by checking that the collector reports success. Query for an agent-host span category specifically; extension telemetry arriving does not establish that agent-host telemetry is.

## API versions

`Microsoft.Dashboard/dashboards@2025-08-01` was verified current on 2026-07-27. The other API and provider versions in these files were not verified in that session. Check before deploying:

```bash
az provider show -n Microsoft.OperationalInsights \
  --query "resourceTypes[?resourceType=='workspaces'].apiVersions" -o tsv | head
```

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
