param([Parameter(Mandatory=$true)][ValidatePattern('^\d{8}-\d{6}$')][string]$RunId)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runDir = Join-Path $root "docs/testing/runs/$RunId"
$finalDir = Join-Path $runDir 'final'
$coverage = Get-ChildItem $finalDir -Recurse -Filter coverage.cobertura.xml |
    Where-Object { $_.Directory.Name -match '^[0-9a-f-]{36}$' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($coverage) {
    Copy-Item $coverage.FullName (Join-Path $finalDir 'backend-coverage.cobertura.xml')
}
# Keep raw collector directories (including machine-named duplicate attachments)
# in the ignored run area; publish only the normalized report file.
$rawDir = Join-Path $root ".run/unit-tests-raw/$RunId"
New-Item -ItemType Directory -Force $rawDir | Out-Null
foreach ($dir in Get-ChildItem $finalDir -Directory) {
    if ($dir.Name -notmatch '^[0-9a-f-]{36}$' -and $dir.Name -notlike "${env:USERNAME}_${env:COMPUTERNAME}_*") { continue }
    $absolute = [IO.Path]::GetFullPath($dir.FullName)
    if (-not $absolute.StartsWith([IO.Path]::GetFullPath($finalDir) + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid collector source path' }
    $destination = Join-Path $rawDir $dir.Name
    if (-not ([IO.Path]::GetFullPath($destination).StartsWith([IO.Path]::GetFullPath($rawDir) + '\', [StringComparison]::OrdinalIgnoreCase))) { throw 'Invalid raw artifact destination' }
    if (Test-Path $destination) { throw 'Raw destination already exists; do not overwrite' }
    Move-Item -LiteralPath $absolute -Destination $destination
}
foreach ($file in Get-ChildItem $runDir -Recurse -File) {
    $text = [IO.File]::ReadAllText($file.FullName)
    $text = $text.Replace($root, '[workspace]').Replace($root.Replace('\','/'), '[workspace]').Replace($root.Replace('\','\\'), '[workspace]')
    $text = $text -replace '(?i)C:[/\\]+Users[/\\]+[^/\\\s"<>]+', '[user-home]'
    $text = $text -replace '(?i)(computerName|user)="[^"]*"', '$1="[REDACTED]"'
    $text = $text.Replace([Environment]::UserName, '[local-user]').Replace([Environment]::MachineName, '[local-machine]')
    $text = $text -replace '(?i)(Bearer\s+)[A-Za-z0-9._-]+', '$1[REDACTED]'
    $text = $text -replace '(?i)(Password|accessToken|refreshToken|Jwt__Key)\s*[:=]\s*[^\s,;]+', '$1=[REDACTED]'
    $text = $text -replace '(?i)Host=[^\r\n<]+', '[REDACTED connection configuration]'
    # Normalize test-run attachment references to the published coverage file.
    if ($file.Extension -eq '.trx') {
        $text = $text -replace 'path="[^"]*coverage.cobertura.xml"', 'path="backend-coverage.cobertura.xml"'
        $text = $text -replace 'href="[^"]*coverage.cobertura.xml"', 'href="backend-coverage.cobertura.xml"'
    }
    [IO.File]::WriteAllText($file.FullName, $text, [Text.UTF8Encoding]::new($false))
}
Write-Output 'Runner artifacts sanitized; raw collector directories retained in ignored .run/.'
