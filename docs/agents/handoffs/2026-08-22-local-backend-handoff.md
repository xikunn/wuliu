# Handoff — 本地后端已跑通 + 灯廊 HTTP 联调（当前）

**日期：** 2026-08-22  
**分支：** `feat/streetlight-web` → `fork`；上游 PR：**https://github.com/xikunn/wuliu/pull/3**（待合并）  
**下一会话建议焦点：** 前端 HTTP 全页验收 + WS 刷新 Should 项；或 BearPi / MQTTX 打通 MQTT 闭环。

---

## 0. 30 秒读这个

| 项 | 内容 |
|----|------|
| **产品** | 智慧路灯「灯廊」，**不是**智慧物流 |
| **契约** | `smart-street-light-master/API文档.md` |
| **已真跑通** | 本机 Docker(PG+EMQX) + Spring Boot :8080 + 登录 API |
| **前端** | `web/` Vue3；`.env.local` → `VITE_API_MODE=http` 连真后端 |
| **仍缺** | 板端 MQTT、WS 驱动页面刷新、401 处理、AI 页、端到端演示 |

先读 [`CONTEXT.md`](../../../CONTEXT.md)，再读本文件。

---

## 1. 不可推翻的边界

1. 交付物 = **板 → MQTT → 云 → 屏**，不是物流运单/地图/GPS。  
2. 物流设计、根目录旧接口文档、物流 handoff **已删**；勿再引入。  
3. HTTP 成功 `code=200`；认证 Header 名 **`token`**（非 Bearer）。  
4. 角色：`ADMIN` / `MUNICIPAL_STAFF`；阈值页仅前端对 ADMIN 隐藏，**后端未做角色拦截**。  
5. 勿提交：`application-secret.yml`、`web/.env.local`、BearPi 整树、`D:\ohos\bearpi-hm_nano`。

---

## 2. Git / PR

| 项 | 值 |
|----|-----|
| 上游 | `xikunn/wuliu` |
| Fork | `Someone-hates-Monday/wuliu` |
| 当前分支 | `feat/streetlight-web` |
| 提交作者 | `Someone-hates-Monday <2872397866@qq.com>` |
| 推送 | **SSH** 可用；HTTPS:443 常失败 |
| 近期提交 | `4382399` 本地联调+总览跳转 · `33cb0ea` 联调清单/审计 · `3eac6a1` 路灯前端重构 |

---

## 3. 已做什么

### 3.1 前端 `web/`（灯廊）

- Vue3 + Pinia + Router + Element Plus + STOMP client  
- 页面：登录/注册、总览、设备、光照、告警、阈值(ADMIN)、控制日志  
- **Mock 默认**；HTTP 模式见 `web/.env.example` / 本地 `.env.local`  
- **总览**：统计卡片 + 实时光照条 **可点击跳转**（带 query 筛选）；「待处理告警」= ACTIVE 未解决数  
- **设备/告警页**：支持 URL `?onlineStatus=`、`?status=`、`?status=ACTIVE`  
- API 层：`web/src/api/client.ts`（mock \| http）

### 3.2 后端 `smart-street-light-master/`

- Spring Boot 3.5.9 / JDK **21** / PG + EMQX + MQTT 订阅 + WS 四 topic + 心跳定时任务  
- **本地跑通套件（新）：**  
  - `docker-compose.yml`（PG **5433**，EMQX **1883**）  
  - `application-local.yml`（profile `local`）  
  - `scripts/init-db.ps1`、`scripts/run-local.ps1`  
  - `LOCAL-RUN.md`  
- 本机已验证：`admin/admin123` 登录 `code=200`；MQTT 连上 EMQX  

### 3.3 文档

| 文档 | 路径 |
|------|------|
| 联调清单 | `docs/collab/发件箱/2026-08-22-联调清单-全员.md` |
| 前后端对齐审计 | `docs/contracts/fe-be-alignment-audit.md` |
| 契约索引 / changelog | `docs/contracts/README.md`、`changelog.md` |
| 协作索引 | `docs/collab/README.md` |
| Agent 索引 | `docs/agents/README.md` |

### 3.4 环境（用户机器）

- JDK **21** 已装（winget）  
- **Maven 未装 PATH**；用 `docker run maven:3.9-eclipse-temurin-21 mvn package` 编译  
- Docker Desktop 可用；与其它 compose（nexent 等）共存，路灯 PG 用 **5433** 避端口冲突  

