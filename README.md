# TraceLogKit - 全面的可观测性堆栈

`TraceLogKit` 是一个完整的可观测性解决方案，为微服务和分布式系统提供指标（Metrics）、日志（Logs）和追踪（Traces）的收集、存储和可视化能力。

## 核心组件

- **Prometheus**：时间序列数据库，收集和存储系统性能指标
- **Loki**：日志聚合系统，收集、存储和查询应用程序日志
- **Tempo**：分布式追踪后端，存储和查询跨服务请求的追踪数据
- **Grafana**：数据可视化平台，统一展示指标、日志和追踪数据
- **OpenTelemetry Collector (otel-collector)**：遥测数据处理器，接收、处理和导出遥测数据
- **Promtail**：Loki 的日志收集代理，从 Docker 容器抓取日志（通过 `docker.sock`），仅上报 `project` 标签 + 原始 JSON 字符串日志行

## 客户端接入规范

业务应用接入 TraceLogKit 时，需遵循以下规范（指标、日志、追踪为三套独立系统，按需接入）：

| 数据类型 | 规范文档 | 说明 |
|----------|----------|------|
| **指标 (Metrics)** | [客户端普罗米修斯规范](docs/客户端普罗米修斯规范.md) | 暴露 `/metrics`，提供 `project`、`service` 标签 |
| **日志 (Logs)** | [客户端容器日志规范](docs/客户端容器日志规范.md) | 输出 JSON 日志，含 `service`、`project`；链路日志需含 `trace_id`、`task_id` |
| **追踪 (Traces)** | [客户端 Tempo 数据规范](docs/客户端tempo数据规范.md) | 通过 OTel SDK 上报，设置 `project`、`service.name`；Span 需含 `task_id` |

## 快速启动

```bash
# 1. 复制环境变量文件
cp .env.example .env

# 2. 编辑 .env 文件，配置各项参数（见下方配置说明）

# 3. 启动服务
# Windows
scripts\start_infrastructure.bat

# Linux/macOS
./scripts/start_infrastructure.sh

# 4. 访问 Grafana
# http://localhost:3000
```

## 配置说明

### 通用设置

#### `TZ` / `PGTZ`
- **用途**：设置时区
- **配置**：例如 `Asia/Shanghai`
- **示例**：`TZ=Asia/Shanghai`

#### `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`
- **用途**：代理设置（本地开发环境通常留空）
- **配置**：如果需要代理，填写代理地址；否则留空
- **示例**：`HTTP_PROXY=`

### Grafana 配置

#### `GRAFANA_ADMIN_USER`
- **用途**：Grafana 管理员用户名
- **配置**：设置管理员用户名
- **示例**：`GRAFANA_ADMIN_USER=admin`

#### `GRAFANA_ADMIN_PASSWORD`
- **用途**：Grafana 管理员密码
- **配置**：设置管理员密码（生产环境请使用强密码）
- **示例**：`GRAFANA_ADMIN_PASSWORD=admin`

#### `GRAFANA_ROOT_URL`
- **用途**：Grafana 根 URL（用于反向代理或外部访问）
- **配置**：留空使用默认相对路径；反向代理时填写完整 URL，如 `https://grafana.example.com`
- **示例**：`GRAFANA_ROOT_URL=`（留空）

### 网络配置

#### `TRACELOGKIT_NETWORK_NAME`
- **用途**：Docker 网络名称，确保 TraceLogKit 与您的应用服务在同一网络中
- **配置**：填写您的 Docker 网络名称
- **示例**：`TRACELOGKIT_NETWORK_NAME=tracelogkit-network`

### 消息队列配置

#### `MQ_TYPE`
- **用途**：指定消息队列类型，控制 Prometheus 抓取哪个消息队列的指标
- **配置**：可选值 `rabbitmq`、`kafka`、`rocketmq`
- **示例**：`MQ_TYPE=rabbitmq`

### Promtail 日志采集配置

Promtail 为**白名单模式**：四个过滤参数全部为空时，默认不采集任何容器日志。

**采集范围**（在 `.env` 中配置，OR 逻辑，匹配任一即采集）：

| 参数 | 说明 |
|------|------|
| `PROMTAIL_CONTAINER_NAMES` | 容器名列表（逗号分隔，精确匹配） |
| `PROMTAIL_CONTAINER_NAME_PATTERN` | 容器名正则 |
| `PROMTAIL_COMPOSE_PROJECT` | Docker Compose 项目名 |
| `PROMTAIL_COMPOSE_SERVICE` | Docker Compose 服务名（逗号分隔） |

