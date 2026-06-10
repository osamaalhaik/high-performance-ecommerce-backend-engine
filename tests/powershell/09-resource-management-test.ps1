param(
    [string]$BaseUrl = "http://localhost:9090",
    [int]$ConcurrentOrders = 6
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\09-resource-management | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

function Invoke-WebRequestSafe {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )

    try {
        if ($Body -ne $null) {
            $json = $Body | ConvertTo-Json -Depth 20
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -ContentType "application/json" -Body $json -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -UseBasicParsing
        }

        $parsed = $null

        if ($response.Content -ne $null -and $response.Content.Trim().Length -gt 0) {
            $parsed = $response.Content | ConvertFrom-Json
        }

        return [pscustomobject]@{
            success = $true
            httpStatus = [int]$response.StatusCode
            body = $parsed
            rawBody = $response.Content
            errorMessage = $null
        }
    } catch {
        $status = $null
        $rawBody = ""
        $parsed = $null
        $message = $_.Exception.Message

        if ($_.Exception.Response -ne $null) {
            $status = [int]$_.Exception.Response.StatusCode

            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $rawBody = $reader.ReadToEnd()

                if ($rawBody.Trim().Length -gt 0) {
                    $parsed = $rawBody | ConvertFrom-Json
                    if ($parsed.message -ne $null) {
                        $message = $parsed.message
                    }
                }
            } catch {
                $message = $_.Exception.Message
            }
        }

        return [pscustomobject]@{
            success = $false
            httpStatus = $status
            body = $parsed
            rawBody = $rawBody
            errorMessage = $message
        }
    }
}

function Get-MetricSafe {
    param(
        [string]$Name
    )

    try {
        $metric = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/metrics/$Name"

        return [pscustomobject]@{
            name = $Name
            available = $true
            metric = $metric
            errorMessage = $null
        }
    } catch {
        return [pscustomobject]@{
            name = $Name
            available = $false
            metric = $null
            errorMessage = $_.Exception.Message
        }
    }
}

function Get-SelectedMetrics {
    $names = @(
        "jvm.threads.live",
        "jvm.threads.daemon",
        "jvm.threads.peak",
        "http.server.requests",
        "hikaricp.connections.active",
        "hikaricp.connections.idle",
        "hikaricp.connections.max",
        "system.cpu.usage",
        "process.cpu.usage",
        "executor.active",
        "executor.pool.size",
        "executor.queue.remaining"
    )

    $result = @()

    foreach ($name in $names) {
        $result += Get-MetricSafe -Name $name
    }

    return $result
}

$healthBefore = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"
$metricsIndexBefore = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/metrics"
$selectedMetricsBefore = Get-SelectedMetrics

$asyncConfigPath = "src\main\java\com\ecommerce\config\AsyncConfig.java"
$applicationConfigPath = "src\main\resources\application.yml"

$asyncConfigText = ""
$applicationConfigText = ""

if (Test-Path $asyncConfigPath) {
    $asyncConfigText = Get-Content $asyncConfigPath -Raw
}

if (Test-Path $applicationConfigPath) {
    $applicationConfigText = Get-Content $applicationConfigPath -Raw
}

$unique = Get-Date -Format "yyyyMMddHHmmssfff"

$adminLogin = Invoke-JsonPost -Uri "$BaseUrl/api/auth/login" -Body @{
    email = "admin@test.com"
    password = "Admin123456"
}

$adminHeaders = @{
    Authorization = "Bearer $($adminLogin.data.token)"
    "Content-Type" = "application/json"
}

$initialStock = $ConcurrentOrders + 4

$product = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
    name = "Resource Management Product $unique"
    description = "Resource management verification product"
    price = 3.0
    stockQuantity = $initialStock
}

$productId = $product.data.id
$tokens = @()

for ($i = 1; $i -le $ConcurrentOrders; $i++) {
    $customer = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "resource-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Resource Test Customer $i"
    }

    $tokens += $customer.data.token
}

$jobs = @()

for ($i = 1; $i -le $ConcurrentOrders; $i++) {
    $token = $tokens[$i - 1]

    $jobs += Start-Job -ScriptBlock {
        param(
            [string]$BaseUrl,
            [string]$Token,
            [string]$ProductId,
            [int]$Index
        )

        $headers = @{
            Authorization = "Bearer $Token"
            "Content-Type" = "application/json"
        }

        $body = @{
            items = @(
                @{
                    productId = $ProductId
                    quantity = 1
                }
            )
        } | ConvertTo-Json -Depth 20

        $watch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $response = Invoke-WebRequest -Method Post -Uri "$BaseUrl/api/orders" -ContentType "application/json" -Headers $headers -Body $body -UseBasicParsing
            $watch.Stop()
            $json = $response.Content | ConvertFrom-Json

            [pscustomobject]@{
                index = $Index
                success = $true
                httpStatus = [int]$response.StatusCode
                orderId = $json.data.orderId
                orderStatus = $json.data.status
                elapsedMs = $watch.ElapsedMilliseconds
                errorMessage = $null
            }
        } catch {
            $watch.Stop()

            [pscustomobject]@{
                index = $Index
                success = $false
                httpStatus = $null
                orderId = $null
                orderStatus = $null
                elapsedMs = $watch.ElapsedMilliseconds
                errorMessage = $_.Exception.Message
            }
        }
    } -ArgumentList $BaseUrl, $token, $productId, $i
}

