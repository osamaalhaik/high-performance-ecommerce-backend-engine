param(
    [string]$BaseUrl = "http://localhost:9090",
    [string]$RedisHost = "127.0.0.1",
    [int]$RedisPort = 6379
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\06-distributed-lock | Out-Null

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

function Invoke-RedisStatusOk {
    param(
        [string[]]$Command
    )

    $reply = Invoke-RedisSimple -Command $Command
    return $reply.StartsWith("+OK")
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

$lockKey = "lock:daily-sales-batch"
$manualLockValue = "manual-test-lock-" + (Get-Date -Format "yyyyMMddHHmmssfff")

Invoke-RedisInteger -Command @("DEL", $lockKey) | Out-Null

$adminLogin = Invoke-JsonPost -Uri "$BaseUrl/api/auth/login" -Body @{
    email = "admin@test.com"
    password = "Admin123456"
}

$adminHeaders = @{
    Authorization = "Bearer $($adminLogin.data.token)"
    "Content-Type" = "application/json"
}

$lockStatusBefore = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/batch/lock-status" -Headers $adminHeaders

$manualLockCreated = Invoke-RedisStatusOk -Command @("SET", $lockKey, $manualLockValue, "EX", "60", "NX")
$lockExistsAfterManualSet = Invoke-RedisInteger -Command @("EXISTS", $lockKey)
$lockTtlAfterManualSet = Invoke-RedisInteger -Command @("TTL", $lockKey)

$lockStatusDuringManualLock = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/batch/lock-status" -Headers $adminHeaders

$batchRunWhileLocked = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/admin/batch/run" -Headers $adminHeaders

$manualLockDeleted = Invoke-RedisInteger -Command @("DEL", $lockKey)

$lockStatusAfterManualDelete = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/batch/lock-status" -Headers $adminHeaders

$batchRunAfterUnlock = Invoke-WebRequestSafe -Method "POST" -Uri "$BaseUrl/api/admin/batch/run" -Headers $adminHeaders

Start-Sleep -Milliseconds 500

$lockStatusAfterBatchRun = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/batch/lock-status" -Headers $adminHeaders

$lockStatusBefore | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\01-lock-status-before.json
$lockStatusDuringManualLock | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\02-lock-status-during-manual-lock.json
$batchRunWhileLocked | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\03-batch-run-while-locked.json
$lockStatusAfterManualDelete | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\04-lock-status-after-manual-delete.json
$batchRunAfterUnlock | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\05-batch-run-after-unlock.json
$lockStatusAfterBatchRun | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\06-lock-status-after-batch-run.json

$blockedCorrectly = ($batchRunWhileLocked.httpStatus -eq 423)
$unlockedRunSucceeded = ($batchRunAfterUnlock.httpStatus -eq 200)
$lockWasVisible = ($lockStatusDuringManualLock.data.locked -eq $true)
$lockRemovedAfterManualDelete = ($lockStatusAfterManualDelete.data.locked -eq $false)
$distributedLockRequirementSatisfied = ($manualLockCreated -and $lockWasVisible -and $blockedCorrectly -and ($manualLockDeleted -eq 1) -and $lockRemovedAfterManualDelete -and $unlockedRunSucceeded)

$summary = [ordered]@{
    testName = "Redis distributed lock verification test"
    baseUrl = $BaseUrl
    redisHost = $RedisHost
    redisPort = $RedisPort
    lockKey = $lockKey
    lockBefore = $lockStatusBefore.data.locked
    manualRedisLockCreated = $manualLockCreated
    lockExistsAfterManualSet = $lockExistsAfterManualSet
    lockTtlAfterManualSet = $lockTtlAfterManualSet
    lockStatusDuringManualLock = $lockStatusDuringManualLock.data.locked
    batchRunWhileLockedHttpStatus = $batchRunWhileLocked.httpStatus
    batchRunWhileLockedSuccess = $batchRunWhileLocked.success
    manualLockDeleted = $manualLockDeleted
    lockStatusAfterManualDelete = $lockStatusAfterManualDelete.data.locked
    batchRunAfterUnlockHttpStatus = $batchRunAfterUnlock.httpStatus
    batchRunAfterUnlockSuccess = $batchRunAfterUnlock.success
    lockStatusAfterBatchRun = $lockStatusAfterBatchRun.data.locked
    blockedCorrectly = $blockedCorrectly
    unlockedRunSucceeded = $unlockedRunSucceeded
    distributedLockRequirementSatisfied = $distributedLockRequirementSatisfied
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 docs\evidence\step-02-tests\06-distributed-lock\07-distributed-lock-summary.json

if (-not $distributedLockRequirementSatisfied) {
    Get-Content docs\evidence\step-02-tests\06-distributed-lock\07-distributed-lock-summary.json
    throw "Redis distributed lock verification test failed"
}

Get-Content docs\evidence\step-02-tests\06-distributed-lock\07-distributed-lock-summary.json