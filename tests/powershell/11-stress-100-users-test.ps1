param(
    [string]$BaseUrl = "http://localhost:9090",
    [int]$Users = 100,
    [int]$ProductCount = 5,
    [int]$StockPerProduct = 30,
    [int]$TimeoutSeconds = 420
)

$ErrorActionPreference = "Stop"

[System.Net.ServicePointManager]::DefaultConnectionLimit = 512

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\11-stress-100-users | Out-Null

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $json = $Body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Headers $Headers -Body $json
}

$typeName = "EcommerceStressRunnerV2"

if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public class StressResultV2
{
    public int index { get; set; }
    public int productIndex { get; set; }
    public string productId { get; set; }
    public int browseProductsHttpStatus { get; set; }
    public int browseProductHttpStatus { get; set; }
    public int orderHttpStatus { get; set; }
    public bool browseProductsSuccess { get; set; }
    public bool browseProductSuccess { get; set; }
    public bool orderSuccess { get; set; }
    public bool flowSuccess { get; set; }
    public bool timedOut { get; set; }
    public long elapsedMs { get; set; }
    public string productsError { get; set; }
    public string productError { get; set; }
    public string orderError { get; set; }
}

public class HttpCallResultV2
{
    public int status { get; set; }
    public string error { get; set; }
}

public static class EcommerceStressRunnerV2
{
    public static StressResultV2[] Run(string baseUrl, string[] tokens, string[] productIds, int[] productIndexes, int timeoutSeconds)
    {
        ServicePointManager.DefaultConnectionLimit = 512;
        ServicePointManager.Expect100Continue = false;

        ManualResetEventSlim gate = new ManualResetEventSlim(false);
        Task<StressResultV2>[] tasks = new Task<StressResultV2>[tokens.Length];

        for (int i = 0; i < tokens.Length; i++)
        {
            int localIndex = i;
            tasks[i] = Task.Run(() =>
            {
                gate.Wait();
                return ExecuteFlow(baseUrl, tokens[localIndex], productIds[localIndex], productIndexes[localIndex], localIndex + 1);
            });
        }

        gate.Set();

        Task[] waitTasks = new Task[tasks.Length];

        for (int i = 0; i < tasks.Length; i++)
        {
            waitTasks[i] = tasks[i];
        }

        Task.WaitAll(waitTasks, timeoutSeconds * 1000);

        StressResultV2[] results = new StressResultV2[tokens.Length];

        for (int i = 0; i < tasks.Length; i++)
        {
            if (tasks[i].IsCompleted && !tasks[i].IsFaulted && !tasks[i].IsCanceled)
            {
                results[i] = tasks[i].Result;
            }
            else
            {
                results[i] = new StressResultV2
                {
                    index = i + 1,
                    productIndex = productIndexes[i],
                    productId = productIds[i],
                    browseProductsHttpStatus = 0,
                    browseProductHttpStatus = 0,
                    orderHttpStatus = 0,
                    browseProductsSuccess = false,
                    browseProductSuccess = false,
                    orderSuccess = false,
                    flowSuccess = false,
                    timedOut = true,
                    elapsedMs = timeoutSeconds * 1000,
                    productsError = "Timed out",
                    productError = "Timed out",
                    orderError = "Timed out"
                };
            }
        }

        return results;
    }

    private static StressResultV2 ExecuteFlow(string baseUrl, string token, string productId, int productIndex, int index)
    {
        Stopwatch watch = Stopwatch.StartNew();

        HttpCallResultV2 products = Execute("GET", baseUrl + "/api/products", null, null);
        HttpCallResultV2 product = Execute("GET", baseUrl + "/api/products/" + productId, null, null);
        string body = "{\"items\":[{\"productId\":\"" + productId + "\",\"quantity\":1}]}";
        HttpCallResultV2 order = Execute("POST", baseUrl + "/api/orders", token, body);

        watch.Stop();

        bool browseProductsSuccess = products.status >= 200 && products.status < 300;
        bool browseProductSuccess = product.status >= 200 && product.status < 300;
        bool orderSuccess = order.status >= 200 && order.status < 300;
        bool flowSuccess = browseProductsSuccess && browseProductSuccess && orderSuccess;

        return new StressResultV2
        {
            index = index,
            productIndex = productIndex,
            productId = productId,
            browseProductsHttpStatus = products.status,
            browseProductHttpStatus = product.status,
            orderHttpStatus = order.status,
            browseProductsSuccess = browseProductsSuccess,
            browseProductSuccess = browseProductSuccess,
            orderSuccess = orderSuccess,
            flowSuccess = flowSuccess,
            timedOut = false,
            elapsedMs = watch.ElapsedMilliseconds,
            productsError = products.error,
            productError = product.error,
            orderError = order.error
        };
    }

