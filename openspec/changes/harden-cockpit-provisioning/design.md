## Context

The Ubuntu LTS host installs Cockpit through one Ansible role and overrides `cockpit.socket` to listen on localhost. The override currently notifies a deferred handler while a later task performs a daemon reload and leaves the running socket without usable file descriptors. Cockpit authentication also has no role-managed account boundary from the normal SSH administrator.

The change touches systemd activation, a PAM-authenticated local user, and OpenSSH configuration. It must preserve access for the existing SSH administrator, avoid committing credentials, and remain idempotent.

## Goals / Non-Goals

**Goals:**

- Apply a changed socket override before the play proceeds, leaving `cockpit.socket` enabled, active, and bound only to the configured local endpoint.
- Provision a dedicated configurable Cockpit administrator with a Vault-backed password hash and `sudo` membership.
- Deny only that Cockpit administrator from SSH, validate the final OpenSSH configuration, and reload Ubuntu's `ssh` service only when the fragment changes.
- Keep all behavior in the existing Cockpit role and document setup and verification for junior operators.

**Non-Goals:**

- Expose Cockpit publicly or replace the SSH tunnel.
- Configure Cockpit certificates, alternate PAM stacks, password generation, or Vault encryption automatically.
- Broaden SSH hardening beyond denying the dedicated Cockpit account.
- Add automated remote end-to-end tests that require a provisioned VPS.

## Decisions

### Apply socket changes synchronously

Register the socket override template result. When it changes, run an immediate `ansible.builtin.systemd` daemon reload followed by an immediate restart of `cockpit.socket`; then unconditionally ensure the socket is enabled and started. This mirrors the known-good manual lifecycle and prevents later role tasks from running while the socket is active but non-functional.

A deferred handler was rejected because it permits the broken intermediate state that caused this change. An unconditional restart was rejected because it would make every playbook run report a change and interrupt active Cockpit sessions.

### Use a normal local account for Cockpit PAM authentication

Use `ansible.builtin.user` with the configured username and SHA-512 password hash, `/bin/bash`, a home directory, and appended `sudo` membership. The non-secret variable references a Vault variable so the role never embeds a username-specific secret or plaintext password.

A system account or non-login shell was rejected because Cockpit's PAM session needs a normal usable local account. Reusing the SSH administrator was rejected because it couples web and SSH credentials and cannot be selectively denied from SSH.

### Deny the account through an OpenSSH fragment

Render `/etc/ssh/sshd_config.d/99-cockpit.conf` from `cockpit_admin_user`. If the file changes, run `/usr/sbin/sshd -t` against the final host configuration and reload the Ubuntu `ssh` service only after validation succeeds. A failed validation stops the play before reload, preserving the currently loaded SSH configuration.

`DenyUsers` was chosen over shell restrictions because Cockpit requires a valid shell. Restarting SSH was rejected because a reload applies valid configuration without unnecessarily disrupting the service.

### Keep configuration in existing inventory files

Add bind, port, username, and password-hash reference variables to `group_vars/all/vars.yml`, and add only a clearly fake SHA-512 hash placeholder to `examples/vault.yml.example`. The existing encrypted Vault remains operator-managed because its password is unavailable during repository development.

## Risks / Trade-offs

- Invalid generated SSH configuration remains on disk after validation fails -> Do not reload SSH; fix the variable/template and rerun Ansible while the previous daemon configuration remains active.
- A malformed or placeholder password hash prevents useful Cockpit login -> Document `openssl passwd -6` and require the real hash in encrypted Vault.
- Renaming `cockpit_admin_user` leaves the prior local user present and no longer denied by the generated fragment -> Treat account renames as an explicit operator migration; remove or lock the old account separately.
- `DenyUsers` depends on Ubuntu's standard inclusion of `sshd_config.d` -> The playbook supports Ubuntu LTS and validates the final configuration before reload.

## Migration Plan

1. Generate a SHA-512 password hash locally and add it to the encrypted Ansible Vault.
2. Run syntax validation, then run the playbook against the Ubuntu VPS.
3. Keep the existing SSH administration session open while verifying the normal administrator can open a second SSH session.
4. Verify the socket state, localhost listener, HTTPS response, Cockpit account groups, SSH configuration, Cockpit login, and Cockpit-account SSH denial.
5. Run the playbook a second time and confirm it reports no unnecessary changes.

Rollback consists of reverting the role and variable changes and rerunning Ansible. If immediate host recovery is needed, remove the deny fragment, validate with `sshd -t`, reload `ssh`, restore the previous socket override, run `systemctl daemon-reload`, and restart `cockpit.socket`.

## Open Questions

None.
