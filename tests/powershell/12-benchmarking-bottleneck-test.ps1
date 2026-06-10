param(
    [string]$BaseUrl = "http://localhost:9090",
    [string]$RedisHost = "127.0.0.1",
    [int]$RedisPort = 6379,
    [int]$ReadIterations = 20,
    [int]$OrderIterations = 10
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\12-benchmarking-bottleneck | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

function Invoke-TimedRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if ($Body -ne $null) {
            $json = $Body | ConvertTo-Json -Depth 20
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -ContentType "application/json" -Body $json -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -UseBasicParsing
        }

        $watch.Stop()

        $parsed = $null

        if ($response.Content -ne $null -and $response.Content.Trim().Length -gt 0) {
            $parsed = $response.Content | ConvertFrom-Json
        }

        return [pscustomobject]@{
            success = $true
            httpStatus = [int]$response.StatusCode
            elapsedMs = $watch.ElapsedMilliseconds
            body = $parsed
            errorMessage = $null
        }
    } catch {
        $watch.Stop()

        $status = $null
        $message = $_.Exception.Message

        if ($_.Exception.Response -ne $null) {
            $status = [int]$_.Exception.Response.StatusCode
        }

        return [pscustomobject]@{
            success = $false
            httpStatus = $status
            elapsedMs = $watch.ElapsedMilliseconds
            body = $null
            errorMessage = $message
        }
    }
}

function Invoke-RedisSimple {
    param(
        [string[]]$Command
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect($RedisHost, $RedisPort)

    try {
        $stream = $client.GetStream()
        $payload = "*" + $Command.Count + "`r`n"

        foreach ($part in $Command) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($part)
            $payload += '$' + $bytes.Length + "`r`n" + $part + "`r`n"
        }

        $outBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $stream.Write($outBytes, 0, $outBytes.Length)
        $stream.Flush()

        $buffer = New-Object byte[] 8192
        $read = $stream.Read($buffer, 0, $buffer.Length)
        [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
    } finally {
        $client.Close()
    }
}

function Invoke-RedisInteger {
    param(
        [string[]]$Command
    )

    $reply = Invoke-RedisSimple -Command $Command
    $line = ($reply -split "`r`n")[0]

    if ($line.StartsWith(":")) {
        return [int]$line.Substring(1)
    }

    throw "Unexpected Redis integer response: $reply"
}

function Average-Elapsed {
    param(
        [object[]]$Samples
    )

    if (@($Samples).Count -eq 0) {
        return 0
    }

    return [math]::Round((($Samples | Measure-Object elapsedMs -Average).Average), 2)
}

function Min-Elapsed {
    param(
        [object[]]$Samples
    )

    if (@($Samples).Count -eq 0) {
        return 0
    }

    return [int](($Samples | Measure-Object elapsedMs -Minimum).Minimum)
}

function Max-Elapsed {
    param(
        [object[]]$Samples
    )

    if (@($Samples).Count -eq 0) {
        return 0
    }

    return [int](($Samples | Measure-Object elapsedMs -Maximum).Maximum)
}

function Improvement-Percent {
    param(
        [double]$Before,
        [double]$After
    )

    if ($Before -le 0) {
        return 0
    }

    return [math]::Round(((($Before - $After) / $Before) * 100), 2)
}

$healthBefore = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"

$unique = Get-Date -Format "yyyyMMddHHmmssfff"

$adminLogin = Invoke-JsonPost -Uri "$BaseUrl/api/auth/login" -Body @{
    email = "admin@test.com"
    password = "Admin123456"
}

$adminHeaders = @{
    Authorization = "Bearer $($adminLogin.data.token)"
    "Content-Type" = "application/json"
}

$product = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
    name = "Benchmark Product $unique"
    description = "Benchmarking and bottleneck analysis product"
    price = 4.0
    stockQuantity = ($OrderIterations + 20)
}

$productId = $product.data.id
$productCacheKey = "products::$productId"
$adminStatsCacheKey = "ecommerce:cache:admin-stats:last24h"

Invoke-RedisInteger -Command @("DEL", $productCacheKey) | Out-Null
Invoke-RedisInteger -Command @("DEL", $adminStatsCacheKey) | Out-Null

$productMiss = Invoke-TimedRequest -Method "GET" -Uri "$BaseUrl/api/products/$productId"

$productHitSamples = @()

