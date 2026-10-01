output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace backing the telemetry store."
  value       = azurerm_log_analytics_workspace.this.id
}

output "app_insights_id" {
  description = "Resource ID of the Application Insights component the collector exports to."
  value       = azurerm_application_insights.this.id
}

output "dashboard_id" {
  description = "Resource ID of the Azure Monitor dashboard with Grafana."
  value       = azapi_resource.dashboard.id
}

output "connection_string" {
  description = "Connection string the collector needs. Treat as a fleet-wide write credential. Marking this sensitive hides it from CLI output but does not remove it from the state file; protect the state accordingly."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
