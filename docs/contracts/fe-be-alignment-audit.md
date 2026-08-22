# 前后端对齐审计（灯廊 web ↔ smart-street-light）

> 日期：2026-08-22  
> 真源：[`smart-street-light-master/API文档.md`](../../smart-street-light-master/API文档.md)  
> 前端：`web/src/api/*`、`web/src/stores/realtime.ts`、各 View  
> 结论：**核心业务 REST + STOMP 主路径已对齐，可 Mock 演示；真后端联调与硬件/MQTT/云端基础设施尚未补齐。**

---

## 1. 结论摘要

| 维度 | 状态 | 说明 |
|------|------|------|
| REST（前端用户操作） | **基本对齐** | `client.ts` 覆盖 API 文档 §1–§6 中所有「前端调用」接口（除详情类只读接口） |
| WebSocket（STOMP） | **部分对齐** | 4 个 topic 均已订阅；仅光照/告警有 UI 消费，设备状态/在线未驱动页面刷新 |
| 后端 §8 AI/RAG | **未对齐** | 后端已实现 `/knowledge-chunks/*`，前端无页面与 API 封装 |
| 硬件/MQTT 通道 | **不在前端范围** | 由 BearPi + EMQX + 后端 MqttConfig 承担；HTTP 降级通道存在鉴权缺口（见 §5） |
| 云端运行环境 | **缺失** | 本地需 Docker(PG+EMQX) + JDK21 + Maven + `application-secret.yml` + 建库脚本 |
| 角色权限 | **仅前端约束** | 后端只校验 JWT，不校验 ADMIN；与 UI「阈值仅管理员」不一致 |

**整体判断：** 前端 MVP 与后端 API **契约层面对齐完成约 85%**（按前端页面所需接口计约 **95%**）；**端到端可演示**依赖 Mock；**端到端真联调**还差云端部署、CORS/代理配置验证、WS 刷新策略、板端 MQTT 适配。

---

## 2. REST 接口对照

约定：`✅` 前端 client + 页面使用 · `△` client 有、页面未用 · `—` 非前端职责 · `✗` 后端有、前端无

### 2.1 用户（§1）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `POST /users/register` | ✅ | ✅ | LoginView 注册 | `role` 可选；后端默认 `MUNICIPAL_STAFF` |
| `POST /users/login` | ✅ | ✅ | LoginView | Header `token` 与后端一致 |

### 2.2 设备（§2）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `GET /devices` | ✅ | ✅ | DevicesView、LightsView | 支持 name/status/onlineStatus 筛选 |
| `GET /devices/{id}` | ✅ | △ | — | **缺设备详情页**（含 latestLight、activeAlarmCount） |
| `POST /devices` | ✅ | ✅ | DevicesView | |
| `PUT /devices/{id}` | ✅ | △ | — | **缺改名 UI** |
| `DELETE /devices/{id}` | ✅ | ✅ | DevicesView | 无二次确认 |
| `GET /devices/statistics` | ✅ | ✅ | DashboardView | |
| `POST /devices/{id}/switch` | ✅ | ✅ | DevicesView | 市政人员 UI 也可操作；后端无角色限制 |
| `POST /devices/status-callback` | ✅ | — | — | 硬件/MQTT 网关 |
| `POST /devices/heartbeat` | ✅ | — | — | 硬件备用 |

### 2.3 光照（§3）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `GET /light-readings` | ✅ | ✅ | LightsView | 未传 startTime/endTime（后端支持，UI 未暴露） |
| `GET /light-readings/latest/{deviceId}` | ✅ | △ | — | Dashboard 走 WS/Mock，未调 REST |
| `GET /light-readings/trend` | ✅ | ✅ | LightsView | **时间范围写死** `2026-08-22 00:00:00`–`23:59:59`，真数据下可能为空 |
| `POST /light-readings` | ✅ | — | — | 硬件/MQTT |

### 2.4 告警（§4）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `GET /alarm-logs` | ✅ | ✅ | AlarmsView | UI 仅筛 `status`，未筛 `deviceId` / `alarmType` |
| `GET /alarm-logs/{id}` | ✅ | ✗ | — | 可选：详情抽屉 |
| `PUT /alarm-logs/{id}/resolve` | ✅ | ✅ | AlarmsView | |
| `GET /alarm-logs/statistics` | ✅ | ✅ | DashboardView | 仅展示 `activeCount`，未展示 `byType` |
| `POST /alarm-logs` | ✅ | — | — | 硬件/系统 |

### 2.5 阈值（§5）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `GET /threshold-config` | ✅ | ✅ | ThresholdView | 路由 + 导航 **admin 门控** |
| `PUT /threshold-config` | ✅ | ✅ | ThresholdView | 后端未限制 ADMIN |

### 2.6 控制日志（§6）

| 接口 | 后端 | 前端 client | 页面 | 备注 |
|------|------|-------------|------|------|
| `GET /control-logs` | ✅ | ✅ | ControlLogsView | 未用 `command` / `operatorId` 筛选 |
| `GET /control-logs/{id}` | ✅ | ✗ | — | 可选 |

