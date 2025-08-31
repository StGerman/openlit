#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install Git
yum install -y git

# Clone OpenLIT repository
cd /home/ec2-user
git clone https://github.com/openlit/openlit.git

# Create environment file
cat > /home/ec2-user/openlit/.env << EOF
# ClickHouse Configuration
INIT_DB_HOST=${clickhouse_host}
INIT_DB_PORT=${clickhouse_port}
INIT_DB_DATABASE=${clickhouse_database}
INIT_DB_USERNAME=${clickhouse_username}
INIT_DB_PASSWORD=${clickhouse_password}

# OTEL Configuration
OTEL_DB_HOST=${otel_host}
OTEL_DB_PORT=${otel_port}

# Demo Accounts
DEMO_ACCOUNT_EMAIL=${demo_email_1}
DEMO_ACCOUNT_PASSWORD=${demo_password_1}

# Application Configuration
TELEMETRY_ENABLED=true
PORT=3000
DOCKER_PORT=3000
SQLITE_DATABASE_URL=file:/app/client/data/data.db

# AWS Configuration
AWS_ACCOUNT_ID=${aws_account_id}
AWS_REGION=${aws_region}
ECR_REPOSITORY=${ecr_repository}
IMAGE_TAG=${image_tag}
EOF

# Create Docker Compose file for AWS deployment
cat > /home/ec2-user/openlit/docker-compose.yml << EOF
services:
  openlit:
    image: ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository}:${image_tag}
    platform: linux/arm64
    environment:
      - TELEMETRY_ENABLED=true
      - INIT_DB_HOST=${clickhouse_host}
      - INIT_DB_PORT=${clickhouse_port}
      - INIT_DB_DATABASE=${clickhouse_database}
      - INIT_DB_USERNAME=${clickhouse_username}
      - INIT_DB_PASSWORD=${clickhouse_password}
      - SQLITE_DATABASE_URL=file:/app/client/data/data.db
      - PORT=3000
      - DOCKER_PORT=3000
      - DEMO_ACCOUNT_EMAIL=${demo_email_1}
      - DEMO_ACCOUNT_PASSWORD=${demo_password_1}
    ports:
      - "3000:3000"
    volumes:
      - openlit-data:/app/client/data
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.94.0
    platform: linux/arm64
    environment:
      - OTEL_DB_HOST=${otel_host}
      - OTEL_DB_PORT=${otel_port}
      - INIT_DB_DATABASE=${clickhouse_database}
      - INIT_DB_USERNAME=${clickhouse_username}
      - INIT_DB_PASSWORD=${clickhouse_password}
    ports:
      - "4317:4317"
      - "4318:4318"
      - "8888:8888"
      - "55679:55679"
    volumes:
      - ./assets/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888/"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  openlit-data:
EOF

# Set proper ownership
chown -R ec2-user:ec2-user /home/ec2-user/openlit

# Configure ECR authentication
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com

# Pull and start services
cd /home/ec2-user/openlit
docker-compose pull
docker-compose up -d

# Create systemd service for auto-restart
cat > /etc/systemd/system/openlit.service << EOF
[Unit]
Description=OpenLIT Demo Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/openlit
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF

systemctl enable openlit.service
systemctl start openlit.service

# Log installation completion
echo "$(date): OpenLIT installation completed successfully" >> /var/log/openlit-install.log
