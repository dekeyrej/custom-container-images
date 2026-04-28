#!/usr/bin/env bash
set -euo pipefail

# override with PVENODES="bluep bluep02 bluep03"
home_dir=$(eval echo ~${SUDO_USER:-$USER})
log_file="$home_dir/repos/custom-container-images/container_log.txt"
echo "Home directory: $home_dir"

default_nodes="iluvatar"
pvenodes_str="${PVENODES:-$default_nodes}"
read -r -a pvenodes <<< "$pvenodes_str"

# override with PHYSICAL_IMAGE_PATH="/mnt/bucket/template/cache/"
ct_image_dir=${PHYSICAL_IMAGE_PATH:-"/mnt/ssd_backup/template/cache/"}

echo "Custom Container Build Started - $(date)" > $log_file

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
  local extra_opts=()

  if [[ $distro == "amazonlinux" || $distro == "centos" || $distro == "rockylinux" ]]; then
    local arch="x86_64"
  else # default to amd64 for ubuntu/debian
    local arch="amd64"
  fi

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
    echo "❌ Build failed for $distro:$release at $(date)" >> $log_file
    exit 1
  fi

  [[ $distro == "amazonlinux" ]] && rm -f "$TARBALL"


  mv "$distro/$release/rootfs.tar.xz" "$distro-$release-latest-custom.tar.xz"
  rm -rf "$distro"
  echo "✅ Finished $distro:$release"
  echo "✅ Finished $distro:$release at $(date)" >> $log_file
  for h in "${pvenodes[@]}"; do
      scp -i /home/ubuntu/.ssh/id_rsa \
          "$distro-$release-latest-custom.tar.xz" \
          "root@$h:$ct_image_dir"
  done
}

print_usage() {
  cat <<EOF
Usage: $0 [options] [distro:release ...]

If one or more "distro:release" arguments are provided, the script will
build each specified image in order. If no arguments are provided, the
script will build the default images (ubuntu:resolute and debian:forky).

Examples:
  $0 ubuntu:resolute debian:forky
  $0 amazonlinux:2023

Options:
  -h, --help    Show this help message
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  print_usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  # Use provided distro:release args
  for img in "$@"; do
    if [[ "$img" != *:* ]]; then
      echo "Invalid image specification: $img" >&2
      print_usage
      exit 1
    fi
    distro="${img%%:*}"
    release="${img#*:}"
    if [[ ! -f "definitions/$distro.yaml" ]]; then
      echo "Unknown distribution or missing definition: $distro" >&2
      exit 1
    fi
    build_image "$distro" "$release"
  done
else
  # No args: fall back to previous default builds
  default_images=("ubuntu:resolute" "debian:forky")
  for img in "${default_images[@]}"; do
    distro="${img%%:*}"
    release="${img#*:}"
    build_image "$distro" "$release"
  done
fi

echo "Custom Container Build Complete - $(date)" >> $log_file
