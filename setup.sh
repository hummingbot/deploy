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
CONDOR_BRANCH=""   # Optional: Branch to clone
CONDOR_PR=""       # Optional: PR ID to pull
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

# Bash does not "restart" after installing tools; export PATH so this same script run sees them.
# (Docker group membership for $USER still requires a new login session — see install message.)
refresh_tool_path() {
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    
    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi
    
    if command_exists npm; then
        local npm_prefix
        npm_prefix=$(npm config get prefix 2>/dev/null || true)
        if [[ -n "$npm_prefix" ]] && [[ -d "$npm_prefix/bin" ]]; then
            export PATH="$npm_prefix/bin:$PATH"
        fi
    fi
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
        -b|--branch)
            CONDOR_BRANCH="$2"
            shift 2
            ;;
        -p|--pr)
            CONDOR_PR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upgrade           Upgrade existing installation"
            echo "  --api               Install only Hummingbot API (standalone)"
            echo "  -b, --branch NAME   Clone a specific branch of Condor"
            echo "  -p, --pr ID         Pull a specific PR ID from Condor"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  Fresh installation (Condor + optional API)"
            echo "  $0 --upgrade        Upgrade existing installations"
            echo "  $0 --api            Install only Hummingbot API"
            echo "  $0 --branch dev     Install from the 'dev' branch"
            echo "  $0 --pr 123         Install from PR #123"
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

install_nodejs_via_nvm() {
    msg_info "Installing Node.js via nvm..."
    
    # Install nvm if not present
    if [ ! -d "$HOME/.nvm" ]; then
        msg_info "Installing nvm (Node Version Manager)..."
        if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash; then
            msg_ok "nvm installed successfully"
        else
            msg_error "Failed to install nvm"
            return 1
        fi
    else
        msg_ok "nvm is already installed"
    fi
    
    # Load nvm into current shell
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Install Node.js LTS (version 24)
    msg_info "Installing Node.js v24 (LTS)..."
    if nvm install 24 2>/dev/null; then
        nvm use 24
        nvm alias default 24
        msg_ok "Node.js v24 installed and set as default"
        
        # Update PATH for current session
        export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"
        return 0
    else
        msg_error "Failed to install Node.js via nvm"
        return 1
    fi
}

