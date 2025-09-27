#!/bin/bash
pvenode=iluvatar

build_image() {
  local distro=$1
  local release=$2

  echo "🔧 Building $distro:$release..."
  distrobuilder build-lxc $distro.yaml ./$distro/$release \
    -o image.architecture=amd64 \
    -o image.release=$release \
    -o image.variant=default

  if [[ $? -ne 0 ]]; then
    echo "❌ Build failed for $distro:$release"
    exit 1
  fi

  mv $distro/$release/rootfs.tar.xz $distro-$release-latest-custom.tar.xz
  rm -rf $distro
  echo "✅ Finished $distro:$release"
  scp -i /home/ubuntu/.ssh/id_rsa $distro-$release-latest-custom.tar.xz \
                                  root@$pvenode:/var/lib/vz/template/cache/
}

build_centos_image() {
  local distro=$1
  local release=$2

  echo "🔧 Building $distro:$release-Stream..."
  distrobuilder build-lxc $distro.yaml ./$distro/$release \
    -o image.architecture=x86_64 \
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
  scp -i /home/ubuntu/.ssh/id_rsa $distro-$release-stream-latest-custom.tar.xz \
                                  root@$pvenode:/var/lib/vz/template/cache/
}

# Ubuntu builds
for release in noble plucky; do
  build_image ubuntu $release
done

# Debian builds
for release in bookworm trixie; do
  build_image debian $release
done

# CentOS builds
for release in 9 10; do
  build_centos_image centos $release
done
