#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: cloud-init, growpart, guest agents, bootloader (os/cloud/packages.txt).
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

LIST=/tmp/cloud-packages.txt
[ -f "$LIST" ] || { echo "[cloud] $LIST missing" >&2; exit 1; }
mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' "$LIST")

# Do not start services inside the chroot
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
trap 'rm -f /usr/sbin/policy-rc.d' EXIT

"${APT[@]}" update
# shim/grub-signed are optional: without them the image still boots, just not
# with Secure Boot enabled.
if ! "${APT[@]}" install -y "${pkgs[@]}"; then
    echo "[cloud] Retrying without the Secure Boot packages..."
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -Ev '^(grub-efi-amd64-signed|shim-signed)$')
    "${APT[@]}" install -y "${pkgs[@]}"
fi
rm -f "$LIST"

command -v cloud-init >/dev/null || { echo "[cloud] ERROR: cloud-init missing" >&2; exit 1; }
command -v growpart  >/dev/null || { echo "[cloud] ERROR: growpart missing" >&2; exit 1; }
echo "[cloud] packages installed."
