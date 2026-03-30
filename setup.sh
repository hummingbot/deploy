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
    
    if ! command_exists make; then
        MISSING_DEPS+=("make")
    fi
    if ! command_exists tmux; then
        MISSING_DEPS+=("tmux")
    fi

    local dep_label="git, curl, make, tmux"
    if [[ "$mode" == "all" ]]; then
        dep_label="git, curl, docker, docker-compose, make, tmux"
    fi

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        msg_ok "All dependencies ($dep_label) are already installed."
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
    local admin_id
    admin_id=$(grep -E '^ADMIN_USER_ID=' "$env_file" | sed -E 's/^ADMIN_USER_ID=//')

    if [ -z "$admin_id" ]; then
        msg_warn "ADMIN_USER_ID not set in $env_file, skipping config.yml update."
        return
    fi

    # Current timestamp in ISO-8601 UTC format
    local current_ts
    current_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # If config.yml doesn't exist or is empty, populate it with the current template contents
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        msg_info "Creating default Condor config.yml at $config_file"
        cat > "$config_file" << 'EOF'
servers:
  local:
    host: localhost
    port: 8000
    username: admin
    password: admin
default_server: local
admin_id: <admin_user_id>
users:
  <admin_user_id>:
    user_id: <admin_user_id>
    role: admin
    created_at: <current_timestamp>
    notes: Primary admin from ADMIN_USER_ID
server_access:
  local:
    owner_id: <admin_user_id>
    created_at: <current_timestamp>
    shared_with: {}
chat_defaults:
  <admin_user_id>: local
version: 1
EOF
    fi

    msg_info "Updating Condor config.yml with ADMIN_USER_ID and current timestamp."

    # Replace placeholders in config.yml (handle macOS vs Linux sed)
    if [[ "${OS:-}" == "darwin" ]]; then
        sed -i '' \
            -e "s/<admin_user_id>/$admin_id/g" \
            -e "s/<current_timestamp>/$current_ts/g" \
            "$config_file"
    else
        sed -i \
            -e "s/<admin_user_id>/$admin_id/g" \
            -e "s/<current_timestamp>/$current_ts/g" \
            "$config_file"
    fi

    msg_ok "Condor config.yml updated at $config_file"
}

# Sync Condor config.yml local server username/password to match hummingbot-api/.env
# (so Condor can connect to the local API with the credentials entered during API setup)
sync_condor_config_api_credentials() {
    local config_file="$CONDOR_DIR/config.yml"
    local api_env="$API_DIR/.env"

    if [ ! -f "$api_env" ]; then
        return 0
    fi
    if [ ! -f "$config_file" ]; then
        return 0
    fi

    local api_user api_pass
    api_user=$(grep -E '^USERNAME=' "$api_env" | sed -E 's/^USERNAME=//' | head -1 | tr -d '\r\n')
    api_pass=$(grep -E '^PASSWORD=' "$api_env" | sed -E 's/^PASSWORD=//' | head -1 | tr -d '\r\n')
    api_user="${api_user:-admin}"
    api_pass="${api_pass:-admin}"

    # Escape for sed: backslash and ampersand
    local api_user_esc api_pass_esc
    api_user_esc="${api_user//\\/\\\\}"
    api_user_esc="${api_user_esc//&/\\&}"
    api_pass_esc="${api_pass//\\/\\\\}"
    api_pass_esc="${api_pass_esc//&/\\&}"

    msg_info "Syncing Condor config.yml local server credentials with Hummingbot API .env (username=$api_user)."

    if [[ "${OS:-}" == "darwin" ]]; then
        sed -i '' \
            -e "0,/^    username: /s/^    username: .*/    username: $api_user_esc/" \
            -e "0,/^    password: /s/^    password: .*/    password: $api_pass_esc/" \
            "$config_file"
    else
        sed -i \
            -e "0,/^    username: /s/^    username: .*/    username: $api_user_esc/" \
            -e "0,/^    password: /s/^    password: .*/    password: $api_pass_esc/" \
            "$config_file"
    fi

    msg_ok "Condor config.yml local server credentials updated to match API .env"

    # If credentials differ from default admin/admin, restart Condor so config is applied
    if [ "$api_user" != "admin" ] || [ "$api_pass" != "admin" ]; then
        if [ -d "$CONDOR_DIR" ]; then
            msg_info "Restarting Condor to apply new API credentials..."
            start_condor_tmux
        fi
    fi
}


# --- Condor source-mode helpers ---

