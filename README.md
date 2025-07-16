# Nodify.Me Agent

> **Monitoring agent for Node.js applications and Docker containers**

Nodify.Me Agent is a lightweight monitoring daemon that runs on your servers to collect system metrics and detect Node.js applications (Next.js, Nest.js, Vite) and Docker containers.

## Quick Installation

**Automated Installation (Recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh | \
  sudo bash -s -- --api-url YOUR_API_URL --token YOUR_AGENT_TOKEN
```

**Manual Installation:**
1. Download the installation script: `curl -fsSL -O https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh`
2. Make it executable: `chmod +x install.sh`
3. Run with your parameters: `sudo ./install.sh --api-url YOUR_API_URL --token YOUR_AGENT_TOKEN`

## Installation Requirements

- **Linux Server** (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2+)
- **Architecture** (amd64 or arm64)
- **Root/sudo access** for installation
- **Network access** to download binaries and communicate with your Nodify.Me app

## Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `--api-url` | ✅ | URL of your Nodify.Me application | `https://app.nodifyme.com` |
| `--token` | ✅ | Agent authentication token (min 16 chars) | `eyJ0eXAiOiJKV1QiLCJhbGc...` |
| `--version` | ❌ | Specific agent version to install | `v1.0.0` (default: `latest`) |

## What Gets Installed

The installation script will:
- Download the appropriate binary for your architecture
- Create a dedicated `nodifyme` system user
- Install the agent as a systemd service
- Configure monitoring directories
- Set up log rotation
- Generate secure configuration files

**Installation Locations:**
- **Binary**: `/usr/local/bin/nodifyme-agent`
- **Configuration**: `/etc/nodifyme/config.yaml`
- **Environment**: `/etc/nodifyme/agent.env`
- **Logs**: `/var/log/nodifyme/`
- **Data**: `/var/lib/nodifyme/`

## Agent Features

### System Monitoring
- **CPU Usage** - Real-time processor utilization
- **Memory Usage** - RAM and swap monitoring  
- **Disk Usage** - Storage space and I/O metrics
- **Network Statistics** - Bandwidth and connection monitoring

### Application Discovery
- **Next.js Applications** - Automatic detection and monitoring
- **Nest.js Applications** - API and service monitoring
- **Vite Applications** - Development and production builds
- **Generic Node.js** - Process detection and health checks

### Container Monitoring
- **Docker Containers** - Resource usage and health status
- **Container Logs** - Read-only log access
- **Image Information** - Container metadata and versions

### Security Features
- **Token-based Authentication** - Secure communication with your app
- **Localhost-only Binding** - Agent API only accessible locally
- **Command Whitelisting** - Only approved operations allowed
- **Non-root Execution** - Agent runs as dedicated system user

## Service Management

**Check Status:**
```bash
systemctl status nodifyme-agent
```

**View Logs:**
```bash
journalctl -u nodifyme-agent -f
```

**Restart Service:**
```bash
sudo systemctl restart nodifyme-agent
```

**Stop Service:**
```bash
sudo systemctl stop nodifyme-agent
```

## Uninstallation

To completely remove the agent:
```bash
curl -fsSL https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/uninstall.sh | sudo bash
```

Or download and run manually:
```bash
curl -fsSL -O https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/uninstall.sh
chmod +x uninstall.sh
sudo ./uninstall.sh
```

## Troubleshooting

### Common Issues

**Agent not starting:**
```bash
# Check service status
systemctl status nodifyme-agent

# Check logs for errors
journalctl -u nodifyme-agent --no-pager

# Verify token is set
cat /etc/nodifyme/agent.env
```

**Connection issues:**
```bash
# Test network connectivity
curl -I https://your-app-url.com

# Check firewall settings
sudo ufw status

# Verify agent is listening
ss -tlnp | grep 9876
```

**Permission issues:**
```bash
# Check file ownership
ls -la /etc/nodifyme/
ls -la /var/log/nodifyme/

# Fix permissions if needed
sudo chown -R nodifyme:nodifyme /etc/nodifyme/
sudo chown -R nodifyme:nodifyme /var/log/nodifyme/
```

### Getting Help

If you encounter issues:
1. Check the [troubleshooting guide](docs/troubleshooting.md)
2. Review the [manual installation guide](docs/manual-install.md)
3. Check your Nodify.Me application logs
4. Verify your server meets the requirements

## Architecture

The Nodify.Me Agent is designed for:
- **Minimal Resource Usage** - Low CPU and memory footprint
- **Security First** - Secure by default with minimal attack surface
- **Easy Deployment** - One-command installation and configuration
- **Reliable Monitoring** - Robust error handling and automatic recovery

## License

Copyright © 2024 Nodify.Me. All rights reserved.

---

*Nodify.Me Agent - Monitoring made simple* 🚀