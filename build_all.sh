#!/usr/bin/env bash
set -euo pipefail

# override with PVENODES="bluep bluep02 bluep03"
default_nodes="iluvatar"
pvenodes_str="${PVENODES:-$default_nodes}"
read -r -a pvenodes <<< "$pvenodes_str"

# override with PHYSICAL_IMAGE_PATH="/mnt/bucket/template/cache/"
ct_image_dir=${PHYSICAL_IMAGE_PATH:-"/mnt/ssd_backup/template/cache/"}

echo "Custom Container Build Log - $(date)" > container_log.txt

amazon_tarball() {
  local arch=$1

  BASE_URL="https://cdn.amazonlinux.com/al2023/os-images/latest/container"

  # Fetch listing and extract the tarball name
  TARBALL=$(curl -fsSL "$BASE_URL/" \
    | grep -oP '(?<=href=")al2023-container-[^"]*'"$arch"'\.tar\.xz' \
    | head -n1)

  if [ -z "$TARBALL" ]; then
    echo "Could not determine latest AL2023 rootfs tarball" >&2
    exit 1
  fi

  curl -fL -O "$BASE_URL/$TARBALL"
  echo "$TARBALL"
}

build_image() {
  local distro=$1
  local release=$2
  local arch=$3
  local extra_opts=()

  if [[ ! -f authorized_keys ]]; then
    echo "authorized_keys not found!"
    exit 1
  fi

  echo "🔧 Building $distro:$release..."

  if [[ $distro == "amazonlinux" ]]; then
    TARBALL=$(amazon_tarball "$arch")
    extra_opts+=(-o source.url="file://$PWD/$TARBALL")
  fi

  distrobuilder build-lxc "definitions/$distro.yaml" "./$distro/$release" \
    -o image.architecture="$arch" \
    -o image.release="$release" \
    -o image.variant=default \
    "${extra_opts[@]}"

  if [[ $? -ne 0 ]]; then
    echo "❌ Build failed for $distro:$release"
    echo "❌ Build failed for $distro:$release at $(date)" >> container_log.txt
    exit 1
  fi

  [[ $distro == "amazonlinux" ]] && rm -f "$TARBALL"


  mv "$distro/$release/rootfs.tar.xz" "$distro-$release-latest-custom.tar.xz"
  rm -rf "$distro"
  echo "✅ Finished $distro:$release"
  echo "✅ Finished $distro:$release at $(date)" >> container_log.txt
  for h in "${pvenodes[@]}"; do
      scp -i /home/ubuntu/.ssh/id_rsa \
          "$distro-$release-latest-custom.tar.xz" \
          "root@$h:$ct_image_dir"
  done
}

# Ubuntu builds - creates ubuntu user
build_image ubuntu jammy amd64
build_image ubuntu noble amd64
build_image ubuntu questing amd64

# Debian builds - creates debian user
build_image debian bookworm amd64
build_image debian trixie amd64
build_image debian forky amd64

# Rocky Linux builds - creates cloud-user
build_image rockylinux  9 x86_64
build_image rockylinux 10 x86_64

# CentOS builds - creates cloud-user
# build_image centos  9-Stream x86_64
# build_image centos 10-Stream x86_64

# Amazon Linux 2023 build - creates ecs-user
build_image amazonlinux 2023 x86_64

echo "Custom Container Build Complete - $(date)" >> container_log.txt
