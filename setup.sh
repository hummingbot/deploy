#!/bin/bash
#
# Hummingbot Deploy Instance Installer
#
# Orchestrates cloning and upgrades; Condor and hummingbot-api use their own Makefiles.
#
# Non-interactive / CI: set DEPLOY_NONINTERACTIVE=1 (or CI=true) and provide:
#   TELEGRAM_TOKEN, ADMIN_USER_ID  (written to condor/.env before first make install)
# Optional: DEPLOY_HUMMINGBOT_API=true|false (default false if omitted)
#
# Standalone API: run this script with --hummingbot-api (see --help).
#
# Nested make: Condor's setup-environment.sh respects SKIP_SETUP_RESTART=1 (no exec restart).
#
set -eu

# --- Configuration ---
CONDOR_REPO="https://github.com/hummingbot/condor.git"
API_REPO="https://github.com/hummingbot/hummingbot-api.git"
# Used in printed hints when the script has no file path (e.g. curl | bash)
DEPLOY_SETUP_RAW_URL="https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh"
CONDOR_DIR="condor"
API_DIR="hummingbot-api"
DOCKER_COMPOSE=""
CONDOR_BRANCH=""
CONDOR_PR=""
AUTO_YES="n"
HB_API_ONLY_MODE="n"

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CREATED_DIRS=()

cleanup() {
    local exit_code=$?
    rm -f get-docker.sh 2>/dev/null || true
    if [ "$exit_code" -ne 0 ]; then
        for dir in "${CREATED_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                msg_warn "Cleaning up partial installation: $dir"
                rm -rf "$dir" 2>/dev/null || true
            fi
        done
    fi
}
trap cleanup EXIT

msg_info() { echo -e "${CYAN}[INFO] $1${NC}"; }
msg_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
msg_warn() { echo -e "${YELLOW}[WARN] $1${NC}" >&2; }
msg_error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }

prompt() { echo -en "${PURPLE}$1${NC}" > /dev/tty 2>/dev/null || echo -en "${PURPLE}$1${NC}"; }

prompt_yesno() {
    local answer=""
    if [[ "${AUTO_YES}" == "y" ]] || deploy_noninteractive; then
        echo "y"
        return
    fi
    while true; do
        prompt "$1 (y/n): "
        if [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; then
            read -r answer < /dev/tty || answer=""
        else
            read -r answer || answer=""
        fi
        case "$answer" in
            [Yy]) echo "y"; return ;;
            [Nn]) echo "n"; return ;;
            *) msg_warn "Please answer 'y' or 'n'" ;;
        esac
    done
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

refresh_tool_path() {
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        \. "$NVM_DIR/nvm.sh"
        nvm use default >/dev/null 2>&1 || nvm use node >/dev/null 2>&1 || true
    fi
    if command_exists npm; then
        local npm_prefix
        npm_prefix=$(npm config get prefix 2>/dev/null || true)
        if [[ -n "${npm_prefix:-}" ]] && [[ -d "$npm_prefix/bin" ]]; then
            export PATH="$npm_prefix/bin:$PATH"
        fi
    fi
}

deploy_noninteractive() {
    [[ "${DEPLOY_NONINTERACTIVE:-}" == "1" ]] || [[ "${CI:-}" == "true" ]] || [[ "${DEBIAN_FRONTEND:-}" == "noninteractive" ]]
}

