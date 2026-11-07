#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: remove machine identity so every VM created from the image is
# unique (machine-id, SSH host keys, cloud-init state), then shrink caches.
# Must run LAST.
set -e

echo "[cloud] Sealing the image..."
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

rm -f /etc/ssh/ssh_host_*
echo sai > /etc/hostname

command -v cloud-init >/dev/null && cloud-init clean --logs --seed >/dev/null 2>&1 || true
rm -rf /var/lib/cloud/*

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin
find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -delete
find /var/log -type f -exec truncate -s 0 {} +
rm -f /root/.bash_history /root/.wget-hsts
rm -rf /tmp/* /var/tmp/*

test ! -s /etc/machine-id || { echo "[cloud] ERROR: machine-id not cleared" >&2; exit 1; }
echo "[cloud] sealed."
