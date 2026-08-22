# Switch BearPi-HM_Nano BUILD.gn to compile one sample only.
# Usage:
#   powershell -ExecutionPolicy Bypass -File firmware\scripts\enable-sample.ps1 -Sample C3

param(
    [ValidateSet('C3', 'D5', 'STREETLIGHT', 'Z2')]
    [string]$Sample = 'C3',
    [string]$BearPiRoot = 'D:\ohos\bearpi-hm_nano'
)

$ErrorActionPreference = 'Stop'

$targets = @{
    C3          = 'C3_e53_sc1_pls:e53_sc1_example'
    D5          = 'D5_iot_mqtt:iot_mqtt'
    STREETLIGHT = 'E_streetlight_mqtt:streetlight_mqtt'
    Z2          = 'Z2_hi3861_flash_ylc:flash_example'
}

$buildGn = Join-Path $BearPiRoot 'applications\BearPi\BearPi-HM_Nano\sample\BUILD.gn'
if (-not (Test-Path $buildGn)) {
    throw "BUILD.gn not found: $buildGn"
}

$target = $targets[$Sample]
$lines = Get-Content $buildGn -Encoding UTF8
$out = New-Object System.Collections.Generic.List[string]
$enabled = $false

foreach ($line in $lines) {
    if ($line -match '^\s*#?"[A-Za-z0-9_]+:[^"]+",\s*$') {
        if ($line -match [regex]::Escape($target)) {
            $out.Add(('        "{0}",' -f $target))
            $enabled = $true
        } else {
            if ($line -match '^\s*"') {
                $out.Add(('#' + $line))
            } else {
                $out.Add($line)
            }
        }
    } else {
        $out.Add($line)
    }
}

if (-not $enabled) {
    throw "Target not found in BUILD.gn: $target"
}

Set-Content -Path $buildGn -Value $out -Encoding UTF8
Write-Host "BUILD.gn updated: enabled $Sample -> $target"
Write-Host "Next: DevEco Studio -> Build -> Upload"
