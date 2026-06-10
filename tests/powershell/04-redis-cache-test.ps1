param(
    [string]$BaseUrl = "http://localhost:9090",
    [string]$RedisHost = "127.0.0.1",
    [int]$RedisPort = 6379
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\04-redis-cache | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
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
    name = "Redis Cache Product $unique"
    description = "Redis cache verification product"
    price = 15.0
    stockQuantity = 30
}

$productId = $product.data.id
$productCacheKey = "products::$productId"
$adminStatsCacheKey = "ecommerce:cache:admin-stats:last24h"

$productCacheDeletedBeforeTest = Invoke-RedisInteger -Command @("DEL", $productCacheKey)
$adminStatsDeletedBeforeTest = Invoke-RedisInteger -Command @("DEL", $adminStatsCacheKey)

$productFirstWatch = [System.Diagnostics.Stopwatch]::StartNew()
$productFirstRead = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"
$productFirstWatch.Stop()

$productExistsAfterFirstRead = Invoke-RedisInteger -Command @("EXISTS", $productCacheKey)
$productTtlAfterFirstRead = Invoke-RedisInteger -Command @("TTL", $productCacheKey)

$productSecondWatch = [System.Diagnostics.Stopwatch]::StartNew()
$productSecondRead = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"
$productSecondWatch.Stop()

$productExistsAfterSecondRead = Invoke-RedisInteger -Command @("EXISTS", $productCacheKey)
$productTtlAfterSecondRead = Invoke-RedisInteger -Command @("TTL", $productCacheKey)

$adminStatsFirstWatch = [System.Diagnostics.Stopwatch]::StartNew()
$adminStatsFirst = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders
$adminStatsFirstWatch.Stop()

$adminStatsExistsAfterFirstRead = Invoke-RedisInteger -Command @("EXISTS", $adminStatsCacheKey)
$adminStatsTtlAfterFirstRead = Invoke-RedisInteger -Command @("TTL", $adminStatsCacheKey)

$adminStatsSecondWatch = [System.Diagnostics.Stopwatch]::StartNew()
$adminStatsSecond = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders
$adminStatsSecondWatch.Stop()

$adminStatsExistsAfterSecondRead = Invoke-RedisInteger -Command @("EXISTS", $adminStatsCacheKey)
$adminStatsTtlAfterSecondRead = Invoke-RedisInteger -Command @("TTL", $adminStatsCacheKey)

$productCacheCreated = ($productExistsAfterFirstRead -eq 1 -and $productTtlAfterFirstRead -gt 0)
$productCacheStillExists = ($productExistsAfterSecondRead -eq 1 -and $productTtlAfterSecondRead -gt 0)

$adminStatsCacheCreated = ($adminStatsExistsAfterFirstRead -eq 1 -and $adminStatsTtlAfterFirstRead -gt 0)
$adminStatsCacheStillExists = ($adminStatsExistsAfterSecondRead -eq 1 -and $adminStatsTtlAfterSecondRead -gt 0)
$adminStatsTimestampEqual = ($adminStatsFirst.data.timestamp -eq $adminStatsSecond.data.timestamp)

$product | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\01-product-created.json
$productFirstRead | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\02-product-first-read.json
$productSecondRead | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\03-product-second-read.json
$adminStatsFirst | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\04-admin-stats-first-read.json
$adminStatsSecond | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\05-admin-stats-second-read.json

$summary = [ordered]@{
    testName = "Redis cache verification test"
    baseUrl = $BaseUrl
    redisHost = $RedisHost
    redisPort = $RedisPort
    productId = $productId
    productCacheKey = $productCacheKey
    productCacheDeletedBeforeTest = $productCacheDeletedBeforeTest
    productFirstReadSuccess = $productFirstRead.success
    productSecondReadSuccess = $productSecondRead.success
    productExistsAfterFirstRead = $productExistsAfterFirstRead
    productTtlAfterFirstRead = $productTtlAfterFirstRead
    productExistsAfterSecondRead = $productExistsAfterSecondRead
    productTtlAfterSecondRead = $productTtlAfterSecondRead
    productFirstReadElapsedMs = $productFirstWatch.ElapsedMilliseconds
    productSecondReadElapsedMs = $productSecondWatch.ElapsedMilliseconds
    productCacheCreated = $productCacheCreated
    productCacheStillExists = $productCacheStillExists
    adminStatsCacheKey = $adminStatsCacheKey
    adminStatsDeletedBeforeTest = $adminStatsDeletedBeforeTest
    adminStatsFirstSuccess = $adminStatsFirst.success
    adminStatsSecondSuccess = $adminStatsSecond.success
    adminStatsExistsAfterFirstRead = $adminStatsExistsAfterFirstRead
    adminStatsTtlAfterFirstRead = $adminStatsTtlAfterFirstRead
    adminStatsExistsAfterSecondRead = $adminStatsExistsAfterSecondRead
    adminStatsTtlAfterSecondRead = $adminStatsTtlAfterSecondRead
    adminStatsFirstReadElapsedMs = $adminStatsFirstWatch.ElapsedMilliseconds
    adminStatsSecondReadElapsedMs = $adminStatsSecondWatch.ElapsedMilliseconds
    adminStatsTimestampEqual = $adminStatsTimestampEqual
    adminStatsCacheCreated = $adminStatsCacheCreated
    adminStatsCacheStillExists = $adminStatsCacheStillExists
    cacheRequirementSatisfied = ($productCacheCreated -and $productCacheStillExists -and $adminStatsCacheCreated -and $adminStatsCacheStillExists -and $adminStatsTimestampEqual)
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\04-redis-cache\06-redis-cache-summary.json

if (-not $summary.cacheRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\04-redis-cache\06-redis-cache-summary.json
    throw "Redis cache verification test failed"
}

Get-Content docs\evidence\step-02-tests\04-redis-cache\06-redis-cache-summary.json