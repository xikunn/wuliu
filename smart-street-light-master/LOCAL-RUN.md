# 本地跑通后端

## 一键（PowerShell）

```powershell
cd smart-street-light-master
powershell -ExecutionPolicy Bypass -File scripts\run-local.ps1
```

包含：Docker(PG:5433 + EMQX:1883) → 建库 → Docker Maven 编译 → 启动 `:8080`。

## 分步

```powershell
docker compose up -d
powershell -ExecutionPolicy Bypass -File scripts\init-db.ps1

# 编译（无需本机 Maven）
docker run --rm -v "${PWD}:/app" -w /app maven:3.9-eclipse-temurin-21 mvn package -DskipTests

# 运行（需 JDK 21）
java -jar target/smart-street-light-0.0.1-SNAPSHOT.jar --spring.profiles.active=local,secret
```

## 配置说明

| 文件 | 作用 |
|------|------|
| `docker-compose.yml` | PG `localhost:5433`，EMQX `1883` / 控制台 `18083` |
| `application-local.yml` | 本地 DB/MQTT 地址（不改远程 `application.yml`） |
| `application-secret.yml` | 密码/JWT（已 gitignore，本地自建） |

## 验收

```powershell
Invoke-RestMethod http://localhost:8080/users/login -Method POST -ContentType application/json -Body '{"username":"admin","password":"admin123"}'
```

`code=200` 即成功。

## 前端 HTTP 联调

```powershell
cd ../web
# .env.local 已配置 VITE_API_MODE=http
npm run dev
```

登录 `admin` / `admin123`（来自 `sql/test-data.sql`）。

EMQX 控制台：http://localhost:18083（默认 admin/public）。