---

## 4. 还差什么（优先级）

### Must（闭环演示）

- [ ] 前端 **HTTP 模式**全页验收（F1–F8，见联调清单 §2）  
- [ ] **MQTT 一条链路**：MQTTX 或 BearPi → `smart-light/{deviceSn}/light` + 收 `command`  
- [ ] 板端 sample 改 topic（`firmware/README.md`）  

### Should（体验）

- [ ] WS 收到 `device-status` / `device-online` 时 **刷新总览/设备页**（现仅光照/告警 toast）  
- [ ] JWT 15min 过期 → **401 跳转登录**  
- [ ] `LatestLightVO.deviceId` 类型兼容（后端偶发 String）  

### Could（答辩加分）

- [ ] 设备详情页、改名 UI（API 已有）  
- [ ] AI 助手页（`/knowledge-chunks/chat`，后端有、前端无）  
- [ ] Dashboard 展示告警 `byType`  

### Won't / 部署暂缓

- 腾讯云部署、腾讯 IoT Hub 替换 EMQX、新 REST 契约  

---

## 5. 怎么用（复制即用）

### 5.1 起云端（本地）

```powershell
cd smart-street-light-master
docker compose up -d
powershell -ExecutionPolicy Bypass -File scripts\init-db.ps1

# 编译（无本机 mvn 时）
docker run --rm -v "${PWD}:/app" -w /app maven:3.9-eclipse-temurin-21 mvn package -DskipTests

# 运行（需 JDK 21）
java -jar target\smart-street-light-0.0.1-SNAPSHOT.jar --spring.profiles.active=local,secret
```

验收：`POST http://localhost:8080/users/login` body `{"username":"admin","password":"admin123"}` → `code=200`。

详见 **`smart-street-light-master/LOCAL-RUN.md`**。

### 5.2 起前端（真后端）

```powershell
cd web
# .env.local 已配置：VITE_API_MODE=http，VITE_API_BASE= 空，VITE_WS_BASE=ws://localhost:8080
npm run dev
```

登录 **`admin` / `admin123`**（来自 `sql/test-data.sql`）。侧边栏应显示 **`HTTP · LIVE`**（非 MOCK）。

### 5.3 Mock 演示（无后端）

不建 `.env.local` 或 `VITE_API_MODE=mock` → `admin/admin123` 内存假数据。

### 5.4 术语速查

- **待处理告警**：`ACTIVE` 且未点「解决」；启动后 test-data 旧心跳常触发 **OFFLINE**（心跳超时），属预期。  
- **心跳超时**：超过 `heartbeatTimeout` 秒未收到光照/心跳 → 标 OFFLINE + 告警。

---

## 6. 架构一层图

```text
[BearPi/MQTTX] --MQTT 1883--> [EMQX] --> [Spring Boot :8080] --> [PG :5433]
                                    |
                               HTTP + WS
                                    v
                              [灯廊 web :5173/5174]
```

---

## 7. 建议 Skills

| 场景 | Skill |
|------|--------|
| 继续 UI | `.cursor/skills/frontend-design` 或 `wuliu-main/.cursor/skills/frontend-design` |
| 联调/契约 | `team-contract-align` |
| 写 PR / 分工 | `team-contract-align` + `docs/collab/` |
| IoT 答辩叙事 | `iot-project-design-defense` |
| 上下文将满 | 更新本 handoff + `HANDOFF-LATEST.md` |

---

## 8. 已知坑

| 现象 | 原因 |
|------|------|
| 启动后多条 OFFLINE 告警 | test-data 心跳过旧 + 60s 超时任务 |
| `wyvrn/Synapse` ERROR 日志 | 外设软件扫 8080，可忽略 |
| Vite 5173 占用 | 用 5174 或杀旧 dev 进程 |
| `application.yml` 仍指 10.59.47.188 | 本地必须用 **`--spring.profiles.active=local,secret`** |
| 板 HTTP 降级要 JWT | 板应走 **MQTT**，勿调 hardware POST 无 token |

---

## 9. 上一版 handoff

旧版 [`2026-08-22-streetlight-web.md`](2026-08-22-streetlight-web.md) 中「本机跑通后端未完成」「PR 删物流待提交」**已过时**，以本文件为准。
