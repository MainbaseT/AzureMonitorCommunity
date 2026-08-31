param vmName string
param location string
param vmResourceId string
param uamiResourceId string

var uamiIdentity = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiResourceId}': {}
  }
}

var failingPeriods = { for: 'PT2M' }
var resolveConfig = { autoResolved: true, timeToResolve: 'PT2M' }

// --- Guest OS CPU Usage ---
resource cpuAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS CPU Usage - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'CPU usage has exceeded 80% threshold over the last 5 minutes'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'avg_over_time(((sum (irate({"system.cpu.time","state" !~ "idle|iowait|steal"}[2m]))) / (sum (irate({"system.cpu.time"}[2m]))))[5m:]) * 100 > 80'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Memory Usage ---
resource memoryAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Memory Usage - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Available memory has dropped below 1 GB over the last 5 minutes'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'min_over_time((sum ({"system.memory.usage", state=~"free|cached|buffered|slab_reclaimable"}))[5m:]) < (1 * 1024 * 1024 * 1024)'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Disk IOPS ---
resource diskIopsAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Disk IOPS - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Disk IOPS has exceeded 5000 operations per second over the last 5 minutes'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'max_over_time((sum (irate({"system.disk.operations"}[2m])))[5m:]) > 5000'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Network In ---
resource networkInAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Network In - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Total network inbound traffic has exceeded 100 GB over the last day'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'sum_over_time((sum (irate({"system.network.io", direction="receive"}[2m])))[1d:]) > (100 * 1024 * 1024 * 1024)'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Network Out ---
resource networkOutAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Network Out - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Total network outbound traffic has exceeded 50 GB over the last day'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'sum_over_time((sum (irate({"system.network.io", direction="transmit"}[2m])))[1d:]) > (50 * 1024 * 1024 * 1024)'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Network Errors ---
resource networkErrorsAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Network Errors - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Network errors have exceeded 10 total errors over the last 5 minutes'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'sum_over_time((sum (irate({"system.network.errors"}[2m])))[5m:]) > 10'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}

// --- Guest OS Disk Operation Time ---
resource diskOpTimeAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: 'Guest OS Disk Operation Time - ${vmName}'
  location: location
  identity: uamiIdentity
  properties: {
    description: 'Average disk operation time has exceeded 100ms over the last 5 minutes'
    severity: 3
    enabled: true
    scopes: [vmResourceId]
    evaluationFrequency: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.PromQLCriteria'
      allOf: [
        {
          name: 'Metric1'
          query: 'avg_over_time(((sum (irate({"system.disk.operation_time"}[2m]))) / (sum (irate({"system.disk.operations"}[2m]))))[5m:]) * 1000 > 100'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      failingPeriods: failingPeriods
    }
    resolveConfiguration: resolveConfig
    actions: []
  }
}
