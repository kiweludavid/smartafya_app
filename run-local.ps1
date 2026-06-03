param(
  [int]$BackendPort = 8000,
  [int]$AdminPort = 3000
)

$ErrorActionPreference = "Stop"

function Start-Backend {
  $backendDir = Join-Path $PSScriptRoot "smartafya_backend\smart_afya"
  if (!(Test-Path $backendDir)) { throw "Backend dir not found: $backendDir" }

  Write-Host "Starting backend on http://127.0.0.1:$BackendPort ..."
  $envFile = Join-Path $backendDir ".env"
  if (!(Test-Path $envFile)) {
    Copy-Item (Join-Path $backendDir ".env.example") $envFile -Force
  }

  $python = Join-Path $backendDir ".venv\Scripts\python.exe"
  if (!(Test-Path $python)) {
    Write-Host "Backend venv not found. Creating and installing deps..."
    Push-Location $backendDir
    python -m venv .venv
    .\.venv\Scripts\python -m pip install --upgrade pip
    .\.venv\Scripts\pip install -r requirements.txt
    Pop-Location
  }

  Start-Process -WorkingDirectory $backendDir -FilePath $python -ArgumentList @(
    "-m","uvicorn","app.main:app","--reload","--host","127.0.0.1","--port",$BackendPort
  )
}

function Start-Admin {
  $adminDir = Join-Path $PSScriptRoot "smartafya_admin\smartafya-admin-dashboard"
  if (!(Test-Path $adminDir)) { throw "Admin dir not found: $adminDir" }

  Write-Host "Starting admin at http://localhost:$AdminPort ..."
  $envLocal = Join-Path $adminDir ".env.local"
  if (!(Test-Path $envLocal)) {
    Copy-Item (Join-Path $adminDir ".env.local.example") $envLocal -Force
  }

  if (!(Test-Path (Join-Path $adminDir "node_modules"))) {
    Write-Host "Installing admin deps..."
    Push-Location $adminDir
    npm install
    Pop-Location
  }

  Start-Process -WorkingDirectory $adminDir -FilePath "npm" -ArgumentList @("run","dev","--","--port",$AdminPort)
}

Start-Backend
Start-Admin

Write-Host ""
Write-Host "Backend: http://127.0.0.1:$BackendPort  (docs: /docs)"
Write-Host "Admin:   http://localhost:$AdminPort"
