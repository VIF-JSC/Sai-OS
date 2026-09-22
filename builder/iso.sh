#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# ISO tree operations: extract, brand the bootloader, repack.

# ---------------------------------------------------------------- unpack ---
# Extract the base ISO into the workspace. The pristine extraction is cached;
# later builds copy from the cache (~30 s instead of 3-5 min).
iso_unpack() {
    say "Preparing workspace..."
    leave_rootfs
    umount "$WORK/mnt" 2>/dev/null || true
    rm -rf "$ROOTFS" "$ISO_TREE"
    mkdir -p "$WORK/mnt" "$ISO_TREE"

    # CI runners are throwaway: skip the cache and extract straight into the
    # workspace, saving ~11 GB of disk compared to keeping a cached copy.
    if [ "${SOSBUILD_NO_CACHE:-${CI:-0}}" = "1" ]; then
        [ -f "${BASE_ISO:-}" ] || fail "No-cache mode needs the base ISO."
        say "Extracting the ISO directly into the workspace (no cache)..."
        mount -o loop,ro "$BASE_ISO" "$WORK/mnt"
        local sq
        sq=$(cd "$WORK/mnt" && ls */filesystem.squashfs 2>/dev/null | head -1)
        [ -n "$sq" ] || { umount "$WORK/mnt"; fail "filesystem.squashfs not found in the ISO"; }
        rsync -a --exclude="$sq" "$WORK/mnt/" "$ISO_TREE/"
        unsquashfs -d "$ROOTFS" "$WORK/mnt/$sq"
        umount "$WORK/mnt"
        done_ "Workspace ready (no cache)."
        return 0
    fi

    if [ ! -d "$CACHE_ROOTFS" ] || [ ! -d "$CACHE_ISO" ]; then
        [ -f "${BASE_ISO:-}" ] || fail "Cache incomplete and no base ISO — run again without options to download it."
        say "Extracting the ISO (first time — later builds use the cache)..."
        rm -rf "${CACHE_ROOTFS:?}" "${CACHE_ISO:?}"
        mount -o loop,ro "$BASE_ISO" "$WORK/mnt"
        local sq
        sq=$(cd "$WORK/mnt" && ls */filesystem.squashfs 2>/dev/null | head -1)
        [ -n "$sq" ] || { umount "$WORK/mnt"; fail "filesystem.squashfs not found in the ISO"; }
        mkdir -p "$CACHE_ISO"
        rsync -a --exclude="$sq" "$WORK/mnt/" "$CACHE_ISO/"
        unsquashfs -d "$CACHE_ROOTFS" "$WORK/mnt/$sq"
        umount "$WORK/mnt"
        done_ "Pristine extraction cached."
    fi

    say "Copying workspace from cache..."
    cp -a "$CACHE_ROOTFS" "$ROOTFS"
    cp -a "$CACHE_ISO/." "$ISO_TREE/"
    done_ "Workspace ready."
}

