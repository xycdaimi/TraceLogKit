#!/bin/sh
set -eu

GRAFANA_URL="${GRAFANA_URL:-http://tracelogkit-grafana:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

echo "[bootstrap] waiting for grafana: ${GRAFANA_URL}/api/health"
for i in $(seq 1 120); do
  if curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
    echo "[bootstrap] grafana is ready"
    break
  fi
  sleep 1
done

echo "[bootstrap] checking credentials"
if ! curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/user" >/dev/null 2>&1; then
  echo "[bootstrap] ERROR: Grafana auth failed for user '${GRAFANA_USER}'."
  echo "[bootstrap] If you upgraded/migrated Grafana before, reset the grafana data volume or set correct GRAFANA_ADMIN_USER/PASSWORD in .env."
  exit 1
fi

echo "[bootstrap] ensuring folder TraceLogKit"
folder_uid="tracelogkit"
folder_payload="$(cat <<'JSON'
{"uid":"tracelogkit","title":"TraceLogKit"}
JSON
)"
curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -H "Content-Type: application/json" \
  -X POST "${GRAFANA_URL}/api/folders" \
  --data "${folder_payload}" >/dev/null 2>&1 || true

echo "[bootstrap] applying datasources"
for f in /resources/datasources/*.json; do
  [ -f "$f" ] || continue
  echo "  - $(basename "$f")"
  # idempotent: try create; if exists, update by uid
  uid="$(cat "$f" | sed -n 's/.*"uid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  if [ -n "$uid" ]; then
    # check existing
    if curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources/uid/${uid}" >/dev/null 2>&1; then
      ds_id="$(curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources/uid/${uid}" | sed -n 's/.*"id":[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)"
      if [ -n "$ds_id" ]; then
        curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
          -H "Content-Type: application/json" \
          -X PUT "${GRAFANA_URL}/api/datasources/${ds_id}" \
          --data @"$f" >/dev/null
        continue
      fi
    fi
  fi
  curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${GRAFANA_URL}/api/datasources" \
    --data @"$f" >/dev/null
done

echo "[bootstrap] applying dashboards"
for f in /resources/dashboards/*.json; do
  [ -f "$f" ] || continue
  echo "  - $(basename "$f")"
  payload="$(cat "$f")"
  curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${GRAFANA_URL}/api/dashboards/db" \
    --data "{\"dashboard\":${payload},\"folderUid\":\"${folder_uid}\",\"overwrite\":true}" >/dev/null
done

echo "[bootstrap] applying alert rules"
for f in /resources/alerting/*.json; do
  [ -f "$f" ] || continue
  echo "  - $(basename "$f")"
  payload="$(cat "$f")"
  uid="$(echo "${payload}" | sed -n 's/.*"uid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  if [ -n "$uid" ]; then
    if curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/v1/provisioning/alert-rules/${uid}" 2>/dev/null | grep -q '"uid"'; then
      curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X PUT "${GRAFANA_URL}/api/v1/provisioning/alert-rules/${uid}" \
        --data "${payload}" >/dev/null 2>&1 || true
    else
      curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST "${GRAFANA_URL}/api/v1/provisioning/alert-rules" \
        --data "${payload}" >/dev/null 2>&1 || true
    fi
  fi
done

echo "[bootstrap] applying notification templates"
for f in /resources/alerting/templates/*.json; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .json)"
  echo "  - $name"
  payload="$(cat "$f")"
  curl -sS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X PUT "${GRAFANA_URL}/api/v1/provisioning/templates/${name}" \
    --data "${payload}" >/dev/null
done

echo "[bootstrap] done"

