#!/usr/bin/env bash
set -euo pipefail
pvenode=iluvatar
ct_image_dir="/mnt/ssd_backup/template/cache/"

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
  scp -i /home/ubuntu/.ssh/id_rsa \
      "$distro-$release-latest-custom.tar.xz" \
      root@$pvenode:$ct_image_dir
}

# Ubuntu builds - creates ubuntu user
for release in jammy noble questing; do
  build_image ubuntu $release amd64
done

# Debian builds - creates debian user
for release in bookworm trixie forky; do
  build_image debian $release amd64
done

# Rocky Linux builds - creates cloud-user
for release in 9 10; do
  build_image rockylinux $release x86_64
done

# CentOS builds - creates cloud-user
for release in 9-Stream 10-Stream; do
  build_image centos $release x86_64
done

# Amazon Linux 2023 build - creates ecs-user
build_image amazonlinux 2023 x86_64

echo "Custom Container Build Complete - $(date)" >> container_log.txt