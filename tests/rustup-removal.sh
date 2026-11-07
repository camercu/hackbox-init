#!/usr/bin/env bash
# Rust now comes from nix rustup (dotfiles) at XDG paths. Hosts set up
# earlier carry a curl-installed rustup in ~/.cargo and ~/.rustup, whose
# ~/.cargo/bin would shadow nix's. The playbook removes it, but only when
# ~/.cargo/bin holds nothing the user installed.
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
# shellcheck disable=SC2329 # called through check
gone() { [ ! -e "$1" ]; }

converge() {
  SUDO_USER="$(id -un)" ansible-playbook -i localhost, -c local \
    -e ansible_become=false -e "homedir=$home" \
    --tags rust "$PLAYBOOK" >"$tmp/converge.log" 2>&1 ||
    { cat "$tmp/converge.log"; return 1; }
}
old_install() {
  mkdir -p "$home/.cargo/bin" "$home/.rustup/toolchains"
  for f in cargo rustc rustup rustfmt cargo-clippy rust-analyzer; do
    touch "$home/.cargo/bin/$f"
  done
}

home="$tmp/proxies-only"
old_install
converge || fail "converge"
check "removes ~/.cargo holding only rustup proxies" gone "$home/.cargo"
check "removes ~/.rustup with it" gone "$home/.rustup"

home="$tmp/user-tools"
old_install
touch "$home/.cargo/bin/ripgrep-all"
converge || fail "converge with user tools"
check "keeps ~/.cargo when the user installed tools" test -e "$home/.cargo/bin/ripgrep-all"
check "keeps ~/.rustup when the user installed tools" test -d "$home/.rustup"

home="$tmp/fresh"
mkdir -p "$home"
converge || fail "converge on a fresh home"
check "fresh home: no change" grep -Eq 'changed=0 ' "$tmp/converge.log"

exit "$fails"
