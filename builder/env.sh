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

# --- Optional components ---
SAI_WPS="${SAI_WPS:-1}"          # 0 = skip WPS Office (keep LMDE's LibreOffice)
WPS_DEB_URL="${WPS_DEB_URL:-}"   # alternative WPS .deb URL; empty = default in 50-office.sh

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

# --- squashfs compression: lz4 is fast for dev, xz is small for release ---
SQUASH_ARGS=(-comp lz4 -noappend)
use_release_compression() {
    SQUASH_ARGS=(-comp xz -b 1M -Xdict-size 100% -noappend)
}

# --- apt inside and outside the chroot ---
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout="${APT_LOCK_TIMEOUT:-600}")
