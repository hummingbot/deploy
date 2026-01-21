#!/bin/bash
#
# Hummingbot Deploy Instance Installer
#
# This script sets up Hummingbot instances with optional Hummingbot API integration.
# Each repository manages its own docker-compose and setup via Makefile.
set -eu
# --- Configuration ---
CONDOR_REPO="https://github.com/hummingbot/condor.git"
API_REPO="https://github.com/hummingbot/hummingbot-api.git"
CONDOR_DIR="condor"
API_DIR="hummingbot-api"
DOCKER_COMPOSE=""  # Will be set by detect_docker_compose()
# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
# --- Track directories we create for cleanup ---
CREATED_DIRS=()
# --- Cleanup trap ---
cleanup() {
    local exit_code=$?
    # Remove any partial downloads
    rm -f get-docker.sh 2>/dev/null || true
    
    # If we're exiting with an error, remove partial git clones we created
    if [ $exit_code -ne 0 ]; then
        for dir in "${CREATED_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                msg_warn "Cleaning up partial installation: $dir"
                rm -rf "$dir" 2>/dev/null || true
            fi
        done
    fi
}
trap cleanup EXIT
# --- Helper Functions ---
msg_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}
msg_ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}
msg_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" >&2
}
msg_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}
prompt() {
    echo -en "${PURPLE}$1${NC}" > /dev/tty
}
prompt_visible() {
    prompt "$1"
    read -r val < /dev/tty || val=""
    echo "$val"
}
prompt_default() {
    prompt "$1 [$2]: "
    read -r val < /dev/tty || val=""
    echo "${val:-$2}"
}
prompt_yesno() {
    while true; do
        prompt "$1 (y/n): "
        read -r val < /dev/tty || val=""
        case "$val" in
            [Yy]) echo "y"; return ;;
            [Nn]) echo "n"; return ;;
            *) msg_warn "Please answer 'y' or 'n'" ;;
        esac
    done
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
# Check if running in interactive mode
is_interactive() {
    # Check if stdin (fd 0) and stdout (fd 1) are terminals
    # Also ensure we have a proper TERM set
    if [[ -t 0 ]] && [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
        return 0
    fi
    
    # Additional check: if /dev/tty is available and writable, we can still be interactive
    if [[ -c /dev/tty ]] && [[ -w /dev/tty ]]; then
        return 0
    fi
    
    return 1
}
# Check if running inside a container
is_container() {
    [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null || grep -q containerd /proc/1/cgroup 2>/dev/null
}
# --- Parse Command Line Arguments ---
UPGRADE_MODE="n"
API_ONLY_MODE="n"
while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade)
            UPGRADE_MODE="y"
            shift
            ;;
        --api)
            API_ONLY_MODE="y"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upgrade           Upgrade existing installation"
            echo "  --api               Install only Hummingbot API (standalone)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  Fresh installation (Condor + optional API)"
            echo "  $0 --upgrade        Upgrade existing installations"
            echo "  $0 --api            Install only Hummingbot API"
            exit 0
            ;;
        *)
            msg_error "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done
