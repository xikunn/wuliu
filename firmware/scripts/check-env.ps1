# BearPi + local cloud environment check
# Usage: powershell -ExecutionPolicy Bypass -File firmware\scripts\check-env.ps1

$ErrorActionPreference = 'Continue'
$ok = 0
$fail = 0
$hint = 0

function Pass($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green; $script:ok++ }
function Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ }
function Hint($msg) { Write-Host "[....] $msg" -ForegroundColor Yellow; $script:hint++ }

Write-Host "=== BearPi / streetlight env check ===" -ForegroundColor Cyan

$bearpi = 'D:\ohos\bearpi-hm_nano'
if (Test-Path $bearpi) { Pass "BearPi source: $bearpi" } else { Fail "Missing BearPi clone at $bearpi" }

# DevEco Studio OR DevEco Device Tool (both valid for BearPi-HM Nano)
$devecoStudioPaths = @(
    "$env:ProgramFiles\Huawei\DevEco Studio",
    "$env:LocalAppData\Programs\Huawei\DevEco Studio"
)
$devecoStudio = $devecoStudioPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
$devecoDeviceTool = 'C:\Program Files\Huawei\DevEco-Device-Tool'
$bearpiBoardJson = Join-Path $devecoDeviceTool 'platforms\platform-hisilicon_riscv\boards\bearpi_hm_nano.json'

if ($devecoStudio) {
    Pass "DevEco Studio: $devecoStudio"
} elseif (Test-Path $devecoDeviceTool) {
    Pass "DevEco Device Tool: $devecoDeviceTool (4.x, VS Code workflow)"
    if (Test-Path $bearpiBoardJson) {
        Pass 'BearPi-HM Nano board profile bundled (hisilicon_riscv)'
    } else {
        Hint 'BearPi board profile not found in Device Tool platforms'
    }
} else {
    Fail 'Neither DevEco Studio nor DevEco Device Tool found'
}

# VS Code + DevEco extensions (required for Device Tool)
$vscodePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles\Microsoft VS Code\Code.exe"
)
$vscode = $vscodePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($vscode) {
    Pass "VS Code: $vscode"
} elseif (Test-Path $devecoDeviceTool) {
    Fail 'VS Code required for DevEco Device Tool'
}

$extDir = Join-Path $env:USERPROFILE '.vscode\extensions'
if (Test-Path $extDir) {
    $devecoExt = Get-ChildItem $extDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'huawei\.deveco-device-tool' }
    if ($devecoExt) {
        Pass "DevEco VS Code extension: $($devecoExt.Name)"
    } elseif (Test-Path $devecoDeviceTool) {
        Hint 'DevEco Device Tool VS Code extension not detected (open VS Code once after install)'
    }
}

# Python 3.8 (Device Tool dependency)
try {
    $pyVer = & py -3.8 --version 2>&1
    if ($LASTEXITCODE -eq 0) { Pass "Python: $pyVer" } else { Hint 'Python 3.8 not on PATH (py -3.8)' }
} catch {
    Hint 'Python launcher not found'
}

$ports = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue
if ($ports) {
    Pass ("Serial ports: " + ($ports.DeviceID -join ', '))
} else {
    Hint 'No serial port — plug BearPi USB and check Device Manager'
}

try {
    $docker = docker ps --format '{{.Names}}' 2>$null
    if ($docker -match 'streetlight-emqx') { Pass 'EMQX container running' } else { Fail 'EMQX not running' }
    if ($docker -match 'streetlight-pg') { Pass 'PostgreSQL container running' } else { Fail 'PG not running' }
} catch {
    Fail 'Docker not available'
}

try {
    $r = Invoke-RestMethod -Uri 'http://localhost:8080/users/login' -Method POST -ContentType 'application/json' -Body '{"username":"admin","password":"admin123"}' -TimeoutSec 3
    if ($r.code -eq 200) { Pass 'Backend :8080 login OK' } else { Fail "Backend code=$($r.code)" }
} catch {
    Fail 'Backend :8080 not responding'
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
if ($ip) { Pass "LAN IP for D5 MQTT broker: $ip" } else { Hint 'Could not detect LAN IP' }

# C3 sample enabled?
$buildGn = Join-Path $bearpi 'applications\BearPi\BearPi-HM_Nano\sample\BUILD.gn'
if (Test-Path $buildGn) {
    $bg = Get-Content $buildGn -Raw
    if ($bg -match '(?m)^\s+"C3_e53_sc1_pls:e53_sc1_example",') {
        Pass 'BUILD.gn: C3_e53_sc1_pls enabled (phase B ready)'
    } else {
        Hint 'BUILD.gn: C3 not enabled — run enable-sample.ps1 -Sample C3'
    }
}

Write-Host ""
Write-Host "Passed $ok, hints $hint, failed $fail"
if ($fail -gt 0) {
    Write-Host "See docs/hardware/BEARPI-PLAN.md"
    exit 1
}
