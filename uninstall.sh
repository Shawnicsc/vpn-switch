#!/usr/bin/env bash
# Remove the full local installation created by ./install.sh.
# Plugin installs are removed with: omarchy plugin remove io.github.shawnicsc.vpn
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
BAR_MODULE="$CONFIG_DIR/bar/modules/vpn.qml"
SHELL_JSON="$CONFIG_DIR/shell.json"
MENU_JSONC="$CONFIG_DIR/extensions/omarchy-menu.jsonc"

NO_RESTART=0
DRY_RUN=0

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

backup() {
  local file=$1 stamp
  [[ -f $file ]] || return 0
  stamp=$(date +%Y%m%d-%H%M%S)
  if (( DRY_RUN )); then
    say "[dry-run] backup $file -> $file.bak.$stamp"
  else
    cp -a -- "$file" "$file.bak.$stamp"
    say "backup: $file.bak.$stamp"
  fi
}

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh [--no-restart] [--dry-run]

  --no-restart  Do not restart the Omarchy shell at the end
  --dry-run     Print the planned changes without writing files
  -h, --help    Show this help

Plugin-only installs are removed with:
  omarchy plugin remove io.github.shawnicsc.vpn
USAGE
}

while (( $# > 0 )); do
  case $1 in
    --no-restart) NO_RESTART=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -e $BIN_DIR/vpn-switch ]]; then
  run rm -f "$BIN_DIR/vpn-switch"
  say "removed $BIN_DIR/vpn-switch"
fi

if [[ -e $BAR_MODULE ]]; then
  backup "$BAR_MODULE"
  run rm -f "$BAR_MODULE"
  say "removed $BAR_MODULE"
fi

if [[ -f $SHELL_JSON ]] && jq -e '
    [(.bar.layout // {}) | to_entries[] | .value[]? | select(.id? == "vpn")] | length > 0
  ' "$SHELL_JSON" >/dev/null 2>&1; then
  if (( DRY_RUN )); then
    say "[dry-run] remove vpn entry from $SHELL_JSON"
  else
    backup "$SHELL_JSON"
    tmp=$(mktemp "${SHELL_JSON}.tmp.XXXXXX")
    jq '(.bar.layout // {}) |= with_entries(.value |= map(select(.id? != "vpn")))' \
      "$SHELL_JSON" > "$tmp" && mv "$tmp" "$SHELL_JSON"
    say "removed vpn entry from $SHELL_JSON"
  fi
fi

if [[ -f $MENU_JSONC ]] && grep -q '>>> vpn-switch menu' "$MENU_JSONC"; then
  if (( DRY_RUN )); then
    say "[dry-run] remove VPN rows from $MENU_JSONC"
  elif command -v python3 >/dev/null 2>&1; then
    backup "$MENU_JSONC"
    python3 "$REPO_DIR/scripts/menu-install.py" "$MENU_JSONC" --remove
    say "removed VPN rows from $MENU_JSONC"
  else
    warn "python3 not found; remove the marked block from $MENU_JSONC manually"
  fi
fi

if (( NO_RESTART )); then
  say "Restart later with: omarchy restart shell"
elif command -v omarchy >/dev/null 2>&1; then
  run omarchy restart shell
else
  say "omarchy command not found; restart your shell manually"
fi