# --- Installation and Setup Functions ---
detect_os_arch() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7*|armv8*) ARCH="arm" ;;
        armv*) ARCH="arm" ;;
        *) msg_warn "Unknown architecture: $ARCH, defaulting to amd64"; ARCH="amd64" ;;
    esac
    msg_info "Detected OS: $OS, Architecture: $ARCH"
    
    # Detect Homebrew location for Apple Silicon
    if [[ "$OS" == "darwin" ]]; then
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}
detect_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
        msg_info "Using Docker Compose plugin"
    elif command_exists docker-compose; then
        DOCKER_COMPOSE="docker-compose"
        msg_info "Using standalone docker-compose"
    else
        msg_error "Neither docker-compose nor docker compose plugin found"
        exit 1
    fi
}
check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        if [[ "$OS" == "darwin" ]]; then
            msg_error "Docker Desktop is not running."
            msg_info "Please start Docker Desktop and try again."
        else
            msg_error "Docker daemon is not running."
            msg_info "Please start Docker and try again."
            if command_exists systemctl; then
                msg_info "Try: sudo systemctl start docker"
            elif command_exists service; then
                msg_info "Try: sudo service docker start"
            fi
        fi
        exit 1
    fi
    msg_ok "Docker daemon is running"
}
check_disk_space() {
    local required_mb=2048  # 2GB minimum
    local available_mb
    
    if [[ "$OS" == "linux" ]]; then
        available_mb=$(df -m . 2>/dev/null | tail -1 | awk '{print $4}')
    elif [[ "$OS" == "darwin" ]]; then
        available_mb=$(df -m . 2>/dev/null | tail -1 | awk '{print $4}')
    else
        # Skip check on unknown OS
        return
    fi
    
    if [[ -n "$available_mb" ]] && [[ $available_mb -lt $required_mb ]]; then
        msg_error "Insufficient disk space. Need ${required_mb}MB, have ${available_mb}MB"
        exit 1
    fi
    msg_ok "Sufficient disk space available (${available_mb}MB)"
}
install_dependencies() {
    msg_info "Checking for dependencies..."
    
    MISSING_DEPS=()
    
    if ! command_exists git; then
        MISSING_DEPS+=("git")
    fi
    if ! command_exists curl; then
        MISSING_DEPS+=("curl")
    fi
    if ! command_exists docker; then
        MISSING_DEPS+=("docker")
    fi
    
    # Check for docker-compose (either standalone or as docker compose plugin)
    if ! (command_exists docker-compose || (command_exists docker && docker compose version >/dev/null 2>&1)); then
        MISSING_DEPS+=("docker-compose")
    fi
    
    if ! command_exists make; then
        MISSING_DEPS+=("make")
    fi
    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        msg_ok "All dependencies (git, curl, docker, docker-compose, make) are already installed."
        return
    fi
    
    msg_warn "The following dependencies are missing: ${MISSING_DEPS[*]}"
    
    # Only attempt auto-install on Linux
    if [[ "$OS" != "linux" ]]; then
        msg_error "Please install missing dependencies manually:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  - $dep"
        done
        if [[ "$OS" == "darwin" ]]; then
            msg_info "On macOS, consider using Homebrew: https://brew.sh"
        fi
        exit 1
    fi
    
    # Check if running in non-interactive mode
    if ! is_interactive; then
        msg_error "Running in non-interactive mode. Please install the missing dependencies manually."
        exit 1
    fi
    
    # Check for root/sudo
    if [[ $EUID -ne 0 ]]; then
        if ! command_exists sudo; then
            msg_error "Missing dependencies require root/sudo privileges."
            msg_info "Please run this script with sudo or install the missing dependencies manually."
            exit 1
        fi
        SUDO_CMD="sudo"
    else
        SUDO_CMD=""
    fi
    
    echo ""
    msg_warn "Some dependencies are missing and need to be installed."
    INSTALL_DEPS=$(prompt_yesno "Would you like to install them automatically?")
    
    if [ "$INSTALL_DEPS" != "y" ]; then
        msg_error "Installation cannot proceed without required dependencies."
        exit 1
    fi
    
    msg_info "Installing dependencies..."
    
    # Detect package manager
    if command_exists apt-get; then
        PKG_MANAGER="apt-get"
        UPDATE_CMD="$SUDO_CMD apt-get update"
        INSTALL_CMD="$SUDO_CMD apt-get install -y"
    elif command_exists yum; then
        PKG_MANAGER="yum"
        UPDATE_CMD="$SUDO_CMD yum check-update || true"
        INSTALL_CMD="$SUDO_CMD yum install -y"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="$SUDO_CMD dnf check-update || true"
        INSTALL_CMD="$SUDO_CMD dnf install -y"
    elif command_exists apk; then
        PKG_MANAGER="apk"
        UPDATE_CMD="$SUDO_CMD apk update"
        INSTALL_CMD="$SUDO_CMD apk add"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
        UPDATE_CMD="$SUDO_CMD pacman -Sy"
        INSTALL_CMD="$SUDO_CMD pacman -S --noconfirm"
    else
        msg_error "Could not detect a supported package manager (apt-get, yum, dnf, apk, pacman)."
        msg_info "Please install the following packages manually: ${MISSING_DEPS[*]}"
        exit 1
    fi
    
    msg_info "Updating package lists..."
    if ! eval "$UPDATE_CMD"; then
        msg_warn "Failed to update package lists, continuing anyway..."
    fi
    
    for dep in "${MISSING_DEPS[@]}"; do
        case $dep in
            docker)
                msg_info "Installing Docker..."
                if command_exists curl; then
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    if ! $SUDO_CMD sh get-docker.sh; then
                        msg_error "Failed to install Docker via get.docker.com"
                        exit 1
                    fi
                    rm -f get-docker.sh
                    
                    # Add current user to docker group (non-root only)
                    if [[ $EUID -ne 0 ]] && command_exists usermod; then
                        $SUDO_CMD usermod -aG docker "$USER" || true
                        msg_info "Added $USER to docker group. You may need to log out and back in for this to take effect."
                    fi
                else
                    msg_error "curl is required to install Docker automatically"
                    exit 1
                fi
                ;;
            docker-compose)
                msg_info "Installing docker-compose..."
                # Try to install docker compose plugin first
                if [[ "$PKG_MANAGER" == "apt-get" ]]; then
                    if ! eval "$INSTALL_CMD docker-compose-plugin"; then
                        msg_warn "Failed to install docker-compose-plugin, trying standalone..."
                        eval "$INSTALL_CMD docker-compose" || {
                            msg_error "Failed to install docker-compose"
                            exit 1
                        }
                    fi
                else
                    # For other package managers, try standalone docker-compose
                    eval "$INSTALL_CMD docker-compose" || {
                        msg_error "Failed to install docker-compose"
                        exit 1
                    }
                fi
                ;;
            *)
                msg_info "Installing $dep..."
                if ! eval "$INSTALL_CMD $dep"; then
                    msg_error "Failed to install $dep"
                    exit 1
                fi
                ;;
        esac
    done
    
    msg_ok "All dependencies installed successfully!"
    
    # Start Docker if it was just installed
    if [[ " ${MISSING_DEPS[*]} " =~ " docker " ]]; then
        msg_info "Starting Docker service..."
        if command_exists systemctl; then
            $SUDO_CMD systemctl start docker
            $SUDO_CMD systemctl enable docker
        elif command_exists service; then
            $SUDO_CMD service docker start
        fi
        sleep 2
    fi
}

