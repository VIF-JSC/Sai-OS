#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Deep debranding: replace the visible string "Linux Mint" in the mint* tools
# (Software Manager, Update Manager, Driver Manager, ...) with the brand name.
#
# ONLY user-visible text is changed. Left untouched:
#   - Technical identifiers: ID_LIKE, the /etc/linuxmint/info path, mint* package names
#   - /usr/share/doc/*/copyright — must be preserved under the GPL
#   - Plain "linuxmint" strings (paths, Python imports, URLs)
set -e

BRAND="${SAI_NAME:-Sai}"

# Directories holding the UI code of the Mint tools and the installer
TARGETS=(
    /usr/lib/linuxmint
    /usr/share/linuxmint
    /usr/share/mint-mirrors
    /usr/share/mintlocale
    /usr/share/mintsources
    # LMDE's live-installer
    /usr/lib/live-installer
    /usr/share/live-installer
)

changed=0
for dir in "${TARGETS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
        sed -i "s/Linux Mint/${BRAND}/g" "$f"
        changed=$((changed + 1))
    done < <(grep -rIl 'Linux Mint' "$dir" 2>/dev/null)
done

# Desktop entries of the mint* apps (Name/Comment shown in the menu)
while IFS= read -r f; do
    sed -i "s/Linux Mint/${BRAND}/g" "$f"
    changed=$((changed + 1))
done < <(grep -Il 'Linux Mint' /usr/share/applications/*.desktop 2>/dev/null)

echo "[debrand-deep] Replaced 'Linux Mint' → '${BRAND}' in ${changed} file(s)."

# Self-check: the main apps no longer show the Linux Mint string
leftover=$(grep -rIl 'Linux Mint' /usr/lib/linuxmint 2>/dev/null | head -3 || true)
[ -z "$leftover" ] || echo "[debrand-deep] WARN: still present in: $leftover"

echo "[debrand-deep] done."
