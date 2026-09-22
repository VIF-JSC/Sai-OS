#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Remove applications rarely used on office machines to keep the ISO smaller.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

echo "[debloat] Removing unused applications..."
# mintwelcome: Mint's welcome screen, shows Mint branding on first login
"${APT[@]}" purge -y thunderbird hexchat drawing hypnotix rhythmbox mintwelcome 2>/dev/null || true
# Remove LibreOffice only when WPS installed successfully (50-office.sh); otherwise keep it.
if [ -d /opt/kingsoft/wps-office ]; then
    "${APT[@]}" purge -y 'libreoffice*' 2>/dev/null || true
fi
"${APT[@]}" autoremove -y || true
"${APT[@]}" clean

echo "[debloat] done."
