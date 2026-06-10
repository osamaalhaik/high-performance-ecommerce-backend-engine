$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force docs\evidence\step-02-tests\01-build | Out-Null

$stdoutPath = "docs\evidence\step-02-tests\01-build\01-maven-clean-test-output.txt"
$stderrPath = "docs\evidence\step-02-tests\01-build\01-maven-clean-test-error.txt"
$summaryPath = "docs\evidence\step-02-tests\01-build\02-maven-clean-test-summary.json"

$process = Start-Process -FilePath ".\mvnw.cmd" -ArgumentList "clean","test" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

$output = Get-Content $stdoutPath -Raw
$errorOutput = ""

if (Test-Path $stderrPath) {
    $errorOutput = Get-Content $stderrPath -Raw
}

if ($process.ExitCode -ne 0) {
    throw "Maven clean test failed with exit code $($process.ExitCode)"
}

$success = $output.Contains("BUILD SUCCESS")
$testSummaryFound = $output.Contains("Tests run: 13, Failures: 0, Errors: 0, Skipped: 0")

$summary = [ordered]@{
    testName = "Maven clean test"
    exitCode = $process.ExitCode
    buildSuccess = $success
    expectedTestSummaryFound = $testSummaryFound
    evidenceOutput = $stdoutPath
    evidenceError = $stderrPath
    stderrCaptured = ($errorOutput.Trim().Length -gt 0)
    timestamp = (Get-Date).ToString("s")
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $summaryPath

if (-not $success -or -not $testSummaryFound) {
    throw "Maven output did not contain the expected success summary"
}

Get-Content $summaryPath