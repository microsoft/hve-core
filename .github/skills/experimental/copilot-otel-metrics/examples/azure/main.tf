# Backing store and dashboard surface for GitHub Copilot fleet telemetry.
#
# This configuration does not deploy the collector. Where the collector runs
# depends on the organization's existing platform, so that choice is left to
# the operator.

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-copilot-logs"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "${var.name_prefix}-copilot-insights"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "other"

  # Ingestion is authenticated by the connection string held by the collector.
  # Set this to true only when the collector runs with a managed identity.
  local_authentication_disabled = false

  tags = var.tags
}

# Azure Monitor dashboards with Grafana. Free, in-portal, and deployable as an
# Azure resource, which Azure Managed Grafana dashboards are not. AzureRM has no
# resource for this type, so it is created through AzAPI.
#
# Provisioned empty on purpose. Import the dashboard JSON through the portal to
# populate it; see README.md step 4.
resource "azapi_resource" "dashboard" {
  type      = "Microsoft.Dashboard/dashboards@2025-08-01"
  name      = "${var.name_prefix}-copilot-dashboard"
  parent_id = data.azurerm_resource_group.this.id
  location  = var.location

  tags = merge(var.tags, {
    GrafanaDashboardTags = "copilot,telemetry"
  })

  body = {
    properties = {}
  }
}

# Monitoring Reader. Required to query Azure Monitor data from Grafana.
resource "azurerm_role_assignment" "reader" {
  count = var.reader_principal_id == "" ? 0 : 1

  scope                = azurerm_log_analytics_workspace.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = var.reader_principal_id
}
