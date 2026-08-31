# VM Insights V2 Onboarding Templates

ARM and Bicep templates for onboarding Azure Virtual Machines to **VM Insights V2**. A single parameterized template handles all combinations of resource provisioning, metrics tiers, and alert rules.

## Glossary

| Term | Meaning |
|------|---------|
| **AMW** | Azure Monitor Workspace. Stores OTel (OpenTelemetry) metrics from the VM |
| **LA** | Log Analytics workspace. Stores `InsightsMetrics` for per-process/detailed metrics |
| **DCR** | Data Collection Rule. Defines which metrics to collect and where to send them |
| **DCRA** | Data Collection Rule Association. Links a DCR to a specific VM |
| **AMA** | Azure Monitor Agent. The VM extension that collects and ships metrics |
| **OTel** | OpenTelemetry. The metrics format used by VM Insights V2 |
| **UAMI** | User-Assigned Managed Identity. Required for PromQL-based guest OS alerts |
| **PromQL** | Prometheus Query Language. Used by guest OS alert rules to query OTel metrics |

## What This Does

These templates onboard an **existing** VM to VM Insights V2 by:

1. Enabling a managed identity on the VM (required by AMA)
2. Optionally creating an Azure Monitor Workspace (AMW) and/or Log Analytics workspace
3. Creating (or reusing) a Data Collection Rule (DCR) for VM Insights metrics
4. Associating the DCR with the VM
5. Installing the Azure Monitor Agent (AMA) extension on the VM
6. Optionally creating recommended alert rules

### What this does NOT do

