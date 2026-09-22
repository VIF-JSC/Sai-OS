#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Appearance: icon theme, cursor, font, Cinnamon theme, and Mint defaults pointed at Sai.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

echo "[appearance] Installing download tools..."
"${APT[@]}" update -qq
"${APT[@]}" install -y --no-install-recommends \
    unzip wget curl git ca-certificates file xz-utils fontconfig cabextract python3

fetch_zip() {  # fetch_zip <url> <extract dir>
    local url="$1" dest="$2" tmp
    tmp=$(mktemp /tmp/fetch-XXXX.zip)
    if wget -q -O "$tmp" "$url"; then
        unzip -qo "$tmp" -d "$dest"
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"
    echo "[appearance] WARNING: could not download $url" >&2
    return 1
}

# --- Icons: Win11 (Fluent / Windows 11 style, familiar to Windows users) ---
echo "[appearance] Win11 icon theme..."
if fetch_zip "https://github.com/yeyushengfan258/Win11-icon-theme/archive/refs/heads/main.zip" /tmp/win11icons; then
    (cd /tmp/win11icons/Win11-icon-theme-main && ./install.sh >/dev/null) || true
    rm -rf /tmp/win11icons
fi
# The theme's install.sh installs to /usr/share/icons/Win11* when run as root
[ -d /usr/share/icons/Win11 ] || echo "[appearance] WARNING: Win11 icons not installed" >&2

# Add the Sai logo to the theme AFTER installing (install.sh wipes the theme
# directory, so the override cannot live in the overlay)
if [ -d /usr/share/sai/icon-overrides/Win11 ] && [ -d /usr/share/icons/Win11 ]; then
    cp -a /usr/share/sai/icon-overrides/Win11/. /usr/share/icons/Win11/
fi

# --- Cursor: Bibata ---
echo "[appearance] Bibata cursor..."
if wget -q -O /tmp/bibata.tar.xz \
     "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.6/Bibata-Modern-Classic.tar.xz"; then
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/
    rm -f /tmp/bibata.tar.xz
fi

# --- Font: Be Vietnam Pro ---
echo "[appearance] Be Vietnam Pro font..."
if fetch_zip "https://github.com/bettergui/BeVietnamPro/archive/refs/heads/master.zip" /tmp/bvp; then
    mkdir -p /usr/share/fonts/truetype/be-vietnam-pro
    find /tmp/bvp -name '*.ttf' -exec cp {} /usr/share/fonts/truetype/be-vietnam-pro/ \;
    rm -rf /tmp/bvp
    fc-cache -f >/dev/null || true
fi

# --- Theme: Cinnamon Delight (+ companion icons) ---
echo "[appearance] Cinnamon Delight theme..."
for repo in Cinnamon-Delight Cinnamon-Delight-Icons; do
    rm -rf "/tmp/$repo"
    git clone --depth 1 "https://github.com/DrMcC0y/${repo}.git" "/tmp/$repo" || continue
    case "$repo" in
        Cinnamon-Delight)       dest="/usr/share/themes/Cinnamon-Delight" ;;
        Cinnamon-Delight-Icons) dest="/usr/share/icons/Cinnamon-Delight-Icons" ;;
    esac
    rm -rf "$dest"
    # The repo may keep the theme in a same-named subdirectory or at the root
    if [ -d "/tmp/$repo/$(basename "$dest")" ]; then
        cp -a "/tmp/$repo/$(basename "$dest")" "$(dirname "$dest")/"
    else
        mkdir -p "$dest"
        cp -a "/tmp/$repo/." "$dest/"
    fi
    rm -rf "/tmp/$repo"
done

# --- Point Mint's defaults at the Sai theme/wallpaper ---
ART=/usr/share/glib-2.0/schemas/mint-artwork.gschema.override
if [ -f "$ART" ]; then
    sed -i \
        -e 's/Mint-Y-Dark-Aqua\|Mint-Y-Dark\|Mint-Y-Aqua/Cinnamon-Delight/g' \
        -e 's/Mint-Y-Sand/Win11/g' \
        -e 's|/usr/share/backgrounds/linuxmint/default_background.jpg|/usr/share/backgrounds/sai/default.png|g' \
        -e 's/linuxmint-logo-ring-symbolic/sai-logo-symbolic/g' \
        "$ART"
fi
GREETER=/etc/lightdm/lightdm-gtk-greeter.conf.d/99_linuxmint.conf
if [ -f "$GREETER" ]; then
    sed -i \
        -e 's|/usr/share/backgrounds/linuxmint/default_background.jpg|/usr/share/backgrounds/sai/default.png|g' \
        -e 's/Mint-Y-Aqua/Cinnamon-Delight/g' -e 's/Mint-Y-Sand/Win11/g' \
        "$GREETER"
fi

# Mint installer icon → Sai logo
[ -f /usr/share/pixmaps/sai-logo.png ] && \
    cp -f /usr/share/pixmaps/sai-logo.png /usr/share/pixmaps/mintubiquity.png

# Make Nemo windows group correctly on the taskbar
if [ -f /usr/share/applications/nemo.desktop ] && \
   ! grep -q '^StartupWMClass=' /usr/share/applications/nemo.desktop; then
    echo 'StartupWMClass=Nemo' >> /usr/share/applications/nemo.desktop
fi

# --- Rebuild caches ---
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
gtk-update-icon-cache -f /usr/share/icons/Win11 >/dev/null 2>&1 || true
glib-compile-schemas /usr/share/glib-2.0/schemas/ || true
dconf update || true

echo "[appearance] done."
