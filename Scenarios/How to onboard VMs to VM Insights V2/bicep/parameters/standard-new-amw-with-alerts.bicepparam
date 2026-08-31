using '../main.bicep'

// Standard free-tier with all recommended alerts

param vmName = '<YOUR_VM_NAME>'
param vmResourceGroup = '<YOUR_VM_RESOURCE_GROUP>'
param vmSubscriptionId = '<YOUR_SUBSCRIPTION_ID>'
param location = '<YOUR_LOCATION>'
param osType = 'Linux'

param createNewAmw = true
param amwName = '<YOUR_AMW_NAME>'

param createNewDcr = true
param enablePerProcessMetrics = false

param enableAlerts = true
param uamiResourceId = '/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<UAMI_NAME>'
