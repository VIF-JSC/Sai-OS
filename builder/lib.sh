#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared helpers: logging, environment checks, workspace + chroot management.

_c_dim='\033[2m'; _c_red='\033[31m'; _c_grn='\033[32m'; _c_ylw='\033[33m'; _c_off='\033[0m'

say()  { echo -e "${_c_dim}::${_c_off} $*"; }
done_() { echo -e "${_c_grn} ✓${_c_off} $*"; }
note() { echo -e "${_c_ylw} !${_c_off} $*"; }
fail() { echo -e "${_c_red} ✗${_c_off} $*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || fail "Root required. Run: sudo ./saibuild"
}

# Install missing host tools (Debian/Ubuntu/Mint hosts only)
require_host_tools() {
    local missing=()
    local t
    for t in unsquashfs mksquashfs xorriso rsync wget; do
        command -v "$t" >/dev/null || missing+=("$t")
    done
    [ -f /usr/lib/ISOLINUX/isohdpfx.bin ] || missing+=(isolinux)
    if [ ${#missing[@]} -gt 0 ]; then
        say "Missing tools: ${missing[*]} — installing..."
        "${APT[@]}" update -qq
        "${APT[@]}" install -y squashfs-tools xorriso rsync wget isolinux syslinux-utils
    fi
}

# Locate the base ISO: argument → existing file → download.
# With a complete extraction cache the ISO is not needed, so skip the ~3 GB download.
locate_base_iso() {
    if [ -z "${1:-}" ] && [ -d "$CACHE_ROOTFS" ] && [ -d "$CACHE_ISO" ]; then
        BASE_ISO=""
        say "Using the existing extraction cache — base ISO not needed."
        return 0
    fi
    if [ -n "${1:-}" ]; then
        [ -f "$1" ] || fail "ISO file not found: $1"
        BASE_ISO="$1"
    elif [ -f "$BASE_ISO_FILE" ]; then
        BASE_ISO="$BASE_ISO_FILE"
    else
        say "Downloading ${BASE_ISO_FILE} (~3 GB)..."
        wget -c --progress=bar:force -O "$BASE_ISO_FILE" "$BASE_ISO_URL"
        BASE_ISO="$BASE_ISO_FILE"
    fi
    say "Base ISO: $BASE_ISO"
}

workspace_ready() { [ -d "$ROOTFS" ] && [ -d "$ISO_TREE" ]; }

# --- Chroot: mount/unmount virtual filesystems + DNS ---
enter_rootfs() {
    local m
    for m in dev dev/pts proc sys; do
        mountpoint -q "$ROOTFS/$m" && continue
        case "$m" in
            dev)     mount --bind /dev "$ROOTFS/dev" ;;
            dev/pts) mount --bind /dev/pts "$ROOTFS/dev/pts" ;;
            proc)    mount -t proc proc "$ROOTFS/proc" ;;
            sys)     mount -t sysfs sysfs "$ROOTFS/sys" ;;
        esac
    done
    # resolv.conf in the ISO is a symlink to systemd-resolved (dangling inside
    # the chroot); replace it with the host's so apt can resolve DNS.
    rm -f "$ROOTFS/etc/resolv.conf"
    cat /etc/resolv.conf > "$ROOTFS/etc/resolv.conf"
}

leave_rootfs() {
    sync || true
    local m
    for m in proc sys dev/pts dev; do
        umount "$ROOTFS/$m" 2>/dev/null || umount -lf "$ROOTFS/$m" 2>/dev/null || true
    done
}

# Run a command inside the rootfs
run_in_rootfs() {
    chroot "$ROOTFS" /bin/bash -c "$1"
}

# Remove the workspace; refuse if anything is still mounted (protects the host)
drop_workspace() {
    leave_rootfs
    umount "$WORK/mnt" 2>/dev/null || true
    if grep -q " $(readlink -f "$ROOTFS" 2>/dev/null || echo "$ROOTFS")/" /proc/mounts 2>/dev/null; then
        fail "Mounts still active under $ROOTFS — not removing. Unmount with: sudo umount -Rlf $ROOTFS"
    fi
    rm -rf "${ROOTFS:?}" "${ISO_TREE:?}" "${WORK:?}/mnt"
}

show_result() {
    echo ""
    done_ "Build complete: $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"
    echo ""
    echo "  Write USB:  sudo dd if=$OUT_ISO of=/dev/sdX bs=4M status=progress"
    echo "  Test VM:    qemu-system-x86_64 -m 4G -enable-kvm -boot d -cdrom $OUT_ISO"
    echo ""
}
