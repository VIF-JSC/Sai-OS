#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Sai build settings. Every value can be overridden via the environment.
# shellcheck disable=SC2034  # variables here are used by builder/*.sh after sourcing

# --- Product ---
SAI_VERSION="${SAI_VERSION:-1.0.0}"
SAI_NAME="Sai"

# --- Base ISO: LMDE (Linux Mint Debian Edition, Debian 13 Trixie) ---
BASE_VERSION="${BASE_VERSION:-7}"
BASE_EDITION="${BASE_EDITION:-cinnamon}"
BASE_ISO_FILE="lmde-${BASE_VERSION}-${BASE_EDITION}-64bit.iso"
BASE_ISO_URL="https://mirrors.kernel.org/linuxmint/debian/${BASE_ISO_FILE}"

# --- apt mirror inside the chroot (empty = keep deb.debian.org) ---
# Example for Vietnam: APT_MIRROR=http://mirror.bizflycloud.vn/debian
APT_MIRROR="${APT_MIRROR:-}"

# --- Working directories ---
WORK="${WORK:-./build}"
ISO_TREE="$WORK/iso-tree"            # ISO contents being edited
ROOTFS="$WORK/rootfs"                # filesystem being edited
CACHE_ROOTFS="$WORK/.cache/rootfs"   # pristine extraction, done once
CACHE_ISO="$WORK/.cache/iso-tree"

# --- Output ---
OUT_ISO="${OUT_ISO:-Sai-${SAI_VERSION}-amd64.iso}"
# ISO volume label: ISO 9660 allows only A-Z 0-9 _ (a hyphen triggers warnings)
ISO_LABEL="SAI"

# --- Cloud image (./saibuild cloud) ---
# Output base name (relative to the repo, or an absolute path); each format adds
# its own extension (.raw, .qcow2, ...)
OUT_CLOUD="${OUT_CLOUD:-Sai-${SAI_VERSION}-cloud-amd64}"
# Comma-separated: raw (default; AWS snapshot, dd, any qemu-img input),
# qcow2 (OpenStack/KVM/Proxmox), vmdk (VMware/AWS), vhd (Azure), gce (Google Cloud tar.gz)
CLOUD_FORMATS="${CLOUD_FORMATS:-raw}"
CLOUD_DISK_GB="${CLOUD_DISK_GB:-}"   # working disk while building; empty = rootfs size + 25%
CLOUD_SHRINK="${CLOUD_SHRINK:-1}"    # 1 = final raw disk sized to data + CLOUD_SLACK_MB
CLOUD_SLACK_MB="${CLOUD_SLACK_MB:-1024}"  # free space left in root before growpart runs
CLOUD_RDP="${CLOUD_RDP:-1}"          # 1 = xrdp remote desktop on 3389; 0 = SSH only
CLOUD_USER="${CLOUD_USER:-saiadmin}" # default cloud-init user (password comes from the cloud)

# --- squashfs compression: lz4 is fast for dev, xz is small for release ---
SQUASH_ARGS=(-comp lz4 -noappend)
use_release_compression() {
    SQUASH_ARGS=(-comp xz -b 1M -Xdict-size 100% -noappend)
}

# --- apt inside and outside the chroot ---
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout="${APT_LOCK_TIMEOUT:-600}")
