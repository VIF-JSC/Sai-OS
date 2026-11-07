#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image only: drop what a VM never uses, to keep the image small.
#   - hardware firmware + CPU microcode (the hypervisor owns the real hardware)
#   - kernel headers when no DKMS module needs them
#   - documentation and man pages (copyright files are KEPT for license compliance)
#   - translations other than English and Vietnamese
# The ISO is not affected: it needs firmware for real machines.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

installed() {   # installed package names matching the given globs
    dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' "$@" 2>/dev/null | awk '$1 ~ /^ii/ {print $2}'
}
before=$(du -sxm / | cut -f1)

# Purging a firmware/l10n package can take a metapackage with it (e.g. mint-meta-*).
# Mark everything manual first so nothing else is ever autoremoved because of that.
apt-mark showauto | xargs -r apt-mark manual >/dev/null

# --- Firmware + microcode ---
mapfile -t pkgs < <(installed 'firmware-*' 'amd64-microcode' 'intel-microcode' 'atmel-firmware' 'bluez-firmware')
if [ ${#pkgs[@]} -gt 0 ]; then
    echo "[slim] firmware: ${pkgs[*]}"
    "${APT[@]}" purge -y "${pkgs[@]}"
fi

# --- Kernel headers (only when DKMS has nothing built against them) ---
if ! { command -v dkms >/dev/null && [ -n "$(dkms status 2>/dev/null)" ]; }; then
    mapfile -t pkgs < <(installed 'linux-headers-*' 'linux-kbuild-*' 'dkms')
    [ ${#pkgs[@]} -gt 0 ] && { echo "[slim] headers: ${pkgs[*]}"; "${APT[@]}" purge -y "${pkgs[@]}"; }
fi

# --- Translations/help for languages other than en + vi ---
mapfile -t pkgs < <(installed 'firefox-l10n-*' 'firefox-esr-l10n-*' 'libreoffice-l10n-*' \
                              'libreoffice-help-*' 'thunderbird-l10n-*' \
                    | grep -Ev -- '-(vi|en-us|en-gb|en)$' || true)
[ ${#pkgs[@]} -gt 0 ] && { echo "[slim] l10n: ${#pkgs[@]} packages"; "${APT[@]}" purge -y "${pkgs[@]}"; }

# --- Docs, man pages, other locales: delete now, and keep future packages from
#     installing them (dpkg path-exclude). Copyright files stay.
cat > /etc/dpkg/dpkg.cfg.d/90-sai-cloud-slim <<'EOF'
# Sai cloud image: no docs/man/info or non en/vi translations (copyright files kept)
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
path-exclude=/usr/share/man/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/vi/*
path-include=/usr/share/locale/en*
path-include=/usr/share/locale/locale.alias
path-exclude=/usr/share/help/*
path-include=/usr/share/help/C/*
path-include=/usr/share/help/vi/*
EOF
find /usr/share/doc -mindepth 1 ! -name copyright ! -type d -delete 2>/dev/null || true
find /usr/share/doc -mindepth 1 -type d -empty -delete 2>/dev/null || true
rm -rf /usr/share/man/* /usr/share/info/*
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
     ! -name 'vi' ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true
find /usr/share/help -mindepth 1 -maxdepth 1 -type d \
     ! -name 'C' ! -name 'vi' -exec rm -rf {} + 2>/dev/null || true

"${APT[@]}" clean
after=$(du -sxm / | cut -f1)
echo "[slim] rootfs ${before} MB → ${after} MB (saved $((before - after)) MB)"
