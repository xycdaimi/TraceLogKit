#!/bin/sh
set -e

TEMPLATE=/etc/promtail/promtail.yaml.tpl
OUTPUT=/etc/promtail/promtail.yaml

# 过滤规则生成（白名单：变量全空 -> 彻底禁止采集）
FILTER_RULES=""
HAS_ANY_FILTER=false

is_blank() {
  # treat whitespace-only as blank
  [ -z "$(printf %s "${1:-}" | tr -d '[:space:]')" ]
}

escape_re2_literal() {
  # escape common RE2 meta chars for literal match in alternation lists
  # shellcheck disable=SC2001
  printf %s "$1" | sed -e 's/[.[\\^$*+?(){}|]/\\&/g'
}

csv_to_re2_alternation_literals() {
  # "a,b,c" -> "a|b|c" (each item escaped as literal)
  # empty items are ignored
  # NOTE: avoid `while ... | ...` subshell issues and external `paste` quirks.
  # Build a single-line RE2 alternation safely.
  printf %s "$1" | awk -F',' '
    BEGIN { n = 0 }
    {
      for (i = 1; i <= NF; i++) {
        s = $i
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        if (s == "") continue
        # escape common RE2 meta chars: . [ \ ^ $ * + ? ( ) { } |
        gsub(/[.[\\^$*+?(){}|]/, "\\\\&", s)
        if (n++ > 0) printf "|"
        printf "%s", s
      }
    }
  '
}

add_keep_filter() {
  # Promtail relabel keep must specify regex + source_labels
  # label should be written as __tmp_container etc (no quotes)
  label=$1
  pattern=$2
  FILTER_RULES="${FILTER_RULES}
      - source_labels: [${label}]
        regex: '${pattern}'
        action: keep"
}

# 1) 容器名称列表过滤（精确匹配，逗号分隔）
if ! is_blank "${PROMTAIL_CONTAINER_NAMES:-}"; then
  HAS_ANY_FILTER=true
  alts=$(csv_to_re2_alternation_literals "$PROMTAIL_CONTAINER_NAMES" || true)
  if ! is_blank "$alts"; then
    add_keep_filter "__tmp_container" "^(${alts})$"
  fi
fi

# 2) 容器名称正则匹配（对规范化后的容器名匹配）
if ! is_blank "${PROMTAIL_CONTAINER_NAME_PATTERN:-}"; then
  HAS_ANY_FILTER=true
  add_keep_filter "__tmp_container" "$PROMTAIL_CONTAINER_NAME_PATTERN"
fi

# 3) Compose 项目匹配（支持逗号列表或正则）
if ! is_blank "${PROMTAIL_COMPOSE_PROJECT:-}"; then
  HAS_ANY_FILTER=true
  if printf %s "$PROMTAIL_COMPOSE_PROJECT" | grep -q ','; then
    alts=$(csv_to_re2_alternation_literals "$PROMTAIL_COMPOSE_PROJECT" || true)
    add_keep_filter "__meta_docker_container_label_com_docker_compose_project" "^(${alts})$"
  else
    add_keep_filter "__meta_docker_container_label_com_docker_compose_project" "$PROMTAIL_COMPOSE_PROJECT"
  fi
fi

# 4) Compose 服务匹配（逗号分隔，"或"）
if ! is_blank "${PROMTAIL_COMPOSE_SERVICE:-}"; then
  HAS_ANY_FILTER=true
  alts=$(csv_to_re2_alternation_literals "$PROMTAIL_COMPOSE_SERVICE" || true)
  if ! is_blank "$alts"; then
    add_keep_filter "__meta_docker_container_label_com_docker_compose_service" "^(${alts})$"
  fi
fi

# 如果没有任何过滤变量：显式 drop 掉所有容器（保证 0 采集）
if [ "$HAS_ANY_FILTER" = "false" ]; then
  # 更强的“禁用采集”：直接生成空 scrape_configs，避免任何 target 被创建/读取/推送
  promtail_loki_url="${LOKI_URL:-http://tracelogkit-loki:3100}"
  cat > "$OUTPUT" <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${promtail_loki_url}/loki/api/v1/push

scrape_configs: []
EOF

  echo "--- Generated Configuration (COLLECTION DISABLED: no filters set) ---"
  cat "$OUTPUT"
  echo "--------------------------------------------------------------------"
  if [ "${PROMTAIL_RENDER_ONLY:-}" = "1" ]; then
    exit 0
  fi
  exec /usr/bin/promtail --config.file="$OUTPUT" "$@"
fi

export FILTER_RULES

render_template() {
  promtail_loki_url="${LOKI_URL:-http://tracelogkit-loki:3100}"
  
  awk -v rules="$FILTER_RULES" \
      -v url="$promtail_loki_url" \
      '{
        if ($0 ~ /\$\{FILTER_RULES\}/) {
            print rules
        } else {
            gsub(/\$\{LOKI_URL:-http:\/\/tracelogkit-loki:3100\}/, url);
            print $0
        }
      }' "$TEMPLATE" > "$OUTPUT"
}

render_template

# 启动前打印配置，让你一眼看到生成的 relabel_configs
echo "--- Generated Configuration ---"
cat "$OUTPUT"
echo "-------------------------------"

if [ "${PROMTAIL_RENDER_ONLY:-}" = "1" ]; then
  exit 0
fi
exec /usr/bin/promtail --config.file="$OUTPUT" "$@"