# Troubleshooting Guide

> **Common issues and solutions for NodifyMe Agent**

## Quick Diagnostics

**Check everything at once:**
```bash
# Service status
systemctl status nodifyme-agent

# Recent logs
journalctl -u nodifyme-agent --since "10 minutes ago" --no-pager

# Network connectivity
curl -I https://your-app-url.com

# Agent API
curl -s http://127.0.0.1:9876/health
```

## Installation Issues

### Download Fails

**Symptoms:**
- `Failed to download agent binary`
- `curl: (22) The requested URL returned error: 404`

**Solutions:**
```bash
# Check internet connectivity
curl -I https://github.com

# Verify architecture detection
uname -m

# Try specific version instead of latest
sudo ./install.sh --version v1.0.0 --api-url YOUR_URL --token YOUR_TOKEN

# Manual download to test
curl -L -I "https://github.com/gsmarketing/nodifymeapp/releases/latest/download/nodifyme-agent-linux-amd64"
```

### Permission Errors

**Symptoms:**
- `Permission denied`
- `Failed to create directory`

**Solutions:**
```bash
# Ensure running as root/sudo
sudo ./install.sh --api-url YOUR_URL --token YOUR_TOKEN

# Check filesystem permissions
df -h
ls -la /usr/local/bin/
ls -la /etc/

# SELinux issues (CentOS/RHEL)
getenforce
sudo setenforce 0  # Temporarily disable for testing
```

### Token Validation Fails

**Symptoms:**
- `AGENT_TOKEN is required but not provided`
- `AGENT_TOKEN must be at least 16 characters long`

**Solutions:**
```bash
# Verify token length
echo -n "YOUR_TOKEN" | wc -c

# Check for hidden characters
echo "YOUR_TOKEN" | xxd

# Use environment variable instead
export AGENT_TOKEN="your-full-token-here"
sudo -E ./install.sh --api-url YOUR_URL
```

## Service Issues

### Service Won't Start

**Symptoms:**
- `Failed to start nodifyme-agent.service`
- `Job for nodifyme-agent.service failed`

**Solutions:**
```bash
# Check detailed error
systemctl status nodifyme-agent -l

# Check journal logs
journalctl -u nodifyme-agent --no-pager

# Verify binary exists and is executable
ls -la /usr/local/bin/nodifyme-agent
ldd /usr/local/bin/nodifyme-agent

# Check config file syntax
cat /etc/nodifyme/config.yaml

# Test manual start
sudo -u nodifyme AGENT_AUTH_TOKEN="$(cat /etc/nodifyme/agent.env | cut -d= -f2)" \
  /usr/local/bin/nodifyme-agent --config /etc/nodifyme/config.yaml
```

### Service Starts But Crashes

**Symptoms:**
- Service shows as `failed` or `inactive`
- Process exits immediately

**Solutions:**
```bash
# Check for core dumps
journalctl -u nodifyme-agent | grep -i "core\|dump\|segfault"

# Verify token format
cat /etc/nodifyme/agent.env

# Check environment loading
systemctl show nodifyme-agent | grep Environment

# Test with verbose logging
# Edit /etc/nodifyme/config.yaml and set log_level: "debug"
sudo systemctl restart nodifyme-agent
journalctl -u nodifyme-agent -f
```

### User/Permission Issues

**Symptoms:**
- `Permission denied` in logs
- `Failed to create log file`

**Solutions:**
```bash
# Check user exists
id nodifyme

# Fix ownership
sudo chown -R nodifyme:nodifyme /etc/nodifyme/
sudo chown -R nodifyme:nodifyme /var/log/nodifyme/
sudo chown -R nodifyme:nodifyme /var/lib/nodifyme/

# Check directory permissions
ls -la /var/log/ | grep nodifyme
ls -la /var/lib/ | grep nodifyme

# Recreate user if needed
sudo userdel nodifyme
sudo groupadd -r nodifyme
sudo useradd -r -s /bin/false -g nodifyme nodifyme
```

