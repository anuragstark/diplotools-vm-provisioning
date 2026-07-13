#!/usr/bin/env bash
set -euo pipefail

echo "Starting application bootstrap..."

# Load environment variables written by SSM deploy step
if [ -f /opt/myplatform/.env ]; then
  set -o allexport
  source /opt/myplatform/.env
  set +o allexport
fi

# Ensure secrets directory exists (since /run is wiped on reboot)
mkdir -p /run/secrets

# Install Docker Compose V2 if missing (self-healing for existing instances)
if ! docker compose version &>/dev/null; then
  echo "Docker Compose V2 not found. Installing..."
  apt-get install -y docker-compose-v2 || \
  curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
  echo "Docker Compose V2 installed."
fi


# Grafana Provisioning (Datasources)

echo "Configuring Grafana Provisioning..."
mkdir -p /opt/myplatform/grafana/provisioning/datasources

cat << 'EOF' > /opt/myplatform/grafana/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF


# Start the Platform

echo "Starting Docker Compose services..."

# Fetch runtime secrets (Dummy commands, simulating AWS SSM)
# In real life: aws ssm get-parameter --name "/myplatform/${ENVIRONMENT}/db_password" --with-decryption ...
echo "DB_PASSWORD=supersecret_from_ssm" > /run/secrets/env_secrets
chmod 600 /run/secrets/env_secrets

echo "Secrets fetched securely."

# Authenticate with ECR
echo "Authenticating with AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Pull latest images based on docker-compose
docker compose -f /opt/myplatform/docker-compose.yml pull

# Start or restart containers dynamically
docker compose -f /opt/myplatform/docker-compose.yml up -d

echo "Bootstrap complete."