- Create the VM itself, which must already exist
- Create resource groups. All referenced resource groups must already exist
- Create a User-Assigned Managed Identity (UAMI). Create it beforehand if using alerts
- Assign RBAC roles to the UAMI. You must grant Monitoring Reader on the AMW
- Create or attach action groups. Alert rules are created but do not send notifications by default (see [Alert Rules](#alert-rules-when-enabled))
- Onboard VMSS or Azure Arc-connected machines (VM-only)

### Cost implications

- **Standard tier** sends OTel metrics to Azure Monitor Workspace at no additional charge beyond the AMW.
- **Per-process tier** adds more OTel counters and sends `DetailedMetrics` to Log Analytics, which incurs Log Analytics ingestion and retention charges. Review [Azure Monitor pricing](https://azure.microsoft.com/pricing/details/monitor/) before enabling.

## Choose Your Scenario

| Scenario | Metrics | Resources created | Parameter file |
|----------|---------|-------------------|----------------|
| **Standard, new everything** | Free | AMW + DCR | `standard-new-amw-new-dcr` |
| **Standard, existing AMW** | Free | DCR only | `standard-existing-amw-new-dcr` |
| **Reuse existing DCR** | Free | DCRA + AMA only (fastest) | `existing-dcr` |
| **Standard + alerts** | Free | AMW + DCR + 8 alert rules | `standard-new-amw-with-alerts` |
| **Per-process, new everything + alerts** | Paid | AMW + LA + DCR + 8 alert rules | `per-process-new-all-with-alerts` |
| **Per-process, existing infra** | Paid | DCR only (reuses AMW + LA) | `per-process-existing-amw-existing-la` |

## Prerequisites

- **Azure subscription** with Contributor role (or equivalent) to create resources
- **Azure CLI** v2.20+ ([install guide](https://learn.microsoft.com/cli/azure/install-azure-cli)), which includes Bicep support
- **An existing VM** to onboard
- **All referenced resource groups** must already exist (the template does not create them)
- If enabling alerts:
  1. Create a [User-Assigned Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities):
     ```bash
     az identity create --name <UAMI_NAME> --resource-group <RG> --location <LOCATION>
     ```
  2. Grant it **Monitoring Reader** on the Azure Monitor Workspace:
     ```bash
     # Get the UAMI principal ID
     UAMI_PRINCIPAL_ID=$(az identity show --name <UAMI_NAME> --resource-group <RG> --query principalId -o tsv)

     # Assign Monitoring Reader on the AMW
     az role assignment create \
       --assignee-object-id $UAMI_PRINCIPAL_ID \
       --assignee-principal-type ServicePrincipal \
       --role "Monitoring Reader" \
       --scope <AMW_RESOURCE_ID>
     ```

## Deploy

### Step 1: Fill in parameters

Copy the parameter file for your scenario and replace all `<PLACEHOLDER>` values:

```jsonc
// Example: parameters/standard-new-amw-new-dcr.parameters.json
{
    "parameters": {
        "vmName":           { "value": "my-vm" },
        "vmResourceGroup":  { "value": "my-rg" },
        "vmSubscriptionId": { "value": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" },
        "location":         { "value": "eastus2" },
        "osType":           { "value": "Linux" },
        "createNewAmw":     { "value": true },
        "amwName":          { "value": "my-amw" },
        "createNewDcr":     { "value": true }
    }
}
```

### Step 2: Run the deployment

#### ARM template (Azure CLI)

```bash
az deployment group create \
  --resource-group <VM_RESOURCE_GROUP> \
  --template-file vmi-v2-onboard.json \
  --parameters @parameters/standard-new-amw-new-dcr.parameters.json
```

> **Why `az deployment group create`?** The ARM JSON template is deployed at resource-group scope. It uses nested `Microsoft.Resources/deployments` with explicit `subscriptionId` and `resourceGroup` on each resource to place them in the correct resource groups (VM RG, AMW RG, DCR RG, etc.). The `--resource-group` value is simply the parent deployment's home resource group. Use the VM resource group.

#### ARM template (PowerShell)

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName <VM_RESOURCE_GROUP> `
  -TemplateFile vmi-v2-onboard.json `
  -TemplateParameterFile parameters\standard-new-amw-new-dcr.parameters.json
```

#### Bicep

```bash
az deployment sub create \
  --location <LOCATION> \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/standard-new-amw-new-dcr.bicepparam
```

> **Why `az deployment sub create`?** The Bicep template uses `targetScope = 'subscription'` because its modules deploy into potentially different resource groups. This requires a subscription-level deployment.

#### Inline parameters (no parameter file)

```bash
az deployment group create \
  --resource-group my-rg \
  --template-file vmi-v2-onboard.json \
  --parameters vmName=my-vm vmResourceGroup=my-rg \
               vmSubscriptionId=$(az account show --query id -o tsv) \
               location=eastus2 osType=Linux \
               createNewAmw=true amwName=my-amw \
               createNewDcr=true
```

> **ARM and Bicep deploy the same resources.** The only operational difference is deployment scope: ARM JSON is orchestrated from a resource-group deployment using nested deployments, while Bicep is authored at subscription scope because its modules target multiple resource groups.

### Step 3: Verify

After deployment, confirm onboarding succeeded:

```bash
# Check AMA extension is installed (use AzureMonitorWindowsAgent for Windows VMs)
az vm extension show \
  --resource-group <VM_RG> --vm-name <VM_NAME> \
  --name AzureMonitorLinuxAgent \
  --query "{name:name, status:provisioningState}" -o table

# Check the DCR association exists
az monitor data-collection rule association list \
  --resource "/subscriptions/<SUB>/resourceGroups/<VM_RG>/providers/Microsoft.Compute/virtualMachines/<VM_NAME>" \
  --query "[].{name:name, ruleId:dataCollectionRuleId}" -o table
```

In the Azure portal:
- **VM > Extensions**: AMA extension should show "Provisioning succeeded"
- **VM > Monitoring > Data collection rules**: DCR association should appear
- **Azure Monitor > Metrics** (AMW): OTel metrics should appear within ~5 minutes
- If per-process: **Log Analytics workspace > Logs**: query `InsightsMetrics | take 10`
- If alerts: **Monitor > Alerts > Alert rules**: 8 alert rules should be listed

## Common Scenarios

### Onboard multiple VMs to the same DCR

Deploy the first VM with a new DCR, then reuse it for additional VMs:

```bash
# First VM, creates AMW + DCR
az deployment group create --resource-group my-rg \
  --template-file vmi-v2-onboard.json \
  --parameters @parameters/standard-new-amw-new-dcr.parameters.json

# Subsequent VMs, reuse the existing DCR
az deployment group create --resource-group my-rg \
  --template-file vmi-v2-onboard.json \
  --parameters vmName=vm-2 vmResourceGroup=my-rg \
               vmSubscriptionId=xxxx location=eastus2 osType=Linux \
               createNewAmw=false createNewDcr=false \
               existingDcrId="/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Insights/dataCollectionRules/msvmi-eastus2-vm-1"
```

### Onboard a Windows VM with per-process metrics and alerts

```bash
az deployment group create --resource-group my-rg \
  --template-file vmi-v2-onboard.json \
  --parameters vmName=my-windows-vm vmResourceGroup=my-rg \
               vmSubscriptionId=xxxx location=eastus2 osType=Windows \
               createNewAmw=true amwName=my-amw \
               createNewLogAnalyticsWorkspace=true logAnalyticsWorkspaceName=my-la \
               createNewDcr=true enablePerProcessMetrics=true \
               enableAlerts=true \
               uamiResourceId="/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-uami"
```

## Parameter Reference

### Required (always)

| Parameter | Type | Description |
|-----------|------|-------------|
| `vmName` | string | Name of the existing VM to onboard |
| `vmResourceGroup` | string | Resource group containing the VM |
| `vmSubscriptionId` | string | Subscription ID of the VM |
| `location` | string | Azure region, must match the VM (e.g. `eastus2`) |

### VM & Identity

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `osType` | string | `Linux` | `Windows` or `Linux`, determines the AMA extension type |
| `enableSystemAssignedIdentity` | bool | `true` | Enable system-assigned managed identity (required by AMA) |
| `identityType` | string | `SystemAssigned` | Use `SystemAssigned, UserAssigned` if the VM already has user-assigned identities |

> ⚠️ **Warning:** Setting `identityType=SystemAssigned` on a VM that already uses user-assigned identities may disrupt existing identity configuration. Use `SystemAssigned, UserAssigned` to preserve existing UAMIs.

### Azure Monitor Workspace

| Parameter | Type | Default | Required when |
|-----------|------|---------|---------------|
| `createNewAmw` | bool | `false` | n/a |
| `amwName` | string | `""` | `createNewAmw=true` |
| `amwResourceGroup` | string | VM RG | `createNewAmw=true` (optional, defaults to VM RG) |
| `existingAmwResourceId` | string | `""` | `createNewAmw=false` AND `createNewDcr=true` |

### Log Analytics Workspace

Only relevant when `enablePerProcessMetrics=true`.

| Parameter | Type | Default | Required when |
|-----------|------|---------|---------------|
| `createNewLogAnalyticsWorkspace` | bool | `false` | n/a |
| `logAnalyticsWorkspaceName` | string | `""` | `enablePerProcessMetrics=true` AND `createNewLogAnalyticsWorkspace=true` |
| `logAnalyticsResourceGroup` | string | VM RG | (optional, defaults to VM RG) |
| `existingLogAnalyticsWorkspaceId` | string | `""` | `enablePerProcessMetrics=true` AND `createNewLogAnalyticsWorkspace=false` |

### Data Collection Rule

| Parameter | Type | Default | Required when |
|-----------|------|---------|---------------|
| `createNewDcr` | bool | `true` | n/a |
| `dcrName` | string | `msvmi-{location}-{vmName}` | `createNewDcr=true` (optional, has default) |
| `dcrResourceGroup` | string | VM RG | `createNewDcr=true` (optional, defaults to VM RG) |
| `existingDcrId` | string | `""` | `createNewDcr=false` |

> ⚠️ **Existing DCR requirements:** When reusing an existing DCR, it must already be configured for VM Insights V2. For standard metrics, the DCR must include `performanceCountersOTel` with stream `Microsoft-OtelPerfMetrics` and an AMW destination. For per-process metrics, it must also include the relevant `process.*` counters and a Log Analytics destination for `InsightsMetrics`. The DCR must be in the same region as the VM.

### Metrics & Alerts

| Parameter | Type | Default | Required when |
|-----------|------|---------|---------------|
| `enablePerProcessMetrics` | bool | `false` | n/a |
| `enableAlerts` | bool | `false` | n/a |
| `uamiResourceId` | string | `""` | `enableAlerts=true` |

## What Gets Deployed

### Standard (free) tier

```
VM ← AMA Extension
VM ← DCRA (VirtualMachineInsightsExtension)
     └── DCR (performanceCountersOTel)
              10 system.* OTel metrics → AMW
```

**OTel counters:** `system.cpu.time`, `system.memory.usage`, `system.disk.io`, `system.disk.operations`, `system.disk.operation_time`, `system.filesystem.usage`, `system.network.io`, `system.network.dropped`, `system.network.errors`, `system.uptime`

### Per-process (paid) tier

```
VM ← AMA Extension
VM ← DCRA (VirtualMachineInsightsExtension)
     └── DCR (combined)
              ├── performanceCountersOTel
              │     25+ counters (system.* + process.*) → AMW
              └── performanceCounters
                    \VmInsights\DetailedMetrics → LA Workspace
```

**Additional per-process counters:** `process.uptime`, `process.cpu.time`, `process.cpu.utilization`, `process.memory.usage`, `process.memory.virtual`, `process.memory.utilization`, `process.disk.io`, `process.disk.operations`, `process.paging.faults`, `process.open_file_descriptors`, `process.threads`, `process.handles`, `process.context_switches`, `process.signals_pending`, `system.processes.count`, `system.processes.created`

### Alert rules (when enabled)

| Alert | Type | Condition |
|-------|------|-----------|
| **VM Availability** | Platform metric | Availability < 1 over 5 min |
| **Guest OS CPU Usage** | PromQL | CPU utilization > 80% over 5 min |
| **Guest OS Memory Usage** | PromQL | Available memory < 1 GB over 5 min |
| **Guest OS Disk IOPS** | PromQL | Disk operations > 5000/sec over 5 min |
| **Guest OS Network In** | PromQL | Inbound traffic > 100 GB/day |
| **Guest OS Network Out** | PromQL | Outbound traffic > 50 GB/day |
| **Guest OS Network Errors** | PromQL | Network errors > 10 in 5 min |
| **Guest OS Disk Operation Time** | PromQL | Avg disk op time > 100ms over 5 min |

All guest OS alerts use a 2-minute failing period and auto-resolve after 2 minutes. VM Availability is a platform metric alert (no UAMI needed); all guest OS alerts use PromQL and require a UAMI with Monitoring Reader on the AMW.

> ⚠️ **No notifications by default.** Alert rules are created without action groups, so no email/SMS/webhook notifications are sent when alerts fire. To receive notifications, [attach an action group](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups) to each alert rule after deployment, or extend the template to include action group references.

## ARM vs Bicep: Which to Use?

| | ARM (`vmi-v2-onboard.json`) | Bicep (`bicep/main.bicep`) |
|---|---|---|
| **Best for** | Portal "Deploy a custom template", REST API, existing ARM pipelines | Azure CLI, CI/CD pipelines, composing into larger deployments |
| **Single file** | ✅ One JSON file | ❌ Main + 8 modules |
| **Readability** | Verbose JSON | Concise, commented |
| **Extensibility** | Edit one large file | Add/swap modules independently |

The Bicep modules in `bicep/modules/` can also be referenced individually from your own Bicep templates if you only need specific pieces (e.g., just the DCR or just the alerts).

## Repository Structure

```
├── vmi-v2-onboard.json                    # ARM: parameterized template
├── parameters/                            # ARM: parameter files for common scenarios
│   ├── standard-new-amw-new-dcr.parameters.json
│   ├── standard-existing-amw-new-dcr.parameters.json
│   ├── existing-dcr.parameters.json
│   ├── standard-new-amw-with-alerts.parameters.json
│   ├── per-process-new-all-with-alerts.parameters.json
│   └── per-process-existing-amw-existing-la.parameters.json
├── bicep/                                 # Bicep: modular equivalent
│   ├── main.bicep                         #   orchestrator
│   ├── modules/                           #   individual resource modules
│   │   ├── vm-identity.bicep
│   │   ├── amw.bicep
│   │   ├── log-analytics.bicep
│   │   ├── dcr-standard.bicep
│   │   ├── dcr-per-process.bicep
│   │   ├── dcra.bicep
│   │   ├── ama-extension.bicep
│   │   ├── alert-host.bicep
│   │   └── alert-guest.bicep
│   └── parameters/                        #   .bicepparam files
│       └── (same scenarios as ARM)
└── README.md
```
