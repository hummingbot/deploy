#!/usr/bin/env bash
#
# install-hummingbot.sh — install the Hummingbot client (Docker or source) + the `hummingbot` wrapper.
#
# The website's "Hummingbot" tab points here; the Hummingbot-vs-Condor choice happens in the UI,
# so this script only installs Hummingbot. (Condor has its own installer: install-condor.sh.)
#
#   curl -fsSL https://hummingbot.org/install-hummingbot.sh | bash                # interactive
#   curl -fsSL https://hummingbot.org/install-hummingbot.sh | bash -s -- --docker
#   curl -fsSL https://hummingbot.org/install-hummingbot.sh | bash -s -- --source --dev
#   curl -fsSL https://hummingbot.org/install-hummingbot.sh | bash -s -- --doctor
#
# Env overrides: HUMMINGBOT_INSTALL (base dir, default $HOME).
# See apps/docs/INSTALL_WIZARD_PLAN.md in hummingbot/hummingbot-web.

main() {
  set -euo pipefail

  REPO="${GITHUB_BASE:-https://github.com}/hummingbot/hummingbot.git"
  BASE_DIR="${HUMMINGBOT_INSTALL:-$HOME}"
  HB_DIR="$BASE_DIR/hummingbot"
  STATE_DIR="$HOME/.hummingbot"
  BIN_DIR="$HOME/.local/bin"

  METHOD=""          # docker | source | develop   (empty -> ask)
  MODE="install"     # install | doctor
  CHANNEL="latest"   # latest | dev
  INSTALL_PLUGIN=1
  ASSUME_YES=0

  ui_init
  parse_args "$@"
  [[ "$MODE" == "doctor" ]] && { run_doctor; exit $?; }

  banner
  detect_platform
  require_cmd curl
  require_cmd git

  [[ -z "$METHOD" ]] && METHOD="$(choose_method)"
  case "$METHOD" in
    docker)  install_docker ;;
    source)  install_source ;;
    develop) install_develop ;;
    *) error "Unknown method: $METHOD" ;;
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
tildify() { printf '%s' "${1/#$HOME/~}"; }

banner() {
  printf '\n%s\n%s\n\n' "${BOLD}🐦 Hummingbot installer${NC}" "${DIM}the open-source client for agentic trading${NC}"
}

is_promptable() { [[ -t 1 && -r /dev/tty ]]; }

prompt() {  # prompt VAR "Question" "default"
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

# ── args / platform / deps ────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: install-hummingbot.sh [options]
  --docker          Run the client via Docker (recommended)
  --source          Build and run the client from source (conda)
  --develop         Develop core / API / Gateway from source      (coming in P3)
  --dev             Use the development channel (default: latest)
  --no-plugin       Skip the default Claude/LLM plugin
  --dir <path>      Base directory (default: $HOME)
  --doctor          Run the health check and exit
  -y, --yes         Assume yes to prompts
  -h, --help        Show this help
EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --docker)    METHOD="docker" ;;
      --source)    METHOD="source" ;;
      --develop)   METHOD="develop" ;;
      --dev)       CHANNEL="dev" ;;
      --latest)    CHANNEL="latest" ;;
      --no-plugin) INSTALL_PLUGIN=0 ;;
      --dir)       shift; BASE_DIR="${1:?--dir needs a path}"; HB_DIR="$BASE_DIR/hummingbot" ;;
      --doctor)    MODE="doctor" ;;
      -y|--yes)    ASSUME_YES=1 ;;
      -h|--help)   usage ;;
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

ensure_docker() {
  command -v docker >/dev/null 2>&1 || error "Docker is required. Install Docker Desktop: https://docker.com/products/docker-desktop"
  docker info >/dev/null 2>&1 || error "Docker is installed but the daemon isn't running. Start Docker and re-run."
  docker compose version >/dev/null 2>&1 || error "Docker Compose v2 is required (docker compose)."
}

# Find conda, or install Miniforge. Leaves `conda` on PATH for the Makefile.
ensure_conda() {
  if ! command -v conda >/dev/null 2>&1; then
    local c
    for c in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3" "/opt/conda"; do
      if [[ -f "$c/etc/profile.d/conda.sh" ]]; then . "$c/etc/profile.d/conda.sh"; break; fi
    done
  fi
  if ! command -v conda >/dev/null 2>&1; then
    info "No conda found — installing Miniforge…"
    local mf; mf="$(mktemp)"
    curl -fsSL -o "$mf" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
      || error "Failed to download Miniforge."
    bash "$mf" -b -p "$HOME/miniforge3" || error "Miniforge install failed."
    . "$HOME/miniforge3/etc/profile.d/conda.sh"
  fi
  command -v conda >/dev/null 2>&1 || error "conda is not available."
  export PATH="$(conda info --base)/bin:$PATH"   # ensure `conda` is on PATH for make
}