    private static HttpCallResultV2 Execute(string method, string url, string token, string body)
    {
        try
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
            request.Method = method;
            request.Timeout = 300000;
            request.ReadWriteTimeout = 300000;
            request.KeepAlive = false;
            request.Accept = "application/json";

            if (!String.IsNullOrWhiteSpace(token))
            {
                request.Headers["Authorization"] = "Bearer " + token;
            }

            if (body != null)
            {
                byte[] bytes = Encoding.UTF8.GetBytes(body);
                request.ContentType = "application/json";
                request.ContentLength = bytes.Length;

                using (Stream stream = request.GetRequestStream())
                {
                    stream.Write(bytes, 0, bytes.Length);
                }
            }

            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            {
                using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                {
                    reader.ReadToEnd();
                }

                return new HttpCallResultV2
                {
                    status = (int)response.StatusCode,
                    error = null
                };
            }
        }
        catch (WebException ex)
        {
            if (ex.Response != null)
            {
                using (HttpWebResponse response = (HttpWebResponse)ex.Response)
                {
                    return new HttpCallResultV2
                    {
                        status = (int)response.StatusCode,
                        error = ex.Message
                    };
                }
            }

            return new HttpCallResultV2
            {
                status = 0,
                error = ex.Message
            };
        }
        catch (Exception ex)
        {
            return new HttpCallResultV2
            {
                status = 0,
                error = ex.Message
            };
        }
    }
}
"@
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

$products = @()

for ($i = 1; $i -le $ProductCount; $i++) {
    $product = Invoke-JsonPost -Uri "$BaseUrl/api/products" -Headers $adminHeaders -Body @{
        name = "Stress Product $unique $i"
        description = "100 concurrent users stress product $i"
        price = 1.0
        stockQuantity = $StockPerProduct
    }

    $products += [pscustomobject]@{
        index = $i
        id = $product.data.id
        initialStock = $StockPerProduct
        response = $product
    }
}

$registeredUsers = @()

for ($i = 1; $i -le $Users; $i++) {
    $registered = Invoke-JsonPost -Uri "$BaseUrl/api/auth/register" -Body @{
        email = "stress-$unique-$i@test.com"
        password = "Customer123456"
        fullName = "Stress User $i"
    }

    $productIndex = (($i - 1) % $ProductCount)
    $selectedProduct = $products[$productIndex]

    $registeredUsers += [pscustomobject]@{
        index = $i
        token = $registered.data.token
        productId = $selectedProduct.id
        productIndex = $selectedProduct.index
    }
}

$healthAfterSeed = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"

$tokens = [string[]]($registeredUsers | ForEach-Object { $_.token })
$productIds = [string[]]($registeredUsers | ForEach-Object { $_.productId })
$productIndexes = [int[]]($registeredUsers | ForEach-Object { $_.productIndex })

$watch = [System.Diagnostics.Stopwatch]::StartNew()
$flowResults = [EcommerceStressRunnerV2]::Run($BaseUrl, $tokens, $productIds, $productIndexes, $TimeoutSeconds)
$watch.Stop()

$orderedResults = @($flowResults | Sort-Object index)

$healthAfter = Invoke-RestMethod -Method Get -Uri "$BaseUrl/actuator/health"

$finalProducts = @()

foreach ($product in $products) {
    $finalProduct = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/products/$($product.id)"

    $finalProducts += [pscustomobject]@{
        index = $product.index
        id = $product.id
        initialStock = $product.initialStock
        finalStock = [int]$finalProduct.data.stockQuantity
        sold = ($product.initialStock - [int]$finalProduct.data.stockQuantity)
        response = $finalProduct
    }
}

$products | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\01-products-created.json
$healthBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\02-health-before.json
$healthAfterSeed | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\03-health-after-seed.json
$orderedResults | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\04-user-flow-results.json
$healthAfter | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\05-health-after-stress.json
$finalProducts | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\06-final-products-state.json

