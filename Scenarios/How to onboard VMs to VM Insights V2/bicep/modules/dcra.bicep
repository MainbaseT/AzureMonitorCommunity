param vmResourceId string
param dcrResourceId string

resource dcra 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: 'VirtualMachineInsightsExtension'
  scope: existing_vm
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this virtual machine.'
    dataCollectionRuleId: dcrResourceId
  }
}

resource existing_vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: last(split(vmResourceId, '/'))
}
