
# 客户端 Tempo（Tracing）数据规范（OTel → Tempo）

## 本规范管什么

**只管追踪**：业务进程通过 OpenTelemetry SDK 上报的 Trace/Span，经 OTel Collector 写入 Tempo。与 Prometheus（指标）、Loki（日志）是**三套独立系统**。**唯有 Tempo 与 Loki 有直接关系**：通过 `trace_id` 实现 Trace↔Log 互跳。

## 目标

让每条 Trace/Span 都携带必要的属性，支持：

- 在 Tempo 中按 `trace_id` 查看单次执行的链路
- 在 Tempo 中按 `task_id` 查看任务的所有执行链路（聚合多个 trace_id）
- 从 **Tempo Trace** 一键反查到 **Loki 日志**（需日志侧含相同 `trace_id`）
- 在 **Loki 日志**中点击 `trace_id` 一键跳转到 Tempo

## 与其他系统的关系

| 系统 | 与 Tempo 的关系 | 客户端需知 |
|------|-----------------|------------|
| **Prometheus（指标）** | **无直接关系**。指标和追踪是不同数据。 | 本规范不涉及 Prometheus。若需指标，见《客户端普罗米修斯规范》。 |
| **Loki（日志）** | **有直接关系**。通过 `trace_id` 实现 Trace↔Log 互跳。 | 若要做 Trace↔Log 互跳，**日志里必须含 `trace_id`**（来自 OTel 上下文）。见《客户端容器日志规范》第 3 节。 |

## 职责边界

- **客户端**：通过 OTel SDK 上报 spans 时，必须设置 `project`、`service.name` 等 Resource Attributes。取值由部署/配置决定（如 service.name=draw-gateway 则 project=draw）。
- **服务端（OTel Collector / Tempo）**：只负责接收、存储、查询，**不做** project 派生或任何转换。

## 术语说明（避免误解）

- 本文的“客户端”指**产生 Trace/Span 的业务进程**（服务端/worker/容器内应用等），即：进程内集成 OpenTelemetry SDK 或自动探针，并通过 OTLP 上报到 Tempo。
- “Tempo/Collector”是后端组件：**只负责接收/存储/查询**，不负责“给请求发号”。

## trace_id 的来源与传播（关键逻辑）

- `trace_id` **由 OpenTelemetry SDK/自动探针在链路起点创建 Root Span 时生成**，并在链路中通过 context propagation 传播（常见为 W3C Trace Context：`traceparent`/`tracestate`）。
- Tempo/Collector **不会生成你的业务请求的 `trace_id`**；它们只接收并存储你上报的 spans。
- 因此：
  - ✅ 任何需要参与 tracing 的服务，都必须**提取/注入**传播上下文（而不是“各自随机生成 trace_id”）。
  - ✅ 链路追踪日志中的 `trace_id` 必须来自**当前 OTel 上下文**（或从 `traceparent` 提取后的上下文），而不是自造一个“伪 trace_id”。

## 强制约定（必须遵守）

- **project 键名**：统一使用 `project`
- **project 值**：由客户端在 Resource Attributes 中设置（如 service.name=draw-gateway 则 project=draw）。OTel Collector / Tempo **不派生**，只存储客户端上报的值。
- **服务名键名（Tracing）**：统一使用 `service.name`（OTel 标准 Resource Attribute）
  - 若需在 Grafana 中按同一维度查询，与日志 `service`、Prometheus `service` label 命名约定保持一致

## 路径排除规则（探针/健康检查不追踪）

**必须排除**：探针、健康检查、指标端点**不得**创建 Span 或上报 OTel。与《客户端普罗米修斯规范》保持一致。

**需排除的路径**（不创建 Span、不上报）：

- `/health`、`/healthz`、`/ready`、`/readyz`、`/live`、`/liveness`、`/ping`
- `/metrics`（Prometheus 指标端点）
- `/actuator/health`、`/actuator/info` 等 Spring Boot Actuator 健康端点

**原因**：探针高频调用会产生大量无业务价值的 Trace，污染 Tempo 数据、影响查询和统计。

**实现方式**（客户端优先，在 SDK/自动探针层排除）：

| 语言/框架 | 配置方式 |
|-----------|----------|
| **Python Flask** | `FlaskInstrumentor().instrument_app(app, excluded_urls="/health,/metrics,/ready")` |
| **Java Agent** | 环境变量 `OTEL_INSTRUMENTATION_HTTP_SERVER_EXCLUDE_PATHS=/health,/metrics,/ready,/actuator/health` |
| **Node.js** | `@opentelemetry/instrumentation-http` 的 `ignoreIncomingRequestHook` |
| **Go** | 在 middleware 中根据 path 判断，探针路径不创建 span |

> 说明：OTel Collector 可配置 filter processor 做兜底过滤，但**客户端必须优先排除**，减少无效数据上报。

## 注入方式（推荐：Resource Attributes）

把 `project` 注入为 **Resource Attribute**，它会自动附着到该进程产生的所有 spans（避免漏标）。

### 环境变量方式（所有语言通用，最推荐）

- `OTEL_SERVICE_NAME=draw-gateway`
- `OTEL_RESOURCE_ATTRIBUTES=project=draw`

也可以合并写：

- `OTEL_RESOURCE_ATTRIBUTES=project=draw,service.name=draw-gateway`

说明：
- `service.name` 是 OTel 标准字段，Grafana/Tempo/OTel 工具链对它有最佳支持
- `project` 是业务维度字段，用于 Grafana 中按 project 过滤

## Span Attributes（必须包含）

在**根 span**上必须添加以下 span attributes：