# Run a native command, giving it the terminal when we have one (Makefiles sometimes prompt).
run_native() { if is_promptable; then "$@" < /dev/tty; else "$@"; fi; }

clone_or_update() {  # clone_or_update <branch>
  local branch="$1"
  if [[ -d "$HB_DIR/.git" ]]; then
    info "Updating $(tildify "$HB_DIR")…"
    git -C "$HB_DIR" fetch --depth 1 origin "$branch" 2>/dev/null || git -C "$HB_DIR" fetch origin 2>/dev/null || true
    git -C "$HB_DIR" checkout "$branch" 2>/dev/null || true
    git -C "$HB_DIR" pull --ff-only 2>/dev/null || warn "Could not fast-forward; leaving checkout as-is."
  else
    info "Cloning Hummingbot ($branch) into $(tildify "$HB_DIR")…"
    git clone --depth 1 --branch "$branch" "$REPO" "$HB_DIR" 2>/dev/null \
      || git clone "$REPO" "$HB_DIR" || error "Failed to clone $REPO"
    git -C "$HB_DIR" checkout "$branch" 2>/dev/null || true
  fi
}

branch_for_channel() { [[ "$CHANNEL" == "dev" ]] && echo "development" || echo "master"; }

# ── method wizard ─────────────────────────────────────────────────────────────
choose_method() {
  is_promptable || error "No method selected and no terminal available. Re-run with --docker or --source."
  {
    printf '%s\n' "${BOLD}How do you want to run Hummingbot?${NC}"
    printf '  %s\n' "1) Docker  — run the client in a container (recommended)"
    printf '  %s\n' "2) Source  — build from source with conda"
    printf '  %s\n' "3) Develop — core / API / Gateway from source (coming in P3)"
  } > /dev/tty
  local choice=""; prompt choice "Choose 1, 2 or 3" "1"
  case "$choice" in
    2|source)  echo "source" ;;
    3|develop) echo "develop" ;;
    *)         echo "docker" ;;
  esac
}

# ── Docker install ────────────────────────────────────────────────────────────
install_docker() {
  step "Installing Hummingbot client (Docker, channel: $CHANNEL)"
  ensure_docker
  mkdir -p "$BASE_DIR"
  clone_or_update "$(branch_for_channel)"

  if [[ "$CHANNEL" == "dev" && -f "$HB_DIR/docker-compose.yml" ]]; then
    info "Pinning image to :development…"
    sed -i.bak -E 's#(image:[[:space:]]*hummingbot/hummingbot):[^[:space:]]+#\1:development#' "$HB_DIR/docker-compose.yml" \
      && rm -f "$HB_DIR/docker-compose.yml.bak"
  fi

  info "Configuring (make setup)…"
  ( cd "$HB_DIR" && run_native make setup )
  info "Pulling image + starting the container (make deploy)…"
  ( cd "$HB_DIR" && make deploy ) || error "make deploy failed."

  finish "docker"
}

# ── Source install ────────────────────────────────────────────────────────────
install_source() {
  step "Installing Hummingbot client (source, channel: $CHANNEL)"
  ensure_conda
  mkdir -p "$BASE_DIR"
  clone_or_update "$(branch_for_channel)"

  info "Building the conda env + compiling (make install — this takes a while)…"
  ( cd "$HB_DIR" && run_native make install ) || error "make install failed."

  finish "source"
}

# ── Develop (P3 stub) ─────────────────────────────────────────────────────────
install_develop() {
  step "Develop Hummingbot / API / Gateway"
  warn "The multi-component developer path arrives in P3."
  cat <<EOF

For now, set up the source dev environment directly:

  git clone $REPO "$HB_DIR"
  cd "$HB_DIR" && ./install && conda activate hummingbot && ./compile

API and Gateway: https://hummingbot.org/installation/
EOF
}

# ── shared finish: wrapper + state + plugin + doctor + next steps ─────────────
finish() {  # finish <method>
  METHOD="$1"
  install_wrapper
  write_state
  maybe_install_plugin
  run_doctor || true
  print_next_steps
}

