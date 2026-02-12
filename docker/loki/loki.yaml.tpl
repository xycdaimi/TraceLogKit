auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: ${LOKI_INDEX_STORE_TYPE:-boltdb-shipper}
      object_store: ${LOKI_OBJECT_STORE_TYPE:-filesystem}
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  ${LOKI_INDEX_STORE_CONFIG}
  ${LOKI_OBJECT_STORE_CONFIG}

compactor:
  working_directory: /loki/compactor
  shared_store: ${LOKI_OBJECT_STORE_TYPE:-filesystem}

limits_config:
  retention_period: 168h
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  allow_structured_metadata: true

chunk_store_config:
  max_look_back_period: 168h

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
