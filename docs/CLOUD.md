# Sai Cloud Image

`./saibuild cloud` turns the same provisioned rootfs used for the ISO into a
bootable VM disk. Use it to run Sai as a cloud desktop (VDI) on OpenStack, AWS,
Google Cloud, Azure, VMware or Proxmox.

```bash
sudo ./saibuild cloud                                # → Sai-<ver>-cloud-amd64.raw (default)
sudo CLOUD_FORMATS=raw,qcow2,vhd ./saibuild cloud     # several formats in one run
make cloud CLOUD_FORMATS=qcow2
```

If the workspace has no fully provisioned rootfs yet, `cloud` unpacks and
provisions it first. The ISO rootfs is only read: every cloud change happens in
a copy inside the disk image, so `./saibuild pack` still produces a normal ISO
afterwards.

## What differs from the ISO

| | Live ISO | Cloud image |
|---|---|---|
| Boot | live-boot + squashfs | GRUB on disk (BIOS **and** UEFI, Secure Boot via shim when available), root ext4 by UUID |
| User | live user `sai`, autologin | **cloud-init** creates `saiadmin` (`CLOUD_USER`) with the SSH key **and the password set in the cloud panel**; passwordless sudo; no password is baked into the image |
| Disk size | — | Image is small (rootfs + 25%); **root partition and filesystem grow to the VM disk size on boot** (cloud-init `growpart` + `resize_rootfs`) |
| Hostname, network | fixed `sai`, NetworkManager | from cloud metadata, rendered for NetworkManager |
| Access | local screen | **Open by default:** SSH (key or password) and xrdp remote desktop on 3389 (`CLOUD_RDP=1`) |
| Firewall | ufw, inbound blocked | ufw, inbound blocked **except 22/tcp (+3389/tcp with RDP)** |
| Console | Plymouth splash | no splash; kernel + GRUB on `ttyS0` and `tty0` (cloud serial consoles) |
| Removed | — | live-boot/live-config, live-installer, the "Install Sai" launcher, TLP |
| Identity | — | sealed: empty `machine-id`, no SSH host keys, clean cloud-init state |

### Drivers

No extra drivers need to be installed: the stock Debian kernel already contains
every paravirtual driver. The cloud image forces them into the initramfs
(`MODULES=most` plus `os/cloud/rootfs/usr/share/initramfs-tools/modules.d/sai-cloud`),
so the root disk is found whatever controller the cloud presents:

| Platform | Disk | Network |
|---|---|---|
| OpenStack / KVM / Proxmox | `virtio_blk`, `virtio_scsi` | `virtio_net` |
| AWS Nitro | `nvme` | `ena` |
| Google Cloud | `virtio_scsi`, `nvme` | `virtio_net`, `gve` (gVNIC) |
| Azure / Hyper-V | `hv_storvsc` | `hv_netvsc` |
| VMware | `vmw_pvscsi`, `ahci` | `vmxnet3` |
| Xen (older AWS) | `xen_blkfront` | `xen_netfront` |

