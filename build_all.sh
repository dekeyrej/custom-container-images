#!/bin/bash
pvenode=iluvatar

build_image() {
  local distro=$1
  local release=$2
  local arch=$3

  if [[ ! -f authorized_keys ]]; then
    echo "authorized_keys not found!"
    exit 1
  fi

  echo "🔧 Building $distro:$release..."
    distrobuilder build-lxc $distro.yaml ./$distro/$release \
    -o image.architecture=$arch \
    -o image.release=$release \
    -o image.variant=default

  if [[ $? -ne 0 ]]; then
    echo "❌ Build failed for $distro:$release"
    exit 1
  fi

  mv $distro/$release/rootfs.tar.xz $distro-$release-latest-custom.tar.xz
  rm -rf $distro
  echo "✅ Finished $distro:$release"
  scp -i /home/ubuntu/.ssh/id_rsa \
      $distro-$release-latest-custom.tar.xz \
      root@$pvenode:/var/lib/vz/template/cache/
}

build_amazon_image() {
  local distro=$1
  local release=$2

  if [[ ! -f authorized_keys ]]; then
    echo "authorized_keys not found!"
    exit 1
  fi

  BASE_URL="https://cdn.amazonlinux.com/al2023/os-images/latest/container"

  # Fetch listing and extract the tarball name
  TARBALL=$(curl -fsSL "$BASE_URL/" \
    | grep -oP '(?<=href=")al2023-container-[^"]*x86_64\.tar\.xz' \
    | head -n1)

  if [ -z "$TARBALL" ]; then
    echo "Could not determine latest AL2023 rootfs tarball" >&2
    exit 1
  fi
  echo "Downloading $TARBALL..."
  curl -fL -O "$BASE_URL/$TARBALL"

  echo "🔧 Building $distro:$release..."
  distrobuilder build-lxc $distro.yaml ./$distro/$release \
    -o image.architecture=amd64 \
    -o image.release=$release \
    -o image.variant=default \
    -o source.url="file://$PWD/$TARBALL"

  if [[ $? -ne 0 ]]; then
    echo "❌ Build failed for $distro:$release"
    exit 1
  fi

  mv $distro/$release/rootfs.tar.xz $distro-$release-latest-custom.tar.xz
  rm -rf $distro
  echo "✅ Finished $distro:$release"
  scp -i /home/ubuntu/.ssh/id_rsa \
      $distro-$release-latest-custom.tar.xz \
      root@$pvenode:/var/lib/vz/template/cache/
  # Clean up downloaded tarball
  rm -f $TARBALL
}

build_centos_image() {
  local distro=$1
  local release=$2
  local arch=$3

  if [[ ! -f authorized_keys ]]; then
    echo "authorized_keys not found!"
    exit 1
  fi

  echo "🔧 Building $distro:$release-Stream..."
  distrobuilder build-lxc $distro.yaml ./$distro/$release \
    -o image.architecture=$arch \
    -o image.release=$release-Stream \
    -o image.variant=default \
    -o source.variant=boot \
    -o source.url=https://mirror.math.princeton.edu/pub/centos-stream/

  if [[ $? -ne 0 ]]; then
    echo "❌ Build failed for $distro:$release-Stream"
    exit 1
  fi

  mv $distro/$release/rootfs.tar.xz $distro-$release-stream-latest-custom.tar.xz
  rm -rf $distro
  echo "✅ Finished $distro:$release-Stream"
  scp -i /home/ubuntu/.ssh/id_rsa \
      $distro-$release-stream-latest-custom.tar.xz \
      root@$pvenode:/var/lib/vz/template/cache/
}

# Ubuntu builds
for release in noble questing; do
  build_image ubuntu $release amd64
done

# Debian builds
for release in bookworm trixie; do
  build_image debian $release amd64
done

# CentOS builds
for release in 9 10; do
  build_centos_image centos $release x86_64
done

# Rocky Linux builds
for release in 9 10; do
  build_image rockylinux $release x86_64
done

# Amazon Linux 2023 build
build_amazon_image amazonlinux 2023
