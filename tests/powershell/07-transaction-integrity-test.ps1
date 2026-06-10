param(
    [string]$BaseUrl = "http://localhost:9090"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\07-transaction-integrity | Out-Null

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

function Get-OrderCount {
    param(
        [object]$Response
    )

    if ($Response.data -eq $null) {
        return 0
    }

    if ($Response.data -is [array]) {
        return @($Response.data).Count
    }

    if ($Response.data.content -ne $null) {
        return @($Response.data.content).Count
    }

    return @($Response.data).Count
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

$successProduct = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
    name = "ACID Success Product $unique"
    description = "Transaction success verification product"
    price = 10.0
    stockQuantity = 3
}

$successProductId = $successProduct.data.id

$successCustomer = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
    email = "acid-success-$unique@test.com"
    password = "Customer123456"
    fullName = "ACID Success Customer"
}

$successHeaders = @{
    Authorization = "Bearer $($successCustomer.data.token)"
    "Content-Type" = "application/json"
}

$successOrder = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/orders" -Headers $successHeaders -Body @{
    items = @(
        @{
            productId = $successProductId
            quantity = 2
        }
    )
}

$successProductAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$successProductId"
$successOrdersAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/orders/my" -Headers $successHeaders

$failureProduct = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
    name = "ACID Rollback Product $unique"
    description = "Transaction rollback verification product"
    price = 12000.0
    stockQuantity = 1
}

$failureProductId = $failureProduct.data.id

$failureCustomer = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
    email = "acid-failure-$unique@test.com"
    password = "Customer123456"
    fullName = "ACID Failure Customer"
}

$failureHeaders = @{
    Authorization = "Bearer $($failureCustomer.data.token)"
    "Content-Type" = "application/json"
}

$failureOrdersBefore = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/orders/my" -Headers $failureHeaders

$failedOrder = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/orders" -Headers $failureHeaders -Body @{
    items = @(
        @{
            productId = $failureProductId
            quantity = 1
        }
    )
}

$failureProductAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$failureProductId"
$failureOrdersAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/orders/my" -Headers $failureHeaders

$successProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\01-success-product-created.json
$successOrder | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\02-success-order-response.json
$successProductAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\03-success-product-after-order.json
$successOrdersAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\04-success-customer-orders.json
$failureProduct | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\05-failure-product-created.json
$failureOrdersBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\06-failure-orders-before.json
$failedOrder | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\07-failed-order-response.json
$failureProductAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\08-failure-product-after-failed-order.json
$failureOrdersAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\09-failure-orders-after.json

$successInitialStock = 3
$successQuantity = 2
$successExpectedFinalStock = 1
$successActualFinalStock = [int]$successProductAfter.data.stockQuantity
$successOrderCreated = ($successOrder.httpStatus -ge 200 -and $successOrder.httpStatus -lt 300 -and $successOrder.success -eq $true)
$successStockUpdatedCorrectly = ($successActualFinalStock -eq $successExpectedFinalStock)
$successOrderVisible = ((Get-OrderCount -Response $successOrdersAfter) -ge 1)

$failureInitialStock = 1
$failureActualFinalStock = [int]$failureProductAfter.data.stockQuantity
$failureOrdersBeforeCount = Get-OrderCount -Response $failureOrdersBefore
$failureOrdersAfterCount = Get-OrderCount -Response $failureOrdersAfter
$failureRejected = ($failedOrder.httpStatus -ge 400 -or $failedOrder.success -eq $false)
$failureStockUnchanged = ($failureActualFinalStock -eq $failureInitialStock)
$failureNoOrderCreated = ($failureOrdersAfterCount -eq $failureOrdersBeforeCount)

$successTransactionSatisfied = ($successOrderCreated -and $successStockUpdatedCorrectly -and $successOrderVisible)
$rollbackTransactionSatisfied = ($failureRejected -and $failureStockUnchanged -and $failureNoOrderCreated)
$acidRequirementSatisfied = ($successTransactionSatisfied -and $rollbackTransactionSatisfied)

$summary = [ordered]@{
    testName = "Transaction integrity and ACID rollback verification test"
    baseUrl = $BaseUrl
    successProductId = $successProductId
    successInitialStock = $successInitialStock
    successOrderQuantity = $successQuantity
    successExpectedFinalStock = $successExpectedFinalStock
    successActualFinalStock = $successActualFinalStock
    successOrderHttpStatus = $successOrder.httpStatus
    successOrderCreated = $successOrderCreated
    successStockUpdatedCorrectly = $successStockUpdatedCorrectly
    successOrderVisible = $successOrderVisible
    failureProductId = $failureProductId
    failureInitialStock = $failureInitialStock
    failureActualFinalStock = $failureActualFinalStock
    failedOrderHttpStatus = $failedOrder.httpStatus
    failedOrderErrorMessage = $failedOrder.errorMessage
    failureOrdersBeforeCount = $failureOrdersBeforeCount
    failureOrdersAfterCount = $failureOrdersAfterCount
    failureRejected = $failureRejected
    failureStockUnchanged = $failureStockUnchanged
    failureNoOrderCreated = $failureNoOrderCreated
    successTransactionSatisfied = $successTransactionSatisfied
    rollbackTransactionSatisfied = $rollbackTransactionSatisfied
    acidRequirementSatisfied = $acidRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\07-transaction-integrity\10-transaction-integrity-summary.json

if (-not $acidRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\07-transaction-integrity\10-transaction-integrity-summary.json
    throw "Transaction integrity and ACID rollback verification test failed"
}

Get-Content docs\evidence\step-02-tests\07-transaction-integrity\10-transaction-integrity-summary.json