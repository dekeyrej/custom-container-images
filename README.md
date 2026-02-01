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

**Note on AmazonLinux 2023:**

AmazonLinux 2023 containers are not supported by default. Provisioning an AmazonLinux 2023 container will fail. Until official support lands, you can (if you dare) patch:
- `/usr/share/perl5/PVE/LXC/Config.pm` -- one word to add (search for amazon in the local file to see where)
- `/usr/share/perl5/PVE/LXC/Setup.pm`  -- 6 new lines to add (search for amazon in the local file to see where)
- `/usr/share/perl5/PVE/LXC/Setup/Amazon.pm` -- new file

Using the files in this repository. This enables amazonlinux-2023 recognition and generates a NetworkManager-compliant config.

⚠️ This patch only affects command-line provisioning via `pct`.