# MQTT 闭环模拟 — 无需 BearPi，用 mosquitto 客户端向 EMQX 发光照/状态
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\mqtt-simulate.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\mqtt-simulate.ps1 -DeviceSn SN-RM-001 -Intensity 25

param(
    [string]$DeviceSn = "SN-RM-001",
    [double]$Intensity = 25.0,
    [string]$EmqxContainer = "streetlight-emqx",
    [int]$BrokerPort = 1883
)

$ErrorActionPreference = "Stop"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$lightPayload = (@{
    deviceSn        = $DeviceSn
    lightIntensity  = $Intensity
    timestamp       = $ts
} | ConvertTo-Json -Compress)

$statusPayload = (@{
    deviceSn  = $DeviceSn
    status    = if ($Intensity -lt 30) { "ON" } else { "OFF" }
    timestamp = $ts
} | ConvertTo-Json -Compress)

$dockerNet = @("--network", "container:$EmqxContainer")
$brokerHost = "127.0.0.1"

Write-Host ">>> 发布光照: smart-light/$DeviceSn/light"
Write-Host "    $lightPayload"
docker run --rm @dockerNet eclipse-mosquitto:2 mosquitto_pub `
    -h $brokerHost -p $BrokerPort `
    -t "smart-light/$DeviceSn/light" `
    -m $lightPayload

Write-Host ">>> 发布状态: smart-light/$DeviceSn/status"
Write-Host "    $statusPayload"
docker run --rm @dockerNet eclipse-mosquitto:2 mosquitto_pub `
    -h $brokerHost -p $BrokerPort `
    -t "smart-light/$DeviceSn/status" `
    -m $statusPayload

Write-Host ""
Write-Host "验收："
Write-Host "  1. 后端日志出现 MQTT 收到消息"
Write-Host "  2. 灯廊 Dashboard 实时光照更新、统计卡片刷新"
Write-Host "  3. 光照 < 30 时应触发 AUTO_ON（控制日志可查）"
Write-Host ""
Write-Host "订阅 command（另开终端）："
Write-Host "  docker run -it --rm --network container:$EmqxContainer eclipse-mosquitto:2 mosquitto_sub -h 127.0.0.1 -p $BrokerPort -t smart-light/$DeviceSn/command -v"
