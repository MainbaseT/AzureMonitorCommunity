using '../main.bicep'

// Standard free-tier: existing AMW, new DCR

param vmName = '<YOUR_VM_NAME>'
param vmResourceGroup = '<YOUR_VM_RESOURCE_GROUP>'
param vmSubscriptionId = '<YOUR_SUBSCRIPTION_ID>'
param location = '<YOUR_LOCATION>'
param osType = 'Linux'

param createNewAmw = false
param existingAmwResourceId = '/subscriptions/<SUB>/resourceGroups/<RG>/providers/microsoft.monitor/accounts/<AMW_NAME>'

param createNewDcr = true
param enablePerProcessMetrics = false
param enableAlerts = false