run_upgrade() {
    msg_info "Existing installation detected. Starting upgrade/installation process..."
    
    # Upgrade Condor if it exists
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Upgrading Condor..."
        if ! (cd "$CONDOR_DIR" && git pull); then
            msg_error "Failed to update Condor repository"
            exit 1
        fi
        msg_ok "Condor repository updated."
    else
        msg_warn "Condor directory not found, skipping Condor upgrade."
    fi
    # Check if API needs to be installed (Condor exists but API doesn't)
    if [ -d "$CONDOR_DIR" ] && [ ! -d "$API_DIR" ]; then
        echo ""
        msg_info "Hummingbot API is not installed yet."
        INSTALL_API=$(prompt_yesno "Do you want to install Hummingbot API now?")
        
        if [ "$INSTALL_API" = "y" ]; then
            echo ""
            echo -e "${BLUE}Installing Hummingbot API:${NC}"
            msg_info "Cloning Hummingbot API repository..."
            CREATED_DIRS+=("$API_DIR")
            if ! git clone --depth 1 "$API_REPO" "$API_DIR"; then
                msg_error "Failed to clone Hummingbot API repository"
                exit 1
            fi
            
            msg_info "Setting up Hummingbot API (running: make setup)..."
            if ! (cd "$API_DIR" && make setup); then
                msg_error "Failed to run make setup for Hummingbot API"
                exit 1
            fi
            
            msg_info "Deploying Hummingbot API (running: make deploy)..."
            if ! (cd "$API_DIR" && make deploy); then
                msg_error "Failed to deploy Hummingbot API"
                exit 1
            fi
            msg_ok "Hummingbot API installation complete!"
        fi
    # Upgrade Hummingbot API if it already exists
    elif [ -d "$API_DIR" ]; then
        msg_info "Upgrading Hummingbot API..."
        if ! (cd "$API_DIR" && git pull); then
            msg_error "Failed to update Hummingbot API repository"
            exit 1
        fi
        msg_ok "Hummingbot API repository updated."
    fi
    # Pull latest images for condor and hummingbot-api only
    msg_info "Pulling latest Docker images..."
    
    if [ -f "$CONDOR_DIR/docker-compose.yml" ]; then
        msg_info "Updating Condor container..."
        if ! (cd "$CONDOR_DIR" && $DOCKER_COMPOSE pull); then
            msg_warn "Failed to pull Condor images, continuing anyway..."
        fi
    fi
    if [ -f "$API_DIR/docker-compose.yml" ]; then
        msg_info "Updating Hummingbot API container..."
        if ! (cd "$API_DIR" && $DOCKER_COMPOSE pull); then
            msg_warn "Failed to pull Hummingbot API images, continuing anyway..."
        fi
    fi
    # Restart services
    msg_info "Restarting services..."
    if [ -f "$CONDOR_DIR/docker-compose.yml" ]; then
        if ! (cd "$CONDOR_DIR" && $DOCKER_COMPOSE up -d --remove-orphans); then
            msg_warn "Failed to restart Condor services"
        fi
    fi
    if [ -f "$API_DIR/docker-compose.yml" ]; then
        if ! (cd "$API_DIR" && $DOCKER_COMPOSE up -d --remove-orphans); then
            msg_warn "Failed to restart Hummingbot API services"
        fi
    fi
    msg_ok "Installation/upgrade complete!"
    
    echo ""
    echo -e "${BLUE}Running services:${NC}"
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Check Condor status: cd $CONDOR_DIR && $DOCKER_COMPOSE ps"
    fi
    if [ -d "$API_DIR" ]; then
        msg_info "Check API status: cd $API_DIR && $DOCKER_COMPOSE ps"
    fi
}

