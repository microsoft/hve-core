# Backing store and dashboard surface for GitHub Copilot fleet telemetry.
#
# Apply this once per environment. One workspace shared across environments
# gives every authorized reader visibility into all of them, and a resource
# attribute cannot take that back: attributes are grouping keys, not access
# boundaries. That is why environment is a required variable with no default.
#
# The state file for this configuration contains the Application Insights
# connection string, which is a fleet-wide write credential. Marking the output
# sensitive hides it from CLI display; it does not remove it from state. Use a
# remote backend with encryption at rest and restricted access, and treat the
# state file itself as a secret.
#
# This configuration does not deploy the collector. Where the collector runs
# depends on the organization's existing platform, so that choice is left to
# the operator.

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  resource_prefix = "${var.name_prefix}-${var.environment}"
  common_tags     = merge(var.tags, { environment = var.environment })
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.resource_prefix}-copilot-logs"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  sku                 = "PerGB2018"

  # Retention is the deletion policy. Data ages out here and not before;
  # nothing in this configuration purges on request. An erasure obligation for
  # a specific person is an operator procedure against this workspace.
  retention_in_days = var.retention_in_days
  daily_quota_gb    = var.daily_quota_gb
  tags              = local.common_tags
}

resource "azurerm_application_insights" "this" {
  name                = "${local.resource_prefix}-copilot-insights"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "other"

  # Ingestion is authenticated by the connection string held by the collector.
  # Set this to true only when the collector runs with a managed identity.
  local_authentication_disabled = false

  tags = local.common_tags
}

# Azure Monitor dashboards with Grafana. Free, in-portal, and deployable as an
# Azure resource, which Azure Managed Grafana dashboards are not. AzureRM has no
# resource for this type, so it is created through AzAPI.
#
# Provisioned empty on purpose. Import the dashboard JSON through the portal to
# populate it; see README.md step 4.
resource "azapi_resource" "dashboard" {
  type      = "Microsoft.Dashboard/dashboards@2025-08-01"
  name      = "${local.resource_prefix}-copilot-dashboard"
  parent_id = data.azurerm_resource_group.this.id
  location  = var.location

  tags = merge(local.common_tags, {
    GrafanaDashboardTags = "copilot,telemetry"
  })

  body = {
    properties = {}
  }
}

# Monitoring Reader. Required to query Azure Monitor data from Grafana.
#
# Opt-in and scoped to this environment's workspace only. Assigning at
# subscription or resource-group scope would hand the principal every
# environment at once, which is what the per-environment split prevents.
resource "azurerm_role_assignment" "reader" {
  count = var.reader_principal_id == "" ? 0 : 1

  scope                = azurerm_log_analytics_workspace.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = var.reader_principal_id
}
