## 1. Cockpit Configuration

- [x] 1.1 Add the configurable Cockpit bind address, port, administrator username, and Vault-backed password hash reference to `group_vars/all/vars.yml`.
- [x] 1.2 Add a clearly fake SHA-512 Cockpit password hash placeholder to `examples/vault.yml.example` without changing or exposing the encrypted Vault contents.
- [x] 1.3 Register socket override changes, immediately reload systemd and restart `cockpit.socket` only when changed, then always ensure the socket is enabled and started.
- [x] 1.4 Remove the deferred Cockpit socket handler if it is no longer used.

## 2. Cockpit Account And SSH Isolation

- [x] 2.1 Provision the configured Cockpit administrator as a normal local user with its Vault-backed password hash, home directory, `/bin/bash`, and appended `sudo` membership.
- [x] 2.2 Add the Cockpit role template for `/etc/ssh/sshd_config.d/99-cockpit.conf` using `DenyUsers` and the configured administrator username.
- [x] 2.3 On SSH fragment changes, validate the final configuration with `/usr/sbin/sshd -t` and reload Ubuntu's `ssh` service only after successful validation.

## 3. Documentation

- [x] 3.1 Update the Ansible README to explain the localhost listener, SSH tunnel, dedicated Cockpit account, explicit SSH denial, `openssl passwd -6`, and encrypted Vault entry.
- [x] 3.2 Document syntax checking, two-run idempotence validation, socket/listener/HTTPS checks, user group verification, SSH configuration validation, Cockpit-user denial, and retained normal administrator access.

## 4. Validation

- [x] 4.1 Run `ansible-playbook site.yml --syntax-check` from `ansible/` when Ansible and Vault credentials are available.
- [ ] 4.2 Run the playbook twice against the Ubuntu VPS and confirm the second run has no unnecessary changes.
- [ ] 4.3 Verify `cockpit.socket` is active and enabled, `127.0.0.1:9090` is listening and responds over HTTPS, and Cockpit is reachable through the SSH tunnel.
- [ ] 4.4 Verify the dedicated account belongs to `sudo`, can authenticate through Cockpit, is denied over SSH, and the normal SSH administrator can still connect.