install_dependencies() {
    # $1: "all" (default) requires Docker; "condor-only" skips Docker checks
    local mode="${1:-all}"

    msg_info "Checking for dependencies..."
    
    MISSING_DEPS=()
    
    if ! command_exists git; then
        MISSING_DEPS+=("git")
    fi
    if ! command_exists curl; then
        MISSING_DEPS+=("curl")
    fi
    if ! command_exists python3; then
        MISSING_DEPS+=("python3")
    fi
    if ! command_exists make; then
        MISSING_DEPS+=("make")
    fi
    if ! command_exists tmux; then
        MISSING_DEPS+=("tmux")
    fi
    if ! command_exists uv; then
        MISSING_DEPS+=("uv")
    fi

    # Check for Node.js/npm - will be installed via nvm if missing
    NODE_NEEDS_INSTALL=false
    if ! command_exists node || ! command_exists npm; then
        NODE_NEEDS_INSTALL=true
        MISSING_DEPS+=("nodejs/npm")
    fi

    # TypeScript check
    if ! command_exists tsc; then
        MISSING_DEPS+=("typescript")
    fi

    # Docker is only required when installing the Hummingbot API
    if [[ "$mode" == "all" ]]; then
        if ! command_exists docker; then
            MISSING_DEPS+=("docker")
        fi
        
        # Check for docker-compose (either standalone or as docker compose plugin)
        if ! (command_exists docker-compose || (command_exists docker && docker compose version >/dev/null 2>&1)); then
            MISSING_DEPS+=("docker-compose")
        fi
    fi

    local dep_label="git, curl, python3, nodejs, npm, typescript (tsc), make, tmux, uv"
    if [[ "$mode" == "all" ]]; then
        dep_label="git, curl, python3, nodejs, npm, typescript (tsc), docker, docker-compose, make, tmux, uv"
    fi

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        msg_ok "All dependencies ($dep_label) are already installed."
        refresh_tool_path
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
            msg_info "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
            msg_info "Install Node.js via nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash"
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
            python3)
                msg_info "Installing Python 3..."
                if [[ "$PKG_MANAGER" == "apt-get" ]]; then
                    if ! eval "$INSTALL_CMD python3 python3-pip"; then
                        msg_error "Failed to install Python 3"
                        exit 1
                    fi
                else
                    if ! eval "$INSTALL_CMD python3"; then
                        msg_error "Failed to install Python 3"
                        exit 1
                    fi
                fi
                ;;
            nodejs/npm)
                # Install via nvm instead of system package manager
                if ! install_nodejs_via_nvm; then
                    msg_error "Failed to install Node.js via nvm"
                    exit 1
                fi
                ;;
            typescript)
                msg_info "Installing TypeScript (tsc)..."
                
                # Make sure npm is available
                refresh_tool_path
                
                if ! command_exists npm; then
                    msg_error "npm is required to install TypeScript but is not available"
                    exit 1
                fi
                
                if ! npm install -g typescript; then
                    msg_error "Failed to install TypeScript (npm install -g typescript)"
                    exit 1
                fi
                refresh_tool_path
                ;;
            uv)
                msg_info "Installing uv..."
                if command_exists curl; then
                    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
                        # Add to PATH for current session
                        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
                        
                        # Persist to shell profile
                        for profile in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
                            if [ -f "$profile" ]; then
                                if ! grep -q 'uv/bin\|\.cargo/bin\|\.local/bin' "$profile" 2>/dev/null; then
                                    echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> "$profile"
                                    msg_ok "Added uv to PATH in $profile"
                                    break
                                fi
                            fi
                        done
                        
                        msg_ok "uv installed successfully"
                    else
                        msg_error "Failed to install uv"
                        exit 1
                    fi
                else
                    msg_error "curl is required to install uv"
                    exit 1
                fi
                ;;
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

    refresh_tool_path
}

update_condor_config() {
    # Update condor/config.yml by inserting the template (if needed)
    # and replacing placeholders with actual values from .env and current timestamp.
    local config_file="$CONDOR_DIR/config.yml"
    local env_file="$CONDOR_DIR/.env"

    if [ ! -d "$CONDOR_DIR" ]; then
        msg_warn "Condor directory '$CONDOR_DIR' not found, skipping config.yml update."
        return
    fi

    if [ ! -f "$env_file" ]; then
        msg_warn "Condor .env not found at $env_file, skipping config.yml update."
        return
    fi

    # Extract ADMIN_USER_ID from .env
    local admin_user_id
    admin_user_id=$(grep "^ADMIN_USER_ID=" "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")

    if [ -z "$admin_user_id" ]; then
        msg_warn "ADMIN_USER_ID not found in $env_file, skipping config.yml update."
        return
    fi

    # Get current date
    local current_date
    current_date=$(date "+%Y-%m-%d")

    # If config.yml doesn't exist or is empty, create it with template
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        msg_info "Creating $config_file with template..."
        cat > "$config_file" << 'CONFIGEOF'
# Telegram user IDs allowed to access the bot
authorized_users:
  - ADMIN_USER_ID_PLACEHOLDER  # Replace with your Telegram user ID

# Hummingbot API server configurations
servers:
  local:
    host: localhost
    port: 8000
    username: admin
    password: admin

# Controller configurations (loaded at startup)
controllers:
  # Example configuration file entries (created: DATE_PLACEHOLDER):
  # main:
  #   type: directional_strategy_vwap
  #   connector: binance
  #   trading_pair: BTC-USDT
  #   leverage: 20
  #   total_amount_quote: 100
  #   ...
CONFIGEOF
    fi

    # Replace placeholders if they exist
    if grep -q "ADMIN_USER_ID_PLACEHOLDER" "$config_file" 2>/dev/null; then
        sed -i.bak "s/ADMIN_USER_ID_PLACEHOLDER/$admin_user_id/g" "$config_file"
        rm -f "$config_file.bak"
        msg_ok "Replaced ADMIN_USER_ID_PLACEHOLDER with $admin_user_id in $config_file"
    fi

    if grep -q "DATE_PLACEHOLDER" "$config_file" 2>/dev/null; then
        sed -i.bak "s/DATE_PLACEHOLDER/$current_date/g" "$config_file"
        rm -f "$config_file.bak"
        msg_ok "Replaced DATE_PLACEHOLDER with $current_date in $config_file"
    fi
}

