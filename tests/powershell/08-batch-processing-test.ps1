param(
    [string]$BaseUrl = "http://localhost:9090",
    [int]$OrderCount = 5
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\08-batch-processing | Out-Null

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
    name = "Batch Processing Product $unique"
    description = "Batch processing verification product"
    price = 5.0
    stockQuantity = ($OrderCount + 10)
}

$productId = $product.data.id

$orderResults = @()

for ($i = 1; $i -le $OrderCount; $i++) {
    $customer = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "batch-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Batch Customer $i"
    }

    $customerHeaders = @{
        Authorization = "Bearer $($customer.data.token)"
        "Content-Type" = "application/json"
    }

    $order = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/orders" -Headers $customerHeaders -Body @{
        items = @(
            @{
                productId = $productId
                quantity = 1
            }
        )
    }

    $orderResults += [pscustomobject]@{
        index = $i
        httpStatus = $order.httpStatus
        success = $order.success
        orderId = $order.body.data.orderId
        orderStatus = $order.body.data.status
        errorMessage = $order.errorMessage
    }
}

Start-Sleep -Seconds 2

$batchWatch = [System.Diagnostics.Stopwatch]::StartNew()
$batchRun = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/admin/batch/run" -Headers $adminHeaders
$batchWatch.Stop()

$finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"

$product | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\08-batch-processing\01-product-created.json
$orderResults | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\08-batch-processing\02-seed-order-results.json
$batchRun | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\08-batch-processing\03-batch-run-response.json
$finalProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\08-batch-processing\04-final-product-state.json

$successfulOrders = @($orderResults | Where-Object { $_.success -eq $true -and $_.httpStatus -ge 200 -and $_.httpStatus -lt 300 }).Count
$failedOrders = @($orderResults | Where-Object { $_.success -ne $true }).Count
$seedOrdersCreated = ($successfulOrders -eq $OrderCount -and $failedOrders -eq 0)

$batchRunHttpStatus = $batchRun.httpStatus
$batchRunSuccess = ($batchRun.httpStatus -ge 200 -and $batchRun.httpStatus -lt 300 -and $batchRun.success -eq $true)
$batchRaw = [string]$batchRun.rawBody
$batchCompleted = ($batchRaw.Contains("COMPLETED") -or $batchRaw.Contains("completed") -or $batchRaw.Contains("success") -or $batchRaw.Contains("successfully"))

$expectedFinalStock = 10
$actualFinalStock = [int]$finalProduct.data.stockQuantity
$productStockConsistent = ($actualFinalStock -eq $expectedFinalStock)

$batchRequirementSatisfied = ($seedOrdersCreated -and $batchRunSuccess -and $batchCompleted -and $productStockConsistent)

$summary = [ordered]@{
    testName = "Batch processing verification test"
    baseUrl = $BaseUrl
    productId = $productId
    orderCount = $OrderCount
    successfulOrders = $successfulOrders
    failedOrders = $failedOrders
    seedOrdersCreated = $seedOrdersCreated
    batchRunHttpStatus = $batchRunHttpStatus
    batchRunSuccess = $batchRunSuccess
    batchCompleted = $batchCompleted
    batchElapsedMs = $batchWatch.ElapsedMilliseconds
    expectedFinalStock = $expectedFinalStock
    actualFinalStock = $actualFinalStock
    productStockConsistent = $productStockConsistent
    batchRequirementSatisfied = $batchRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\08-batch-processing\05-batch-processing-summary.json

if (-not $batchRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\08-batch-processing\05-batch-processing-summary.json
    throw "Batch processing verification test failed"
}

Get-Content docs\evidence\step-02-tests\08-batch-processing\05-batch-processing-summary.json