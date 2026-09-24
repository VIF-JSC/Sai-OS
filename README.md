# Sai OS

**Sai** is an enterprise-grade, privacy-first desktop operating system engineered for organizations, enterprises, and public sector institutions. Remastered from **LMDE 7 “Gigi”** (Linux Mint Debian Edition, based on **Debian 13 Trixie** with zero Ubuntu/Canonical dependencies), Sai delivers a turnkey, local-first computing environment designed to eliminate vendor lock-in, ensure complete data autonomy, and provide a frictionless transition for teams accustomed to Windows.

[English](README.md) • [Tiếng Việt](README.vi.md)

---

## Strategic Pillars & Value Proposition

Sai shifts the operating system paradigm from vendor-dictated cloud ecosystems to customer-centric autonomy, guided by three core principles:

### 1. Data Ownership & Infrastructure Autonomy *(Quyền tự chủ dữ liệu & hạ tầng)*
- **Privacy-by-Design & Zero Telemetry**: Out of the box, external telemetry, diagnostic reporting, and background tracking (including Firefox telemetry) are disabled. No organizational data leaves your network boundary.
- **Local-First Architecture**: Daily office tasks, document processing, and core utilities execute entirely on local hardware, without requiring cloud logins, online accounts, or external service dependencies.
- **Sovereign Fleet Lifecycle**: Organizations maintain end-to-end control of their operating system deployment. Internal update endpoints (`sai-update`), private package repositories, and automated snapshot rollbacks give IT administrators complete sovereignty over software lifecycle and fleet policies.

### 2. Anti-Vendor Lock-in & Open Standards *(Giải phóng khỏi phụ thuộc nhà cung cấp)*
- **Independent Debian Foundation**: Built on upstream LMDE 7 and Debian 13 "Trixie", freeing your organization from recurring operating system license subscriptions, proprietary vendor choke points, and arbitrary hardware deprecation cycles (e.g. artificial TPM 2.0 or CPU constraints).
- **Free of Proprietary Package Stores**: Built without Ubuntu dependencies or forced containerized package formats (no forced `snapd`), utilizing standard Debian `.deb` packages and native `apt` repositories.
- **Open Standards Throughout**: Relies on standard systemd architecture, native POSIX interfaces, open document formats, and standard configuration files.
- **Auditable & Reproducible**: 100% of the build scripts, system overlays, and provisioning stages are open and auditable in this repository. Organizations can inspect every line of code, modify packages, and reproduce their own OS images independently using `saibuild`.

### 3. Purpose-Built for Organizations *(Cho tổ chức / doanh nghiệp của bạn)*
- **Frictionless Windows-to-Linux Transition**: Features a familiar Cinnamon desktop layout (traditional bottom taskbar, Cinnamenu start menu, and Windows-standard shortcuts such as `Super+E` for File Explorer, `Ctrl+Shift+Esc` for System Monitor, and `Super+Shift+S` / `PrtSc` for screenshots), minimizing staff retraining time and operational downtime.
- **Turnkey Office Readiness**: Pre-configured with the `vi_VN` locale, Asia/Ho_Chi_Minh timezone, modern `Be Vietnam Pro` typography, and the `fcitx5` + `Lotus` input engine (Telex enabled out of the box). Bundled with office productivity tools (WPS Office / LibreOffice), document templates (`New Document` context menu), browser (Firefox), screenshot utility (Flameshot), and clipboard history (CopyQ).
- **Enterprise-Grade Manageability & Rollback Safety**:
  - Automated maintenance via `sai-update` running on a quiet systemd timer.
  - **Automated Timeshift snapshot creation** before every system upgrade, providing instantaneous, one-click rollback if an update causes regressions.
  - Deterministic, run-once idempotent migrations (`/usr/share/sai/migrations/`) to safely roll out configuration updates across existing fleets.
- **Hardened Default Security**: Inbound network connections blocked by default via `ufw` firewall, automated 5-minute screen locking, and unprivileged user safeguards.
- **Post-Quantum Cryptography**: TLS, Firefox and SSH use NIST FIPS 203 ML-KEM hybrid key exchange by default, users sign documents with ML-DSA (FIPS 204) from the file manager, `sai-pqc ca` issues post-quantum certificates for internal servers, releases are ML-DSA-signed, and a daily check plus the **Post-Quantum Security** menu entry (`sai-pqc`) report which parts of the machine are quantum-safe. See [docs/PQC.md](docs/PQC.md).
- **Hardware Longevity & Resource Optimization**: `zram` RAM swap compression and `TLP` power management extend the operational lifespan of legacy office workstations and maximize laptop battery life.

