#!/bin/sh
set -e

TEMPLATE=/etc/prometheus/prometheus.yml.tpl
OUTPUT=/etc/prometheus/prometheus.yml
TARGETS_TEMPLATE=/etc/prometheus/targets/external-services.yml.tpl
TARGETS_OUTPUT=/etc/prometheus/targets/external-services.yml

normalize_url_target() {
  echo "$1" | sed -e 's#^https\?://##' -e 's#/$##'
}

if [ -z "$PROM_CONSUL_SERVER" ]; then
  consul_host="${CONSUL_HOST:-consul}"
  consul_port="${CONSUL_PORT:-8500}"
  PROM_CONSUL_SERVER="${consul_host}:${consul_port}"
fi

# Safe defaults so Prometheus can start before services.
# These are Docker-network DNS names (not host URLs). Targets will be "down" until services are up.
if [ -z "$PROM_INGRESS_TARGET" ]; then
  PROM_INGRESS_TARGET="ingress-service:${INGRESS_SERVICE_PORT:-80}"
fi

if [ -z "$PROM_LOG_TARGET" ]; then
  PROM_LOG_TARGET="log-service:${LOG_SERVICE_PORT:-9999}"
fi

# 生成外部服务目标配置
API_GATEWAY_TARGET_CONFIG=""
if [ -n "$PROM_API_GATEWAY_TARGET" ]; then
  API_GATEWAY_TARGET_CONFIG=$(cat <<EOF
# API Gateway（静态目标）
- targets:
    - "${PROM_API_GATEWAY_TARGET}"
  labels:
    service: "api-gateway"
    job: "api-gateway"
EOF
)
fi

MODEL_FORWARDER_TARGET_CONFIG=""
if [ -n "$PROM_MODEL_FORWARDER_TARGET" ]; then
  MODEL_FORWARDER_TARGET_CONFIG=$(cat <<EOF
# Model Forwarder（静态目标）
- targets:
    - "${PROM_MODEL_FORWARDER_TARGET}"
  labels:
    service: "model-forwarder"
    job: "model-forwarder"
EOF
)
fi

export PROM_CONSUL_SERVER \
  PROM_INGRESS_TARGET \
  PROM_LOG_TARGET \
  API_GATEWAY_TARGET_CONFIG \
  MODEL_FORWARDER_TARGET_CONFIG

# 生成 Prometheus 主配置文件
if [ -f "$TEMPLATE" ]; then
  envsubst < "$TEMPLATE" > "$OUTPUT"
fi

# 生成外部服务目标文件
if [ -f "$TARGETS_TEMPLATE" ]; then
  envsubst < "$TARGETS_TEMPLATE" > "$TARGETS_OUTPUT"
fi

exec /bin/prometheus "$@"
