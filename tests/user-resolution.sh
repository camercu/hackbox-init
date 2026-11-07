#!/usr/bin/env bash
# The playbook must target the user who ran bootstrap.sh, and refuse a
# target that is root, empty or not a valid login name.
# Runs on any host with ansible: only the `always`-tagged tasks run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLAYBOOK="$HERE/../ansible/hackbox-init.yml"
fails=0

ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# Prints "user|homedir" as the playbook resolves them under env $@.
resolve() {
  env "$@" ansible -i localhost, -c local localhost \
    --playbook-dir "$HERE/../ansible" -m debug -a 'msg={{ user }}|{{ homedir }}' 2>/dev/null |
    sed -n 's/.*"msg": "\(.*\)".*/\1/p'
}

# Exit status of the guard tasks under env $@.
guard() {
  env "$@" ansible-playbook -i localhost, -c local -e ansible_become=false \
    --tags __none__ "$PLAYBOOK" >/dev/null 2>&1
}

expect_user() {
  want=$1
  shift
  got=$(resolve "$@")
  if [ "$got" = "$want" ]; then ok "resolve $* -> $want"; else fail "resolve $* -> '$got', want '$want'"; fi
}

expect_guard() {
  want=$1
  shift
  if guard "$@"; then got=pass; else got=refuse; fi
  if [ "$got" = "$want" ]; then ok "guard $* -> $want"; else fail "guard $* -> $got, want $want"; fi
}

expect_user 'kali|/home/kali' SUDO_USER=kali USER=root
expect_user 'kali|/home/kali' SUDO_USER= USER=kali
expect_user 'kali|/home/kali' -u SUDO_USER USER=kali

expect_guard pass SUDO_USER=kali USER=root
expect_guard refuse -u SUDO_USER USER=root
expect_guard refuse -u SUDO_USER -u USER
expect_guard refuse 'SUDO_USER= kali' USER=root
expect_guard refuse SUDO_USER=Kali USER=root

[ "$fails" -eq 0 ] || { echo "$fails failure(s)"; exit 1; }
