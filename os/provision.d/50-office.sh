#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# WPS Office for Linux — an office suite familiar to users coming from Windows.
#
# WPS Office is freeware, closed-source software by Kingsoft and is NOT part of this
# repository. This script downloads the official .deb from the WPS CDN at build time
# and installs it unmodified. ISO users accept Kingsoft's EULA when they first open WPS.
#
# Options (environment variables at build time):
#   SAI_WPS=0          skip WPS and keep LMDE's LibreOffice (see 60-debloat.sh)
#   WPS_DEB_URL=...    use another .deb URL (newer builds from https://www.wps.com/office/linux/)
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

if [ "${SAI_WPS:-1}" != "1" ]; then
    echo "[office] SAI_WPS=0 — skipping WPS Office."
    exit 0
fi

# Public download link from the WPS for Linux page (international build, no URL signing).
WPS_DEB_URL="${WPS_DEB_URL:-https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11723/wps-office_11.1.0.11723.XA_amd64.deb}"
DEB=/tmp/wps-office.deb

if [ -d /opt/kingsoft/wps-office ]; then
    echo "[office] WPS already present in the rootfs — skipping."
    exit 0
fi

echo "[office] Downloading WPS Office: $WPS_DEB_URL"
wget --tries=3 --timeout=60 -q -O "$DEB" "$WPS_DEB_URL" || true
if [ ! -s "$DEB" ] || ! file "$DEB" | grep -qi 'Debian binary package'; then
    echo "[office] WARNING: WPS download failed — the ISO will not include WPS Office." >&2
    rm -f "$DEB"
    exit 0
fi

# Do not fail the whole build over one externally downloaded package: warn and continue.
if ! "${APT[@]}" install -y "$DEB"; then
    "${APT[@]}" install -f -y || true
    if [ ! -d /opt/kingsoft/wps-office ]; then
        echo "[office] WARNING: WPS could not be installed on this base — skipping." >&2
    fi
fi
rm -f "$DEB"

echo "[office] done."
