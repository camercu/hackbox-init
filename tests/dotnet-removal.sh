#!/usr/bin/env bash
# git-credential-manager now comes from nix (dotfiles). Hosts set up earlier
# carry a .NET SDK and a GCM tool install (about 1.2 GB); the playbook
# removes them.
# Runs on any host with ansible, inside a temp dir.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLAYBOOK="$HERE/../ansible/hackbox-init.yml"
fails=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
gone() { [ ! -e "$1" ] && [ ! -L "$1" ]; }

converge() {
  SUDO_USER="$(id -un)" ansible-playbook -i localhost, -c local \
    -e ansible_become=false -e "legacy_dotnet_root=$tmp" \
    --tags gcm "$PLAYBOOK" >"$tmp/converge.log" 2>&1 ||
    { cat "$tmp/converge.log"; return 1; }
}

mkdir -p "$tmp/usr/local/share/dotnet" "$tmp/usr/local/bin/.store" "$tmp/etc/profile.d"
touch "$tmp/usr/local/share/dotnet/dotnet" "$tmp/usr/local/bin/git-credential-manager" \
  "$tmp/etc/profile.d/dotnet.sh"
ln -s "$tmp/usr/local/share/dotnet/dotnet" "$tmp/usr/local/bin/dotnet"
touch "$tmp/usr/local/bin/keep-me"

converge || fail "converge"
for p in usr/local/share/dotnet usr/local/bin/.store usr/local/bin/dotnet \
  usr/local/bin/git-credential-manager etc/profile.d/dotnet.sh; do
  if gone "$tmp/$p"; then ok "removes /$p"; else fail "removes /$p"; fi
done
if [ -e "$tmp/usr/local/bin/keep-me" ]; then ok "leaves other /usr/local/bin files"; else fail "leaves other /usr/local/bin files"; fi

converge || fail "converge on a clean host"
if grep -Eq 'changed=0 ' "$tmp/converge.log"; then ok "clean host: no change"; else fail "clean host: no change"; fi

exit "$fails"
