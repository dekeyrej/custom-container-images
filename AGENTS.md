# AGENTS.md - Custom LXC Image Builder

## Build System
- **Core Tool:** Uses `distrobuilder` (must be built from source).
- **Definitions:** YAML files in `definitions/` define the image layout, packages, and user creation.
- **Artifacts:** Produces `.tar.xz` rootfs images.

## Critical Commands
- **Build Specific Images:** `sudo ./build_image.sh distro:release` (e.g., `sudo ./build_image.sh ubuntu:noble`)
- **Build All Defaults:** `sudo ./build_all.sh`
- **Verification:** Check `container_log.txt` for build status.

## Environment Requirements
The build scripts rely on these environment variables for deploying images to Proxmox nodes:
- `PVENODES`: Space-separated list of target Proxmox nodes (defaults to `iluvatar`).
- `PHYSICAL_IMAGE_PATH`: Path on the target nodes where templates are stored (defaults to `/mnt/ssd_backup/template/cache/`).
- **Sudo Note:** If running via sudo, these must be added to `/etc/sudoers`: `Defaults:%sudo env_keep += "PVENODES PHYSICAL_IMAGE_PATH"`.

## Operational Gotchas
- **SSH Keys:** A local `authorized_keys` file is **required** in the root directory; it is baked into the images.
- **Amazon Linux 2023:** Not supported by Proxmox by default; requires patches described in `proxmox_updates/PVE.md`.
- **Build Process:** `build_image.sh` handles `amd64` vs `x86_64` architecture mapping based on the distribution.
