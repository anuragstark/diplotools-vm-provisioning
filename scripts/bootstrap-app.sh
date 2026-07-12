#!/usr/bin/env bash
set -euo pipefail

echo "Starting application bootstrap..."

# Fetch runtime secrets (Dummy commands, simulating AWS SSM)
# In real life: aws ssm get-parameter --name "/myplatform/${ENVIRONMENT}/db_password" --with-decryption ...
echo "DB_PASSWORD=supersecret_from_ssm" > /run/secrets/env_secrets
chmod 600 /run/secrets/env_secrets

echo "Secrets fetched securely."

# Pull latest images based on docker-compose
docker compose -f /opt/myplatform/docker-compose.yml pull

echo "Bootstrap complete."