# ------------------------------------------------------------ boot brand ---
# Rebrand the boot menus (isolinux + GRUB) from Linux Mint to Sai.
# DEBUG_BOOT=1 drops quiet/splash so the kernel log is visible.
iso_brand_boot() {
    local title="${SAI_NAME} ${SAI_VERSION} 64-bit"
    say "Branding bootloader → ${title}"

    local cfg
    # Menu labels + live-session parameters, applied to every isolinux and GRUB cfg
    while IFS= read -r cfg; do
        sed -i \
            -e "s/LMDE [0-9][0-9.]* Cinnamon 64-bit/${title}/gI" \
            -e "s/LMDE [0-9][0-9.]* 64-bit/${title}/gI" \
            -e "s/Welcome to LMDE [0-9][0-9.]*/Welcome to ${title}/gI" \
            -e "s/Linux Mint Debian Edition/${SAI_NAME}/gI" \
            -e "s/\bLMDE\b/${SAI_NAME}/g" \
            -e "s/Linux Mint/${SAI_NAME}/gI" \
            -e "s/username=mint/username=sai/g" \
            -e "s/hostname=lmde/hostname=sai/g" \
            -e "s/hostname=mint/hostname=sai/g" \
            "$cfg"
        # Live-session language: English by default (no locale=vi_VN injected);
        # Vietnamese is preinstalled and selectable in Settings → Languages.
        # Kernel cmdline: normalize quiet/splash (except the nomodeset entry)
        if [ "${DEBUG_BOOT:-0}" = "1" ]; then
            sed -i -E '/^[[:space:]]*(append|APPEND|linux)/ s/\b(quiet|splash)\b//g' "$cfg"
        else
            sed -i -E '/^[[:space:]]*(append|APPEND)[[:space:]].*boot=(casper|live)/ { /nomodeset|nosplash/! { s/\b(quiet|splash)\b//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//; s/[[:space:]]*--/ quiet splash --/; /--/! s/$/ quiet splash/ } }' "$cfg"
        fi
    done < <(find "$ISO_TREE" \( -path '*/isolinux/*.cfg' -o -path '*/syslinux/*.cfg' \
                               -o -path '*/grub/*.cfg' -o -path '*/EFI/boot/*.cfg' \) 2>/dev/null)

    # Boot menu background image
    local art="$BUILD_ROOT/brand/boot-splash.png"
    local isolinux_bin isolinux_dir=""
    isolinux_bin=$(find "$ISO_TREE" -maxdepth 3 -name isolinux.bin 2>/dev/null | head -1)
    [ -n "$isolinux_bin" ] && isolinux_dir=$(dirname "$isolinux_bin")

    if [ -f "$art" ] && [ -n "$isolinux_dir" ]; then
        # Keep Mint's stock gfxboot UI (switching to vesamenu falls back to a
        # black text screen); only swap the background image.
        cp "$art" "$isolinux_dir/splash.png"
        find "$isolinux_dir" -name '*.cfg' \
            -exec sed -i '/^[[:space:]]*menu[[:space:]]\+background/Id' {} +
        local menu_cfg="$isolinux_dir/stdmenu.cfg"
        [ -f "$menu_cfg" ] || menu_cfg="$isolinux_dir/isolinux.cfg"
        [ -f "$menu_cfg" ] && sed -i '1i menu background splash.png' "$menu_cfg"
        done_ "Boot menu background: $(basename "$menu_cfg")"
    fi

    if [ -f "$art" ] && [ -d "$ISO_TREE/boot/grub" ]; then
        cp "$art" "$ISO_TREE/boot/grub/splash.png"
        local grub_cfg="$ISO_TREE/boot/grub/grub.cfg"
        if [ -f "$grub_cfg" ] && ! grep -q '^background_image' "$grub_cfg"; then
            # background_image is a GRUB2 COMMAND (not a variable) and only works
            # AFTER gfxterm is active. Mint does not enable gfxterm, so insert the
            # whole sequence at the top of the file.
            sed -i '1i insmod all_video\ninsmod gfxterm\nterminal_output gfxterm\ninsmod png\nbackground_image /boot/grub/splash.png' "$grub_cfg"
            # Mint sets menu colors further down, which would override ours, so
            # edit those lines in place: black = transparent over the image,
            # cyan highlight per the Sai palette.
            sed -i -e 's|^set color_normal=.*|set color_normal=white/black|' \
                   -e 's|^set color_highlight=.*|set color_highlight=cyan/black|' "$grub_cfg"
        fi
        done_ "GRUB background."
    fi

    iso_add_install_entry
}

# Add an "Install Sai" entry to the boot menu.
# LMDE uses live-installer, which has no ubiquity-style only-ubiquity parameter,
# so Sai injects the token `sai.install=1` into the kernel cmdline. The script
# /usr/bin/sai-install-launcher in the rootfs sees the token and opens the
# installer as soon as the session starts. The entry title is ASCII because
# BIOS gfxboot may not render non-ASCII characters.
iso_add_install_entry() {
    local title="Install Sai (Install to disk)"

    # GRUB (UEFI machines) — loopback.cfg too, so Ventoy/loopback boots get the Install entry
    local grub_cfg
    for grub_cfg in "$ISO_TREE/boot/grub/grub.cfg" "$ISO_TREE/boot/grub/loopback.cfg"; do
        [ -f "$grub_cfg" ] || continue
        # Do not use only-ubiquity as the guard: Mint's stock "OEM install" entry
        # also contains it. Check for Sai's own Install title instead.
        grep -q "Install Sai" "$grub_cfg" && continue
        # Two passes: pass 1 captures the first live menuentry block, pass 2 prints
        # the clone BEFORE it, so Install becomes the first entry.
        awk -v title="$title" '
            NR == FNR {
                if (/^menuentry/ && !captured) { capture = 1; captured = 1 }
                if (capture) block = block $0 "\n"
                if (capture && /^}/) capture = 0
                next
            }
            /^menuentry/ && !emitted {
                emitted = 1
                clone = block
                sub(/menuentry "[^"]*"/, "menuentry \"" title "\"", clone)
                sub(/boot=live/, "boot=live sai.install=1", clone)
                printf "%s\n", clone
            }
            { print }
        ' "$grub_cfg" "$grub_cfg" > "$grub_cfg.tmp" && mv "$grub_cfg.tmp" "$grub_cfg"
        # Install is first but must NOT be the default: pin default to entry 1
        # (Start, since Install is always entry 0). Use the index rather than the
        # title so this does not depend on the sed above; replace an existing
        # set default line if present (later lines win in grub.cfg).
        if grep -q '^set default=' "$grub_cfg"; then
            sed -i 's/^set default=.*/set default="1"/' "$grub_cfg"
        else
            sed -i '1i set default="1"' "$grub_cfg"
        fi
        done_ "Install entry added: $(basename "$grub_cfg")"
    done

    # isolinux (BIOS machines)
    local live_cfg
    live_cfg=$(find "$ISO_TREE" -path '*/isolinux/live.cfg' 2>/dev/null | head -1)
    if [ -n "$live_cfg" ] && ! grep -q "Install Sai" "$live_cfg"; then
        # Two passes: clone the live label and insert it BEFORE the original so
        # Install is first. Safe because the live label keeps "menu default";
        # syslinux/gfxboot picks the default by that flag, not by position.
        awk -v title="$title" '
            NR == FNR {
                if (/^label /) nlabel++
                if (nlabel == 1) block = block $0 "\n"
                next
            }
            /^label / && !emitted {
                emitted = 1
                clone = block
                sub(/^label [^\n]*/, "label install", clone)
                sub(/menu label [^\n]*/, "menu label " title, clone)
                # Do NOT inherit "menu default" — Install must not be the default
                sub(/[ \t]*menu default\n/, "", clone)
                sub(/boot=live/, "boot=live sai.install=1", clone)
                printf "%s\n", clone
            }
            { print }
        ' "$live_cfg" "$live_cfg" > "$live_cfg.tmp" && mv "$live_cfg.tmp" "$live_cfg"
        done_ "isolinux: Install entry added."
    fi
}