**数据约束**：Promtail 只会把“日志内容本身是 JSON 字符串”的行推送到 Loki，并且：
- 从 JSON 中**直接提取** `project` 和 `service`（禁止派生，`project` 为空则丢弃）
- **最终写入 Loki 的标签只有 `project`**（不会写入 `job/container/compose_*` 等标签）

客户端需在 JSON 日志中提供 `service` 和 `project`，详见 [客户端容器日志规范](docs/客户端容器日志规范.md)。

#### `LOKI_URL`
- **用途**：Promtail 推送日志到 Loki 的地址
- **配置**：Docker 网络内使用 `http://tracelogkit-loki:3100`，远程 Loki 使用实际地址
- **示例**：`LOKI_URL=http://tracelogkit-loki:3100`

### Redis 配置

#### `REDIS_HOST`
- **用途**：Redis 服务地址
- **配置**：填写 Redis 的主机名或 IP 地址
- **示例**：`REDIS_HOST=your-redis-host`

#### `REDIS_PORT`
- **用途**：Redis 服务端口
- **配置**：填写 Redis 的端口号
- **示例**：`REDIS_PORT=6379`

#### `REDIS_PASSWORD`
- **用途**：Redis 访问密码（如果设置了密码）
- **配置**：填写 Redis 密码，如果未设置密码则留空
- **示例**：`REDIS_PASSWORD=admin`

### PostgreSQL 配置

#### `DB_READ_HOST`
- **用途**：PostgreSQL 只读副本的主机地址（用于监控，减少主库负载）
- **配置**：填写 PostgreSQL 只读副本的主机名或 IP 地址
- **示例**：`DB_READ_HOST=tracelogkit-postgres-replica`

#### `DB_READ_PORT`
- **用途**：PostgreSQL 只读副本的端口
- **配置**：填写 PostgreSQL 的端口号
- **示例**：`DB_READ_PORT=5432`

#### `DB_READ_USER`
- **用途**：PostgreSQL 只读用户
- **配置**：填写具有只读权限的数据库用户名
- **示例**：`DB_READ_USER=admin`

#### `DB_READ_PASSWORD`
- **用途**：PostgreSQL 只读用户密码
- **配置**：填写只读用户的密码
- **示例**：`DB_READ_PASSWORD=admin`

#### `DB_READ_DB`
- **用途**：要监控的数据库名称
- **配置**：填写数据库名称
- **示例**：`DB_READ_DB=aiflow_data`

### RabbitMQ 配置（当 `MQ_TYPE=rabbitmq` 时）

#### `RABBITMQ_HOST`
- **用途**：RabbitMQ 服务地址
- **配置**：填写 RabbitMQ 的主机名或 IP 地址
- **示例**：`RABBITMQ_HOST=your-rabbitmq-host`

#### `RABBITMQ_PORT`
- **用途**：RabbitMQ Prometheus 指标暴露端口
- **配置**：RabbitMQ 默认在 15692 端口暴露 Prometheus 指标
- **示例**：`RABBITMQ_PORT=15692`

### Kafka 配置（当 `MQ_TYPE=kafka` 时）

#### `KAFKA_BOOTSTRAP_SERVERS`
- **用途**：Kafka 集群的引导服务器地址
- **配置**：格式为 `host:port`，多个服务器用逗号分隔
- **示例**：`KAFKA_BOOTSTRAP_SERVERS=your-kafka-host:9092`

### RocketMQ 配置（当 `MQ_TYPE=rocketmq` 时）

#### `ROCKETMQ_NAMESRV_ADDR`
- **用途**：RocketMQ NameServer 地址
- **配置**：格式为 `host:port`
- **示例**：`ROCKETMQ_NAMESRV_ADDR=rocketmq-namesrv:9876`

#### `ROCKETMQ_ACL_ENABLED`
- **用途**：是否启用 RocketMQ ACL（访问控制列表）
- **配置**：`true` 或 `false`
- **示例**：`ROCKETMQ_ACL_ENABLED=false`

#### `ROCKETMQ_ACCESS_KEY` / `ROCKETMQ_SECRET_KEY`
- **用途**：RocketMQ ACL 访问密钥（如果启用了 ACL）
- **配置**：如果启用了 ACL，填写访问密钥和秘密密钥
- **示例**：`ROCKETMQ_ACCESS_KEY=`（未启用 ACL 时留空）

#### `ROCKETMQ_EXPORTER_PORT`
- **用途**：RocketMQ Exporter 端口
- **配置**：RocketMQ Exporter 的端口号
- **示例**：`ROCKETMQ_EXPORTER_PORT=5557`

### Consul 服务发现配置

#### `CONSUL_HOST`
- **用途**：Consul 服务器地址
- **配置**：填写 Consul 的主机名或 IP 地址
- **示例**：`CONSUL_HOST=your-consul-host`

