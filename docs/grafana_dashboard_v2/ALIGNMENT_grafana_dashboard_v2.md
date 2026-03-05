## 项目上下文（TraceLogKit Observability Stack）

- **Grafana**：`grafana/grafana:11.5.0`，通过 `docker/grafana/bootstrap.sh` 使用 HTTP API 将 `docker/grafana/resources/` 下的 datasources/dashboards/alerting 应用到 Grafana（覆盖写入）。
- **数据源（当前已配置）**：
  - **Prometheus**（默认数据源）：`uid=tracelogkit-prometheus`
  - **Loki**：`uid=tracelogkit-loki`，并配置了 derived fields（从日志 JSON 中抽 `trace_id`/`task_id` 跳转 Tempo）
  - **Tempo**：`uid=tracelogkit-tempo`，并配置了 traces→logs（用 traceId 回查 Loki）
- **Prometheus 采集模型**：单一 scrape job（`job_name: all-services`）+ `file_sd_configs` 动态发现 `/etc/prometheus/targets/*.yml`。仓库默认 targets 仅包含 TraceLogKit 基础设施组件（Prometheus/OTel Collector/Tempo/Loki）。

## 原始需求（来自对话）

- 用户发现现有 Grafana 面板中有多个“根本没用/默认空”的面板。
- 需要一套**规范、落地、符合问题追踪逻辑**的 Grafana 面板设计，落地到 `docker/grafana/resources/`。
- 日志侧继续保留 `trace_id`，但要求 `trace_id` 必须来自 OTel SDK/自动探针的上下文（或标准传播提取），禁止自造伪 trace_id。

## 需求理解（将模糊需求转成可执行口径）

目标是形成一套“从告警到根因”的闭环：

1. **先发现**：告警/红灯（错误率、日志错误、基础设施健康）
2. **再定位对象**：哪个 project/service/任务/请求受影响
3. **再定位证据**：
   - **日志**：错误堆栈、业务参数、关键事件
   - **Trace**：调用链、耗时分解、错误 span 定位
   - **指标**：趋势、容量、饱和、丢弃/背压
4. **再回溯**：从 trace 反查同时间窗日志；从日志一键跳 trace（log↔trace 互跳）

## 边界确认（明确任务范围）

- **在范围内**：
  - 重写/重构 `docker/grafana/resources/dashboards/*.json`（必要时新增/替换现有 dashboard）
  - 统一 dashboard 命名、tags、变量、跳转链接（Explore 链接、derived fields 的使用说明等）
  - 使默认 targets（仅基础设施）下也能“有用”：避免依赖仓库中并不存在的业务指标（如 `ai_router_*`、`http_requests_total` 等）导致默认空面板
- **不在范围内**（除非用户追加）：
  - 修改业务服务的埋点/日志实现、Promtail pipeline、Tempo/Collector 的核心架构
  - 引入额外插件或依赖外部 Grafana marketplace 插件

## 关键歧义与决策（先给出默认决策，必要时再调整）

- **“service” 的可选性**：当前 Loki 最终仅保留 label `project`（文档强调），`service` 多数存在于日志 JSON 字段而非 label。默认面板以 `project` + 解析 JSON 字段为主，避免依赖 `label_values(service)`。
- **Trace 面板展示方式**：Grafana dashboard 中直接展示 Tempo traces 的 panel 形态在不同版本/面板类型上差异较大。默认采用：
  - Logs Drilldown 面板（Loki logs）作为“检索入口”
  - Tempo Explore/Trace 页面作为“链路详情入口”（通过 derived fields/链接跳转）
  - 若确认 Grafana 11.5.0 的 Tempo trace panel 能稳定导入，再补充“Trace List/TraceQL”面板

## 验收标准（可测试）

- 默认 targets 只有基础设施组件时：
  - “Stack/Infra Overview”类面板不空、能看到 Prometheus/Loki/Tempo/Collector 的健康与基本吞吐/错误/丢弃趋势
  - “Logs Drilldown”类面板能按 `project/task_id/trace_id/request_id` 检索日志（前提：日志按规范写 JSON 字段）
  - 日志中 `trace_id`/`task_id` 可点击跳转 Tempo（derived fields 生效）
  - 从 Tempo trace 详情页能反查 Loki 日志（tracesToLogsV2 生效）

