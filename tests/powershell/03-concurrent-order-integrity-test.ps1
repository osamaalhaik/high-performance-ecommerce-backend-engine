param(
    [string]$BaseUrl = "http://localhost:9090",
    [int]$InitialStock = 10,
    [int]$ConcurrentAttempts = 20,
    [int]$OrderQuantity = 1
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\03-concurrent-access | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
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
    name = "Concurrent Integrity Product $unique"
    description = "Concurrent access integrity test product"
    price = 1.0
    stockQuantity = $InitialStock
}

$productId = $product.data.id

$tokens = @()

for ($i = 1; $i -le $ConcurrentAttempts; $i++) {
    $register = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "concurrent-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Concurrent Customer $i"
    }

    $tokens += $register.data.token
}

$jobs = @()

for ($i = 1; $i -le $ConcurrentAttempts; $i++) {
    $token = $tokens[$i - 1]

    $jobs += Start-Job -ScriptBlock {
        param(
            [string]$BaseUrl,
            [string]$Token,
            [string]$ProductId,
            [int]$Quantity,
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
                    quantity = $Quantity
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
                errorMessage = $null
                elapsedMs = $watch.ElapsedMilliseconds
            }
        } catch {
            $watch.Stop()

            $status = $null
            $message = $_.Exception.Message
            $bodyText = ""

            if ($_.Exception.Response -ne $null) {
                $status = [int]$_.Exception.Response.StatusCode

                try {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $bodyText = $reader.ReadToEnd()

                    if ($bodyText.Trim().Length -gt 0) {
                        $errorJson = $bodyText | ConvertFrom-Json
                        if ($errorJson.message -ne $null) {
                            $message = $errorJson.message
                        }
                    }
                } catch {
                    $message = $_.Exception.Message
                }
            }

            [pscustomobject]@{
                index = $Index
                success = $false
                httpStatus = $status
                orderId = $null
                orderStatus = $null
                errorMessage = $message
                elapsedMs = $watch.ElapsedMilliseconds
            }
        }
    } -ArgumentList $BaseUrl, $token, $productId, $OrderQuantity, $i
}

$results = Receive-Job -Job $jobs -Wait
Remove-Job -Job $jobs

$orderedResults = @($results | Sort-Object index)

$finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"
$finalStock = [int]$finalProduct.data.stockQuantity

$successfulOrders = @($orderedResults | Where-Object { $_.success -eq $true }).Count
$failedOrders = @($orderedResults | Where-Object { $_.success -eq $false }).Count
$totalSold = $successfulOrders * $OrderQuantity
$integrityEquationLeft = $finalStock + $totalSold
$integrityHolds = ($integrityEquationLeft -eq $InitialStock)
$noOverselling = ($finalStock -ge 0 -and $totalSold -le $InitialStock)

$orderedResults | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\03-concurrent-access\01-concurrent-order-results.json
$finalProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\03-concurrent-access\02-final-product-state.json

$summary = [ordered]@{
    testName = "Concurrent order integrity test"
    baseUrl = $BaseUrl
    productId = $productId
    initialStock = $InitialStock
    concurrentAttempts = $ConcurrentAttempts
    orderQuantity = $OrderQuantity
    successfulOrders = $successfulOrders
    failedOrders = $failedOrders
    totalSold = $totalSold
    finalStock = $finalStock
    integrityEquation = "$finalStock + $totalSold = $InitialStock"
    integrityHolds = $integrityHolds
    noOverselling = $noOverselling
    minElapsedMs = [int](($orderedResults | Measure-Object elapsedMs -Minimum).Minimum)
    maxElapsedMs = [int](($orderedResults | Measure-Object elapsedMs -Maximum).Maximum)
    avgElapsedMs = [math]::Round((($orderedResults | Measure-Object elapsedMs -Average).Average), 2)
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\03-concurrent-access\03-concurrent-order-summary.json

if (-not $integrityHolds -or -not $noOverselling) {
    Get-Content docs\evidence\step-02-tests\03-concurrent-access\03-concurrent-order-summary.json
    throw "Concurrent access integrity test failed"
}

Get-Content docs\evidence\step-02-tests\03-concurrent-access\03-concurrent-order-summary.json