for ($i = 1; $i -le $ReadIterations; $i++) {
    $productHitSamples += Invoke-TimedRequest -Method "GET" -Uri "$BaseUrl/api/products/$productId"
}

$productCacheExists = Invoke-RedisInteger -Command @("EXISTS", $productCacheKey)
$productCacheTtl = Invoke-RedisInteger -Command @("TTL", $productCacheKey)

Invoke-RedisInteger -Command @("DEL", $adminStatsCacheKey) | Out-Null

$adminStatsMiss = Invoke-TimedRequest -Method "GET" -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders

$adminStatsHitSamples = @()

for ($i = 1; $i -le $ReadIterations; $i++) {
    $adminStatsHitSamples += Invoke-TimedRequest -Method "GET" -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders
}

$adminStatsCacheExists = Invoke-RedisInteger -Command @("EXISTS", $adminStatsCacheKey)
$adminStatsCacheTtl = Invoke-RedisInteger -Command @("TTL", $adminStatsCacheKey)

$orderSamples = @()

for ($i = 1; $i -le $OrderIterations; $i++) {
    $customer = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "benchmark-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Benchmark Customer $i"
    }

    $customerHeaders = @{
        Authorization = "Bearer $($customer.data.token)"
        "Content-Type" = "application/json"
    }

    $orderSamples += Invoke-TimedRequest -Method "POST" -Uri "$BaseUrl/api/orders" -Headers $customerHeaders -Body @{
        items = @(
            @{
                productId = $productId
                quantity = 1
            }
        )
    }
}

$healthAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"
$finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"

$productHitSuccessfulSamples = @($productHitSamples | Where-Object { $_.success -eq $true -and $_.httpStatus -ge 200 -and $_.httpStatus -lt 300 })
$adminStatsHitSuccessfulSamples = @($adminStatsHitSamples | Where-Object { $_.success -eq $true -and $_.httpStatus -ge 200 -and $_.httpStatus -lt 300 })
$orderSuccessfulSamples = @($orderSamples | Where-Object { $_.success -eq $true -and $_.httpStatus -ge 200 -and $_.httpStatus -lt 300 })

$productMissElapsedMs = [double]$productMiss.elapsedMs
$productHitAvgElapsedMs = Average-Elapsed -Samples $productHitSuccessfulSamples
$productHitMinElapsedMs = Min-Elapsed -Samples $productHitSuccessfulSamples
$productHitMaxElapsedMs = Max-Elapsed -Samples $productHitSuccessfulSamples
$productCacheImprovementPercent = Improvement-Percent -Before $productMissElapsedMs -After $productHitAvgElapsedMs

$adminStatsMissElapsedMs = [double]$adminStatsMiss.elapsedMs
$adminStatsHitAvgElapsedMs = Average-Elapsed -Samples $adminStatsHitSuccessfulSamples
$adminStatsHitMinElapsedMs = Min-Elapsed -Samples $adminStatsHitSuccessfulSamples
$adminStatsHitMaxElapsedMs = Max-Elapsed -Samples $adminStatsHitSuccessfulSamples
$adminStatsCacheImprovementPercent = Improvement-Percent -Before $adminStatsMissElapsedMs -After $adminStatsHitAvgElapsedMs

$orderAvgElapsedMs = Average-Elapsed -Samples $orderSuccessfulSamples
$orderMinElapsedMs = Min-Elapsed -Samples $orderSuccessfulSamples
$orderMaxElapsedMs = Max-Elapsed -Samples $orderSuccessfulSamples

$bottleneckName = "Transactional order creation path"
$bottleneckReason = "Order creation is slower than cached reads because it performs authenticated request validation, wallet balance verification, pessimistic database locks for user wallet and product stock, stock update, order persistence, payment persistence, cache eviction, and Redis queue enqueue operations."

$healthBeforeUp = ($healthBefore.status -eq "UP")
$healthAfterUp = ($healthAfter.status -eq "UP")
$productBenchmarkValid = ($productMiss.success -eq $true -and @($productHitSuccessfulSamples).Count -eq $ReadIterations -and $productCacheExists -eq 1)
$adminStatsBenchmarkValid = ($adminStatsMiss.success -eq $true -and @($adminStatsHitSuccessfulSamples).Count -eq $ReadIterations -and $adminStatsCacheExists -eq 1)
$orderBenchmarkValid = (@($orderSuccessfulSamples).Count -eq $OrderIterations)
$benchmarkRequirementSatisfied = ($healthBeforeUp -and $healthAfterUp -and $productBenchmarkValid -and $adminStatsBenchmarkValid -and $orderBenchmarkValid)

