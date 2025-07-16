#!/bin/bash

# NodifyMe Agent Uninstallation Script
# This script completely removes the NodifyMe monitoring agent from Linux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="nodifyme-agent"
USER_NAME="nodifyme"
GROUP_NAME="nodifyme"
INSTALL_DIR="/usr/local/bin"
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

# Function to confirm uninstallation
confirm_uninstall() {
    echo -e "${YELLOW}This will completely remove the NodifyMe agent from your system.${NC}"
    echo -e "${YELLOW}This action cannot be undone.${NC}"
    echo
    echo -e "The following will be removed:"
    echo -e "  - Binary: ${BLUE}$INSTALL_DIR/nodifyme-agent${NC}"
    echo -e "  - Service: ${BLUE}$SERVICE_NAME${NC}"
    echo -e "  - Configuration: ${BLUE}$CONFIG_DIR${NC}"
    echo -e "  - Logs: ${BLUE}$LOG_DIR${NC}"
    echo -e "  - Data: ${BLUE}$DATA_DIR${NC}"
    echo -e "  - User: ${BLUE}$USER_NAME${NC}"
    echo -e "  - Group: ${BLUE}$GROUP_NAME${NC}"
    echo
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Uninstallation cancelled"
        exit 0
    fi
}

# Function to stop and disable service
stop_service() {
    print_status "Stopping and disabling service..."
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        systemctl disable "$SERVICE_NAME"
        print_success "Service disabled"
    else
        print_warning "Service was not enabled"
    fi
}

# Function to remove systemd service
remove_service() {
    print_status "Removing systemd service..."
    
    # Remove service file
    if [[ -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        print_success "Service file removed"
    else
        print_warning "Service file not found"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd reloaded"
}

# Function to remove binary
remove_binary() {
    print_status "Removing agent binary..."
    
    if [[ -f "$INSTALL_DIR/nodifyme-agent" ]]; then
        rm -f "$INSTALL_DIR/nodifyme-agent"
        print_success "Binary removed"
    else
        print_warning "Binary not found"
    fi
}

# Function to remove configuration
remove_config() {
    print_status "Removing configuration..."
    
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        print_success "Configuration directory removed"
    else
        print_warning "Configuration directory not found"
    fi
}

# Function to remove logs
remove_logs() {
    print_status "Removing logs..."
    
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        print_success "Log directory removed"
    else
        print_warning "Log directory not found"
    fi
}

# Function to remove data
remove_data() {
    print_status "Removing data..."
    
    if [[ -d "$DATA_DIR" ]]; then
        rm -rf "$DATA_DIR"
        print_success "Data directory removed"
    else
        print_warning "Data directory not found"
    fi
}

# Function to remove logrotate configuration
remove_logrotate() {
    print_status "Removing logrotate configuration..."
    
    if [[ -f "/etc/logrotate.d/$SERVICE_NAME" ]]; then
        rm -f "/etc/logrotate.d/$SERVICE_NAME"
        print_success "Logrotate configuration removed"
    else
        print_warning "Logrotate configuration not found"
    fi
}

# Function to remove user and group
remove_user() {
    print_status "Removing system user and group..."
    
    # Remove user if exists
    if id "$USER_NAME" &>/dev/null; then
        userdel "$USER_NAME" 2>/dev/null || true
        print_success "User $USER_NAME removed"
    else
        print_warning "User $USER_NAME not found"
    fi
    
    # Remove group if exists and empty
    if getent group "$GROUP_NAME" &>/dev/null; then
        groupdel "$GROUP_NAME" 2>/dev/null || true
        print_success "Group $GROUP_NAME removed"
    else
        print_warning "Group $GROUP_NAME not found"
    fi
}

# Function to clean up package manager files (if applicable)
cleanup_package_manager() {
    print_status "Cleaning up package manager files..."
    
    # Remove repository files if they exist
    if [[ -f "/etc/apt/sources.list.d/nodifyme.list" ]]; then
        rm -f "/etc/apt/sources.list.d/nodifyme.list"
        print_success "Repository file removed"
    fi
    
    if [[ -f "/etc/apt/sources.list.d/nodifyme-packages.list" ]]; then
        rm -f "/etc/apt/sources.list.d/nodifyme-packages.list"
        print_success "Repository file removed"
    fi
    
    # Remove GPG keys if they exist
    if [[ -f "/usr/share/keyrings/nodifyme-archive-keyring.gpg" ]]; then
        rm -f "/usr/share/keyrings/nodifyme-archive-keyring.gpg"
        print_success "GPG key removed"
    fi
    
    if [[ -f "/usr/share/keyrings/nodifyme-packages.gpg" ]]; then
        rm -f "/usr/share/keyrings/nodifyme-packages.gpg"
        print_success "GPG key removed"
    fi
    
    # Update package list if apt is available
    if command -v apt &>/dev/null; then
        apt update &>/dev/null || true
        print_success "Package list updated"
    fi
}

# Function to verify removal
verify_removal() {
    print_status "Verifying removal..."
    
    local errors=0
    
    # Check if binary still exists
    if [[ -f "$INSTALL_DIR/nodifyme-agent" ]]; then
        print_error "Binary still exists at $INSTALL_DIR/nodifyme-agent"
        ((errors++))
    fi
    
    # Check if service still exists
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        print_error "Service still exists: $SERVICE_NAME"
        ((errors++))
    fi
    
    # Check if user still exists
    if id "$USER_NAME" &>/dev/null; then
        print_error "User still exists: $USER_NAME"
        ((errors++))
    fi
    
    # Check if directories still exist
    if [[ -d "$CONFIG_DIR" ]]; then
        print_error "Configuration directory still exists: $CONFIG_DIR"
        ((errors++))
    fi
    
    if [[ -d "$LOG_DIR" ]]; then
        print_error "Log directory still exists: $LOG_DIR"
        ((errors++))
    fi
    
    if [[ -d "$DATA_DIR" ]]; then
        print_error "Data directory still exists: $DATA_DIR"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "Removal verified successfully"
    else
        print_error "Removal verification failed with $errors errors"
        exit 1
    fi
}

# Function to display completion message
completion_message() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  NodifyMe Agent Uninstallation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "The NodifyMe agent has been completely removed from your system."
    echo
    echo -e "If you want to reinstall the agent in the future, you can:"
    echo -e "1. Download the installation script from the repository"
    echo -e "2. Run: ${YELLOW}sudo bash install.sh${NC}"
    echo
}

# Function to handle cleanup on exit
cleanup() {
    # This function can be used for any cleanup needed on script exit
    :
}

# Main uninstallation function
main() {
    print_status "Starting NodifyMe agent uninstallation..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check if running as root
    check_root
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Stop and disable service
    stop_service
    
    # Remove systemd service
    remove_service
    
    # Remove binary
    remove_binary
    
    # Remove configuration
    remove_config
    
    # Remove logs
    remove_logs
    
    # Remove data
    remove_data
    
    # Remove logrotate configuration
    remove_logrotate
    
    # Remove user and group
    remove_user
    
    # Clean up package manager files
    cleanup_package_manager
    
    # Verify removal
    verify_removal
    
    # Display completion message
    completion_message
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            # Skip confirmation
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --force    Skip confirmation prompt"
            echo "  --help     Show this help message"
            echo
            echo "This script will completely remove the NodifyMe agent from your system."
            echo "Use with caution as this action cannot be undone."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Override confirmation if --force is used
if [[ "$FORCE" == "true" ]]; then
    confirm_uninstall() {
        print_status "Force mode enabled, skipping confirmation"
    }
fi

# Run main uninstallation
main "$@" 