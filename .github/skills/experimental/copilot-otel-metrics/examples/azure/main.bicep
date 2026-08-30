// Backing store and dashboard surface for GitHub Copilot fleet telemetry.
//
// Deploy with:
//   az deployment group create -g <resource-group> -f main.bicep \
//     -p namePrefix=<prefix> environment=<prod|staging|dev>
//
// Deploy this once per environment. One workspace shared across environments
// gives every authorized reader visibility into all of them, and a resource
// attribute cannot take that back: attributes are grouping keys, not access
// boundaries. That is why environment is required rather than defaulted.
//
// This template does not deploy the collector. Where the collector runs
// (Container Apps, AKS, a VM) depends on the organization's existing platform,
// so that choice is left to the operator.
//
// API versions: Microsoft.Dashboard/dashboards@2025-08-01 was verified current
// on 2026-07-27. The OperationalInsights and Insights versions below were not
// verified in that session; confirm with `az provider show -n <namespace>
// --query "resourceTypes[?resourceType=='<type>'].apiVersions"` before deploying.

@description('Prefix for all resource names. Follow your existing naming convention.')
@minLength(3)
@maxLength(16)
param namePrefix string

@description('Environment this deployment serves. Deploy one set of resources per environment.')
@minLength(2)
@maxLength(12)
param environment string

@description('Region for all resources. The dashboard must sit in the same region as the workspace.')
param location string = resourceGroup().location

@description('Log Analytics retention in days. This is a cost decision, not a default.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Daily ingestion cap in GB. -1 disables the cap and removes the only spend guardrail.')
param dailyQuotaGb int = 5

@description('Object ID of the principal that will read telemetry. Leave empty to skip the role assignment.')
param readerPrincipalId string = ''

var workspaceName = '${namePrefix}-${environment}-copilot-logs'
var appInsightsName = '${namePrefix}-${environment}-copilot-insights'
var dashboardName = '${namePrefix}-${environment}-copilot-dashboard'

// Monitoring Reader. Required to query Azure Monitor data from Grafana.
var monitoringReaderRoleId = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: {
    environment: environment
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    // Retention is the deletion policy. Data ages out at this boundary and not
    // before; nothing here purges on request. An erasure obligation for a
    // specific person is an operator procedure against this workspace, not a
    // property of this template.
    retentionInDays: retentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'other'
  tags: {
    environment: environment
  }
  properties: {
    Application_Type: 'other'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    // Ingestion is authenticated by the connection string held by the collector.
    // Local auth stays enabled because the collector has no Entra identity path
    // when it runs outside Azure; disable it if the collector runs with a
    // managed identity.
    DisableLocalAuth: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Azure Monitor dashboards with Grafana. Free, in-portal, and unlike Azure
// Managed Grafana dashboards, deployable as an Azure resource.
//
// Provisioned empty on purpose. Import the dashboard JSON through the portal to
// populate it; see README.md step 4.
resource dashboard 'Microsoft.Dashboard/dashboards@2025-08-01' = {
  name: dashboardName
  location: location
  tags: {
    GrafanaDashboardTags: 'copilot,telemetry'
    environment: environment
  }
  properties: {}
}

// Opt-in and scoped to this environment's workspace only. Assigning a reader at
// subscription or resource-group scope would hand them every environment at
// once, which is the outcome the per-environment split exists to prevent.
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(readerPrincipalId)) {
  name: guid(workspace.id, readerPrincipalId, monitoringReaderRoleId)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleId)
    principalId: readerPrincipalId
  }
}

output workspaceId string = workspace.id
output appInsightsId string = appInsights.id
output dashboardId string = dashboard.id

// Read this from a deployment output rather than committing it anywhere.
#disable-next-line outputs-should-not-contain-secrets
output connectionStringCommand string = 'az monitor app-insights component show -g ${resourceGroup().name} -a ${appInsightsName} --query connectionString -o tsv'
