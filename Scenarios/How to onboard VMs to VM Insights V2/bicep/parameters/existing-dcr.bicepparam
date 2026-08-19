using '../main.bicep'

// Reuse existing DCR, the fastest onboarding path

param vmName = '<YOUR_VM_NAME>'
param vmResourceGroup = '<YOUR_VM_RESOURCE_GROUP>'
param vmSubscriptionId = '<YOUR_SUBSCRIPTION_ID>'
param location = '<YOUR_LOCATION>'
param osType = 'Linux'

param createNewAmw = false
param createNewDcr = false
param existingDcrId = '/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Insights/dataCollectionRules/<DCR_NAME>'

param enablePerProcessMetrics = false
param enableAlerts = false