is_interactive() {
    if [[ -t 0 ]] && [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
        return 0
    fi
    if [[ -c /dev/tty ]] && [[ -w /dev/tty ]]; then
        return 0
    fi
    return 1
}

# --- Parse Command Line Arguments ---
UPGRADE_MODE="n"
while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade) UPGRADE_MODE="y"; shift ;;
        --hummingbot-api) HB_API_ONLY_MODE="y"; shift ;;
        --api) HB_API_ONLY_MODE="y"; shift ;; # alias for --hummingbot-api
        -y|--yes) AUTO_YES="y"; shift ;;
        -b|--branch) CONDOR_BRANCH="$2"; shift 2 ;;
        -p|--pr) CONDOR_PR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upgrade              Upgrade existing installation (Condor + optional API)"
            echo "  --hummingbot-api       Install or upgrade Hummingbot API only (Docker stack)"
            echo "  --api                  Same as --hummingbot-api (alias)"
            echo "  -y, --yes              Auto-confirm prompts (e.g. API reinstall)"
            echo "  -b, --branch NAME      Clone a specific branch of Condor"
            echo "  -p, --pr ID            Pull a specific PR ID from Condor"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Non-interactive Condor install: DEPLOY_NONINTERACTIVE=1 TELEGRAM_TOKEN=... ADMIN_USER_ID=..."
            echo ""
            echo "Examples:"
            echo "  $0                         # Fresh Condor (+ prompts for Telegram / optional API)"
            echo "  $0 --upgrade               # Pull repos, rebuild Condor, refresh Docker images"
            echo "  $0 --hummingbot-api        # Install or upgrade Hummingbot API stack only"
            echo "  $0 --hummingbot-api -y     # Same, auto-confirm reinstall prompts"
            exit 0
            ;;
        *)
            msg_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Absolute path for "bash /path/setup.sh …" hints. Empty when piped: `curl … | bash` leaves
# BASH_SOURCE unset, and `set -u` would error on ${BASH_SOURCE[0]}.
deploy_resolve_script_abs() {
    local s="${BASH_SOURCE[0]:-}"
    if [[ -n "$s" && -f "$s" ]]; then
        echo "$(cd "$(dirname "$s")" >/dev/null 2>&1 && pwd)/$(basename "$s")"
        return
    fi
    if [[ -f "$(pwd)/setup.sh" ]]; then
        echo "$(pwd)/setup.sh"
        return
    fi
    echo ""
}
DEPLOY_SCRIPT_ABS="$(deploy_resolve_script_abs)"

# Print either `bash <path> FLAGS` or `curl … | bash -s -- FLAGS` when path is unknown.
deploy_print_rerun() {
    local extra="$1"
    local suffix="${2:-}"
    if [[ -n "${DEPLOY_SCRIPT_ABS:-}" ]]; then
        echo -e "       ${GREEN}bash ${DEPLOY_SCRIPT_ABS} ${extra}${NC}${suffix}"
    else
        echo -e "       ${GREEN}curl -fsSL ${DEPLOY_SETUP_RAW_URL} | bash -s -- ${extra}${NC}${suffix}"
    fi
}

print_tmux_section() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Condor logs (read this first)${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Condor runs in tmux session ${CYAN}condor${NC}. To see live logs and tracebacks:"
    echo ""
    echo -e "       ${GREEN}${BOLD}tmux attach -t condor${NC}"
    echo ""
    echo -e "  • Detach without stopping Condor: press ${CYAN}Ctrl+B${NC} then ${CYAN}D${NC}"
    echo -e "  • Stop Condor completely: ${CYAN}tmux kill-session -t condor${NC}"
    echo ""
}

print_telegram_verify_section() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Telegram — verify the bot came online${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Next step: open the Telegram chat with your Condor bot."
    echo "  After the process starts successfully, Condor notifies admins with:"
    echo ""
    echo -e "       ${GREEN}\"Condor is online and ready.\"${NC}"
    echo ""
    echo "  If that message does not appear within a minute or two:"
    echo "  • Attach to tmux (command above) and read the error output."
    echo "  • Confirm condor/.env has a valid TELEGRAM_TOKEN and ADMIN_USER_ID."
    echo ""
}

print_hummingbot_api_manual_section() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Hummingbot API only (no Condor)${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Same installer, API-only mode (clones or upgrades ./hummingbot-api, pulls images):"
    echo ""
    deploy_print_rerun "--hummingbot-api"
    echo ""
    echo "  Fully manual equivalent (after Docker is installed and running):"
    echo ""
    echo -e "       ${GREEN}git clone --depth 1 ${API_REPO} hummingbot-api${NC}"
    echo -e "       ${GREEN}cd hummingbot-api && make setup && docker compose pull && make deploy${NC}"
    echo ""
    echo "  Condor's setup wizard expects the API repo as ../hummingbot-api when both live side by side."
    echo ""
}

