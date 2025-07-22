#!/bin/bash

# Nodify.Me Agent Update Script
# Updates an existing agent installation to the latest version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGENT_VERSION="${AGENT_VERSION:-latest}"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="nodifyme-agent"
USER_NAME="nodifyme"
GROUP_NAME="nodifyme"
CONFIG_DIR="/etc/nodifyme"
BACKUP_DIR="/var/backups/nodifyme"

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

# Function to detect architecture
detect_arch() {
    print_status "Detecting system architecture..."
    
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
    
    print_success "Detected architecture: $ARCH"
}

# Function to check current installation
check_current_installation() {
    print_status "Checking current installation..."
    
    # Check if agent binary exists
    if [[ ! -f "$INSTALL_DIR/nodifyme-agent" ]]; then
        print_error "Nodify.Me agent is not installed at $INSTALL_DIR/nodifyme-agent"
        print_error "Use the install script for new installations"
        exit 1
    fi
    
    # Check if service exists
    if ! systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
        print_error "Nodify.Me agent service is not installed"
        exit 1
    fi
    
    # Get current version
    if command -v "$INSTALL_DIR/nodifyme-agent" &> /dev/null; then
        CURRENT_VERSION=$("$INSTALL_DIR/nodifyme-agent" --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    else
        CURRENT_VERSION="unknown"
    fi
    
    print_success "Current installation found (version: $CURRENT_VERSION)"
}

# Function to create backup
create_backup() {
    print_status "Creating backup of current installation..."
    
    # Create backup directory
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CURRENT_BACKUP_DIR="$BACKUP_DIR/$BACKUP_TIMESTAMP"
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Backup binary
    if [[ -f "$INSTALL_DIR/nodifyme-agent" ]]; then
        cp "$INSTALL_DIR/nodifyme-agent" "$CURRENT_BACKUP_DIR/"
        print_success "Binary backed up"
    fi
    
    # Backup configuration
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$CURRENT_BACKUP_DIR/"
        print_success "Configuration backed up"
    fi
    
    # Save service status
    systemctl status "$SERVICE_NAME" > "$CURRENT_BACKUP_DIR/service_status.txt" 2>&1 || true
    
    print_success "Backup created at $CURRENT_BACKUP_DIR"
}

# Function to stop service
stop_service() {
    print_status "Stopping Nodify.Me agent service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
}

# Function to download new agent
download_new_agent() {
    print_status "Downloading new agent version..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download URL
    if [[ "$AGENT_VERSION" == "latest" ]]; then
        DOWNLOAD_URL="https://github.com/gsmarketing/nodifymeapp/releases/latest/download/nodifyme-agent-linux-$ARCH"
    else
        DOWNLOAD_URL="https://github.com/gsmarketing/nodifymeapp/releases/download/$AGENT_VERSION/nodifyme-agent-linux-$ARCH"
    fi
    
    print_status "Downloading from: $DOWNLOAD_URL"
    
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
    
    # Get new version
    NEW_VERSION=$(./nodifyme-agent --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    
    print_success "New agent downloaded (version: $NEW_VERSION)"
}

# Function to install new binary
install_new_binary() {
    print_status "Installing new binary..."
    
    # Replace binary
    cp nodifyme-agent "$INSTALL_DIR/"
    chmod 755 "$INSTALL_DIR/nodifyme-agent"
    
    # Ensure correct ownership
    chown root:root "$INSTALL_DIR/nodifyme-agent"
    
    print_success "New binary installed"
}

# Function to start service
start_service() {
    print_status "Starting Nodify.Me agent service..."
    
    # Start service
    if systemctl start "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        print_error "Check logs: journalctl -u $SERVICE_NAME"
        exit 1
    fi
    
    # Verify service is running
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service is running and healthy"
    else
        print_error "Service started but is not healthy"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
}

# Function to verify update
verify_update() {
    print_status "Verifying update..."
    
    # Check binary version
    INSTALLED_VERSION=$("$INSTALL_DIR/nodifyme-agent" --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    
    if [[ "$INSTALLED_VERSION" != "$NEW_VERSION" ]]; then
        print_error "Version mismatch after update"
        print_error "Expected: $NEW_VERSION, Got: $INSTALLED_VERSION"
        exit 1
    fi
    
    # Check service status
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        print_error "Service is not running after update"
        exit 1
    fi
    
    print_success "Update verified successfully"
}

# Function to cleanup
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Function to display post-update information
post_update_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    Nodify.Me Agent Update Complete    ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "Previous Version: ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e "Current Version: ${BLUE}$NEW_VERSION${NC}"
    echo -e "Backup Location: ${BLUE}$CURRENT_BACKUP_DIR${NC}"
    echo
    echo -e "Service Status:"
    systemctl status "$SERVICE_NAME" --no-pager --lines=3
    echo
    echo -e "Useful Commands:"
    echo -e "  Check Status: ${YELLOW}systemctl status $SERVICE_NAME${NC}"
    echo -e "  View Logs: ${YELLOW}journalctl -u $SERVICE_NAME -f${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart $SERVICE_NAME${NC}"
    echo
    if [[ -d "$CURRENT_BACKUP_DIR" ]]; then
        echo -e "To rollback if needed:"
        echo -e "  ${YELLOW}sudo systemctl stop $SERVICE_NAME${NC}"
        echo -e "  ${YELLOW}sudo cp $CURRENT_BACKUP_DIR/nodifyme-agent $INSTALL_DIR/${NC}"
        echo -e "  ${YELLOW}sudo systemctl start $SERVICE_NAME${NC}"
        echo
    fi
}

# Main update function
main() {
    print_status "Starting Nodify.Me agent update..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check if running as root
    check_root
    
    # Detect architecture
    detect_arch
    
    # Check current installation
    check_current_installation
    
    # Create backup
    create_backup
    
    # Stop service
    stop_service
    
    # Download new agent
    download_new_agent
    
    # Install new binary
    install_new_binary
    
    # Start service
    start_service
    
    # Verify update
    verify_update
    
    # Display post-update information
    post_update_info
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            AGENT_VERSION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --version VERSION    Specify agent version (default: latest)"
            echo "  --help               Show this help message"
            echo
            echo "Environment Variables:"
            echo "  AGENT_VERSION        Agent version to install"
            echo
            echo "Example:"
            echo "  sudo $0                    # Update to latest"
            echo "  sudo $0 --version v1.2.0  # Update to specific version"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main update
main "$@"