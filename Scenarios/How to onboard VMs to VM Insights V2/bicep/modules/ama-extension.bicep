param vmName string
param location string
param amaExtensionType string

resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${vmName}/${amaExtensionType}'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: amaExtensionType
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}
