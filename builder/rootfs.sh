#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Rootfs operations: install packages, apply the overlay, run provisioning scripts.

# Repair a half-finished apt/dpkg state left by a previous build, if any
rootfs_repair_apt() {
    run_in_rootfs '
        rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
        timeout 60 dpkg --configure -a --force-confdef --force-confold >/dev/null 2>&1 || true
        # Stop debconf from downloading package data during install (not needed in a chroot)
        mkdir -p /usr/share/package-data-downloads.disabled
        [ -d /usr/share/package-data-downloads ] && \
            find /usr/share/package-data-downloads -maxdepth 1 -type f \
                 -exec mv -f {} /usr/share/package-data-downloads.disabled/ \; 2>/dev/null
        true
    '
}

# Install the packages listed in os/apt/packages.txt
rootfs_install_packages() {
    local list="$BUILD_ROOT/os/apt/packages.txt"
    [ -f "$list" ] || { note "$list not found, skipping."; return 0; }

    say "Installing extra packages..."
    grep -Ev '^\s*(#|$)' "$list" > "$ROOTFS/tmp/pkg.list"
    local mirror_cmd=""
    if [ -n "$APT_MIRROR" ]; then
        # Replace deb.debian.org with a nearby mirror (APT_MIRROR in builder/env.sh)
        # for faster builds. LMDE declares its repos in official-package-repositories.list.
        mirror_cmd="sed -i 's|http://deb.debian.org/debian|$APT_MIRROR|g; s|https://deb.debian.org/debian|$APT_MIRROR|g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true;"
    fi
    run_in_rootfs "
        export DEBIAN_FRONTEND=noninteractive
        echo 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true' | debconf-set-selections
        echo 'ttf-mscorefonts-installer msttcorefonts/present-mscorefonts-eula note' | debconf-set-selections
        $mirror_cmd
        apt-get -o DPkg::Lock::Timeout=600 update
        xargs -a /tmp/pkg.list apt-get -o DPkg::Lock::Timeout=600 install -y
        rm -f /tmp/pkg.list
    "
    done_ "Packages installed."
}

# Overlay files from os/rootfs/ onto the filesystem
rootfs_apply_overlay() {
    workspace_ready || fail "No workspace. Run: sudo ./saibuild unpack"
    local src="$BUILD_ROOT/os/rootfs"
    [ -d "$src" ] || { note "$src not found, skipping overlay."; return 0; }
    enter_rootfs   # idempotent; mounts are needed to compile dconf/schemas in the chroot

    say "Applying the os/rootfs/ overlay..."
    # fcitx5/profile must be a FILE; remove a same-named directory so rsync does not fail
    [ -d "$ROOTFS/etc/skel/.config/fcitx5/profile" ] && \
        rm -rf "$ROOTFS/etc/skel/.config/fcitx5/profile"
    rsync -a "$src/" "$ROOTFS/"

    # The overlay changes dconf/gschema files, so recompile or the ISO ships a stale DB
    [ -d "$ROOTFS/etc/dconf/db/local.d" ] && run_in_rootfs \
        'dconf compile /etc/dconf/db/local /etc/dconf/db/local.d 2>/dev/null || dconf update || true'
    [ -d "$ROOTFS/usr/share/glib-2.0/schemas" ] && run_in_rootfs \
        'glib-compile-schemas /usr/share/glib-2.0/schemas/ || true'
    done_ "Overlay applied."
}

# Run os/provision.d/NN-*.sh in order inside the rootfs
rootfs_run_provisioners() {
    local script name
    for script in "$BUILD_ROOT/os/provision.d/"*.sh; do
        [ -f "$script" ] || continue
        name=$(basename "$script")
        say "Provision: $name"
        install -m 0755 "$script" "$ROOTFS/tmp/$name"
        chroot "$ROOTFS" /usr/bin/env \
            SAI_NAME="$SAI_NAME" \
            SAI_VERSION="$SAI_VERSION" \
            SAI_WPS="${SAI_WPS:-1}" \
            WPS_DEB_URL="${WPS_DEB_URL:-}" \
            BASE_VERSION="$BASE_VERSION" \
            BASE_EDITION="$BASE_EDITION" \
            /bin/bash "/tmp/$name"
        rm -f "$ROOTFS/tmp/$name"
        done_ "$name"
    done
}

# Verify the rootfs is complete before allowing a quick pack.
# The marker is written only when EVERYTHING passes; after a Ctrl+C mid-way,
# `quick` re-provisions instead of packing an incomplete rootfs.
rootfs_validate() {
    run_in_rootfs '
        set -e
        test -f /etc/dconf/db/local
        test -f /etc/xdg/autostart/sai-theme.desktop
        test -f /etc/systemd/zram-generator.conf
        test -d /usr/share/cinnamon/applets/Cinnamenu@json
        test -f /usr/share/plymouth/themes/sai/sai.plymouth
        test -x /usr/bin/sai-update
        test -x /usr/bin/sai-install-launcher
        test -x /usr/bin/sai-first-run
        test -f /usr/share/applications/sai-welcome.desktop
        test -f /usr/share/sai/welcome/index.html
        test -f /etc/xdg/autostart/sai-first-run.desktop
        test -f /etc/skel/Desktop/sai-welcome.desktop
        test -f /etc/firefox/policies/policies.json
        test -d /etc/skel/Templates
        grep -q "^ENABLED=yes" /etc/ufw/ufw.conf
        command -v fcitx5 >/dev/null
        date -u +%Y-%m-%dT%H:%M:%SZ > /etc/sai-release-stamp
    '
    # WPS is downloaded from an external CDN; if missing, warn but do not fail the build
    run_in_rootfs 'test -d /opt/kingsoft/wps-office' || \
        note "WPS Office is not in the rootfs (download failed or SAI_WPS=0) — the ISO ships without it."
}

rootfs_is_validated() { [ -f "$ROOTFS/etc/sai-release-stamp" ]; }

# Full pass: packages + overlay + provisioning + validation + cleanup
rootfs_provision() {
    workspace_ready || fail "No workspace. Run: sudo ./saibuild unpack"
    say "Mounting chroot..."
    enter_rootfs
    rootfs_repair_apt
    rootfs_install_packages
    rootfs_apply_overlay
    rootfs_run_provisioners
    rootfs_validate
    done_ "Rootfs validated."

    say "Cleaning the chroot..."
    run_in_rootfs '
        apt-get -o DPkg::Lock::Timeout=600 clean
        rm -rf /tmp/* /var/tmp/*
        rm -f /etc/resolv.conf
    '
    leave_rootfs
}

rootfs_shell() {
    workspace_ready || fail "No workspace. Run: sudo ./saibuild unpack"
    enter_rootfs
    say "Inside the rootfs chroot — type 'exit' to leave."
    chroot "$ROOTFS" /bin/bash || true
    leave_rootfs
}