# (Re)start Condor in a detached tmux session (same as deploy/condor/Makefile: uv run)
start_condor_tmux() {
    local condor_abs
    condor_abs="$(cd "$CONDOR_DIR" && pwd)"

    if ! command_exists tmux; then
        msg_error "tmux is not installed. Please install tmux and try again."
        exit 1
    fi

    # Find uv even if it's not on PATH in this shell (common after running setup-environment.sh in a subshell)
    local uv_bin=""
    if command_exists uv; then
        uv_bin="$(command -v uv)"
    elif [ -x "$HOME/.local/bin/uv" ]; then
        uv_bin="$HOME/.local/bin/uv"
    elif [ -x "$HOME/.cargo/bin/uv" ]; then
        uv_bin="$HOME/.cargo/bin/uv"
    fi

    if [ -z "$uv_bin" ]; then
        msg_error "'uv' is not available on PATH or in common install locations (~/.local/bin, ~/.cargo/bin)."
        msg_info "Run $CONDOR_DIR/setup-environment.sh once (it installs uv if needed), or install from https://docs.astral.sh/uv/ and ensure 'uv' is on PATH."
        exit 1
    fi

    if tmux has-session -t condor 2>/dev/null; then
        msg_info "Restarting existing tmux session 'condor'..."
        tmux kill-session -t condor
    fi

    msg_info "Starting Condor in detached tmux session 'condor'..."
    tmux new-session -d -s condor \
        "cd '$condor_abs' && '$uv_bin' run python main.py; exec bash"
    msg_ok "Condor is running in tmux session 'condor'."
    msg_info "Attach: tmux attach -t condor  |  Detach: Ctrl+B, D  |  Stop: tmux kill-session -t condor"
}

# Global npm installs often need root on Linux; use sudo when not already root.
npm_install_global_elevated() {
    if [ "${EUID:-0}" -eq 0 ]; then
        npm install -g "$@"
    elif command_exists sudo; then
        sudo -H npm install -g "$@"
    else
        msg_warn "sudo not available; running npm install -g without elevation (may fail)."
        npm install -g "$@"
    fi
}

# Mirrors deploy/condor/Makefile `install` after `setup`: uv sync --dev, setup-chrome, install-ai-tools
install_condor_post_setup_extras() {
    if [ ! -d "$CONDOR_DIR" ] || [ ! -f "$CONDOR_DIR/pyproject.toml" ]; then
        msg_warn "Condor project not found; skipping dev deps, Chrome, and AI CLI tools."
        return 0
    fi
    if ! command_exists uv; then
        msg_warn "uv not on PATH; skipping Condor Makefile extras (run from $CONDOR_DIR after installing uv)."
        return 0
    fi

    echo ""
    msg_info "Condor: syncing dev Python dependencies (uv sync --dev, same as Makefile install)..."
    if ! (cd "$CONDOR_DIR" && uv sync --dev); then
        msg_warn "uv sync --dev failed; skipping remaining Condor optional steps."
        return 0
    fi

    msg_info "Condor: installing Chrome for Plotly image generation (kaleido)..."
    if (cd "$CONDOR_DIR" && uv run python -c "import kaleido; kaleido.get_chrome_sync()" 2>/dev/null); then
        :
    else
        msg_warn "Chrome/kaleido setup skipped (not required for basic usage)."
    fi

    msg_info "Condor: installing AI CLI tools (Claude Code, Gemini CLI, ACP helpers)..."
    if command_exists claude; then
        msg_info "Claude Code already installed ($(claude --version 2>/dev/null || echo ok))"
    else
        if command_exists curl; then
            if ! curl -fsSL https://claude.ai/install.sh | sh; then
                msg_warn "Claude Code install script failed."
            fi
        else
            msg_warn "curl not found; skipping Claude Code install."
        fi
    fi

    if ! command_exists node; then
        msg_warn "Node.js not found; skipping Gemini CLI and ACP npm packages. Install from https://nodejs.org/ if needed."
    else
        if command_exists gemini; then
            msg_info "Gemini CLI already installed ($(gemini --version 2>/dev/null || echo ok))"
        else
            if ! npm_install_global_elevated @google/gemini-cli; then
                msg_warn "Failed to install @google/gemini-cli."
            fi
        fi
        if command_exists claude-code-acp; then
            msg_info "claude-code-acp already installed"
        else
            if ! npm_install_global_elevated @zed-industries/claude-code-acp; then
                msg_warn "Failed to install claude-code-acp."
            fi
        fi
        if command_exists codex-acp; then
            msg_info "codex-acp already installed"
        else
            if ! npm_install_global_elevated @zed-industries/codex-acp; then
                msg_warn "Failed to install codex-acp."
            fi
        fi
    fi

    msg_ok "Condor optional Makefile steps (dev deps, Chrome, AI tools) finished."
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
        install_condor_post_setup_extras
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
    
    # Run Condor's setup-environment.sh script (handles .env/config, deps, tmux launch)
    msg_info "Running Condor setup script..."
    if [ -f "$CONDOR_DIR/setup-environment.sh" ]; then
        if ! (cd "$CONDOR_DIR" && source setup-environment.sh); then
            msg_error "Failed to run Condor setup-environment.sh"
            exit 1
        fi
    else
        msg_error "Condor setup-environment.sh not found"
        exit 1
    fi

    install_condor_post_setup_extras

    msg_ok "Condor installation complete!"
    
    # Ensure Condor config.yml is populated and placeholders are replaced
    update_condor_config

    # Start Condor in a tmux session (source-mode run)
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
    msg_info "Restart Condor:   cd $SCRIPT_DIR/$CONDOR_DIR && source setup-environment.sh"
    
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
