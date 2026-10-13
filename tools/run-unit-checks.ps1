param(
    [Parameter(Mandatory=$true)][ValidatePattern('^\d{8}-\d{6}$')][string]$RunId,
    [ValidateSet('baseline','development','final')][string]$Phase = 'final',
    [Parameter(Mandatory=$true)][ValidateSet('backend','frontend','build','analyze','web')][string]$Check,
    [string[]]$TestFiles = @()
)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "docs/testing/runs/$RunId/$Phase"
New-Item -ItemType Directory -Force $outDir | Out-Null
Set-Location $root
$tool = 'dotnet'
$arguments = @()
switch ($Check) {
    'backend' {
        $arguments = @('test','backend/tests/IOTAgriBackend.Tests.csproj','--configuration','Release','--no-restore','--logger','trx;LogFileName=backend.trx','--results-directory',$outDir)
        if ($Phase -eq 'final') { $arguments += @('--collect','XPlat Code Coverage') }
    }
    'build' { $arguments = @('build','backend/IOTAgriBackend.csproj','--configuration','Release','--no-restore') }
    default {
        $tool = Join-Path $root '.runtime/flutter/bin/flutter.bat'
        Set-Location (Join-Path $root 'frontend')
        switch ($Check) {
            'frontend' { $arguments = @('test','--no-pub','--reporter','expanded','--file-reporter',"json:$(Join-Path $outDir 'frontend-events.jsonl')"); if ($Phase -eq 'final') { $arguments += '--coverage' }; $arguments += ($TestFiles -split ',') }
            'analyze' { $arguments = @('analyze','--no-pub') }
            'web' { $arguments = @('test','--no-pub','--platform','chrome','--reporter','expanded','test/add_device_web_test.dart') }
        }
    }
}
$started = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')
$cwd = (Get-Location).Path
# Capture the native exit code before formatting or file operations.
$output = & $tool @arguments 2>&1
$nativeExit = $LASTEXITCODE
$textOutput = ($output | ForEach-Object { $_.ToString() }) -join "`n"
# Sanitize machine-specific paths and possible credentials in runner output.
$textOutput = $textOutput.Replace($root, '[workspace]').Replace($root.Replace('\','/'), '[workspace]')
$textOutput = $textOutput -replace 'C:\\Users\\[^\\\s]+', '[user-home]'
$textOutput = $textOutput -replace '(?i)(Bearer\s+)[A-Za-z0-9._-]+', '$1[REDACTED]'
$textOutput = $textOutput -replace '(?i)(Password|accessToken|refreshToken|Jwt__Key)\s*[:=]\s*[^\s,;]+', '$1=[REDACTED]'
$textOutput = $textOutput -replace '(?i)Host=[^\r\n]+', '[REDACTED connection configuration]'
if ($Check -eq 'frontend' -and (Test-Path (Join-Path $outDir 'frontend-events.jsonl'))) {
    $eventsPath = Join-Path $outDir 'frontend-events.jsonl'
    $events = [IO.File]::ReadAllText($eventsPath).Replace($root.Replace('\','/'), '[workspace]').Replace($root.Replace('\','\\'), '[workspace]')
    $events = $events -replace 'C:/Users/[^/\s"\\]+', '[user-home]'
    [IO.File]::WriteAllText($eventsPath, $events, [Text.UTF8Encoding]::new($false))
}
$header = "Started: $started`nWorking directory: $($cwd.Replace($root, '[workspace]'))`nCommand: $($tool.Replace($root, '[workspace]')) $($arguments -join ' ')`nExit code: $nativeExit`n"
[IO.File]::WriteAllText((Join-Path $outDir "$Check.log"), $header + $textOutput, [Text.UTF8Encoding]::new($false))
Copy-Item (Join-Path $outDir "$Check.log") (Join-Path $outDir ("$Check-" + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '.log'))
@{check=$Check; phase=$Phase; started=$started; command=@($tool.Replace($root,'[workspace]'))+$arguments; workingDirectory=$cwd.Replace($root,'[workspace]'); exitCode=$nativeExit} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $outDir "$Check.json") -Encoding UTF8
if ($Check -eq 'frontend' -and $Phase -eq 'final' -and (Test-Path 'coverage/lcov.info')) { Copy-Item 'coverage/lcov.info' (Join-Path $outDir 'frontend-lcov.info') }
Write-Output $textOutput
Write-Output "Exit code: $nativeExit"
exit $nativeExit
