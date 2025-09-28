# Configurations and Script to build LXC images

**Purpose:** Build lxc images for use with Proxmox-VE 9 such that containers can be provisioned with OpenTufu/Terraform and be immediately handed off to Ansible for management.

**Problem:** The default CT templates provided by Proxmox don't create a non-root user (and thus, don't set authorized_keys for a non-root user), and the lxc images from linuxcontainers.org don't enable openssh-server by default(, nor create a non-root user???).  With either option some sort 'intermediate step' is required to prepare the resulting container for management.

**Possible Solutions:**
- Create a 'local-action' provisioner for tf to 'touch up' the container with a `pct push` of a script, and a `pct exec` to run the script. This is an avenue for follow-on exploration.
- Wire tf and ansible together such that they share a common view of the inventory so that ansible can `touch up` the containers.  This requires two steps (tf and ansible) before the container can even be accessed. (proof of concept works)
- Create and apply a `hook script` to the container configuration to execute the `pct push`/`pct exec` actions.  (works/tested)
- **This Repo** Modify existing [lxc-ci](https://github.com/lxc/lxc-ci.git) images (e.g., `ubuntu.yaml`) to enable openssh-server, create a non-root user, enable sudo (without password) for the non-root user, and prepopulate the non-root user's authorized_keys.

The `build_all.sh` script uses [distrobuilder](https://github.com/lxc/distrobuiler.git) to build the custom images, and copy them to my Proxmox-VE 9 node.

The `test_all.sh` script provisions a modest container for each image to verify functionality.

**Note:** `centos 10` is very new.  As such, (as of: Proxmox-VE 9.0.6), trying to provision a `centos 10` container will fail.  Until it is officially released, you can (if you dare) update /usr/share/perl5/PVE/LXC/Setup/CentOS.pm from [here:](https://raw.githubusercontent.com/proxmox/pve-container/refs/heads/master/src/PVE/LXC/Setup/CentOS.pm). This recognizes CentOS `10` as valid _and_ builds a NetworkManager compliant configuration.  This update _only_ 'fixes' command-line creation using `pct`.  Down-stream updates to the tf provider will still be required before `centos 10` can be provisioned that way.