// ============================================================================
// VM Insights V2 Onboarding (Bicep)
//
// Single parameterized template covering:
//   - New or existing Azure Monitor Workspace (AMW)
//   - New or existing Log Analytics workspace (for per-process metrics)
//   - New or existing Data Collection Rule (DCR)
//   - Standard (free) or per-process (paid) metrics tier
//   - Optional recommended alert rules
// ============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// VM Configuration
// ---------------------------------------------------------------------------

@description('Name of the existing virtual machine to onboard.')
param vmName string

@description('Resource group containing the VM.')
param vmResourceGroup string

@description('Subscription ID of the VM.')
param vmSubscriptionId string

@description('Azure region (must match VM location, e.g. eastus2).')
param location string

@allowed(['Windows', 'Linux'])
@description('OS type of the VM, which determines the AMA extension to install.')
param osType string = 'Linux'

// ---------------------------------------------------------------------------
// Managed Identity
// ---------------------------------------------------------------------------

@description('Enable system-assigned managed identity on the VM (required by AMA). Safe to set true even if already enabled.')
param enableSystemAssignedIdentity bool = true

@allowed(['SystemAssigned', 'SystemAssigned, UserAssigned'])
@description('Use "SystemAssigned, UserAssigned" if the VM already has user-assigned identities to avoid overwriting them.')
param identityType string = 'SystemAssigned'

// ---------------------------------------------------------------------------
// Azure Monitor Workspace
// ---------------------------------------------------------------------------

@description('Set to true to create a new Azure Monitor Workspace. Set to false to use an existing one via existingAmwResourceId.')
param createNewAmw bool = false

@description('Name for the new Azure Monitor Workspace. Required when createNewAmw=true.')
param amwName string = ''

@description('Resource group for the new AMW. Defaults to VM resource group.')
param amwResourceGroup string = vmResourceGroup

@description('Full resource ID of an existing Azure Monitor Workspace. Required when createNewAmw=false.')
param existingAmwResourceId string = ''

// ---------------------------------------------------------------------------
// Log Analytics Workspace (required for per-process metrics)
// ---------------------------------------------------------------------------

@description('Set to true to create a new Log Analytics workspace. Only used when enablePerProcessMetrics=true.')
param createNewLogAnalyticsWorkspace bool = false

@description('Name for the new Log Analytics workspace. Required when createNewLogAnalyticsWorkspace=true.')
param logAnalyticsWorkspaceName string = ''

@description('Resource group for the new Log Analytics workspace. Defaults to VM resource group.')
param logAnalyticsResourceGroup string = vmResourceGroup

@description('Full resource ID of an existing Log Analytics workspace. Required when enablePerProcessMetrics=true and createNewLogAnalyticsWorkspace=false.')
param existingLogAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// Data Collection Rule
// ---------------------------------------------------------------------------

@description('Set to true to create a new Data Collection Rule. Set to false to use an existing one via existingDcrId.')
param createNewDcr bool = true

@description('Name for the new DCR. Defaults to msvmi-{location}-{vmName}.')
param dcrName string = 'msvmi-${location}-${vmName}'

@description('Resource group for the new DCR. Defaults to VM resource group.')
param dcrResourceGroup string = vmResourceGroup

@description('Full resource ID of an existing DCR. Required when createNewDcr=false.')
param existingDcrId string = ''

// ---------------------------------------------------------------------------
// Metrics Tier
// ---------------------------------------------------------------------------

@description('Enable per-process metrics (paid tier). Adds process.* OTel counters and InsightsMetrics/DetailedMetrics via Log Analytics. Requires a Log Analytics workspace.')
param enablePerProcessMetrics bool = false

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------

@description('Create recommended VM Insights alert rules (VM Availability + guest OS alerts for CPU, memory, disk, network).')
param enableAlerts bool = false

@description('Full resource ID of a User-Assigned Managed Identity for guest OS PromQL-based alerts. Required when enableAlerts=true.')
param uamiResourceId string = ''

// ---------------------------------------------------------------------------
// Computed values
// ---------------------------------------------------------------------------

var vmResourceId = '/subscriptions/${vmSubscriptionId}/resourceGroups/${vmResourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}'
var amaExtensionType = osType == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'

var amwResourceId = createNewAmw
  ? '/subscriptions/${vmSubscriptionId}/resourceGroups/${amwResourceGroup}/providers/microsoft.monitor/accounts/${amwName}'
  : existingAmwResourceId

var logAnalyticsWorkspaceId = createNewLogAnalyticsWorkspace
  ? '/subscriptions/${vmSubscriptionId}/resourceGroups/${logAnalyticsResourceGroup}/providers/microsoft.operationalinsights/workspaces/${logAnalyticsWorkspaceName}'
  : existingLogAnalyticsWorkspaceId

