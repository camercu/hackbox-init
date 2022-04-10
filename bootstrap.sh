#!/bin/bash

# exit when any command fails
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CLEAR=$(tput sgr0)

function info {
    echo "${BLUE}[*] $@${CLEAR}"
}

function warn {
    echo "${YELLOW}[!] $@${CLEAR}"
}

function error {
    echo "${RED}[x] $@${CLEAR}"
}

function success {
    echo "${GREEN}[+] $@${CLEAR}"
}

if [[ "$UID" != 0 ]]; then
    error "This script must be run as root!"
    info "Re-trying with sudo..."
    sudo $0 $@
    exit $?
fi

if lspci | grep -i vmware &>/dev/null; then
    info "Ensuring VMWare Tools are installed..."
    apt update && apt install -y open-vm-tools fuse3

    info "Ensuring shared folder is mounted..."
    if ! grep -f '.host:/vm-share' /etc/fstab &>/dev/null; then
        cat /etc/fstab "$HERE/fstab" > /tmp/fstab.new
        mv /tmp/fstab.new /etc/fstab
        mkdir -p "$(awk '{print $2}')"
        mount -a
    fi
fi

info "Installing prerequisites for Ansible..."
apt update && apt install -y python3 python3-pip

info "Installing Ansible..."
python3 -m pip install ansible argcomplete

info "Running Ansible script..."
ansible-playbook -v -i localhost, --connection=local -e "ansible_python_interpreter=$(which python3)" "$HERE/ansible/hackbox-init.yml"

success "Done!"