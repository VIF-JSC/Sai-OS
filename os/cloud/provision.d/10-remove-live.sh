#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: this disk is an INSTALLED system, so remove everything that only
# makes sense on the live ISO (live-boot, installer, install-mode autostart).
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

echo "[cloud] Removing live-session packages..."
mapfile -t live_pkgs < <(dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' \
        'live-boot*' 'live-config*' 'live-tools' 'live-installer*' 'casper' 'calamares*' \
        2>/dev/null | awk '$1 ~ /^ii/ {print $2}')
if [ ${#live_pkgs[@]} -gt 0 ]; then
    echo "[cloud]   ${live_pkgs[*]}"
    "${APT[@]}" purge -y "${live_pkgs[@]}"
fi

# Laptop power management has no use on a VM
dpkg-query -W -f '${db:Status-Abbrev}' tlp 2>/dev/null | grep -q '^ii' && "${APT[@]}" purge -y tlp || true

# Sai's live-only pieces (installer launcher, live-config identity)
rm -rf /etc/live
rm -f /etc/xdg/autostart/sai-install-mode.desktop \
      /usr/bin/sai-install-launcher \
      /usr/share/applications/live-installer.desktop \
      /etc/skel/Desktop/live-installer.desktop

# Live users must not exist in the image; cloud-init creates the real user
for u in mint sai "${CLOUD_USER:-saiadmin}"; do
    id "$u" >/dev/null 2>&1 && userdel -r "$u" 2>/dev/null || true
done

echo "[cloud] live bits removed."
