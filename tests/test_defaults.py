"""Static checks of the Sai default configuration (no ISO build required)."""

from __future__ import annotations

import json
import os
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]

PINNED = [
    "firefox.desktop",
    "wps-office-prometheus.desktop",
    "mintinstall.desktop",
    "cinnamon-settings.desktop",
]


class DesktopDefaultsTests(unittest.TestCase):
    def test_taskbar_pins_consistent(self):
        """Taskbar pins in dconf and in the applet schema must match."""
        dconf = (ROOT / "os/rootfs/etc/dconf/db/local.d/00-sai-desktop").read_text()
        for app in PINNED:
            self.assertIn(app, dconf)

        schema = json.loads(
            (ROOT / "os/rootfs/usr/share/cinnamon/applets"
                    "/grouped-window-list@cinnamon.org/settings-schema.json").read_text())
        self.assertEqual(PINNED, schema["pinned-apps"]["default"])

    def test_no_unlisted_third_party_apps(self):
        """No third-party browser/chat app is preconfigured outside the list (Firefox is the default)."""
        for cfg in (ROOT / "os/rootfs/etc").rglob("*"):
            if cfg.is_file() and cfg.stat().st_size < 1_000_000:
                try:
                    text = cfg.read_text()
                except (UnicodeDecodeError, PermissionError):
                    continue
                self.assertNotIn("google-chrome", text, str(cfg))
                self.assertNotIn("zalo", text.lower(), str(cfg))

    def test_desktop_has_only_intended_shortcuts(self):
        desktop = ROOT / "os/rootfs/etc/skel/Desktop"
        if desktop.is_dir():
            leftovers = {p.name for p in desktop.iterdir()} & {
                "google-chrome.desktop", "zalo.desktop",
                "wps-office-prometheus.desktop", "mintinstall.desktop"}
            self.assertFalse(leftovers)

    def test_default_browser_is_firefox(self):
        mimeapps = (ROOT / "os/rootfs/etc/skel/.config/mimeapps.list").read_text()
        self.assertIn("x-scheme-handler/https=firefox.desktop", mimeapps)

    def test_update_timer_enabled(self):
        link = ROOT / "os/rootfs/etc/systemd/system/timers.target.wants/sai-update.timer"
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(link), "/usr/lib/systemd/system/sai-update.timer",
                         "timer symlink must point at the shipped unit")
        unit = ROOT / "os/rootfs/usr/lib/systemd/system/sai-update.timer"
        self.assertTrue(unit.is_file())

    def test_internal_apt_source_disabled_by_default(self):
        src = (ROOT / "os/rootfs/etc/apt/sources.list.d/sai.sources").read_text()
        self.assertIn("Enabled: no", src)

    def test_provision_scripts_ordered_and_executable(self):
        scripts = sorted((ROOT / "os/provision.d").glob("*.sh"))
        self.assertGreaterEqual(len(scripts), 6)
        for s in scripts:
            self.assertTrue(s.stat().st_mode & 0o111, f"{s.name} is not executable")
            self.assertTrue(s.name[:2].isdigit(), f"{s.name} lacks an order prefix")


if __name__ == "__main__":
    unittest.main()