Start-Sleep -Milliseconds 500

$selectedMetricsDuring = Get-SelectedMetrics

$orderResults = Receive-Job -Job $jobs -Wait
Remove-Job -Job $jobs

$orderedResults = @($orderResults | Sort-Object index)

$healthAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"
$metricsIndexAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/metrics"
$selectedMetricsAfter = Get-SelectedMetrics
$finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"

$healthBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\01-health-before.json
$metricsIndexBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\02-metrics-index-before.json
$selectedMetricsBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\03-selected-metrics-before.json
$product | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\04-product-created.json
$selectedMetricsDuring | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\05-selected-metrics-during-load.json
$orderedResults | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\06-order-results.json
$selectedMetricsAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\07-selected-metrics-after.json
$healthAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\08-health-after.json
$finalProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\09-final-product-state.json
$asyncConfigText | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\10-async-config-source.txt
$applicationConfigText | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\11-application-config-source.txt

$successfulOrders = @($orderedResults | Where-Object { $_.success -eq $true -and $_.httpStatus -ge 200 -and $_.httpStatus -lt 300 }).Count
$failedOrders = @($orderedResults | Where-Object { $_.success -ne $true }).Count
$ordersSucceeded = ($successfulOrders -eq $ConcurrentOrders -and $failedOrders -eq 0)

$expectedFinalStock = $initialStock - $successfulOrders
$actualFinalStock = [int]$finalProduct.data.stockQuantity
$productStockConsistent = ($actualFinalStock -eq $expectedFinalStock)

$metricCountBefore = @($metricsIndexBefore.names).Count
$metricCountAfter = @($metricsIndexAfter.names).Count
$metricsEndpointAvailable = ($metricCountBefore -gt 0 -and $metricCountAfter -gt 0)

$threadMetricAvailable = (@($selectedMetricsAfter | Where-Object { $_.name -eq "jvm.threads.live" -and $_.available -eq $true }).Count -eq 1)
$httpMetricAvailable = (@($selectedMetricsAfter | Where-Object { $_.name -eq "http.server.requests" -and $_.available -eq $true }).Count -eq 1)

$healthBeforeUp = ($healthBefore.status -eq "UP")
$healthAfterUp = ($healthAfter.status -eq "UP")
$dbHealthVisible = ($healthAfter.components.db.status -eq "UP")
$redisHealthVisible = ($healthAfter.components.redis.status -eq "UP")

$asyncThreadPoolConfigured = ($asyncConfigText.Contains("ThreadPoolTaskExecutor") -and $asyncConfigText.Contains("setCorePoolSize") -and $asyncConfigText.Contains("setMaxPoolSize") -and $asyncConfigText.Contains("setQueueCapacity"))
$resourceRequirementSatisfied = ($healthBeforeUp -and $healthAfterUp -and $dbHealthVisible -and $redisHealthVisible -and $metricsEndpointAvailable -and $threadMetricAvailable -and $httpMetricAvailable -and $asyncThreadPoolConfigured -and $ordersSucceeded -and $productStockConsistent)

$summary = [ordered]@{
    testName = "Resource management and capacity control verification test"
    baseUrl = $BaseUrl
    concurrentOrders = $ConcurrentOrders
    productId = $productId
    initialStock = $initialStock
    successfulOrders = $successfulOrders
    failedOrders = $failedOrders
    expectedFinalStock = $expectedFinalStock
    actualFinalStock = $actualFinalStock
    ordersSucceeded = $ordersSucceeded
    productStockConsistent = $productStockConsistent
    healthBeforeUp = $healthBeforeUp
    healthAfterUp = $healthAfterUp
    dbHealthVisible = $dbHealthVisible
    redisHealthVisible = $redisHealthVisible
    metricCountBefore = $metricCountBefore
    metricCountAfter = $metricCountAfter
    metricsEndpointAvailable = $metricsEndpointAvailable
    threadMetricAvailable = $threadMetricAvailable
    httpMetricAvailable = $httpMetricAvailable
    asyncThreadPoolConfigured = $asyncThreadPoolConfigured
    minOrderElapsedMs = [int](($orderedResults | Measure-Object elapsedMs -Minimum).Minimum)
    maxOrderElapsedMs = [int](($orderedResults | Measure-Object elapsedMs -Maximum).Maximum)
    avgOrderElapsedMs = [math]::Round((($orderedResults | Measure-Object elapsedMs -Average).Average), 2)
    resourceRequirementSatisfied = $resourceRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\09-resource-management\12-resource-management-summary.json

if (-not $resourceRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\09-resource-management\12-resource-management-summary.json
    throw "Resource management and capacity control verification test failed"
}

Get-Content docs\evidence\step-02-tests\09-resource-management\12-resource-management-summary.json