#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# System identity: os-release, hostname, locale, and debranding of Mint files.
# Runs inside the chroot. Variables from the builder: SAI_VERSION, BASE_VERSION, BASE_EDITION.
set -e
export DEBIAN_FRONTEND=noninteractive

V="${SAI_VERSION:-1.0.0}"
EDITION="${BASE_EDITION:-cinnamon}"
PRETTY="Sai ${V}"

echo "[identity] ${PRETTY} (base: LMDE ${BASE_VERSION:-7} / Debian 13)"

# --- Language: English by default, Vietnamese generated so users can switch ---
sed -i -e 's/^# *\(vi_VN.UTF-8 UTF-8\)/\1/' -e 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen >/dev/null
printf 'LANG=en_US.UTF-8\n' > /etc/default/locale

# --- Timezone: Vietnam ---
ln -snf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
echo Asia/Ho_Chi_Minh > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true

# --- OS identification ---
# VERSION_CODENAME keeps the LMDE codename (gigi) and DEBIAN_CODENAME (trixie):
# Mint tools and apt look these up; unknown values break them.
tee /etc/os-release > /usr/lib/os-release <<EOF
NAME="Sai"
PRETTY_NAME="${PRETTY}"
VERSION="${V}"
VERSION_ID="${V}"
ID=sai
ID_LIKE="debian linuxmint"
VERSION_CODENAME=gigi
DEBIAN_CODENAME=trixie
HOME_URL="https://sai.internal/"
SUPPORT_URL="https://sai.internal/"
BUG_REPORT_URL="https://sai.internal/"
EOF

cat > /etc/lsb-release <<EOF
DISTRIB_ID=Sai
DISTRIB_RELEASE=${V}
DISTRIB_CODENAME=gigi
DISTRIB_DESCRIPTION="${PRETTY}"
EOF

# Read by Mint tools (mintinstall, mintupdate, live-installer, adjust-grub-title)
mkdir -p /etc/linuxmint
cat > /etc/linuxmint/info <<EOF
RELEASE=${V}
CODENAME=gigi
EDITION="${EDITION^}"
DESCRIPTION="${PRETTY}"
DESKTOP=Gnome
TOOLKIT=GTK
NEW_FEATURES_URL=https://sai.internal/
RELEASE_NOTES_URL=https://sai.internal/
USER_GUIDE_URL=https://sai.internal/
GRUB_TITLE=${PRETTY}
EOF

# --- Hostname + login banner ---
echo sai > /etc/hostname
sed -i 's/\bmint\b/sai/g' /etc/hosts
printf 'Sai %s \\n \\l\n' "$V" > /etc/issue
printf 'Sai %s\n' "$V" > /etc/issue.net

# --- Live session ---
for f in /etc/casper.conf /etc/live.conf; do
    [ -f "$f" ] || continue
    sed -i -e 's/Linux Mint/Sai/g' \
           -e 's/^\(export HOST=\).*/\1sai/' \
           -e 's/^\(export USERNAME=\).*/\1sai/' "$f"
done
id mint >/dev/null 2>&1 && usermod -c "Sai" mint || true

# --- Debrand the remaining Mint references ---
[ -f /etc/default/grub ] && \
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Sai"/' /etc/default/grub
[ -f /etc/default/grub.d/50_linuxmint.cfg ] && \
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Sai"/' /etc/default/grub.d/50_linuxmint.cfg

for f in /usr/share/applications/live-installer.desktop \
         /usr/share/applications/calamares.desktop \
         /etc/skel/Desktop/ubiquity.desktop; do
    [ -f "$f" ] && sed -i 's/Linux Mint/Sai/g' "$f"
done

find /usr/share/plymouth -type f \( -name '*.plymouth' -o -name '*.script' \) \
    -exec sed -i 's/Linux Mint/Sai/g' {} + 2>/dev/null || true
find /usr/share/distro-info -name '*.csv' \
    -exec sed -i 's/Linux Mint/Sai/g; s/linuxmint/sai/g' {} + 2>/dev/null || true
find /etc/skel /root -maxdepth 2 -type f \( -name '.bashrc' -o -name '.profile' \) \
    -exec sed -i 's/\bmint\b/sai/g' {} + 2>/dev/null || true
rm -f /etc/skel/.config/dconf/user

# --- Terminal logo for neofetch/fastfetch ---
mkdir -p /usr/local/bin
if [ -x /usr/bin/fastfetch ]; then
    cat > /usr/local/bin/fastfetch <<'EOF'
#!/bin/sh
# fastfetch with the Sai logo
for logo in /usr/share/sai/ascii-logo-color.ansi /usr/share/sai/ascii-logo.txt; do
    [ -f "$logo" ] && exec /usr/bin/fastfetch --logo "$logo" "$@"
done
exec /usr/bin/fastfetch "$@"
EOF
    chmod 755 /usr/local/bin/fastfetch
fi
if [ -x /usr/bin/neofetch ]; then
    cat > /usr/local/bin/neofetch <<'EOF'
#!/bin/sh
# neofetch with the Sai logo: print the logo, then the info block below it
# (neofetch --ascii miscalculates the width when the logo contains ANSI colors)
for logo in /usr/share/sai/ascii-logo-color.ansi /usr/share/sai/ascii-logo.txt; do
    if [ -f "$logo" ]; then
        cat "$logo"
        exec /usr/bin/neofetch --off "$@"
    fi
done
exec /usr/bin/neofetch "$@"
EOF
    chmod 755 /usr/local/bin/neofetch
fi

echo "[identity] done."