install_api_standalone() {
    msg_info "Starting Hummingbot API standalone installation..."
    
    SCRIPT_DIR="$(pwd)"
    msg_ok "Installation directory: $SCRIPT_DIR"
    
    echo ""
    echo -e "${BLUE}Installing Hummingbot API:${NC}"
    
    msg_info "Cloning Hummingbot API repository..."
    CREATED_DIRS+=("$API_DIR")
    if ! git clone --depth 1 "$API_REPO" "$API_DIR"; then
        msg_error "Failed to clone Hummingbot API repository"
        exit 1
    fi
    
    msg_info "Setting up Hummingbot API (running: make setup)..."
    if ! (cd "$API_DIR" && make setup); then
        msg_error "Failed to run make setup for Hummingbot API"
        exit 1
    fi
    
    msg_info "Deploying Hummingbot API (running: make deploy)..."
    if ! (cd "$API_DIR" && make deploy); then
        msg_error "Failed to deploy Hummingbot API"
        exit 1
    fi
    
    # --- Summary ---
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    msg_ok "Hummingbot API Installation Complete!"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Installation Summary:${NC}"
    msg_info "Installation directory: $SCRIPT_DIR/$API_DIR"
    msg_info "Hummingbot API is installed and running"
    
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    msg_info "Check API status: cd $SCRIPT_DIR/$API_DIR && $DOCKER_COMPOSE ps"
    msg_info "View logs: cd $SCRIPT_DIR/$API_DIR && $DOCKER_COMPOSE logs -f"
    
    echo ""
    echo -e "${BLUE}To upgrade in the future:${NC}"
    msg_info "Run: cd $SCRIPT_DIR/$API_DIR && git pull && make deploy"
}

