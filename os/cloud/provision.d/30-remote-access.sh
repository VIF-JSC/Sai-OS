#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cloud image: SSH (always) and xrdp remote desktop (CLOUD_RDP=1), plus the
# matching ufw openings. Inbound stays blocked for everything else; restrict the
# source addresses in the cloud's security group as well.
set -e
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=600)

printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
trap 'rm -f /usr/sbin/policy-rc.d' EXIT

# Default cloud-init user name (CLOUD_USER, default saiadmin)
U="${CLOUD_USER:-saiadmin}"
[[ "$U" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "[cloud] invalid CLOUD_USER: $U" >&2; exit 1; }
sed -i "s/^    name: saiadmin$/    name: $U/; s/sudo passwd saiadmin/sudo passwd $U/" \
    /etc/cloud/cloud.cfg.d/90-sai.cfg
grep -q "^    name: $U$" /etc/cloud/cloud.cfg.d/90-sai.cfg || { echo "[cloud] ERROR: default user not set" >&2; exit 1; }
echo "[cloud] default user: $U"

systemctl enable ssh >/dev/null 2>&1 || true
systemctl enable qemu-guest-agent >/dev/null 2>&1 || true

ports=(22)
if [ "${CLOUD_RDP:-1}" = "1" ]; then
    echo "[cloud] Installing xrdp remote desktop..."
    "${APT[@]}" install -y xrdp xorgxrdp
    # xrdp reads the TLS key through the ssl-cert group
    adduser xrdp ssl-cert >/dev/null 2>&1 || true
    systemctl enable xrdp >/dev/null 2>&1 || true
    ports+=(3389)
fi

# Open ports by editing ufw's rule files directly: running `ufw allow` in a
# chroot would touch the BUILD HOST's iptables.
add_rule() {   # file chain port any-address
    local file="$1" chain="$2" port="$3" any="$4"
    [ -f "$file" ] || return 0
    grep -q -- "--dport $port -j ACCEPT" "$file" && return 0
    sed -i "/^### END RULES ###/i ### tuple ### allow tcp $port $any any $any in\n-A $chain -p tcp --dport $port -j ACCEPT\n" "$file"
}
for p in "${ports[@]}"; do
    add_rule /etc/ufw/user.rules  ufw-user-input  "$p" 0.0.0.0/0
    add_rule /etc/ufw/user6.rules ufw6-user-input "$p" ::/0
done
grep -q -- '--dport 22 -j ACCEPT' /etc/ufw/user.rules || { echo "[cloud] ERROR: SSH not allowed in ufw" >&2; exit 1; }
echo "[cloud] inbound allowed: ${ports[*]}/tcp"
