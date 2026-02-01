# Custom LXC Image Builder for Proxmox-VE 9 with Terraform & Ansible Integration

**Purpose:** Build custom LXC images for Proxmox-VE 9 that support seamless provisioning via OpenTofu/Terraform and immediate handoff to Ansible for configuration management.

**Problem:** Default CT templates provided by Proxmox don't create a non-root user (and thus, don't set authorized_keys for a non-root user). LXC images from linuxcontainers.org don't enable `openssh-server`, nor do they create a non-root user. This requires an intermediate step before containers can be managed via Ansible.

**Possible Solutions:**

- **Local Provisioner Script:** Use Terraform `local-exec` to `pct push` and `pct exec` a setup script. (Exploratory)
- **Shared Inventory:** Wire Terraform and Ansible to share inventory, allowing Ansible to perform initial setup. (Proof of concept works)
- **Hook Script:** Apply a container hook script to automate `pct push`/`pct exec`. (Tested and working)
- **This Repo’s Approach:** Modify [lxc-ci](https://github.com/lxc/lxc-ci/) build definitions (e.g., `ubuntu.yaml`) to:
  - Enable `openssh-server`
  - Create default non-root user (ubuntu, debian, cloud-user, or ecs-user)
  - Grant passwordless `sudo` for the default user
  - Prepopulate `authorized_keys` for the default user

**Scripts:**

- `build_all.sh`: Uses [distrobuilder - **Must** build from source!](https://github.com/lxc/distrobuilder/) to build custom images and copy them to the Proxmox-VE 9 node.
- `test_all.sh`: Provisions a container for each image to verify functionality.

**Edits to YAMLs:**

Generally, the edits consist of adding two blocks under `files`, adding a line (or a couple) under `packages`, and adding one block under `actions` though for Rocky, Amazon, and CentOS there are also edits related to the `source`.  The examples below are from `ubuntu.yaml`.

```yaml
files:
# allow ubuntu to sudo with no password JSD
- path: /etc/sudoers.d/90-sudo-nopasswd
  generator: dump
  mode: 0440
  content: |-
    # User rules for ubuntu
    ubuntu ALL=(ALL) NOPASSWD:ALL
  variants:
    - default

# add authorized_keys for hosts to ssh in as ubuntu JSD
- path: /home/ubuntu/.ssh/authorized_keys
  generator: copy
  source: authorized_keys
  mode: 0600
  uid: 1000
  gid: 1000
  variants:
  - default
```

```yaml
packages:
  manager: apt
  update: true
  cleanup: true
  sets:
  - packages:
    - fuse3
    releases:
    - jammy
    - noble
    - plucky
    - questing
    action: install

  - packages:
    - openssh-client
    - openssh-server  # allow ssh in JSD
    - sudo
    - vim
    action: install
```

```yaml
actions:
# add default user JSD
- trigger: post-update
  action: |-
    #!/bin/sh
    set -eux

    # Create the ubuntu user account
    getent group sudo >/dev/null 2>&1 || groupadd --system sudo
    useradd --create-home -s /bin/bash -G sudo -U ubuntu
  variants:
  - default
```


**Note on AmazonLinux 2023:**

AmazonLinux 2023 containers are not supported by default. Provisioning an AmazonLinux 2023 container will fail. See [PVE.md](proxmox_updates/PVE.md) for a workaround.