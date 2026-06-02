#!/usr/bin/env bash
#
# setup.sh — back-compat shim.
#
# The Condor installer was renamed to install-condor.sh. This shim forwards to it so existing
# `curl -fsSL .../deploy/main/setup.sh | bash` links keep working. Prefer install-condor.sh directly.

set -euo pipefail

# If we're running from a checkout, use the sibling install-condor.sh.
src="${BASH_SOURCE[0]:-}"
if [[ -n "$src" && -f "$src" ]]; then
  dir="$(cd "$(dirname "$src")" && pwd)"
  if [[ -f "$dir/install-condor.sh" ]]; then
    exec bash "$dir/install-condor.sh" "$@"
  fi
fi

# Piped via curl | bash: fetch the renamed installer and run it.
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT INT TERM
curl -fsSL "https://raw.githubusercontent.com/hummingbot/deploy/main/install-condor.sh" -o "$tmp" \
  || { echo "Could not fetch install-condor.sh — see https://github.com/hummingbot/deploy" >&2; exit 1; }
if [[ -t 1 && -r /dev/tty ]]; then exec bash "$tmp" "$@" < /dev/tty; else exec bash "$tmp" "$@"; fi
