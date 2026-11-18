#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

fail() { printf 'validate: %s\n' "$*" >&2; exit 1; }

for file in manifest.json README.md LICENSE CHANGELOG.md BarWidget.qml bin/vpn-switch install.sh uninstall.sh preview.png extras/omarchy-menu.jsonc.fragment; do
  [[ -f $file ]] || fail "missing $file"
done
[[ -x bin/vpn-switch ]] || fail "bin/vpn-switch must be executable"

jq -e '.schemaVersion == 1' manifest.json >/dev/null || fail "manifest schemaVersion must be 1"
jq -e '(.id | type == "string") and (.id | startswith("omarchy.") | not)' manifest.json >/dev/null \
  || fail "manifest id must be a non-reserved string"
jq -e '(.kinds | type == "array") and (.kinds | length > 0)' manifest.json >/dev/null \
  || fail "manifest kinds must be a non-empty array"
jq -e '(.entryPoints | type == "object")' manifest.json >/dev/null || fail "manifest entryPoints must be an object"

while IFS= read -r entry; do
  [[ -n $entry ]] || continue
  [[ $entry != /* && $entry != *..* ]] || fail "unsafe entry point: $entry"
  [[ -f $entry ]] || fail "missing entry point file: $entry"
done < <(jq -r '.entryPoints[]' manifest.json)

version=$(jq -r '.version' manifest.json)
grep -q "VPN_SWITCH_VERSION=\"$version\"" bin/vpn-switch || fail "bin/vpn-switch version does not match manifest ($version)"

bash -n bin/vpn-switch
bash -n install.sh
bash -n uninstall.sh
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' scripts/menu-install.py

if grep -n '\\u000f' extras/omarchy-menu.jsonc.fragment >/dev/null 2>&1; then
  fail 'menu fragment uses \\u000f... (JSON \\u takes 4 hex digits; use a surrogate pair)'
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning bin/vpn-switch install.sh uninstall.sh scripts/validate.sh
fi

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT"
fi

if [[ ${1:-} == --tag ]]; then
  tag=${2:-}
  [[ -n $tag ]] || fail "--tag requires a tag name"
  [[ $tag == "v$version" ]] || fail "tag $tag does not match manifest version v$version"
fi

echo "validate: ok (v$version)"
