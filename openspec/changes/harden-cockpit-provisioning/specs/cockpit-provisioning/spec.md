## ADDED Requirements

### Requirement: Cockpit socket is configured for local access
The provisioning system SHALL install Cockpit, create the systemd socket override directory, render the configured bind address and port into the override, and ensure `cockpit.socket` is enabled and started. The default endpoint MUST be `127.0.0.1:9090` and MUST remain accessible through an SSH local-forwarding tunnel.

#### Scenario: Initial Cockpit provisioning
- **WHEN** the playbook runs on a supported Ubuntu LTS host without Cockpit configuration
- **THEN** Cockpit is installed, `listen.conf` contains only the configured listener after clearing inherited listeners, and `cockpit.socket` is enabled and active

#### Scenario: Localhost listener is reachable
- **WHEN** provisioning completes with the default bind variables
- **THEN** the host listens for Cockpit on `127.0.0.1:9090` and its HTTPS endpoint responds locally

### Requirement: Socket configuration changes take effect immediately
The provisioning system MUST synchronously reload systemd and restart `cockpit.socket` when the socket override changes, before proceeding beyond Cockpit socket configuration. It SHALL NOT depend solely on a deferred handler for this lifecycle.

#### Scenario: Socket override changes
- **WHEN** Ansible changes `/etc/systemd/system/cockpit.socket.d/listen.conf`
- **THEN** Ansible performs a systemd daemon reload, restarts `cockpit.socket`, and leaves the socket enabled and active during the same role execution

#### Scenario: Socket override is unchanged
- **WHEN** the rendered socket override already matches the host file
- **THEN** Ansible keeps `cockpit.socket` enabled and started without unnecessarily restarting it

### Requirement: Dedicated Cockpit administrator is provisioned
The provisioning system SHALL create the configured Cockpit administrator as a normal local Linux user with a home directory, `/bin/bash`, a valid password hash, and appended membership in the `sudo` group. Cockpit SHALL use this account for username/password PAM authentication instead of requiring reuse of the normal SSH administrator.

#### Scenario: Cockpit administrator is created
- **WHEN** the playbook runs with a valid administrator username and password hash
- **THEN** the local user exists with a home directory, `/bin/bash`, and membership in the `sudo` group

#### Scenario: Cockpit login uses the dedicated account
- **WHEN** an operator enters the configured Cockpit administrator username and corresponding password in Cockpit
- **THEN** PAM can authenticate the account and Cockpit grants the user's authorized session

### Requirement: Cockpit credentials remain secret
The non-secret Ansible variables SHALL reference a password hash held in encrypted Ansible Vault data. The repository MUST NOT contain a real Cockpit password or real password hash in an unencrypted file, and the Vault example SHALL contain only an unmistakable replacement placeholder.

#### Scenario: Operator configures the Cockpit password
- **WHEN** the operator generates a SHA-512 hash with `openssl passwd -6` and stores it under the documented Vault variable
- **THEN** the Cockpit role receives the hash through the non-secret variable reference without storing plaintext credentials in Git

### Requirement: Cockpit administrator is denied SSH access
The provisioning system SHALL render an OpenSSH configuration fragment using the configured Cockpit administrator username and `DenyUsers`. When the fragment changes, it MUST validate the final OpenSSH configuration before reloading Ubuntu's `ssh` service, and MUST NOT reload the service if validation fails.

#### Scenario: Valid SSH deny fragment changes
- **WHEN** Ansible changes `/etc/ssh/sshd_config.d/99-cockpit.conf` and `sshd -t` succeeds
- **THEN** Ansible reloads the `ssh` service and SSH authentication for the Cockpit administrator is rejected

#### Scenario: Final SSH configuration is invalid
- **WHEN** the deny fragment changes and `sshd -t` fails against the final host configuration
- **THEN** the play fails before reloading the `ssh` service

#### Scenario: Normal administration user connects
- **WHEN** the configured Cockpit administrator is denied and the existing SSH administration user authenticates
- **THEN** the existing SSH administration user's access remains allowed

#### Scenario: SSH fragment is unchanged
- **WHEN** the rendered deny fragment already matches the host file
- **THEN** Ansible does not validate or reload SSH unnecessarily

### Requirement: Cockpit operation is documented and verifiable
The Ansible README SHALL explain the localhost listener and SSH tunnel, dedicated account separation, Vault-backed password hash setup, explicit SSH denial, syntax checking, two-run idempotence check, and commands for verifying socket state, listener, HTTPS response, account groups, SSH validity, denied Cockpit-user SSH, and retained administrator SSH.

#### Scenario: Junior operator follows setup documentation
- **WHEN** a junior operator follows the README to configure and provision Cockpit
- **THEN** the operator can generate and encrypt the required hash, run the playbook, access Cockpit through the tunnel, and execute every required verification

### Requirement: Repeated provisioning is idempotent
The Cockpit provisioning tasks SHALL converge without reporting unnecessary changes or restarting/reloading services on a second run with unchanged inputs and host state.

#### Scenario: Playbook runs twice
- **WHEN** the playbook completes successfully and immediately runs again with unchanged configuration
- **THEN** the second run reports no unnecessary Cockpit, socket, user, or SSH configuration changes
