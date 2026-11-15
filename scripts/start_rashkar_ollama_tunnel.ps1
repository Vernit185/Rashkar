<#
.SYNOPSIS
    Starts and verifies Rashkar's local Ollama Qwen3:8B + authenticated tunnel for Render Free.
.DESCRIPTION
    1. Checks that Ollama is installed.
    2. Verifies qwen3:8b is present (without reinstalling or replacing it).
    3. Verifies Rashkar's configured model and prompts.
    4. Starts Ollama on 127.0.0.1:11434 if not already running.
    5. Starts the authenticated local proxy on 127.0.0.1:11435 and ngrok static domain tunnel.
    6. Verifies unauthorized rejection (401) and authenticated inference (200).
    7. Displays a clear connection status summary.
#>

param(
    [string]$NgrokDomain = $env:NGROK_STATIC_DOMAIN
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $PSScriptRoot ".ollama_tunnel.env"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " RASHKAR LOCAL AI (QWEN3:8B + CROP DOCTOR) TUNNEL LAUNCHER" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 1. Check Ollama installation
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Error "Ollama is not installed or not in PATH. Install Ollama for Windows first."
}
$ollamaVer = (ollama --version).Trim()
Write-Host "[1/7] Ollama installed: $ollamaVer" -ForegroundColor Cyan

# 2. Start Ollama if not running on 127.0.0.1:11434
$ollamaUp = $false
try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2 -ErrorAction Stop
    $ollamaUp = $true
} catch {}

if (-not $ollamaUp) {
    Write-Host "[2/7] Starting Ollama daemon on 127.0.0.1:11434..." -ForegroundColor Yellow
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5
} else {
    Write-Host "[2/7] Ollama daemon already running on 127.0.0.1:11434." -ForegroundColor Cyan
}

# 3. Verify qwen3:8b is present (never pull/replace)
$qwenModel = $tags.models | Where-Object { $_.name -eq "qwen3:8b" -or $_.name -like "qwen3:8b*" } | Select-Object -First 1
if (-not $qwenModel) {
    Write-Error "qwen3:8b was not found in local Ollama. Run 'ollama list' to verify."
}
Write-Host "[3/7] Verified model: $($qwenModel.name) (digest: $($qwenModel.digest.Substring(0,12)))" -ForegroundColor Cyan

# 4. Verify Rashkar prompt builder & guardrails
Set-Location $RepoRoot
$env:PYTHONPATH = $RepoRoot
python -c "from cropnet.services.api.app.core.config import settings; from cropnet.services.api.app.services.llm.prompt_builder import ExplanationPromptBuilder; assert settings.OLLAMA_MODEL == 'qwen3:8b'; print('Prompt builder & model verified:', settings.OLLAMA_MODEL)"
Write-Host "[4/7] Verified Rashkar prompts and qwen3:8b configuration." -ForegroundColor Cyan

# 5. Load or generate persistent local OLLAMA_AUTH_TOKEN (never printed to logs)
if (-not (Test-Path $EnvFile)) {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = [Convert]::ToBase64String($bytes) -replace '[+/=]', ''
    "OLLAMA_AUTH_TOKEN=$token" | Set-Content -Path $EnvFile -Encoding UTF8
    icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
    Write-Host "[5/7] Created protected tunnel token at $EnvFile (copy value into Render OLLAMA_AUTH_TOKEN)." -ForegroundColor Yellow
} else {
    Write-Host "[5/7] Loaded existing protected tunnel token from $EnvFile." -ForegroundColor Cyan
}

$tokenLine = Get-Content $EnvFile | Where-Object { $_ -match "^OLLAMA_AUTH_TOKEN=" } | Select-Object -First 1
$authToken = ($tokenLine -replace "^OLLAMA_AUTH_TOKEN=", "").Trim()

# 5b. Start local Crop Doctor PyTorch server on 127.0.0.1:11436 if not running
$cdReady = $false
try {
    $cdHealth = Invoke-RestMethod -Uri "http://127.0.0.1:11436/health" -TimeoutSec 2 -ErrorAction Stop
    if ($cdHealth.loaded) { $cdReady = $true }
} catch {}

if (-not $cdReady) {
    Write-Host "[5b/8] Starting Crop Doctor PyTorch server (neghani/plantvillage-mobilenetv2) on 127.0.0.1:11436..." -ForegroundColor Cyan
    $cdCmd = "python '$PSScriptRoot\crop_doctor_local_server.py'"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $cdCmd -WindowStyle Minimized
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        try {
            $cdHealth = Invoke-RestMethod -Uri "http://127.0.0.1:11436/health" -TimeoutSec 3 -ErrorAction Stop
            if ($cdHealth.loaded) { $cdReady = $true; break }
        } catch {}
    }
    if (-not $cdReady) {
        Write-Error "Crop Doctor PyTorch server did not become ready on 127.0.0.1:11436."
    }
}
Write-Host "[5b/8] Crop Doctor ready: $($cdHealth.model_id) on 127.0.0.1:11436" -ForegroundColor Green