#### `CONSUL_PORT`
- **用途**：Consul 服务器端口
- **配置**：Consul 默认端口为 8500
- **示例**：`CONSUL_PORT=8500`

**说明**：配置 Consul 后，Prometheus 可以通过服务发现自动发现和抓取服务指标。

**Prometheus 抓取目标**：本项目通过 `docker/prometheus/targets/` 目录下的 YAML 文件配置监控目标。请参考 `example.yml.example`、`draw-spec.yml.example`、`ai-router.yml.example` 等示例，复制并重命名为 `.yml` 后编写自己的监控目标。每个 target 需提供 `project`、`service`、`job` 标签，且 `job` 必须与 `project` 一致。容器启动时会将该目录挂载到 Prometheus，无需环境变量配置。详见 [客户端普罗米修斯规范](docs/客户端普罗米修斯规范.md)。

### Loki 存储配置

Loki 存储分为索引存储和对象存储两部分。索引存储固定为 `boltdb-shipper`，对象存储可选 `filesystem` 或 `s3`。

#### `LOKI_INDEX_STORE_TYPE`
- **用途**：Loki 索引存储类型
- **配置**：固定为 `boltdb-shipper`（默认，唯一支持的类型）
- **示例**：`LOKI_INDEX_STORE_TYPE=boltdb-shipper`

#### `LOKI_OBJECT_STORE_TYPE`
- **用途**：Loki 对象存储类型
- **配置**：可选值 `filesystem`（开发环境）或 `s3`（生产环境）
- **示例**：`LOKI_OBJECT_STORE_TYPE=filesystem`

#### `LOKI_S3_ENDPOINT`
- **用途**：S3 兼容存储的端点地址（当 `LOKI_OBJECT_STORE_TYPE=s3` 时使用）
- **配置**：填写 S3 服务的端点地址
- **示例**：
  - MinIO：`LOKI_S3_ENDPOINT=minio:9000`
  - AWS S3：`LOKI_S3_ENDPOINT=s3.amazonaws.com`
  - 阿里云 OSS：`LOKI_S3_ENDPOINT=oss-cn-hangzhou.aliyuncs.com`

#### `LOKI_S3_REGION`
- **用途**：S3 存储区域
- **配置**：填写 S3 存储的区域名称
- **示例**：`LOKI_S3_REGION=us-east-1` 或 `LOKI_S3_REGION=cn-hangzhou`

#### `LOKI_S3_BUCKET_NAME`
- **用途**：S3 存储桶名称
- **配置**：填写用于存储 Loki 数据的存储桶名称
- **示例**：`LOKI_S3_BUCKET_NAME=loki`

#### `LOKI_S3_ACCESS_KEY`
- **用途**：S3 访问密钥 ID
- **配置**：填写 S3 访问密钥
- **示例**：`LOKI_S3_ACCESS_KEY=admin`

#### `LOKI_S3_SECRET_KEY`
- **用途**：S3 秘密访问密钥
- **配置**：填写 S3 秘密密钥
- **示例**：`LOKI_S3_SECRET_KEY=adminadmin`

#### `LOKI_S3_FORCE_PATH_STYLE`
- **用途**：是否强制使用路径样式访问（MinIO 等需要设置为 `true`）
- **配置**：`true` 或 `false`
- **示例**：
  - MinIO：`LOKI_S3_FORCE_PATH_STYLE=true`
  - AWS S3：`LOKI_S3_FORCE_PATH_STYLE=false`

#### `LOKI_S3_INSECURE`
- **用途**：是否使用不安全的连接（HTTP 而非 HTTPS）
- **配置**：`true` 或 `false`
- **示例**：
  - 本地 MinIO：`LOKI_S3_INSECURE=true`
  - AWS S3：`LOKI_S3_INSECURE=false`

### OpenTelemetry 配置

#### `OTEL_EXPORTER_OTLP_ENDPOINT`
- **用途**：OpenTelemetry Collector 的 OTLP 接收端点
- **配置**：应用程序应将遥测数据发送到此地址；应用在 Docker 网络内时用 `http://tracelogkit-otel-collector:4318`，宿主机运行时用 `http://localhost:4318`
- **示例**：`OTEL_EXPORTER_OTLP_ENDPOINT=http://tracelogkit-otel-collector:4318`

#### `OTEL_EXPORTER_OTLP_PROTOCOL`
- **用途**：OTLP 协议类型
- **配置**：通常使用 `http/protobuf`
- **示例**：`OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`

#### `OTEL_TRACES_EXPORTER`
- **用途**：追踪数据导出器类型
- **配置**：使用 `otlp`
- **示例**：`OTEL_TRACES_EXPORTER=otlp`