### 2.7 大模型 / RAG（§8 + 代码扩展）

API 文档仅描述 `POST /knowledge-chunks/chat`；代码中还有：

| 接口 | 后端 | 前端 | 说明 |
|------|------|------|------|
| `POST /knowledge-chunks/chat` | ✅ | ✗ | 单轮对话（文档 §8） |
| `POST /knowledge-chunks/rag` | ✅ | ✗ | 与 chat 相同，走 RAG 检索 |
| `POST /knowledge-chunks/import` | ✅ | ✗ | 批量导入知识文档（需 pgvector + LLM key） |

`vite.config.ts` 已为 `/knowledge-chunks` 配置 dev proxy，但 **前端未封装、无 UI**。

---

## 3. WebSocket（STOMP）对照

| Topic | 消息类型 | 后端触发 | 前端订阅 | UI 行为 | 差距 |
|-------|----------|----------|----------|---------|------|
| `/topic/light-readings` | `LIGHT_REPORTED` | 光照上报 | ✅ | Dashboard 实时光照 | 见 §4 类型问题 |
| `/topic/device-status` | `DEVICE_STATUS_CHANGED` | 自动/手动/回传 | ✅ | **空回调** | 设备页/总览不自动刷新 |
| `/topic/device-online` | `DEVICE_ONLINE_STATUS_CHANGED` | 上线/离线 | ✅ | **空回调** | 在线数/列表不自动更新 |
| `/topic/alarms` | `ALARM_CREATED` | 新告警 | ✅ | AppShell  toast | 告警列表页不自动刷新 |

连接：`ws://host:8080/ws?token={jwt}` — 与文档一致。Mock 模式用定时器模拟光照，不连 WS。

---

## 4. 契约/实现细项差异（非新接口，但联调会踩坑）

### 4.1 WS 消息体结构

后端推送 `WebSocketMessage`：`{ type, timestamp, data }`。前端解析 `JSON.parse(msg.body).data` — **正确**。

### 4.2 字段类型

后端 `LatestLightVO.deviceId` 在部分路径为 **String**（见 `LightReadingsServiceImpl`），前端类型为 **number**。联调时 Dashboard/图表需做兼容。

### 4.3 分页默认值

前端多处写死 `pageSize: 50` 或 `100`，与文档默认 10 一致可用，大数据量时需分页 UI（**非必须新接口**）。

### 4.4 光照趋势时间

`LightsView.vue` 硬编码日期，联调真库时应改为「当天」或日期选择器 — **纯前端改动，无需新接口**。

### 4.5 JWT 15 分钟

文档规定 token 15 分钟有效；前端 **无 refresh、无 401 统一跳转登录**。长会话会 silent fail — 可前端补拦截器或后端加长/refresh（**可选新接口：refresh token，当前后端无**）。

### 4.6 角色与权限

| 能力 | 前端 | 后端 |
|------|------|------|
| 阈值配置 | 仅 ADMIN 可见 | 任意登录用户可调 |
| 设备增删改、开关 | 所有登录用户 | 任意登录用户 |
| 注册为 ADMIN | 注册表单可选 | 接口允许传 `role=ADMIN` |

答辩演示可接受；生产需后端 `@PreAuthorize` 或等价拦截 — **非新 REST 字段，是后端加固**。

### 4.7 硬件 HTTP 降级与 JWT

`HttpAuthInterceptor` 仅放行 `/users/register`、`/users/login`。以下硬件 HTTP 接口 **同样需要 Header token**：

- `POST /devices/status-callback`
- `POST /devices/heartbeat`
- `POST /light-readings`
- `POST /alarm-logs`

若 BearPi 只走 **MQTT → EMQX → 后端订阅**，无影响。若走 HTTP 模拟硬件，需在 `WebMvcConfiguration` **excludePathPatterns** 或设备级 API Key — **云端/backend 待补齐，非前端接口**。

---

## 5. 是否需要「额外接口」？

### 5.1 前端已够用、**不需要**向后端要新接口

- 设备详情、编辑名称、告警详情、日志详情 → 后端 **已有** GET/PUT，补 UI 即可  
- 趋势图日期、告警按设备筛选、Dashboard 按类型统计 → **现有查询参数** 已支持  
- WS 驱动刷新 → **现有 4 个 topic** 已够，补前端订阅回调即可  

### 5.2 后端已有、前端**未接入**（不是新接口，是新产品能力）

| 能力 | 接口 | 建议 |
|------|------|------|
| AI 运维问答 | `POST /knowledge-chunks/chat` 或 `/rag` | 答辩加分项：单独「运维助手」页 |
| 知识库导入 | `POST /knowledge-chunks/import` | ADMIN 维护页；依赖 LLM + pgvector |

### 5.3 可选、当前双方都**没有**的接口（仅在有明确需求时再定）

| 需求 | 说明 |
|------|------|
| `POST /users/refresh` | 长会话免登；MVP 可不做 |
| 设备绑定/解绑用户 | 文档无；多租户才需要 |
| 批量开关灯 | 文档无；可循环调 `switch` 或后端加 batch |
| 固件 OTA | 文档无；实训范围外 |

