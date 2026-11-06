# Bootstrapping Kali Build

These files are intended to bootstrap a fresh Kali build to be ready for hacking
with all of my preferred tools.

## Usage

Run `bootstrap.sh`. This will install Ansible and then run the Ansible script.
Extra arguments go to `ansible-playbook`, e.g. `./bootstrap.sh --tags dotfiles`.

If setting this up in a VM and desiring a shared folder with the host, share
the folder with the name `vm-share`.
