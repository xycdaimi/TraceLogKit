FROM public.ecr.aws/docker/library/alpine:3.23.2 AS envsubst
RUN apk add --no-cache gettext
#
# Normalize entrypoint line endings in a root-capable stage.
# On Windows checkouts, entrypoint.sh may be CRLF, which breaks shebang execution inside Linux containers
# and manifests as: "exec /entrypoint.sh: no such file or directory" (actually /bin/sh\r not found).
COPY entrypoint.sh /tmp/entrypoint.sh
RUN tr -d '\r' < /tmp/entrypoint.sh > /tmp/entrypoint.lf.sh

FROM quay.io/prometheus/prometheus:v3.8.1
COPY --from=envsubst /usr/bin/envsubst /usr/bin/envsubst
COPY --from=envsubst /lib/ /lib/
COPY --from=envsubst /usr/lib/ /usr/lib/
COPY --chmod=755 --from=envsubst /tmp/entrypoint.lf.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
