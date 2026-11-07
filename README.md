# Bootstrapping Kali Build

These files are intended to bootstrap a fresh Kali build to be ready for hacking
with all of my preferred tools.

## Usage

Run `bootstrap.sh`. This will install Ansible and then run the Ansible script.
Extra arguments go to `ansible-playbook`, e.g. `./bootstrap.sh --tags dotfiles`.
Run it as the user you want to set up, not as root. Pass `-e user=NAME` to set
up someone else.

If setting this up in a VM and desiring a shared folder with the host, share
the folder with the name `vm-share`.

## Checks

Lint the playbook before committing:

```sh
nix-shell -p ansible-lint --run ansible-lint
```

`.ansible-lint` lists the rules skipped on purpose and why.

Run the tests; they need only `ansible` and stay off the system:

```sh
for t in tests/*.sh; do "$t" || echo "FAILED: $t"; done
```
