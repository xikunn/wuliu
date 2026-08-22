# 初始化 smart-street-light 库（需 docker compose up -d 后执行）
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Schema = Join-Path $Root "sql\schema.sql"
$TestData = Join-Path $Root "sql\test-data.sql"

if (-not (docker ps --filter name=streetlight-pg --format "{{.Names}}")) {
  Write-Error "streetlight-pg 未运行。请先: docker compose up -d"
}

Write-Host "Recreating database..."
@'
DROP DATABASE IF EXISTS "smart-street-light";
CREATE DATABASE "smart-street-light";
'@ | docker exec -i streetlight-pg psql -U postgres

Write-Host "Copying SQL files into container..."
docker cp $Schema streetlight-pg:/tmp/schema.sql
docker cp $TestData streetlight-pg:/tmp/test-data.sql

Write-Host "Applying schema (skip CREATE DATABASE)..."
docker exec streetlight-pg sh -c "grep -v '^CREATE DATABASE' /tmp/schema.sql | psql -U postgres -d smart-street-light -v ON_ERROR_STOP=1 -f -"

Write-Host "Loading test data..."
docker exec streetlight-pg psql -U postgres -d smart-street-light -v ON_ERROR_STOP=1 -f /tmp/test-data.sql

Write-Host "Done. Test login: admin / admin123"