print_condor_install_footer() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Later: upgrade Condor + sibling repos${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    deploy_print_rerun "--upgrade"
    echo ""
    print_hummingbot_api_manual_section
}

detect_os_arch() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7*|armv8*|armv*) ARCH="arm" ;;
        *) msg_warn "Unknown architecture: $ARCH, defaulting to amd64"; ARCH="amd64" ;;
    esac
    msg_info "Detected OS: $OS, Architecture: $ARCH"
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
        else
            msg_error "Docker daemon is not running."
        fi
        exit 1
    fi
    msg_ok "Docker daemon is running"
}

check_disk_space() {
    local required_mb=2048
    local available_mb=""
    if [[ "$OS" == "linux" ]] || [[ "$OS" == "darwin" ]]; then
        available_mb=$(df -m . 2>/dev/null | tail -1 | awk '{print $4}')
    else
        return
    fi
    if [[ -n "${available_mb:-}" ]] && [[ "$available_mb" -lt "$required_mb" ]]; then
        msg_error "Insufficient disk space. Need ${required_mb}MB, have ${available_mb}MB"
        exit 1
    fi
    msg_ok "Sufficient disk space available (${available_mb:-unknown}MB)"
}

install_nodejs_via_nvm() {
    msg_info "Installing Node.js via nvm..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash || return 1
    fi
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 24 >/dev/null 2>&1 || nvm install --lts >/dev/null 2>&1 || return 1
    nvm use 24 >/dev/null 2>&1 || nvm use --lts >/dev/null 2>&1 || true
    nvm alias default 24 >/dev/null 2>&1 || nvm alias default "$(nvm version)" >/dev/null 2>&1 || true
    export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"
}

