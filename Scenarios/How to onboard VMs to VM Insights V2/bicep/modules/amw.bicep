param amwName string
param location string

resource amw 'microsoft.monitor/accounts@2023-04-03' = {
  name: amwName
  location: location
  properties: {}
}

output amwResourceId string = amw.id
