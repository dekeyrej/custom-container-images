# **Proxmox‑VE LXC Updates to Support Amazon Linux 2023**

Amazon Linux 2023 containers are **not supported by Proxmox‑VE by default**.  
Attempting to create an AL2023 container with `pct` will fail unless Proxmox is patched to recognize the distro and route setup through a proper handler.

This document describes the minimal, surgical updates required to enable:

- OS detection for Amazon Linux 2023  
- Correct dispatch to a dedicated setup module  
- NetworkManager‑compatible configuration generation  
- Clean provisioning via `pct create`  

These patches are intentionally small, reversible, and isolated.

---

## ⚙️ Required Patches

Apply the following modifications on the Proxmox node:

### **1. `/usr/share/perl5/PVE/LXC/Config.pm`**  
Add amazon to the list of valid ostype values (line 520 in my version):

```perl
ostype => {
        optional => 1,
        type => 'string',
        enum => [
            qw(debian devuan ubuntu centos fedora opensuse archlinux alpine gentoo nixos amazon unmanaged)
        ],
        description =>
            "OS type. This is used to setup configuration inside the container, and corresponds to lxc setup scripts in /usr/share/lxc/config/<ostype>.common.conf. Value 'unmanaged' can be used to skip and OS specific setup.",
    },
```

### **2. `/usr/share/perl5/PVE/LXC/Setup.pm`**  
Add the Amazon Linux setup module and register it in the plugin tables and detection logic (all within the first 100 lines).

```perl
#(...)
use PVE::LXC::Setup::Alpine;
use PVE::LXC::Setup::Amazon;
use PVE::LXC::Setup::ArchLinux;

#(...)
my $plugins = {
    alpine => 'PVE::LXC::Setup::Alpine',
    amazon => 'PVE::LXC::Setup::Amazon',
    archlinux => 'PVE::LXC::Setup::ArchLinux',
#(...)
my $plugin_alias = {
    'opensuse-leap' => 'opensuse',
    'opensuse-tumbleweed' => 'opensuse',
    'opensuse-slowroll' => 'opensuse',
    'openEuler' => 'openeuler',
    amzn => 'amazon',
    arch => 'archlinux',
#(...)
} elsif (-f "$rootdir/etc/openEuler-release") {
        return "openeuler";
    } elsif (-e "$rootdir/etc/amazon-linux-release") {
        return "amazon";
    } elsif (-f "$rootdir/etc/os-release") {
        die "unable to detect OS distribution\n";
    } else {
#(...)
```

This enables both:
- Alias detection (ID=amzn → amazon)
- Direct detection via /etc/amazon-linux-release
Together, they allow pct create to auto‑recognize Amazon Linux rootfs images.

### **3. `/usr/share/perl5/PVE/LXC/Setup/Amazon.pm`**  

Copy Fedora.pm to Amazon.pm and edit the three lines marked with `# JSD` 
 - line  1: ```package PVE::LXC::Setup::Amazon;```
 - line 15: ```die "unsupported Amazon release '$version'\n" if !defined($version) || $version != 2023;```
 - line 19: ```$conf->{ostype} = "amazon";```

A complete version of this file is included in this repository under
```
proxmox_updates/Setup/Amazon.pm
```

---

## 🎁 Bonus: `pct create` Auto‑Detects Amazon Linux via `/etc/os-release`

Once these patches are applied, **no special flags are required** when creating an Amazon Linux 2023 container.

Proxmox’s `pct` tool will correctly identify the OS based on the rootfs’s `/etc/os-release`:

- `ID=amzn`  
- `ID_LIKE="fedora rhel centos"`  
- `VERSION_ID="2023"`

With the patched `Config.pm` and `Setup.pm`, this automatically maps to the new setup module:

```
pct create <vmid> /path/to/al2023-rootfs.tar.xz
```

No need to specify `--ostype amazon`.  
Detection happens as soon as the rootfs is unpacked.

From the CLI’s perspective, Amazon Linux behaves like any other first‑class distro.

---

## 📝 What This Patch Enables

- `pct create` works cleanly with Amazon Linux 2023  
- Systemd boots without errors  
- NetworkManager receives a valid, Proxmox‑compatible config  
- SSH + user provisioning (from your custom image) works as expected  
- Terraform → pct → Ansible workflows function normally  

This is everything needed for your automation pipeline.

---

## ⚠️ Important Limitations

This patch **does not** modify the Proxmox API layer.

- The Proxmox API still does not officially recognize Amazon Linux  
- Terraform’s Proxmox provider and Ansible’s Proxmox modules will not gain new API‑level capabilities  
- Only the **CLI (`pct`)** benefits from these changes  

If your workflow uses Terraform to call `pct` directly, you’re good.  
If you rely on the Proxmox API to create containers, this patch will not help.

---

## 🧪 Stability Notes

These patches are:

- Minimal  
- Easy to revert  
- Tested on Proxmox‑VE 9.x  
- Compatible with distrobuilder‑generated AL2023 images  
- Safe for NetworkManager‑based networking  
- Non‑intrusive to other distros  

They do not modify any core Proxmox logic beyond adding a new distro handler.