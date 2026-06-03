$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping common local dev servers..."

# Stop uvicorn (python) on port 8000
$p8000 = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 8000 -State Listen | Select-Object -First 1
if ($p8000) {
  $pid = $p8000.OwningProcess
  Write-Host "Stopping process on 127.0.0.1:8000 (PID $pid)"
  Stop-Process -Id $pid -Force
}

# Stop next dev on port 3000
$p3000 = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 3000 -State Listen | Select-Object -First 1
if ($p3000) {
  $pid = $p3000.OwningProcess
  Write-Host "Stopping process on 127.0.0.1:3000 (PID $pid)"
  Stop-Process -Id $pid -Force
}

Write-Host "Done."