# 6. Start authenticated proxy on 127.0.0.1:11435 if not running
$proxyRunning = $false
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:11435/api/tags" -TimeoutSec 2 -ErrorAction Stop | Out-Null
    $proxyRunning = $true
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        $proxyRunning = $true
    }
}

if (-not $proxyRunning) {
    Write-Host "[6/7] Starting authenticated Ollama proxy on 127.0.0.1:11435..." -ForegroundColor Cyan
    $proxyCmd = "`$env:OLLAMA_AUTH_TOKEN='$authToken'; python '$PSScriptRoot\ollama_tunnel_proxy.py'"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $proxyCmd -WindowStyle Minimized
    Start-Sleep -Seconds 2
} else {
    Write-Host "[6/7] Authenticated Ollama proxy already running on 127.0.0.1:11435." -ForegroundColor Cyan
}

# Verify unauthenticated request is rejected (401) and authenticated request succeeds (200)
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:11435/api/tags" -TimeoutSec 3 -ErrorAction Stop | Out-Null
    Write-Error "SECURITY ERROR: Unauthenticated request to 127.0.0.1:11435 was NOT rejected!"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 401) {
        Write-Error "Unexpected status from proxy auth check: $($_.Exception.Message)"
    }
}

$authCheck = Invoke-RestMethod -Uri "http://127.0.0.1:11435/api/tags" -Headers @{ Authorization = "Bearer $authToken" } -TimeoutSec 4
$cdProxyCheck = Invoke-RestMethod -Uri "http://127.0.0.1:11435/crop-doctor/status" -Headers @{ Authorization = "Bearer $authToken" } -TimeoutSec 4
Write-Host "[6/8] Proxy security verified: unauthenticated=401, Ollama=200 ($($authCheck.models.Count) models), CropDoctor=$($cdProxyCheck.loaded)" -ForegroundColor Green

# 7. Start ngrok static domain tunnel if configured
$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
$ngrokExe = if ($ngrokCmd) { $ngrokCmd.Source } else {
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ngrok.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\*ngrok*\ngrok.exe", "C:\Program Files\ngrok\ngrok.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $ngrokExe) {
    Write-Host "[7/7] ngrok is NOT installed yet. Install with: winget install Ngrok.Ngrok" -ForegroundColor Yellow
    Write-Host "      Then authenticate once: ngrok config add-authtoken <YOUR_NGROK_TOKEN>" -ForegroundColor Yellow
    Write-Host "      Then re-run with: powershell -ExecutionPolicy Bypass -File .\scripts\start_rashkar_ollama_tunnel.ps1 -NgrokDomain <your-static>.ngrok-free.dev" -ForegroundColor Yellow
    exit 0
}

if (-not $NgrokDomain) {
    Write-Host "[7/7] Pass -NgrokDomain <your-static>.ngrok-free.dev (or set NGROK_STATIC_DOMAIN) to start the HTTPS tunnel." -ForegroundColor Yellow
    exit 0
}

$ngrokExisting = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if (-not $ngrokExisting) {
    Write-Host "[7/8] Starting ngrok HTTPS tunnel: https://$NgrokDomain -> http://127.0.0.1:11435" -ForegroundColor Green
    Start-Process -FilePath $ngrokExe -ArgumentList "http", "--domain=$NgrokDomain", "11435" -WindowStyle Minimized
    Start-Sleep -Seconds 3
} else {
    Write-Host "[7/8] ngrok process already running; verifying tunnel https://$NgrokDomain..." -ForegroundColor Cyan
}

$tunnelTags = Invoke-RestMethod -Uri "https://$NgrokDomain/api/tags" -Headers @{
    Authorization = "Bearer $authToken"
    "ngrok-skip-browser-warning" = "true"
} -TimeoutSec 8
$tunnelCd = Invoke-RestMethod -Uri "https://$NgrokDomain/crop-doctor/status" -Headers @{
    Authorization = "Bearer $authToken"
    "ngrok-skip-browser-warning" = "true"
} -TimeoutSec 8
Write-Host "----------------------------------------------------------" -ForegroundColor Green
Write-Host " Ollama (qwen3:8b) : READY ($($tunnelTags.models.Count) models)" -ForegroundColor Green
Write-Host " Crop Doctor (PyTorch) : READY ($($tunnelCd.model_id))" -ForegroundColor Green
Write-Host " Auth Proxy (11435)    : READY" -ForegroundColor Green
Write-Host " Ngrok Tunnel          : CONNECTED (https://$NgrokDomain)" -ForegroundColor Green
Write-Host "----------------------------------------------------------" -ForegroundColor Green
