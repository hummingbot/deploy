#!/bin/bash
#
# Hummingbot Deploy Instance Installer
#
# This script sets up Hummingbot instances with optional Hummingbot API integration.
# Each repository manages its own docker-compose and setup via Makefile.

set -e

# --- Configuration ---
CONDOR_REPO="https://github.com/hummingbot/condor.git"
API_REPO="https://github.com/hummingbot/hummingbot-api.git"
CONDOR_DIR="condor"
API_DIR="hummingbot-api"

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helper Functions ---
msg_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

msg_ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}

msg_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

msg_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

prompt() {
    echo -en "${PURPLE}$1${NC}" > /dev/tty
}

prompt_visible() {
    prompt "$1"
    read -r val < /dev/tty
    echo "$val"
}

prompt_default() {
    prompt "$1 [$2]: "
    read -r val < /dev/tty
    echo "${val:-$2}"
}

prompt_yesno() {
    while true; do
        prompt "$1 (y/n): "
        read -r val < /dev/tty
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

check_conda() {
    if command_exists conda; then
        return 0
    fi
    return 1
}

install_conda() {
    msg_info "Installing Anaconda..."
    
    CONDA_INSTALL_DIR="$HOME/anaconda3"
    
    # Download appropriate installer for OS and architecture
    case "$OS" in
        linux)
            case "$ARCH" in
                amd64|x86_64)
                    CONDA_INSTALLER="Anaconda3-2024.02-1-Linux-x86_64.sh"
                    ;;
                arm64|aarch64)
                    CONDA_INSTALLER="Anaconda3-2024.02-1-Linux-aarch64.sh"
                    ;;
                *)
                    msg_error "Unsupported architecture for Linux: $ARCH"
                    return 1
                    ;;
            esac
            ;;
        darwin)
            case "$ARCH" in
                amd64|x86_64)
                    CONDA_INSTALLER="Anaconda3-2024.02-1-MacOSX-x86_64.sh"
                    ;;
                arm64|aarch64)
                    CONDA_INSTALLER="Anaconda3-2024.02-1-MacOSX-arm64.sh"
                    ;;
                *)
                    msg_error "Unsupported architecture for macOS: $ARCH"
                    return 1
                    ;;
            esac
            ;;
        *)
            msg_error "Unsupported OS for Anaconda installation: $OS"
            return 1
            ;;
    esac
    
    CONDA_URL="https://repo.anaconda.com/archive/$CONDA_INSTALLER"
    CONDA_TEMP="/tmp/$CONDA_INSTALLER"
    
    msg_info "Downloading Anaconda from: $CONDA_URL"
    if ! curl -fL "$CONDA_URL" -o "$CONDA_TEMP"; then
        msg_error "Failed to download Anaconda installer"
        return 1
    fi
    
    msg_info "Running Anaconda installer..."
    if ! bash "$CONDA_TEMP" -b -p "$CONDA_INSTALL_DIR"; then
        msg_error "Anaconda installation failed"
        rm -f "$CONDA_TEMP"
        return 1
    fi
    
    rm -f "$CONDA_TEMP"
    
    # Initialize conda
    msg_info "Initializing conda..."
    "$CONDA_INSTALL_DIR/bin/conda" init bash
    
    msg_ok "Anaconda installed successfully at: $CONDA_INSTALL_DIR"
    msg_info "Restarting shell to activate conda and continue installation..."
    
    # Get the directory where the script is located
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Restart bash and re-invoke this script with --upgrade flag to continue
    exec bash -c "source $HOME/.bashrc && bash '$SCRIPT_PATH' --upgrade"
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
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv*) ARCH="arm" ;;
    esac
    msg_info "Detected OS: $OS, Architecture: $ARCH"
}

