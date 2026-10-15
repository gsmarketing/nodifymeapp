#!/bin/bash
# Generated on each release; local edits to a published copy are overwritten.

# Nodify.Me Agent Installation Script
# This script installs the Nodify.Me monitoring agent on Linux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGENT_VERSION="v0.1.10"
API_URL="${API_URL:-}"
AGENT_TOKEN="${AGENT_TOKEN:-}"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="nodifyme-agent"
USER_NAME="nodifyme"
GROUP_NAME="nodifyme"
CONFIG_DIR="/etc/nodifyme"
LOG_DIR="/var/log/nodifyme"
DATA_DIR="/var/lib/nodifyme"
HELPER_DIR="/usr/local/lib/nodifyme"

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
    print_status "Downloading Nodify.Me agent..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download URLs (binary, checksums and signature come from the same release)
    if [[ "$AGENT_VERSION" == "latest" ]]; then
        RELEASE_URL="https://github.com/gsmarketing/nodifymeapp/releases/latest/download"
    else
        RELEASE_URL="https://github.com/gsmarketing/nodifymeapp/releases/download/$AGENT_VERSION"
    fi
    BINARY_NAME="nodifyme-agent-linux-$ARCH"
    
    # -f: fail on HTTP errors instead of saving an error page
    if ! curl -fsSL -o nodifyme-agent "$RELEASE_URL/$BINARY_NAME"; then
        print_error "Failed to download agent binary"
        exit 1
    fi
    
    verify_binary
    
    if ! chmod +x nodifyme-agent; then
        print_error "Failed to make binary executable"
        exit 1
    fi
    
    # Confirm it's a Linux executable. Read the ELF magic bytes directly: the
    # `file` command is not installed on minimal server images.
    if ! head -c 4 nodifyme-agent | grep -q $'\x7fELF'; then
        print_error "Downloaded binary is not a valid ELF executable"
        exit 1
    fi
    
    print_success "Agent binary downloaded and verified"
}

# Verify SHA256 (checksums.txt) and RSA signature (.sig) before anything runs.
# Fails closed: any missing file, missing tool or mismatch aborts the install.
verify_binary() {
    print_status "Verifying binary checksum and signature..."
    
    for tool in sha256sum openssl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "$tool is required to verify the agent binary"
            exit 1
        fi
    done
    
    if ! curl -fsSL -o checksums.txt "$RELEASE_URL/checksums.txt" || \
       ! curl -fsSL -o nodifyme-agent.sig "$RELEASE_URL/$BINARY_NAME.sig" || \
       ! curl -fsSL -o build-public-key.pem "https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/build-public-key.pem"; then
        print_error "Could not download verification files; refusing to install"
        exit 1
    fi
    
    local expected actual
    expected=$(awk -v f="$BINARY_NAME" '$2 == f || $2 == "*"f {print $1}' checksums.txt)
    actual=$(sha256sum nodifyme-agent | cut -d' ' -f1)
    if [[ -z "$expected" || "$expected" != "$actual" ]]; then
        print_error "Checksum mismatch for $BINARY_NAME; refusing to install"
        exit 1
    fi
    
    if ! openssl dgst -sha256 -verify build-public-key.pem -signature nodifyme-agent.sig nodifyme-agent >/dev/null 2>&1; then
        print_error "Signature verification failed; refusing to install"
        exit 1
    fi
    
    # build-public-key.pem stays in TEMP_DIR: create_update_helper installs it root-owned
    rm -f checksums.txt nodifyme-agent.sig
    print_success "Checksum and signature verified"
}