#### `OTEL_PROPAGATORS`
- **用途**：追踪传播器
- **配置**：通常使用 `tracecontext,baggage`
- **示例**：`OTEL_PROPAGATORS=tracecontext,baggage`

#### `OTEL_RESOURCE_ATTRIBUTES`
- **用途**：资源属性，用于标识部署环境
- **配置**：键值对格式
- **示例**：`OTEL_RESOURCE_ATTRIBUTES=deployment.environment=dev`

#### `OTEL_TRACES_SAMPLER`
- **用途**：追踪采样策略
- **配置**：`always_on`（总是采样）或 `always_off`（不采样）
- **示例**：`OTEL_TRACES_SAMPLER=always_on`

#### `OTEL_TRACES_SAMPLER_ARG`
- **用途**：追踪采样参数
- **配置**：采样率（0.0 到 1.0）
- **示例**：`OTEL_TRACES_SAMPLER_ARG=1.0`（100% 采样）

## 配置示例

### 开发环境配置示例

```env
# 基础配置
TZ=Asia/Shanghai
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
TRACELOGKIT_NETWORK_NAME=tracelogkit-network
LOKI_URL=http://tracelogkit-loki:3100

# Promtail 采集范围（至少配置一项，否则不采集任何容器）
# PROMTAIL_CONTAINER_NAMES=my-app
# PROMTAIL_COMPOSE_PROJECT=my-project

# 外部服务配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

DB_READ_HOST=localhost
DB_READ_PORT=5432
DB_READ_USER=admin
DB_READ_PASSWORD=admin
DB_READ_DB=aiflow_data

MQ_TYPE=rabbitmq
RABBITMQ_HOST=localhost
RABBITMQ_PORT=15692

# Consul 配置
CONSUL_HOST=localhost
CONSUL_PORT=8500

# Loki 存储（开发环境使用文件系统）
LOKI_OBJECT_STORE_TYPE=filesystem

# OpenTelemetry
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

### 生产环境配置示例

```env
# 基础配置
TZ=Asia/Shanghai
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-strong-password
TRACELOGKIT_NETWORK_NAME=production-network
LOKI_URL=http://tracelogkit-loki:3100

# Promtail 采集范围（至少配置一项）
# PROMTAIL_COMPOSE_PROJECT=production-app

# 外部服务配置（使用实际的服务地址）
REDIS_HOST=redis.production.internal
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password

DB_READ_HOST=postgres-replica.production.internal
DB_READ_PORT=5432
DB_READ_USER=readonly_user
DB_READ_PASSWORD=your-db-password
DB_READ_DB=production_db

MQ_TYPE=rabbitmq
RABBITMQ_HOST=rabbitmq.production.internal
RABBITMQ_PORT=15692

# Consul 配置
CONSUL_HOST=consul.production.internal
CONSUL_PORT=8500

# Loki 存储（生产环境使用 S3）
LOKI_OBJECT_STORE_TYPE=s3
LOKI_S3_ENDPOINT=s3.amazonaws.com
LOKI_S3_REGION=us-east-1
LOKI_S3_BUCKET_NAME=production-loki-logs
LOKI_S3_ACCESS_KEY=your-access-key
LOKI_S3_SECRET_KEY=your-secret-key
LOKI_S3_FORCE_PATH_STYLE=false
LOKI_S3_INSECURE=false

# OpenTelemetry
OTEL_EXPORTER_OTLP_ENDPOINT=http://tracelogkit-otel-collector:4318
```

## 常见问题

### 1. 如何确认配置是否正确？

启动服务后，检查：
- Prometheus 目标状态：访问 `http://localhost:9090/targets`
- Grafana 数据源：登录 Grafana，检查数据源连接状态
- 服务日志：查看各服务的日志输出

### 2. 服务无法连接到外部服务？

- 检查 `.env` 中的服务地址和端口是否正确
- 确保所有服务在同一 Docker 网络中
- 检查防火墙和网络路由

### 3. Consul 服务发现不工作？

- 确认服务已注册到 Consul
- 检查 `CONSUL_HOST` 和 `CONSUL_PORT` 配置
- 在 Prometheus 的 `/targets` 页面查看服务发现状态

### 4. Loki 存储配置问题？

- 开发环境使用 `LOKI_OBJECT_STORE_TYPE=filesystem` 即可
- 生产环境使用 S3 时，设置 `LOKI_OBJECT_STORE_TYPE=s3`，确保 S3 配置正确且可访问
- 检查 S3 访问密钥和权限

## 更多信息

- **配置说明**：详细的配置项和默认值请参考 `.env.example` 文件中的注释
- **客户端接入**：指标、日志、追踪的接入规范见上方「客户端接入规范」表格中的文档链接