var dcrResourceId = createNewDcr
  ? '/subscriptions/${vmSubscriptionId}/resourceGroups/${dcrResourceGroup}/providers/Microsoft.Insights/dataCollectionRules/${dcrName}'
  : existingDcrId

var standardOtelCounters = [
  'system.filesystem.usage'
  'system.disk.io'
  'system.disk.operation_time'
  'system.disk.operations'
  'system.memory.usage'
  'system.network.io'
  'system.cpu.time'
  'system.network.dropped'
  'system.network.errors'
  'system.uptime'
]

var processOtelCounters = [
  'process.uptime'
  'process.cpu.time'
  'process.cpu.utilization'
  'process.memory.usage'
  'process.memory.virtual'
  'process.memory.utilization'
  'process.disk.io'
  'process.disk.operations'
  'process.paging.faults'
  'process.open_file_descriptors'
  'process.threads'
  'process.handles'
  'process.context_switches'
  'process.signals_pending'
  'system.processes.count'
  'system.processes.created'
]

var allOtelCounters = concat(standardOtelCounters, processOtelCounters)

// ============================================================================
// Module deployments (scoped to their respective resource groups)
// ============================================================================

// --- Enable system-assigned managed identity on the VM ---
module enableIdentity 'modules/vm-identity.bicep' = if (enableSystemAssignedIdentity) {
  name: 'EnableVMSystemIdentity'
  scope: resourceGroup(vmSubscriptionId, vmResourceGroup)
  params: {
    vmName: vmName
    location: location
    identityType: identityType
  }
}

// --- Create a new Azure Monitor Workspace ---
module createAmw 'modules/amw.bicep' = if (createNewAmw) {
  name: 'CreateAMW'
  scope: resourceGroup(vmSubscriptionId, amwResourceGroup)
  params: {
    amwName: amwName
    location: location
  }
}

// --- Create a new Log Analytics workspace (for per-process metrics) ---
module createLa 'modules/log-analytics.bicep' = if (createNewLogAnalyticsWorkspace && enablePerProcessMetrics) {
  name: 'CreateLogAnalyticsWorkspace'
  scope: resourceGroup(vmSubscriptionId, logAnalyticsResourceGroup)
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

// --- DCR: Standard OTel metrics only (free tier) ---
module createStandardDcr 'modules/dcr-standard.bicep' = if (createNewDcr && !enablePerProcessMetrics) {
  name: 'CreateStandardDCR'
  scope: resourceGroup(vmSubscriptionId, dcrResourceGroup)
  dependsOn: [createAmw]
  params: {
    dcrName: dcrName
    location: location
    amwResourceId: amwResourceId
    counterSpecifiers: standardOtelCounters
  }
}

// --- DCR: Per-process metrics (paid tier) ---
module createPerProcessDcr 'modules/dcr-per-process.bicep' = if (createNewDcr && enablePerProcessMetrics) {
  name: 'CreatePerProcessDCR'
  scope: resourceGroup(vmSubscriptionId, dcrResourceGroup)
  dependsOn: [createAmw, createLa]
  params: {
    dcrName: dcrName
    location: location
    amwResourceId: amwResourceId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    counterSpecifiers: allOtelCounters
  }
}

// --- Associate DCR with VM ---
module createDcra 'modules/dcra.bicep' = {
  name: 'CreateDCRA'
  scope: resourceGroup(vmSubscriptionId, vmResourceGroup)
  dependsOn: [createStandardDcr, createPerProcessDcr]
  params: {
    vmResourceId: vmResourceId
    dcrResourceId: dcrResourceId
  }
}

// --- Install Azure Monitor Agent extension ---
module installAma 'modules/ama-extension.bicep' = {
  name: 'InstallAMAExtension'
  scope: resourceGroup(vmSubscriptionId, vmResourceGroup)
  dependsOn: [createDcra, enableIdentity]
  params: {
    vmName: vmName
    location: location
    amaExtensionType: amaExtensionType
  }
}

// --- Host alert: VM Availability ---
module hostAlerts 'modules/alert-host.bicep' = if (enableAlerts) {
  name: 'CreateHostAlertRules'
  scope: resourceGroup(vmSubscriptionId, vmResourceGroup)
  params: {
    vmName: vmName
    vmResourceId: vmResourceId
  }
}

// --- Guest OS alerts (PromQL-based, requires UAMI) ---
module guestAlerts 'modules/alert-guest.bicep' = if (enableAlerts) {
  name: 'CreateGuestAlertRules'
  scope: resourceGroup(vmSubscriptionId, vmResourceGroup)
  params: {
    vmName: vmName
    location: location
    vmResourceId: vmResourceId
    uamiResourceId: uamiResourceId
  }
}
