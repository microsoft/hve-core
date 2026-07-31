#!/usr/bin/env bash
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# deploy.sh
# Create the Log Analytics workspace, Application Insights component, and
# Azure Monitor dashboard that back GitHub Copilot fleet telemetry.
#
# This creates billable resources. Review the ingestion cost discussion in
# references/azure-capture.md before running it.

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-}"
LOCATION="${LOCATION:-}"
NAME_PREFIX="${NAME_PREFIX:-}"
RETENTION_DAYS="${RETENTION_DAYS:-90}"
DAILY_QUOTA_GB="${DAILY_QUOTA_GB:-5}"

usage() {
  cat <<'EOF'
Usage: RESOURCE_GROUP=rg LOCATION=eastus NAME_PREFIX=contoso ./deploy.sh

Required environment variables:
  RESOURCE_GROUP   Existing resource group for the telemetry resources
  LOCATION         Region; the dashboard must match the workspace region
  NAME_PREFIX      3-16 lowercase letters, digits, or hyphens

Optional:
  RETENTION_DAYS   Log Analytics retention, 30-730 (default 90)
  DAILY_QUOTA_GB   Ingestion cap in GB; -1 disables the cap (default 5)
EOF
}

require_inputs() {
  local missing=0
  for var in RESOURCE_GROUP LOCATION NAME_PREFIX; do
    if [[ -z "${!var}" ]]; then
      echo "error: $var is not set" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    usage >&2
    exit 2
  fi
}

require_tooling() {
  if ! command -v az >/dev/null 2>&1; then
    echo "error: the Azure CLI is not installed" >&2
    exit 3
  fi
  # The application-insights command group ships as an extension. Installing it
  # mutates the operator's CLI, so ask rather than doing it silently.
  if ! az extension show --name application-insights >/dev/null 2>&1; then
    echo "error: the application-insights CLI extension is required" >&2
    echo "       install it with: az extension add --name application-insights" >&2
    exit 4
  fi
}

main() {
  require_inputs
  require_tooling

  local workspace_name="${NAME_PREFIX}-copilot-logs"
  local insights_name="${NAME_PREFIX}-copilot-insights"
  local dashboard_name="${NAME_PREFIX}-copilot-dashboard"

  echo "Creating Log Analytics workspace ${workspace_name}"
  local workspace_id
  workspace_id=$(az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$workspace_name" \
    --location "$LOCATION" \
    --retention-time "$RETENTION_DAYS" \
    --quota "$DAILY_QUOTA_GB" \
    --query id -o tsv)

  echo "Creating Application Insights component ${insights_name}"
  az monitor app-insights component create \
    --resource-group "$RESOURCE_GROUP" \
    --app "$insights_name" \
    --location "$LOCATION" \
    --workspace "$workspace_id" \
    --application-type other \
    --output none

  echo "Creating Azure Monitor dashboard ${dashboard_name}"
  # Provisioned empty. Import the dashboard JSON through the portal to populate
  # it; see README.md step 4.
  az resource create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$dashboard_name" \
    --resource-type "Microsoft.Dashboard/dashboards" \
    --api-version "2025-08-01" \
    --location "$LOCATION" \
    --properties '{}' \
    --output none

  cat <<EOF

Done. Retrieve the collector's connection string with:

  az monitor app-insights component show \\
    --resource-group "$RESOURCE_GROUP" --app "$insights_name" \\
    --query connectionString -o tsv

Treat that value as a fleet-wide write credential. Put it in a secret store and
supply it to the collector as APPLICATIONINSIGHTS_CONNECTION_STRING. Do not
commit it and do not paste it into a chat transcript or an issue.

Azure Managed Grafana is not created here. If you decide its triggers apply,
install the extension first with: az extension add --name amg
EOF
}

main "$@"
