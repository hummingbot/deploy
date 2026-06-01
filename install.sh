#!/usr/bin/env bash
#
# Hummingbot installer — one entry point to install Hummingbot or Condor.
#
#   curl -fsSL https://hummingbot.org/install.sh | bash                 # interactive wizard
#   curl -fsSL https://hummingbot.org/install.sh | bash -s -- --condor  # Condor (existing process)
#   curl -fsSL https://hummingbot.org/install.sh | bash -s -- --doctor  # health check only
#
# The user picks Hummingbot or Condor (in the website UI, or this wizard).
#   • Condor      → routed to the EXISTING, unchanged deploy/setup.sh. We don't reimplement it.
#   • Hummingbot  → the client install + `hummingbot` wrapper + LLM plugin (built out in P2).
#
# See apps/docs/INSTALL_WIZARD_PLAN.md in hummingbot/hummingbot-web.

main() {
  set -euo pipefail

  REPO_RAW="${DEPLOY_RAW_BASE:-https://raw.githubusercontent.com/hummingbot/deploy/main}"
  BASE_DIR="${HUMMINGBOT_INSTALL:-$HOME}"
  API_DIR="$BASE_DIR/hummingbot-api"
  CONDOR_DIR="$BASE_DIR/condor"
  STATE_DIR="$HOME/.hummingbot"

  PRODUCT=""        # condor | hummingbot   (empty -> ask)
  MODE="install"    # install | upgrade | doctor

  ui_init
  parse_args "$@"

  [[ "$MODE" == "doctor" ]] && { run_doctor; exit $?; }

  banner
  detect_platform
  require_cmd curl

  [[ -z "$PRODUCT" ]] && PRODUCT="$(choose_product)"
  case "$PRODUCT" in
    condor)     run_condor ;;       # exec's the existing installer — never returns
    hummingbot) install_hummingbot ;;
    *) error "Unknown product: $PRODUCT" ;;
  esac
}

# ── UI helpers ────────────────────────────────────────────────────────────────
ui_init() {
  if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[0;31m'; GRN=$'\033[0;32m'
    YEL=$'\033[1;33m'; CYN=$'\033[0;36m'; NC=$'\033[0m'
  else
    BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; CYN=""; NC=""
  fi
}
info()    { printf '%s\n' "${CYN}→${NC} $*"; }
warn()    { printf '%s\n' "${YEL}!${NC} $*" >&2; }
success() { printf '%s\n' "${GRN}✓${NC} $*"; }
error()   { printf '%s\n' "${RED}✗ $*${NC}" >&2; exit 1; }
step()    { printf '\n%s\n' "${BOLD}$*${NC}"; }
tildify() { printf '%s' "${1/#$HOME/~}"; }  # replacement '~' is literal; no tilde expansion here

banner() {
  printf '\n%s\n%s\n\n' "${BOLD}🐦 Hummingbot installer${NC}" "${DIM}open-source framework for agentic trading${NC}"
}

# Under `curl | bash`, stdin is the script — interactive input must come from /dev/tty.
is_promptable() { [[ -t 1 && -r /dev/tty ]]; }

# prompt VAR "Question" "default"
prompt() {
  local __var="$1" __q="$2" __def="${3:-}" __ans=""
  if ! is_promptable; then
    [[ -n "$__def" ]] && { printf -v "$__var" '%s' "$__def"; return 0; }
    error "Need a value for '$__q' but no terminal is available."
  fi
  if [[ -n "$__def" ]]; then printf '%s ' "${CYN}?${NC} $__q ${DIM}[$__def]${NC}:" > /dev/tty
  else printf '%s ' "${CYN}?${NC} $__q:" > /dev/tty; fi
  read -r __ans < /dev/tty || true
  printf -v "$__var" '%s' "${__ans:-$__def}"
}

# ── args / platform ───────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: install.sh [options]
  --condor          Install Condor (routes to the existing deploy/setup.sh)
  --hummingbot      Install the Hummingbot client            (coming in P2)
  --upgrade         Update an existing install in place
  --doctor          Run the health check and exit
  --dir <path>      Base directory (default: $HOME)
  -h, --help        Show this help
EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --condor)     PRODUCT="condor" ;;
      --hummingbot) PRODUCT="hummingbot" ;;
      --upgrade)    MODE="upgrade" ;;
      --doctor)     MODE="doctor" ;;
      --dir)        shift; BASE_DIR="${1:?--dir needs a path}"; API_DIR="$BASE_DIR/hummingbot-api"; CONDOR_DIR="$BASE_DIR/condor" ;;
      -h|--help)    usage ;;
      *) warn "Ignoring unknown option: $1" ;;
    esac
    shift
  done
}

detect_platform() {
  local platform; platform="$(uname -ms)"
  case "$platform" in
    Darwin\ arm64|Darwin\ x86_64) OS="darwin" ;;
    Linux\ x86_64|Linux\ aarch64|Linux\ arm64) OS="linux" ;;
    *) error "Unsupported platform: $platform. Windows users: run inside WSL2 (Windows support is coming)." ;;
  esac
  if [[ "$OS" == "linux" ]] && command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
    error "musl libc (Alpine) is not supported. Use a glibc-based distro."
  fi
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."; }