$successfulUserFlows = @($orderedResults | Where-Object { $_.flowSuccess -eq $true }).Count
$failedUserFlows = @($orderedResults | Where-Object { $_.flowSuccess -ne $true }).Count
$orderSuccessCount = @($orderedResults | Where-Object { $_.orderSuccess -eq $true }).Count

$serverErrorCount = @($orderedResults | Where-Object {
    ($_.browseProductsHttpStatus -ge 500) -or
    ($_.browseProductHttpStatus -ge 500) -or
    ($_.orderHttpStatus -ge 500)
}).Count

$timedOutJobs = @($orderedResults | Where-Object { $_.timedOut -eq $true }).Count

$totalInitialStock = [int](($finalProducts | Measure-Object initialStock -Sum).Sum)
$totalFinalStock = [int](($finalProducts | Measure-Object finalStock -Sum).Sum)
$totalSold = [int](($finalProducts | Measure-Object sold -Sum).Sum)

$stockIntegrityHolds = (($totalFinalStock + $totalSold) -eq $totalInitialStock)
$orderCountMatchesSoldStock = ($orderSuccessCount -eq $totalSold)
$healthBeforeUp = ($healthBefore.status -eq "UP")
$healthAfterSeedUp = ($healthAfterSeed.status -eq "UP")
$healthAfterUp = ($healthAfter.status -eq "UP")
$allUsersCompleted = (@($orderedResults).Count -eq $Users)
$allFlowsSucceeded = ($successfulUserFlows -eq $Users -and $failedUserFlows -eq 0)
$noServerErrors = ($serverErrorCount -eq 0)
$noTimedOutJobs = ($timedOutJobs -eq 0)

$stressRequirementSatisfied = ($healthBeforeUp -and $healthAfterSeedUp -and $healthAfterUp -and $allUsersCompleted -and $allFlowsSucceeded -and $noServerErrors -and $noTimedOutJobs -and $stockIntegrityHolds -and $orderCountMatchesSoldStock)

$elapsedValues = @($orderedResults | ForEach-Object { $_.elapsedMs })

$minElapsed = 0
$maxElapsed = 0
$avgElapsed = 0

if ($elapsedValues.Count -gt 0) {
    $minElapsed = [int](($orderedResults | Measure-Object elapsedMs -Minimum).Minimum)
    $maxElapsed = [int](($orderedResults | Measure-Object elapsedMs -Maximum).Maximum)
    $avgElapsed = [math]::Round((($orderedResults | Measure-Object elapsedMs -Average).Average), 2)
}

$summary = [ordered]@{
    testName = "100 concurrent users stress verification test"
    baseUrl = $BaseUrl
    users = $Users
    productCount = $ProductCount
    stockPerProduct = $StockPerProduct
    totalInitialStock = $totalInitialStock
    totalFinalStock = $totalFinalStock
    totalSold = $totalSold
    successfulUserFlows = $successfulUserFlows
    failedUserFlows = $failedUserFlows
    orderSuccessCount = $orderSuccessCount
    allUsersCompleted = $allUsersCompleted
    allFlowsSucceeded = $allFlowsSucceeded
    serverErrorCount = $serverErrorCount
    timedOutJobs = $timedOutJobs
    noServerErrors = $noServerErrors
    noTimedOutJobs = $noTimedOutJobs
    healthBeforeUp = $healthBeforeUp
    healthAfterSeedUp = $healthAfterSeedUp
    healthAfterUp = $healthAfterUp
    stockIntegrityHolds = $stockIntegrityHolds
    orderCountMatchesSoldStock = $orderCountMatchesSoldStock
    minElapsedMs = $minElapsed
    maxElapsedMs = $maxElapsed
    avgElapsedMs = $avgElapsed
    totalStressElapsedMs = $watch.ElapsedMilliseconds
    stressRequirementSatisfied = $stressRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\11-stress-100-users\07-stress-100-users-summary.json

if (-not $stressRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\11-stress-100-users\07-stress-100-users-summary.json
    throw "100 concurrent users stress verification test failed"
}

Get-Content docs\evidence\step-02-tests\11-stress-100-users\07-stress-100-users-summary.json