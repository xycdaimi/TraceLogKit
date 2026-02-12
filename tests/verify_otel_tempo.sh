#!/bin/bash
echo "=== 验证 OTel Collector → Tempo 连接 ==="

echo "1. 检查容器状态..."
docker ps | grep -E "otel-collector|tempo"

echo -e "\n2. 检查网络连通性..."
docker exec tracelogkit-otel-collector ping -c 2 tracelogkit-tempo > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ OTel Collector 可以 ping 通 Tempo"
else
    echo "✗ OTel Collector 无法 ping 通 Tempo"
fi

echo -e "\n3. 检查端口连通性..."
docker exec tracelogkit-otel-collector nc -zv tracelogkit-tempo 4317 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ 端口 4317 (gRPC) 可达"
else
    echo "✗ 端口 4317 (gRPC) 不可达"
fi

echo -e "\n4. 检查 Tempo 健康状态..."
curl -s http://localhost:3200/ready
echo ""

echo -e "\n5. 查看 OTel Collector 最新日志（最后 10 行）..."
docker logs --tail 10 tracelogkit-otel-collector

echo -e "\n6. 查看 Tempo 最新日志（最后 10 行）..."
docker logs --tail 10 tracelogkit-tempo