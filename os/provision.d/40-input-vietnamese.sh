#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Vietnamese input: fcitx5 + Lotus. Default config (profile, env, autostart) lives in
# the os/rootfs overlay; this script installs the packages and disables IBus.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

echo "[input] Removing any preinstalled fcitx5..."
"${APT[@]}" remove -y fcitx5 fcitx5-unikey 2>/dev/null || true
"${APT[@]}" autoremove -y 2>/dev/null || true

# --- fcitx5-lotus repo (has a Debian trixie branch) ---
CODENAME=$(. /etc/os-release && echo "${DEBIAN_CODENAME:-${UBUNTU_CODENAME:-trixie}}")
mkdir -p /etc/apt/keyrings
[ -f /etc/apt/keyrings/fcitx5-lotus.gpg ] || \
    curl -fsSL https://fcitx5-lotus.pages.dev/pubkey.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg
echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/${CODENAME} ${CODENAME} main" \
    > /etc/apt/sources.list.d/fcitx5-lotus.list

echo "[input] Installing fcitx5-lotus..."
"${APT[@]}" update -qq
if ! "${APT[@]}" install -y fcitx5-lotus fcitx5-config-qt \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 im-config; then
    # Fallback: if Lotus fails on this base, use fcitx5-unikey from the main Debian
    # archive (Telex works fine) and switch the default profile to unikey.
    echo "[input] WARNING: fcitx5-lotus failed to install — falling back to fcitx5-unikey." >&2
    rm -f /etc/apt/sources.list.d/fcitx5-lotus.list
    "${APT[@]}" update -qq
    "${APT[@]}" install -y fcitx5 fcitx5-unikey fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 im-config
    sed -i 's/lotus/unikey/g' /etc/skel/.config/fcitx5/profile
    rm -f /etc/skel/.config/fcitx5/conf/lotus.conf
fi

# --- Disable IBus autostart so it does not compete with fcitx5 ---
mkdir -p /etc/xdg/autostart-disabled
for f in ibus.desktop ibus-daemon.desktop; do
    [ -f "/etc/xdg/autostart/$f" ] && \
        mv -f "/etc/xdg/autostart/$f" "/etc/xdg/autostart-disabled/$f"
done

# The login helper from the overlay must be executable
[ -f /usr/local/bin/sai-input-setup ] && chmod 755 /usr/local/bin/sai-input-setup

echo "[input] done."
