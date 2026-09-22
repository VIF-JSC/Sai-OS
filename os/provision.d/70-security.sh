#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Safe defaults for office machines: firewall blocking inbound connections.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

echo "[security] Enabling ufw..."
command -v ufw >/dev/null || "${APT[@]}" install -y ufw

# Debian's default policy already matches (INPUT=DROP, OUTPUT=ACCEPT in
# /etc/default/ufw); only enable it. Do not call `ufw enable` inside the chroot
# because it touches the build host's iptables; edit the config so the service
# loads the rules when the real machine boots.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable ufw >/dev/null 2>&1 || true

grep -q '^ENABLED=yes' /etc/ufw/ufw.conf || { echo "[security] ERROR: ufw not enabled" >&2; exit 1; }
echo "[security] done."
