param dcrName string
param location string
param amwResourceId string
param logAnalyticsWorkspaceId string
param counterSpecifiers array

resource dcr 'Microsoft.Insights/dataCollectionRules@2024-03-11' = {
  name: dcrName
  location: location
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'Microsoft-InsightsMetrics'
          streams: ['Microsoft-InsightsMetrics']
          scheduledTransferPeriod: 'PT1M'
          samplingFrequencyInSeconds: 60
          counterSpecifiers: ['\\VmInsights\\DetailedMetrics']
        }
      ]
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
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspaceId
          name: 'vmInsightworkspace'
        }
      ]
      monitoringAccounts: [
        {
          accountResourceId: amwResourceId
          name: 'MonitoringAccountDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-InsightsMetrics']
        destinations: ['vmInsightworkspace']
      }
      {
        streams: ['Microsoft-OtelPerfMetrics']
        destinations: ['MonitoringAccountDestination']
      }
    ]
  }
}

output dcrId string = dcr.id
