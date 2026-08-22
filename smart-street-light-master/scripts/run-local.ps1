# 本地启动：Docker(PG+EMQX) + 编译 + 运行 jar
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  Write-Error "未找到 Java。请安装 JDK 21。"
}
$javaLine = (java -version 2>&1 | Select-Object -First 1) -join " "
if ($javaLine -notmatch '"21\.') {
  Write-Warning "当前: $javaLine — 需要 JDK 21"
}

Write-Host "Starting Docker services..."
docker compose up -d
Start-Sleep -Seconds 6
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "init-db.ps1")

$profiles = "local,secret"
Write-Host "Building with Docker Maven (无需本机 mvn)..."
docker run --rm `
  -v "${Root}:/app" `
  -w /app `
  maven:3.9-eclipse-temurin-21 `
  mvn package -DskipTests -q

Write-Host "Starting http://localhost:8080 (profiles=$profiles)..."
java -jar target/smart-street-light-0.0.1-SNAPSHOT.jar --spring.profiles.active=$profiles
