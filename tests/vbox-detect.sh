#!/usr/bin/env bash
# VirtualBox Guest Additions install only inside VirtualBox. The guest is
# known by its PCI device (vendor 0x80ee): systemd-detect-virt says "none"
# on arm64 VirtualBox guests.
# Runs on any host with ansible, inside a temp dir. The install itself needs
# a real guest; this checks only that other machines are left alone and that
# a VirtualBox guest is recognized.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLAYBOOK="$HERE/../ansible/hackbox-init.yml"
fails=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# converge PCI_DIR: run the vbox tasks against a fake /sys/bus/pci/devices.
# --check: on a VirtualBox guest the apt step then reports instead of acting.
converge() {
  SUDO_USER="$(id -un)" ansible-playbook -i localhost, -c local --check \
    -e ansible_become=false -e "vbox_pci_devices=$1" \
    --tags vbox "$PLAYBOOK" >"$tmp/converge.log" 2>&1
}
pci_device() { mkdir -p "$1/$2" && echo "$3" >"$1/$2/vendor"; }
# result TASK: the first result line ansible printed for TASK.
result() { grep -A2 "TASK \[common : $1" "$tmp/converge.log" | grep -m1 -E '^(ok|changed|skipping|fatal|\[ERROR\])'; }
deps="Install VirtualBox Guest Additions build deps"

pci_device "$tmp/other" 0000:00:01.0 0x8086
pci_device "$tmp/other" 0000:00:02.0 0x1af4
converge "$tmp/other" || fail "converge without a VirtualBox device"
case "$(result "$deps")" in
  skipping*) ok "skips a machine with no VirtualBox device" ;;
  *) fail "skips a machine with no VirtualBox device: $(result "$deps")" ;;
esac

pci_device "$tmp/vbox" 0000:00:01.0 0x8086
pci_device "$tmp/vbox" 0000:00:04.0 0x80ee
converge "$tmp/vbox" || true # apt is absent off Debian; reaching it is the point
case "$(result "$deps")" in
  skipping* | "") fail "recognizes a VirtualBox guest by its PCI device: $(result "$deps")" ;;
  *) ok "recognizes a VirtualBox guest by its PCI device" ;;
esac

exit "$fails"