---

## Features at a Glance

| Domain | Included Features & Capabilities |
|---|---|
| **Desktop Experience** | Windows-like Cinnamon desktop, Cinnamenu application launcher, traditional taskbar, Win11-style icons, Bibata cursor, Cinnamon Delight theme. |
| **Localization & Fonts** | Generated `vi_VN` locale, `Asia/Ho_Chi_Minh` timezone, `Be Vietnam Pro` corporate typography, `fcitx5` + `Lotus` input method (Telex toggle via `` ` `` key). English UI by default (switch to Tiếng Việt anytime in Settings → Languages). |
| **Productivity Suite** | WPS Office (optional, full Word/Excel/PowerPoint compatibility) or LibreOffice, Firefox, Flameshot, CopyQ clipboard manager, System Monitor, right-click "New Document" templates (`etc/skel/Templates`). |
| **Fleet Operations** | `sai-update` orchestrated maintenance, automatic Timeshift snapshot before upgrades for instant rollback, run-once sequential migrations. |
| **Security & Privacy** | `ufw` firewall enabled with inbound traffic blocked, 5-minute screen lock policy, telemetry stripped/disabled, unprivileged user environment. |
| **Post-Quantum Cryptography** | NIST ML-KEM (FIPS 203) hybrid key exchange for TLS, Firefox and SSH, enforced at build time; ML-DSA (FIPS 204) document signing from the file manager, internal PQ certificate authority and release signatures; daily compliance check (`/var/lib/sai/pqc-status.json`); `sai-pqc` tool and menu entry. |
| **Hardware Efficiency** | `zram` compressed RAM swap for smooth multitasking on low-spec systems; `TLP` advanced power tuning for laptops. |
| **Installation** | Dedicated bootloader option **Install Sai (Install to disk)** for direct installation, plus live session mode. |

---

## Building the ISO

### Prerequisites
- A Debian, Ubuntu, or Linux Mint host with root privileges (or Docker).
- Approximately 15 GB of free disk space.
- The base LMDE 7 ISO (~3 GB) is downloaded once and cached locally.

### Quick Start

```bash
# Development build (lz4 compression, fast iteration)
sudo ./saibuild

# Release build (xz compression, optimized compact ISO)
sudo ./saibuild all --release

# View all available targets and help
make help
```

### Fast Development Workflow

For iterating on provisioning scripts or rootfs configurations:

```bash
sudo ./saibuild unpack      # Extract base ISO into build/ (cached)
sudo ./saibuild provision   # Apply overlay, install packages, run os/provision.d/
sudo ./saibuild shell       # Enter the chroot environment for debugging
sudo ./saibuild quick       # Repack the ISO immediately after overlay edits
bash builder/inspect-iso.sh # Inspect bootloader branding on the generated ISO
make test                   # Execute static tests (no root required)
```

### Build Environment Configuration

Custom parameters can be configured via environment variables (defaults in `builder/env.sh`):

| Variable | Description | Default |
|---|---|---|
| `SAI_VERSION` | Version string embedded in ISO name, `/etc/os-release`, and boot menu | `0.1.0` |
| `SAI_WPS=0` | Omit WPS Office and retain LMDE's LibreOffice package | `1` |
| `WPS_DEB_URL` | Custom download URL for WPS Office `.deb` package | Upstream build URL |
| `APT_MIRROR` | Nearby Debian mirror to accelerate package downloads | `http://deb.debian.org/debian` |

### Docker & macOS Support

To build on macOS or non-Debian environments:

```bash
docker compose run builder
# Inside the container:
./saibuild
```

### Continuous Integration (CI)

Every pull request and commit to `main` runs automated static checks (`shellcheck` and Python unit tests). Pushes to `main` or version tags (`v*`) build the production ISO, upload it as a 7-day workflow artifact, and publish GitHub Releases on tags.

---

## Repository Architecture

```
Sai-OS/
├── saibuild                  # Unified CLI orchestrator for build lifecycle
├── Makefile                  # Developer shortcuts for build, test, and cleanup
├── builder/
│   ├── env.sh                # Build parameters and default configuration
│   ├── iso.sh                # ISO tree operations: extract, brand bootloader, pack
│   ├── rootfs.sh             # Chroot operations: overlay, package install, validation
│   └── inspect-iso.sh        # Bootloader and ISO artifact verification script
├── os/
│   ├── apt/packages.txt      # Enterprise and office packages added to base LMDE
│   ├── rootfs/               # Files overlaid on target filesystem (configs, updates)
│   └── provision.d/          # Ordered chroot provisioning scripts (10- to 90-)
├── brand/
│   ├── apply.py              # Generation script for logos, themes, and splash art
│   ├── logo/                 # Vector brand assets
│   └── Wallpaper 4K/         # Branded desktop backgrounds
├── tests/                    # Automated regression tests (syntax, pins, configs)
└── docs/
    └── REBRAND.md            # Enterprise white-label and customization guide
```

---

## Deployment & Installation

1. Flash the generated `Sai-*.iso` to a USB drive (e.g. using Ventoy, Rufus, or `dd`).
2. Boot target machine in UEFI or BIOS mode.
3. Select **Install Sai (Install to disk)** to launch directly into the installer, or choose **Start Sai** to evaluate the environment in a live session.
4. For automated or unattended enterprise deployments, refer to [docs/REBRAND.md](docs/REBRAND.md), Section 7.

---

## Enterprise Fleet Updates & Rollback Safety

Installed workstations are configured with an automated maintenance pipeline via `sai-update` (executed daily by a systemd timer):

1. **Pre-Update Safety Snapshot**: Before performing any system changes, `sai-update` automatically creates a local **Timeshift snapshot**. If a broken upstream dependency or hardware incompatibility occurs, the system can be restored to its exact previous state in minutes.
2. **Deterministic Upgrade**: Runs `apt full-upgrade` against configured repositories. By default, the custom Sai internal repository (`/etc/apt/sources.list.d/sai.sources`) is staged in disabled state until your internal repository is hosted.
3. **Run-Once Ordered Migrations**: Executes idempotent migration scripts located in `/usr/share/sai/migrations/` (see the [Migrations Guide](os/rootfs/usr/share/sai/migrations/README.md)) to push configuration changes, security patches, or desktop tweaks cleanly to existing fleets.

---

## Enterprise White-Labeling & Deployment Customization

The public repository uses clean placeholder values to enable open, independent compilation out of the box:
- **Internal Domain**: `sai.internal` (used in browser defaults, documentation, and support dialogs).
- **Support Contact**: Generic enterprise IT support message.
- **OTA Repository**: Staged in disabled state until pointed to your organization's internal mirror.

To deploy Sai under your organization's own corporate identity, consult [docs/REBRAND.md](docs/REBRAND.md). It outlines every brand touchpoint, wallpaper/icon specifications, and provides a step-by-step checklist for enterprise white-labeling.

---

## Licensing & Compliance

- **Build Orchestration & Configuration Code**: Released under **GPL-3.0-or-later** ([LICENSE](LICENSE)).
- **Sai Brand Assets & Trademarks**: All rights reserved ([LICENSE-BRAND.md](LICENSE-BRAND.md)).
- **Upstream Operating System & Packages**: The resulting ISO contains Debian, LMDE, and open-source packages governed by their respective upstream licenses (accessible inside the system at `/usr/share/doc/<package>/copyright`).
- **WPS Office (Optional)**: Freeware distributed by Kingsoft, downloaded unmodified at build time under Kingsoft's End User License Agreement. See [CREDITS.md](CREDITS.md).

*Sai is an independent project and is not affiliated with, sponsored by, or endorsed by Linux Mint, Debian, or Canonical.*

---

## Verification & Contributing

We welcome issues, feedback, and pull requests:

```bash
# Run unit tests and syntax checks locally
make test

# Test the resulting ISO in QEMU virtual machine
qemu-system-x86_64 -m 4G -enable-kvm -boot d -cdrom Sai-*.iso
```
