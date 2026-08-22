# 将本仓 firmware/streetlight 同步到 BearPi sample 目录（阶段 D 合并固件）
# 用法: powershell -ExecutionPolicy Bypass -File firmware\scripts\sync-streetlight-sample.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'streetlight'
$bearpi = 'D:\ohos\bearpi-hm_nano'
$dest = Join-Path $bearpi 'applications\BearPi\BearPi-HM_Nano\sample\E_streetlight_mqtt'

if (-not (Test-Path $bearpi)) {
    Write-Error "BearPi root not found: $bearpi"
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'src') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'include') | Out-Null

Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
Write-Host "Synced -> $dest"
Write-Host "Then: enable-sample.ps1 -Sample STREETLIGHT"