# ── wizard ────────────────────────────────────────────────────────────────────
choose_product() {
  is_promptable || error "No product selected and no terminal available. Re-run with --condor or --hummingbot."
  {
    printf '%s\n' "${BOLD}What do you want to install?${NC}"
    printf '  %s\n' "1) Condor      — Telegram + AI trading agents (Docker)"
    printf '  %s\n' "2) Hummingbot  — the trading client / framework"
  } > /dev/tty
  local choice=""; prompt choice "Choose 1 or 2" "1"
  case "$choice" in
    2|hummingbot) echo "hummingbot" ;;
    *) echo "condor" ;;
  esac
}

# ── Condor: route to the existing installer (unchanged) ───────────────────────
run_condor() {
  step "Installing Condor (Telegram + AI trading agents)"
  local args=(); [[ "$MODE" == "upgrade" ]] && args+=("--upgrade")

  # Prefer a sibling setup.sh when run from a deploy checkout; otherwise fetch the canonical one.
  local setup; setup="$(sibling_setup)"
  if [[ -n "$setup" ]]; then
    info "Handing off to the existing Condor installer: $(tildify "$setup")"
  else
    info "Fetching the existing Condor installer (setup.sh)…"
    setup="$(mktemp)"; curl -fsSL "$REPO_RAW/setup.sh" -o "$setup" \
      || error "Could not download the Condor installer."
  fi

  # setup.sh reads prompts from stdin; under `curl | bash` hand it the terminal.
  if is_promptable; then exec bash "$setup" "${args[@]}" < /dev/tty
  else exec bash "$setup" "${args[@]}"; fi
}

sibling_setup() {
  local src="${BASH_SOURCE[0]:-}"; [[ -f "$src" ]] || return 0
  local dir; dir="$(cd "$(dirname "$src")" && pwd)"
  [[ -f "$dir/setup.sh" ]] && printf '%s' "$dir/setup.sh"
}

# ── Hummingbot client (P2) ────────────────────────────────────────────────────
install_hummingbot() {
  step "Hummingbot client"
  warn "The Hummingbot client path arrives in the next installer release (P2)."
  cat <<EOF

For now, install the client directly:

  ${BOLD}Docker${NC}
    git clone https://github.com/hummingbot/hummingbot.git "$BASE_DIR/hummingbot"
    cd "$BASE_DIR/hummingbot" && make setup && make deploy && docker attach hummingbot

  ${BOLD}Source${NC}
    git clone https://github.com/hummingbot/hummingbot.git "$BASE_DIR/hummingbot"
    cd "$BASE_DIR/hummingbot" && ./install && conda activate hummingbot && ./compile && ./start

Docs: https://hummingbot.org/client/installation/

${DIM}P2 will add: this path wired in, the `hummingbot start/update/doctor` wrapper, and the LLM plugin.${NC}
EOF
}

# ── doctor ────────────────────────────────────────────────────────────────────
run_doctor() {
  step "Health check"
  local fails=0
  _ok()   { success "$1"; }
  _bad()  { printf '%s\n' "${RED}✗${NC} $1 ${DIM}— $2${NC}"; fails=$((fails+1)); }
  _warn() { printf '%s\n' "${YEL}!${NC} $1 ${DIM}— $2${NC}"; }

  command -v docker >/dev/null 2>&1 && _ok "docker installed" || _bad "docker missing" "install Docker Desktop"
  if command -v docker >/dev/null 2>&1; then
    docker info >/dev/null 2>&1 && _ok "docker daemon running" || _bad "docker daemon down" "start Docker"
    docker compose version >/dev/null 2>&1 && _ok "docker compose available" || _warn "docker compose missing" "install Compose v2"
  fi
  command -v uv   >/dev/null 2>&1 && _ok "uv installed"   || _warn "uv missing"   "needed for Condor"
  command -v tmux >/dev/null 2>&1 && _ok "tmux installed" || _warn "tmux missing" "needed to run Condor"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^hummingbot-api$'; then
    _ok "hummingbot-api container up"
  else _warn "hummingbot-api not running" "cd $(tildify "$API_DIR") && docker compose up -d"; fi
  if curl -fsS -o /dev/null --max-time 3 http://localhost:8000/docs 2>/dev/null; then
    _ok "API reachable on :8000"
  else _warn "API not answering on :8000" "give it a few seconds after first start"; fi

  if tmux has-session -t condor 2>/dev/null; then _ok "Condor running (attach: tmux attach -t condor)"
  else _warn "Condor not running" "tmux session 'condor' not found"; fi

  printf '\n'
  if [[ "$fails" -gt 0 ]]; then warn "$fails critical check(s) failed."; return 1; fi
  success "No critical failures."; return 0
}

# Run — this MUST be the last line (truncation safety for curl | bash).
main "$@"