**结论：当前阶段不需要向后端申请新的 REST 契约**；优先补 **云端部署 + MQTT 板端 + 前端 WS 刷新与趋势时间**。

---

## 6. 缺失的云端部分及补齐步骤

### 6.1 基础设施清单

| 组件 | 配置来源 | 当前缺口 |
|------|----------|----------|
| PostgreSQL | `application.yml` → `10.59.47.188:5432` | 远程不可达时需 **本地 Docker**（`docker.sh` / `pgvector/pgvector:pg17`） |
| EMQX | `mqtt.broker-url` → `tcp://10.59.47.188:1883` | 同上；本地 `emqx:latest` 1883 + 18083 控制台 |
| Spring Boot | `:8080` | 需 **JDK 21** + **Maven**；本机此前仅 JDK 17 |
| 密钥配置 | `application-secret.yml` | 从 `application-secret-example.yml` 复制：DB 密码、JWT secret、MQTT 账号、**llm.api-key** |
| 数据库 schema | `sql/schema.sql` | 建库 `smart-street-light` + pgvector + 默认阈值行 |
| 测试数据 | `sql/test-data.sql` | 可选：预置用户/设备 |

### 6.2 推荐本地联调顺序

```text
1. Docker 启动 PostgreSQL + EMQX（改 application.yml 指向 localhost）
2. 执行 sql/schema.sql（+ test-data.sql）
3. 创建 application-secret.yml
4. mvn package && java -jar target/smart-street-light-*.jar
5. web/.env.local：
     VITE_API_MODE=http
     VITE_API_BASE=          # dev 留空，走 vite proxy
     VITE_WS_BASE=ws://localhost:8080
6. npm run dev → 注册/登录 → 添加 deviceSn 与板端一致的设备
7. BearPi 发布 smart-light/{deviceSn}/light|status|alarm；订阅 command
```

### 6.3 后端服务内逻辑（已具备，无需前端改接口）

- 光照上报 → 写库 + 阈值判定 + MQTT command + WS 推送  
- 心跳超时 → `@Scheduled` 每 30s + OFFLINE 告警 + WS  
- 手动开关 → 更新 DB + control_logs + MQTT `MANUAL_ON/OFF` + WS  

前端在 HTTP 模式下 **手动开关** 会立即改库；硬件最终状态以 `status` topic 回传为准。

### 6.4 板端（firmware）

- 源码：`D:\ohos\bearpi-hm_nano`（junction 见 `firmware/README.md`）  
- Topic 对齐：`smart-light/{deviceSn}/light|status|alarm|command`  
- **尚未**在 sample 中完成 MQTT  payload 与 SN 配置 — 与云端并行项  

### 6.5 AI/RAG 云端依赖（可选模块）

- PostgreSQL **pgvector** 扩展 + `knowledge_chunks` 表（见 schema）  
- `llm.api-key` / `base-url` / `model`  
- 导入文档后 `/rag` 才有检索增强；无 key 时 chat 接口会失败  

---

## 7. 建议实施优先级（MoSCoW）

### Must（联调最小闭环）

1. 本地 PG + EMQX + 后端启动 + `sql/schema.sql` — 步骤见 [联调清单 §1](../collab/发件箱/2026-08-22-联调清单-全员.md)  
2. `web` 设 `VITE_API_MODE=http` — 见 `web/.env.example`  
3. BearPi 至少 **light + command** 一条链路 — 见联调清单 §3  
4. 修复 `LightsView` 趋势时间为动态「当天」 — **已完成**（`web/src/utils/datetime.ts`）  

### Should（演示体验）

5. WS 订阅 `device-status` / `device-online` 时刷新 Dashboard + Devices  
6. 401 统一提示并跳转登录  
7. `LatestLightVO.deviceId` 类型兼容  

### Could（答辩加分）

8. 设备详情页（`GET /devices/{id}`）  
9. AI 运维助手页（`/knowledge-chunks/chat`）  
10. Dashboard 展示 `alarmStatistics.byType`  

### Won't（本阶段）

- 新 REST 契约（batch、refresh、OTA）  
- 后端角色鉴权（除非答辩安全问答需要）  

---

## 8. 相关文件索引

| 用途 | 路径 |
|------|------|
| API 真源 | `smart-street-light-master/API文档.md` |
| 前端 API 层 | `web/src/api/client.ts`、`types.ts`、`mock.ts` |
| 实时 | `web/src/stores/realtime.ts` |
| Dev 代理 | `web/vite.config.ts` |
| 建库 | `smart-street-light-master/sql/schema.sql` |
| Docker 示例 | `smart-street-light-master/docker.sh` |
| 板端说明 | `firmware/README.md` |
| HTTP 摘要 | [http.md](http.md) |
| MQTT 摘要 | [mqtt.md](mqtt.md) |

---

## 9. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-08-22 | 初版：灯廊 web 对齐路灯后端审计 + 云端补齐清单 |
