#!/usr/bin/env bash
# Full local installation for Omarchy (CLI + custom bar module + optional menu rows).
# For the plugin-only install, use:
#   omarchy plugin add https://github.com/Shawnicsc/vpn-switch.git --enable
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(jq -r '.version // "dev"' "$REPO_DIR/manifest.json" 2>/dev/null || printf 'dev')

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
BAR_MODULE="$CONFIG_DIR/bar/modules/vpn.qml"
SHELL_JSON="$CONFIG_DIR/shell.json"
MENU_JSONC="$CONFIG_DIR/extensions/omarchy-menu.jsonc"

WITH_MENU=0
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
Usage: ./install.sh [--with-menu] [--no-restart] [--dry-run]

  --with-menu   Merge the VPN rows into ~/.config/omarchy/extensions/omarchy-menu.jsonc
  --no-restart  Do not restart the Omarchy shell at the end
  --dry-run     Print the planned changes without writing files
  -h, --help    Show this help

Plugin-only install (no CLI, menu rows, or shell.json edits):
  omarchy plugin add https://github.com/Shawnicsc/vpn-switch.git --enable
USAGE
}

while (( $# > 0 )); do
  case $1 in
    --with-menu) WITH_MENU=1 ;;
    --no-restart) NO_RESTART=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

for file in "$REPO_DIR/bin/vpn-switch" "$REPO_DIR/BarWidget.qml" "$REPO_DIR/manifest.json"; do
  [[ -f $file ]] || { warn "missing source file: $file"; exit 1; }
done
[[ -x $REPO_DIR/bin/vpn-switch ]] || { warn "$REPO_DIR/bin/vpn-switch is not executable"; exit 1; }

say "Installing vpn-switch $VERSION"
say "  CLI    -> $BIN_DIR/vpn-switch"
say "  widget -> $BAR_MODULE"

mkdir -p "$BIN_DIR" "$CONFIG_DIR/bar/modules"

backup "$BIN_DIR/vpn-switch"
run install -m 755 "$REPO_DIR/bin/vpn-switch" "$BIN_DIR/vpn-switch"

backup "$BAR_MODULE"
run install -m 644 "$REPO_DIR/BarWidget.qml" "$BAR_MODULE"

ensure_bar_entry() {
  local file=$SHELL_JSON tmp
  if [[ ! -f $file ]]; then
    warn "$file not found; add {\"id\":\"vpn\",\"type\":\"qml\"} to bar.layout.right manually"
    return 0
  fi
  if jq -e '[(.bar.layout // {}) | to_entries[] | .value[]? | select(.id? == "vpn")] | length > 0' \
      "$file" >/dev/null 2>&1; then
    say "bar entry already present in shell.json"
    return 0
  fi
  if (( DRY_RUN )); then
    say "[dry-run] add bar entry {\"id\":\"vpn\",\"type\":\"qml\"} to $file"
    return 0
  fi
  backup "$file"
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  if ! jq --argjson entry '{"id":"vpn","type":"qml"}' '
      if (.bar.layout? | type) != "object" then
        .bar.layout = { right: [$entry] }
      else
        .bar.layout.right = ((.bar.layout.right // []) as $r
          | (($r | map(.id) | index("omarchy.network")) // null) as $i
          | if $i == null then $r + [$entry] else $r[0:$i] + [$entry] + $r[$i:] end)
      end
    ' "$file" > "$tmp"; then
    rm -f "$tmp"
    warn "could not update $file"
    return 1
  fi
  mv "$tmp" "$file"
  say "added VPN entry to $file"
}
ensure_bar_entry

if (( WITH_MENU )); then
  if [[ ! -f $MENU_JSONC ]]; then
    warn "$MENU_JSONC not found; skipping menu integration"
  elif ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; merge extras/omarchy-menu.jsonc.fragment manually"
  elif grep -q '>>> vpn-switch menu' "$MENU_JSONC"; then
    if (( DRY_RUN )); then
      say "[dry-run] update vpn-switch block in $MENU_JSONC"
    else
      backup "$MENU_JSONC"
      python3 "$REPO_DIR/scripts/menu-install.py" "$MENU_JSONC" "$REPO_DIR/extras/omarchy-menu.jsonc.fragment"
      say "updated VPN menu rows in $MENU_JSONC"
    fi
  elif grep -qE '^[[:space:]]*"vpn(\.[^"]+)?"[[:space:]]*:' "$MENU_JSONC"; then
    warn "existing VPN keys found in $MENU_JSONC; not touching it."
    warn "Merge extras/omarchy-menu.jsonc.fragment manually, or remove the old rows first."
  else
    if (( DRY_RUN )); then
      say "[dry-run] add VPN rows to $MENU_JSONC"
    else
      backup "$MENU_JSONC"
      python3 "$REPO_DIR/scripts/menu-install.py" "$MENU_JSONC" "$REPO_DIR/extras/omarchy-menu.jsonc.fragment"
      say "added VPN rows to $MENU_JSONC"
    fi
  fi
fi

if (( NO_RESTART )); then
  say "Restart later with: omarchy restart shell"
elif command -v omarchy >/dev/null 2>&1; then
  run omarchy restart shell
else
  say "omarchy command not found; restart your shell manually"
fi

if (( ! DRY_RUN )); then
  say "Installed: $("$BIN_DIR/vpn-switch" version)"
  say "Toggle the VPN icon in the bar, or run: vpn-switch toggle tailscale"
fi
