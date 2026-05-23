#!/bin/bash
set -e

echo "=== Starting Inference Worker Setup ==="

# Update system
apt-get update
apt-get upgrade -y
apt-get install -y \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    htop \
    unzip

# Create application directory
mkdir -p /opt/inference-worker
cd /opt/inference-worker

# Clone repository
git clone ${github_repo} /tmp/hiring
cp -r /tmp/hiring/devops/quickstart/workers/inference-worker/* /opt/inference-worker/

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# Create systemd service file
cat > /etc/systemd/system/inference-worker.service << 'EOF'
[Unit]
Description=Inference Worker (iii Framework)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/inference-worker
Environment="PATH=/opt/inference-worker/venv/bin"
Environment="III_URL=ws://localhost:49134"
ExecStart=/opt/inference-worker/venv/bin/python inference_worker.py

Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=inference-worker

[Install]
WantedBy=multi-user.target
EOF

# Create init script for iii engine (placeholder - would need actual iii engine binary)
cat > /etc/systemd/system/iii-engine.service << 'EOF'
[Unit]
Description=iii Engine Runtime
After=network.target
Before=inference-worker.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/inference-worker
# Note: Replace with actual iii engine binary path when available
ExecStart=/bin/sleep 3600

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ubuntu:ubuntu /opt/inference-worker
chmod +x /opt/inference-worker/venv/bin/python

# Enable and start services
systemctl daemon-reload
systemctl enable iii-engine
systemctl enable inference-worker
systemctl start iii-engine
systemctl start inference-worker

echo "=== Inference Worker Setup Complete ==="
