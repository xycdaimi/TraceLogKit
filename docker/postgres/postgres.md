# PostgreSQL Docker 配置

本目录包含 AI Router 项目的 PostgreSQL 数据库容器配置。

## 版本信息

- **PostgreSQL 版本**: 18 (Alpine)
- **镜像**: postgres:18-alpine

## 快速启动

### 使用 Docker Compose

```bash
# 启动 PostgreSQL
cd postgres
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止 PostgreSQL
docker-compose down
```

### 使用脚本

**Linux/Mac:**
```bash
./start.sh    # 启动
./stop.sh     # 停止
```

**Windows:**
```cmd
start.bat     # 启动
stop.bat      # 停止
```

## 端口说明

| 端口 | 用途 |
|------|------|
| 5432 | PostgreSQL 服务端口 |

## 配置说明

### 主要配置项

- **数据库名**: `admin`
- **用户名**: `admin`
- **密码**: `admin`
- **端口**: 5432
- **时区**: Asia/Shanghai

### 连接信息

**连接字符串:**
```
postgresql://admin:admin@localhost:5432/admin
```

**异步连接字符串 (asyncpg):**
```
postgresql+asyncpg://admin:admin@localhost:5432/admin
```

## 数据持久化

数据存储在 Docker volume `postgres_data` 中，即使容器删除，数据也会保留。

### 查看数据卷
```bash
docker volume ls | grep postgres
```

### 删除数据卷（谨慎操作）
```bash
# 停止容器并删除数据卷
docker-compose down -v
```

## 数据库初始化

容器首次启动时会自动执行 `scripts/init_database.sql` 脚本，创建以下表结构：

### logs 表

用于存储系统日志的表：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | 主键（自增） |
| timestamp | TIMESTAMP WITH TIME ZONE | 日志时间戳 |
| task_id | VARCHAR(255) | 任务 ID |
| service_name | VARCHAR(100) | 服务名称 |
| service_instance | VARCHAR(100) | 服务实例 ID |
| level | VARCHAR(20) | 日志级别 |
| event | VARCHAR(100) | 事件标识 |
| message | TEXT | 日志消息 |
| context | JSONB | 额外上下文（JSON） |
| created_at | TIMESTAMP WITH TIME ZONE | 记录创建时间 |

### 索引

- `idx_logs_timestamp` - 时间戳索引
- `idx_logs_task_id` - 任务 ID 索引
- `idx_logs_service_name` - 服务名称索引
- `idx_logs_level` - 日志级别索引
- `idx_logs_event` - 事件索引
- `idx_logs_created_at` - 创建时间索引
- `idx_logs_task_service` - 任务和服务复合索引
- `idx_logs_timestamp_level` - 时间戳和级别复合索引

## 连接数据库

### 使用 psql 命令行

```bash
# 进入容器
docker exec -it tracelogkit-postgres-primary psql -U admin -d admin

# 或直接从主机连接（需要安装 psql 客户端）
psql -h localhost -p 5432 -U admin -d admin
```

### 使用 Python (asyncpg)

```python
import asyncpg

# 创建连接
conn = await asyncpg.connect(
    host='localhost',
    port=5432,
    user='admin',
    password='admin',
    database='admin'
)

# 创建连接池
pool = await asyncpg.create_pool(
    host='localhost',
    port=5432,
    user='admin',
    password='admin',
    database='admin',
    min_size=5,
    max_size=20
)
```

## 健康检查

容器配置了健康检查，每 10 秒检查一次数据库是否可用：

```bash
# 查看健康状态
docker-compose ps
```

## 常用命令

### 查看容器状态
```bash
docker-compose ps
```

### 查看日志
```bash
# 实时查看日志
docker-compose logs -f

# 查看最近 100 行日志
docker-compose logs --tail=100
```

### 重启容器
```bash
docker-compose restart
```

### 进入容器
```bash
docker exec -it tracelogkit-postgres-primary bash
```

## 备份与恢复

### 备份数据库

```bash
# 备份整个数据库
docker exec tracelogkit-postgres-primary pg_dump -U admin admin > backup.sql

# 备份特定表
docker exec tracelogkit-postgres-primary pg_dump -U admin -t logs admin > logs_backup.sql
```

### 恢复数据库

```bash
# 恢复数据库
docker exec -i tracelogkit-postgres-primary psql -U admin admin < backup.sql
```

## 故障排查

### 容器无法启动

1. 检查 Docker 是否运行
2. 查看日志：`docker-compose logs`
3. 检查端口是否被占用：`netstat -an | grep 5432`

### 无法连接数据库

1. 确认容器正在运行：`docker-compose ps`
2. 检查健康状态：`docker inspect tracelogkit-postgres-primary`
3. 查看日志：`docker-compose logs`

### 性能优化

如需优化性能，可以创建 `config/postgresql.conf` 文件并在 docker-compose.yml 中挂载：

```yaml
volumes:
  - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
```

## 网络配置

PostgreSQL 容器连接到 `tracelogkit-network` 网络，可以与其他 TraceLogKit 服务通信。

## 安全建议

⚠️ **生产环境注意事项：**

1. 修改默认密码
2. 限制网络访问
3. 启用 SSL/TLS 连接
4. 定期备份数据
5. 监控数据库性能

## 相关文档

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [Docker Hub - PostgreSQL](https://hub.docker.com/_/postgres)
- [asyncpg 文档](https://magicstack.github.io/asyncpg/)

