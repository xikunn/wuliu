# BearPi 硬件探索与开发规划（智慧路灯）

> **日期：** 2026-08-22  
> **产品：** 智慧路灯「灯廊」  
> **契约真源：** `smart-street-light-master/API文档.md` § MQTT  
> **板端源码：** `D:\ohos\bearpi-hm_nano`（junction：`firmware/bearpi-hm_nano`，勿整树提交 Git）

---

## 1. 硬件选型结论

| 组件 | 型号 | 本项目用途 |
|------|------|------------|
| 主控 | **BearPi-HM Nano**（Hi3861） | WiFi STA、MQTT 客户端、GPIO/I2C |
| 扩展板 | **E53_SC1 智慧路灯盾** | BH1750 光照 + GPIO_7 灯控 |
| 网络 | 实验室 WiFi → PC/服务器 EMQX `:1883` | 板不直连 Web/DB |
| 可选 | E53_IS1 人体红外 | 答辩加分，MVP 不做 |

**不采用：** 华为 IoT OC（`$oc/devices/...`）、OneNET — 官方 D9/D6 的 topic 需改为本项目 `smart-light/{deviceSn}/…`。

---

## 2. E53_SC1 引脚与 API（C3 sample）

| 功能 | 硬件 | 驱动 API |
|------|------|----------|
| 光照 | BH1750，I2C `0x23` | `E53_SC1_Init()`、`E53_SC1_Read_Data()` → lux (float) |
| 灯控 | GPIO_7 数字输出 | `Light_StatusSet(ON/OFF)` |

官方 sample：`applications/BearPi/BearPi-HM_Nano/sample/C3_e53_sc1_pls`

验收：串口每秒打印 `Lux data:xx.xx`；遮光 < 20 lux 时补光灯亮。

---

## 3. 板 ↔ 云 MQTT 数据（与后端对齐）

### 上行（板 publish）

| Topic | QoS | Payload |
|-------|-----|---------|
| `smart-light/{deviceSn}/light` | 0 | `{"deviceSn","lightIntensity","timestamp"}` |
| `smart-light/{deviceSn}/status` | 0 | `{"deviceSn","status":"ON\|OFF","timestamp"}` |
| `smart-light/{deviceSn}/alarm` | 1 | `{"deviceSn","alarmType","message","timestamp"}`（可选） |

### 下行（板 subscribe）

| Topic | QoS | Payload |
|-------|-----|---------|
| `smart-light/{deviceSn}/command` | 1 | `{"command":"AUTO_ON\|AUTO_OFF\|MANUAL_ON\|MANUAL_OFF","timestamp"}` |

**规则：** 阈值判定在云端；板收到 command 后 GPIO 动作，再 publish `status`。周期 `light` 即隐式心跳。

`deviceSn` 必须与 Web「设备」页添加时完全一致（如 `SN-RM-001`）。

---

## 4. 官方 Sample 地图（34 个，与本项目相关）

| 阶段 | Sample | 路径 | 学到什么 |
|------|--------|------|----------|
| **①** | `C3_e53_sc1_pls` | `sample/C3_e53_sc1_pls` | BH1750 + GPIO_7 |
| **②** | `D5_iot_mqtt` | `sample/D5_iot_mqtt` | WiFi + Paho MQTT pub/sub |
| 参考 | `D9_iot_cloud_oc_light` | `sample/D9_iot_cloud_oc_light` | 路灯业务结构（topic 需改） |
| WiFi 基础 | `D2_iot_wifi_sta_connect` | — | 仅连网时可用 |

当前 `BUILD.gn` 默认编译 `Z2_hi3861_flash_ylc`，**每次只启用一个 sample**。

---

## 5. 分阶段实施计划（当前执行顺序）

### 阶段 A — 环境（Must）

- [ ] 安装 **DevEco Studio**（HarmonyOS / Hi3861）
- [ ] USB 驱动 + 识别 COM 口（设备管理器）
- [ ] 导入工程：`D:\ohos\bearpi-hm_nano`，板型 **BearPi-HM Nano / Hi3861**
- [ ] 配置 `compiler_bin_path`、烧录端口
- [ ] PC 端：Docker EMQX `:1883` + Spring Boot `:8080`（见 `smart-street-light-master/LOCAL-RUN.md`）
- [ ] 板与 PC **同一 WiFi 网段**（D5 需填 PC 局域网 IP）