sync_condor_config_api_credentials() {
    # If API is installed, sync Condor's config.yml 'local' server credentials with API's .env
    local condor_config="$CONDOR_DIR/config.yml"
    local api_env="$API_DIR/.env"

    if [ ! -f "$condor_config" ]; then
        msg_warn "Condor config.yml not found, skipping credential sync."
        return
    fi

    if [ ! -f "$api_env" ]; then
        msg_warn "API .env not found at $api_env, skipping credential sync."
        return
    fi

    local api_username
    local api_password
    api_username=$(grep "^USERNAME=" "$api_env" 2>/dev/null | cut -d= -f2)
    api_password=$(grep "^PASSWORD=" "$api_env" 2>/dev/null | cut -d= -f2)

    if [ -z "$api_username" ] || [ -z "$api_password" ]; then
        msg_warn "Could not extract API credentials from $api_env, skipping sync."
        return
    fi

    # Update config.yml 'local' server credentials using sed (simple approach)
    # This assumes a structure like:
    # servers:
    #   local:
    #     host: ...
    #     username: ...
    #     password: ...

    # Replace username
    if grep -A5 "servers:" "$condor_config" | grep -q "username:"; then
        sed -i.bak "/servers:/,/^[^ ]/ s/username: .*/username: $api_username/" "$condor_config"
        rm -f "$condor_config.bak"
    fi

    # Replace password
    if grep -A5 "servers:" "$condor_config" | grep -q "password:"; then
        sed -i.bak "/servers:/,/^[^ ]/ s/password: .*/password: $api_password/" "$condor_config"
        rm -f "$condor_config.bak"
    fi

    msg_ok "Synced Condor config.yml local server credentials with API .env"
}

install_condor_post_setup_extras() {
    # After Condor's setup-environment.sh runs, this function runs any additional steps
    # that are needed but not covered by the setup script (e.g., installing extra tools).
    msg_info "Running post-setup extras for Condor..."
    
    # Currently, setup-environment.sh handles all necessary setup
    # This function is a placeholder for future enhancements
    
    msg_ok "Post-setup extras complete"
}

run_condor_manual_install_and_build() {
    # Execute the equivalent of `make install` and `make run` manually,
    # except for the final app start command which is handled in tmux.
    local condor_path="$CONDOR_DIR"

    if [ ! -d "$condor_path" ]; then
        msg_error "Condor directory not found: $condor_path"
        exit 1
    fi

    msg_info "Running Condor setup script (manual make install step)..."
    if ! (cd "$condor_path" && chmod +x setup-environment.sh && ./setup-environment.sh); then
        msg_error "Failed to run setup-environment.sh"
        exit 1
    fi

    msg_info "Syncing Python dependencies (uv sync --dev)..."
    if ! (cd "$condor_path" && uv sync --dev); then
        msg_error "Failed to sync Condor Python dependencies"
        exit 1
    fi

    # Load nvm and check for Node.js/npm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    msg_info "Checking Node.js and npm..."
    if ! command_exists node; then
        msg_error "Node.js is required but not found"
        msg_info "Attempting to install Node.js via nvm..."
        if ! install_nodejs_via_nvm; then
            msg_error "Failed to install Node.js"
            exit 1
        fi
    fi
    
    if ! command_exists npm; then
        msg_error "npm is required but not found"
        exit 1
    fi

    msg_info "Installing frontend dependencies (npm install)..."
    if ! (cd "$condor_path/frontend" && npm install); then
        msg_error "Failed to install frontend dependencies"
        exit 1
    fi

    msg_info "Setting up Chrome for chart rendering (optional)..."
    if ! (cd "$condor_path" && uv run python -c "import kaleido; kaleido.get_chrome_sync()" 2>/dev/null); then
        msg_warn "Chrome setup skipped (not required for basic usage)"
    fi

    msg_info "Building frontend (manual make run step)..."
    if ! (cd "$condor_path/frontend" && npm run build); then
        msg_error "Failed to build frontend"
        exit 1
    fi
}

