#!/usr/bin/env python3
"""使用 OpenTelemetry SDK 发送测试 trace（推荐方式）"""
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

# 配置 OTLP exporter
exporter = OTLPSpanExporter(
    endpoint="http://localhost:4318/v1/traces"
)

# 创建 TracerProvider
resource = Resource.create({"service.name": "test-service"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

# 创建 tracer 并发送 span
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("test-span") as span:
    span.set_attribute("test.attribute", "test-value")
    span.set_attribute("test.status", "success")
    # span 会自动结束并发送

print("Trace 已发送")
print(f"Trace ID: {format(span.get_span_context().trace_id, '032x')}")
print("在 Grafana Tempo 中查询此 trace ID")