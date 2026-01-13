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
    [[ -t 0 ]] && [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]
}
# Check if running inside a container
is_container() {
    [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null || grep -q containerd /proc/1/cgroup 2>/dev/null
}
# Escape special characters for .env file
escape_env_value() {
    local value="$1"
    # Escape backslashes, double quotes, and dollar signs
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    echo "$value"
}
# --- Parse Command Line Arguments ---
UPGRADE_MODE="n"
while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade)
            UPGRADE_MODE="y"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upgrade           Upgrade existing installation"
            echo "  -h, --help          Show this help message"
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
    msg_warn "Missing dependencies: ${MISSING_DEPS[*]}"
    msg_info "Attempting to install missing dependencies..."
    case "$OS" in
        linux)
            if ! command_exists apt-get; then
                msg_error "This script currently only supports Debian/Ubuntu-based Linux distributions for automatic dependency installation."
                msg_info "Please install missing dependencies manually: ${MISSING_DEPS[*]}"
                exit 1
            fi
            export DEBIAN_FRONTEND=noninteractive
            sudo apt-get update
            sudo apt-get install -y git curl build-essential
            if ! command_exists docker; then
                msg_info "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm -f get-docker.sh
                sudo usermod -aG docker "$USER"
                msg_warn "Added $USER to docker group."
                
                # Try to use Docker with sg to get group permissions without re-login
                msg_info "Attempting to apply Docker group permissions..."
            fi
            
            # Start Docker daemon - handle both systemd and non-systemd systems
            # Skip if running inside a container
            if ! is_container; then
                if command_exists systemctl; then
                    sudo systemctl start docker 2>/dev/null || true
                    sudo systemctl enable docker 2>/dev/null || true
                elif command_exists service; then
                    sudo service docker start 2>/dev/null || true
                else
                    msg_warn "Could not detect init system. Please start Docker daemon manually if needed."
                fi
            else
                msg_info "Running inside container - Docker daemon should be managed by host"
            fi
            # Check if docker-compose is needed
            if ! (command_exists docker-compose || (command_exists docker && docker compose version >/dev/null 2>&1)); then
                msg_info "Installing Docker Compose..."
                
                # Try to get latest version, with fallback
                LATEST_COMPOSE=""
                if command_exists jq; then
                    LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name' 2>/dev/null) || true
                fi
                
                # Fallback to grep/sed if jq not available or failed
                if [ -z "$LATEST_COMPOSE" ] || [ "$LATEST_COMPOSE" = "null" ]; then
                    LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1) || true
                fi
                
                # Final fallback to a known stable version
                if [ -z "$LATEST_COMPOSE" ] || [ "$LATEST_COMPOSE" = "null" ]; then
                    LATEST_COMPOSE="v2.24.0"
                    msg_warn "Could not detect latest Docker Compose version, using fallback: $LATEST_COMPOSE"
                fi
                
                COMPOSE_URL="https://github.com/docker/compose/releases/download/$LATEST_COMPOSE/docker-compose-$(uname -s)-$(uname -m)"
                
                if ! sudo curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose; then
                    msg_error "Failed to download Docker Compose from $COMPOSE_URL"
                    exit 1
                fi
                sudo chmod +x /usr/local/bin/docker-compose
                msg_ok "Docker Compose installed."
            fi
            ;;
        darwin)
            if ! command_exists brew; then
                msg_error "Homebrew is not installed. Please install it first by visiting https://brew.sh/"
                exit 1
            fi
            
            if ! command_exists git; then
                msg_info "Installing git..."
                brew install git
            fi
            
            if ! command_exists curl; then
                msg_info "Installing curl..."
                brew install curl
            fi
            
            if ! command_exists make; then
                # On macOS, make comes with Xcode Command Line Tools
                if ! xcode-select -p >/dev/null 2>&1; then
                    msg_info "Installing Xcode Command Line Tools (includes make)..."
                    xcode-select --install 2>/dev/null || true
                    msg_warn "Xcode Command Line Tools installation started. Please complete the installation dialog, then re-run this script."
                    exit 0
                else
                    # CLT installed but make not found - try brew as fallback
                    msg_info "Installing make via Homebrew..."
                    brew install make
                    # Note: brew installs as 'gmake', warn user
                    if command_exists gmake && ! command_exists make; then
                        msg_warn "GNU Make installed as 'gmake'. You may need to create an alias or use 'gmake' directly."
                        msg_info "To use as 'make', add to your shell profile: alias make='gmake'"
                    fi
                fi
            fi
            
            if ! command_exists docker; then
                msg_info "Installing Docker Desktop for Mac..."
                brew install --cask docker
                msg_warn "Docker Desktop installed. Please open Docker Desktop to start the Docker daemon, then re-run this script."
                exit 0
            fi
            ;;
        *)
            msg_error "Unsupported operating system: $OS"
            msg_info "Please install dependencies manually: ${MISSING_DEPS[*]}"
            exit 1
            ;;
    esac
    msg_ok "Dependency installation complete."
}
setup_condor_config() {
    ENV_FILE="$CONDOR_DIR/.env"
    
    # Check if running in interactive mode
    if ! is_interactive; then
        msg_warn "Non-interactive mode detected. Skipping configuration prompts."
        msg_info "Please configure $ENV_FILE manually after installation."
        return
    fi
    
    # 1. Check if .env already exists
    if [ -f "$ENV_FILE" ]; then
        echo ""
        echo ">> Found existing $ENV_FILE file."
        echo ">> Credentials already exist. Skipping setup params."
        echo ""
        return
    fi
    
    # 2. Prompt for Telegram Bot Token with validation
    echo ""
    while true; do
        prompt "Enter your Telegram Bot Token: "
        read -r telegram_token < /dev/tty || telegram_token=""
        telegram_token=$(echo "$telegram_token" | tr -d '[:space:]')
        
        if [ -z "$telegram_token" ]; then
            msg_warn "Telegram Bot Token cannot be empty. Please try again."
            continue
        fi
        
        # Validate token format: digits:alphanumeric
        if ! [[ "$telegram_token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            msg_error "Invalid Telegram Bot Token format. Expected format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
            msg_info "Please enter a valid token."
            continue
        fi
        
        break
    done
    
    # 3. Prompt for Admin User ID with validation
    echo ""
    echo "Enter your Telegram User ID (you will be the admin)."
    echo "(Tip: Message @userinfobot on Telegram to get your ID)"
    while true; do
        prompt "Admin User ID: "
        read -r admin_id < /dev/tty || admin_id=""
        admin_id=$(echo "$admin_id" | tr -d '[:space:]')
        
        if [ -z "$admin_id" ]; then
            msg_warn "Admin User ID cannot be empty. Please try again."
            continue
        fi
        
        # Validate user ID is numeric
        if ! [[ "$admin_id" =~ ^[0-9]+$ ]]; then
            msg_error "Invalid User ID. User ID should be numeric (e.g., 123456789)."
            continue
        fi
        
        break
    done
    
    # 4. Prompt for OpenAI API Key (optional)
    echo ""
    echo "Enter your OpenAI API Key (optional, for AI features)."
    echo "Press Enter to skip if not using AI features."
    prompt "OpenAI API Key: "
    read -r openai_key < /dev/tty || openai_key=""
    openai_key=$(echo "$openai_key" | tr -d '[:space:]')
    
    # 5. Create .env file with escaped values
    {
        echo "TELEGRAM_TOKEN=$(escape_env_value "$telegram_token")"
        echo "ADMIN_USER_ID=$(escape_env_value "$admin_id")"
        if [ -n "$openai_key" ]; then
            echo "OPENAI_API_KEY=$(escape_env_value "$openai_key")"
        fi
    } > "$ENV_FILE"
    
    msg_ok "Configuration saved to $ENV_FILE"
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
    msg_info "Pulling latest Docker images (condor and hummingbot-api only)..."
    
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
    msg_info "Check container status with: cd $CONDOR_DIR && $DOCKER_COMPOSE ps"
    if [ -d "$API_DIR" ]; then
        msg_info "Or: cd $API_DIR && $DOCKER_COMPOSE ps"
    fi
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
    
    # Setup Condor configuration
    setup_condor_config
    
    msg_info "Setting up Condor (running: make setup)..."
    if ! (cd "$CONDOR_DIR" && make setup); then
        msg_error "Failed to run make setup for Condor"
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
    msg_info "Check Condor status: cd $SCRIPT_DIR/$CONDOR_DIR && $DOCKER_COMPOSE ps"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "Check API status: cd $SCRIPT_DIR/$API_DIR && $DOCKER_COMPOSE ps"
    fi
    
    echo ""
    echo -e "${BLUE}To upgrade in the future:${NC}"
    msg_info "Run this script with --upgrade flag from the deployment directory"
    msg_info "Or re-run this script without flags if both repos exist"
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
# Determine installation or upgrade path
if [ "$UPGRADE_MODE" = "y" ] || ([ -d "$CONDOR_DIR" ] && [ -d "$API_DIR" ]) || ([ -d "$CONDOR_DIR" ] && [ -f "$CONDOR_DIR/docker-compose.yml" ]); then
    run_upgrade
else
    run_installation
fi
