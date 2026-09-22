#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Plymouth boot splash: Sai theme embedded into the initramfs.
# Must run LAST: update-initramfs has to capture every other rootfs change.
set -e

THEME=/usr/share/plymouth/themes/sai
ASSETS=/usr/share/backgrounds/sai

mkdir -p "$THEME"
rm -f "$THEME"/*.png   # drop assets from previous builds to avoid mismatched frames

# Copy only the assets Plymouth needs. Do NOT copy the 4K wallpapers here: the whole
# theme directory goes into the initramfs (bigger initrd, slower boot).
for f in animation-*.png throbber-*.png watermark.png plymouth-logo.png \
         bullet.png entry.png lock.png; do
    cp "$ASSETS"/$f "$THEME/" 2>/dev/null || true
done

# If the brand set lacks any frame, substitute the watermark
if [ -f "$THEME/watermark.png" ]; then
    for i in $(seq -f '%04g' 1 36); do
        [ -f "$THEME/animation-$i.png" ] || cp "$THEME/watermark.png" "$THEME/animation-$i.png"
    done
    for i in $(seq -f '%04g' 1 30); do
        [ -f "$THEME/throbber-$i.png" ] || cp "$THEME/watermark.png" "$THEME/throbber-$i.png"
    done
fi

# Theme definition (Plymouth two-step module)
cat > "$THEME/sai.plymouth" <<'EOF'
[Plymouth Theme]
Name=Sai
Description=Sai boot screen
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/sai
Font=Cantarell 12
TitleFont=Cantarell Light 30
HorizontalAlignment=.5
VerticalAlignment=.5
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.382
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.382
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=-1
Transition=none
TransitionDuration=0.0
# Navy background fading to black; the blue S mark with a silver star sits in the center
BackgroundStartColor=0x0a1226
BackgroundEndColor=0x000000
ProgressBarBackgroundColor=0x142a4d
ProgressBarForegroundColor=0x00d4ff
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false

[shutdown]
UseEndAnimation=false

[reboot]
UseEndAnimation=false

[updates]
SuppressMessages=true
UseProgressBar=true
ProgressBarShowPercentComplete=true
Title=Installing updates...
SubTitle=Do not turn off the computer

[system-upgrade]
SuppressMessages=true
UseProgressBar=true
ProgressBarShowPercentComplete=true
Title=Upgrading the system...
SubTitle=Do not turn off the computer

[firmware-upgrade]
SuppressMessages=true
UseProgressBar=true
ProgressBarShowPercentComplete=true
Title=Upgrading firmware...
SubTitle=Do not turn off the computer
EOF

# Force the default theme. Mint's default.plymouth symlink is managed by alternatives
# and may still point at BGRT: replace the symlink directly, then sync alternatives.
rm -f /usr/share/plymouth/themes/default.plymouth
ln -s "$THEME/sai.plymouth" /usr/share/plymouth/themes/default.plymouth
update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth "$THEME/sai.plymouth" 300 >/dev/null 2>&1 || true
update-alternatives --set default.plymouth "$THEME/sai.plymouth" >/dev/null 2>&1 || true

# On LMDE/Debian, /etc/plymouth/plymouthd.conf sets Theme=mint-logo and this file
# OVERRIDES the default.plymouth symlink (both end up in the initramfs). Without
# overwriting it, boot still shows the Mint logo even with the symlink fixed.
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=sai
ShowDelay=0
EOF

# Embed the theme into the initramfs (the live boot reads the initrd, not the rootfs)
update-initramfs -u -k all

# Self-check: symlink + plymouthd.conf + theme actually present INSIDE the initramfs
if ! readlink -f /usr/share/plymouth/themes/default.plymouth | grep -q '/sai/sai.plymouth$'; then
    echo "[boot-splash] ERROR: default.plymouth does not point at the Sai theme" >&2
    exit 1
fi
grep -q '^Theme=sai' /etc/plymouth/plymouthd.conf || {
    echo "[boot-splash] ERROR: plymouthd.conf does not set Theme=sai" >&2; exit 1
}
latest_initrd=$(ls -1t /boot/initrd.img-* | head -1)
if command -v lsinitramfs >/dev/null 2>&1; then
    lsinitramfs "$latest_initrd" | grep -q 'plymouth/themes/sai/sai.plymouth' || {
        echo "[boot-splash] ERROR: initramfs does not contain the sai theme" >&2; exit 1
    }
    # plymouthd.conf inside the initramfs must be the Theme=sai version just written
    lsinitramfs "$latest_initrd" | grep -q 'etc/plymouth/plymouthd.conf' && \
        echo "[boot-splash] initramfs contains plymouthd.conf (Theme=sai)."
fi

echo "[boot-splash] done."
