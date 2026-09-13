## Why

The current Cockpit socket override can leave `cockpit.socket` active but non-functional until it is manually stopped and started. Cockpit also reuses the SSH administration account, instead of having a dedicated local account whose web access and SSH access can be controlled independently.

## What Changes

- Apply Cockpit socket override changes immediately with a systemd daemon reload and socket restart, then always ensure the socket is enabled and started.
- Add configurable Cockpit bind address and port variables while preserving the localhost-only default.
- Create a configurable local Cockpit administrator with a Vault-backed password hash, home directory, login shell, and `sudo` membership.
- Render an SSH configuration fragment that denies the Cockpit administrator SSH access, validate the complete SSH configuration, and reload Ubuntu's `ssh` service only after valid changes.
- Document Cockpit tunneling, account separation, password hash generation, Vault configuration, idempotence, and operational verification.

## Capabilities

### New Capabilities

- `cockpit-provisioning`: Reliable localhost-only Cockpit socket activation and secure provisioning of a dedicated Cockpit administrator that cannot log in through SSH.

### Modified Capabilities

None.

## Impact

- Updates the existing Ansible Cockpit role tasks and templates; its obsolete socket handler may be removed.
- Adds non-secret Cockpit variables to `ansible/group_vars/all/vars.yml` and a placeholder password hash to `ansible/examples/vault.yml.example`.
- Updates `ansible/README.md` with setup and verification instructions.
- Changes host-local systemd, Linux user/group, PAM password, and OpenSSH configuration on supported Ubuntu LTS servers.
- Adds no new Ansible collections or runtime dependencies.
