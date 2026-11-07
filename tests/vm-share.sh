#!/usr/bin/env bash
# On VMware, the user's dotfiles and hackbox-init clones become links to the
# host's shared copies. A real clone must be moved aside, never deleted, and
# a re-run must leave the shared copy untouched.
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
links_to_share() { [ "$(readlink "$home/.dotfiles")" = "$share/.dotfiles" ]; }
share_is_empty() { [ -z "$(ls -A "$share/.dotfiles")" ]; }

home="$tmp/home"
share="$tmp/share"
mkdir -p "$home/.dotfiles" "$share/.dotfiles"
echo mine > "$home/.dotfiles/local-work"
mkdir -p "$home/hackbox-init" # the share has no hackbox-init

converge() {
  SUDO_USER="$(id -un)" ansible-playbook -i localhost, -c local \
    -e ansible_become=false -e "homedir=$home" -e "vm_share=$share" \
    --tags vmshare "$PLAYBOOK" >"$tmp/converge.log" 2>&1 ||
    { cat "$tmp/converge.log"; return 1; }
}

converge || fail "first converge"
check "clone links to the shared copy" links_to_share
check "real clone moved aside with its work" grep -qx mine "$home/.dotfiles.pre-share/local-work"
check "copy missing from the share left alone" test -d "$home/hackbox-init" -a ! -L "$home/hackbox-init"

converge || fail "second converge"
check "re-run keeps the link" links_to_share
check "re-run plants nothing inside the share" share_is_empty

[ "$fails" -eq 0 ] || { echo "$fails failure(s)"; exit 1; }
