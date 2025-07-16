#!/bin/bash

# NodifyMe Agent Installation Script
# This script installs the NodifyMe monitoring agent on Linux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGENT_VERSION="${AGENT_VERSION:-latest}"
API_URL="${API_URL:-}"
AGENT_TOKEN="${AGENT_TOKEN:-}"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="nodifyme-agent"
USER_NAME="nodifyme"
GROUP_NAME="nodifyme"
CONFIG_DIR="/etc/nodifyme"
LOG_DIR="/var/log/nodifyme"
DATA_DIR="/var/lib/nodifyme"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to detect OS and architecture
detect_system() {
    print_status "Detecting system information..."
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
    else
        print_error "Could not detect OS"
        exit 1
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    print_success "Detected: $OS_NAME $OS_VERSION ($ARCH)"
}

# Function to download agent binary
download_agent() {
    print_status "Downloading NodifyMe agent..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download URL
    if [[ "$AGENT_VERSION" == "latest" ]]; then
        DOWNLOAD_URL="https://github.com/gsmarketing/nodifymeapp/releases/latest/download/nodifyme-agent-linux-$ARCH"
    else
        DOWNLOAD_URL="https://github.com/gsmarketing/nodifymeapp/releases/download/$AGENT_VERSION/nodifyme-agent-linux-$ARCH"
    fi
    
    # Download binary
    if ! curl -L -o nodifyme-agent "$DOWNLOAD_URL"; then
        print_error "Failed to download agent binary"
        exit 1
    fi
    
    # Verify binary
    if ! chmod +x nodifyme-agent; then
        print_error "Failed to make binary executable"
        exit 1
    fi
    
    # Test binary
    if ! ./nodifyme-agent --version > /dev/null 2>&1; then
        print_error "Downloaded binary is not working"
        exit 1
    fi
    
    print_success "Agent binary downloaded successfully"
}

# Function to install agent
install_agent() {
    print_status "Installing agent to $INSTALL_DIR..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Install binary
    cp nodifyme-agent "$INSTALL_DIR/"
    chmod 755 "$INSTALL_DIR/nodifyme-agent"
    
    print_success "Agent installed to $INSTALL_DIR/nodifyme-agent"
}

# Function to create system user
create_user() {
    print_status "Creating system user..."
    
    # Check if user already exists
    if id "$USER_NAME" &>/dev/null; then
        print_warning "User $USER_NAME already exists"
    else
        # Create user and group
        groupadd -r "$GROUP_NAME" 2>/dev/null || true
        useradd -r -s /bin/false -g "$GROUP_NAME" "$USER_NAME" 2>/dev/null || true
        print_success "Created user $USER_NAME"
    fi
}

# Function to create directories
create_directories() {
    print_status "Creating directories..."
    
    # Create configuration directory
    mkdir -p "$CONFIG_DIR"
    chown "$USER_NAME:$GROUP_NAME" "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    chown "$USER_NAME:$GROUP_NAME" "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Create data directory
    mkdir -p "$DATA_DIR"
    chown "$USER_NAME:$GROUP_NAME" "$DATA_DIR"
    chmod 755 "$DATA_DIR"
    
    print_success "Directories created"
}

