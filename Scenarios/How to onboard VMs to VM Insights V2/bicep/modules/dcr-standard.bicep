param dcrName string
param location string
param amwResourceId string
param counterSpecifiers array

resource dcr 'Microsoft.Insights/dataCollectionRules@2024-03-11' = {
  name: dcrName
  location: location
  properties: {
    dataSources: {
      performanceCountersOTel: [
        {
          name: 'OtelDataSource'
          streams: ['Microsoft-OtelPerfMetrics']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: counterSpecifiers
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: amwResourceId
          name: 'MonitoringAccountDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-OtelPerfMetrics']
        destinations: ['MonitoringAccountDestination']
      }
    ]
  }
}

output dcrId string = dcr.id
