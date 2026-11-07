#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: turn the provisioned rootfs into a bootable VM disk
# (BIOS + UEFI/Secure Boot, cloud-init, auto-grow root) and export it as
# qcow2 / vmdk / vhd / gce / raw.
#
# The ISO rootfs ($ROOTFS) is only READ here: it is copied into the disk image
# and every cloud-specific change (os/cloud/) happens inside that copy, so the
# same workspace can still produce the live ISO.

CLOUD_MNT="$WORK/cloud-mnt"
CLOUD_LOOP=""

require_cloud_tools() {
    local missing=() t
    for t in losetup sfdisk sgdisk mkfs.vfat mkfs.ext4 qemu-img partx blkid; do
        command -v "$t" >/dev/null || missing+=("$t")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        say "Missing cloud tools: ${missing[*]} — installing..."
        "${APT[@]}" update -qq
        "${APT[@]}" install -y qemu-utils dosfstools e2fsprogs fdisk gdisk util-linux
    fi
}

# Size of the disk: rootfs + 25% + 1 GiB, rounded up to whole GiB (Azure needs
# MiB alignment; whole GiB also satisfies AWS/GCP). Override with CLOUD_DISK_GB.
cloud_disk_gb() {
    if [ -n "${CLOUD_DISK_GB:-}" ]; then echo "$CLOUD_DISK_GB"; return; fi
    local used_kb
    used_kb=$(du -sx --block-size=1K "$ROOTFS" | cut -f1)
    echo $(( (used_kb * 5 / 4) / 1024 / 1024 + 2 ))
}

# Partition nodes (/dev/loopNpX) may not appear inside containers without udev;
# create them from sysfs when missing.
cloud_ensure_part_nodes() {
    local loop="$1" name part n
    name=$(basename "$loop")
    partx -u "$loop" 2>/dev/null || true
    for part in /sys/block/"$name"/"$name"p*; do
        [ -e "$part/dev" ] || continue
        n="/dev/$(basename "$part")"
        # devtmpfs may create the node at the same moment: ignore "File exists"
        [ -b "$n" ] || mknod "$n" b "$(cut -d: -f1 "$part/dev")" "$(cut -d: -f2 "$part/dev")" 2>/dev/null || true
    done
    local _
    for _ in 1 2 3 4 5; do [ -b "${loop}p3" ] && return 0; sleep 1; done
    fail "Partition devices for $loop did not appear"
}

cloud_mount_virtual() {
    local m
    for m in dev dev/pts proc sys run; do mkdir -p "$CLOUD_MNT/$m"; done
    mountpoint -q "$CLOUD_MNT/dev"     || mount --bind /dev "$CLOUD_MNT/dev"
    mountpoint -q "$CLOUD_MNT/dev/pts" || mount --bind /dev/pts "$CLOUD_MNT/dev/pts"
    mountpoint -q "$CLOUD_MNT/proc"    || mount -t proc proc "$CLOUD_MNT/proc"
    mountpoint -q "$CLOUD_MNT/sys"     || mount -t sysfs sysfs "$CLOUD_MNT/sys"
    mountpoint -q "$CLOUD_MNT/run"     || mount -t tmpfs tmpfs "$CLOUD_MNT/run"
    rm -f "$CLOUD_MNT/etc/resolv.conf"
    cat /etc/resolv.conf > "$CLOUD_MNT/etc/resolv.conf"
}

# Unmount everything and detach the loop device. Safe to call repeatedly.
cloud_teardown() {
    sync || true
    if [ -d "$CLOUD_MNT" ]; then
        local m
        for m in run sys proc dev/pts dev boot/efi ""; do
            mountpoint -q "$CLOUD_MNT/$m" 2>/dev/null && \
                { umount "$CLOUD_MNT/$m" 2>/dev/null || umount -lf "$CLOUD_MNT/$m" 2>/dev/null || true; }
        done
    fi
    if [ -n "$CLOUD_LOOP" ]; then
        losetup -d "$CLOUD_LOOP" 2>/dev/null || true
        CLOUD_LOOP=""
    fi
}

