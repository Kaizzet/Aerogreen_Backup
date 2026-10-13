param([Parameter(Mandatory=$true)][ValidatePattern('^\d{8}-\d{6}$')][string]$RunId)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$finalDir = Join-Path $root "docs/testing/runs/$RunId/final"
[xml]$cov = Get-Content -Raw (Join-Path $finalDir 'backend-coverage.cobertura.xml')
[xml]$trx = Get-Content -Raw (Join-Path $finalDir 'backend.trx')
$events = Get-Content (Join-Path $finalDir 'frontend-events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json }
$tests = @{}
foreach ($event in $events) {
    if ($event.type -eq 'testStart' -and $event.test.name -notlike 'loading *') {
        $tests[$event.test.id] = $event.test
    }
}
$cases = @()
foreach ($event in $events) {
    if ($event.type -eq 'testDone' -and $tests.ContainsKey($event.testID)) {
        $test = $tests[$event.testID]
        $kind = if ($test.url -eq 'package:flutter_test/src/widget_tester.dart') { 'widget' } else { 'unit' }
        $cases += [pscustomobject]@{name=$test.name;kind=$kind;result=$event.result;skipped=$event.skipped;source=($(if($test.root_url){$test.root_url}else{$test.url}))}
    }
}
$lcov = Get-Content (Join-Path $finalDir 'frontend-lcov.info')
$found=0; $hit=0
foreach($line in $lcov) {
    if($line -match '^LF:(\d+)$') {$found += [int]$Matches[1]}
    if($line -match '^LH:(\d+)$') {$hit += [int]$Matches[1]}
}
$summary = [ordered]@{
    backendCounters=@{total=[int]$trx.TestRun.ResultSummary.Counters.total;passed=[int]$trx.TestRun.ResultSummary.Counters.passed;failed=[int]$trx.TestRun.ResultSummary.Counters.failed;notExecuted=[int]$trx.TestRun.ResultSummary.Counters.notExecuted}
    backendLines=@{hit=[int]$cov.coverage.'lines-covered';found=[int]$cov.coverage.'lines-valid';percent=100.0*[int]$cov.coverage.'lines-covered'/[int]$cov.coverage.'lines-valid'}
    backendBranches=@{hit=[int]$cov.coverage.'branches-covered';found=[int]$cov.coverage.'branches-valid';percent=100.0*[int]$cov.coverage.'branches-covered'/[int]$cov.coverage.'branches-valid'}
    flutterCases=$cases.Count
    flutterRunnerSuccess=($events | Where-Object type -eq done | Select-Object -Last 1).success
    flutterLoadFailures=@($events | Where-Object { $_.type -eq 'testDone' -and -not $tests.ContainsKey($_.testID) -and $_.result -ne 'success' }).Count
    flutterUnit=@($cases | Where-Object kind -eq unit).Count
    flutterWidget=@($cases | Where-Object kind -eq widget).Count
    flutterFailed=@($cases | Where-Object result -ne success).Count
    flutterSkipped=@($cases | Where-Object skipped -eq $true).Count
    flutterLines=@{hit=$hit;found=$found;percent=100.0*$hit/$found}
}
$summary | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $finalDir 'summary.json') -Encoding UTF8
$cases | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $finalDir 'flutter-test-cases.json') -Encoding UTF8
$summary | ConvertTo-Json -Depth 5
