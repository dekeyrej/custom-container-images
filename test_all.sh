#!/bin/bash

build_container() {
  local vmid=$1
  local template=$2
  local ostype=$3
  local hostname=$4
  local ipaddress=$5
  local pool=$6


  ssh iluvatar pct create $vmid local:vztmpl/$template --hostname $hostname \
             --ostype $ostype --rootfs local-lvm:8 --arch amd64 \
             --net0 name=eth0,bridge=vmbr0,gw=192.168.86.1,ip=$ipaddress/24 \
             --cores 2 --memory 2048 --swap 0 --pool $pool --start --unprivileged 1

  if [[ $? -ne 0 ]]; then
    echo "❌ Test failed for VMID $vmid ($hostname)"
    exit 1
  fi

  echo "✅ Test succeeded for VMID $vmid ($hostname)"
}

build_container 200 "ubuntu-noble-latest-custom.tar.xz"     "ubuntu" "pippin"  "192.168.86.92"  "Shire"
build_container 201 "ubuntu-questing-latest-custom.tar.xz"  "ubuntu" "merry"   "192.168.86.93"  "Shire"
build_container 202 "debian-bookworm-latest-custom.tar.xz"  "debian" "boromir" "192.168.86.96"  "Gondor"
build_container 203 "debian-trixie-latest-custom.tar.xz"    "debian" "faramir" "192.168.86.97"  "Gondor"
build_container 204 "centos-9-stream-latest-custom.tar.xz"  "centos" "eomer"   "192.168.86.101" "Rohan"
build_container 205 "centos-10-stream-latest-custom.tar.xz" "centos" "eowyn"   "192.168.86.102" "Rohan"