# ------------------------------------------------------------------ pack ---
iso_pack_squashfs() {
    workspace_ready || fail "No workspace. Run: sudo ./saibuild unpack"
    leave_rootfs

    # Clean up before compressing. The virtual directories must be EMPTY but
    # PRESENT: without them the live system has no mountpoints for devtmpfs/proc.
    rm -rf "$ROOTFS/tmp"/* "$ROOTFS/var/tmp"/* 2>/dev/null || true
    local d
    for d in proc sys dev run; do
        mkdir -p "$ROOTFS/$d"
        find "$ROOTFS/$d" -mindepth 1 -delete 2>/dev/null || true
    done

    # LMDE (Debian live-boot) keeps the squashfs in live/; casper/ kept as fallback
    local live_dir=""
    for d in live casper; do
        [ -d "$ISO_TREE/$d" ] && { live_dir="$d"; break; }
    done
    [ -n "$live_dir" ] || fail "Neither live/ nor casper/ found in the ISO tree"

    say "Compressing filesystem.squashfs (${SQUASH_ARGS[1]}) → ${live_dir}/ ..."
    mksquashfs "$ROOTFS" "$ISO_TREE/$live_dir/filesystem.squashfs" "${SQUASH_ARGS[@]}"
    # filesystem.size: casper needs it; live-boot ignores it, but refresh it if present
    if [ -f "$ISO_TREE/$live_dir/filesystem.size" ]; then
        du -sx --block-size=1 "$ROOTFS" | cut -f1 > "$ISO_TREE/$live_dir/filesystem.size"
    fi

    # The live boot reads the initrd from $live_dir/, not from the squashfs. The
    # Plymouth step regenerated the initramfs inside the rootfs, so copy it out.
    local initrd live_initrd
    initrd=$(ls -1t "$ROOTFS"/boot/initrd.img-* 2>/dev/null | head -1)
    live_initrd=$(ls -1 "$ISO_TREE/$live_dir"/initrd* 2>/dev/null | head -1)
    if [ -n "$initrd" ] && [ -n "$live_initrd" ]; then
        cp "$initrd" "$live_initrd"
        done_ "Live initrd: $(basename "$initrd") → ${live_dir}/$(basename "$live_initrd")"
    else
        note "Could not update the live initrd (initrd=$initrd, live=$live_initrd)"
    fi
}

iso_pack_image() {
    workspace_ready || fail "No workspace. Run: sudo ./saibuild unpack"
    say "Creating the ISO image..."

    ( cd "$ISO_TREE" || fail "Cannot enter $ISO_TREE"
      find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt 2>/dev/null || true

      local args=(-as mkisofs -iso-level 3 -full-iso9660-filenames -volid "$ISO_LABEL")
      # BIOS
      if [ -f isolinux/isolinux.bin ]; then
          args+=(-b isolinux/isolinux.bin -c isolinux/boot.cat
                 -no-emul-boot -boot-load-size 4 -boot-info-table)
          [ -f /usr/lib/ISOLINUX/isohdpfx.bin ] && \
              args+=(-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin)
      fi
      # UEFI
      local efi=""
      [ -f EFI/boot/efiboot.img ] && efi=EFI/boot/efiboot.img
      [ -z "$efi" ] && [ -f boot/grub/efi.img ] && efi=boot/grub/efi.img
      if [ -n "$efi" ]; then
          args+=(-eltorito-alt-boot -e "$efi" -no-emul-boot
                 -append_partition 2 0xef "$efi")
      fi
      args+=(-output "$BUILD_ROOT/$OUT_ISO" .)
      xorriso "${args[@]}"
    )
}

iso_pack() {
    iso_pack_squashfs
    # The rootfs is now inside the squashfs; on CI delete it to reclaim ~10 GB
    # for writing the ISO (GitHub runners have ~14 GB free).
    if [ "${CI:-0}" = "1" ]; then
        say "CI: freeing the rootfs after compression..."
        rm -rf "${ROOTFS:?}"
    fi
    iso_pack_image
}
