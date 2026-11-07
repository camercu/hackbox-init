#!/bin/bash

# exit when any command fails
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Colors are optional: tput fails without a usable TERM (cron, nohup, CI).
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
CLEAR=$(tput sgr0 2>/dev/null || true)

function info {
  echo "${BLUE}[*] ${*}${CLEAR}"
}

function warn {
  echo "${YELLOW}[!] ${*}${CLEAR}"
}

function error {
  echo "${RED}[x] ${*}${CLEAR}"
}

function success {
  echo "${GREEN}[+] ${*}${CLEAR}"
}

# Prints the hypervisor name (e.g. "oracle" for VirtualBox, "vmware"), or
# "none" on bare metal. DMI files do not exist on ARM guests, so ask systemd.
function detect_hypervisor {
  systemd-detect-virt --vm 2>/dev/null || true
}

if [[ "$UID" != 0 ]]; then
  warn "This script must be run as root!"
  info "Re-trying with sudo..."
  sudo "$0" "$@"
  exit $?
fi

info "Updating apt cache..."
apt update

hypervisor="$(detect_hypervisor)"
info "Hypervisor: $hypervisor"
if [[ "$hypervisor" == vmware ]]; then
  info "Ensuring VMWare Tools are installed..."
  apt install -y open-vm-tools fuse3

  info "Ensuring shared folder is mounted..."
  host_dir="$(awk '{print $1}' "$HERE/fstab")"
  if ! grep -qF "$host_dir" /etc/fstab; then
    cat /etc/fstab "$HERE/fstab" >/tmp/fstab.new
    mv /tmp/fstab.new /etc/fstab
    mountpt="$(awk '{print $2}' "$HERE/fstab")"
    mkdir -p "$mountpt"
    mount -a
  fi
elif [[ "$hypervisor" == oracle ]]; then
  info "Installing prerequisites for VirtualBox Guest Additions..."
  # Headers for the running kernel build the additions now; the arch
  # metapackage keeps headers in step with kernel upgrades so DKMS rebuilds.
  apt install -y build-essential dkms "linux-headers-$(uname -r)" \
    "linux-headers-$(dpkg --print-architecture)"
fi

# Kali's python is externally managed (PEP 668): pip install fails, use apt.
info "Installing Ansible..."
apt install -y python3 ansible-core

info "Running Ansible script..."
ansible-playbook -v -i localhost, --connection=local -e "ansible_python_interpreter=$(which python3)" "$HERE/ansible/hackbox-init.yml" "$@"

success "Done!"
