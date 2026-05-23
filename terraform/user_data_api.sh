#!/bin/bash
set -e

echo "=== Starting API Gateway Setup ==="

# Update system
apt-get update
apt-get upgrade -y
apt-get install -y \
    nodejs \
    npm \
    git \
    wget \
    curl \
    htop \
    unzip

# Create application directory
mkdir -p /opt/caller-worker
cd /opt/caller-worker

# Clone repository
git clone ${github_repo} /tmp/hiring
cp -r /tmp/hiring/devops/quickstart/workers/caller-worker/* /opt/caller-worker/

# Install Node.js dependencies
npm install

# Build TypeScript
npm run build || true

# Create environment file
cat > /opt/caller-worker/.env << EOF
III_URL=ws://${inference_worker_ip}:49134
NODE_ENV=production
PORT=3111
EOF

# Create systemd service file
cat > /etc/systemd/system/caller-worker.service << 'EOF'
[Unit]
Description=Caller Worker (API Gateway) - iii Framework
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/caller-worker
Environment="PATH=/usr/bin:/usr/local/bin"
EnvironmentFile=/opt/caller-worker/.env
ExecStart=/usr/bin/npm run dev

Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=caller-worker

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ubuntu:ubuntu /opt/caller-worker
chmod +x /opt/caller-worker/.env

# Enable and start service
systemctl daemon-reload
systemctl enable caller-worker
systemctl start caller-worker

echo "=== API Gateway Setup Complete ==="
