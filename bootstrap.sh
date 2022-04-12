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
    warn "This script must be run as root!"
    info "Re-trying with sudo..."
    sudo $0 $@
    exit $?
fi

in_vmware=$(lspci | grep -i vmware &>/dev/null && echo true || echo false )
if [[ $in_vmware == true ]]; then
    info "Ensuring VMWare Tools are installed..."
    apt update && apt install -y open-vm-tools fuse3

    info "Ensuring shared folder is mounted..."
    host_dir="$(awk '{print $1}' $HERE/fstab)"
    if ! grep -F "$host_dir" /etc/fstab &>/dev/null; then
        cat /etc/fstab "$HERE/fstab" > /tmp/fstab.new
        mv /tmp/fstab.new /etc/fstab
        mountpt="$(awk '{print $2}' "$HERE/fstab")"
        mkdir -p "$mountpt"
        mount -a
    fi
fi

info "Installing prerequisites for Ansible..."
apt update && apt install -y python3 python3-pip

info "Installing Ansible..."
python3 -m pip install -U ansible

info "Running Ansible script..."
ansible-playbook -v -i localhost, --connection=local -e "ansible_python_interpreter=$(which python3)" "$HERE/ansible/hackbox-init.yml"

if [[ $in_vmware == true && -d /mnt/share/.dotfiles ]]; then
    info "Swapping out dotfile dir for shared copy..."
    [[ -d /home/kali/.dotfiles && ! -L /home/kali/.dotfiles ]] && rm -rf /home/kali/.dotfiles
    ln -sf /mnt/share/.dotfiles /home/kali/.dotfiles
fi

if [[ $in_vmware == true && -d /mnt/share/hackbox-init ]]; then
    info "Swapping out hackbox-init dir for shared copy..."
    [[ -d /home/kali/hackbox-init && ! -L /home/kali/hackbox-init ]] && rm -rf /home/kali/hackbox-init
    ln -sf /mnt/share/hackbox-init /home/kali/hackbox-init
fi

success "Done!"