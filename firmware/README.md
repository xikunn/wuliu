# 板端固件（BearPi-HM Nano）

## 实际源码位置

OpenHarmony 目录很深，直接放在 Desktop 长路径下容易导致 DevEco **编译失败**。  
因此物理克隆在：

```text
D:\ohos\bearpi-hm_nano
```

本目录下的 `bearpi-hm_nano` 是指向上述路径的 **目录联接（junction）**，在资源管理器 / Cursor 里可当项目子目录使用。

来源：https://gitee.com/bearpi/bearpi-hm_nano （shallow clone）

## DevEco 导入哪个文件夹

导入下面**任一**路径即可（内容相同）：

- `D:\ohos\bearpi-hm_nano`（推荐，路径最短）
- `…\wuliu-main\firmware\bearpi-hm_nano`

**不要**导入 `smart-street-light-master`。

导入后：SOC / 板型选 **Hi3861 / BearPi-HM Nano**，再配置 `compiler_bin_path` 与 COM 口，Build → Upload。

## 与仓库的关系

- `smart-street-light-master`：智慧路灯云端后端（Spring Boot）
- `web/`：路灯控制台前端「灯廊」
- `firmware/bearpi-hm_nano`：官方 sample；对接路灯时改 MQTT topic 为 `smart-light/{deviceSn}/…`
- **`docs/hardware/BEARPI-PLAN.md`**：小熊派模块选型、MQTT 数据、C3→D5→合并路线图
- **`firmware/streetlight/`**：合并固件源码（本仓跟踪）
- **`firmware/scripts/`**：`enable-sample.ps1`、`check-env.ps1`、`sync-streetlight-sample.ps1`

建议将 `firmware/bearpi-hm_nano/` 加入 `.gitignore`（体积大、自带 `.git`），不要整仓提交进业务 Git。