## Connectivity Issues

### Can't Connect to App

**Symptoms:**
- `Connection refused`
- `Timeout connecting to server`
- Agent appears healthy but app doesn't see it

**Solutions:**
```bash
# Test direct connectivity
curl -v https://your-app-url.com

# Check DNS resolution
nslookup your-app-url.com

# Test specific port if not 443/80
telnet your-app-url.com 3001

# Check firewall
sudo ufw status
sudo iptables -L

# Test with different URL
# Edit /etc/nodifyme/config.yaml and change api.url
sudo systemctl restart nodifyme-agent
```

### Agent API Not Responding

**Symptoms:**
- `curl: (7) Failed to connect to 127.0.0.1 port 9876: Connection refused`

**Solutions:**
```bash
# Check if agent is listening
ss -tlnp | grep 9876

# Check process is running
ps aux | grep nodifyme-agent

# Verify port configuration
grep -i port /etc/nodifyme/config.yaml

# Test with netstat
netstat -tlnp | grep 9876

# Check for port conflicts
lsof -i :9876
```

### Authentication Errors

**Symptoms:**
- `401 Unauthorized`
- `Invalid token`
- `Authentication failed`

**Solutions:**
```bash
# Verify token in environment file
cat /etc/nodifyme/agent.env

# Check token format
echo "AGENT_AUTH_TOKEN" | base64 -d  # If it's base64 encoded

# Test with manual token
curl -H "X-Agent-Token: YOUR_TOKEN" http://127.0.0.1:9876/metrics

# Regenerate token from app
# Get new token from NodifyMe app and update /etc/nodifyme/agent.env
sudo systemctl restart nodifyme-agent
```

## Application Discovery Issues

### Apps Not Being Detected

**Symptoms:**
- Applications running but not showing in dashboard
- Empty application list

**Solutions:**
```bash
# Check discovery paths
grep -A 10 "discovery:" /etc/nodifyme/config.yaml

# Verify applications are in scanned paths
find /var/www /home/*/apps /opt -name "package.json" 2>/dev/null

# Check if apps are actually running
ps aux | grep node
ps aux | grep npm

# Manual scan trigger (if API supports it)
curl -X POST -H "X-Agent-Token: YOUR_TOKEN" http://127.0.0.1:9876/scan

# Enable debug logging for discovery
# Edit config.yaml and restart service
```

### Container Discovery Issues

**Symptoms:**
- Docker containers not detected
- Container list empty

**Solutions:**
```bash
# Check if Docker is running
systemctl status docker

# Verify Docker socket permissions
ls -la /var/run/docker.sock

# Add nodifyme user to docker group
sudo usermod -a -G docker nodifyme
sudo systemctl restart nodifyme-agent

# Test Docker access
sudo -u nodifyme docker ps

# Check container visibility
docker ps -a
```

## Performance Issues

### High CPU Usage

**Symptoms:**
- Agent consuming excessive CPU
- System slowdown

**Solutions:**
```bash
# Check agent resource usage
top -p $(pgrep nodifyme-agent)

# Adjust monitoring intervals
# Edit /etc/nodifyme/config.yaml:
monitoring:
  interval: 60s  # Increase from 30s

discovery:
  scan_interval: 10m  # Increase from 5m

# Limit discovery paths
discovery:
  paths:
    - "/var/www"  # Remove unused paths

sudo systemctl restart nodifyme-agent
```

### High Memory Usage

**Symptoms:**
- Agent memory usage growing over time
- Out of memory errors

**Solutions:**
```bash
# Check memory usage trend
ps -p $(pgrep nodifyme-agent) -o pid,vsz,rss,etime

# Set memory limits in systemd
sudo systemctl edit nodifyme-agent
# Add:
[Service]
MemoryLimit=128M

# Reduce metrics retention
# Edit /etc/nodifyme/config.yaml:
monitoring:
  metrics_retention: 6h  # Reduce from 24h

sudo systemctl restart nodifyme-agent
```

