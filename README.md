# Sai

**Sai** is a desktop operating system for office work, remastered from **LMDE 7 “Gigi”**
(Linux Mint Debian Edition, based on **Debian 13 Trixie**, with no Ubuntu dependency). It is
aimed at Vietnamese users coming from Windows: a Windows-like Cinnamon desktop, Vietnamese
locale and input method preinstalled, an office suite, centralized updates, and safe defaults.

This repository contains **everything needed to build the Sai ISO from a stock LMDE ISO**:
the build scripts, the files overlaid onto the system, the provisioning scripts that run
inside the chroot, and the brand assets.

## Features

- Windows-like Cinnamon desktop: start menu (Cinnamenu), taskbar, familiar keyboard shortcuts
- Vietnamese: `vi_VN` locale generated, Asia/Ho_Chi_Minh timezone, fcitx5 + Lotus input method
  with Telex enabled (the UI defaults to English; switch in Settings → Languages)
- Applications: WPS Office (optional, see below), Firefox, Flameshot, CopyQ, System Monitor
- **Welcome page** opened in Firefox on first login, with an icon on the Desktop and in the menu
- Document templates in the right-click → New Document menu (`etc/skel/Templates`)
- Centralized updates: `sai-update` + daily systemd timer, Timeshift snapshot before each
  update for rollback, run-once ordered migrations
- Safe defaults: ufw enabled (inbound blocked), screen lock after 5 minutes, Firefox telemetry off
- zram swap, TLP power saving, Be Vietnam Pro font, Win11 icons, Bibata cursor, Cinnamon Delight theme
- Boot menu entry **Install Sai (Install to disk)** that goes straight to the installer

## Building the ISO

Requires a Debian/Ubuntu/Mint host with root (or Docker) and about 15 GB of free disk. The
base LMDE ISO (~3 GB) is downloaded once and cached.

```bash
sudo ./saibuild                 # dev build (lz4, fast)
sudo ./saibuild all --release   # release build (xz, smaller ISO)
make help                       # all shortcuts
```

Fast development loop:

```bash
sudo ./saibuild unpack      # extract the base ISO into build/ (once, cached)
sudo ./saibuild provision   # install packages + overlay + provisioning scripts
sudo ./saibuild shell       # enter the chroot for manual changes
sudo ./saibuild quick       # after editing the overlay, repack immediately
bash builder/inspect-iso.sh # check the boot branding of the built ISO
make test                   # static tests, no root needed
```

Environment options (defaults in `builder/env.sh`):

| Variable | Meaning |
|---|---|
| `SAI_VERSION` | Version written into the ISO name, os-release and the boot menu |
| `SAI_WPS=0` | Skip WPS Office and keep LMDE's LibreOffice |
| `WPS_DEB_URL` | Alternative WPS .deb URL (newer builds from wps.com/office/linux) |
| `APT_MIRROR` | A nearby Debian mirror for faster builds, e.g. `http://mirror.bizflycloud.vn/debian` |

On macOS: `docker compose run builder`, then run the commands above inside the container.
CI (`.github/workflows/build.yml`): every push and pull request runs shellcheck + unittest;
pushes to `main` or a `v*` tag build the real ISO and keep it as a workflow artifact for 7
days; a `v*` tag also creates a GitHub Release.

## Repository layout

| Path | Role |
|---|---|
| `saibuild` | Build CLI that orchestrates the steps |
| `builder/iso.sh` | ISO tree operations: extract, brand the bootloader, add the Install entry, repack |
| `builder/rootfs.sh` | Chroot operations: packages, local .debs, overlay, provisioning, validation |
| `os/rootfs/` | Files overlaid onto the system (branding, default configuration, `sai-update`, `sai-first-run`) |
| `os/provision.d/` | Scripts run inside the chroot in order `10-` → `90-` (identity, appearance, input method, office, debloat, security, debranding, installer, boot splash) |
| `os/apt/packages.txt` | Packages added on top of stock LMDE |
| `brand/` | Logo, wallpapers, boot splash, and `apply.py`, which generates every asset from the source files |
| `tests/` | Static tests: script syntax, config files, taskbar pins, wallpaper references |

## Installing

Boot the ISO and choose **Install Sai (Install to disk)** to go straight to the installer
(LMDE's live-installer), or **Start Sai** for a live session. Unattended installation is not
supported yet; see [docs/REBRAND.md](docs/REBRAND.md), section 7.

## Updating installed machines (OTA)

Installed machines run `sai-update` daily (systemd timer):

1. `apt full-upgrade`, including the Sai repository once enabled
   (`os/rootfs/etc/apt/sources.list.d/sai.sources`, disabled by default until you host a repo)
2. Run-once migrations in `/usr/share/sai/migrations/`; see the
   [migrations README](os/rootfs/usr/share/sai/migrations/README.md)

## Placeholder values

The public repository ships placeholder values so anyone can build: the `sai.internal`
domain (Firefox home page, About dialog), a generic support message, and a disabled OTA
repository. Replace them for your deployment following the table in
[docs/REBRAND.md](docs/REBRAND.md), section 7.

## Brand and renaming

The logo, wallpapers and the **Sai** name are not covered by the GPL; see
[LICENSE-BRAND.md](LICENSE-BRAND.md). To ship your own distribution, follow
[docs/REBRAND.md](docs/REBRAND.md): it maps every place the brand appears, lists the size
of each asset, and provides a system-wide rename checklist.

## License

- Source code in this repository: **GPL-3.0-or-later** ([LICENSE](LICENSE))
- Sai brand assets: all rights reserved ([LICENSE-BRAND.md](LICENSE-BRAND.md))
- The resulting ISO contains LMDE/Debian and thousands of open-source packages under their own
  licenses, available inside the ISO at `/usr/share/doc/<package>/copyright`. WPS Office is
  closed-source freeware from Kingsoft, downloaded unmodified at build time under Kingsoft's
  EULA. See [CREDITS.md](CREDITS.md).

Sai is not affiliated with, sponsored by, or endorsed by Linux Mint or Debian.

## Contributing

Open an issue or a pull request. Run `make test` (shellcheck + unittest, no root needed)
before submitting. Changes under `os/rootfs/` or `os/provision.d/` should describe how they
were tested on a real ISO (QEMU: `qemu-system-x86_64 -m 4G -enable-kvm -boot d -cdrom Sai-*.iso`).