# Function to install agent
install_agent() {
    print_status "Installing agent to $INSTALL_DIR..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Stop a running agent and unlink the old binary first
    # (copying over a running binary fails with "Text file busy")
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    # The root helper is the same binary: stop it too, so no old code keeps serving
    systemctl stop nodifyme-helper.service 2>/dev/null || true
    rm -f "$INSTALL_DIR/nodifyme-agent" 2>/dev/null || true
    
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

# Function to create agent environment file
create_config() {
    print_status "Creating agent environment..."

    # agent.env is the single source of truth for agent runtime settings.
    # Agent behavior (poll intervals, etc.) is controlled by the API via heartbeat
    # responses — not by local config files. This keeps all agents in sync with
    # the platform without requiring SSH access when settings change.
    cat > "$CONFIG_DIR/agent.env" <<EOF
# Nodify.Me Agent Environment
# Do not edit manually — agent behavior is controlled by the platform API.

# API endpoint this agent reports to
API_URL=${API_URL:-http://localhost:3001}

# Agent authentication token (issued by the platform on server registration)
AGENT_AUTH_TOKEN=${AGENT_TOKEN:-}
EOF

    chown "$USER_NAME:$GROUP_NAME" "$CONFIG_DIR/agent.env"
    chmod 600 "$CONFIG_DIR/agent.env"

    print_success "Agent environment created at $CONFIG_DIR/agent.env"
}

# Function to create systemd service
create_service() {
    print_status "Creating systemd service..."
    
    # Create service file
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=Nodify.Me Monitoring Agent
Documentation=https://github.com/gsmarketing/nodifymeapp
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
EnvironmentFile=$CONFIG_DIR/agent.env
ExecStart=$INSTALL_DIR/nodifyme-agent
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

# Self-update without sudo: the agent (unprivileged, NoNewPrivileges) only stages a
# binary + signature in $DATA_DIR. A root path unit picks it up, re-verifies the
# signature against a root-owned key, swaps the binary and restarts the agent.
create_update_helper() {
    print_status "Installing self-update helper..."

    mkdir -p "$HELPER_DIR"
    chown root:root "$HELPER_DIR"
    chmod 755 "$HELPER_DIR"

    install -o root -g root -m 644 "$TEMP_DIR/build-public-key.pem" "$HELPER_DIR/build-public-key.pem"

    cat > "$HELPER_DIR/apply-update.sh" <<'EOF'
#!/bin/bash
# Nodify.Me agent update helper. Runs as root from nodifyme-agent-update.service.
# Treats the staged files as untrusted: they are written by the agent user.
set -euo pipefail

STAGED=/var/lib/nodifyme/pending-update
STAGED_SIG=/var/lib/nodifyme/pending-update.sig
PUBKEY=/usr/local/lib/nodifyme/build-public-key.pem
TARGET=/usr/local/bin/nodifyme-agent
PREVIOUS=/usr/local/lib/nodifyme/nodifyme-agent.prev
SERVICE=nodifyme-agent

log() { echo "agent-update: $*"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Copy into a root-only directory before checking anything, then remove the staged
# files so the path unit doesn't retrigger and the agent can't swap them mid-check.
for f in "$STAGED" "$STAGED_SIG"; do
    if [[ -L "$f" || ! -f "$f" ]]; then
        log "rejecting $f: missing, not a regular file, or a symlink"
        rm -f "$STAGED" "$STAGED_SIG"
        exit 1
    fi
done
cp "$STAGED" "$WORK/agent"
cp "$STAGED_SIG" "$WORK/agent.sig"
rm -f "$STAGED" "$STAGED_SIG"

if ! openssl dgst -sha256 -verify "$PUBKEY" -signature "$WORK/agent.sig" "$WORK/agent" >/dev/null 2>&1; then
    log "signature verification failed; update refused"
    exit 1
fi
if ! head -c 4 "$WORK/agent" | grep -q $'\x7fELF'; then
    log "staged file is not an ELF executable; update refused"
    exit 1
fi

# Keep the current binary for rollback, then swap atomically (no "Text file busy").
cp -p "$TARGET" "$PREVIOUS"
install -o root -g root -m 755 "$WORK/agent" "$TARGET.new"
mv -f "$TARGET.new" "$TARGET"
# The root helper is the same binary: stop it so the next request starts the new one
systemctl stop nodifyme-helper.service 2>/dev/null || true
systemctl restart "$SERVICE"

sleep 10
if systemctl is-active --quiet "$SERVICE"; then
    log "update applied; $SERVICE is running"
    exit 0
fi

log "new binary did not stay up; rolling back"
install -o root -g root -m 755 "$PREVIOUS" "$TARGET.new"
mv -f "$TARGET.new" "$TARGET"
systemctl stop nodifyme-helper.service 2>/dev/null || true
systemctl restart "$SERVICE"
exit 1
EOF
    chown root:root "$HELPER_DIR/apply-update.sh"
    chmod 755 "$HELPER_DIR/apply-update.sh"

    cat > "/etc/systemd/system/$SERVICE_NAME-update.service" <<EOF
[Unit]
Description=Nodify.Me Agent Update (applies a staged, signed binary)

[Service]
Type=oneshot
ExecStart=$HELPER_DIR/apply-update.sh
PrivateTmp=true
NoNewPrivileges=true
ProtectHome=true
EOF

    cat > "/etc/systemd/system/$SERVICE_NAME-update.path" <<EOF
[Unit]
Description=Watch for a staged Nodify.Me agent update

[Path]
PathExists=$DATA_DIR/pending-update
Unit=$SERVICE_NAME-update.service

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME-update.path"

    print_success "Self-update helper installed"
}

# Privileged helper: the root half of the privilege split. The agent stays
# unprivileged (NoNewPrivileges, ProtectSystem=strict); for managed actions it asks
# `nodifyme-agent helper` over a unix socket. systemd owns the socket and starts the
# helper only when the agent connects; the helper exits after a minute idle. It
# accepts only the agent user (checked by the kernel via SO_PEERCRED) and runs only
# fixed, compiled-in actions. It is the same signed binary as the agent, so updates
# cover both (see AGENT-OPERATIONS.md, Managed Action Privilege Model).
create_helper() {
    print_status "Installing privileged helper (socket-activated)..."

    cat > "/etc/systemd/system/nodifyme-helper.socket" <<EOF
[Unit]
Description=Nodify.Me privileged helper socket

[Socket]
ListenStream=/run/nodifyme/helper.sock
SocketMode=0660
SocketUser=root
SocketGroup=$GROUP_NAME
DirectoryMode=0755
RemoveOnStop=true

[Install]
WantedBy=sockets.target
EOF

    cat > "/etc/systemd/system/nodifyme-helper.service" <<EOF
[Unit]
Description=Nodify.Me privileged helper (root; started on demand, exits when idle)
Requires=nodifyme-helper.socket
After=nodifyme-helper.socket

[Service]
Type=simple
# No User= line on purpose: the service runs as root by default, and naming root
# explicitly makes systemd drop CAP_SETUID when hardening is on, which breaks
# apt (it cannot switch to its _apt sandbox user).
Environment=NODIFYME_AGENT_USER=$USER_NAME
ExecStart=$INSTALL_DIR/nodifyme-agent helper
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nodifyme-helper

# Hardening that fits any action. Filesystem protections (ProtectSystem and
# friends) are decided per real action once those exist.
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictRealtime=true
EOF

    systemctl daemon-reload
    systemctl enable --now nodifyme-helper.socket

    print_success "Privileged helper socket installed"
}

# Older onboarding left a permanent SSH login on the server: a `nodifyme-api` user
# whose key the platform kept. Nodify.Me no longer uses SSH after the install (the
# agent connects out instead), so remove that login if it exists.
remove_legacy_ssh_access() {
    if id nodifyme-api &>/dev/null; then
        print_status "Removing the legacy nodifyme-api SSH login..."
        pkill -u nodifyme-api 2>/dev/null || true
        userdel -r nodifyme-api 2>/dev/null || true
        rm -rf /opt/nodifyme 2>/dev/null || true
        print_success "Legacy SSH login removed"
    fi
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
    print_status "Starting Nodify.Me agent service..."
    
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
    
    # Check the privileged helper answers the agent user. Not fatal: monitoring
    # works without it, but managed actions (install, deploy) will not.
    if runuser -u "$USER_NAME" -- "$INSTALL_DIR/nodifyme-agent" helper-check >/dev/null 2>&1; then
        print_success "Privileged helper verified"
    else
        print_warning "Privileged helper did not answer; managed actions will be unavailable."
        print_warning "Check: systemctl status nodifyme-helper.socket; journalctl -u nodifyme-helper"
    fi

    print_success "Installation verified successfully"
}

# Function to display post-installation information
post_install_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Nodify.Me Agent Installation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "Service Name: ${BLUE}$SERVICE_NAME${NC}"
    echo -e "Binary Location: ${BLUE}$INSTALL_DIR/nodifyme-agent${NC}"
    echo -e "Environment: ${BLUE}$CONFIG_DIR/agent.env${NC}"
    echo -e "Log Directory: ${BLUE}$LOG_DIR${NC}"
    echo -e "Data Directory: ${BLUE}$DATA_DIR${NC}"
    echo
    echo -e "Useful Commands:"
    echo -e "  Check Status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "  View Logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo -e "  Stop: ${YELLOW}systemctl stop $SERVICE_NAME${NC}"
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
    print_status "Starting Nodify.Me agent installation..."
    
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

    # Install the root-side self-update helper
    create_update_helper

    create_helper

    remove_legacy_ssh_access

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
            AGENT_VERSION="v0.1.10"
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