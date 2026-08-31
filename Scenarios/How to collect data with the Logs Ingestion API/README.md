# How to collect data with the Logs Ingestion API

The [Logs Ingestion API](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview) lets you send external data to a Log Analytics workspace in Azure Monitor using a REST API call. Use it to ingest custom logs from any source that can make HTTP requests.

## Tutorial

For a complete walkthrough of configuring a custom table, data collection rule (DCR), data collection endpoint (DCE), and sending data with PowerShell, see:

**[Tutorial: Send data to Azure Monitor Logs with Logs ingestion API (Azure portal)](https://learn.microsoft.com/azure/azure-monitor/logs/tutorial-logs-ingestion-portal)**

## Sample data

This folder contains synthetic Apache access log data for use with the tutorial:

| File | Description |
|------|-------------|
| [sample_access.log](sample_access.log) | Pre-generated synthetic Apache access log (~200 entries). Ready to use with the tutorial's `LogGenerator.ps1` script. |
| [Generate-SampleAccessLog.ps1](Generate-SampleAccessLog.ps1) | PowerShell script to generate your own synthetic access log with a configurable number of entries. |

### Using the sample data

1. Download `sample_access.log` from this folder.
1. Follow the [tutorial](https://learn.microsoft.com/azure/azure-monitor/logs/tutorial-logs-ingestion-portal) to set up your DCR, DCE, and custom table.
1. Use the `LogGenerator.ps1` script from the tutorial to convert and send the data:

   ```powershell
   .\LogGenerator.ps1 -Log "sample_access.log" -Type "file" -Output "data_sample.json"
   ```

### Generating your own data

Run `Generate-SampleAccessLog.ps1` to create a custom-sized log file:

```powershell
.\Generate-SampleAccessLog.ps1 -Count 500 -Output "my_access.log"
```

## Why synthetic data?

The sample data in this folder is fully synthetic — no real IP addresses, domains, or user traffic patterns. This avoids privacy concerns that can arise when using real-world access log datasets. The synthetic entries are structured to match standard Apache Combined Log Format so they work with the tutorial's KQL `parse` transformation.