辅助脚本：`firmware/scripts/enable-sample.ps1`、`firmware/scripts/check-env.ps1`

### 阶段 B — C3：传感器 + 灯控

```powershell
powershell -ExecutionPolicy Bypass -File firmware\scripts\enable-sample.ps1 -Sample C3
```

DevEco：**Build → Upload**，串口 115200 查看日志。

| 验收项 | 期望 |
|--------|------|
| BH1750 | 串口持续输出 `Lux data:xx.xx` |
| GPIO_7 | 遮光（< 20 lux）灯亮，移开灯灭 |

### 阶段 C — D5：MQTT pub/sub

```powershell
# 修改 D5 iot_mqtt.c：WifiConnect SSID/PSK、Broker IP（PC 局域网 IP）
powershell -ExecutionPolicy Bypass -File firmware\scripts\enable-sample.ps1 -Sample D5
```

Broker 可用本机 Docker EMQX（`allow_anonymous`）或 `mqtt-simulate.ps1` 同网段访问。

| 验收项 | 期望 |
|--------|------|
| 连接 | 串口 `WiFi connect succeed`、`MQTTConnect` 成功 |
| 上行 | Paho/MQTTX 订阅 `pubtopic` 收到计数消息 |
| 下行 | 向 `substopic` 发布，串口打印 `Message arrived` |

### 阶段 D — 合并路灯固件

源码骨架（本仓跟踪）：`firmware/streetlight/`

```powershell
powershell -ExecutionPolicy Bypass -File firmware\scripts\sync-streetlight-sample.ps1
powershell -ExecutionPolicy Bypass -File firmware\scripts\enable-sample.ps1 -Sample STREETLIGHT
```

逻辑：

1. `WifiConnect` → MQTT 连 EMQX  
2. 订阅 `smart-light/{deviceSn}/command`  
3. 定时读 BH1750 → publish `.../light`  
4. 收到 command → `Light_StatusSet` → publish `.../status`  

配置模板：`firmware/streetlight/streetlight_config.h`（从 `.example` 复制）

### 阶段 E — 端到端闭环（全员）

1. Web 添加设备，`deviceSn` 与固件一致  
2. 板子上电上报 `light`  
3. Dashboard 实时光照更新（WS）  
4. Web 手动开/关灯 → 板收 `MANUAL_ON/OFF` → `status` 回传  
5. 遮光验证云端 `AUTO_ON`（阈值默认开灯 < 30 lux）

---

## 6. 配置对齐表

| 配置项 | 板端 | 云端/Web |
|--------|------|----------|
| deviceSn | `streetlight_config.h` | 设备页添加 |
| WiFi | `WIFI_SSID` / `WIFI_PSK` | 同网段可访问 EMQX |
| EMQX | `MQTT_BROKER_IP` `:1883` | Docker `streetlight-emqx` |
| MQTT 认证 | 空（本地匿名）或 secret 一致 | `application-secret.yml` |
| 阈值 | 不配置 | Web ADMIN 阈值页 / DB |

---

## 7. 查阅来源索引

| 文档 | 路径 |
|------|------|
| 板端 README | `firmware/README.md` |
| MQTT 契约摘要 | `docs/contracts/mqtt.md` |
| API 真源 | `smart-street-light-master/API文档.md` |
| 联调清单 §3 | `docs/collab/发件箱/2026-08-22-联调清单-全员.md` |
| C3 README | `bearpi-hm_nano/.../sample/C3_e53_sc1_pls/README.md` |
| D5 README | `bearpi-hm_nano/.../sample/D5_iot_mqtt/README.md` |
| 本地云端 | `smart-street-light-master/LOCAL-RUN.md` |
| MQTT 模拟（无板） | `smart-street-light-master/scripts/mqtt-simulate.ps1` |

---

## 8. 风险与注意

- `firmware/bearpi-hm_nano` 已 gitignore，**sample 修改在 D 盘**，本仓用 `firmware/streetlight/` 跟踪自定义固件  
- DevEco 路径过深会编译失败 → 必须用 `D:\ohos\bearpi-hm_nano`  
- D5 默认 Broker `192.168.0.176`、WiFi `Hold` — **必须改成本机 IP 和真实 SSID**  
- 板端不走 HTTP 降级（需 JWT）；只走 MQTT  
- 每次只启用一个 `BUILD.gn` sample，避免链接冲突

---

## 9. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-08-22 | 初版：模块选型、MQTT 契约、C3→D5→合并→闭环路线图 |
