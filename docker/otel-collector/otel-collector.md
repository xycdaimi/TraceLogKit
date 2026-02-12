# OpenTelemetry Collector（Tracing 汇聚）

启动：

- Windows：`.\start.bat`
- Linux/macOS：`./start.sh`

端口：

- OTLP gRPC：`localhost:4317`
- OTLP HTTP：`http://localhost:4318`
- Collector metrics：`http://localhost:8888/metrics`

说明：

- 本 Collector 将 OTLP traces 转发到 `tracelogkit-tempo:4317`（同一 Docker 网络内，默认 `${TRACELOGKIT_NETWORK_NAME:-tracelogkit-network}`）。
- Tempo 是 TraceLogKit 的 tracing 后端。

