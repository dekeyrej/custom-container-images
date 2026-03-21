# **Custom LXC Image Builder for Proxmox‑VE 9**  
### **Terraform‑Ready • Ansible‑Ready • SSH‑Ready**

**Purpose:**  
Produce custom LXC images for Proxmox‑VE 9 that support seamless provisioning via OpenTofu/Terraform and immediate handoff to Ansible — without needing post‑creation hacks, push scripts, or manual fixes.

---

## 🚧 Why This Exists

Proxmox and upstream LXC images are excellent, but they don’t meet the needs of Terraform‑driven automation:

- Proxmox templates don’t create a non‑root user  
- linuxcontainers.org images don’t enable SSH or create a non‑root user  
- Terraform can’t provision a container it can’t SSH into  
- Ansible can’t run without a user + authorized_keys  

This repo solves all of that by generating **SSH‑ready, user‑ready, Ansible‑ready** LXC images.

---

## 🧩 Alternative Approaches (and why this repo takes a different path)

Several solutions *can* work:

- **Local Provisioner Script:**  
  Terraform `local-exec` → `pct push` + `pct exec`  
  *(Tested and works, but feels bolted‑on)*

- **Shared Inventory:**  
  Terraform + Ansible share inventory; Ansible performs initial setup  
  *(Proof of concept works)*

- **Hook Script:**  
  Proxmox container hook automates `pct push`/`pct exec`  
  *(Tested and works)*

- **Ansible Provider inside Terraform:**  
  Terraform provisions → Ansible provider configures  
  *(Complex example: [terraform-forward](https://github.com/dekeyrej/terraform-forward/tree/main))*

### **This repo’s approach:**  
Modify upstream [lxc-ci](https://github.com/lxc/lxc-ci/) definitions (e.g., `ubuntu.yaml`) to:

- Enable `openssh-server`
- Create a default non‑root user (`ubuntu`, `debian`, `cloud-user`, `ecs-user`)
- Grant passwordless sudo
- Prepopulate `authorized_keys`

This produces images that “just work” with Terraform and Ansible.

---

## 🔄 Provisioning Flow

```
Terraform → pct create → Custom LXC Image → SSH-ready non-root user → Ansible
```

---

## 🐧 Supported Distributions

| Distro | Status | Notes |
|--------|--------|-------|
| Ubuntu (jammy, noble, questing) | ✅ Working | user: `ubuntu` |
| Debian (bookworm, trixie) | ✅ Working | user: `debian` |
| CentOS Stream (9, 10) | ✅ Working | user: `cloud-user` |
| Rocky Linux (9, 10) | ✅ Working | user: `cloud-user` |
| Amazon Linux 2023 | ✅ Working* | user: `ecs-user`<br>See: [PVE.md](proxmox_updates/PVE.md) for workaround |

---

## 🚀 Getting Started

```bash
sudo apt install -y golang-go gcc debootstrap rsync gpg squashfs-tools git \
                   make build-essential libwin-hivex-perl wimtools genisoimage

git clone https://github.com/lxc/distrobuilder.git
cd distrobuilder
make
sudo install $HOME/go/bin/distrobuilder /usr/local/bin

cd ..
git clone https://github.com/dekeyrej/custom-container-images.git
cd custom-container-images

cp ~/.ssh/id_rsa.pub authorized_keys

# scp destinations for custom images
export PVENODES="iluvatar"                    
# physical path on the node(s) where lxc templates are stored
export PHYSICAL_IMAGE_PATH="/mnt/ssd_backup/template/cache"   

sudo ./build_all.sh
```

---

## 🛠 Scripts

- **`build_all.sh`**  
  Builds all images using **distrobuilder (must be built from source)** and copies them to the Proxmox‑VE 9 node.

---

## 🧬 YAML Modifications (Example: Ubuntu)

Most distros require:

- Two `files` blocks  
- One or two `packages` edits  
- One `actions` block  
- Some distros (Rocky, CentOS, Amazon) also require `source` tweaks

### **files**
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

### **packages**
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

### **actions**
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

---

## ⚠️ Amazon Linux 2023

AmazonLinux 2023 containers are **not supported by Proxmox by default**.  
Provisioning will fail unless Proxmox is patched.

See: **[PVE.md](proxmox_updates/PVE.md)** for a workaround.