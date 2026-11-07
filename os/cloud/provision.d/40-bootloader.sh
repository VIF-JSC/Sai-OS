#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: initramfs with every virtual disk/NIC driver, then GRUB for both
# BIOS (i386-pc) and UEFI (shim + signed GRUB when available, for Secure Boot).
# CLOUD_LOOP is the whole-disk loop device, passed in by builder/cloud.sh.
set -e
[ -b "${CLOUD_LOOP:-}" ] || { echo "[cloud] CLOUD_LOOP is not a block device" >&2; exit 1; }

# /etc/default/grub normally comes from grub-pc/grub-efi-amd64; only the -bin
# packages are installed here, so make sure the file exists.
[ -f /etc/default/grub ] || cat > /etc/default/grub <<'CFG'
GRUB_DEFAULT=0
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR="Sai"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""
CFG

echo "[cloud] Rebuilding initramfs (installed system, cloud drivers)..."
update-initramfs -u -k all
for k in /boot/initrd.img-*; do
    lsinitramfs "$k" | grep -qE 'virtio_blk|virtio_scsi' \
        || echo "[cloud] WARNING: virtio driver not found in $k (may be built into the kernel)"
done

echo "[cloud] GRUB for BIOS..."
grub-install --target=i386-pc --recheck "$CLOUD_LOOP"

echo "[cloud] GRUB for UEFI..."
if [ -f /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed ] && \
   [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    # The signed GRUB looks for its config under /EFI/debian; keep that id.
    # --force-extra-removable also installs \EFI\BOOT\BOOTX64.EFI (no NVRAM in images).
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian \
                 --uefi-secure-boot --no-nvram --force-extra-removable
    echo "[cloud] UEFI: shim + signed GRUB (Secure Boot capable)"
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian \
                 --no-uefi-secure-boot --no-nvram --removable
    echo "[cloud] UEFI: unsigned GRUB (disable Secure Boot on the VM)"
fi

update-grub
grep -q 'console=ttyS0' /boot/grub/grub.cfg || { echo "[cloud] ERROR: serial console missing from grub.cfg" >&2; exit 1; }
grep -q 'root=UUID=' /boot/grub/grub.cfg    || { echo "[cloud] ERROR: grub.cfg does not mount root by UUID" >&2; exit 1; }
test -f /boot/efi/EFI/BOOT/BOOTX64.EFI       || { echo "[cloud] ERROR: no removable UEFI loader" >&2; exit 1; }
echo "[cloud] bootloader installed."