# $1: all | condor-only (condor-only skips docker / compose requirement)
install_dependencies() {
    local mode="${1:-all}"
    msg_info "Checking dependencies for git clone / make..."

    MISSING_DEPS=()
    command_exists git || MISSING_DEPS+=("git")
    command_exists curl || MISSING_DEPS+=("curl")
    command_exists make || MISSING_DEPS+=("make")
    command_exists tmux || MISSING_DEPS+=("tmux")
    command_exists uv || MISSING_DEPS+=("uv")

    if ! command_exists node || ! command_exists npm; then
        MISSING_DEPS+=("nodejs/npm")
    fi

    if [[ "$mode" == "all" ]]; then
        command_exists docker || MISSING_DEPS+=("docker")
        if ! (command_exists docker-compose || (command_exists docker && docker compose version >/dev/null 2>&1)); then
            MISSING_DEPS+=("docker-compose")
        fi
    fi

    local label="git, curl, make, tmux, uv, node, npm"
    [[ "$mode" == "all" ]] && label="$label, docker, docker-compose"

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        msg_ok "Dependencies present ($label)"
        refresh_tool_path
        return
    fi

    msg_warn "Missing: ${MISSING_DEPS[*]}"

    if [[ "$OS" != "linux" ]]; then
        msg_error "Install these manually, then re-run:"
        printf '  - %s\n' "${MISSING_DEPS[@]}"
        exit 1
    fi

    local auto_install=false
    if deploy_noninteractive || [[ "${AUTO_YES}" == "y" ]] || ! is_interactive; then
        auto_install=true
    fi

    if ! $auto_install; then
        if ! is_interactive; then
            msg_error "Non-interactive shell: set DEPLOY_NONINTERACTIVE=1 or install deps manually."
            exit 1
        fi
        if [ "$(prompt_yesno "Install missing packages automatically?")" != "y" ]; then
            exit 1
        fi
    fi

    local SUDO_CMD=""
    if [[ $EUID -ne 0 ]]; then
        command_exists sudo || { msg_error "sudo required to install packages"; exit 1; }
        SUDO_CMD="sudo"
    fi

    if command_exists apt-get; then
        $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get update -qq
        PKG_INSTALL="$SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y"
    elif command_exists dnf; then
        $SUDO_CMD dnf check-update || true
        PKG_INSTALL="$SUDO_CMD dnf install -y"
    elif command_exists yum; then
        $SUDO_CMD yum install -y || true
        PKG_INSTALL="$SUDO_CMD yum install -y"
    elif command_exists apk; then
        $SUDO_CMD apk update
        PKG_INSTALL="$SUDO_CMD apk add"
    elif command_exists pacman; then
        $SUDO_CMD pacman -Sy --noconfirm
        PKG_INSTALL="$SUDO_CMD pacman -S --noconfirm"
    else
        msg_error "Unsupported package manager"
        exit 1
    fi

    for dep in "${MISSING_DEPS[@]}"; do
        case $dep in
            git|curl|make|tmux)
                msg_info "Installing $dep..."
                eval "$PKG_INSTALL $dep" || exit 1
                ;;
            uv)
                curl -LsSf https://astral.sh/uv/install.sh | sh || exit 1
                export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
                ;;
            nodejs/npm)
                install_nodejs_via_nvm || exit 1
                ;;
            docker)
                curl -fsSL https://get.docker.com -o get-docker.sh
                $SUDO_CMD sh get-docker.sh || exit 1
                rm -f get-docker.sh
                [[ $EUID -ne 0 ]] && $SUDO_CMD usermod -aG docker "$USER" || true
                if command_exists systemctl; then
                    $SUDO_CMD systemctl enable docker --now 2>/dev/null || true
                fi
                ;;
            docker-compose)
                if command_exists apt-get; then
                    eval "$PKG_INSTALL docker-compose-plugin" || eval "$PKG_INSTALL docker-compose" || exit 1
                else
                    eval "$PKG_INSTALL docker-compose" || exit 1
                fi
                ;;
            *)
                msg_info "Installing $dep..."
                eval "$PKG_INSTALL $dep" || exit 1
                ;;
        esac
    done

    msg_ok "Dependencies installed"
    refresh_tool_path
}

ensure_condor_env_noninteractive() {
    # After clone, before make install — seed .env so setup-environment skips prompts.
    if [[ -f "$CONDOR_DIR/.env" ]]; then
        return 0
    fi
    if ! deploy_noninteractive; then
        return 0
    fi
    if [[ -z "${TELEGRAM_TOKEN:-}" ]] || [[ -z "${ADMIN_USER_ID:-}" ]]; then
        msg_error "DEPLOY_NONINTERACTIVE requires TELEGRAM_TOKEN and ADMIN_USER_ID in the environment."
        exit 1
    fi
    msg_info "Writing $CONDOR_DIR/.env (non-interactive)"
    umask 077
    cat > "$CONDOR_DIR/.env" << EOF
TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
ADMIN_USER_ID=${ADMIN_USER_ID}
DEPLOY_HUMMINGBOT_API=${DEPLOY_HUMMINGBOT_API:-false}
EOF
    umask 022
}

ensure_api_dotenv_unattended() {
    # Skip if setup already ran; otherwise write defaults when unattended so make setup does not prompt.
    local api_root="$1"
    [[ -f "$api_root/.env" ]] && return 0
    if [[ -t 0 ]] && [[ -t 1 ]] && [[ "${AUTO_YES}" != "y" ]] && ! deploy_noninteractive; then
        return 0
    fi
    local abs
    abs="$(cd "$api_root" && pwd)"
    msg_info "Writing default $api_root/.env for unattended setup"
    umask 077
    cat > "$api_root/.env" << EOF
USERNAME=${HUMMINGBOT_API_USERNAME:-admin}
PASSWORD=${HUMMINGBOT_API_PASSWORD:-admin}
CONFIG_PASSWORD=${HUMMINGBOT_CONFIG_PASSWORD:-admin}
DEBUG_MODE=false
BROKER_HOST=localhost
BROKER_PORT=1883
BROKER_USERNAME=admin
BROKER_PASSWORD=password
DATABASE_URL=postgresql+asyncpg://hbot:hummingbot-api@localhost:5432/hummingbot_api
GATEWAY_URL=http://localhost:15888
GATEWAY_PASSPHRASE=${HUMMINGBOT_CONFIG_PASSWORD:-admin}
BOTS_PATH=$abs
EOF
    umask 022
}