# Run os/cloud/provision.d/NN-*.sh inside the disk image
cloud_run_provisioners() {
    local script name
    for script in "$BUILD_ROOT/os/cloud/provision.d/"*.sh; do
        [ -f "$script" ] || continue
        name=$(basename "$script")
        say "Cloud provision: $name"
        install -m 0755 "$script" "$CLOUD_MNT/tmp/$name"
        chroot "$CLOUD_MNT" /usr/bin/env \
            SAI_NAME="$SAI_NAME" \
            SAI_VERSION="$SAI_VERSION" \
            CLOUD_RDP="${CLOUD_RDP:-1}" \
            CLOUD_USER="${CLOUD_USER:-saiadmin}" \
            CLOUD_LOOP="$CLOUD_LOOP" \
            /bin/bash "/tmp/$name"
        rm -f "$CLOUD_MNT/tmp/$name"
        done_ "$name"
    done
}

# GPT layout shared by the working disk and the final disk, so partition start
# sectors (which GRUB's boot code points at) are identical on both.
#   1: BIOS boot (GRUB core.img)  2: EFI system  3: root, LAST so growpart can extend it
cloud_partition() {   # file [root size, e.g. 9000MiB; empty = rest of disk]
    local root_size="${2:+size=$2, }"
    sfdisk --quiet "$1" <<EOF
label: gpt
size=1MiB,   type=21686148-6449-6E6F-744E-656564454649, name="bios"
size=255MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="esp"
${root_size}type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOF
}

cloud_mkfs_root() {   # device [extra mkfs.ext4 args...]
    local dev="$1"; shift
    # Leave out features older GRUB/e2fsprogs cannot read; fall back if mkfs is too old for -O ^x
    mkfs.ext4 -q -L sai-root -O ^orphan_file,^metadata_csum_seed "$@" "$dev" 2>/dev/null \
        || mkfs.ext4 -q -L sai-root "$@" "$dev"
}

# Copy the finished system onto a new disk that is only as large as its data
# (+ CLOUD_SLACK_MB). Cloud uploads/imports of raw images transfer the full
# file size, so this is what makes the raw file small. Same partition starts,
# same filesystem UUIDs and the same BIOS boot area are kept, so GRUB, grub.cfg
# and fstab stay valid without reinstalling anything. Expects the working root
# mounted at $CLOUD_MNT (virtual filesystems already unmounted). Replaces $1.
cloud_repack() {
    local raw="$1" final="$WORK/cloud-final.raw" fmnt="$WORK/cloud-final-mnt"
    local used_kb iused uuid root_mb start total_mb floop
    used_kb=$(df --output=used -k "$CLOUD_MNT" | tail -1 | tr -d ' ')
    iused=$(df --output=iused "$CLOUD_MNT" | tail -1 | tr -d ' ')
    uuid=$(blkid -s UUID -o value "${CLOUD_LOOP}p3")
    # data + 5% ext4 metadata + journal + slack, in whole MiB
    root_mb=$(( used_kb / 1024 * 105 / 100 + 256 + ${CLOUD_SLACK_MB:-1024} ))
    start=$(sfdisk -d "$raw" | awk -F'[=,]' '/^[^ ]*3 :/ {gsub(/ /,"",$2); print $2}')
    [ -n "$start" ] && [ -n "$uuid" ] || fail "Could not read the working disk layout"
    total_mb=$(( start / 2048 + root_mb + 1 ))   # +1 MiB for the backup GPT

    say "Repacking onto a ${total_mb} MiB disk (data $(( used_kb / 1024 )) MiB + slack)..."
    rm -f "$final"
    truncate -s "${total_mb}M" "$final"
    cloud_partition "$final" "${root_mb}MiB"
    floop=$(losetup -fP --show "$final")
    cloud_ensure_part_nodes "$floop"

    # Boot code: MBR (first 440 bytes, not the partition table) + BIOS boot partition
    dd if="$CLOUD_LOOP" of="$floop" bs=440 count=1 conv=notrunc status=none
    dd if="${CLOUD_LOOP}p1" of="${floop}p1" bs=1M status=none
    # ESP as a whole (same FAT serial = same UUID in fstab)
    umount "$CLOUD_MNT/boot/efi"
    dd if="${CLOUD_LOOP}p2" of="${floop}p2" bs=1M conv=sparse status=none
    # Root: fresh filesystem with the same UUID, enough inodes for the copy
    cloud_mkfs_root "${floop}p3" -U "$uuid" -m 1 -N $(( iused * 13 / 10 + 20000 ))
    mkdir -p "$fmnt"
    mount "${floop}p3" "$fmnt"
    if ! rsync -aHAXS --numeric-ids "$CLOUD_MNT/" "$fmnt/"; then
        umount "$fmnt"; losetup -d "$floop"
        fail "Copy to the final disk failed (raise CLOUD_SLACK_MB?)"
    fi
    sync
    df -h "$fmnt" | tail -1
    umount "$fmnt"
    losetup -d "$floop"

    umount "$CLOUD_MNT"
    cloud_teardown
    sfdisk --quiet --verify "$final" >/dev/null || fail "GPT verification failed on the final disk"
    mv -f "$final" "$raw"
    done_ "Final raw disk: ${total_mb} MiB (root grows to the VM disk size on first boot)"
}

