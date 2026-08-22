# 智慧路灯合并固件（阶段 D）

本目录代码由本仓 Git 跟踪；通过 `firmware/scripts/sync-streetlight-sample.ps1` 同步到 BearPi 工程。

## 前置

1. 阶段 B：`C3_e53_sc1_pls` 验收 BH1750 + GPIO_7  
2. 阶段 C：`D5_iot_mqtt` 验收 WiFi + MQTT  
3. 复制配置：`cp streetlight_config.h.example streetlight_config.h` 并填写 WiFi / Broker IP / `DEVICE_SN`

## 同步与编译

```powershell
powershell -ExecutionPolicy Bypass -File firmware\scripts\sync-streetlight-sample.ps1
powershell -ExecutionPolicy Bypass -File firmware\scripts\enable-sample.ps1 -Sample STREETLIGHT
```

DevEco：**Build → Upload**，串口查看 `published light` / `command arrived`。

## 依赖文件

同步前需存在（从官方 sample 复制，首次 sync 脚本不自动复制驱动）：

- `src/E53_SC1.c`、`include/E53_SC1.h` ← `C3_e53_sc1_pls`
- `src/wifi_connect.c`、`include/wifi_connect.h` ← `D5_iot_mqtt`

或运行：

```powershell
$bp = 'D:\ohos\bearpi-hm_nano\applications\BearPi\BearPi-HM_Nano\sample'
Copy-Item "$bp\C3_e53_sc1_pls\src\E53_SC1.c","$bp\C3_e53_sc1_pls\include\E53_SC1.h" -Destination firmware\streetlight\ -Recurse
# ... 见 BEARPI-PLAN.md
```

## 端到端

Web 添加同 `DEVICE_SN` 设备 → Dashboard 实时光照 → 手动开关 → 板子 `status` 回传。
