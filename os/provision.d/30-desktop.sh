#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Desktop panel: install Cinnamon applets/extensions/actions, adjust Cinnamenu and the systray.
# The panel layout lives in the overlay (os/rootfs/etc/dconf/db/local.d/); this script
# only installs software and patches files shipped by Mint packages.
set -e
export DEBIAN_FRONTEND=noninteractive

SPICE_CACHE=/tmp/spices

# Fetch one spice from Mint's cinnamon-spices-* repos (each repo downloaded once)
add_spice() {  # add_spice <repo> <uuid> <destination>
    local repo="$1" uuid="$2" dest="$3" src
    local unpack="$SPICE_CACHE/$repo"
    if [ ! -d "$unpack" ]; then
        mkdir -p "$unpack"
        if ! wget -q -O "$unpack.zip" \
             "https://github.com/linuxmint/${repo}/archive/refs/heads/master.zip"; then
            echo "[desktop] WARNING: could not download $repo" >&2
            return 0
        fi
        unzip -qo "$unpack.zip" -d "$unpack"
        rm -f "$unpack.zip"
    fi
    src=$(find "$unpack" -type d -path "*/files/$uuid" -print -quit)
    [ -n "$src" ] || src=$(find "$unpack" -type d -name "$uuid" -print -quit)
    if [ -z "$src" ]; then
        echo "[desktop] WARNING: $uuid not found in $repo" >&2
        return 0
    fi
    mkdir -p "$dest"
    rm -rf "${dest:?}/$uuid"
    cp -a "$src" "$dest/"
    echo "[desktop] + $uuid"
}

rm -rf "$SPICE_CACHE"

# Applets
add_spice cinnamon-spices-applets Cinnamenu@json        /usr/share/cinnamon/applets
add_spice cinnamon-spices-applets weather@mockturtl     /usr/share/cinnamon/applets
# Extensions (installed, not enabled)
add_spice cinnamon-spices-extensions blur-overview@nailfarmer.nailfarmer.com /usr/share/cinnamon/extensions
add_spice cinnamon-spices-extensions cinnamon-dynamic-wallpaper@TobiZog      /usr/share/cinnamon/extensions
add_spice cinnamon-spices-extensions Watermark@germanfr                      /usr/share/cinnamon/extensions
# Nemo actions
add_spice cinnamon-spices-actions copy-path-to-clipboard@claudiux    /usr/share/nemo/actions
add_spice cinnamon-spices-actions create-desktop-shortcut@anaximeno  /usr/share/nemo/actions
add_spice cinnamon-spices-actions send-with-kdeconnect@rcalixte      /usr/share/nemo/actions

rm -rf "$SPICE_CACHE"

# Nemo actions ship as .nemo_action.in: activate them and make scripts executable
find /usr/share/nemo/actions -name '*.nemo_action.in' \
    -exec sh -c 'for f; do cp -f "$f" "${f%.in}"; done' _ {} +
find /usr/share/nemo/actions -type f \( -name '*.py' -o -name '*.sh' \) -exec chmod +x {} +

# --- Start menu (Cinnamenu): Sai logo, no text label ---
find /usr/share/cinnamon/applets/Cinnamenu@json -name settings-schema.json | \
while read -r schema; do
    python3 - "$schema" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as fh:
    cfg = json.load(fh)
cfg.get("menu-icon-custom", {})["default"] = True
if "menu-icon" in cfg:
    cfg["menu-icon"]["default"] = "/usr/share/pixmaps/sai-logo.png"
    cfg["menu-icon"]["default_icon"] = "/usr/share/pixmaps/sai-logo.png"
if "menu-label" in cfg:
    cfg["menu-label"]["default"] = ""
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=4, ensure_ascii=False)
    fh.write("\n")
PY
done
# Icon shown in the applet list
if [ -f /usr/share/pixmaps/sai-logo.png ]; then
    find /usr/share/cinnamon/applets/Cinnamenu@json -maxdepth 2 -type d | \
    while read -r d; do
        cp -f /usr/share/pixmaps/sai-logo.png "$d/icon.png" 2>/dev/null || true
    done
fi

# --- Systray: stop legacy icons (fcitx5, ...) from scaling up to the panel height ---
SYSTRAY=/usr/share/cinnamon/applets/systray@cinnamon.org/applet.js
if [ -f "$SYSTRAY" ]; then
    python3 - "$SYSTRAY" <<'PY'
import sys
path = sys.argv[1]
with open(path) as fh:
    code = fh.read()
code = code.replace(
    "this.icon_size = this.getPanelIconSize(St.IconType.FULLCOLOR) * global.ui_scale;",
    "this.icon_size = Math.min(this.getPanelIconSize(St.IconType.FULLCOLOR) * global.ui_scale, 16 * global.ui_scale);")
code = code.replace(
    "this.icon_size = this.getPanelIconSize() * global.ui_scale;",
    "this.icon_size = Math.min(this.getPanelIconSize() * global.ui_scale, 16 * global.ui_scale);")
code = code.replace("icon.set_y_align(Clutter.ActorAlign.FILL);",
                    "icon.set_y_align(Clutter.ActorAlign.CENTER);")
code = code.replace("button.set_y_align(Clutter.ActorAlign.FILL);",
                    "button.set_y_align(Clutter.ActorAlign.CENTER);")
with open(path, "w") as fh:
    fh.write(code)
PY
fi

dconf update || true
glib-compile-schemas /usr/share/glib-2.0/schemas/ || true

echo "[desktop] done."