# Move the backup GPT to the (new) end of the file and fix the protective MBR
cloud_fix_gpt_end() {
    if command -v sgdisk >/dev/null; then
        sgdisk -e "$1" >/dev/null
    else
        sfdisk --quiet --relocate gpt-bak-std "$1"
    fi
}

# Convert the raw disk into each requested format
cloud_export() {
    local raw="$1" base="$2" fmt
    for fmt in ${CLOUD_FORMATS//,/ }; do
        case "$fmt" in
            qcow2)  # OpenStack (Viettel, VNG, FPT, BizFly…), KVM, Proxmox
                say "Exporting qcow2..."
                qemu-img convert -p -O qcow2 -c -o compat=1.1 "$raw" "$base.qcow2" ;;
            vmdk)   # VMware vSphere/ESXi, AWS import-image
                say "Exporting vmdk (streamOptimized)..."
                qemu-img convert -p -O vmdk -o subformat=streamOptimized "$raw" "$base.vmdk" ;;
            vhd)    # Azure: fixed VHD, size aligned to 1 MiB
                say "Exporting fixed VHD (Azure)..."
                qemu-img convert -p -O vpc -o subformat=fixed,force_size "$raw" "$base.vhd" ;;
            gce)    # Google Cloud: tar.gz containing exactly one file named disk.raw
                say "Exporting GCE tarball..."
                local tdir="$WORK/gce"
                rm -rf "$tdir"; mkdir -p "$tdir"
                cp --sparse=always "$raw" "$tdir/disk.raw"
                # GCE requires the disk size to be a whole number of GiB
                local sz; sz=$(stat -c %s "$tdir/disk.raw")
                truncate -s $(( (sz + 1073741823) / 1073741824 * 1073741824 )) "$tdir/disk.raw"
                cloud_fix_gpt_end "$tdir/disk.raw"
                tar --format=oldgnu -Sczf "$base.gce.tar.gz" -C "$tdir" disk.raw
                rm -rf "$tdir" ;;
            raw) ;;  # handled by cloud_build: the working disk is moved, not copied
            *) note "Unknown cloud format '$fmt' (qcow2|vmdk|vhd|gce|raw) — skipped." ;;
        esac
    done
}

