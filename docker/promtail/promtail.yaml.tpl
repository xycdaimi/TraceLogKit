server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_URL:-http://tracelogkit-loki:3100}/loki/api/v1/push
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      # 规范化容器名（Docker SD 通常给的是 "/name"）
      - source_labels: [__meta_docker_container_name]
        regex: '^/(.*)$'
        target_label: __tmp_container
        replacement: '$1'

      # 过滤规则（变量全空 -> drop all；变量非空 -> keep 匹配项）
      ${FILTER_RULES}

      # 清理临时标签，避免污染 Loki labels
      - regex: '^__tmp_.*$'
        action: labeldrop

      # 兜底清理：确保不会把 job/container/compose_* 之类标签带到 Loki
      # project 标签在 pipeline 中生成，这里不生成任何业务标签
      - regex: '^(job|container|compose_project|compose_service)$'
        action: labeldrop

    pipeline_stages:
      - docker: {}

      # 只允许 JSON 字符串行：JSON 解析失败会打上 __error__，下一步统一丢弃
      - json:
          expressions:
            service: service

      - match:
          selector: '{__error__!=""}'
          action: drop
          drop_counter_reason: non_json_or_json_parse_error

      # 从 JSON 字段 service 派生 project：取第一个 '-' 之前的前缀
      # 例：service="foo-bar-baz" -> project="foo"
      - regex:
          source: service
          expression: '^(?P<project>[^-]+)(?:-.*)?$'

      # 最终只输出一个业务标签：project
      - labels:
          project:

      # project 为空则丢弃，避免把空标签值写入 Loki
      - match:
          selector: '{project=""}'
          action: drop
          drop_counter_reason: empty_project

      # 严格保证发往 Loki 只有 project 一个标签（其余全部丢弃）
      - labeldrop:
          - __error__
          - __error_details__
          - __error_source__
          - job
          - container
          - compose_project
          - compose_service
          - stream
          - filename