$product | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\01-product-created.json
$productMiss | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\02-product-cache-miss-sample.json
$productHitSamples | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\03-product-cache-hit-samples.json
$adminStatsMiss | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\04-admin-stats-cache-miss-sample.json
$adminStatsHitSamples | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\05-admin-stats-cache-hit-samples.json
$orderSamples | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\06-order-creation-samples.json
$finalProduct | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\07-final-product-state.json

$summary = [ordered]@{
    testName = "Benchmarking and bottleneck analysis verification test"
    baseUrl = $BaseUrl
    readIterations = $ReadIterations
    orderIterations = $OrderIterations
    productId = $productId
    productCacheKey = $productCacheKey
    productCacheExists = $productCacheExists
    productCacheTtl = $productCacheTtl
    productMissElapsedMs = $productMissElapsedMs
    productHitAvgElapsedMs = $productHitAvgElapsedMs
    productHitMinElapsedMs = $productHitMinElapsedMs
    productHitMaxElapsedMs = $productHitMaxElapsedMs
    productCacheImprovementPercent = $productCacheImprovementPercent
    adminStatsCacheKey = $adminStatsCacheKey
    adminStatsCacheExists = $adminStatsCacheExists
    adminStatsCacheTtl = $adminStatsCacheTtl
    adminStatsMissElapsedMs = $adminStatsMissElapsedMs
    adminStatsHitAvgElapsedMs = $adminStatsHitAvgElapsedMs
    adminStatsHitMinElapsedMs = $adminStatsHitMinElapsedMs
    adminStatsHitMaxElapsedMs = $adminStatsHitMaxElapsedMs
    adminStatsCacheImprovementPercent = $adminStatsCacheImprovementPercent
    orderAvgElapsedMs = $orderAvgElapsedMs
    orderMinElapsedMs = $orderMinElapsedMs
    orderMaxElapsedMs = $orderMaxElapsedMs
    successfulProductHitSamples = @($productHitSuccessfulSamples).Count
    successfulAdminStatsHitSamples = @($adminStatsHitSuccessfulSamples).Count
    successfulOrderSamples = @($orderSuccessfulSamples).Count
    healthBeforeUp = $healthBeforeUp
    healthAfterUp = $healthAfterUp
    productBenchmarkValid = $productBenchmarkValid
    adminStatsBenchmarkValid = $adminStatsBenchmarkValid
    orderBenchmarkValid = $orderBenchmarkValid
    bottleneckName = $bottleneckName
    bottleneckReason = $bottleneckReason
    benchmarkRequirementSatisfied = $benchmarkRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\08-benchmark-summary.json

$analysis = @"
# Benchmarking and Bottleneck Analysis

## Numeric Benchmark Summary

- Product cache miss: $productMissElapsedMs ms
- Product cache hit average over $ReadIterations reads: $productHitAvgElapsedMs ms
- Product cache improvement: $productCacheImprovementPercent %

- Admin stats cache miss: $adminStatsMissElapsedMs ms
- Admin stats cache hit average over $ReadIterations reads: $adminStatsHitAvgElapsedMs ms
- Admin stats cache improvement: $adminStatsCacheImprovementPercent %

- Order creation average over $OrderIterations orders: $orderAvgElapsedMs ms
- Order creation min: $orderMinElapsedMs ms
- Order creation max: $orderMaxElapsedMs ms

## Identified Bottleneck

The main bottleneck is: $bottleneckName.

Reason: $bottleneckReason

## Conclusion

Caching reduces repeated read pressure on the database for product reads and admin statistics. The order creation path remains intentionally heavier because it protects shared data integrity through wallet verification, stock locking, transactional persistence, payment handling, cache eviction, and asynchronous queue submission. This bottleneck is acceptable and justified because it protects correctness under concurrency.
"@

$analysis | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\12-benchmarking-bottleneck\09-bottleneck-analysis.md

if (-not $benchmarkRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\12-benchmarking-bottleneck\08-benchmark-summary.json
    throw "Benchmarking and bottleneck analysis verification test failed"
}

Get-Content docs\evidence\step-02-tests\12-benchmarking-bottleneck\08-benchmark-summary.json