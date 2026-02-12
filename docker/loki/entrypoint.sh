#!/bin/sh
set -e

TEMPLATE=/etc/loki/loki.yaml.tpl
OUTPUT=/etc/loki/loki.yaml

# 索引存储配置
# 注意：Loki 的索引存储仅支持 boltdb-shipper（使用文件系统），不支持 PostgreSQL 和 MySQL
LOKI_INDEX_STORE_TYPE="${LOKI_INDEX_STORE_TYPE:-boltdb-shipper}"

# 如果用户尝试使用不支持的索引存储类型，给出错误提示
if [ "$LOKI_INDEX_STORE_TYPE" != "boltdb-shipper" ]; then
  echo "[ERROR] Loki 索引存储类型 '$LOKI_INDEX_STORE_TYPE' 不受支持" >&2
  echo "[ERROR] Loki 的索引存储仅支持 boltdb-shipper（使用文件系统）" >&2
  echo "[ERROR] 请将 LOKI_INDEX_STORE_TYPE 设置为 boltdb-shipper 或留空（使用默认值）" >&2
  exit 1
fi

# BoltDB-shipper 索引存储，使用 Loki 默认配置（避免与新版本 schema 不兼容的字段）
# 这里仅声明使用 boltdb_shipper，具体目录等参数使用 Loki 内置默认值
LOKI_INDEX_STORE_CONFIG=$(cat <<EOF
  boltdb_shipper: {}
EOF
)

# 对象存储配置
LOKI_OBJECT_STORE_TYPE="${LOKI_OBJECT_STORE_TYPE:-filesystem}"
LOKI_OBJECT_STORE_CONFIG=""

case "$LOKI_OBJECT_STORE_TYPE" in
  s3)
    LOKI_OBJECT_STORE_CONFIG=$(cat <<EOF
  s3:
    endpoint: ${LOKI_S3_ENDPOINT}
    region: ${LOKI_S3_REGION}
    bucketnames: ${LOKI_S3_BUCKET_NAME}
    access_key_id: ${LOKI_S3_ACCESS_KEY}
    secret_access_key: ${LOKI_S3_SECRET_KEY}
    s3forcepathstyle: ${LOKI_S3_FORCE_PATH_STYLE}
    insecure: ${LOKI_S3_INSECURE}
EOF
)
    ;;
  filesystem|*)
    # 使用 Loki 默认的 filesystem 存储配置（目录路径使用内置默认）
    LOKI_OBJECT_STORE_CONFIG=$(cat <<EOF
  filesystem: {}
EOF
)
    ;;
esac

export LOKI_INDEX_STORE_TYPE LOKI_INDEX_STORE_CONFIG LOKI_OBJECT_STORE_TYPE LOKI_OBJECT_STORE_CONFIG

render_template() {
  if [ ! -f "$TEMPLATE" ]; then
    echo "[ERROR] Loki config template not found at $TEMPLATE" >&2
    exit 1
  fi

  # 使用 awk 进行简单变量替换，避免依赖 envsubst
  awk -v idx="${LOKI_INDEX_STORE_TYPE:-boltdb-shipper}" \
      -v obj="${LOKI_OBJECT_STORE_TYPE:-filesystem}" \
      -v idx_cfg="$LOKI_INDEX_STORE_CONFIG" \
      -v obj_cfg="$LOKI_OBJECT_STORE_CONFIG" \
      '{
        gsub(/\$\{LOKI_INDEX_STORE_TYPE:-boltdb-shipper\}/, idx);
        gsub(/\$\{LOKI_OBJECT_STORE_TYPE:-filesystem\}/, obj);
        gsub(/\$\{LOKI_INDEX_STORE_CONFIG\}/, idx_cfg);
        gsub(/\$\{LOKI_OBJECT_STORE_CONFIG\}/, obj_cfg);
        print;
      }' "$TEMPLATE" > "$OUTPUT"
}

render_template

exec /usr/bin/loki -config.file="$OUTPUT"