# Function to validate required parameters
validate_parameters() {
    if [[ -z "$AGENT_TOKEN" ]]; then
        print_error "AGENT_TOKEN is required but not provided"
        print_error "Use --token TOKEN or set AGENT_TOKEN environment variable"
        exit 1
    fi
    
    if [[ ${#AGENT_TOKEN} -lt 16 ]]; then
        print_error "AGENT_TOKEN must be at least 16 characters long"
        exit 1
    fi
    
    print_success "Parameters validated successfully"
}

# Function to create configuration
create_config() {
    print_status "Creating configuration..."
    
    # Create default configuration
    cat > "$CONFIG_DIR/config.yaml" <<EOF
# NodifyMe Agent Configuration
api:
  url: "${API_URL:-http://localhost:3001}"
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
  run_as_user: "$USER_NAME"
  run_as_group: "$GROUP_NAME"
  allow_privileged: false
EOF

    # Create environment file for the agent token
    cat > "$CONFIG_DIR/agent.env" <<EOF
# Agent Authentication Token
AGENT_AUTH_TOKEN=${AGENT_TOKEN:-}
EOF
    
    chown "$USER_NAME:$GROUP_NAME" "$CONFIG_DIR/config.yaml"
    chmod 644 "$CONFIG_DIR/config.yaml"
    
    chown "$USER_NAME:$GROUP_NAME" "$CONFIG_DIR/agent.env"
    chmod 600 "$CONFIG_DIR/agent.env"  # More restrictive for token file
    
    print_success "Configuration created at $CONFIG_DIR/config.yaml"
    print_success "Environment file created at $CONFIG_DIR/agent.env"
}

# Function to create systemd service
create_service() {
    print_status "Creating systemd service..."
    
    # Create service file
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=NodifyMe Monitoring Agent
Documentation=https://github.com/gsmarketing/nodifymeapp
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
EnvironmentFile=$CONFIG_DIR/agent.env
ExecStart=$INSTALL_DIR/nodifyme-agent --config $CONFIG_DIR/config.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nodifyme-agent

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $DATA_DIR
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
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd service created"
}

# Function to create logrotate configuration
create_logrotate() {
    print_status "Creating logrotate configuration..."
    
    cat > "/etc/logrotate.d/$SERVICE_NAME" <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $USER_NAME $GROUP_NAME
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF
    
    print_success "Logrotate configuration created"
}

# Function to enable and start service
start_service() {
    print_status "Starting NodifyMe agent service..."
    
    # Enable service
    systemctl enable "$SERVICE_NAME"
    
    # Start service
    if systemctl start "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check if binary exists
    if [[ ! -f "$INSTALL_DIR/nodifyme-agent" ]]; then
        print_error "Agent binary not found"
        exit 1
    fi
    
    # Check if service is running
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        print_error "Service is not running"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
    
    # Check if service is enabled
    if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_error "Service is not enabled"
        exit 1
    fi
    
    print_success "Installation verified successfully"
}

# Function to display post-installation information
post_install_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  NodifyMe Agent Installation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "Service Name: ${BLUE}$SERVICE_NAME${NC}"
    echo -e "Binary Location: ${BLUE}$INSTALL_DIR/nodifyme-agent${NC}"
    echo -e "Configuration: ${BLUE}$CONFIG_DIR/config.yaml${NC}"
    echo -e "Log Directory: ${BLUE}$LOG_DIR${NC}"
    echo -e "Data Directory: ${BLUE}$DATA_DIR${NC}"
    echo
    echo -e "Useful Commands:"
    echo -e "  Check Status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "  View Logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "  Stop: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
    echo
    echo -e "Next Steps:"
    echo -e "1. Configure the agent by editing ${BLUE}$CONFIG_DIR/config.yaml${NC}"
    echo -e "2. Set your API URL and token in the configuration"
    echo -e "3. Restart the service: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo
}

# Function to handle cleanup
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Main installation function
main() {
    print_status "Starting NodifyMe agent installation..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check if running as root
    check_root
    
    # Validate required parameters
    validate_parameters
    
    # Detect system
    detect_system
    
    # Download agent
    download_agent
    
    # Install agent
    install_agent
    
    # Create user
    create_user
    
    # Create directories
    create_directories
    
    # Create configuration
    create_config
    
    # Create service
    create_service
    
    # Create logrotate
    create_logrotate
    
    # Start service
    start_service
    
    # Verify installation
    verify_installation
    
    # Display post-installation information
    post_install_info
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            AGENT_VERSION="$2"
            shift 2
            ;;
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        --token)
            AGENT_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --version VERSION    Specify agent version (default: latest)"
            echo "  --api-url URL        Set API URL (required)"
            echo "  --token TOKEN        Set agent token (required, min 16 chars)"
            echo "  --help               Show this help message"
            echo
            echo "Environment Variables:"
            echo "  AGENT_VERSION        Agent version to install"
            echo "  API_URL              API URL for the agent"
            echo "  AGENT_TOKEN          Authentication token (required)"
            echo
            echo "Example:"
            echo "  sudo $0 --api-url https://app.nodifyme.com --token eyJ0eXAiOiJKV1Q..."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main installation
main "$@" 