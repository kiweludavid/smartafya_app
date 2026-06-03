# Hot-reload when `flutter run` is already active (reads VM Service URL from Cursor terminal logs).

$ErrorActionPreference = "Continue"
$appRoot = Split-Path $PSScriptRoot -Parent
$terminalsRoot = Join-Path $env:USERPROFILE ".cursor\projects"

$vmUrl = $null
if (Test-Path $terminalsRoot) {
    $logs = Get-ChildItem -Path $terminalsRoot -Recurse -Filter "*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "terminals\\" }
    foreach ($log in ($logs | Sort-Object LastWriteTime -Descending | Select-Object -First 40)) {
        $line = Select-String -Path $log.FullName -Pattern "Dart VM Service.*?(http://[^\s]+)" |
            Select-Object -Last 1
        if ($line -and $line.Matches.Count -gt 0) {
            $vmUrl = $line.Matches[0].Groups[1].Value.TrimEnd('/')
            break
        }
    }
}

if (-not $vmUrl) {
    Write-Host "No Flutter VM Service found. Run: flutter run -d emulator-5554"
    exit 1
}

Write-Host "Hot reload via $vmUrl"
Set-Location $appRoot

# Pipe 'R' to flutter attach (full hot restart — picks up logic/UI changes reliably).
$out = cmd /c "echo R| flutter attach -d emulator-5554 --debug-uri `"$vmUrl`" 2>&1"
$out | Select-Object -Last 8 | ForEach-Object { Write-Host $_ }

if ($out -match "Reloaded|Restarted|reload|restart") {
    Write-Host "Hot restart OK."
    exit 0
}

Write-Host "Attach reload may have failed - press r in your flutter run terminal."
exit 0