install_wrapper() {
  mkdir -p "$BIN_DIR"
  info "Installing the ${BOLD}hummingbot${NC} command → $(tildify "$BIN_DIR/hummingbot")"
  cat > "$BIN_DIR/hummingbot" <<'WRAP'
#!/usr/bin/env bash
# hummingbot — thin wrapper installed by install-hummingbot.sh.
# Verbs: start · update · doctor · --version. It resolves *where* to run
# bin/hummingbot_quickstart.py (source conda env / docker container) and hides
# conda activate / docker attach. Not a lifecycle CLI — see INSTALL_WIZARD_PLAN.md.
set -euo pipefail

STATE="$HOME/.hummingbot/state.json"
[[ -f "$STATE" ]] || { echo "No Hummingbot install found. Run install-hummingbot.sh first." >&2; exit 1; }

jget() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$STATE" | head -1; }
jset() { sed -i.bak "s/\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$1\": \"$2\"/" "$STATE" && rm -f "$STATE.bak"; }

METHOD="$(jget method)"; BASE_DIR="$(jget base_dir)"; CHANNEL="$(jget channel)"
HB_DIR="$BASE_DIR/hummingbot"

branch_for() { [[ "$1" == dev ]] && echo development || echo master; }   # source branch
tag_for()    { [[ "$1" == dev ]] && echo development || echo latest; }   # docker image tag

usage() {
  cat <<USAGE
hummingbot — manage your Hummingbot client ($METHOD, channel: $CHANNEL)

  hummingbot start [--v2 FILE | -f FILE] [-p PASSWORD] [--headless]
                          launch the client REPL, or autostart a strategy config
  hummingbot update [--dev | --latest]
                          pull the newest version (and switch channel)
  hummingbot doctor       quick health check for this install
  hummingbot --version    print the installed version
USAGE
}

cmd="${1:-start}"; [[ $# -gt 0 ]] && shift || true
case "$cmd" in
  start)
    case "$METHOD" in
      source) cd "$HB_DIR"; exec conda run -n hummingbot --no-capture-output ./bin/hummingbot_quickstart.py "$@" ;;
      docker) docker start hummingbot >/dev/null 2>&1 || true; exec docker attach hummingbot ;;
      *) echo "Unknown method '$METHOD' in $STATE." >&2; exit 1 ;;
    esac ;;
  update)
    for a in "$@"; do case "$a" in --dev) CHANNEL=dev ;; --latest) CHANNEL=latest ;; esac; done
    case "$METHOD" in
      source)
        cd "$HB_DIR"
        b="$(branch_for "$CHANNEL")"
        git fetch --depth 1 origin "$b" 2>/dev/null || git fetch origin 2>/dev/null || true
        git checkout "$b" 2>/dev/null || git checkout -B "$b" "origin/$b" 2>/dev/null || true
        git pull --ff-only 2>/dev/null || true
        make install ;;
      docker)
        cd "$HB_DIR"
        if [[ -f docker-compose.yml ]]; then
          sed -i.bak -E "s#(image:[[:space:]]*hummingbot/hummingbot):[^[:space:]]+#\1:$(tag_for "$CHANNEL")#" docker-compose.yml \
            && rm -f docker-compose.yml.bak
        fi
        docker compose pull && docker compose up -d ;;
      *) echo "Unknown method '$METHOD'." >&2; exit 1 ;;
    esac
    jset channel "$CHANNEL"
    echo "✓ Updated ($METHOD, channel: $CHANNEL)." ;;
  doctor)
    case "$METHOD" in
      source) conda env list 2>/dev/null | awk '{print $1}' | grep -qx hummingbot \
                && echo "✓ hummingbot conda env present" \
                || { echo "✗ hummingbot conda env missing — run: install-hummingbot.sh --source" >&2; exit 1; } ;;
      docker) docker ps --format '{{.Names}}' 2>/dev/null | grep -qx hummingbot \
                && echo "✓ hummingbot container running" \
                || echo "! hummingbot container not running — run: hummingbot start" ;;
    esac ;;
  -v|--version|version)
    [[ -f "$HB_DIR/hummingbot/VERSION" ]] && cat "$HB_DIR/hummingbot/VERSION" || echo "unknown" ;;
  -h|--help|help) usage ;;
  *) echo "unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac
WRAP
  chmod +x "$BIN_DIR/hummingbot"
  ensure_path
}

