# Manual Installation Guide

> **Technical user guide for manual Nodify.Me Agent installation**

This guide is for system administrators and technical users who want more control over the installation process.

## Prerequisites

- Linux server (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2+)
- Root or sudo access
- `curl` and `systemctl` available
- Network access to GitHub and your Nodify.Me application

## Step-by-Step Installation

### 1. Download Installation Script

```bash
# Download the script
curl -fsSL -O https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh

# Make it executable
chmod +x install.sh

# Review the script (recommended)
less install.sh
```

### 2. Obtain Agent Token

Get your agent token from your Nodify.Me application:
- Log in to your Nodify.Me app
- Go to Settings → Servers → Add Server
- Generate or copy the agent token

### 3. Run Installation

```bash
# Basic installation
sudo ./install.sh --api-url https://your-app.com --token YOUR_TOKEN

# With specific version
sudo ./install.sh --api-url https://your-app.com --token YOUR_TOKEN --version v1.0.0

# Environment variables (alternative)
export API_URL="https://your-app.com"
export AGENT_TOKEN="your-token-here"
sudo -E ./install.sh
```

### 4. Verify Installation

```bash
# Check service status
systemctl status nodifyme-agent

# View recent logs
journalctl -u nodifyme-agent --since "5 minutes ago"

# Test agent connectivity
curl -s http://127.0.0.1:9876/health || echo "Agent not responding"
```

## Installation Options

### Custom Installation Directory

```bash
# Set custom directories before installation
export INSTALL_DIR="/opt/nodifyme/bin"
export CONFIG_DIR="/opt/nodifyme/etc"
export LOG_DIR="/opt/nodifyme/logs"
export DATA_DIR="/opt/nodifyme/data"

sudo -E ./install.sh --api-url YOUR_URL --token YOUR_TOKEN
```

### Specific Architecture

```bash
# Force specific architecture (usually auto-detected)
export ARCH="amd64"  # or "arm64"
sudo -E ./install.sh --api-url YOUR_URL --token YOUR_TOKEN
```

## Configuration Files

### Main Configuration (`/etc/nodifyme/config.yaml`)

```yaml
# Nodify.Me Agent Configuration
api:
  url: "https://your-app.com"
  timeout: 30s
  retry_attempts: 3

monitoring:
  interval: 30s
  metrics_retention: 24h
  log_level: "info"

discovery:
  scan_interval: 5m
  enabled: true
  paths:
    - "/var/www"
    - "/home/*/apps"
    - "/opt"

security:
  run_as_user: "nodifyme"
  run_as_group: "nodifyme"
  allow_privileged: false
```

### Environment File (`/etc/nodifyme/agent.env`)

```bash
# Agent Authentication Token
AGENT_AUTH_TOKEN=your-secure-token-here
```

### Systemd Service (`/etc/systemd/system/nodifyme-agent.service`)

```ini
[Unit]
Description=Nodify.Me Monitoring Agent
Documentation=https://github.com/gsmarketing/nodifymeapp
After=network.target
Wants=network.target

[Service]
Type=simple
User=nodifyme
Group=nodifyme
EnvironmentFile=/etc/nodifyme/agent.env
ExecStart=/usr/local/bin/nodifyme-agent --config /etc/nodifyme/config.yaml
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nodifyme-agent

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/nodifyme /var/lib/nodifyme
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

## Binary-Only Installation

If you prefer to install just the binary without the full setup:

### 1. Download Binary

```bash
# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Download latest binary
curl -L -o nodifyme-agent \
  "https://github.com/gsmarketing/nodifymeapp/releases/latest/download/nodifyme-agent-linux-$ARCH"

# Make executable
chmod +x nodifyme-agent

# Move to PATH
sudo mv nodifyme-agent /usr/local/bin/
```

### 2. Create Configuration

```bash
# Create config directory
sudo mkdir -p /etc/nodifyme

# Create config file
sudo tee /etc/nodifyme/config.yaml > /dev/null <<EOF
api:
  url: "https://your-app.com"
  timeout: 30s
  retry_attempts: 3
monitoring:
  interval: 30s
  log_level: "info"
EOF

# Create environment file
sudo tee /etc/nodifyme/agent.env > /dev/null <<EOF
AGENT_AUTH_TOKEN=your-token-here
EOF

# Set permissions
sudo chmod 600 /etc/nodifyme/agent.env
```

### 3. Run Manually

```bash
# Run in foreground (for testing)
AGENT_AUTH_TOKEN=your-token-here /usr/local/bin/nodifyme-agent --config /etc/nodifyme/config.yaml

# Run in background
nohup /usr/local/bin/nodifyme-agent --config /etc/nodifyme/config.yaml > /var/log/nodifyme-agent.log 2>&1 &
```

## Security Considerations

### File Permissions

```bash
# Verify secure permissions
ls -la /etc/nodifyme/
# Should show:
# -rw-r--r-- config.yaml
# -rw------- agent.env (600 - only owner can read)
```

### Network Security

```bash
# Agent only binds to localhost
ss -tlnp | grep 9876
# Should show: 127.0.0.1:9876

# Firewall considerations
# No need to open port 9876 - agent uses SSH tunnels for communication
```

### User Security

```bash
# Verify agent runs as non-root user
ps aux | grep nodifyme-agent
# Should show user "nodifyme", not "root"
```

## Updating the Agent

### Automatic Update

```bash
# Run installer again with force flag
sudo ./install.sh --api-url YOUR_URL --token YOUR_TOKEN --force
```

### Manual Update

```bash
# Stop service
sudo systemctl stop nodifyme-agent

# Download new binary
curl -L -o /tmp/nodifyme-agent-new \
  "https://github.com/gsmarketing/nodifymeapp/releases/latest/download/nodifyme-agent-linux-amd64"

# Replace binary
sudo mv /tmp/nodifyme-agent-new /usr/local/bin/nodifyme-agent
sudo chmod +x /usr/local/bin/nodifyme-agent

# Start service
sudo systemctl start nodifyme-agent
```

## Debugging

### Enable Debug Logging

```bash
# Edit config file
sudo nano /etc/nodifyme/config.yaml

# Change log_level to "debug"
monitoring:
  log_level: "debug"

# Restart service
sudo systemctl restart nodifyme-agent
```

### Check Agent API

```bash
# Test agent endpoints
curl -s http://127.0.0.1:9876/health
curl -s -H "X-Agent-Token: YOUR_TOKEN" http://127.0.0.1:9876/metrics
```

### System Resource Usage

```bash
# Check agent resource usage
top -p $(pgrep nodifyme-agent)
systemctl status nodifyme-agent
```

## Advanced Configuration

### Custom Monitoring Paths

Edit `/etc/nodifyme/config.yaml`:

```yaml
discovery:
  paths:
    - "/var/www"           # Web applications
    - "/home/*/apps"       # User applications
    - "/opt/apps"          # System applications
    - "/srv/applications"  # Service applications
```

### Monitoring Intervals

```yaml
monitoring:
  interval: 15s          # Collect metrics every 15 seconds
  
discovery:
  scan_interval: 2m      # Scan for new apps every 2 minutes
```

### Resource Limits

Edit the systemd service file to adjust limits:

```ini
# Memory limit (optional)
MemoryLimit=128M

# CPU limit (optional)  
CPUQuota=50%

# File descriptor limit
LimitNOFILE=32768
```

## Troubleshooting

See the [troubleshooting guide](troubleshooting.md) for common issues and solutions.

---

*For automated installation, see the main [README](../README.md)*