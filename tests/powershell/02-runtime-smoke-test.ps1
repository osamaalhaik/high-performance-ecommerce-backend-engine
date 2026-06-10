param(
    [string]$BaseUrl = "http://localhost:9090"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\02-runtime-smoke | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

function Invoke-JsonPatch {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Patch -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

$unique = Get-Date -Format "yyyyMMddHHmmssfff"

$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"

$adminLogin = Invoke-JsonPost -Uri "$BaseUrl/api/auth/login" -Body @{
    email = "admin@test.com"
    password = "Admin123456"
}

$adminToken = $adminLogin.data.token

$adminHeaders = @{
    Authorization = "Bearer $adminToken"
    "Content-Type" = "application/json"
}

$product = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
    name = "Smoke Test Product $unique"
    description = "Runtime smoke test product"
    price = 25.0
    stockQuantity = 50
}

$productId = $product.data.id

$productsPage = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products?page=0&size=20"

$productFirstRead = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"
$productSecondRead = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$productId"

$customerEmail = "customer-$unique@test.com"

$customerRegister = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
    email = $customerEmail
    password = "Customer123456"
    fullName = "Runtime Smoke Customer"
}

$customerToken = $customerRegister.data.token

$customerHeaders = @{
    Authorization = "Bearer $customerToken"
    "Content-Type" = "application/json"
}

$order = Invoke-JsonPost -Uri "$BaseUrl/api/orders" -Headers $customerHeaders -Body @{
    items = @(
        @{
            productId = $productId
            quantity = 2
        }
    )
}

$myOrders = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/orders/my" -Headers $customerHeaders

$adminStatsFirst = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders
$adminStatsSecond = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/stats" -Headers $adminHeaders

$batchLockStatus = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/batch/lock-status" -Headers $adminHeaders

$instanceInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/instance"

$summary = [ordered]@{
    testName = "Runtime smoke test"
    baseUrl = $BaseUrl
    healthStatus = $health.status
    adminLoginSuccess = $adminLogin.success
    productCreated = $product.success
    productId = $productId
    productsPageSuccess = $productsPage.success
    productFirstReadSuccess = $productFirstRead.success
    productSecondReadSuccess = $productSecondRead.success
    customerRegisterSuccess = $customerRegister.success
    orderCreated = $order.success
    orderId = $order.data.orderId
    orderStatus = $order.data.status
    myOrdersSuccess = $myOrders.success
    adminStatsFirstSuccess = $adminStatsFirst.success
    adminStatsSecondSuccess = $adminStatsSecond.success
    adminStatsCacheTimestampEqual = ($adminStatsFirst.data.timestamp -eq $adminStatsSecond.data.timestamp)
    batchLockStatusSuccess = $batchLockStatus.success
    batchLockKey = $batchLockStatus.data.lockKey
    instanceEndpointSuccess = $instanceInfo.success
    instanceName = $instanceInfo.data.instanceName
    timestamp = (Get-Date).ToString("s")
}

$health | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\01-health.json
$product | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\02-product-created.json
$productFirstRead | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\03-product-first-read.json
$productSecondRead | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\04-product-second-read.json
$order | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\05-order-created.json
$myOrders | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\06-my-orders.json
$adminStatsFirst | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\07-admin-stats-first.json
$adminStatsSecond | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\08-admin-stats-second.json
$batchLockStatus | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\09-batch-lock-status.json
$instanceInfo | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\10-instance-info.json
$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\02-runtime-smoke\11-runtime-smoke-summary.json

Get-Content docs\evidence\step-02-tests\02-runtime-smoke\11-runtime-smoke-summary.json