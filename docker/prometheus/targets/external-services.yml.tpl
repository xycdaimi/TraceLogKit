# 外部服务的监控配置（通过环境变量动态生成）
# 此文件由 entrypoint.sh 根据 .env 配置自动生成

# API Gateway（如果配置了静态目标）
${API_GATEWAY_TARGET_CONFIG}

# Model Forwarder（如果配置了静态目标）
${MODEL_FORWARDER_TARGET_CONFIG}

# Ingress Service
- targets:
    - "${PROM_INGRESS_TARGET:-ingress-service:80}"
  labels:
    service: "ingress-service"
    job: "ingress-service"

# Log Service
- targets:
    - "${PROM_LOG_TARGET:-log-service:9999}"
  labels:
    service: "log-service"
    job: "log-service"
