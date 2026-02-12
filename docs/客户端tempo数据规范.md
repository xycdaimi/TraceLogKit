
# 客户端 Tempo（Tracing）数据规范（OTel → Tempo）

## 目标

让每条 Trace/Span 都携带必要的属性，从而在 Grafana 里实现：

- 从 **Tempo Trace** 一键反查到 **Loki 日志**（自动限定到同一个 `project`）
- 在日志中按 `trace_id / task_id / request_id / service` 过滤，完成全链路排查
- 在 Tempo 中按 `trace_id` 查看单次执行的链路
- 在 Tempo 中按 `task_id` 查看任务的所有执行链路（聚合多个 trace_id）

## 强制约定（必须遵守）

- **project 键名**：统一使用 `project`
- **project 值**：与日志里 `service` 推导出的项目名一致
  - 规则：`project = service` 的第一个 `-` 前缀
  - 示例：`service="draw-spec-gateway"` → `project="draw"`
- **服务名键名（Tracing）**：统一使用 `service.name`（OTel 标准 Resource Attribute）
  - 建议其值与日志 JSON 字段 `service` 保持一致（同一套服务命名）

## 注入方式（推荐：Resource Attributes）

把 `project` 注入为 **Resource Attribute**，它会自动附着到该进程产生的所有 spans（避免漏标）。

### 环境变量方式（所有语言通用，最推荐）

- `OTEL_SERVICE_NAME=draw-gateway`
- `OTEL_RESOURCE_ATTRIBUTES=project=draw`

也可以合并写：

- `OTEL_RESOURCE_ATTRIBUTES=project=draw,service.name=draw-gateway`

说明：
- `service.name` 是 OTel 标准字段，Grafana/Tempo/OTel 工具链对它有最佳支持
- `project` 是你的业务维度字段，用于和 Loki 的 `{project="..."}` 对齐

## Span Attributes（必须包含）

在**根 span**上必须添加以下 span attributes：

- `project=draw`（与 resource attribute 一致即可）
- `task_id=...`（**必须**：用于关联任务的多次执行）
- `request_id=...`（强烈建议：高基数字段，只允许放在 trace/span attributes，不要做 Prometheus label）

**强制约束**：
- ✅ 所有 Span 都**必须包含** `task_id` 属性
- ✅ trace_id 和 task_id 是强制绑定的（有 trace 就有 task_id）

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

## 与日志关联的最小字段集合（供日志侧对齐）

不是所有日志都是"请求链路日志"。这里的字段要求仅针对**你希望与 Tempo Trace 关联**的那类日志（例如请求入口、跨服务调用、关键业务事件等）。

为了能在 Loki 侧用 `| json` 解析并按 trace 维度过滤，约定如下：

- **如果该条日志包含 `trace_id`**（表示它属于某条 trace 的一部分），则**必须同时包含**：
  - `service`：字符串，容器名（用于 promtail 派生 project）
  - `trace_id`：字符串（32 hex）
  - `task_id`：字符串（格式建议：`task_<标识符>`）- **强制要求**
  
- 同时**强烈建议**包含：
  - `span_id`：字符串（16 hex）
  - `request_id`：字符串（便于按请求维度检索）

**强制约束**：
- ✅ `trace_id` 和 `task_id` **必须成对出现**
- ✅ 如果存在 `trace_id`，那么必定有 `task_id`
- ✅ 如果存在 `task_id`，那么必定有 `trace_id`
- ✅ `task_id` 与 `trace_id` 是一对多关系
  - 一个任务可能有多次执行（首次、重试等），每次执行有独立的 `trace_id`
  - 用 `task_id` 可以追踪任务的所有执行历史

对于不属于请求链路的普通运行日志，可以不包含 `trace_id/task_id/span_id/request_id`（这些字段要么全有，要么全无），但仍要保持 JSON 结构化与包含 `service`（否则可能被采集侧丢弃，取决于 Promtail 策略）。

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

**Drilldown Dashboard**（支持多维度查询）：
- 输入 **task_id**：查看该任务的所有执行日志（首次、重试等）
- 输入 **trace_id**：查看单次执行的详细链路和日志
- 输入 **request_id**：按请求 ID 过滤日志
- 点击日志中的 trace_id 链接：跳转到 Tempo 查看单次执行链路
- 点击日志中的 task_id 链接：跳转到 Tempo 查看任务的所有 Trace

### Grafana 数据源配置

**Loki 数据源**已配置 derived fields：
- `trace_id`：点击跳转到 Tempo 查看单次执行链路
- `task_id`：点击跳转到 Tempo 查看任务的所有 Trace（使用 TraceQL 查询）
