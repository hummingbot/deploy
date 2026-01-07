#!/bin/bash
#
# Hummingbot Deploy Instance Installer
#
# This script should be run from within the cloned 'deploy' repository.
# It will create a self-contained instance directory with all required components.
#

set -e

# --- Configuration ---
INSTANCE_DIR="hbot-instance"
CONDOR_REPO="https://github.com/hummingbot/condor.git"
API_REPO="https://github.com/hummingbot/hummingbot-api.git"
DASHBOARD_REPO="https://github.com/hummingbot/dashboard.git"

# --- Default Flags ---
INSTALL_DASHBOARD="n"

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
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Parse Command Line Arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-dashboard)
            INSTALL_DASHBOARD="y"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-dashboard    Include Dashboard service in the installation"
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
    if command_exists git && command_exists docker && (command_exists docker-compose || docker compose version >/dev/null 2>&1); then
        msg_ok "All dependencies (git, docker, docker-compose) are already installed."
        return
    fi
    
    msg_warn "Some dependencies are missing. You may need to run this with 'sudo'."
    msg_info "Attempting to install missing dependencies..."

    case "$OS" in
        linux)
            if ! command_exists apt-get; then
                msg_error "This script currently only supports Debian/Ubuntu-based Linux distributions for automatic dependency installation."
                exit 1
            fi
            export DEBIAN_FRONTEND=noninteractive
            sudo apt-get update
            sudo apt-get install -y git curl

            if ! command_exists docker; then
                msg_info "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm get-docker.sh
            fi
            sudo systemctl start docker
            sudo systemctl enable docker

            if ! (command_exists docker-compose || docker compose version >/dev/null 2>&1); then
                msg_info "Installing Docker Compose..."
                LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
                sudo curl -L "https://github.com/docker/compose/releases/download/$LATEST_COMPOSE/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
            fi
            ;;
        darwin)
            if ! command_exists brew; then
                msg_error "Homebrew is not installed. Please install it first by visiting https://brew.sh/"
                exit 1
            fi
            brew install git
            if ! command_exists docker; then
                msg_info "Installing Docker Desktop for Mac..."
                brew install --cask docker
                msg_warn "Please open Docker Desktop to start the Docker daemon, then re-run this script."
                exit 0
            fi
            ;;
        *)
            msg_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    msg_ok "Dependency installation complete."
}

run_upgrade() {
    msg_info "Existing installation found in './$INSTANCE_DIR'. Starting upgrade process..."
    cd "$INSTANCE_DIR"
    
    for repo in condor hummingbot-api dashboard; do
        if [ -d "$repo" ]; then
            msg_info "Pulling latest changes for $repo..."
            (cd "$repo" && git pull)
        fi
    done

    msg_info "Pulling latest Docker images..."
    docker compose pull

    msg_info "Restarting services with updated images..."
    docker compose up -d --remove-orphans

    msg_ok "Upgrade complete!"
}

run_installation() {
    msg_info "Starting new installation..."
    mkdir -p "$INSTANCE_DIR"
    cd "$INSTANCE_DIR"
    msg_ok "Created instance directory: $(pwd)"

    # --- User Prompts ---
    echo ""
    echo -e "${BLUE}Component Selection:${NC}"
    msg_info "Condor Bot will be installed by default."
    INSTALL_API=$(prompt_default "Install Hummingbot API service? (y/n)" "y")
    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        msg_info "Dashboard service will be installed (--with-dashboard flag detected)."
    fi

    # --- Clone Repositories ---
    echo ""
    msg_info "Cloning repositories..."
    msg_info "Cloning Condor..."
    git clone --depth 1 "$CONDOR_REPO"
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "Cloning Hummingbot API..."
        git clone --depth 1 "$API_REPO"
    fi
    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        msg_info "Cloning Dashboard..."
        git clone --depth 1 "$DASHBOARD_REPO"
    fi

    # --- Configuration Prompts ---
    echo ""
    echo -e "${BLUE}Universal Configuration:${NC}"
    CONFIG_PASSWORD=$(prompt_default "Enter a password to encrypt your credentials" "admin")
    TELEGRAM_TOKEN=$(prompt_visible "Enter your Telegram Bot Token: ")
    ADMIN_USER_ID=$(prompt_visible "Enter your Admin Telegram User ID (get it from @userinfobot): ")
    OPENAI_API_KEY=$(prompt_visible "Enter your OpenAI API Key (optional, press Enter to skip): ")

    if [ "$INSTALL_API" = "y" ]; then
        echo ""
        echo -e "${BLUE}Hummingbot API Configuration:${NC}"
        API_USERNAME=$(prompt_default "Enter a username for Hummingbot API" "admin")
        API_PASSWORD=$(prompt_default "Enter a password for Hummingbot API" "admin")
    fi

    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        echo ""
        echo -e "${BLUE}Dashboard Configuration:${NC}"
        DASHBOARD_USERNAME=$(prompt_default "Enter a username for the Dashboard" "${API_USERNAME:-admin}")
        DASHBOARD_PASSWORD=$(prompt_default "Enter a password for the Dashboard" "${API_PASSWORD:-admin}")
    fi

    # --- Create .env file ---
    msg_info "Creating universal .env file..."
    cat > .env << EOF
# Universal .env file for Hummingbot Deploy services
# Generated on $(date)
# Values in this file will be used by all services managed by docker-compose.

# --- Security ---
CONFIG_PASSWORD=${CONFIG_PASSWORD}

# --- Condor Telegram Bot ---
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
ADMIN_USER_ID=${ADMIN_USER_ID}
AUTHORIZED_USERS=${ADMIN_USER_ID}
OPENAI_API_KEY=${OPENAI_API_KEY}

# --- Hummingbot API ---
USERNAME=${API_USERNAME:-admin}
PASSWORD=${API_PASSWORD:-admin}

# --- Dashboard ---
DASHBOARD_USERNAME=${DASHBOARD_USERNAME:-admin}
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD:-admin}

