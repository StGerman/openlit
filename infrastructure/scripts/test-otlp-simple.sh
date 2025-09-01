#!/bin/bash
set -e

INSTANCE_IP="34.225.86.252"

echo "🔧 Simple OTLP Collector Test - Just getting it running first..."

echo "📤 Step 1: Upload debug configuration (no ClickHouse)..."
cat > /tmp/otel-simple.yaml << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
EOF

scp /tmp/otel-simple.yaml ec2-user@$INSTANCE_IP:~/openlit/assets/otel-collector-config.yaml

echo ""
echo "📤 Step 2: Simple docker-compose (no ClickHouse env vars)..."
cat > /tmp/docker-compose-simple.yml << 'EOF'
services:
  openlit:
    image: ghcr.io/openlit/openlit:latest
    platform: linux/arm64
    environment:
      - TELEMETRY_ENABLED=true
      - INIT_DB_HOST=https://v5s7ohqrt5.us-east-1.aws.clickhouse.cloud
      - INIT_DB_PORT=8443
      - INIT_DB_DATABASE=openlit
      - INIT_DB_USERNAME=default
      - INIT_DB_PASSWORD=HZqNl2H~dpl5x
      - SQLITE_DATABASE_URL=file:/app/client/data/data.db
      - PORT=3000
      - DEMO_ACCOUNT_EMAIL=stas.german@gmail.com
      - DEMO_ACCOUNT_PASSWORD=MikMeusSatan123!
    ports:
      - "3000:3000"
    volumes:
      - openlit-data:/app/client/data
    restart: always

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.94.0
    platform: linux/arm64
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
    volumes:
      - ./assets/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml:ro
    restart: unless-stopped

volumes:
  openlit-data:
EOF

scp /tmp/docker-compose-simple.yml ec2-user@$INSTANCE_IP:~/openlit/docker-compose.yml

echo ""
echo "🔄 Step 3: Restart with simple config..."
ssh ec2-user@$INSTANCE_IP 'cd ~/openlit && sudo docker-compose down && sudo docker-compose up -d'

echo ""
echo "⏳ Waiting 15 seconds..."
sleep 15

echo ""
echo "📊 Container status:"
ssh ec2-user@$INSTANCE_IP 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'

echo ""
echo "📝 OTEL logs:"
ssh ec2-user@$INSTANCE_IP 'sudo docker logs openlit-otel-collector-1 --tail 10'

echo ""
echo "🧪 Testing ports:"
for port in 4317 4318 8888; do
    if timeout 5 nc -z $INSTANCE_IP $port; then
        echo "✅ Port $port is accessible"
    else
        echo "❌ Port $port not accessible"
    fi
done

echo ""
echo "🎉 Simple test completed!"

# Cleanup
rm -f /tmp/otel-simple.yaml /tmp/docker-compose-simple.yml