# Add ~/.local/bin to PATH (idempotent, shell-aware).
ensure_path() {
  case ":$PATH:" in *":$BIN_DIR:"*) return 0 ;; esac
  local rc line="export PATH=\"\$HOME/.local/bin:\$PATH\""
  case "$(basename "${SHELL:-}")" in
    zsh)  rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash) [[ "$OS" == "darwin" ]] && rc="$HOME/.bash_profile" || rc="$HOME/.bashrc" ;;
    *)    rc="$HOME/.profile" ;;
  esac
  if [[ -w "$(dirname "$rc")" ]] && ! { [[ -f "$rc" ]] && grep -qF "$BIN_DIR" "$rc"; }; then
    { printf '\n# Hummingbot\n%s\n' "$line"; } >> "$rc"
    info "Added ~/.local/bin to PATH in $(tildify "$rc") — open a new shell or: ${BOLD}source $(tildify "$rc")${NC}"
  fi
  export PATH="$BIN_DIR:$PATH"
}

write_state() {
  mkdir -p "$STATE_DIR"
  cat > "$STATE_DIR/state.json" <<EOF
{
  "product": "hummingbot",
  "method": "$METHOD",
  "channel": "$CHANNEL",
  "base_dir": "$BASE_DIR"
}
EOF
}

# Default-on Claude/LLM plugin. Full wiring lands when the hummingbot MCP server ships;
# for now we record intent and tell the user (opt out with --no-plugin).
maybe_install_plugin() {
  [[ "$INSTALL_PLUGIN" == "1" ]] || { info "Skipping the Claude/LLM plugin (--no-plugin)."; return 0; }
  # TODO(plugin): write "$HB_DIR/.mcp.json" registering the local hummingbot MCP server
  #               (tools: run_bot on tmux, list_configs) once that package is published.
  info "Claude/LLM plugin: enabled by default; full setup lands with the hummingbot MCP server."
}

# ── doctor ────────────────────────────────────────────────────────────────────
run_doctor() {
  step "Health check"
  local fails=0
  _ok()   { success "$1"; }
  _bad()  { printf '%s\n' "${RED}✗${NC} $1 ${DIM}— $2${NC}"; fails=$((fails+1)); }
  _warn() { printf '%s\n' "${YEL}!${NC} $1 ${DIM}— $2${NC}"; }

  command -v git >/dev/null 2>&1 && _ok "git installed" || _bad "git missing" "install git"
  [[ -d "$HB_DIR/.git" ]] && _ok "Hummingbot checkout present ($(tildify "$HB_DIR"))" \
    || _warn "no checkout at $(tildify "$HB_DIR")" "run install-hummingbot.sh"

  if command -v conda >/dev/null 2>&1 && conda env list 2>/dev/null | awk '{print $1}' | grep -qx hummingbot; then
    _ok "hummingbot conda env present (source mode)"
  elif command -v docker >/dev/null 2>&1; then
    docker info >/dev/null 2>&1 && _ok "docker daemon running" || _warn "docker daemon down" "start Docker for the container client"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx hummingbot && _ok "hummingbot container running" \
      || _warn "hummingbot container not running" "hummingbot start"
  else
    _warn "neither conda env nor docker found" "install via --source or --docker"
  fi

  command -v hummingbot >/dev/null 2>&1 && _ok "hummingbot command on PATH" \
    || _warn "hummingbot not on PATH yet" "open a new shell, or source your shell rc"

  printf '\n'
  if [[ "$fails" -gt 0 ]]; then warn "$fails critical check(s) failed."; return 1; fi
  success "No critical failures."; return 0
}

# ── next steps ────────────────────────────────────────────────────────────────
print_next_steps() {
  cat <<EOF

${GRN}${BOLD}🎉 Hummingbot is installed.${NC} ${DIM}($METHOD, channel: $CHANNEL)${NC}

  ${BOLD}Launch${NC}     hummingbot start
  ${BOLD}Autostart${NC}  hummingbot start --v2 <config.yml> -p <password> [--headless]
  ${BOLD}Update${NC}     hummingbot update            ${DIM}(switch channel: --dev / --latest)${NC}
  ${BOLD}Check${NC}      hummingbot doctor

  ${DIM}If 'hummingbot' isn't found, open a new terminal (or source your shell rc).${NC}

EOF
}

# Run — this MUST be the last line (truncation safety for curl | bash).
main "$@"
