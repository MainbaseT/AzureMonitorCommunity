<#
.SYNOPSIS
    Generates synthetic Apache Combined Log Format access log data for use with
    the Azure Monitor Logs Ingestion API tutorial.

.DESCRIPTION
    Creates a sample_access.log file with realistic but fully synthetic entries.
    All IP addresses, domains, paths, and user agents are fabricated — no real
    PII is included.

    The output matches the Apache Combined Log Format expected by the tutorial's
    KQL parse transformation:
      IP - - [timestamp] "METHOD /path HTTP/1.1" status size "referer" "user-agent" "-"

.PARAMETER Count
    Number of log entries to generate. Default: 200.

.PARAMETER Output
    Path to the output file. Default: sample_access.log in the current directory.

.PARAMETER StartDate
    Starting timestamp for log entries. Default: 2024-03-15T08:00:00.

.EXAMPLE
    .\Generate-SampleAccessLog.ps1
    .\Generate-SampleAccessLog.ps1 -Count 500 -Output "my_access.log"
    .\Generate-SampleAccessLog.ps1 -Count 100 -StartDate "2024-06-01T12:00:00"
#>
param(
    [int]$Count = 200,
    [string]$Output = "sample_access.log",
    [datetime]$StartDate = [datetime]"2024-03-15T08:00:00"
)

# --- Pools of synthetic values ---

$methods = @("GET", "GET", "GET", "GET", "GET", "POST", "PUT", "DELETE", "HEAD")
$httpVersions = @("HTTP/1.1", "HTTP/1.1", "HTTP/1.1", "HTTP/2.0")

$paths = @(
    "/"
    "/index.html"
    "/about.html"
    "/contact.html"
    "/products"
    "/products/catalog"
    "/products/details?id=1042"
    "/products/details?id=2087"
    "/products/details?id=3291"
    "/api/v1/status"
    "/api/v1/health"
    "/api/v1/users"
    "/api/v1/orders"
    "/api/v1/inventory"
    "/api/v2/search?q=monitor"
    "/api/v2/search?q=logs"
    "/images/logo.png"
    "/images/banner.jpg"
    "/images/hero-bg.webp"
    "/css/main.css"
    "/css/theme.css"
    "/js/app.js"
    "/js/analytics.js"
    "/fonts/opensans.woff2"
    "/favicon.ico"
    "/robots.txt"
    "/sitemap.xml"
    "/docs/getting-started"
    "/docs/api-reference"
    "/docs/faq"
    "/blog/2024/new-features"
    "/blog/2024/performance-tips"
    "/login"
    "/dashboard"
    "/dashboard/settings"
    "/admin/reports"
    "/admin/users"
    "/download/latest"
    "/pricing"
    "/support/tickets"
    "/support/kb/1001"
    "/support/kb/2045"
)

# Weighted status codes: mostly 200, some errors
$statusWeights = @(
    @{ Code = 200; Weight = 65 }
    @{ Code = 301; Weight = 3 }
    @{ Code = 302; Weight = 2 }
    @{ Code = 304; Weight = 8 }
    @{ Code = 400; Weight = 3 }
    @{ Code = 401; Weight = 3 }
    @{ Code = 403; Weight = 3 }
    @{ Code = 404; Weight = 8 }
    @{ Code = 500; Weight = 3 }
    @{ Code = 502; Weight = 1 }
    @{ Code = 503; Weight = 1 }
)

# Build expanded status array for weighted random selection
$statusPool = @()
foreach ($s in $statusWeights) {
    for ($i = 0; $i -lt $s.Weight; $i++) {
        $statusPool += $s.Code
    }
}

$userAgents = @(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0'
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15'
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0'
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.64 Mobile Safari/537.36'
    'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36'
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1'
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/122.0.6261.62 Mobile/15E148 Safari/604.1'
    'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1'
    'Mozilla/5.0 (compatible; ContosoBot/1.0; +https://contoso.example.com/bot)'
    'Mozilla/5.0 (compatible; ExampleSearchBot/1.0; +https://search.example.com/bot)'
    'Mozilla/5.0 (compatible; ExampleCrawler/1.0; +https://crawler.example.com/bot)'
    'curl/8.5.0'
    'Python-urllib/3.12'
    'axios/1.6.7'
)

$referers = @(
    "-"
    "-"
    "-"
    "-"
    "https://www.contoso-web.example.com/"
    "https://www.contoso-web.example.com/products"
    "https://www.contoso-web.example.com/docs/getting-started"
    "https://www.contoso-web.example.com/blog/2024/new-features"
    "https://search.contoso.example.com/results?q=monitor+logs"
    "https://portal.contoso.example.com/dashboard"
)

# --- Helper functions ---

function Get-SeededRandomInt {
    param([int]$Minimum, [int]$Maximum)
    return $script:Random.Next($Minimum, $Maximum) # Maximum is exclusive (matches Get-Random)
}

function Get-SeededRandomItem {
    param([object[]]$Items)
    return $Items[$script:Random.Next(0, $Items.Count)]
}

function Get-SyntheticIP {
    # RFC 5737 documentation-range IPs (198.51.100.0/24, 203.0.113.0/24)
    $prefix = Get-SeededRandomItem @("198.51.100", "203.0.113")
    return "$prefix.$(Get-SeededRandomInt -Minimum 1 -Maximum 255)"
}

function Get-ResponseSize {
    param([int]$StatusCode, [string]$Path)
    switch ($StatusCode) {
        304 { return 0 }
        { $_ -ge 400 } { return Get-SeededRandomInt -Minimum 150 -Maximum 600 }
        default {
            if ($Path -match '\.(png|jpg|webp|woff2)$') { return Get-SeededRandomInt -Minimum 5000 -Maximum 150000 }
            if ($Path -match '\.(css|js)$') { return Get-SeededRandomInt -Minimum 800 -Maximum 45000 }
            if ($Path -match '^/api/') { return Get-SeededRandomInt -Minimum 50 -Maximum 8000 }
            return Get-SeededRandomInt -Minimum 1200 -Maximum 35000
        }
    }
}

# --- Generate entries ---

$random = [System.Random]::new(42)  # Fixed seed for reproducibility
$entries = [System.Collections.Generic.List[string]]::new($Count)
$currentTime = $StartDate

for ($i = 0; $i -lt $Count; $i++) {
    $ip = Get-SyntheticIP
    $method = $methods | Get-Random
    $path = $paths | Get-Random
    $httpVersion = $httpVersions | Get-Random
    $status = $statusPool | Get-Random
    $size = Get-ResponseSize -StatusCode $status -Path $path
    $ua = $userAgents | Get-Random
    $referer = $referers | Get-Random

    # Format timestamp as Apache CLF: [dd/Mon/yyyy:HH:mm:ss +0000]
    $ts = $currentTime.ToString("dd/MMM/yyyy:HH:mm:ss +0000", [System.Globalization.CultureInfo]::InvariantCulture)

    $entry = '{0} - - [{1}] "{2} {3} {4}" {5} {6} "{7}" "{8}" "-"' -f `
        $ip, $ts, $method, $path, $httpVersion, $status, $size, $referer, $ua

    $entries.Add($entry)

    # Advance time by 1-90 seconds
    $currentTime = $currentTime.AddSeconds((Get-Random -Minimum 1 -Maximum 91))
}

# --- Write output ---

$entries | Set-Content -Path $Output -Encoding UTF8
Write-Host "Generated $Count synthetic Apache access log entries in: $Output"
