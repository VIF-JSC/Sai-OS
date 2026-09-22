# Sai brand and artwork

The source code in this repository (build scripts, scripts shipped in the operating
system, configuration, documentation) is released under **GNU GPL-3.0-or-later**; see
[LICENSE](LICENSE).

That license does **not** cover the Sai brand identity:

- The names **Sai** / **SAI OS**, the wordmark, the S-and-star logo and their variants
- Wallpapers, boot menu backgrounds, the Plymouth watermark, the ASCII logo
- Every file under `brand/`, `os/rootfs/usr/share/backgrounds/sai/`,
  `os/rootfs/usr/share/pixmaps/sai-*`, `os/rootfs/usr/share/icons/**/sai-logo*`,
  `os/rootfs/usr/share/sai/ascii-logo*`, `os/rootfs/usr/share/sai/icon-overrides/`

These assets are **copyright and trademarks of the Sai project, all rights reserved**.
You may download, build and use the unmodified Sai ISO. If you fork this repository to
ship your own distribution, replace the name and the brand assets with your own;
[docs/REBRAND.md](docs/REBRAND.md) lists every location and provides a rename checklist.

## Third-party trademarks

Sai is remastered from LMDE (Linux Mint Debian Edition) on top of Debian. **Linux Mint**,
**LMDE** and the Mint logo are trademarks of Linux Mint; **Debian** is a trademark of
Software in the Public Interest, Inc. Sai is not affiliated with, sponsored by, or
endorsed by Linux Mint or Debian. The ISO removes the Mint name and logo from every
visible location; technical identifiers (`ID_LIKE`, the `/etc/linuxmint/info` path,
`mint*` package names) are kept because system tools depend on them. The copyright
notices of every package remain untouched at `/usr/share/doc/<package>/copyright`.

Other third-party components (theme, icons, cursor, font, input method, WPS Office)
keep their original licenses; see [CREDITS.md](CREDITS.md).
