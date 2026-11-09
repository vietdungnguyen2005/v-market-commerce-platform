param([ValidateRange(1,10)][int]$Runs = 3, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$backend = Join-Path $repo 'backend'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $backend 'target/portfolio-evidence/import' }
$destination = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$sha = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source revision' }
if (& git -C $repo diff HEAD --name-only -- backend/src backend/pom.xml) { throw 'Backend source differs from HEAD' }
$fixture = Join-Path $backend 'src/test/java/dev/vmarket/VMarketApplicationTest.java'
$fixtureHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$wrapper = if ($IsWindows) { Join-Path $backend 'mvnw.cmd' } else { Join-Path $backend 'mvnw' }
$attempt = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$methods = @(
  'seededSupplierOnboardingBenchmarkProducesMeasuredImportAndReconciliationEvidence',
  'supplierPreviewMapsAndQuarantinesRowsWithoutAnyBusinessWrites',
  'concurrentSupplierConfirmationsShareOneDurableIdentityAndOneMovement',
  'supplierDatabaseFailureRollsBackChunkAndUsesOnlyTheExistingSafeRestart'
)
$selector = '-Dtest=VMarketApplicationTest#' + ($methods -join '+')
$observations = @()
Push-Location $backend
try {
  for ($iteration=1; $iteration -le $Runs; $iteration++) {
    $started = [DateTime]::UtcNow
    $log = Join-Path $destination "run-$attempt-$iteration.log"
    & $wrapper -q $selector test *> $log
    if ($LASTEXITCODE -ne 0) { throw "Maven failed on run $iteration; inspect isolated test log $log" }
    $benchmarkFile = Join-Path $backend 'target/onboarding-benchmark.json'
    $xmlFile = Join-Path $backend 'target/surefire-reports/TEST-dev.vmarket.VMarketApplicationTest.xml'
    if ((Get-Item $benchmarkFile).LastWriteTimeUtc -lt $started) { throw 'Stale benchmark artifact' }
    [xml]$xml = Get-Content -LiteralPath $xmlFile -Raw
    $suite = $xml.testsuite
    if ([int]$suite.tests -ne 4 -or [int]$suite.failures -ne 0 -or [int]$suite.errors -ne 0 -or [int]$suite.skipped -ne 0) {
      throw 'Expected exactly four passing, non-skipped integration scenarios'
    }
    $actualMethods = @($suite.testcase | ForEach-Object { $_.name })
    foreach ($method in $methods) { if ($method -notin $actualMethods) { throw "Missing scenario $method" } }
    if ((Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash -ne $fixtureHash -or
        (& git -C $repo rev-parse HEAD).Trim() -ne $sha -or
        (& git -C $repo diff HEAD --name-only -- backend/src backend/pom.xml)) { throw 'Backend snapshot changed' }
    $metric = Get-Content -LiteralPath $benchmarkFile -Raw | ConvertFrom-Json
    if ($metric.validRows -ne 200 -or $metric.rejectedRows -ne 20 -or $metric.jobsAfterDuplicate -ne 1 -or
        $metric.movementsAfterDuplicate -ne 200 -or $metric.mismatches -ne 0 -or $metric.unverifiedStockRows -ne 0) {
      throw 'Measured business invariants not satisfied'
    }
    Copy-Item -LiteralPath $benchmarkFile -Destination (Join-Path $destination "run-$attempt-$iteration-benchmark.json")
    $observations += [ordered]@{run=$iteration;startedAtUtc=$started.ToString('o');sourceSha=$sha;
      tests=@($actualMethods);testsPassed=4;testsSkipped=0;metrics=$metric}
    Write-Output "Completed isolated V-Market run $iteration/${Runs}: 200 accepted / 20 rejected / 1 job / 200 movements / 0 mismatches"
  }
} finally { Pop-Location }
$summary = [ordered]@{recordedAtUtc=[DateTime]::UtcNow.ToString('o');sourceSha=$sha;fixtureSha256=$fixtureHash;runs=$Runs;
  kind='repeated isolated correctness and timing baseline';synthetic=$true;
  command='./mvnw.cmd -q ' + $selector + ' test';
  environment='Spring Boot application context + MockMvc + disposable Testcontainers PostgreSQL17.6/Redis8.2';
  limitations=@('Not a before/after performance comparison.','Not browser/HTTP-network or production load testing.',
    'Each run starts a fresh application/container fixture; phase timings exclude process/container startup.',
    'Four scenarios per run; not the full application suite.','No real supplier/customer data or external API is used.');
  observations=$observations}
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $destination ('import-results-' + $attempt + '.json')) -Encoding utf8