cloud_build() {
    [ -d "$ROOTFS" ] || fail "No rootfs. Run: sudo ./saibuild provision"
    rootfs_is_validated || fail "Rootfs is not fully provisioned. Run: sudo ./saibuild provision"
    require_cloud_tools
    leave_rootfs

    local gb raw base esp root m
    gb=$(cloud_disk_gb)
    # OUT_CLOUD may be absolute (CI writes to /mnt) or relative to the repo
    case "$OUT_CLOUD" in /*) base="$OUT_CLOUD" ;; *) base="$BUILD_ROOT/$OUT_CLOUD" ;; esac
    mkdir -p "$(dirname "$base")"
    raw="$WORK/cloud-disk.raw"
    say "Cloud disk: ${gb} GiB (grows to the VM disk size on first boot)"

    # 1. Sparse working disk (roomy, so provisioning can install packages)
    rm -f "$raw"
    truncate -s "${gb}G" "$raw"
    cloud_partition "$raw"
    CLOUD_LOOP=$(losetup -fP --show "$raw")
    cloud_ensure_part_nodes "$CLOUD_LOOP"
    esp="${CLOUD_LOOP}p2"; root="${CLOUD_LOOP}p3"

    mkfs.vfat -F32 -n ESP "$esp" >/dev/null
    cloud_mkfs_root "$root"

    # 2. Copy the provisioned rootfs
    mkdir -p "$CLOUD_MNT"
    mount "$root" "$CLOUD_MNT"
    mkdir -p "$CLOUD_MNT/boot/efi"
    mount "$esp" "$CLOUD_MNT/boot/efi"
    say "Copying rootfs into the disk image..."
    rsync -aHAX --numeric-ids \
        --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' \
        --exclude='/tmp/*' --exclude='/var/tmp/*' --exclude='/boot/efi/*' \
        "$ROOTFS/" "$CLOUD_MNT/"

    # 3. fstab by UUID (an installed system, not a live one)
    cat > "$CLOUD_MNT/etc/fstab" <<EOF
# Sai cloud image — partitions by UUID; root grows on first boot (cloud-init growpart)
UUID=$(blkid -s UUID -o value "$root")  /          ext4  defaults,discard,errors=remount-ro  0 1
UUID=$(blkid -s UUID -o value "$esp")  /boot/efi  vfat  umask=0077                          0 2
EOF

    # 4. Cloud overlay + provisioning (removes live bits, installs cloud-init,
    #    drivers, guest agents, bootloader, then seals the image)
    [ -d "$BUILD_ROOT/os/cloud/rootfs" ] && rsync -a "$BUILD_ROOT/os/cloud/rootfs/" "$CLOUD_MNT/"
    install -m 0644 "$BUILD_ROOT/os/cloud/packages.txt" "$CLOUD_MNT/tmp/cloud-packages.txt"
    cloud_mount_virtual
    cloud_run_provisioners
    rm -f "$CLOUD_MNT/etc/resolv.conf"

    # 5. Make the raw file as small as the data: repack onto a right-sized disk
    #    (default), or keep the working disk with unused blocks discarded
    for m in run sys proc dev/pts dev; do umount "$CLOUD_MNT/$m" 2>/dev/null || umount -lf "$CLOUD_MNT/$m" || true; done
    if [ "${CLOUD_SHRINK:-1}" = "1" ]; then
        cloud_repack "$raw"
    else
        fstrim "$CLOUD_MNT" 2>/dev/null || note "fstrim not supported here; images will be larger."
        cloud_teardown
    fi

    # CI runners are short on disk: the rootfs is no longer needed
    if [ "${CI:-0}" = "1" ]; then
        say "CI: freeing the rootfs..."
        rm -rf "${ROOTFS:?}"
    fi

    cloud_export "$raw" "$base"
    # raw (default): AWS import-snapshot, dd, or input for any qemu-img conversion.
    # Move the sparse working disk instead of copying it.
    if [[ ",${CLOUD_FORMATS}," == *",raw,"* ]]; then
        mv -f "$raw" "$base.raw"
    else
        rm -f "$raw"
    fi
    done_ "Cloud image(s) ready."
}

show_cloud_result() {
    local base="$OUT_CLOUD" f
    echo ""
    for f in "$base".qcow2 "$base".vmdk "$base".vhd "$base".gce.tar.gz "$base".raw; do
        [ -f "$f" ] && done_ "$f ($(du -h "$f" | cut -f1))"
    done
    echo ""
    echo "  Test locally:  see docs/CLOUD.md (QEMU + NoCloud seed)"
    echo "  Upload:        docs/CLOUD.md has per-cloud commands"
    echo ""
}
