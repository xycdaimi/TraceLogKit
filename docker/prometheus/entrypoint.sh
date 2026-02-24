#!/bin/sh
set -e

TEMPLATE=/etc/prometheus/prometheus.yml.tpl
OUTPUT=/etc/prometheus/prometheus.yml

# 生成 Prometheus 主配置文件
if [ -f "$TEMPLATE" ]; then
  cp "$TEMPLATE" "$OUTPUT"
fi

exec /bin/prometheus "$@"
