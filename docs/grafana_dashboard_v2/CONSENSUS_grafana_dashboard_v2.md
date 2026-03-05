## 共识结论

本次 Grafana 面板重构的目标是形成一套**可落地的问题追踪闭环**，并保证在“默认只采集基础设施 targets”的情况下，面板不会大面积空白。

关键共识：

- **不再依赖业务 Prometheus 指标**（如 `ai_router_*`、`http_requests_total` 等）作为默认面板核心，否则在未接入业务指标时必空。
- **日志与 Trace 的关联策略**：
  - 日志保留 `trace_id`（必须来自 OTel 上下文/标准传播提取，禁止自造伪 trace_id）
  - Grafana 通过 Loki derived fields 实现 **Logs → Tempo** 跳转
  - Grafana 通过 Tempo tracesToLogsV2 实现 **Tempo → Loki** 反查
- **面板职责分离**：
  - Dashboard 以“发现/筛选/定位入口”为主
  - Trace 的“链路详情”优先使用 Tempo Explore/Trace 视图（通过链接跳转），避免在 dashboard 内强依赖特定 trace panel 形态导致不稳定

## 信息架构（Dashboards）

### 1）Infra Overview (Default Targets)

- **文件**：`docker/grafana/resources/dashboards/infra_overview.json`
- **uid**：`tracelogkit_api_stability`
- **用途**：基础设施健康与 scrape 质量检查（UP / scrape duration / samples）
- **为什么替换原 API Stability**：原面板依赖 `http_requests_total`、`http_request_duration_seconds_bucket` 等业务指标，默认 targets 下为空。

### 2）Ingestion Pipeline (Traces & Logs)

- **文件**：`docker/grafana/resources/dashboards/ingestion_pipeline.json`
- **uid**：`tracelogkit_task_pipeline`
- **用途**：观察“采集链路”是否在接收/导出（OTel Collector receiver/exporter、Tempo spans received、Loki bytes received）
- **注意**：不同版本组件指标名可能变化；面板保留 scrape samples 作为兜底。

### 3）Incident Triage (Logs & Alerts)

- **文件**：`docker/grafana/resources/dashboards/incident_triage.json`
- **uid**：`tracelogkit_service_error_rate`
- **用途**：告警入口 + 错误日志聚合（按 project / service / error_code）+ 最近错误日志列表
- **变量**：
  - `project`：来自 Loki label `project`（支持 All）
  - `service`：正则（从日志 JSON 字段解析）

### 4）Drilldown（Logs）

- **文件**：`docker/grafana/resources/dashboards/drilldown.json`
- **uid**：`tracelogkit_drilldown`
- **用途**：按 `task_id / trace_id / request_id` 精确检索日志，并从日志字段一键跳 Tempo
- **变更**：`project` 从手工 textbox 改为 Loki `label_values(project)` 查询变量（支持 All/多选），对应查询改为 `project=~"$project"`。

### 5）Log Error Rate (Loki)

- **文件**：`docker/grafana/resources/dashboards/log_error_rate.json`
- **uid**：`tracelogkit_log_error_rate`
- **用途**：日志错误率监控与告警（对接 `docker/grafana/resources/alerting/log_error_rule.json`）
- **定位**：属于“发现”层（信号灯），不承担 drilldown。

### 6）TraceLogKit Stack Overview

- **文件**：`docker/grafana/resources/dashboards/tracelogkit_stack_overview.json`
- **uid**：`tracelogkit_stack_overview`
- **用途**：基础设施组件 UP + Prometheus 自身状态（head series/queries）

## 问题追踪闭环（推荐工作流）

1. 先看 **Incident Triage**：告警是否 firing？错误集中在哪个 project/service？
2. 进入 **Drilldown**：填 `task_id/trace_id/request_id` 精确定位到一次执行的日志集合。
3. 在日志里点击 `trace_id`（derived field）跳到 Tempo 查看该次执行链路；或点击 `task_id`（TraceQL）聚合看多次执行。
4. 在 Tempo Trace 详情页使用 tracesToLogsV2 回查同一 `project` 下的 Loki 日志（对齐时间窗）。
5. 如怀疑采集链路异常：看 **Ingestion Pipeline** + **Infra Overview**（UP、scrape quality、Collector 接收/导出是否异常）。

## 验收标准

- `bootstrap.sh` 能成功导入全部 dashboard JSON（JSON 语法正确，uid 不冲突，引用的数据源 uid 存在）。
- 默认 targets 仅包含基础设施组件时：
  - Infra Overview / Stack Overview 不空
  - Incident Triage / Drilldown 在有日志数据时可用，并可通过 `trace_id/task_id` 跳转 Tempo
  - Ingestion Pipeline 至少能显示 scrape samples；如组件指标存在则显示接收/导出曲线