update_condor_config() {
    local config_file="$CONDOR_DIR/config.yml"
    local env_file="$CONDOR_DIR/.env"

    if [ ! -d "$CONDOR_DIR" ] || [ ! -f "$env_file" ]; then
        return 0
    fi

    local admin_user_id
    admin_user_id=$(grep "^ADMIN_USER_ID=" "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    [[ -n "$admin_user_id" ]] || return 0

    local current_date
    current_date=$(date "+%Y-%m-%d")

    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        msg_info "Creating $config_file with template..."
        cat > "$config_file" << 'CONFIGEOF'
servers:
  local:
    host: localhost
    port: 8000
    username: admin
    password: admin

default_server: local

admin_id: ADMIN_USER_ID_PLACEHOLDER

users: {}

server_access:
  local:
    owner_id: ADMIN_USER_ID_PLACEHOLDER
    created_at: null
    shared_with: {}

chat_defaults: 
    ADMIN_USER_ID_PLACEHOLDER: local

version: 1
CONFIGEOF
    fi

    if grep -q "ADMIN_USER_ID_PLACEHOLDER" "$config_file" 2>/dev/null; then
        sed -i.bak "s/ADMIN_USER_ID_PLACEHOLDER/$admin_user_id/g" "$config_file"
        rm -f "$config_file.bak"
        msg_ok "Updated admin_id in $config_file"
    fi

    if grep -q "DATE_PLACEHOLDER" "$config_file" 2>/dev/null; then
        sed -i.bak "s/DATE_PLACEHOLDER/$current_date/g" "$config_file"
        rm -f "$config_file.bak"
    fi
}

sync_condor_config_api_credentials() {
    local condor_config="$CONDOR_DIR/config.yml"
    local api_env="$API_DIR/.env"

    [[ -f "$condor_config" && -f "$api_env" ]] || return 0

    local api_username api_password
    api_username=$(grep "^USERNAME=" "$api_env" 2>/dev/null | cut -d= -f2-)
    api_password=$(grep "^PASSWORD=" "$api_env" 2>/dev/null | cut -d= -f2-)

    [[ -n "$api_username" && -n "$api_password" ]] || return 0

    if grep -A5 "servers:" "$condor_config" | grep -q "username:"; then
        sed -i.bak "/servers:/,/^[^ ]/ s/username: .*/username: $api_username/" "$condor_config"
        rm -f "$condor_config.bak"
    fi
    if grep -A5 "servers:" "$condor_config" | grep -q "password:"; then
        sed -i.bak "/servers:/,/^[^ ]/ s/password: .*/password: $api_password/" "$condor_config"
        rm -f "$condor_config.bak"
    fi
    msg_ok "Synced Condor config.yml with API .env credentials"
}

run_condor_make_install() {
    if [ ! -d "$CONDOR_DIR" ]; then
        msg_error "Condor directory not found"
        exit 1
    fi
    msg_info "Running make install (Condor Makefile)..."
    (
        cd "$CONDOR_DIR"
        export SKIP_SETUP_RESTART=1
        make install
    ) || exit 1

    msg_info "Running make build-frontend..."
    (cd "$CONDOR_DIR" && make build-frontend) || exit 1
}

start_condor_tmux() {
    msg_info "Starting Condor in tmux..."
    if tmux has-session -t condor 2>/dev/null; then
        tmux kill-session -t condor
    fi
    if [ -d "$CONDOR_DIR" ]; then
        (cd "$CONDOR_DIR" && tmux new-session -d -s condor "uv run python main.py")
        sleep 2
        if tmux has-session -t condor 2>/dev/null; then
            msg_ok "Condor session 'condor' started (tmux attach -t condor)"
        else
            msg_error "Failed to start Condor tmux session"
        fi
    fi
}

pull_hummingbot_images() {
    msg_info "Pulling Hummingbot Docker images..."
    docker pull hummingbot/hummingbot:latest || msg_warn "Could not pull hummingbot/hummingbot:latest"
    docker pull hummingbot/hummingbot-api:latest || msg_warn "Could not pull hummingbot/hummingbot-api:latest"
}

run_upgrade() {
    msg_info "Starting upgrade..."

    if [ -d "$CONDOR_DIR" ]; then
        msg_info "Updating Condor (git pull)..."
        (cd "$CONDOR_DIR" && git pull) || msg_warn "Condor git pull failed"
        refresh_tool_path
        msg_info "Rebuilding Condor (make install && make build-frontend)..."
        (
            cd "$CONDOR_DIR"
            export SKIP_SETUP_RESTART=1
            make install
        ) || msg_warn "Condor make install failed"
        (cd "$CONDOR_DIR" && make build-frontend) || msg_warn "Condor build-frontend failed"
    fi

    if [ -d "$API_DIR" ]; then
        msg_info "Updating Hummingbot API (git pull)..."
        (cd "$API_DIR" && git pull) || msg_warn "API git pull failed"
        detect_docker_compose
        msg_info "Pulling compose images and restarting API stack..."
        (cd "$API_DIR" && eval "$DOCKER_COMPOSE pull") || msg_warn "compose pull failed"
        pull_hummingbot_images
        (cd "$API_DIR" && eval "$DOCKER_COMPOSE up -d --remove-orphans") || msg_warn "compose up failed"
    fi

    if [ -d "$CONDOR_DIR" ]; then
        start_condor_tmux
    fi

    update_condor_config
    sync_condor_config_api_credentials

    msg_ok "Upgrade complete"
    echo ""
    if [[ -d "$CONDOR_DIR" ]]; then
        print_tmux_section
        print_telegram_verify_section
    fi
    if [[ -d "$API_DIR" ]]; then
        echo -e "${BOLD}  Hummingbot API (Docker)${NC}"
        echo -e "  Status / logs:  ${GREEN}cd ${API_DIR} && ${DOCKER_COMPOSE} ps${NC}"
        echo -e "  Follow logs:     ${GREEN}cd ${API_DIR} && ${DOCKER_COMPOSE} logs -f${NC}"
        echo -e "  REST docs:       ${CYAN}http://localhost:8000/docs${NC}"
        echo ""
    fi
    print_condor_install_footer
}

install_api_standalone() {
    SCRIPT_DIR="$(pwd)"
    msg_info "Standalone Hummingbot API in $SCRIPT_DIR/$API_DIR"

    CREATED_DIRS+=("$API_DIR")
    git clone --depth 1 "$API_REPO" "$API_DIR" || exit 1

    ensure_api_dotenv_unattended "$SCRIPT_DIR/$API_DIR"

    (cd "$API_DIR" && make setup) || exit 1

    msg_info "Pulling latest images from docker-compose.yml (postgres, emqx, API)..."
    (cd "$API_DIR" && eval "$DOCKER_COMPOSE pull") || exit 1
    pull_hummingbot_images

    (cd "$API_DIR" && make deploy) || exit 1

    msg_ok "Hummingbot API deployed"
    print_api_post_install_summary "$SCRIPT_DIR"
}

print_api_post_install_summary() {
    local base="$1"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Hummingbot API is running${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • REST + Swagger:  http://localhost:8000/docs"
    echo "  • EMQX dashboard:  http://localhost:18083  (default login is often admin / public — see EMQX docs)"
    echo ""
    echo -e "  Check containers:  ${GREEN}cd ${base}/${API_DIR} && ${DOCKER_COMPOSE} ps${NC}"
    echo -e "  Stream logs:       ${GREEN}cd ${base}/${API_DIR} && ${DOCKER_COMPOSE} logs -f${NC}"
    echo ""
    echo "  Refresh images later (same as this installer’s API upgrade path):"
    echo -e "       ${GREEN}cd ${base}/${API_DIR} && git pull && docker compose pull && docker compose up -d${NC}"
    echo ""
    echo "  Or re-run the installer (pulls repo + compose + client images):"
    deploy_print_rerun "--hummingbot-api" "  ${CYAN}# use -y if prompted${NC}"
    echo ""
}

clone_condor() {
    if [ -n "$CONDOR_PR" ]; then
        CREATED_DIRS+=("$CONDOR_DIR")
        git clone "$CONDOR_REPO" "$CONDOR_DIR"
        (cd "$CONDOR_DIR" && git fetch origin "pull/$CONDOR_PR/head:pr-$CONDOR_PR" && git checkout "pr-$CONDOR_PR") || exit 1
    elif [ -n "$CONDOR_BRANCH" ]; then
        CREATED_DIRS+=("$CONDOR_DIR")
        git clone --depth 1 -b "$CONDOR_BRANCH" "$CONDOR_REPO" "$CONDOR_DIR" || exit 1
    else
        CREATED_DIRS+=("$CONDOR_DIR")
        git clone --depth 1 "$CONDOR_REPO" "$CONDOR_DIR" || exit 1
    fi
}

run_fresh_install() {
    SCRIPT_DIR="$(pwd)"
    msg_ok "Installation directory: $SCRIPT_DIR"

    echo ""
    echo -e "${BLUE}Installing Condor${NC}"
    clone_condor

    [[ -f "$CONDOR_DIR/Makefile" ]] || { msg_error "Condor Makefile missing"; exit 1; }

    ensure_condor_env_noninteractive
    run_condor_make_install

    update_condor_config
    start_condor_tmux

    echo ""
    msg_ok "Installation complete"
    print_tmux_section
    print_telegram_verify_section
    print_condor_install_footer
}

# --- Main ---
clear 2>/dev/null || true
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

if [ "$HB_API_ONLY_MODE" = "y" ]; then
    install_dependencies "all"
    check_docker_running
    detect_docker_compose

    if [ -d "$API_DIR" ]; then
        msg_warn "Directory exists: $API_DIR"
        if [ "$(prompt_yesno "Upgrade existing API (git pull + compose pull + deploy)?")" = "y" ]; then
            (cd "$API_DIR" && git pull) || exit 1
            msg_info "Pulling latest Compose service images..."
            (cd "$API_DIR" && eval "$DOCKER_COMPOSE pull") || exit 1
            pull_hummingbot_images
            (cd "$API_DIR" && eval "$DOCKER_COMPOSE up -d --remove-orphans") || exit 1
            msg_ok "Hummingbot API upgraded"
            print_api_post_install_summary "$(pwd)"
        fi
    else
        install_api_standalone
    fi
    exit 0
fi

should_upgrade() {
    [[ "$UPGRADE_MODE" == "y" ]] \
        || [[ -d "$CONDOR_DIR/.git" ]] \
        || ([[ -d "$CONDOR_DIR" ]] && [[ -d "$API_DIR" ]]) \
        || ([[ -d "$CONDOR_DIR" ]] && [[ -f "$CONDOR_DIR/docker-compose.yml" ]])
}

if should_upgrade; then
    if [ -d "$API_DIR" ]; then
        install_dependencies "all"
        check_docker_running
        detect_docker_compose
    else
        install_dependencies "condor-only"
    fi
    refresh_tool_path
    run_upgrade
else
    install_dependencies "condor-only"
    refresh_tool_path
    run_fresh_install
fi
