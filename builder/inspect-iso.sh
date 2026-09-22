#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Quick check of the boot branding in the ISO/workspace after a build.
#   bash builder/inspect-iso.sh [file.iso]
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
source builder/env.sh

ISO="${1:-$OUT_ISO}"

section() { echo ""; echo "===== $1 ====="; }

section "File ISO"
[ -f "$ISO" ] && ls -lh "$ISO" || echo "(not built yet: $ISO)"

section "Boot menu (isolinux) in workspace"
if [ -d "$ISO_TREE/isolinux" ]; then
    grep -RinE 'menu background|LMDE|Sai|boot=live' "$ISO_TREE/isolinux"/*.cfg | head -30
else
    echo "(no workspace — run sudo ./saibuild unpack first)"
fi

section "GRUB in workspace"
[ -f "$ISO_TREE/boot/grub/grub.cfg" ] && \
    grep -nE 'menuentry|background_image|quiet|splash' "$ISO_TREE/boot/grub/grub.cfg" | head -30 || \
    echo "(no grub.cfg)"

section "Plymouth in rootfs"
if [ -d "$ROOTFS/usr/share/plymouth/themes" ]; then
    # plain readlink, no root/chroot needed; the symlink in the rootfs uses an absolute path
    link_target=$(readlink "$ROOTFS/usr/share/plymouth/themes/default.plymouth" 2>/dev/null || echo "(no symlink)")
    echo "default.plymouth → $link_target"
    ls "$ROOTFS/usr/share/plymouth/themes/sai/" 2>/dev/null | head -8
else
    echo "(no rootfs)"
fi

section "Does the live initrd contain the Sai theme?"
INITRD=$(ls "$ISO_TREE"/live/initrd* "$ISO_TREE"/casper/initrd* 2>/dev/null | head -1)
if [ -n "$INITRD" ] && command -v lsinitramfs >/dev/null; then
    lsinitramfs "$INITRD" | grep -cE 'plymouth/themes/sai' | \
        xargs -I{} echo "{} sai theme file(s) in the initrd"
    lsinitramfs "$INITRD" | grep -E 'plymouth/themes/(mint-logo|bgrt)' | head -5 || echo "(no Mint/BGRT theme left — good)"
else
    echo "(no initrd or lsinitramfs missing)"
fi

section "ISO label + boot records"
[ -f "$ISO" ] && xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null | head -10 || true
