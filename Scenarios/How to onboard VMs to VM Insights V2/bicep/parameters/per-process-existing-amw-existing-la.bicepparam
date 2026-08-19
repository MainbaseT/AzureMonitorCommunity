using '../main.bicep'

// Per-process (paid) tier: existing AMW + existing LA, new DCR, no alerts

param vmName = '<YOUR_VM_NAME>'
param vmResourceGroup = '<YOUR_VM_RESOURCE_GROUP>'
param vmSubscriptionId = '<YOUR_SUBSCRIPTION_ID>'
param location = '<YOUR_LOCATION>'
param osType = 'Linux'

param createNewAmw = false
param existingAmwResourceId = '/subscriptions/<SUB>/resourceGroups/<RG>/providers/microsoft.monitor/accounts/<AMW_NAME>'

param createNewLogAnalyticsWorkspace = false
param existingLogAnalyticsWorkspaceId = '/subscriptions/<SUB>/resourceGroups/<RG>/providers/microsoft.operationalinsights/workspaces/<LA_NAME>'

param createNewDcr = true
param enablePerProcessMetrics = true

param enableAlerts = false
