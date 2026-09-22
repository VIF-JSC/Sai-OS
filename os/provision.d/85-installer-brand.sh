#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Brand the live-installer: logo, welcome image, slideshow, colors.
# (80-debrand-deep already replaced the "Linux Mint" text; this script handles the visuals.)
set -e

LI=/usr/share/live-installer
[ -d "$LI" ] || { echo "[installer-brand] $LI not found — skipping."; exit 0; }

SAI_LOGO=/usr/share/icons/hicolor/scalable/apps/sai-logo.svg

# Logo in the installer window + welcome screen image
if [ -f "$SAI_LOGO" ]; then
    cp -f "$SAI_LOGO" "$LI/logo.svg"
    cp -f "$SAI_LOGO" "$LI/welcome.svg"
    echo "[installer-brand] logo.svg + welcome.svg → Sai logo"
fi

# Slideshow shown while files are copied: replace Mint's slides with the Sai page
# (self-contained, no dependency on the original l10n/jsonp set)
if [ -f /usr/share/sai/slideshow/index.html ]; then
    rm -rf "$LI/slideshow"
    mkdir -p "$LI/slideshow"
    cp /usr/share/sai/slideshow/index.html "$LI/slideshow/index.html"
    echo "[installer-brand] slideshow → Sai slides"
fi

# Wizard frame: Sai palette (brand blue #0F4FD6, dark #0A1226, accent #00D4FF).
# Selectors and the diagonal-stripe pattern are kept from the original; only the
# colors change (original: header grey #3f3f43, welcome black #2b2b2b, OEM blue #1575ca).
cat > "$LI/style.css" <<'CSS'
#TimezoneLabel {
  color: #efefef;
  background-color: #0A1226;
  border-radius: 4px;
}

.live-installer-welcome-oem-config {
  background-color: #0F4FD6;
  background-image: repeating-linear-gradient(-45deg, transparent, transparent 35px, rgba(255,255,255,.05) 35px, rgba(255,255,255,.05) 70px);
  color: #ffffff;
}

.live-installer-welcome {
  background-color: #0A1226;
  background-image: repeating-linear-gradient(-45deg, transparent, transparent 35px, rgba(0,212,255,.04) 35px, rgba(0,212,255,.04) 70px);
  color: #efefef;
}

.live-installer-header {
  color: #ffffff;
  background-color: #0F4FD6;
}

.live-installer-map {
  background-color: #16418F;
  background-image: repeating-linear-gradient(-45deg, transparent, transparent 35px, rgba(255,255,255,.05) 35px, rgba(255,255,255,.05) 70px);
}
CSS
echo "[installer-brand] style.css → Sai palette"

# Installer default language: geoip guesses from the IP address (in Vietnam it
# preselects Vietnamese and switches the UI), which contradicts the English-by-default
# policy. Patch: always preselect en_US; geoip still sets the TIMEZONE; the user can
# still pick Vietnamese from the list.
MAIN=/usr/lib/live-installer/main.py
if [ -f "$MAIN" ]; then
    python3 - "$MAIN" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
old = """            if (ccode == self.cur_country_code and
                (not set_iter or
                 set_iter and lang == 'en' or  # prefer English, or
                 set_iter and lang == ccode.lower())):  # fuzzy: lang matching ccode (fr_FR, de_DE, es_ES, ...)
                set_iter = iter"""
new = """            if locale == "en_US":  # Sai: English by default; geoip only used for the timezone
                set_iter = iter"""
if old in src:
    open(path, "w").write(src.replace(old, new))
    print("[installer-brand] language preselect → en_US")
else:
    print("[installer-brand] WARNING: language selection block not matched — upstream code changed?")
PY
fi

echo "[installer-brand] done."
