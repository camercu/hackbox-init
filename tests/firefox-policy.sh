#!/usr/bin/env bash
# Firefox add-ons come from an enterprise policy in /etc/firefox/policies.
# That file replaces Kali's distribution policies.json, so Kali's policies
# must survive inside it.
# Runs on any host with ansible, inside a temp dir.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLAYBOOK="$HERE/../ansible/hackbox-init.yml"
fails=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
# check NAME TEST...: TEST is a command; ok when it exits 0.
check() {
  name=$1
  shift
  if "$@"; then ok "$name"; else fail "$name"; fi
}
# policy EXPR: exits 0 when the python EXPR holds for the written policies, p.
# shellcheck disable=SC2329 # called through check
policy() { python3 -c '
import json, sys
p = json.load(open(sys.argv[1]))["policies"]
sys.exit(0 if eval(sys.argv[2]) else 1)' "$tmp/etc/policies.json" "$1"; }

converge() {
  SUDO_USER="$(id -un)" ansible-playbook -i localhost, -c local \
    -e ansible_become=false \
    -e "firefox_distribution_policies=$tmp/kali-policies.json" \
    -e "firefox_policies_dir=$tmp/etc" \
    --tags firefox "$PLAYBOOK" >"$tmp/converge.log" 2>&1 ||
    { cat "$tmp/converge.log"; return 1; }
}

cat >"$tmp/kali-policies.json" <<'EOF'
{"policies": {"DisableTelemetry": true,
  "ExtensionSettings": {"kali@example": {"installation_mode": "allowed"}}}}
EOF

converge || fail "first converge"
check "keeps Kali's own policies" policy 'p["DisableTelemetry"] is True'
check "keeps Kali's own add-on settings" policy '"kali@example" in p["ExtensionSettings"]'
check "installs uBlock Origin from AMO" policy \
  'p["ExtensionSettings"]["uBlock0@raymondhill.net"]["install_url"].endswith("/ublock-origin/latest.xpi")'
check "installs, but lets the user remove" policy \
  'p["ExtensionSettings"]["uBlock0@raymondhill.net"]["installation_mode"] == "normal_installed"'

converge || fail "second converge"
check "re-run changes nothing" grep -Eq 'changed=0 ' "$tmp/converge.log"

rm -f "$tmp/kali-policies.json" "$tmp/etc/policies.json"
converge || fail "converge without Kali policies"
check "installs add-ons with no Kali policies" policy \
  '"foxyproxy@eric.h.jung" in p["ExtensionSettings"]'

exit "$fails"