# --- Internal Service Configuration ---
# These are used by services to communicate with each other inside the Docker network.
BROKER_HOST=emqx
DATABASE_URL=postgresql+asyncpg://hbot:hummingbot-api@postgres:5432/hummingbot_api
BOTS_PATH=/hummingbot-api/bots

# --- Default App Settings ---
DEBUG_MODE=false
LOGFIRE_ENVIRONMENT=prod
BANNED_TOKENS='["NAV","ARS","ETHW","ETHF","NEWT"]'
EOF
    msg_ok ".env file created."

    # --- Create credentials.yml for Dashboard ---
    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        msg_info "Creating credentials.yml for Dashboard..."
        cat > credentials.yml << EOF
credentials:
  usernames:
    ${DASHBOARD_USERNAME}:
      email: user@example.com
      name: Dashboard User
      password: ${DASHBOARD_PASSWORD}
cookie:
  expiry_days: 30
  key: "hummingbot-dashboard-key"
  name: "hummingbot-dashboard-cookie"
pre-authorized:
  emails: []
EOF
        msg_ok "credentials.yml created."
    fi

    # --- Create docker-compose.yml ---
    msg_info "Generating docker-compose.yml..."
    cat > docker-compose.yml << EOF
# Hummingbot Deploy - Docker Compose Configuration

services:
  condor:
    image: hummingbot/condor:latest
    container_name: condor
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./condor/condor_bot_data.pickle:/app/condor_bot_data.pickle
      - ./condor/config.yml:/app/config.yml
      - ./condor/routines:/app/routines
    network_mode: host
EOF

    if [ "$INSTALL_API" = "y" ] || [ "$INSTALL_DASHBOARD" = "y" ]; then
        cat >> docker-compose.yml << EOF

  emqx:
    image: emqx:5
    container_name: hummingbot-broker
    restart: unless-stopped
    environment:
      - EMQX_NAME=emqx
      - EMQX_LOADED_PLUGINS="emqx_recon,emqx_retainer,emqx_management,emqx_dashboard"
    ports:
      - "1883:1883"
      - "8081:8081"
      - "8083:8083"
      - "8084:8084"
      - "8883:8883"
      - "18083:18083"
    volumes:
      - emqx_data:/opt/emqx/data
      - emqx_log:/opt/emqx/log
    networks:
      - hummingbot_net

  postgres:
    image: postgres:16
    container_name: hummingbot-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=hummingbot_api
      - POSTGRES_USER=hbot
      - POSTGRES_PASSWORD=hummingbot-api
      - POSTGRES_INITDB_ARGS=--encoding=UTF8
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql:ro
    ports:
      - "5432:5432"
    networks:
      - hummingbot_net
EOF
    fi

    if [ "$INSTALL_API" = "y" ]; then
        cat >> docker-compose.yml << EOF

  hummingbot-api:
    image: hummingbot/hummingbot-api:latest
    container_name: hummingbot-api
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./hummingbot-api/bots:/hummingbot-api/bots
      - /var/run/docker.sock:/var/run/docker.sock
    env_file: .env
    environment:
      # Override specific values for Docker networking
      - BROKER_HOST=emqx
      - DATABASE_URL=postgresql+asyncpg://hbot:hummingbot-api@postgres:5432/hummingbot_api
      - GATEWAY_URL=http://host.docker.internal:15888
    extra_hosts:
      # Map host.docker.internal to host gateway for Linux compatibility
      # On macOS/Windows, Docker Desktop provides this automatically
      # On Linux, this maps to the docker bridge gateway IP
      - "host.docker.internal:host-gateway"
    depends_on:
      - postgres
      - emqx
    networks:
      - hummingbot_net
EOF
    fi

    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        cat >> docker-compose.yml << EOF

  dashboard:
    image: hummingbot/dashboard:latest
    container_name: dashboard
    restart: unless-stopped
    ports:
      - "8501:8501"
    volumes:
      - ./credentials.yml:/home/dashboard/credentials.yml
      - ./dashboard/frontend/pages:/home/dashboard/frontend/pages
    env_file: .env
    environment:
      - BACKEND_API_HOST=hummingbot-api
      - BACKEND_API_PORT=8000
    depends_on:
      - hummingbot-api
    networks:
      - hummingbot_net
EOF
    fi

    cat >> docker-compose.yml << EOF

volumes:
  emqx_data:
  emqx_log:
  postgres_data:

networks:
  hummingbot_net:
    driver: bridge
EOF
    msg_ok "docker-compose.yml generated."

    # --- Start Services ---
    msg_info "Pulling required Docker images..."
    docker compose pull

    msg_info "Starting services..."
    docker compose up -d

    # --- Summary ---
    echo ""
    msg_ok "Installation Complete!"
    echo -e "Your services are running in the ${PURPLE}$(pwd)${NC} directory."
    echo ""
    echo -e "${BLUE}Access your services:${NC}"
    msg_info "Condor Bot is running and connected to Telegram."
    if [ "$INSTALL_API" = "y" ]; then
        msg_info "Hummingbot API Docs: http://localhost:8000/docs"
    fi
    if [ "$INSTALL_DASHBOARD" = "y" ]; then
        msg_info "Dashboard: http://localhost:8501"
    fi
    echo ""
    msg_info "To manage services, navigate to the '$INSTANCE_DIR' directory and use 'docker compose' commands."
    msg_info "To upgrade in the future, re-run this script from the same directory it was first run."
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
install_dependencies

if [ -d "$INSTANCE_DIR" ]; then
    run_upgrade
else
    run_installation
fi