- `project=draw`（与 resource attribute 一致即可）
- `task_id=...`（**必须**：用于关联任务的多次执行）
- `request_id=...`（强烈建议：高基数字段，只允许放在 trace/span attributes，不要做 Prometheus label）

**强制约束**：
- ✅ 所有 Span 都**必须包含** `task_id` 属性
- ✅ 只要存在 Span，就天然存在 `trace_id`；并且该 Trace 内的所有 Span 都必须带 `task_id`

### task_id 在 Span 中的使用（强制要求）

**适用场景**：所有 Trace/Span（强制要求，不是可选的）

**添加位置**：在**根 Span**（入口 Span）上添加

**task_id 与 trace_id 的强制关系**：
- **强制绑定**：
  - ✅ 如果存在 `trace_id`，那么**必定有** `task_id`
  - ✅ 如果存在 `task_id`，那么**必定有** `trace_id`
- **一对多关系**：一个 `task_id` 对应多个 `trace_id`
- 每次执行（首次/重试）生成新的 `trace_id`，但共享同一个 `task_id`
- 用 `trace_id` 查看单次执行的详细链路
- 用 `task_id` 查看任务的所有执行历史

**代码示例**（Python OpenTelemetry）：

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

# 在根 Span 上添加 task_id
with tracer.start_as_current_span("process_task") as span:
    span.set_attribute("task_id", "task_abc123")
    span.set_attribute("request_id", "req_456")
    span.set_attribute("project", "draw")
    
    # 业务逻辑...
    # 子 Span 会自动继承 trace context
```

**注意事项**：
- task_id **必须**作为 **Span Attribute**（不是 Resource Attribute）
- Resource Attribute 是进程级别的，而 task_id 是请求级别的
- **所有 Span 都必须包含 task_id**，不是可选的
- 如果使用自动埋点（auto-instrumentation），可以通过 context propagation 传递 task_id

## trace_id / span_id 格式要求（与日志联动）

- `trace_id`：32 位十六进制字符串（不带 `0x`，不带 `-`）
- `span_id`：16 位十六进制字符串

## 与日志关联（log↔trace correlation）的最小字段集合（供日志侧对齐）

不是所有日志都是"请求链路日志"。这里的字段要求仅针对**你希望与 Tempo Trace 关联**的那类日志（例如请求入口、跨服务调用、关键业务事件等）。

**Trace↔Log 互跳的前提**：日志里必须含 `trace_id`（来自 OTel 上下文）。约定如下：

- **链路追踪日志必须包含**（用于与 Tempo Trace 互跳）：
  - `service`：字符串，容器名（Promtail 从 JSON 提取 project，必须提供，禁止派生）
  - `trace_id`：字符串（32 hex，来自 OTel 上下文）
  - `task_id`：字符串（格式建议：`task_<标识符>`）- **强制要求**
  
- 同时**强烈建议**包含：
  - `span_id`：字符串（16 hex）
  - `request_id`：字符串（便于按请求维度检索）

**强制约束**：
- ✅ 链路追踪日志中 `trace_id` 和 `task_id` **必须成对出现**
- ✅ `task_id` 与 `trace_id` 是一对多关系
  - 一个任务可能有多次执行（首次、重试等），每次执行有独立的 `trace_id`
  - 用 `task_id` 可以追踪任务的所有执行历史

> 说明：如果某一端（例如终端 App）无法获取 `trace_id`，也不要随机生成。可以让服务端把 `trace_id` 回传给终端侧记录，或改用 `request_id` 做关联键。

对于不属于请求链路的普通运行日志，可以不包含 `trace_id/task_id/span_id/request_id`（这些字段要么全有，要么全无），但仍要保持 JSON 结构化与包含 `service`（否则可能被采集侧丢弃）。

**部署侧需知**：Trace↔Log 互跳要求 Promtail 已配置为采集该容器。Promtail 通过四个过滤规则（容器名列表、容器名正则、Compose 项目、Compose 服务）控制采集范围，OR 逻辑（匹配任一即采集），四个参数全空则禁止采集。详见《客户端容器日志规范》。

## Tempo 查询方式

### 按 trace_id 查询（单次执行）

在 Grafana Tempo 数据源中，直接输入 trace_id：

```
0123456789abcdef0123456789abcdef
```

### 按 task_id 查询（任务的所有执行）

使用 TraceQL 查询：

```traceql
{span.task_id="task_abc123"}
```

**说明**：
- 这会返回该 task_id 对应的**所有 trace**（首次执行、重试等）
- 相当于聚合显示多个 trace_id 的链路
- 一个 task_id 对应多个 trace_id（一对多关系）

### 在 Dashboard 中使用

**Traces 面板**（`/d/tracelogkit_traces`）：
1. **Trace 列表**：输入 task_id，按 TraceQL `{span.task_id="..."}` 查询该任务的所有 trace（首次执行、重试等）；列表仅展示 trace 级信息（traceID、Start time、Duration），点击 traceID 在下方展示链路
2. **Trace 时间线（Waterfall）**：展示选中 trace 的 span 明细与调用关系；点击 span 可反查 Loki 日志（tracesToLogs）
3. **重试分析**：多条 trace = 多次执行，对比各次可判断重试次数、是否成功、失败原因

**从 Logs 跳转**：
- 点击日志中的 `trace_id` 链接：跳转到 Tempo 查看单次执行链路
- 点击日志中的 `task_id` 链接：跳转到 Traces 面板查看该任务的所有 Trace

### Grafana 数据源配置

**Loki 数据源**已配置 derived fields：
- `trace_id`：点击跳转到 Traces 面板并展示单次执行链路
- `task_id`：点击跳转到 Traces 面板并展示该任务的所有 Trace（TraceQL 查询）