Guest agents ship for each hypervisor and only start on their own platform:
`qemu-guest-agent` (OpenStack/Proxmox), `open-vm-tools` (VMware),
`hyperv-daemons` (Azure/Hyper-V). AWS and Google Cloud need none; cloud-init
covers provisioning on both.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `CLOUD_FORMATS` | `raw` | Comma list of `raw`, `qcow2`, `vmdk`, `vhd`, `gce` |
| `CLOUD_DISK_GB` | auto | Image disk size; auto = rootfs + 25% + ~1 GiB. VMs can use any larger disk |
| `CLOUD_RDP` | `1` | `1` = install xrdp and open 3389; `0` = SSH only |
| `CLOUD_USER` | `saiadmin` | Default cloud-init user (gets the cloud's SSH key + password) |
| `CLOUD_SHRINK` | `1` | Final raw disk sized to the data + `CLOUD_SLACK_MB` (small uploads); root grows on boot |
| `CLOUD_SLACK_MB` | `1024` | Free space left in the image's root before growpart runs |
| `OUT_CLOUD` | `Sai-<ver>-cloud-amd64` | Output base name (extension added per format) |

Customize the image with `os/cloud/packages.txt`, the overlay in
`os/cloud/rootfs/`, and the ordered scripts in `os/cloud/provision.d/`
(`90-seal.sh` must stay last).

## Formats and upload

The `raw` file is sparse: `ls -lh` shows the full disk size, `du -h` the real
usage. Copy it with `cp --sparse=always`, `rsync -S` or convert it; plain
uploads send the full size.

| Target | Format | Commands |
|---|---|---|
| OpenStack (Viettel IDC, VNG Cloud, FPT, BizFly…) | qcow2 or raw | `openstack image create sai-1.0 --disk-format qcow2 --container-format bare --file Sai-*.qcow2 --property hw_qemu_guest_agent=yes --property hw_firmware_type=uefi` |
| AWS | raw (or vmdk) | `aws s3 cp Sai-*.raw s3://BUCKET/` → `aws ec2 import-snapshot --disk-container Format=RAW,UserBucket={S3Bucket=BUCKET,S3Key=Sai-....raw}` → `aws ec2 register-image --name sai --architecture x86_64 --root-device-name /dev/xvda --block-device-mappings DeviceName=/dev/xvda,Ebs={SnapshotId=snap-…} --ena-support --boot-mode uefi-preferred` |
| Google Cloud | gce | `gsutil cp Sai-*.gce.tar.gz gs://BUCKET/` → `gcloud compute images create sai --source-uri gs://BUCKET/Sai-....gce.tar.gz --guest-os-features UEFI_COMPATIBLE,VIRTIO_SCSI_MULTIQUEUE,GVNIC` |
| Azure | vhd | `az storage blob upload --type page …` → `az image create --source https://….vhd --os-type Linux --hyper-v-generation V2` |
| VMware | vmdk | Import into vSphere / ESXi as an existing disk |
| Proxmox | raw or qcow2 | `qm importdisk <vmid> Sai-*.raw <storage>`, add a Cloud-Init drive, set BIOS to OVMF or SeaBIOS |

Convert later without rebuilding: `qemu-img convert -O qcow2 -c Sai-*.raw Sai.qcow2`.

## Test locally (QEMU + NoCloud seed)

```bash
cat > user-data <<'EOF'
#cloud-config
ssh_authorized_keys: [ "ssh-ed25519 AAAA... you@laptop" ]
password: ChangeMe123          # what a cloud panel's "password" field sends
chpasswd: { expire: false }
EOF
echo "instance-id: sai-test" > meta-data
cloud-localds seed.iso user-data meta-data      # package: cloud-image-utils

cp --sparse=always Sai-*-cloud-amd64.raw test.raw && qemu-img resize -f raw test.raw 40G
qemu-system-x86_64 -m 4G -smp 2 -enable-kvm -nographic \
  -drive file=test.raw,format=raw,if=virtio -drive file=seed.iso,media=cdrom \
  -nic user,model=virtio,hostfwd=tcp::2222-:22,hostfwd=tcp::3389-:3389
# add -bios /usr/share/ovmf/OVMF.fd to test UEFI

ssh -p 2222 saiadmin@localhost 'df -h /'   # root should show ~40G
```

Then connect with any RDP client (Remmina, Microsoft Remote Desktop) to
`localhost:3389` as `saiadmin` / the password set above.

## Remote desktop security

- The password comes from the cloud (panel field or user-data `password:` /
  `chpasswd:`). Without one, log in with the SSH key and run `sudo passwd saiadmin`;
  xrdp needs a password.
- The same password works for SSH and RDP. For key-only SSH, set user-data
  `ssh_pwauth: false`.
- Port 3389 is open in ufw so the cloud security group is the actual gate: allow
  it only from your office/VPN ranges, or keep 3389 closed there and tunnel
  through SSH (`ssh -L 3389:localhost:3389 saiadmin@vm`, then RDP to `localhost`).
  `CLOUD_RDP=0` builds an SSH-only image without xrdp.

## CI artifact

GitHub Actions builds the raw image and uploads it compressed as
`Sai-<ver>-cloud-amd64.raw.zst` (with `SHA256SUMS.cloud`). Restore the sparse raw
disk with `zstd -d Sai-*-cloud-amd64.raw.zst`, or stream it straight into another
format: `zstd -dc Sai-*.raw.zst > disk.raw && qemu-img convert -O qcow2 -c disk.raw Sai.qcow2`.
