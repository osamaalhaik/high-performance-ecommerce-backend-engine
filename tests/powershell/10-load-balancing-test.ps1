param(
    [string]$BaseUrl = "http://localhost:9090",
    [int]$Requests = 12
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\10-load-balancing | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

$nginxPath = "infra\nginx\nginx.conf"
$loadBalancerConfigPath = "src\main\java\com\ecommerce\config\LoadBalancerConfig.java"

$nginxText = ""
$loadBalancerConfigText = ""

if (Test-Path $nginxPath) {
    $nginxText = Get-Content $nginxPath -Raw
}

if (Test-Path $loadBalancerConfigPath) {
    $loadBalancerConfigText = Get-Content $loadBalancerConfigPath -Raw
}

$adminLogin = Invoke-JsonPost -Uri "$BaseUrl/api/auth/login" -Body @{
    email = "admin@test.com"
    password = "Admin123456"
}

$adminHeaders = @{
    Authorization = "Bearer $($adminLogin.data.token)"
    "Content-Type" = "application/json"
}

$instanceInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/instance"

$selections = @()

for ($i = 1; $i -le $Requests; $i++) {
    $response = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/lb/next" -Headers $adminHeaders

    $selections += [pscustomobject]@{
        index = $i
        success = $response.success
        selectedServer = $response.data
        message = $response.message
    }
}

$distribution = $selections |
    Group-Object selectedServer |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            server = $_.Name
            count = $_.Count
        }
    }

$counts = @($distribution | ForEach-Object { $_.count })
$uniqueServerCount = @($distribution).Count
$totalSelections = @($selections).Count

$maxCount = 0
$minCount = 0

if ($counts.Count -gt 0) {
    $maxCount = [int](($counts | Measure-Object -Maximum).Maximum)
    $minCount = [int](($counts | Measure-Object -Minimum).Minimum)
}

$nginxConfigExists = (Test-Path $nginxPath)
$nginxUpstreamConfigured = ($nginxText.Contains("upstream") -and $nginxText.Contains("proxy_pass") -and $nginxText.Contains("weight="))
$nginxMultipleBackendsConfigured = (($nginxText -split "`n" | Where-Object { $_.Contains("127.0.0.1:909") -or $_.Contains("server ") }).Count -ge 3)

$loadBalancerConfigExists = (Test-Path $loadBalancerConfigPath)
$weightedRoundRobinCodeExists = ($loadBalancerConfigText.Contains("WeightedRoundRobin") -or $loadBalancerConfigText.Contains("weight"))
$endpointReturnedMultipleServers = ($uniqueServerCount -ge 3)
$weightedDistributionObserved = ($maxCount -gt $minCount)
$allSelectionsSuccessful = (@($selections | Where-Object { $_.success -eq $true }).Count -eq $Requests)

$loadBalancingRequirementSatisfied = ($nginxConfigExists -and $nginxUpstreamConfigured -and $nginxMultipleBackendsConfigured -and $loadBalancerConfigExists -and $weightedRoundRobinCodeExists -and $endpointReturnedMultipleServers -and $weightedDistributionObserved -and $allSelectionsSuccessful)

$instanceInfo | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\01-instance-info.json
$selections | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\02-load-balancer-selections.json
$distribution | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\03-load-balancer-distribution.json
$nginxText | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\04-nginx-config-source.txt
$loadBalancerConfigText | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\05-load-balancer-config-source.txt

$summary = [ordered]@{
    testName = "Load balancing and scaling strategy verification test"
    baseUrl = $BaseUrl
    requests = $Requests
    totalSelections = $totalSelections
    uniqueServerCount = $uniqueServerCount
    maxServerSelectionCount = $maxCount
    minServerSelectionCount = $minCount
    allSelectionsSuccessful = $allSelectionsSuccessful
    endpointReturnedMultipleServers = $endpointReturnedMultipleServers
    weightedDistributionObserved = $weightedDistributionObserved
    nginxConfigExists = $nginxConfigExists
    nginxUpstreamConfigured = $nginxUpstreamConfigured
    nginxMultipleBackendsConfigured = $nginxMultipleBackendsConfigured
    loadBalancerConfigExists = $loadBalancerConfigExists
    weightedRoundRobinCodeExists = $weightedRoundRobinCodeExists
    currentInstanceName = $instanceInfo.data.instanceName
    currentInstancePort = $instanceInfo.data.serverPort
    loadBalancingRequirementSatisfied = $loadBalancingRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\10-load-balancing\06-load-balancing-summary.json

if (-not $loadBalancingRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\10-load-balancing\06-load-balancing-summary.json
    throw "Load balancing and scaling strategy verification test failed"
}

Get-Content docs\evidence\step-02-tests\10-load-balancing\06-load-balancing-summary.json