install_dependencies() {
    msg_info "Checking for dependencies..."
    
    MISSING_DEPS=()
    
    if ! command_exists git; then
        MISSING_DEPS+=("git")
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
        msg_ok "All dependencies (git, docker, docker-compose, make) are already installed."
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
                msg_warn "Docker installed. You may need to log out and back in for permissions to take effect."
            fi
            
            sudo systemctl start docker 2>/dev/null || true
            sudo systemctl enable docker 2>/dev/null || true

            # Check if docker-compose is needed
            if ! (command_exists docker-compose || (command_exists docker && docker compose version >/dev/null 2>&1)); then
                msg_info "Installing Docker Compose..."
                LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
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
            
            if ! command_exists make; then
                msg_info "Installing make..."
                brew install make
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

run_upgrade() {
    msg_info "Existing installation detected. Starting upgrade/installation process..."
    
    # Upgrade Condor if it exists
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Upgrading Condor..."
        (cd "$CONDOR_DIR" && git pull)
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
            git clone --depth 1 "$API_REPO" "$API_DIR"
            
            msg_info "Setting up Hummingbot API (running: make setup)..."
            (cd "$API_DIR" && make setup)
            
            msg_info "Deploying Hummingbot API (running: make deploy)..."
            (cd "$API_DIR" && make deploy)
            msg_ok "Hummingbot API installation complete!"
        fi
    # Upgrade Hummingbot API if it already exists
    elif [ -d "$API_DIR" ]; then
        msg_info "Upgrading Hummingbot API..."
        (cd "$API_DIR" && git pull)
        msg_ok "Hummingbot API repository updated."
    fi

    # Pull latest images for condor and hummingbot-api only
    msg_info "Pulling latest Docker images (condor and hummingbot-api only)..."
    
    if [ -f "$CONDOR_DIR/docker-compose.yml" ]; then
        msg_info "Updating Condor container..."
        (cd "$CONDOR_DIR" && docker compose pull || true)
    fi

    if [ -f "$API_DIR/docker-compose.yml" ]; then
        msg_info "Updating Hummingbot API container..."
        (cd "$API_DIR" && docker compose pull || true)
    fi

    # Restart services
    msg_info "Restarting services..."
    if [ -f "$CONDOR_DIR/docker-compose.yml" ]; then
        (cd "$CONDOR_DIR" && docker compose up -d --remove-orphans || true)
    fi
    if [ -f "$API_DIR/docker-compose.yml" ]; then
        (cd "$API_DIR" && docker compose up -d --remove-orphans || true)
    fi

    msg_ok "Installation/upgrade complete!"
    
    echo ""
    echo -e "${BLUE}Running services:${NC}"
    msg_info "Check container status with: cd $CONDOR_DIR && docker compose ps"
    if [ -d "$API_DIR" ]; then
        msg_info "Or: cd $API_DIR && docker compose ps"
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
    git clone --depth 1 "$CONDOR_REPO" "$CONDOR_DIR"
    
    msg_info "Setting up Condor (running: make setup)..."
    (cd "$CONDOR_DIR" && make setup)
    
    msg_info "Deploying Condor (running: make deploy)..."
    (cd "$CONDOR_DIR" && make deploy)
    msg_ok "Condor installation complete!"
    
    # --- Prompt for API Installation ---
    echo ""
    INSTALL_API=$(prompt_yesno "Do you also want to install Hummingbot API on this machine?")
    
    if [ "$INSTALL_API" = "y" ]; then
        echo ""
        echo -e "${BLUE}Installing Hummingbot API:${NC}"
        
        # --- Check for Conda ---
        msg_info "Checking for conda..."
        if ! check_conda; then
            msg_warn "Conda is not installed. Hummingbot API requires Python via Conda."
            INSTALL_CONDA=$(prompt_yesno "Would you like to install Anaconda now?")
            
            if [ "$INSTALL_CONDA" = "y" ]; then
                if install_conda; then
                    msg_ok "Anaconda installed and shell restarted. Continuing with API installation..."
                    # After exec bash, script will continue from here with conda available
                else
                    msg_error "Failed to install Anaconda. Please install it manually from https://www.anaconda.com/download"
                    exit 1
                fi
            else
                msg_error "Anaconda is required for Hummingbot API installation. Skipping API installation."
                INSTALL_API="n"
            fi
        else
            msg_ok "Conda is already installed."
        fi
        
        if [ "$INSTALL_API" = "y" ]; then
            msg_info "Cloning Hummingbot API repository..."
            git clone --depth 1 "$API_REPO" "$API_DIR"
            
            msg_info "Setting up Hummingbot API (running: make setup)..."
            (cd "$API_DIR" && make setup)
            
            msg_info "Deploying Hummingbot API (running: make deploy)..."
            (cd "$API_DIR" && make deploy)
            msg_ok "Hummingbot API installation complete!"
        fi
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
    msg_info "Check Condor status: cd $SCRIPT_DIR/$CONDOR_DIR && docker compose ps"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "Check API status: cd $SCRIPT_DIR/$API_DIR && docker compose ps"
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
  ██║     ██║   ██║██║╚██╗██║██║  ██║██║   ██║██╔══██╝
  ╚██████╗╚██████╔╝██║ ╚████║██████╔╝╚██████╔╝██║  ██║
   ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝
BANNER
echo -e "${NC}"
echo -e "${CYAN}  Hummingbot Deploy Installer${NC}"
echo ""

detect_os_arch
install_dependencies

# Determine installation or upgrade path
if [ "$UPGRADE_MODE" = "y" ] || ([ -d "$CONDOR_DIR" ] && [ -d "$API_DIR" ]) || ([ -d "$CONDOR_DIR" ] && [ -f "$CONDOR_DIR/docker-compose.yml" ]); then
    run_upgrade
else
    run_installation
fi
