param vmName string
param location string
param identityType string

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  identity: {
    type: identityType
  }
}