start_condor_tmux() {
    # Start or restart Condor in a tmux session
    msg_info "Starting Condor in tmux session..."
    
    # Kill existing session if present
    if tmux has-session -t condor 2>/dev/null; then
        msg_info "Stopping existing Condor tmux session..."
        tmux kill-session -t condor
    fi
    
    # Start new session
    if [ -d "$CONDOR_DIR" ]; then
        (cd "$CONDOR_DIR" && tmux new-session -d -s condor "uv run python main.py")
        sleep 2
        
        if tmux has-session -t condor 2>/dev/null; then
            msg_ok "Condor started in tmux session 'condor'"
            msg_info "View logs: tmux attach -t condor (Ctrl+B, D to detach)"
        else
            msg_error "Failed to start Condor in tmux"
        fi
    else
        msg_error "Condor directory not found: $CONDOR_DIR"
    fi
}

run_upgrade() {
    msg_info "Starting upgrade process..."
    
    # Pull latest changes for both repos if they exist
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Updating Condor repository..."
        if ! (cd "$CONDOR_DIR" && git pull); then
            msg_error "Failed to update Condor repository"
            exit 1
        fi
        msg_ok "Condor repository updated."
    fi
    
    if [ -d "$API_DIR" ]; then
        msg_info "Updating Hummingbot API repository..."
        if ! (cd "$API_DIR" && git pull); then
            msg_error "Failed to update Hummingbot API repository"
            exit 1
        fi
        msg_ok "Hummingbot API repository updated."
    fi
    # Pull latest images for condor and hummingbot-api only
    msg_info "Pulling latest Docker images..."
    
    # Condor runs via source/tmux — no Docker image to pull; just restart the session
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Restarting Condor tmux session after upgrade..."
        start_condor_tmux
    fi
    if [ -f "$API_DIR/docker-compose.yml" ]; then
        msg_info "Updating Hummingbot API container..."
        if ! (cd "$API_DIR" && $DOCKER_COMPOSE pull); then
            msg_warn "Failed to pull Hummingbot API images, continuing anyway..."
        fi
        msg_info "Pulling latest Hummingbot image (hummingbot/hummingbot:latest)..."
        if ! docker pull hummingbot/hummingbot:latest; then
            msg_warn "Failed to pull hummingbot/hummingbot:latest, continuing anyway..."
        fi
    fi
    # Restart services
    msg_info "Restarting services..."
    if [ -d "$CONDOR_DIR" ]; then
        start_condor_tmux
    fi
    if [ -f "$API_DIR/docker-compose.yml" ]; then
        if ! (cd "$API_DIR" && $DOCKER_COMPOSE up -d --remove-orphans); then
            msg_warn "Failed to restart Hummingbot API services"
        fi
    fi

    # Ensure Condor config.yml is populated and placeholders are replaced
    update_condor_config
    # If API is installed, sync Condor config local server credentials with API .env
    sync_condor_config_api_credentials

    msg_ok "Installation/upgrade complete!"
    
    echo ""
    echo -e "${BLUE}Running services:${NC}"
    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Check Condor status: tmux attach -t condor"
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

    if [ -n "$CONDOR_PR" ]; then
        msg_info "Cloning Condor and pulling PR #$CONDOR_PR..."
        CREATED_DIRS+=("$CONDOR_DIR")
        git clone "$CONDOR_REPO" "$CONDOR_DIR"
        (cd "$CONDOR_DIR" && git fetch origin "pull/$CONDOR_PR/head:pr-$CONDOR_PR" && git checkout "pr-$CONDOR_PR") || {
            msg_error "Failed to pull PR #$CONDOR_PR"
            exit 1
        }
    elif [ -n "$CONDOR_BRANCH" ]; then
        msg_info "Cloning Condor branch '$CONDOR_BRANCH'..."
        CREATED_DIRS+=("$CONDOR_DIR")
        if ! git clone --depth 1 -b "$CONDOR_BRANCH" "$CONDOR_REPO" "$CONDOR_DIR"; then
            msg_error "Failed to clone branch '$CONDOR_BRANCH'"
            exit 1
        fi
    else
        msg_info "Cloning Condor repository..."
        CREATED_DIRS+=("$CONDOR_DIR")
        if ! git clone --depth 1 "$CONDOR_REPO" "$CONDOR_DIR"; then
            msg_error "Failed to clone Condor repository"
            exit 1
        fi
    fi
    
    # Manually run the equivalent of make install + make run (except app launch in tmux)
    if [ ! -f "$CONDOR_DIR/setup-environment.sh" ]; then
        msg_error "Condor setup-environment.sh not found"
        exit 1
    fi
    run_condor_manual_install_and_build

    install_condor_post_setup_extras

    msg_ok "Condor installation complete!"
    
    # Ensure Condor config.yml is populated and placeholders are replaced
    update_condor_config

    # Start Condor in tmux after install/build steps complete
    start_condor_tmux
    
    # --- Summary ---
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    msg_ok "Installation Complete!"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Installation Summary:${NC}"
    msg_info "Installation directory: $SCRIPT_DIR"
    msg_info "Condor is installed and running"
    
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    msg_info "1. Open Telegram and start a chat with your Condor bot"
    msg_info "2. Use /config command to add Hummingbot API servers and manage access"
    msg_info "3. Check Condor status: tmux attach -t condor  (Ctrl+B, D to detach)"
    # Hummingbot API installation and management are handled via Condor's setup script.
    
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    msg_info "View Condor logs: tmux attach -t condor"
    msg_info "Stop Condor:      tmux kill-session -t condor"
    msg_info "Restart Condor:   cd $SCRIPT_DIR/$CONDOR_DIR && bash setup-environment.sh"
    
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

# Handle --api flag for standalone API installation
if [ "$API_ONLY_MODE" = "y" ]; then
    install_dependencies "all"
    check_docker_running
    detect_docker_compose

    if [ -d "$API_DIR" ]; then
        msg_warn "Hummingbot API directory already exists at $API_DIR"
        REINSTALL=$(prompt_yesno "Do you want to upgrade/reinstall?")
        if [ "$REINSTALL" = "y" ]; then
            msg_info "Upgrading Hummingbot API..."
            (cd "$API_DIR" && git pull)
            msg_info "Pulling latest Hummingbot image (hummingbot/hummingbot:latest)..."
            docker pull hummingbot/hummingbot:latest || msg_warn "Failed to pull hummingbot/hummingbot:latest, continuing anyway..."
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
    # Upgrade: Docker is needed if API directory exists
    if [ -d "$API_DIR" ]; then
        install_dependencies "all"
        check_docker_running
        detect_docker_compose
    else
        install_dependencies "condor-only"
    fi
    run_upgrade
else
    # Fresh install: Docker will be needed if the user opts in for the API
    # We check for Docker/compose later inside run_installation if API is chosen.
    install_dependencies "condor-only"
    run_installation
fi
