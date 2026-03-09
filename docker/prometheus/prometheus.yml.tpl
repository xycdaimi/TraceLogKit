global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # 动态服务发现（文件服务发现）
  # 在 /etc/prometheus/targets/ 目录下添加 YAML 文件即可动态添加监控目标
  # Prometheus 会自动发现并开始监控，无需重启
  # 所有服务（包括 TraceLogKit 自身服务和外部服务）都通过此方式配置
  - job_name: "all-services"
    metrics_path: /metrics
    file_sd_configs:
      - files:
          - "/etc/prometheus/targets/*.yml"
        refresh_interval: 30s
    relabel_configs:
      # 若 target 的 labels 中有 metrics_path，则用作抓取路径（支持同端口不同路由）
      - source_labels: [metrics_path]
        regex: "(.+)"
        target_label: __metrics_path__
        replacement: "${1}"
      - regex: "metrics_path"
        action: labeldrop