run_installation() {
    msg_info "Starting new installation..."
    
    SCRIPT_DIR="$(pwd)"
    msg_ok "Installation directory: $SCRIPT_DIR"
    # --- Clone and Setup Condor ---
    echo ""
    echo -e "${BLUE}Installing Condor Bot:${NC}"
    msg_info "Cloning Condor repository..."
    CREATED_DIRS+=("$CONDOR_DIR")
    if ! git clone --depth 1 "$CONDOR_REPO" "$CONDOR_DIR"; then
        msg_error "Failed to clone Condor repository"
        exit 1
    fi
    
    # Run Condor's setup-environment.sh script
    msg_info "Running Condor setup script..."
    if [ -f "$CONDOR_DIR/setup-environment.sh" ]; then
        if ! (cd "$CONDOR_DIR" && bash setup-environment.sh); then
            msg_error "Failed to run Condor setup-environment.sh"
            exit 1
        fi
    else
        msg_error "Condor setup-environment.sh not found"
        exit 1
    fi
    
    msg_info "Deploying Condor (running: make deploy)..."
    if ! (cd "$CONDOR_DIR" && make deploy); then
        msg_error "Failed to deploy Condor"
        exit 1
    fi
    msg_ok "Condor installation complete!"
    
    # --- Prompt for API Installation ---
    echo ""
    INSTALL_API=$(prompt_yesno "Do you also want to install Hummingbot API on this machine?")
    
    if [ "$INSTALL_API" = "y" ]; then
        echo ""
        echo -e "${BLUE}Installing Hummingbot API:${NC}"
        
        msg_info "Cloning Hummingbot API repository..."
        CREATED_DIRS+=("$API_DIR")
        if ! git clone --depth 1 "$API_REPO" "$API_DIR"; then
            msg_error "Failed to clone Hummingbot API repository"
            exit 1
        fi
        
        msg_info "Setting up Hummingbot API (running: make setup)..."
        if ! (cd "$API_DIR" && make setup); then
            msg_error "Failed to run make setup for Hummingbot API"
            exit 1
        fi
        
        msg_info "Deploying Hummingbot API (running: make deploy)..."
        if ! (cd "$API_DIR" && make deploy); then
            msg_error "Failed to deploy Hummingbot API"
            exit 1
        fi
        msg_ok "Hummingbot API installation complete!"
    fi
    # --- Summary ---
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    msg_ok "Installation Complete!"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Installation Summary:${NC}"
    msg_info "Installation directory: $SCRIPT_DIR"
    msg_info "Condor is installed and running"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "Hummingbot API is installed and running"
    fi
    
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    msg_info "1. Open Telegram and start a chat with your Condor bot"
    msg_info "2. Use /config command to add Hummingbot API servers and manage access"
    msg_info "3. Check Condor status: cd $SCRIPT_DIR/$CONDOR_DIR && $DOCKER_COMPOSE ps"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "4. Check API status: cd $SCRIPT_DIR/$API_DIR && $DOCKER_COMPOSE ps"
    fi
    
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    msg_info "View Condor logs: cd $SCRIPT_DIR/$CONDOR_DIR && $DOCKER_COMPOSE logs -f"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "View API logs: cd $SCRIPT_DIR/$API_DIR && $DOCKER_COMPOSE logs -f"
    fi
    
    echo ""
    echo -e "${BLUE}To upgrade in the future:${NC}"
    msg_info "Run this script with --upgrade flag: bash $0 --upgrade"
}
# --- Main Execution ---
clear
echo -e "${GREEN}"
cat << "BANNER"
   ██████╗ ██████╗ ███╗   ██╗██████╗  ██████╗ ██████╗ 
  ██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔═══██╗██╔══██╗
  ██║     ██║   ██║██╔██╗ ██║██║  ██║██║   ██║██████╔╝
  ██║     ██║   ██║██║╚██╗██║██║  ██║██║   ██║██╔══██╗
  ╚██████╗╚██████╔╝██║ ╚████║██████╔╝╚██████╔╝██║  ██║
   ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝
BANNER
echo -e "${NC}"
echo -e "${CYAN}  Hummingbot Deploy Installer${NC}"
echo ""
detect_os_arch
check_disk_space
install_dependencies
check_docker_running
detect_docker_compose

# Handle --api flag for standalone API installation
if [ "$API_ONLY_MODE" = "y" ]; then
    if [ -d "$API_DIR" ]; then
        msg_warn "Hummingbot API directory already exists at $API_DIR"
        REINSTALL=$(prompt_yesno "Do you want to upgrade/reinstall?")
        if [ "$REINSTALL" = "y" ]; then
            msg_info "Upgrading Hummingbot API..."
            (cd "$API_DIR" && git pull)
            (cd "$API_DIR" && make deploy)
            msg_ok "Hummingbot API upgraded successfully!"
        fi
    else
        install_api_standalone
    fi
    exit 0
fi

# Determine installation or upgrade path
if [ "$UPGRADE_MODE" = "y" ] || ([ -d "$CONDOR_DIR" ] && [ -d "$API_DIR" ]) || ([ -d "$CONDOR_DIR" ] && [ -f "$CONDOR_DIR/docker-compose.yml" ]); then
    run_upgrade
else
    run_installation
fi