### Network Issues

**Symptoms:**
- Slow response times
- Intermittent connectivity

**Solutions:**
```bash
# Test network latency
ping your-app-url.com

# Check bandwidth
curl -o /dev/null -s -w "Download: %{speed_download} bytes/sec\n" https://your-app-url.com

# Adjust timeouts
# Edit /etc/nodifyme/config.yaml:
api:
  timeout: 60s  # Increase from 30s
  retry_attempts: 5  # Increase from 3

sudo systemctl restart nodifyme-agent
```

## Log Analysis

### Enable Detailed Logging

```bash
# Edit config file
sudo nano /etc/nodifyme/config.yaml

# Set debug level
monitoring:
  log_level: "debug"

# Restart service
sudo systemctl restart nodifyme-agent

# Watch logs in real-time
journalctl -u nodifyme-agent -f
```

### Log File Locations

```bash
# Systemd journal (primary)
journalctl -u nodifyme-agent

# Traditional log files (if configured)
ls -la /var/log/nodifyme/

# Agent-specific logs
tail -f /var/log/nodifyme/agent.log
```

### Common Log Patterns

**Normal startup:**
```
INFO  Starting NodifyMe Agent v1.0.0
INFO  Loading configuration from /etc/nodifyme/config.yaml
INFO  Starting API server on port 9876
INFO  Agent started - monitoring server
```

**Connection issues:**
```
ERROR Failed to connect to API: connection refused
WARN  Retrying connection in 10 seconds
```

**Authentication problems:**
```
ERROR Authentication failed: invalid token
ERROR X-Agent-Token header missing or invalid
```

## Emergency Recovery

### Complete Reinstall

```bash
# Stop and remove service
sudo systemctl stop nodifyme-agent
sudo systemctl disable nodifyme-agent
sudo rm -f /etc/systemd/system/nodifyme-agent.service

# Remove files
sudo rm -rf /etc/nodifyme/
sudo rm -rf /var/log/nodifyme/
sudo rm -rf /var/lib/nodifyme/
sudo rm -f /usr/local/bin/nodifyme-agent

# Remove user
sudo userdel nodifyme
sudo groupdel nodifyme

# Reinstall
curl -fsSL https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh | \
  sudo bash -s -- --api-url YOUR_URL --token YOUR_TOKEN
```

### Backup Configuration

```bash
# Before making changes, backup config
sudo cp -r /etc/nodifyme/ /tmp/nodifyme-backup/

# Restore if needed
sudo cp -r /tmp/nodifyme-backup/* /etc/nodifyme/
sudo chown -R nodifyme:nodifyme /etc/nodifyme/
sudo systemctl restart nodifyme-agent
```

## Getting Additional Help

### Collect Diagnostic Information

```bash
# Create diagnostic report
cat > /tmp/nodifyme-diagnostics.txt <<EOF
=== System Information ===
$(uname -a)
$(cat /etc/os-release)

=== Service Status ===
$(systemctl status nodifyme-agent)

=== Recent Logs ===
$(journalctl -u nodifyme-agent --since "1 hour ago" --no-pager)

=== Configuration ===
$(cat /etc/nodifyme/config.yaml)

=== Network ===
$(ss -tlnp | grep 9876)
$(ps aux | grep nodifyme-agent)

=== Permissions ===
$(ls -la /etc/nodifyme/)
$(ls -la /var/log/nodifyme/)
EOF

echo "Diagnostic report saved to /tmp/nodifyme-diagnostics.txt"
```

### Contact Support

When reporting issues, include:
1. Your operating system and version
2. The exact error message
3. Steps to reproduce the issue
4. The diagnostic report above
5. Your NodifyMe app version

---

*Most issues can be resolved by checking logs and verifying configuration. When in doubt, try a clean reinstall.*