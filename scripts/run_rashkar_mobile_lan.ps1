<#
.SYNOPSIS
    Launches Rashkar Flutter Web and CropNet FastAPI Backend for LAN testing on your phone.
.DESCRIPTION
    Detects your active Wi-Fi IPv4 address, starts or verifies FastAPI on 0.0.0.0:8000,
    and serves the Flutter Web build on 0.0.0.0:8080 with reverse proxy for API routes.
#>

$ErrorActionPreference = "Stop"

# 1. Detect active Wi-Fi IPv4 address
$wifiIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -match "Wi-Fi|Wireless|WLAN" -and $_.IPAddress -notlike "169.254*"
} | Select-Object -First 1).IPAddress

if (-not $wifiIp) {
    # Fallback to default gateway interface
    $wifiIp = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1).IPv4Address.IPAddress
}

if (-not $wifiIp) {
    $wifiIp = "127.0.0.1"
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " RASHKAR MOBILE LAN LAUNCHER" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Detected PC Local IP: $wifiIp" -ForegroundColor Yellow
Write-Host "Web Server Port:      8080"
Write-Host "Backend API Port:     8000"
Write-Host "Phone Access URL:     http://${wifiIp}:8080" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green

# 2. Check if backend is listening on port 8000
$backendActive = $false
try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/v1/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($res.status -eq "healthy") { $backendActive = $true }
} catch {}

if ($backendActive) {
    Write-Host "[OK] CropNet FastAPI backend is already running on port 8000." -ForegroundColor Green
} else {
    Write-Host "[*] Starting CropNet FastAPI backend on 0.0.0.0:8000..." -ForegroundColor Cyan
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "cd 'D:\CSE AIML\CropNet' ; `$env:PYTHONPATH='D:\CSE AIML\CropNet' ; python -m uvicorn cropnet.services.api.app.main:app --host 0.0.0.0 --port 8000" -WindowStyle Minimized
    Start-Sleep -Seconds 3
}

# 3. Check if Flutter web server is listening on port 8080
$webActive = $false
try {
    $res = Invoke-WebRequest -Uri "http://127.0.0.1:8080" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($res.StatusCode -eq 200) { $webActive = $true }
} catch {}

if ($webActive) {
    Write-Host "[OK] Flutter Web server is already running on port 8080." -ForegroundColor Green
} else {
    Write-Host "[*] Starting Flutter Web server on 0.0.0.0:8080..." -ForegroundColor Cyan
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "python 'D:\CSE AIML\Rashkar\scripts\serve_web.py'" -WindowStyle Minimized
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "READY! Open this URL on your phone's browser:" -ForegroundColor Green
Write-Host "   >>> http://${wifiIp}:8080 <<<" -ForegroundColor Yellow -BackgroundColor DarkGreen
Write-Host ""
Write-Host "Note on Mobile GPS over HTTP:" -ForegroundColor DarkYellow
Write-Host "- Browsers restrict navigator.geolocation to HTTPS or localhost."
Write-Host "- Rashkar includes a manual location/taluka picker if GPS is blocked."
Write-Host "- To enable live GPS on Android Chrome over LAN:"
Write-Host "  1. Open chrome://flags/#unsafely-treat-insecure-origin-as-secure"
Write-Host "  2. Add 'http://${wifiIp}:8080' and enable the flag."
Write-Host "  3. Relaunch Chrome on your phone."
Write-Host "==========================================================" -ForegroundColor Green
