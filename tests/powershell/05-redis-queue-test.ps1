param(
    [string]$BaseUrl = "http://localhost:9090",
    [string]$RedisHost = "127.0.0.1",
    [int]$RedisPort = 6379,
    [int]$OrderCount = 6,
    [int]$DrainTimeoutSeconds = 35
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\05-redis-queue | Out-Null

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

$readyQueueKey = "ecommerce:queue:async-jobs"
$failedQueueKey = "ecommerce:queue:async-jobs:failed"

Invoke-RedisInteger -Command @("DEL", $readyQueueKey) | Out-Null
Invoke-RedisInteger -Command @("DEL", $failedQueueKey) | Out-Null

$readyBefore = Invoke-RedisInteger -Command @("LLEN", $readyQueueKey)
$failedBefore = Invoke-RedisInteger -Command @("LLEN", $failedQueueKey)

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
    name = "Redis Queue Product $unique"
    description = "Redis queue verification product"
    price = 2.0
    stockQuantity = ($OrderCount + 5)
}

$productId = $product.data.id

$tokens = @()

for ($i = 1; $i -le $OrderCount; $i++) {
    $register = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "queue-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Queue Test Customer $i"
    }

    $tokens += $register.data.token
}

$jobs = @()

for ($i = 1; $i -le $OrderCount; $i++) {
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

$orderResults = Receive-Job -Job $jobs -Wait
Remove-Job -Job $jobs

$orderedResults = @($orderResults | Sort-Object index)
$successfulOrders = @($orderedResults | Where-Object { $_.success -eq $true }).Count
$failedOrders = @($orderedResults | Where-Object { $_.success -eq $false }).Count

Start-Sleep -Milliseconds 300

$readyAfterOrders = Invoke-RedisInteger -Command @("LLEN", $readyQueueKey)
$failedAfterOrders = Invoke-RedisInteger -Command @("LLEN", $failedQueueKey)

$maxObservedReadyQueueLength = $readyAfterOrders
$queueObserved = ($readyAfterOrders -gt 0)

$deadline = (Get-Date).AddSeconds($DrainTimeoutSeconds)

do {
    Start-Sleep -Seconds 1
    $currentReady = Invoke-RedisInteger -Command @("LLEN", $readyQueueKey)

    if ($currentReady -gt $maxObservedReadyQueueLength) {
        $maxObservedReadyQueueLength = $currentReady
    }

    if ($currentReady -eq 0) {
        break
    }
} while ((Get-Date) -lt $deadline)

$readyAfterDrain = Invoke-RedisInteger -Command @("LLEN", $readyQueueKey)
$failedAfterDrain = Invoke-RedisInteger -Command @("LLEN", $failedQueueKey)

$finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"

$orderedResults | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\05-redis-queue\01-order-results.json
$product | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\05-redis-queue\02-product-created.json
$finalProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\05-redis-queue\03-final-product-state.json

$expectedJobs = $successfulOrders * 2
$ordersCreated = ($successfulOrders -eq $OrderCount -and $failedOrders -eq 0)
$queueDrained = ($readyAfterDrain -eq 0)
$failedQueueDidNotIncrease = ($failedAfterDrain -eq $failedBefore)
$queueRequirementSatisfied = ($ordersCreated -and $queueObserved -and $queueDrained -and $failedQueueDidNotIncrease)

$summary = [ordered]@{
    testName = "Redis asynchronous queue verification test"
    baseUrl = $BaseUrl
    redisHost = $RedisHost
    redisPort = $RedisPort
    readyQueueKey = $readyQueueKey
    failedQueueKey = $failedQueueKey
    productId = $productId
    orderCount = $OrderCount
    successfulOrders = $successfulOrders
    failedOrders = $failedOrders
    expectedJobs = $expectedJobs
    readyBefore = $readyBefore
    failedBefore = $failedBefore
    readyAfterOrders = $readyAfterOrders
    failedAfterOrders = $failedAfterOrders
    maxObservedReadyQueueLength = $maxObservedReadyQueueLength
    readyAfterDrain = $readyAfterDrain
    failedAfterDrain = $failedAfterDrain
    ordersCreated = $ordersCreated
    queueObserved = $queueObserved
    queueDrained = $queueDrained
    failedQueueDidNotIncrease = $failedQueueDidNotIncrease
    queueRequirementSatisfied = $queueRequirementSatisfied
    finalProductStock = $finalProduct.data.stockQuantity
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\05-redis-queue\04-redis-queue-summary.json

if (-not $queueRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\05-redis-queue\04-redis-queue-summary.json
    throw "Redis asynchronous queue verification test failed"
}

Get-Content docs\evidence\step-02-tests\05-redis-queue\04-redis-queue-summary.json